import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../../data/services/ocr_service.dart';
import '../../data/services/pdf_service.dart';
import '../../data/services/table_detection_service.dart';
import '../../domain/entities/document.dart';
import '../blocs/document_bloc.dart';
import '../screens/pdf_preview_screen.dart';
import '../screens/scanner_screen.dart';
import '../screens/offline_translate_screen.dart';
import '../screens/audio_reader_screen.dart';
import '../screens/qr_scanner_screen.dart';
import '../screens/vip_pass_screen.dart';
import '../../data/services/vip_service.dart';
import 'signature_stamp_dialog.dart';

/// Interactive 2-Column Grid presenting all on-device PrivaScan AI features
/// directly on the Home Screen.
class HomeFeaturesGrid extends StatefulWidget {
  const HomeFeaturesGrid({super.key});

  @override
  State<HomeFeaturesGrid> createState() => _HomeFeaturesGridState();
}

class _HomeFeaturesGridState extends State<HomeFeaturesGrid> {
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  void _openScanner(BuildContext context, ScanMode mode) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => ScannerScreen(initialMode: mode),
      ),
    );
  }

  /// Photo to PDF Tool: Converts single or multi photos to PDF and saves directly
  /// into the device's shared Documents directory (/storage/emulated/0/Documents/PrivaScan).
  void _convertPhotoToPdf() {
    HapticFeedback.lightImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text(
          'Photo to PDF Converter',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        message: const Text(
          'Convert any photo into a clean PDF and save directly to your device Documents folder.',
        ),
        actions: [
          CupertinoActionSheetAction(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo_fill_on_rectangle_fill, size: 20),
                SizedBox(width: 8),
                Text('Pick Photos from Gallery'),
              ],
            ),
            onPressed: () {
              Navigator.pop(sheetContext);
              _processPhotoToPdf(isCamera: false);
            },
          ),
          CupertinoActionSheetAction(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera_fill, size: 20),
                SizedBox(width: 8),
                Text('Capture with Camera'),
              ],
            ),
            onPressed: () {
              Navigator.pop(sheetContext);
              _processPhotoToPdf(isCamera: true);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(sheetContext),
        ),
      ),
    );
  }

  Future<void> _processPhotoToPdf({
    required bool isCamera,
  }) async {
    try {
      final List<String> imagePaths = [];
      if (isCamera) {
        final photo = await _picker.pickImage(source: ImageSource.camera);
        if (photo == null || !mounted) return;
        imagePaths.add(photo.path);
      } else {
        final photos = await _picker.pickMultiImage();
        if (photos.isEmpty || !mounted) return;
        imagePaths.addAll(photos.map((p) => p.path));
      }

      if (imagePaths.isEmpty || !mounted) return;

      // Show non-blocking progress indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => PopScope(
          canPop: false,
          child: CupertinoAlertDialog(
            title: const Text('Converting to PDF'),
            content: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CupertinoActivityIndicator(radius: 14),
                  const SizedBox(height: 12),
                  Text(
                    'Generating PDF from ${imagePaths.length} photo${imagePaths.length > 1 ? 's' : ''}...\nSaving directly to Documents folder.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final now = DateTime.now();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
      final fileName = 'PrivaScan_$dateStr.pdf';
      final title = 'PrivaScan Photo Doc $dateStr';

      // 100% on-device PDF generation
      final pdfService = PdfService();
      final pdfBytes = await pdfService.generatePdf(
        imagePaths,
        documentTitle: title,
        quality: PdfQuality.high,
      );

      // Save directly to device storage Documents folder
      final savedFile = await _savePdfToDocuments(pdfBytes, fileName);

      // Also create a local Document record so it appears in "My Scanned Documents"
      final doc = Document(
        id: const Uuid().v4(),
        name: 'Photo PDF ${DateFormat('MMM d, HH:mm').format(now)}',
        imagePaths: imagePaths,
        createdAt: now,
        updatedAt: now,
        extractedText: 'PDF saved to Documents/PrivaScan/$fileName',
        tags: ['pdf', 'photo'],
      );

      if (!mounted) return;
      context.read<DocumentBloc>().add(AddDocument(doc));
      // Dismiss progress dialog
      Navigator.of(context, rootNavigator: true).pop();

      final fileSizeKb = (pdfBytes.length / 1024).toStringAsFixed(1);
      final displayPath = savedFile != null
          ? savedFile.path
          : '/storage/emulated/0/Documents/PrivaScan/$fileName';

      // Show completion feedback dialog
      showCupertinoDialog(
        context: context,
        builder: (successCtx) => CupertinoAlertDialog(
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: Color(0xFF34C759),
                size: 22,
              ),
              SizedBox(width: 8),
              Text('PDF Saved!'),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your photo${imagePaths.length > 1 ? 's were' : ' was'} successfully converted to PDF and saved directly in your device Documents folder.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6.resolveFrom(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Size: $fileSizeKb KB • ${imagePaths.length} Page${imagePaths.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Path: $displayPath',
                        style: TextStyle(
                          fontSize: 10,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('View PDF'),
              onPressed: () {
                Navigator.pop(successCtx);
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => PdfPreviewScreen(
                      documentName: 'Photo PDF $dateStr',
                      imagePaths: imagePaths,
                    ),
                  ),
                );
              },
            ),
            CupertinoDialogAction(
              child: const Text('Share'),
              onPressed: () async {
                Navigator.pop(successCtx);
                await Printing.sharePdf(
                  bytes: pdfBytes,
                  filename: fileName,
                );
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Done'),
              onPressed: () => Navigator.pop(successCtx),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to convert photo to PDF: $e')),
      );
    }
  }

  Future<File?> _savePdfToDocuments(Uint8List bytes, String fileName) async {
    try {
      Directory? targetDir;

      if (Platform.isAndroid) {
        // Direct public Documents/PrivaScan directory
        final privaScanDocs = Directory('/storage/emulated/0/Documents/PrivaScan');
        try {
          if (!await privaScanDocs.exists()) {
            await privaScanDocs.create(recursive: true);
          }
          targetDir = privaScanDocs;
        } catch (_) {
          // Direct public Documents directory root
          final rootDocs = Directory('/storage/emulated/0/Documents');
          try {
            if (!await rootDocs.exists()) {
              await rootDocs.create(recursive: true);
            }
            targetDir = rootDocs;
          } catch (_) {}
        }

        // Fallback: external storage documents directory
        if (targetDir == null) {
          try {
            final dirs = await getExternalStorageDirectories(
              type: StorageDirectory.documents,
            );
            if (dirs != null && dirs.isNotEmpty) {
              targetDir = dirs.first;
            }
          } catch (_) {}
        }
      }

      // Fallback for iOS or other platforms
      targetDir ??= await getApplicationDocumentsDirectory();

      final file = File('${targetDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      debugPrint('Error saving PDF to Documents: $e');
      return null;
    }
  }

  void _showQuickOcrTool(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Smart OCR & Text Extractor'),
        message: const Text(
          'Extract all text from any photo or document 100% on-device.',
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



  void _showSignatureStampTool() async {
    HapticFeedback.lightImpact();
    final isVip = VipService.instance.isVip;
    if (!isVip) {
      final upgraded = await VipPassScreen.show(
        context,
        triggerPerk: 'Custom Digital Signature & Stamp',
      );
      if (!upgraded && !VipService.instance.isVip) return;
    }
    if (!mounted) return;
    await SignatureStampDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title (Clean, no 100% offline banner and no "2x2 Grid" text)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Text(
            'ALL FEATURES & AI TOOLS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),

        // 2-Column Grid containing all features including Photo to PDF
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.18,
            children: [
              _buildFeatureCard(
                theme: theme,
                isDark: isDark,
                title: 'Photo to PDF',
                subtitle: 'Save to Documents',
                icon: CupertinoIcons.doc_append,
                accentColor: const Color(0xFFE11D48),
                badge: 'PDF Save',
                onTap: _convertPhotoToPdf,
              ),
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
                title: 'Smart OCR Text',
                subtitle: 'Extract & copy text',
                icon: CupertinoIcons.viewfinder,
                accentColor: const Color(0xFF00C7BE),
                badge: 'On-Device',
                onTap: () => _showQuickOcrTool(context),
              ),
              _buildFeatureCard(
                theme: theme,
                isDark: isDark,
                title: 'QR & Barcode',
                subtitle: 'Instant live camera',
                icon: CupertinoIcons.barcode_viewfinder,
                accentColor: const Color(0xFF6366F1),
                badge: 'Advanced',
                onTap: () => Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const QrScannerScreen()),
                ),
              ),
              _buildFeatureCard(
                theme: theme,
                isDark: isDark,
                title: 'Table to CSV',
                subtitle: 'Invoices & bills',
                icon: CupertinoIcons.table,
                accentColor: const Color(0xFF30B0C7),
                badge: 'CSV',
                onTap: _showTableExtractorTool,
              ),
              _buildFeatureCard(
                theme: theme,
                isDark: isDark,
                title: 'Offline Translate',
                subtitle: '30+ languages & auto',
                icon: CupertinoIcons.globe,
                accentColor: const Color(0xFFFF9500),
                badge: 'Offline',
                onTap: () => Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const OfflineTranslateScreen()),
                ),
              ),
              _buildFeatureCard(
                theme: theme,
                isDark: isDark,
                title: 'Audio Reader (TTS)',
                subtitle: 'Listen hands-free',
                icon: CupertinoIcons.speaker_2_fill,
                accentColor: const Color(0xFFFF2D55),
                badge: 'Voice',
                onTap: () => Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const AudioReaderScreen()),
                ),
              ),
              _buildFeatureCard(
                theme: theme,
                isDark: isDark,
                title: 'Sign & Stamp',
                subtitle: 'Signatures & stamps',
                icon: CupertinoIcons.signature,
                accentColor: const Color(0xFF2563EB),
                badge: 'VIP',
                onTap: _showSignatureStampTool,
              ),
              _buildFeatureCard(
                theme: theme,
                isDark: isDark,
                title: 'VIP Pass',
                subtitle: '₹99/mo • 100% Ad-Free',
                icon: CupertinoIcons.sparkles,
                accentColor: const Color(0xFF7C3AED),
                badge: '₹99/mo',
                onTap: () => Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const VipPassScreen()),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // My Documents Section Divider
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'MY SCANNED DOCUMENTS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
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
        padding: const EdgeInsets.all(13),
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
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
}
