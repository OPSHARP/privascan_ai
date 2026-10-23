import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/services/document_classifier_service.dart';
import '../../data/services/image_service.dart';
import '../../data/services/ocr_service.dart';
import '../../domain/entities/document.dart';
import '../blocs/document_bloc.dart';
import '../widgets/floating_pill_nav_bar.dart';
import 'dashboard_screen.dart';
import 'document_workspace_screen.dart';
import 'scanner_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _openCameraScanner(BuildContext context, [ScanMode mode = ScanMode.document]) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => ScannerScreen(initialMode: mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Preserve tab states while switching
          IndexedStack(
            index: _currentIndex,
            children: [
              const DashboardScreen(embedded: true),
              _CameraHubPage(
                onLaunchScanner: (mode) => _openCameraScanner(context, mode),
              ),
            ],
          ),

          // Floating Pill Bottom Navigation Bar (exact match to reference image)
          FloatingPillNavBar(
            currentIndex: _currentIndex,
            onTabSelected: (index) {
              setState(() => _currentIndex = index);
            },
            onCameraTap: () {
              // Direct one-tap camera launch with haptic feedback
              setState(() => _currentIndex = 1);
              _openCameraScanner(context, ScanMode.document);
            },
          ),
        ],
      ),
    );
  }
}

/// Dedicated Camera Hub tab view when Camera is the active tab.
/// Provides instant access to live scanner and specialized capture modes.
class _CameraHubPage extends StatelessWidget {
  final ValueChanged<ScanMode> onLaunchScanner;

  const _CameraHubPage({required this.onLaunchScanner});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            backgroundColor: theme.scaffoldBackgroundColor.withValues(
              alpha: 0.85,
            ),
            surfaceTintColor: Colors.transparent,
            pinned: true,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
            title: Text(
              'Camera Scanner',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.35,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // Hero Camera Card with Glowing Aperture
                  GestureDetector(
                    onTap: () => onLaunchScanner(ScanMode.document),
                    child: Container(
                      width: double.infinity,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0F172A),
                            Color(0xFF1E293B),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF00E5FF).withValues(alpha: 0.25),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background Viewfinder Grid Lines
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ViewfinderOverlayPainter(),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF00E5FF)
                                      .withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: const Color(0xFF00E5FF),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00E5FF)
                                          .withValues(alpha: 0.45),
                                      blurRadius: 18,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  CupertinoIcons.camera_fill,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Open Live Camera Scanner',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Auto Edge-Detect • Instant ML Filters • On-Device OCR',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Quick Mode Selectors
                  Row(
                    children: [
                      Text(
                        'CAPTURE MODES',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildModeTile(
                    theme: theme,
                    isDark: isDark,
                    title: 'Standard Document',
                    subtitle: 'Single page document, invoice, receipt, or notes',
                    icon: CupertinoIcons.doc_text,
                    color: const Color(0xFF007AFF),
                    onTap: () => onLaunchScanner(ScanMode.document),
                  ),
                  const SizedBox(height: 10),
                  _buildModeTile(
                    theme: theme,
                    isDark: isDark,
                    title: 'ID Card & Passport',
                    subtitle: 'Front and back side 2-in-1 merged page',
                    icon: CupertinoIcons.person_crop_rectangle,
                    color: const Color(0xFF5856D6),
                    onTap: () => onLaunchScanner(ScanMode.idCard),
                  ),
                  const SizedBox(height: 10),
                  _buildModeTile(
                    theme: theme,
                    isDark: isDark,
                    title: 'Batch Multi-Page Scanner',
                    subtitle: 'Rapid continuous capture with multi-page export',
                    icon: CupertinoIcons.square_stack_3d_up_fill,
                    color: const Color(0xFF34C759),
                    onTap: () => onLaunchScanner(ScanMode.batch),
                  ),
                  const SizedBox(height: 10),
                  _buildModeTile(
                    theme: theme,
                    isDark: isDark,
                    title: 'Import from Gallery',
                    subtitle: 'Pick existing photo or PDF from device storage',
                    icon: CupertinoIcons.photo_on_rectangle,
                    color: const Color(0xFFFF9500),
                    onTap: () => _importImage(context),
                  ),
                ],
              ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.only(bottom: 110),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTile({
    required ThemeData theme,
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importImage(BuildContext context) async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null || !context.mounted) return;

      final processed = await ImageService().applyFilter(
        picked.path,
        FilterType.magicColor,
      );
      final ocrService = OcrService();
      final ocrText = await ocrService.extractText(processed);
      ocrService.dispose();
      final classification = DocumentClassifierService.classify(text: ocrText);

      final doc = Document(
        id: const Uuid().v4(),
        name: 'Scan ${DateTime.now().month}-${DateTime.now().day}',
        imagePaths: [processed],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        extractedText: ocrText,
        tags: [classification.id],
      );

      if (!context.mounted) return;
      context.read<DocumentBloc>().add(AddDocument(doc));

      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => DocumentWorkspaceScreen(document: doc),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import error: $e')),
      );
    }
  }
}

class _ViewfinderOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const cornerLength = 20.0;
    const padding = 16.0;

    final left = padding;
    final top = padding;
    final right = size.width - padding;
    final bottom = size.height - padding;

    // Top-left corner
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left, top + cornerLength), paint);

    // Top-right corner
    canvas.drawLine(Offset(right, top), Offset(right - cornerLength, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLength), paint);

    // Bottom-left corner
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLength, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left, bottom - cornerLength), paint);

    // Bottom-right corner
    canvas.drawLine(Offset(right, bottom), Offset(right - cornerLength, bottom), paint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
