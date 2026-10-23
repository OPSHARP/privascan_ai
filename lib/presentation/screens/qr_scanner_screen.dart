import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/barcode_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCameraError = false;
  bool _isFlashOn = false;
  bool _useFrontCamera = false;
  bool _isProcessing = false;

  final BarcodeService _barcodeService = BarcodeService();
  final ImagePicker _picker = ImagePicker();

  late final AnimationController _laserController;
  late final Animation<double> _laserPosition;
  Timer? _scanTimer;

  DetectedBarcode? _currentResult;
  final List<DetectedBarcode> _scanHistory = [];

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _laserPosition = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );

    _initCamera();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _laserController.dispose();
    _cameraController?.dispose();
    _barcodeService.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        final camera = _cameras![_useFrontCamera ? 1 : 0];
        _cameraController = CameraController(
          camera,
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
          _isCameraError = false;
        });

        _startAutoScanLoop();
      } else {
        if (mounted) setState(() => _isCameraError = true);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) setState(() => _isCameraError = true);
    }
  }

  void _startAutoScanLoop() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 750), (timer) async {
      if (!mounted ||
          _cameraController == null ||
          !_cameraController!.value.isInitialized ||
          _isProcessing ||
          _currentResult != null) {
        return;
      }

      await _captureAndScanFrame();
    });
  }

  Future<void> _captureAndScanFrame() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final xFile = await _cameraController!.takePicture();
      final barcodes = await _barcodeService.scanImage(xFile.path);

      // Clean up temporary snapshot
      try {
        final f = File(xFile.path);
        if (await f.exists()) await f.delete();
      } catch (_) {}

      if (barcodes.isNotEmpty && mounted) {
        final code = barcodes.first;
        HapticFeedback.heavyImpact();
        setState(() {
          _currentResult = code;
          if (!_scanHistory.any((b) => b.rawValue == code.rawValue)) {
            _scanHistory.insert(0, code);
          }
        });
        _showResultSheet(code);
      }
    } catch (_) {
      // Ignored for continuous scanning frames
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    HapticFeedback.lightImpact();
    try {
      final newMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newMode);
      setState(() => _isFlashOn = !_isFlashOn);
    } catch (_) {}
  }

  Future<void> _flipCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    HapticFeedback.mediumImpact();
    _scanTimer?.cancel();
    _useFrontCamera = !_useFrontCamera;
    await _cameraController?.dispose();
    await _initCamera();
  }

  Future<void> _scanFromGallery() async {
    HapticFeedback.lightImpact();
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;

      setState(() => _isProcessing = true);
      final barcodes = await _barcodeService.scanImage(picked.path);
      setState(() => _isProcessing = false);

      if (!mounted) return;

      if (barcodes.isEmpty) {
        showCupertinoDialog(
          context: context,
          builder: (dCtx) => CupertinoAlertDialog(
            title: const Text('No Code Found'),
            content: const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No QR code or barcode was detected in the chosen image.'),
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(dCtx),
              ),
            ],
          ),
        );
      } else {
        final code = barcodes.first;
        HapticFeedback.heavyImpact();
        setState(() {
          _currentResult = code;
          if (!_scanHistory.any((b) => b.rawValue == code.rawValue)) {
            _scanHistory.insert(0, code);
          }
        });
        _showResultSheet(code);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
    }
  }

  void _showResultSheet(DetectedBarcode code) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pull notch
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Format Header Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.barcode_viewfinder,
                          size: 16,
                          color: Color(0xFF6366F1),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          code.formatLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(sheetCtx),
                    child: const Icon(CupertinoIcons.xmark_circle_fill, size: 24, color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Code Value Display
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: SelectableText(
                  code.rawValue,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Contextual Primary Action Button
              if (code.isUrl)
                _buildActionButton(
                  icon: CupertinoIcons.globe,
                  label: 'Open in Web Browser',
                  color: const Color(0xFF2563EB),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final uri = Uri.tryParse(code.rawValue);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                )
              else if (code.isUpi)
                _buildActionButton(
                  icon: CupertinoIcons.money_dollar_circle_fill,
                  label: 'Pay via UPI App',
                  color: const Color(0xFF10B981),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final uri = Uri.tryParse(code.rawValue);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                )
              else if (code.isEmail)
                _buildActionButton(
                  icon: CupertinoIcons.mail_solid,
                  label: 'Send Email',
                  color: const Color(0xFF8B5CF6),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final uri = Uri.tryParse(
                      code.rawValue.startsWith('mailto:') ? code.rawValue : 'mailto:${code.rawValue}',
                    );
                    if (uri != null) await launchUrl(uri);
                  },
                )
              else if (code.isPhone)
                _buildActionButton(
                  icon: CupertinoIcons.phone_fill,
                  label: 'Call Number',
                  color: const Color(0xFF059669),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final uri = Uri.tryParse(
                      code.rawValue.startsWith('tel:') ? code.rawValue : 'tel:${code.rawValue}',
                    );
                    if (uri != null) await launchUrl(uri);
                  },
                )
              else
                _buildActionButton(
                  icon: CupertinoIcons.search,
                  label: 'Search on Web',
                  color: const Color(0xFF2563EB),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final query = Uri.encodeComponent(code.rawValue);
                    final uri = Uri.tryParse('https://www.google.com/search?q=$query');
                    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),

              const SizedBox(height: 12),

              // Secondary Actions (Copy & Share)
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code.rawValue));
                        Navigator.pop(sheetCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.doc_on_doc,
                            size: 18,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Copy Text',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        SharePlus.instance.share(
                          ShareParams(
                            text: code.rawValue,
                            subject: 'Scanned ${code.formatLabel}',
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.share,
                            size: 18,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Share',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Scan Next Button
              CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 14),
                borderRadius: BorderRadius.circular(16),
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  setState(() => _currentResult = null);
                },
                child: const Text(
                  'Scan Another Code',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() => _currentResult = null);
      }
    });
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Scans',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  if (_scanHistory.isNotEmpty)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('Clear', style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        setState(() => _scanHistory.clear());
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _scanHistory.isEmpty
                    ? const Center(
                        child: Text(
                          'No codes scanned yet in this session.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _scanHistory.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _scanHistory[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.barcode_viewfinder,
                                color: Color(0xFF6366F1),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              item.rawValue,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text(
                              item.formatLabel,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                            onTap: () {
                              Navigator.pop(ctx);
                              _showResultSheet(item);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final boxSize = math.min(size.width * 0.72, 280.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          if (_isInitialized && _cameraController != null)
            CameraPreview(_cameraController!)
          else if (_isCameraError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.camera, size: 54, color: Colors.white54),
                    const SizedBox(height: 16),
                    const Text(
                      'Camera Unavailable',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You can still pick and scan images directly from your photo gallery.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    CupertinoButton(
                      color: CupertinoColors.activeBlue,
                      borderRadius: BorderRadius.circular(20),
                      onPressed: _scanFromGallery,
                      child: const Text('Pick Image from Gallery'),
                    ),
                  ],
                ),
              ),
            )
          else
            const Center(
              child: CupertinoActivityIndicator(color: Colors.white, radius: 16),
            ),

          // Dark overlay with cut-out viewfinder
          CustomPaint(
            size: size,
            painter: _ViewfinderOverlayPainter(
              boxSize: boxSize,
              centerOffset: Offset(size.width / 2, size.height * 0.44),
            ),
          ),

          // Viewfinder Target Frame with animated laser scan bar
          Positioned(
            top: (size.height * 0.44) - (boxSize / 2),
            left: (size.width - boxSize) / 2,
            width: boxSize,
            height: boxSize,
            child: Stack(
              children: [
                // Corner Brackets
                CustomPaint(
                  size: Size(boxSize, boxSize),
                  painter: _CornerBracketPainter(color: const Color(0xFF6366F1)),
                ),

                // Animated Laser Scan Bar
                AnimatedBuilder(
                  animation: _laserPosition,
                  builder: (context, _) {
                    return Positioned(
                      top: boxSize * _laserPosition.value,
                      left: 8,
                      right: 8,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0xFF6366F1),
                              Color(0xFF38BDF8),
                              Color(0xFF6366F1),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.8),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Top Navigation & Action Bar
          Positioned(
            top: topPadding + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                _buildCircleIconButton(
                  icon: CupertinoIcons.xmark,
                  onPressed: () => Navigator.pop(context),
                ),

                // Title
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.barcode_viewfinder, color: Color(0xFF6366F1), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'QR & Barcode Scanner',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // History button
                _buildCircleIconButton(
                  icon: CupertinoIcons.clock,
                  onPressed: _showHistorySheet,
                ),
              ],
            ),
          ),

          // Bottom Control Floating Pill (Gallery, Flash, Flip)
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Gallery Pick
                  _buildBottomActionItem(
                    icon: CupertinoIcons.photo_on_rectangle,
                    label: 'Gallery',
                    onTap: _scanFromGallery,
                  ),

                  // Flash Toggle
                  _buildBottomActionItem(
                    icon: _isFlashOn ? CupertinoIcons.bolt_fill : CupertinoIcons.bolt_slash_fill,
                    label: _isFlashOn ? 'Flash On' : 'Flash Off',
                    accentColor: _isFlashOn ? const Color(0xFFFBBF24) : null,
                    onTap: _toggleFlash,
                  ),

                  // Flip Camera
                  _buildBottomActionItem(
                    icon: CupertinoIcons.camera_rotate,
                    label: 'Flip',
                    onTap: _flipCamera,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildBottomActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accentColor ?? Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: accentColor ?? Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewfinderOverlayPainter extends CustomPainter {
  final double boxSize;
  final Offset centerOffset;

  _ViewfinderOverlayPainter({
    required this.boxSize,
    required this.centerOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final rect = Rect.fromCenter(
      center: centerOffset,
      width: boxSize,
      height: boxSize,
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CornerBracketPainter extends CustomPainter {
  final Color color;

  _CornerBracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 26.0;
    const radius = 16.0;

    // Top-Left
    final tl = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, radius)
      ..arcToPoint(const Offset(radius, 0), radius: const Radius.circular(radius))
      ..lineTo(cornerLength, 0);
    canvas.drawPath(tl, paint);

    // Top-Right
    final tr = Path()
      ..moveTo(size.width - cornerLength, 0)
      ..lineTo(size.width - radius, 0)
      ..arcToPoint(Offset(size.width, radius), radius: const Radius.circular(radius))
      ..lineTo(size.width, cornerLength);
    canvas.drawPath(tr, paint);

    // Bottom-Left
    final bl = Path()
      ..moveTo(0, size.height - cornerLength)
      ..lineTo(0, size.height - radius)
      ..arcToPoint(Offset(radius, size.height), radius: const Radius.circular(radius))
      ..lineTo(cornerLength, size.height);
    canvas.drawPath(bl, paint);

    // Bottom-Right
    final br = Path()
      ..moveTo(size.width - cornerLength, size.height)
      ..lineTo(size.width - radius, size.height)
      ..arcToPoint(Offset(size.width, size.height - radius), radius: const Radius.circular(radius))
      ..lineTo(size.width, size.height - cornerLength);
    canvas.drawPath(br, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
