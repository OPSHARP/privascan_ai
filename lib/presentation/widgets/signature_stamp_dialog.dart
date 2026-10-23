import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/services/vip_service.dart';
import '../screens/vip_pass_screen.dart';

class SignatureStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  const SignatureStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}

class SignatureStampResult {
  final Uint8List imageBytes;
  final String title;
  final bool isSignature;

  const SignatureStampResult({
    required this.imageBytes,
    required this.title,
    required this.isSignature,
  });

  Uint8List get bytes => imageBytes;
}

class SignatureStampDialog extends StatefulWidget {
  const SignatureStampDialog({super.key});

  /// Opens the dialog, automatically checking VIP status first.
  /// If user is not VIP, opens the VipPassScreen.
  static Future<SignatureStampResult?> show(BuildContext context) async {
    if (!VipService.instance.isVip) {
      final unlocked = await Navigator.push<bool>(
        context,
        CupertinoPageRoute(
          builder: (_) => const VipPassScreen(),
          fullscreenDialog: true,
        ),
      );
      if (unlocked != true && !VipService.instance.isVip) {
        return null;
      }
    }

    if (!context.mounted) return null;

    return showModalBottomSheet<SignatureStampResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SignatureStampDialog(),
    );
  }

  @override
  State<SignatureStampDialog> createState() => _SignatureStampDialogState();
}

class _SignatureStampDialogState extends State<SignatureStampDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Signature state
  final List<SignatureStroke> _strokes = [];
  List<Offset> _currentPoints = [];
  Color _selectedInkColor = const Color(0xFF0F172A); // Midnight Black
  final double _selectedStrokeWidth = 3.0;

  final List<Color> _inkColors = [
    const Color(0xFF0F172A), // Midnight Black
    const Color(0xFF1D4ED8), // Royal Ink Blue
    const Color(0xFFB91C1C), // Deep Red
    const Color(0xFF047857), // Forest Green
  ];

  // Stamp state
  String _selectedPreset = 'APPROVED';
  final TextEditingController _customStampController =
      TextEditingController(text: 'OFFICIALLY VERIFIED');
  Color _selectedStampColor = const Color(0xFF16A34A); // Green
  bool _includeDate = true;

  final List<Map<String, dynamic>> _stampPresets = [
    {
      'id': 'APPROVED',
      'label': 'APPROVED',
      'color': const Color(0xFF16A34A),
      'icon': CupertinoIcons.checkmark_seal_fill,
    },
    {
      'id': 'VERIFIED',
      'label': 'VERIFIED',
      'color': const Color(0xFF2563EB),
      'icon': CupertinoIcons.shield_lefthalf_fill,
    },
    {
      'id': 'CONFIDENTIAL',
      'label': 'CONFIDENTIAL',
      'color': const Color(0xFFDC2626),
      'icon': CupertinoIcons.lock_fill,
    },
    {
      'id': 'PAID',
      'label': 'PAID',
      'color': const Color(0xFF059669),
      'icon': CupertinoIcons.money_dollar_circle_fill,
    },
    {
      'id': 'CUSTOM',
      'label': 'CUSTOM',
      'color': const Color(0xFF7C3AED),
      'icon': CupertinoIcons.pencil_ellipsis_rectangle,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customStampController.dispose();
    super.dispose();
  }

  Future<void> _saveSignature() async {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw your signature first')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const canvasWidth = 500.0;
    const canvasHeight = 220.0;

    final painter = _SignaturePainter(strokes: _strokes, activePoints: const []);
    painter.paint(canvas, const Size(canvasWidth, canvasHeight));

    final picture = recorder.endRecording();
    final image = await picture.toImage(canvasWidth.toInt(), canvasHeight.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null && mounted) {
      Navigator.pop(
        context,
        SignatureStampResult(
          imageBytes: byteData.buffer.asUint8List(),
          title: 'Digital Signature',
          isSignature: true,
        ),
      );
    }
  }

  Future<void> _saveStamp() async {
    HapticFeedback.mediumImpact();
    final stampText = _selectedPreset == 'CUSTOM'
        ? _customStampController.text.trim().toUpperCase()
        : _selectedPreset;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const width = 320.0;
    const height = 140.0;

    final dateStr = _includeDate
        ? DateFormat('dd MMM yyyy').format(DateTime.now()).toUpperCase()
        : null;

    _paintOfficialStamp(
      canvas: canvas,
      size: const Size(width, height),
      text: stampText.isEmpty ? 'VERIFIED' : stampText,
      color: _selectedStampColor,
      dateString: dateStr,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null && mounted) {
      Navigator.pop(
        context,
        SignatureStampResult(
          imageBytes: byteData.buffer.asUint8List(),
          title: 'Official Stamp ($stampText)',
          isSignature: false,
        ),
      );
    }
  }

  void _paintOfficialStamp({
    required Canvas canvas,
    required Size size,
    required String text,
    required Color color,
    String? dateString,
  }) {
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final rect = Rect.fromLTWH(6, 6, size.width - 12, size.height - 12);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // Outer border
    canvas.drawRRect(rrect, borderPaint);

    // Inner thin border
    final innerRect = Rect.fromLTWH(12, 12, size.width - 24, size.height - 24);
    final innerRRect = RRect.fromRectAndRadius(innerRect, const Radius.circular(8));
    final innerPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(innerRRect, innerPaint);

    // Main stamp text
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width - 40);

    final textY = dateString != null
        ? (size.height / 2) - textPainter.height + 4
        : (size.height - textPainter.height) / 2;

    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, textY),
    );

    // Date and footer
    if (dateString != null) {
      final datePainter = TextPainter(
        text: TextSpan(
          text: '$dateString • PRIVASCAN AI',
          style: TextStyle(
            color: color.withValues(alpha: 0.85),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: size.width - 40);

      datePainter.paint(
        canvas,
        Offset((size.width - datePainter.width) / 2, textY + textPainter.height + 6),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 38,
            height: 4.5,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(CupertinoIcons.sparkles, color: Color(0xFF7C3AED), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'VIP Digital Stamp & Sign',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF22222E) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: const Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(CupertinoIcons.signature, size: 18),
                  text: 'Digital Signature',
                ),
                Tab(
                  icon: Icon(CupertinoIcons.checkmark_seal_fill, size: 18),
                  text: 'Official Stamp',
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSignatureTab(theme, isDark),
                _buildStampTab(theme, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureTab(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        children: [
          // Drawing Canvas
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _currentPoints = [details.localPosition];
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _currentPoints.add(details.localPosition);
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      if (_currentPoints.isNotEmpty) {
                        _strokes.add(
                          SignatureStroke(
                            points: List.from(_currentPoints),
                            color: _selectedInkColor,
                            strokeWidth: _selectedStrokeWidth,
                          ),
                        );
                        _currentPoints = [];
                      }
                    });
                  },
                  child: Stack(
                    children: [
                      CustomPaint(
                        painter: _SignaturePainter(
                          strokes: _strokes,
                          activePoints: _currentPoints,
                          activeColor: _selectedInkColor,
                          activeWidth: _selectedStrokeWidth,
                        ),
                        size: Size.infinite,
                      ),
                      if (_strokes.isEmpty && _currentPoints.isEmpty)
                        Center(
                          child: Text(
                            'Sign here with your finger',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Row(
                          children: [
                            if (_strokes.isNotEmpty)
                              IconButton(
                                icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 20),
                                onPressed: () {
                                  setState(() => _strokes.removeLast());
                                },
                                tooltip: 'Undo',
                              ),
                            IconButton(
                              icon: const Icon(CupertinoIcons.trash, color: CupertinoColors.destructiveRed, size: 20),
                              onPressed: () {
                                setState(() {
                                  _strokes.clear();
                                  _currentPoints.clear();
                                });
                              },
                              tooltip: 'Clear',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Ink Color Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ink Color:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Row(
                children: _inkColors.map((color) {
                  final isSelected = _selectedInkColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedInkColor = color),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                )
                              ]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _saveSignature,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.checkmark_alt, size: 18),
                  SizedBox(width: 8),
                  Text('Apply Digital Signature', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStampTab(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stamp Preview Card
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _selectedStampColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: _buildStampPreviewWidget(),
            ),
          ),
          const SizedBox(height: 16),

          // Preset Chips
          Text(
            'Select Stamp Type:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _stampPresets.map((preset) {
              final isSelected = _selectedPreset == preset['id'];
              final color = preset['color'] as Color;
              return ChoiceChip(
                label: Text(preset['label'] as String),
                selected: isSelected,
                avatar: Icon(
                  preset['icon'] as IconData,
                  size: 15,
                  color: isSelected ? Colors.white : color,
                ),
                selectedColor: color,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedPreset = preset['id'] as String;
                      _selectedStampColor = color;
                    });
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Custom Stamp Input (if custom selected)
          if (_selectedPreset == 'CUSTOM') ...[
            CupertinoTextField(
              controller: _customStampController,
              placeholder: 'Enter Custom Stamp Text (e.g. APPROVED BY DR.)',
              style: TextStyle(color: theme.colorScheme.onSurface),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF22222E) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
          ],

          // Toggle Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Include Today\'s Date & Seal',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              CupertinoSwitch(
                value: _includeDate,
                activeTrackColor: const Color(0xFF7C3AED),
                onChanged: (val) => setState(() => _includeDate = val),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedStampColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _saveStamp,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.checkmark_seal_fill, size: 18),
                  SizedBox(width: 8),
                  Text('Apply Official Stamp', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStampPreviewWidget() {
    final stampText = _selectedPreset == 'CUSTOM'
        ? _customStampController.text.trim().toUpperCase()
        : _selectedPreset;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _selectedStampColor, width: 2.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stampText.isEmpty ? 'VERIFIED' : stampText,
            style: TextStyle(
              color: _selectedStampColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          if (_includeDate) ...[
            const SizedBox(height: 3),
            Text(
              '${DateFormat('dd MMM yyyy').format(DateTime.now()).toUpperCase()} • PRIVASCAN AI',
              style: TextStyle(
                color: _selectedStampColor.withValues(alpha: 0.8),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<SignatureStroke> strokes;
  final List<Offset> activePoints;
  final Color? activeColor;
  final double? activeWidth;

  const _SignaturePainter({
    required this.strokes,
    required this.activePoints,
    this.activeColor,
    this.activeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length > 1) {
        final path = Path()..moveTo(stroke.points[0].dx, stroke.points[0].dy);
        for (var i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
        canvas.drawPath(path, paint);
      } else if (stroke.points.isNotEmpty) {
        canvas.drawCircle(stroke.points[0], stroke.strokeWidth / 2, paint);
      }
    }

    if (activePoints.isNotEmpty) {
      final paint = Paint()
        ..color = activeColor ?? const Color(0xFF0F172A)
        ..strokeWidth = activeWidth ?? 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (activePoints.length > 1) {
        final path = Path()..moveTo(activePoints[0].dx, activePoints[0].dy);
        for (var i = 1; i < activePoints.length; i++) {
          path.lineTo(activePoints[i].dx, activePoints[i].dy);
        }
        canvas.drawPath(path, paint);
      } else {
        canvas.drawCircle(activePoints[0], (activeWidth ?? 3.0) / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
