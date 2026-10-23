import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../data/services/image_service.dart';

class SignaturePlacementScreen extends StatefulWidget {
  final String pageImagePath;
  final Uint8List signatureBytes;
  final int pageNumber;
  final int totalPages;

  const SignaturePlacementScreen({
    super.key,
    required this.pageImagePath,
    required this.signatureBytes,
    required this.pageNumber,
    required this.totalPages,
  });

  @override
  State<SignaturePlacementScreen> createState() =>
      _SignaturePlacementScreenState();
}

class _SignaturePlacementScreenState extends State<SignaturePlacementScreen> {
  final ImageService _imageService = ImageService();

  Uint8List? _pageBytes;
  ui.Image? _pageImage;
  ui.Image? _sigImage;
  bool _isLoading = true;
  bool _isSaving = false;

  // Normalized coordinates relative to the underlying page image (0.0 to 1.0)
  double _relativeX = 0.55;
  double _relativeY = 0.75;
  double _relativeWidth = 0.35;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      final pageFile = File(widget.pageImagePath);
      final pBytes = await pageFile.readAsBytes();
      final pImg = await decodeImageFromList(pBytes);
      final sImg = await decodeImageFromList(widget.signatureBytes);

      if (mounted) {
        setState(() {
          _pageBytes = pBytes;
          _pageImage = pImg;
          _sigImage = sImg;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load images for signature placement: $e');
      if (mounted) Navigator.pop(context, false);
    }
  }

  double get _relativeHeight {
    if (_pageImage == null || _sigImage == null) return _relativeWidth;
    final sigAspect = _sigImage!.height / _sigImage!.width;
    final pageAspect = _pageImage!.height / _pageImage!.width;
    return (_relativeWidth * sigAspect) / pageAspect;
  }

  void _setSizePreset(double width) {
    setState(() {
      _relativeWidth = width;
      _relativeX = _relativeX.clamp(0.0, math.max(0.0, 1.0 - _relativeWidth));
      _relativeY = _relativeY.clamp(0.0, math.max(0.0, 1.0 - _relativeHeight));
    });
  }

  void _setAlignmentPreset({required double x, required double y}) {
    setState(() {
      _relativeX = x.clamp(0.0, math.max(0.0, 1.0 - _relativeWidth));
      _relativeY = y.clamp(0.0, math.max(0.0, 1.0 - _relativeHeight));
    });
  }

  Future<void> _applySignature() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await _imageService.stampOverlay(
        widget.pageImagePath,
        widget.signatureBytes,
        relativeX: _relativeX,
        relativeY: _relativeY,
        relativeWidth: _relativeWidth,
        relativeHeight: _relativeHeight,
      );

      // Invalidate image cache so the newly stamped file is immediately re-rendered
      PaintingBinding.instance.imageCache.evict(FileImage(File(widget.pageImagePath)));

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stamp signature: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return _buildCanvas(constraints);
                      },
                    ),
                  ),
                  _buildBottomControls(),
                ],
              ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Position Signature',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Page ${widget.pageNumber} of ${widget.totalPages}',
                style: const TextStyle(
                  color: CupertinoColors.activeBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: CupertinoColors.activeBlue,
            borderRadius: BorderRadius.circular(16),
            onPressed: _isSaving ? null : _applySignature,
            child: _isSaving
                ? const CupertinoActivityIndicator(radius: 10, color: Colors.white)
                : const Text(
                    'Apply',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas(BoxConstraints constraints) {
    if (_pageImage == null || _pageBytes == null) {
      return const SizedBox();
    }

    final pageImgW = _pageImage!.width.toDouble();
    final pageImgH = _pageImage!.height.toDouble();

    // Calculate BoxFit.contain dimensions
    final scale = math.min(
      constraints.maxWidth / pageImgW,
      constraints.maxHeight / pageImgH,
    );
    final renderedW = pageImgW * scale;
    final renderedH = pageImgH * scale;
    final offsetX = (constraints.maxWidth - renderedW) / 2;
    final offsetY = (constraints.maxHeight - renderedH) / 2;

    final sigRelH = _relativeHeight;
    final sigBoxW = _relativeWidth * renderedW;
    final sigBoxH = sigRelH * renderedH;
    final sigLeft = offsetX + (_relativeX * renderedW);
    final sigTop = offsetY + (_relativeY * renderedH);

    return Stack(
      children: [
        // Page Image
        Positioned(
          left: offsetX,
          top: offsetY,
          width: renderedW,
          height: renderedH,
          child: RepaintBoundary(
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.1),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Image.memory(
                _pageBytes!,
                fit: BoxFit.fill,
              ),
            ),
          ),
        ),

        // Interactive Signature Box
        Positioned(
          left: sigLeft,
          top: sigTop,
          width: sigBoxW,
          height: sigBoxH,
          child: RepaintBoundary(
            child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                final deltaRelX = details.delta.dx / renderedW;
                final deltaRelY = details.delta.dy / renderedH;
                _relativeX = (_relativeX + deltaRelX)
                    .clamp(0.0, math.max(0.0, 1.0 - _relativeWidth));
                _relativeY = (_relativeY + deltaRelY)
                    .clamp(0.0, math.max(0.0, 1.0 - sigRelH));
              });
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Dashed border & Signature Image
                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.activeBlue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: CupertinoColors.activeBlue,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Image.memory(
                      widget.signatureBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // Corner Resize Handle (Bottom-Right)
                Positioned(
                  right: -12,
                  bottom: -12,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        final deltaRelW = details.delta.dx / renderedW;
                        _relativeWidth = (_relativeWidth + deltaRelW)
                            .clamp(0.12, 0.85);
                        _relativeX = _relativeX.clamp(
                          0.0,
                          math.max(0.0, 1.0 - _relativeWidth),
                        );
                        _relativeY = _relativeY.clamp(
                          0.0,
                          math.max(0.0, 1.0 - _relativeHeight),
                        );
                      });
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: CupertinoColors.activeBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.arrow_up_left_arrow_down_right,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Size Presets
          Row(
            children: [
              const Text(
                'Size:',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              _buildPillButton(
                label: 'Small',
                isSelected: (_relativeWidth - 0.22).abs() < 0.05,
                onTap: () => _setSizePreset(0.22),
              ),
              const SizedBox(width: 6),
              _buildPillButton(
                label: 'Medium',
                isSelected: (_relativeWidth - 0.35).abs() < 0.05,
                onTap: () => _setSizePreset(0.35),
              ),
              const SizedBox(width: 6),
              _buildPillButton(
                label: 'Large',
                isSelected: (_relativeWidth - 0.50).abs() < 0.05,
                onTap: () => _setSizePreset(0.50),
              ),
              const Spacer(),
              // Quick Placement Presets
              _buildPillButton(
                label: 'Bottom Right',
                isSelected: false,
                onTap: () => _setAlignmentPreset(x: 0.60, y: 0.78),
              ),
              const SizedBox(width: 6),
              _buildPillButton(
                label: 'Center',
                isSelected: false,
                onTap: () => _setAlignmentPreset(x: 0.32, y: 0.45),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '💡 Drag signature to position • Drag blue corner handle to resize',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPillButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? CupertinoColors.activeBlue
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
