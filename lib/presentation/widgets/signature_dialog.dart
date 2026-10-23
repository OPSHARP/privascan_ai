import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../data/services/signature_service.dart';

class SignatureDialog extends StatefulWidget {
  const SignatureDialog({super.key});

  static Future<Uint8List?> show(BuildContext context) {
    return showCupertinoModalPopup<Uint8List>(
      context: context,
      builder: (_) => const SignatureDialog(),
    );
  }

  @override
  State<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  _SignatureStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}

class _SignatureDialogState extends State<SignatureDialog> {
  final List<_SignatureStroke> _strokes = [];
  _SignatureStroke? _currentStroke;

  Color _selectedColor = const Color(0xFF1E3A8A); // Classic pen blue
  double _strokeWidth = 3.5;
  bool _saveToLibrary = true;

  final List<Color> _availableColors = const [
    Color(0xFF1E3A8A), // Classic Blue
    Color(0xFF0F172A), // Jet Black
    Color(0xFFDC2626), // Crimson Red
    Color(0xFF15803D), // Forest Green
  ];

  Future<Uint8List?> _renderSignatureToBytes() async {
    if (_strokes.isEmpty) return null;

    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final stroke in _strokes) {
      for (final p in stroke.points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
    }

    if (minX == double.infinity) return null;

    const pad = 16.0;
    final contentW = math.max(60.0, (maxX - minX) + (pad * 2));
    final contentH = math.max(30.0, (maxY - minY) + (pad * 2));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(-minX + pad, -minY + pad);

    for (final stroke in _strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.strokeWidth * 1.5
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      contentW.toInt(),
      contentH.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();

    if (bytes != null && _saveToLibrary) {
      try {
        await SignatureService.instance.saveSignature(bytes);
      } catch (_) {}
    }

    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 520,
      margin: const EdgeInsets.only(top: 40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Text(
                    'Draw Signature',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _strokes.isEmpty
                        ? null
                        : () async {
                            final navigator = Navigator.of(context);
                            final bytes = await _renderSignatureToBytes();
                            if (mounted) navigator.pop(bytes);
                          },
                    child: const Text(
                      'Use',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Drawing Canvas Area
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      // Guide watermark
                      Center(
                        child: Text(
                          'Sign here with finger or stylus',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.15),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onPanStart: (details) {
                          setState(() {
                            _currentStroke = _SignatureStroke(
                              points: [details.localPosition],
                              color: _selectedColor,
                              strokeWidth: _strokeWidth,
                            );
                            _strokes.add(_currentStroke!);
                          });
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            _currentStroke?.points.add(details.localPosition);
                          });
                        },
                        child: CustomPaint(
                          painter: _SignaturePainter(strokes: _strokes),
                          size: Size.infinite,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Pen tools: Colors, Width, Undo, Clear
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Pen colors
                  ..._availableColors.map((color) {
                    final isSelected = _selectedColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? CupertinoColors.activeBlue
                                : Colors.white,
                            width: isSelected ? 3 : 1.5,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),

                  // Stroke width selectors
                  ...[
                    (2.0, 4.0),
                    (3.5, 7.0),
                    (5.5, 10.0),
                  ].map((pair) {
                    final isSelected = _strokeWidth == pair.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _strokeWidth = pair.$1),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? CupertinoColors.activeBlue.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? CupertinoColors.activeBlue
                                : Colors.black12,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: pair.$2,
                            height: pair.$2,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? CupertinoColors.activeBlue
                                  : (isDark ? Colors.white60 : Colors.black54),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  const Spacer(),
                  // Undo
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: _strokes.isEmpty
                        ? null
                        : () => setState(() => _strokes.removeLast()),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.arrow_uturn_left, size: 16),
                        SizedBox(width: 4),
                        Text('Undo', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  // Clear
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: _strokes.isEmpty
                        ? null
                        : () => setState(() => _strokes.clear()),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.trash,
                            size: 16, color: CupertinoColors.destructiveRed),
                        SizedBox(width: 4),
                        Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.destructiveRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Save to Library switch
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  CupertinoSwitch(
                    value: _saveToLibrary,
                    onChanged: (val) => setState(() => _saveToLibrary = val),
                    activeTrackColor: CupertinoColors.activeGreen,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Save to Signature Library for 1-tap reuse',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<_SignatureStroke> strokes;

  _SignaturePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.strokeWidth
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
