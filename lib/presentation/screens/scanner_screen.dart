import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../blocs/document_bloc.dart';
import '../../data/services/image_service.dart';
import '../../data/services/ad_service.dart';
import '../../data/services/document_classifier_service.dart';
import '../../domain/entities/document.dart';
import 'document_workspace_screen.dart';

enum ScanMode { document, idCard, batch }

class ScannerScreen extends StatefulWidget {
  final ScanMode initialMode;

  const ScannerScreen({
    super.key,
    this.initialMode = ScanMode.document,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _cameraError = false;
  final ImagePicker _picker = ImagePicker();
  final List<String> _scannedPages = [];
  FilterType _selectedFilter = FilterType.original;
  int _selectedPageIndex = 0;
  bool _useFrontCamera = false;

  ScanMode _scanMode = ScanMode.document;
  String? _idFrontPath;
  String? _idBackPath;
  bool _isIdCard = false;
  bool _isReviewingBatch = false;

  late final AnimationController _scanLineController;
  late final Animation<double> _scanLinePosition;

  late final AnimationController _captureController;

  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();

    _scanMode = widget.initialMode;
    if (_scanMode == ScanMode.idCard) {
      _isIdCard = true;
    }

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _scanLinePosition = Tween<double>(begin: 0.08, end: 0.92).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOutSine),
    );

    _captureController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (!mounted) {
          _cameraController?.dispose();
          return;
        }
        setState(() {
          _isInitialized = true;
          _cameraError = false;
        });
      } else {
        if (mounted) setState(() => _cameraError = true);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) setState(() => _cameraError = true);
    }
  }

  void _toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    _useFrontCamera = !_useFrontCamera;
    final cameraIndex = _useFrontCamera ? 1 : 0;

    await _cameraController?.dispose();
    final newController = CameraController(
      _cameras![cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );
    _cameraController = newController;
    await newController.initialize();
    if (!mounted) {
      newController.dispose();
      return;
    }
    setState(() {});
  }

  void _closeScanner() {
    for (final path in _scannedPages) {
      try {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _captureController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: (_scannedPages.isEmpty ||
                          (_scanMode == ScanMode.batch && !_isReviewingBatch))
                      ? _buildCameraView()
                      : _buildPagePreview(),
                ),
                _buildBottomControls(),
              ],
            ),
            // Top Bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _closeScanner,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.xmark,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  if (_scannedPages.isNotEmpty &&
                      (_scanMode != ScanMode.batch || _isReviewingBatch))
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      color: CupertinoColors.activeBlue,
                      borderRadius: BorderRadius.circular(20),
                      onPressed: _saveDocument,
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else if (_scannedPages.isNotEmpty &&
                      _scanMode == ScanMode.batch &&
                      !_isReviewingBatch)
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      color: CupertinoColors.activeBlue,
                      borderRadius: BorderRadius.circular(20),
                      onPressed: () => setState(() => _isReviewingBatch = true),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.checkmark_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Done (${_scannedPages.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_cameras != null && _cameras!.length > 1)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _toggleCamera,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.camera_rotate,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Page count badge in review mode
            if (_scannedPages.isNotEmpty &&
                (_scanMode != ScanMode.batch || _isReviewingBatch))
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_selectedPageIndex + 1} of ${_scannedPages.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            // ID Card Step Guide Banner
            if (_scanMode == ScanMode.idCard && _scannedPages.isEmpty)
              Positioned(
                top: MediaQuery.of(context).padding.top + 56,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: CupertinoColors.activeBlue,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.person_crop_square_fill,
                          color: CupertinoColors.activeBlue,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _idFrontPath == null
                              ? 'Step 1 of 2: Align FRONT of ID Card'
                              : 'Step 2 of 2: Align BACK of ID Card',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_idFrontPath != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _idFrontPath = null),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Retake',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            // Batch Mode live status banner
            if (_scanMode == ScanMode.batch &&
                _scannedPages.isNotEmpty &&
                !_isReviewingBatch)
              Positioned(
                top: MediaQuery.of(context).padding.top + 56,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: CupertinoColors.activeBlue,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.square_stack_3d_up_fill,
                          color: CupertinoColors.activeBlue,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Batch: ${_scannedPages.length} ${_scannedPages.length == 1 ? 'page' : 'pages'} scanned',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    if (_cameraError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.camera_fill,
                  size: 36,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera Unavailable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'No camera sensor detected or permission denied. You can still scan documents by importing from Photos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                onPressed: () => _addMorePage(false),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.photo, size: 18),
                    SizedBox(width: 8),
                    Text('Import from Photos', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() => _cameraError = false);
                  _initCamera();
                },
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    color: CupertinoColors.activeBlue,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (!_isInitialized || _cameraController == null) {
      return const Center(child: CupertinoActivityIndicator(radius: 16));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            RepaintBoundary(
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
            if (_scanMode == ScanMode.idCard)
              Center(
                child: Container(
                  width: math.min(constraints.maxWidth * 0.88, 340),
                  height: math.min(constraints.maxWidth * 0.88, 340) / 1.58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: CupertinoColors.activeBlue,
                      width: 2.5,
                    ),
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _idFrontPath == null ? 'FRONT SIDE' : 'BACK SIDE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _scanLineController,
                  _captureController,
                ]),
                builder: (context, _) {
                  final height = constraints.maxHeight;
                  double scanY;
                  if (_isCapturing) {
                    scanY = _captureController.value * height;
                  } else {
                    scanY = _scanLinePosition.value * height;
                  }

                  final flashOpacity =
                      _isCapturing && _captureController.value < 0.33
                      ? (1.0 - _captureController.value / 0.33) * 0.6
                      : 0.0;

                  return Stack(
                    children: [
                      _buildCornerBrackets(height),
                      if (!_isCapturing) _buildScanLine(scanY),
                      if (_isCapturing)
                        _buildSweepLine(scanY, _captureController.value),
                      if (flashOpacity > 0)
                        Positioned.fill(
                          child: Container(
                            color: Colors.white.withValues(alpha: flashOpacity),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCornerBrackets(double height) {
    return CustomPaint(
      painter: _CornerBracketPainter(
        opacity: 0.55 + 0.2 * math.sin(_scanLineController.value * math.pi),
      ),
      size: Size.infinite,
    );
  }

  Widget _buildScanLine(double yPosition) {
    return Positioned(
      top: yPosition - 1.5,
      left: 40,
      right: 40,
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(1.5),
          color: CupertinoColors.activeBlue.withValues(alpha: 0.8),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.activeBlue.withValues(alpha: 0.6),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSweepLine(double yPosition, double progress) {
    final glowOpacity = progress < 0.8 ? 1.0 : (1.0 - (progress - 0.8) / 0.2);
    return Positioned(
      top: yPosition - 2,
      left: 20,
      right: 20,
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: CupertinoColors.activeBlue.withValues(alpha: glowOpacity),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.activeBlue.withValues(
                alpha: 0.6 * glowOpacity,
              ),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagePreview() {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            itemCount: _scannedPages.length,
            onPageChanged: (index) =>
                setState(() => _selectedPageIndex = index),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: InteractiveViewer(
                    child: Image.file(
                      File(_scannedPages[index]),
                      fit: BoxFit.contain,
                      cacheWidth: 1080,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_scannedPages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _buildFilterChips(),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildFilterChips() {
    const filters = [
      MapEntry(FilterType.original, 'Original'),
      MapEntry(FilterType.grayscale, 'Grayscale'),
      MapEntry(FilterType.blackAndWhite, 'B&W'),
    ];

    return filters.map((filter) {
      final isSelected = _selectedFilter == filter.key;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedFilter = filter.key);
            _applyFilter(_scannedPages[_selectedPageIndex], filter.key);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? CupertinoColors.activeBlue
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                filter.value,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildBottomControls() {
    final bool showCameraControls = _scannedPages.isEmpty ||
        (_scanMode == ScanMode.batch && !_isReviewingBatch);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode switcher when no pages yet
          if (_scannedPages.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CupertinoSlidingSegmentedControl<ScanMode>(
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                thumbColor: CupertinoColors.activeBlue,
                groupValue: _scanMode,
                children: const {
                  ScanMode.document: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      'Document',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ScanMode.idCard: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      'ID Card',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ScanMode.batch: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      'Batch',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                },
                onValueChanged: (mode) {
                  if (mode != null) {
                    setState(() {
                      _scanMode = mode;
                      _idFrontPath = null;
                      _idBackPath = null;
                      _isIdCard = false;
                      _isReviewingBatch = false;
                    });
                  }
                },
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Gallery / Thumbnails
              SizedBox(
                width: 60,
                height: 60,
                child: !showCameraControls
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _addMorePage(false),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(
                              CupertinoIcons.photo,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : (_scannedPages.isEmpty
                        ? CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => _addMorePage(false),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(
                                  CupertinoIcons.photo,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              if (_scanMode == ScanMode.batch &&
                                  !_isReviewingBatch) {
                                setState(() => _isReviewingBatch = true);
                              }
                            },
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(_scannedPages.last),
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: CupertinoColors.activeBlue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${_scannedPages.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
              ),
              // Shutter Button
              GestureDetector(
                onTap: showCameraControls
                    ? (_isCapturing ? null : _captureImage)
                    : () {
                        // In review mode, resume camera scanning
                        setState(() {
                          _isReviewingBatch = false;
                          if (_scanMode != ScanMode.batch) {
                            _scanMode = ScanMode.batch;
                          }
                        });
                      },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isCapturing ? Colors.grey : Colors.white,
                      ),
                      child: !showCameraControls
                          ? const Icon(
                              CupertinoIcons.add,
                              size: 32,
                              color: Colors.black,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              // Delete / Retake
              SizedBox(
                width: 60,
                height: 60,
                child: _scannedPages.isNotEmpty && !showCameraControls
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            if (_scannedPages.isNotEmpty) {
                              final removed =
                                  _scannedPages.removeAt(_selectedPageIndex);
                              try {
                                final file = File(removed);
                                if (file.existsSync()) file.deleteSync();
                              } catch (_) {}
                              if (_selectedPageIndex >= _scannedPages.length) {
                                _selectedPageIndex = math.max(
                                  0,
                                  _scannedPages.length - 1,
                                );
                              }
                              if (_scannedPages.isEmpty) {
                                _isReviewingBatch = false;
                                _idFrontPath = null;
                                _idBackPath = null;
                                _isIdCard = false;
                              }
                            }
                          });
                        },
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.trash,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _captureImage() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isCapturing) {
      return;
    }
    try {
      setState(() => _isCapturing = true);
      _captureController.forward(from: 0.0);

      final XFile image = await _cameraController!.takePicture();
      final savedPath = await _saveImageToAppDir(image.path);

      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        _captureController.reset();

        if (_scanMode == ScanMode.idCard) {
          if (_idFrontPath == null) {
            // Front captured
            setState(() {
              _idFrontPath = savedPath;
              _isCapturing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Front side captured! Now align BACK of ID card.',
                ),
                duration: Duration(seconds: 2),
                backgroundColor: CupertinoColors.activeBlue,
              ),
            );
          } else {
            // Back captured
            setState(() {
              _idBackPath = savedPath;
              _isIdCard = true;
              _scannedPages.add(_idFrontPath!);
              _scannedPages.add(_idBackPath!);
              _selectedPageIndex = 0;
              _isCapturing = false;
            });
          }
        } else if (_scanMode == ScanMode.batch) {
          // Batch mode: add page and stay in camera mode
          setState(() {
            _scannedPages.add(savedPath);
            _selectedPageIndex = _scannedPages.length - 1;
            _isCapturing = false;
          });
        } else {
          // Standard single document scan: transition to preview
          setState(() {
            _scannedPages.add(savedPath);
            _selectedPageIndex = _scannedPages.length - 1;
            _isCapturing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isCapturing = false);
      debugPrint('Capture error: $e');
    }
  }

  Future<void> _addMorePage(bool fromCamera) async {
    try {
      final XFile? image = fromCamera
          ? await _picker.pickImage(source: ImageSource.camera)
          : await _picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        final savedPath = await _saveImageToAppDir(image.path);
        setState(() {
          _scannedPages.add(savedPath);
          _selectedPageIndex = _scannedPages.length - 1;
        });
      }
    } catch (e) {
      debugPrint('Pick image error: $e');
    }
  }

  Future<void> _applyFilter(String imagePath, FilterType filter) async {
    if (filter == FilterType.original) return;
    try {
      final imageService = ImageService();
      final filteredPath = await imageService.applyFilter(imagePath, filter);
      _scannedPages[_selectedPageIndex] = filteredPath;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Filter error: $e');
    }
  }

  Future<String> _saveImageToAppDir(String sourcePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${const Uuid().v4()}.jpg';
    final newPath = '${directory.path}/$fileName';
    await File(sourcePath).copy(newPath);
    return newPath;
  }

  Future<void> _saveDocument() async {
    if (_scannedPages.isEmpty) return;

    final now = DateTime.now();
    final defaultName = _isIdCard || _scanMode == ScanMode.idCard
        ? 'ID Card ${now.month}/${now.day}/${now.year}'
        : 'Scan ${now.month}/${now.day}/${now.year}';
    final defaultTags = _isIdCard || _scanMode == ScanMode.idCard
        ? [DocumentClassifierService.ids.id]
        : <String>[];

    final document = Document(
      id: const Uuid().v4(),
      name: defaultName,
      imagePaths: List.from(_scannedPages),
      tags: defaultTags,
      createdAt: now,
      updatedAt: now,
    );

    context.read<DocumentBloc>().add(AddDocument(document));

    await AdService.instance.showInterstitialAd();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(
          builder: (_) =>
              DocumentWorkspaceScreen(document: document, initialTabIndex: 0),
        ),
      );
    }
  }
}

class _CornerBracketPainter extends CustomPainter {
  final double opacity;

  _CornerBracketPainter({this.opacity = 0.6});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CupertinoColors.activeBlue.withValues(alpha: opacity)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const margin = 36.0;
    const bracketLength = 28.0;

    // Top-left
    canvas.drawLine(
      Offset(margin, margin + bracketLength),
      Offset(margin, margin),
      paint,
    );
    canvas.drawLine(
      Offset(margin, margin),
      Offset(margin + bracketLength, margin),
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(size.width - margin, margin + bracketLength),
      Offset(size.width - margin, margin),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - margin, margin),
      Offset(size.width - margin - bracketLength, margin),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(margin, size.height - margin - bracketLength),
      Offset(margin, size.height - margin),
      paint,
    );
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(margin + bracketLength, size.height - margin),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin - bracketLength),
      Offset(size.width - margin, size.height - margin),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin),
      Offset(size.width - margin - bracketLength, size.height - margin),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornerBracketPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
