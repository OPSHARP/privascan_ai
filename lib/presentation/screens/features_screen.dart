import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/document_repository_impl.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/document_classifier_service.dart';
import '../../data/services/image_service.dart';
import '../../data/services/ocr_service.dart';
import '../../data/services/table_detection_service.dart';
import '../../data/services/translation_service.dart';
import '../../data/services/tts_service.dart';
import '../../domain/entities/document.dart';
import '../blocs/document_bloc.dart';
import 'scanner_screen.dart';
import 'document_workspace_screen.dart';
import 'settings_screen.dart';

class FeaturesScreen extends StatefulWidget {
  const FeaturesScreen({super.key});

  @override
  State<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends State<FeaturesScreen> {
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();
  final ImageService _imageService = ImageService();

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Sleek Large App Bar
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
              'Features',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.35,
                color: theme.colorScheme.onSurface,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  CupertinoIcons.settings,
                  color: theme.colorScheme.primary,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                tooltip: 'Settings',
              ),
            ],
          ),

          // 100% Offline Privacy Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: _buildPrivacyBanner(theme, isDark),
            ),
          ),

          // Section 1: Capture & Scan Modes
          SliverToBoxAdapter(
            child: _buildSectionHeader(theme, 'SCAN & CAPTURE MODES'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
              ),
              delegate: SliverChildListDelegate([
                _buildFeatureCard(
                  theme: theme,
                  isDark: isDark,
                  title: 'Document Scan',
                  subtitle: 'Auto-crop & contrast',
                  icon: CupertinoIcons.doc_text_viewfinder,
                  accentColor: const Color(0xFF007AFF),
                  badge: 'Standard',
                  onTap: () => _openScanner(context, ScanMode.document),
                ),
                _buildFeatureCard(
                  theme: theme,
                  isDark: isDark,
                  title: 'ID Card / Passport',
                  subtitle: 'Dual-side combo',
                  icon: CupertinoIcons.person_crop_rectangle,
                  accentColor: const Color(0xFF5856D6),
                  badge: '2-in-1',
                  onTap: () => _openScanner(context, ScanMode.idCard),
                ),
                _buildFeatureCard(
                  theme: theme,
                  isDark: isDark,
                  title: 'Batch Scanner',
                  subtitle: 'Rapid multi-page',
                  icon: CupertinoIcons.square_stack_3d_up_fill,
                  accentColor: const Color(0xFF34C759),
                  badge: 'Fast',
                  onTap: () => _openScanner(context, ScanMode.batch),
                ),
                _buildFeatureCard(
                  theme: theme,
                  isDark: isDark,
                  title: 'Gallery Import',
                  subtitle: 'Convert photo to scan',
                  icon: CupertinoIcons.photo_on_rectangle,
                  accentColor: const Color(0xFFFF9500),
                  badge: 'Import',
                  onTap: _importFromGallery,
                ),
              ]),
            ),
          ),

          // Section 2: AI & On-Device Intelligence
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _buildSectionHeader(theme, 'ON-DEVICE AI TOOLS'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildListToolTile(
                  theme: theme,
                  isDark: isDark,
                  title: 'Smart OCR & Text Extractor',
                  description:
                      'Recognize & copy all text from any photo or document offline.',
                  icon: CupertinoIcons.viewfinder,
                  iconColor: const Color(0xFF00C7BE),
                  actionLabel: 'Extract Text',
                  onTap: () => _showQuickOcrTool(context),
                ),
                const SizedBox(height: 10),
                _buildListToolTile(
                  theme: theme,
                  isDark: isDark,
                  title: 'Table & Spreadsheet Extractor',
                  description:
                      'Extract receipt & invoice line items into clean CSV format.',
                  icon: CupertinoIcons.table,
                  iconColor: const Color(0xFF30B0C7),
                  actionLabel: 'Extract Table',
                  onTap: _showTableExtractorTool,
                ),
                const SizedBox(height: 10),
                _buildListToolTile(
                  theme: theme,
                  isDark: isDark,
                  title: 'Offline Translation',
                  description:
                      'Translate document text into 50+ languages with zero internet.',
                  icon: CupertinoIcons.globe,
                  iconColor: const Color(0xFF5856D6),
                  actionLabel: 'Translate',
                  onTap: () => _showTranslatorTool(context),
                ),
                const SizedBox(height: 10),
                _buildListToolTile(
                  theme: theme,
                  isDark: isDark,
                  title: 'Audio Document Reader (TTS)',
                  description:
                      'Listen to scanned pages spoken out loud with natural voice.',
                  icon: CupertinoIcons.speaker_2_fill,
                  iconColor: const Color(0xFFFF2D55),
                  actionLabel: 'Listen',
                  onTap: () => _showAudioReaderTool(context),
                ),
              ]),
            ),
          ),

          // Section 3: PDF & Security Tools
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _buildSectionHeader(theme, 'PDF & DATA VAULT'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildListToolTile(
                  theme: theme,
                  isDark: isDark,
                  title: 'Export Encrypted Backup',
                  description:
                      'Create a secure .privascan archive of all scans and tags.',
                  icon: CupertinoIcons.arrow_up_doc_fill,
                  iconColor: const Color(0xFF34C759),
                  actionLabel: 'Export',
                  onTap: _exportOfflineBackup,
                ),
                const SizedBox(height: 10),
                _buildListToolTile(
                  theme: theme,
                  isDark: isDark,
                  title: 'Restore from Backup',
                  description:
                      'Safely restore documents and tags from a .privascan file.',
                  icon: CupertinoIcons.arrow_down_doc_fill,
                  iconColor: const Color(0xFF007AFF),
                  actionLabel: 'Restore',
                  onTap: _restoreOfflineBackup,
                ),
                const SizedBox(height: 10),
                _buildListToolTile(
                  theme: theme,
                  isDark: isDark,
                  title: 'Recycle Bin & Recovery',
                  description:
                      'Recover deleted documents or purge items after 30 days.',
                  icon: CupertinoIcons.trash_fill,
                  iconColor: const Color(0xFFFF3B30),
                  actionLabel: 'Open Trash',
                  onTap: () => _openTrash(context),
                ),
              ]),
            ),
          ),

          // Clearance for floating bottom navigation bar
          const SliverPadding(
            padding: EdgeInsets.only(bottom: 110),
          ),
        ],
      ),
    );
  }

  // --- Sub-widgets & UI Helpers ---

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildPrivacyBanner(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF0B291A),
                  const Color(0xFF081C12),
                ]
              : [
                  const Color(0xFFE8F8EE),
                  const Color(0xFFD6F3E0),
                ],
        ),
        border: Border.all(
          color: const Color(0xFF34C759).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF34C759).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF34C759).withValues(alpha: 0.2),
            ),
            child: const Icon(
              CupertinoIcons.shield_lefthalf_fill,
              color: Color(0xFF34C759),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '100% Offline Engine',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF34C759),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF34C759),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'No scans or text ever leave your device. Zero cloud uploads.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required ThemeData theme,
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String badge,
    required VoidCallback onTap,
  }) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            Column(
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
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListToolTile({
    required ThemeData theme,
    required bool isDark,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
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
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
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
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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

  // --- Real Interactive Actions ---

  void _openScanner(BuildContext context, ScanMode mode) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => ScannerScreen(initialMode: mode),
      ),
    );
  }

  Future<void> _importFromGallery() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;

      final processed = await _imageService.applyFilter(
        picked.path,
        FilterType.magicColor,
      );
      final ocrText = await _ocrService.extractText(processed);
      final classification = DocumentClassifierService.classify(
        text: ocrText,
      );

      final doc = Document(
        id: const Uuid().v4(),
        name: 'Import ${DateTime.now().month}-${DateTime.now().day}',
        imagePaths: [processed],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        extractedText: ocrText,
        tags: [classification.id],
      );

      if (!mounted) return;
      context.read<DocumentBloc>().add(AddDocument(doc));

      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => DocumentWorkspaceScreen(document: doc),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import error: $e')),
      );
    }
  }

  void _showQuickOcrTool(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Smart OCR & Text Extractor'),
        message: const Text(
          'Select a document or pick a new photo to extract all text on-device.',
        ),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Pick Image from Gallery'),
            onPressed: () async {
              Navigator.pop(ctx);
              final picked =
                  await _picker.pickImage(source: ImageSource.gallery);
              if (picked == null || !mounted) return;

              final text = await _ocrService.extractText(picked.path);
              if (!mounted) return;
              _showExtractedTextDialog(text);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Capture with Camera'),
            onPressed: () {
              Navigator.pop(ctx);
              _openScanner(context, ScanMode.document);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _showExtractedTextDialog(String text) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Extracted OCR Text'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SizedBox(
            height: 220,
            child: SingleChildScrollView(
              child: SelectableText(
                text.trim().isEmpty ? 'No text detected in this image.' : text,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Copy All'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Text copied to clipboard!')),
              );
            },
          ),
          CupertinoDialogAction(
            child: const Text('Done'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showTableExtractorTool() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Table & Spreadsheet Extractor'),
        message: const Text(
          'Detect and export structured tables from invoices and receipts.',
        ),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Pick Receipt / Table Image'),
            onPressed: () async {
              Navigator.pop(ctx);
              final picked =
                  await _picker.pickImage(source: ImageSource.gallery);
              if (picked == null || !mounted) return;

              final ocrText = await _ocrService.extractText(picked.path);
              final tableDetector = TableDetectionService();
              final tableResult = tableDetector.detectTable(ocrText);

              if (!mounted) return;
              showCupertinoDialog(
                context: context,
                builder: (dCtx) => CupertinoAlertDialog(
                  title: const Text('Extracted Table Data'),
                  content: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Detected ${tableResult.rows.length} rows.\n\n'
                      '${tableResult.csvContent}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('Copy CSV'),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: tableResult.csvContent),
                        );
                        Navigator.pop(dCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('CSV copied to clipboard!'),
                          ),
                        );
                      },
                    ),
                    CupertinoDialogAction(
                      child: const Text('Done'),
                      onPressed: () => Navigator.pop(dCtx),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _showTranslatorTool(BuildContext context) {
    final controller = TextEditingController(
      text: 'PrivaScan AI keeps all documents encrypted on your device.',
    );

    showCupertinoDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: const Text('Offline Translation'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoTextField(
                  controller: controller,
                  placeholder: 'Enter text to translate...',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Target: ', style: TextStyle(fontSize: 12)),
                    Text(
                      'Spanish',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(ctx),
            ),
            CupertinoDialogAction(
              child: const Text('Translate'),
              onPressed: () async {
                final service = TranslationService();
                final result = await service.translateText(
                  controller.text,
                  TranslateLanguage.english,
                  TranslateLanguage.spanish,
                );
                if (!context.mounted) return;
                Navigator.pop(ctx);
                showCupertinoDialog(
                  context: context,
                  builder: (rCtx) => CupertinoAlertDialog(
                    title: const Text('Translation Result (Spanish)'),
                    content: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(result),
                    ),
                    actions: [
                      CupertinoDialogAction(
                        child: const Text('Copy'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: result));
                          Navigator.pop(rCtx);
                        },
                      ),
                      CupertinoDialogAction(
                        child: const Text('OK'),
                        onPressed: () => Navigator.pop(rCtx),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAudioReaderTool(BuildContext context) {
    final controller = TextEditingController(
      text: 'Welcome to PrivaScan AI. All your documents are processed 100% locally on your phone.',
    );

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Audio Document Reader'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: controller,
                placeholder: 'Enter text to listen...',
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Stop'),
            onPressed: () {
              TtsService.instance.stop();
              Navigator.pop(ctx);
            },
          ),
          CupertinoDialogAction(
            child: const Text('Play Audio'),
            onPressed: () {
              TtsService.instance.speak(controller.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Playing audio locally...')),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _exportOfflineBackup() async {
    try {
      final repository = context.read<DocumentRepositoryImpl>();
      final backupService = BackupService(repository);
      final result = await backupService.createBackup();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup error: $e')),
      );
    }
  }

  Future<void> _restoreOfflineBackup() async {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'Select a .privascan backup archive to restore your documents and tags.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            child: const Text('Select File'),
            onPressed: () async {
              Navigator.pop(ctx);
              final repository = context.read<DocumentRepositoryImpl>();
              final backupService = BackupService(repository);
              final result = await backupService.restoreBackup();

              if (!mounted) return;
              if (result.success) {
                context.read<DocumentBloc>().add(LoadDocuments());
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.message)),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openTrash(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Open Home tab and select Trash from the category filter.'),
      ),
    );
  }
}
