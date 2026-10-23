import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/document.dart';
import '../blocs/document_bloc.dart';
import '../blocs/ai_bloc.dart';
import '../../data/services/ocr_service.dart';
import '../../data/services/ad_service.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/document_classifier_service.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/services/translation_languages.dart';
import '../../data/services/tts_service.dart';
import '../../data/services/table_detection_service.dart';
import '../../data/services/barcode_service.dart';
import '../widgets/signature_stamp_dialog.dart';
import 'signature_placement_screen.dart';
import 'pdf_preview_screen.dart';

class DocumentWorkspaceScreen extends StatefulWidget {
  final Document document;
  final int initialTabIndex;

  const DocumentWorkspaceScreen({
    super.key,
    required this.document,
    this.initialTabIndex = 0,
  });

  @override
  State<DocumentWorkspaceScreen> createState() =>
      _DocumentWorkspaceScreenState();
}

class _DocumentWorkspaceScreenState extends State<DocumentWorkspaceScreen>
  with SingleTickerProviderStateMixin {
  final OcrService _ocrService = OcrService();
  final ImagePicker _picker = ImagePicker();
  final TtsService _ttsService = TtsService.instance;

  final TableDetectionService _tableService = TableDetectionService();
  final BarcodeService _barcodeService = BarcodeService();
  List<DetectedBarcode> _detectedBarcodes = [];

  String _extractedText = '';
  bool _isProcessingOcr = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _customQuestionController =
      TextEditingController();
  int _currentTabIndex = 0;
  late SupportedLanguage _selectedLanguage;

  late List<String> _imagePaths;
  int _currentPageIndex = 0;
  final PageController _pageController = PageController();
  TtsPlaybackState _ttsState = TtsPlaybackState.stopped;
  double _ttsSpeed = 0.5;

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.initialTabIndex;
    _nameController.text = widget.document.name;
    _extractedText = widget.document.extractedText ?? '';
    _imagePaths = List.from(widget.document.imagePaths);

    final box = Hive.box(AppConstants.settingsBox);
    final savedBcp = box.get(AppConstants.targetLanguageKey, defaultValue: 'hi') as String;
    _selectedLanguage = TranslationLanguages.fromBcpCode(savedBcp);

    _ttsService.init();
    _ttsService.stateNotifier.addListener(_onTtsStateChanged);

    _scanBarcodesForCurrentPage();

    if (_extractedText.isEmpty && _imagePaths.isNotEmpty) {
      _isProcessingOcr = true;
      _processOcr();
    }
  }

  void _onTtsStateChanged() {
    if (mounted) {
      setState(() {
        _ttsState = _ttsService.stateNotifier.value;
      });
    }
  }

  Future<void> _scanBarcodesForCurrentPage() async {
    if (_imagePaths.isEmpty || _currentPageIndex >= _imagePaths.length) {
      if (mounted) setState(() => _detectedBarcodes = []);
      return;
    }
    final path = _imagePaths[_currentPageIndex];
    try {
      final barcodes = await _barcodeService.scanImage(path);
      if (mounted) {
        setState(() {
          _detectedBarcodes = barcodes;
        });
      }
    } catch (_) {}
  }

  void _autoSuggestTitle({bool notifyOnSame = true}) {
    if (_extractedText.isEmpty ||
        _extractedText.contains('No readable text found')) {
      if (notifyOnSame) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No extracted OCR text available to suggest a title.'),
          ),
        );
      }
      return;
    }

    final suggested = DocumentClassifierService.suggestTitle(
      text: _extractedText,
      currentTitle: _nameController.text,
    );

    if (suggested.isNotEmpty) {
      final wasChanged = _nameController.text != suggested;
      setState(() {
        _nameController.text = suggested;
      });
      final updatedDoc = widget.document.copyWith(
        name: suggested,
        updatedAt: DateTime.now(),
      );
      context.read<DocumentBloc>().add(UpdateDocument(updatedDoc));
      if (notifyOnSame) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasChanged ? 'Renamed to: $suggested' : 'Title is already optimal',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _exportTableCsv() async {
    if (_extractedText.isEmpty ||
        _extractedText.contains('No readable text found')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No extracted OCR text available to export table data.'),
        ),
      );
      return;
    }

    try {
      final result = _tableService.detectTable(_extractedText);
      final safeName = widget.document.name.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
      final file = await _tableService.exportToCsvFile(
        result.csvContent,
        fileName: '${safeName}_table',
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: '${widget.document.name} - Tabular Data (.csv)',
          text: 'Extracted tabular CSV data from PrivaScan AI',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customQuestionController.dispose();
    _ocrService.dispose();
    _barcodeService.dispose();
    _pageController.dispose();
    _ttsService.stateNotifier.removeListener(_onTtsStateChanged);
    _ttsService.stop();
    super.dispose();
  }

  void _confirmDelete(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Move to Trash'),
        content: const Text(
          'Move this document to Trash? It will remain restorable for 30 days before being permanently deleted.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              context.read<DocumentBloc>().add(
                MoveToTrash(widget.document.id),
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Moved "${widget.document.name}" to Trash'),
                  action: SnackBarAction(
                    label: 'UNDO',
                    onPressed: () {
                      context.read<DocumentBloc>().add(
                        RestoreDocument(widget.document.id),
                      );
                    },
                  ),
                  duration: const Duration(seconds: 4),
                ),
              );
            },
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
  }

  Future<void> _processOcr() async {
    if (_imagePaths.isEmpty) return;
    setState(() => _isProcessingOcr = true);

    try {
      final textBuffer = StringBuffer();
      for (final imagePath in _imagePaths) {
        final text = await _ocrService.extractText(imagePath);
        if (text.trim().isNotEmpty) {
          textBuffer.writeln(text);
        }
      }

      _extractedText = textBuffer.toString().trim();

      if (_extractedText.isEmpty) {
        _extractedText = "No readable text found in the document.";
      }

      DocumentCategory? determinedCategory;
      final List<String> tags = List.from(widget.document.tags);
      if (!tags.any((t) => t.startsWith('category_'))) {
        determinedCategory = DocumentClassifierService.classify(
          title: widget.document.name,
          text: _extractedText,
        );
        tags.add(determinedCategory.id);
      }

      // Auto-suggest smart title if current title is default
      String docName = _nameController.text;
      final defaultPatterns = RegExp(
        r'^(scan|document|id card|doc)\b',
        caseSensitive: false,
      );
      if (defaultPatterns.hasMatch(docName.trim()) || docName.trim().isEmpty) {
        final suggested = DocumentClassifierService.suggestTitle(
          text: _extractedText,
          currentTitle: docName,
          category: determinedCategory,
        );
        if (suggested.isNotEmpty && suggested != docName) {
          docName = suggested;
          _nameController.text = suggested;
        }
      }

      final updatedDoc = widget.document.copyWith(
        name: docName,
        extractedText: _extractedText,
        tags: tags,
        imagePaths: _imagePaths,
        updatedAt: DateTime.now(),
      );
      if (mounted) {
        context.read<DocumentBloc>().add(UpdateDocument(updatedDoc));
      }
      _scanBarcodesForCurrentPage();
    } catch (e) {
      _extractedText = 'OCR error occurred on this device.\n\nDetails: $e';

      final updatedDoc = widget.document.copyWith(
        extractedText: _extractedText,
        imagePaths: _imagePaths,
        updatedAt: DateTime.now(),
      );
      if (mounted) {
        context.read<DocumentBloc>().add(UpdateDocument(updatedDoc));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingOcr = false);
      }
    }
  }

  void _toggleTts() {
    if (_extractedText.isEmpty ||
        _extractedText.contains('No readable text found')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No extracted text to read aloud.')),
      );
      return;
    }
    if (_ttsState == TtsPlaybackState.playing) {
      _ttsService.pause();
    } else {
      _ttsService.speak(_extractedText);
    }
  }

  void _stopTts() {
    _ttsService.stop();
  }

  void _setTtsSpeed(double speed) {
    setState(() => _ttsSpeed = speed);
    _ttsService.setRate(speed);
  }

  Future<void> _addPage(bool fromCamera) async {
    try {
      final XFile? image = fromCamera
          ? await _picker.pickImage(source: ImageSource.camera)
          : await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${const Uuid().v4()}.jpg';
      final newPath = '${directory.path}/$fileName';
      await File(image.path).copy(newPath);

      setState(() {
        _imagePaths.add(newPath);
        _currentPageIndex = _imagePaths.length - 1;
      });

      _pageController.animateToPage(
        _currentPageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      if (!mounted) return;
      final updatedDoc = widget.document.copyWith(
        imagePaths: _imagePaths,
        updatedAt: DateTime.now(),
      );
      context.read<DocumentBloc>().add(UpdateDocument(updatedDoc));

      // Re-run OCR on updated page list
      _processOcr();
    } catch (e) {
      debugPrint('Add page error: $e');
    }
  }

  void _showAddPageSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Add Page to Document'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _addPage(true);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera),
                SizedBox(width: 8),
                Text('Capture with Camera'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _addPage(false);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo),
                SizedBox(width: 8),
                Text('Import from Gallery'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _deleteCurrentPage() {
    if (_imagePaths.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A document must have at least one page.')),
      );
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Page'),
        content: Text('Are you sure you want to delete Page ${_currentPageIndex + 1}?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                final removed = _imagePaths.removeAt(_currentPageIndex);
                try {
                  final f = File(removed);
                  if (f.existsSync()) f.deleteSync();
                } catch (_) {}
                if (_currentPageIndex >= _imagePaths.length) {
                  _currentPageIndex = _imagePaths.length - 1;
                }
              });

              final updatedDoc = widget.document.copyWith(
                imagePaths: _imagePaths,
                updatedAt: DateTime.now(),
              );
              context.read<DocumentBloc>().add(UpdateDocument(updatedDoc));
            },
          ),
        ],
      ),
    );
  }

  void _showReorderDialog() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            height: 480,
            margin: const EdgeInsets.only(top: 80),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Reorder Pages',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: _imagePaths.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setModalState(() {
                        final item = _imagePaths.removeAt(oldIndex);
                        _imagePaths.insert(newIndex, item);
                      });
                      setState(() {});
                      final updatedDoc = widget.document.copyWith(
                        imagePaths: _imagePaths,
                        updatedAt: DateTime.now(),
                      );
                      this.context.read<DocumentBloc>().add(UpdateDocument(updatedDoc));
                    },
                    itemBuilder: (context, index) {
                      final path = _imagePaths[index];
                      return ListTile(
                        key: ValueKey(path),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(path),
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text('Page ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: const Icon(CupertinoIcons.bars),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _signCurrentPage() async {
    if (_imagePaths.isEmpty) return;
    final result = await SignatureStampDialog.show(context);
    if (result == null || !mounted) return;

    final currentPath = _imagePaths[_currentPageIndex];
    final bool? applied = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(
        builder: (_) => SignaturePlacementScreen(
          pageImagePath: currentPath,
          signatureBytes: result.bytes,
          pageNumber: _currentPageIndex + 1,
          totalPages: _imagePaths.length,
        ),
      ),
    );

    if (applied == true && mounted) {
      PaintingBinding.instance.imageCache
          .evict(FileImage(File(currentPath)));
      setState(() {});

      final updatedDoc = widget.document.copyWith(
        imagePaths: _imagePaths,
        updatedAt: DateTime.now(),
      );
      context.read<DocumentBloc>().add(UpdateDocument(updatedDoc));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.title} placed onto Page ${_currentPageIndex + 1}',
          ),
          backgroundColor: CupertinoColors.activeGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showCategoryPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Assign Category to "${widget.document.name}"'),
        message: const Text('Smart offline folders organize your documents seamlessly'),
        actions: DocumentClassifierService.allCategories.map((category) {
          final isCurrent = widget.document.primaryCategory == category.id;
          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              final newTags = widget.document.tags
                  .where((t) => !t.startsWith('category_'))
                  .toList()..add(category.id);
              final updated = widget.document.copyWith(
                tags: newTags,
                updatedAt: DateTime.now(),
              );
              context.read<DocumentBloc>().add(UpdateDocument(updated));
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(category.icon, size: 18, color: category.color),
                const SizedBox(width: 8),
                Text(
                  category.name,
                  style: TextStyle(
                    color: isCurrent ? category.color : null,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  Icon(CupertinoIcons.checkmark, size: 16, color: category.color),
                ],
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showShareOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Document Options & Sharing'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => PdfPreviewScreen(
                    documentName: widget.document.name,
                    imagePaths: _imagePaths,
                    extractedText: _extractedText,
                  ),
                ),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.doc_fill),
                SizedBox(width: 8),
                Text('Share as PDF (Options & Watermark)'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _exportTableCsv();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.table),
                SizedBox(width: 8),
                Text('Export Table (.csv)'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _autoSuggestTitle(notifyOnSame: true);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.sparkles),
                SizedBox(width: 8),
                Text('Auto-Suggest Title (AI)'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: _extractedText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied extracted text')),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.doc_on_clipboard),
                SizedBox(width: 8),
                Text('Copy Extracted Text'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _toggleTts();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_ttsState == TtsPlaybackState.playing
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.speaker_2_fill),
                const SizedBox(width: 8),
                Text(_ttsState == TtsPlaybackState.playing
                    ? 'Pause Read Aloud'
                    : 'Read Aloud (Text-to-Speech)'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _showCategoryPicker();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.folder_fill),
                SizedBox(width: 8),
                Text('Change Category'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Row(
                          children: [Icon(CupertinoIcons.back), Text('Back')],
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: CupertinoTextField(
                          controller: _nameController,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          suffix: CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: Size.zero,
                            onPressed: () => _autoSuggestTitle(notifyOnSame: true),
                            child: Icon(
                              CupertinoIcons.sparkles,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          onSubmitted: (value) {
                            final updatedDoc = widget.document.copyWith(
                              name: value,
                              updatedAt: DateTime.now(),
                            );
                            context.read<DocumentBloc>().add(
                              UpdateDocument(updatedDoc),
                            );
                          },
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            onPressed: _showShareOptions,
                            child: const Icon(CupertinoIcons.share),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.only(left: 8, right: 16),
                            onPressed: () => _confirmDelete(context),
                            child: const Icon(
                              CupertinoIcons.trash,
                              color: CupertinoColors.destructiveRed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<int>(
                        groupValue: _currentTabIndex,
                        backgroundColor: isDark
                            ? const Color(0xFF1C1C1E)
                            : const Color(0xFFE5E5EA),
                        children: const {
                          0: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Scan'),
                          ),
                          1: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Text'),
                          ),
                          2: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('AI'),
                          ),
                          3: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('PDF'),
                          ),
                        },
                        onValueChanged: (val) {
                          if (val != null) {
                            setState(() => _currentTabIndex = val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          RepaintBoundary(child: _buildScanTab(theme)),
          RepaintBoundary(child: _buildTextTab(theme)),
          RepaintBoundary(child: _buildAiTab(theme)),
          RepaintBoundary(child: _buildPdfTab(theme)),
        ],
      ),
      bottomNavigationBar: const BannerAdWidget(),
    );
  }

  Widget _buildScanTab(ThemeData theme) {
    if (_imagePaths.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.photo,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No images in document',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: () => _showAddPageSheet(context),
              child: const Text('Add Page'),
            ),
          ],
        ),
      );
    }

    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Top Page Action Bar: Page indicator & Page Tools (Sign, Reorder, Add, Delete)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
            border: Border(
              bottom: BorderSide(
                color: theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Page ${_currentPageIndex + 1} of ${_imagePaths.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    onPressed: _signCurrentPage,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.pen, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Sign',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    onPressed: _showReorderDialog,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.arrow_up_down, size: 16),
                        SizedBox(width: 4),
                        Text('Reorder', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    onPressed: () => _showAddPageSheet(context),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.plus_circle, size: 16),
                        SizedBox(width: 4),
                        Text('Add', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  if (_imagePaths.length > 1)
                    CupertinoButton(
                      padding: const EdgeInsets.only(left: 4),
                      onPressed: _deleteCurrentPage,
                      child: const Icon(
                        CupertinoIcons.trash,
                        size: 18,
                        color: CupertinoColors.destructiveRed,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Interactive Page View
        if (_detectedBarcodes.isNotEmpty)
          _buildBarcodeBanner(theme),

        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _imagePaths.length,
            onPageChanged: (idx) {
              setState(() => _currentPageIndex = idx);
              _scanBarcodesForCurrentPage();
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InteractiveViewer(
                    child: Image.file(
                      File(_imagePaths[index]),
                      key: ValueKey(
                        '${_imagePaths[index]}_${File(_imagePaths[index]).existsSync() ? File(_imagePaths[index]).lastModifiedSync().millisecondsSinceEpoch : 0}',
                      ),
                      fit: BoxFit.contain,
                      cacheWidth: 1080,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Thumbnail strip at bottom for multi-page documents
        if (_imagePaths.length > 1)
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
              border: Border(
                top: BorderSide(
                  color: theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _imagePaths.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = index == _currentPageIndex;
                return GestureDetector(
                  onTap: () {
                    setState(() => _currentPageIndex = index);
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.file(
                      File(_imagePaths[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildBarcodeBanner(ThemeData theme) {
    final barcode = _detectedBarcodes.first;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.qrcode,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      barcode.formatLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Detected',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  barcode.rawValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (barcode.isUrl || barcode.isUpi || barcode.isEmail || barcode.isPhone)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
              onPressed: () async {
                final uri = Uri.tryParse(barcode.rawValue);
                if (uri != null) {
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open link')),
                      );
                    }
                  }
                }
              },
              child: Text(
                barcode.isUrl
                    ? 'Open'
                    : barcode.isUpi
                        ? 'Pay'
                        : barcode.isEmail
                            ? 'Email'
                            : 'Call',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          const SizedBox(width: 4),
          CupertinoButton(
            padding: const EdgeInsets.all(6),
            minimumSize: Size.zero,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: barcode.rawValue));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied: ${barcode.rawValue}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Icon(
              CupertinoIcons.doc_on_clipboard,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextTab(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    if (_isProcessingOcr) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CupertinoActivityIndicator(radius: 16),
            const SizedBox(height: 20),
            Text(
              'Extracting text...',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_extractedText.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.doc_text,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 20),
            Text(
              'No text extracted',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: _processOcr,
              child: const Text('Extract Text'),
            ),
          ],
        ),
      );
    }

    final entities = AiService.detectEntities(_extractedText);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Extracted Text',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: _toggleTts,
                    child: Row(
                      children: [
                        Icon(
                          _ttsState == TtsPlaybackState.playing
                              ? CupertinoIcons.pause_fill
                              : CupertinoIcons.speaker_2_fill,
                          size: 16,
                          color: _ttsState == TtsPlaybackState.playing
                              ? CupertinoColors.activeGreen
                              : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _ttsState == TtsPlaybackState.playing
                              ? 'Pause'
                              : 'Read Aloud',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _ttsState == TtsPlaybackState.playing
                                ? CupertinoColors.activeGreen
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _extractedText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                    child: const Row(
                      children: [
                        Icon(CupertinoIcons.doc_on_clipboard, size: 16),
                        SizedBox(width: 4),
                        Text('Copy', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_ttsState != TtsPlaybackState.stopped)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.waveform,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _ttsState == TtsPlaybackState.playing
                      ? 'Reading Aloud...'
                      : 'Audio Paused',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                CupertinoSlidingSegmentedControl<double>(
                  groupValue: _ttsSpeed,
                  backgroundColor: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFE5E5EA),
                  children: {
                    0.4: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text('0.75x', style: TextStyle(fontSize: 10)),
                    ),
                    0.5: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text('1x', style: TextStyle(fontSize: 10)),
                    ),
                    0.65: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text('1.25x', style: TextStyle(fontSize: 10)),
                    ),
                  },
                  onValueChanged: (val) {
                    if (val != null) _setTtsSpeed(val);
                  },
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _toggleTts,
                  child: Icon(
                    _ttsState == TtsPlaybackState.playing
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 4),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _stopTts,
                  child: const Icon(
                    CupertinoIcons.stop_fill,
                    size: 18,
                    color: CupertinoColors.destructiveRed,
                  ),
                ),
              ],
            ),
          ),
        if (entities.isNotEmpty) _buildEntityChips(theme, entities),
        Divider(height: 1, color: theme.dividerTheme.color),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: SelectableText(
              _extractedText,
              style: TextStyle(
                fontSize: 17,
                height: 1.4,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiTab(ThemeData theme) {
    return BlocBuilder<AiBloc, AiState>(
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Text(
                  'AI ACTIONS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _buildAiRow(
                      theme,
                      icon: CupertinoIcons.text_alignleft,
                      color: CupertinoColors.activeBlue,
                      label: 'Quick Summary',
                      onTap: () => _generateSummary('Quick Summary'),
                      isLast: false,
                    ),
                    _buildAiRow(
                      theme,
                      icon: CupertinoIcons.checkmark_square,
                      color: CupertinoColors.activeGreen,
                      label: 'Action Items',
                      onTap: () => _generateSummary('Action Items'),
                      isLast: false,
                    ),
                    _buildAiRow(
                      theme,
                      icon: CupertinoIcons.tag,
                      color: CupertinoColors.activeOrange,
                      label: 'Key Entities',
                      onTap: () => _generateSummary('Key Entities'),
                      isLast: false,
                    ),
                    _buildAiRow(
                      theme,
                      icon: CupertinoIcons.globe,
                      color: CupertinoColors.systemIndigo,
                      label: 'Translate (${_selectedLanguage.englishName})',
                      subtitle: '${_selectedLanguage.flag} ${_selectedLanguage.nativeName}',
                      trailing: CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        onPressed: _showLanguagePicker,
                        child: Text(
                          'Change',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      onTap: () => _translateDocument(),
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Text(
                  'ASK A QUESTION',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: _customQuestionController,
                        placeholder: 'Ask about this document...',
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        onSubmitted: (_) => _askQuestion(),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _askQuestion,
                      child: const Icon(
                        CupertinoIcons.arrow_up_circle_fill,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (state is AiProcessing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CupertinoActivityIndicator(radius: 14),
                  ),
                )
              else if (state is AiSuccess)
                _buildAiResponseCard(theme, state.response)
              else if (state is AiError)
                _buildErrorCard(theme, state.message),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAiRow(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String label,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
    required bool isLast,
  }) {
    return GestureDetector(
      onTap: _extractedText.isEmpty ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: _extractedText.isEmpty ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.only(left: 16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 0,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 17,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: trailing,
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Icon(
                          CupertinoIcons.chevron_forward,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 46),
                  child: Divider(height: 1, color: theme.dividerTheme.color),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdfTab(ThemeData theme) {
    final imageCount = widget.document.imagePaths.length;

    if (imageCount == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.doc_richtext,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 20),
            Text(
              'No images to export',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            CupertinoIcons.doc_fill,
            size: 80,
            color: CupertinoColors.systemRed.resolveFrom(context),
          ),
          const SizedBox(height: 24),
          Text(
            'Export as PDF',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$imageCount page${imageCount == 1 ? '' : 's'} ready for export.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => PdfPreviewScreen(
                      documentName: widget.document.name,
                      imagePaths: widget.document.imagePaths,
                      extractedText: _extractedText,
                    ),
                  ),
                );
              },
              child: const Text('Generate PDF Preview'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiResponseCard(ThemeData theme, String response) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.sparkles,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'AI Response',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: response));
                },
                child: const Icon(CupertinoIcons.doc_on_clipboard, size: 20),
              ),
            ],
          ),
          Divider(height: 16, color: theme.dividerTheme.color),
          SelectableText(
            response,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _generateSummary(String template) {
    if (_extractedText.isEmpty) {
      return;
    }
    context.read<AiBloc>().add(GenerateSummary(_extractedText, template));
  }

  void _translateDocument([SupportedLanguage? language]) {
    if (_extractedText.isEmpty) return;
    final target = language ?? _selectedLanguage;
    context.read<AiBloc>().add(
          TranslateText(_extractedText, target.language),
        );
  }

  void _showLanguagePicker() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final allLanguages = TranslationLanguages.popularLanguages;
            final filtered = searchQuery.isEmpty
                ? allLanguages
                : allLanguages.where((lang) {
                    final q = searchQuery.toLowerCase();
                    return lang.englishName.toLowerCase().contains(q) ||
                        lang.nativeName.toLowerCase().contains(q);
                  }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.2,
                      ),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Translate Document',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          onPressed: () => Navigator.pop(ctx),
                          child: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.activeGreen.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.shield_fill,
                            size: 16,
                            color: CupertinoColors.activeGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'On-Device Translation • Zero data leaves your phone',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF2E7D32),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: CupertinoSearchTextField(
                      placeholder: 'Search 25+ languages...',
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      onChanged: (val) {
                        setModalState(() => searchQuery = val);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No matching languages',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              indent: 56,
                              color: theme.dividerTheme.color,
                            ),
                            itemBuilder: (context, idx) {
                              final lang = filtered[idx];
                              final isSelected =
                                  lang.language == _selectedLanguage.language;

                              return ListTile(
                                leading: Text(
                                  lang.flag,
                                  style: const TextStyle(fontSize: 26),
                                ),
                                title: Text(
                                  lang.englishName,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  lang.nativeName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(
                                        CupertinoIcons
                                            .checkmark_alt_circle_fill,
                                        color: CupertinoColors.activeBlue,
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  setState(() {
                                    _selectedLanguage = lang;
                                  });
                                  Hive.box(AppConstants.settingsBox).put(
                                    AppConstants.targetLanguageKey,
                                    lang.language.bcpCode,
                                  );
                                  _translateDocument(lang);
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
      },
    );
  }

  void _askQuestion() {
    final question = _customQuestionController.text.trim();
    if (question.isEmpty || _extractedText.isEmpty) return;
    context.read<AiBloc>().add(AskCustomQuestion(_extractedText, question));
    _customQuestionController.clear();
    FocusScope.of(context).unfocus();
  }

  Widget _buildEntityChips(ThemeData theme, ExtractedEntities entities) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: theme.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (final phone in entities.phones)
              _buildChip(
                theme: theme,
                icon: CupertinoIcons.phone_fill,
                label: 'Call $phone',
                color: CupertinoColors.activeGreen,
                onTap: () => _launchAction(
                  'tel:${phone.replaceAll(RegExp(r'[^\d+]'), '')}',
                ),
              ),
            for (final email in entities.emails)
              _buildChip(
                theme: theme,
                icon: CupertinoIcons.mail_solid,
                label: 'Email $email',
                color: CupertinoColors.activeBlue,
                onTap: () => _launchAction('mailto:$email'),
              ),
            for (final url in entities.urls)
              _buildChip(
                theme: theme,
                icon: CupertinoIcons.globe,
                label: url.length > 28 ? '${url.substring(0, 25)}...' : url,
                color: CupertinoColors.systemIndigo,
                onTap: () {
                  final link =
                      url.startsWith('http') ? url : 'https://$url';
                  _launchAction(link);
                },
              ),
            for (final amount in entities.amounts)
              _buildChip(
                theme: theme,
                icon: CupertinoIcons.money_dollar,
                label: amount,
                color: CupertinoColors.systemOrange,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: amount));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied $amount to clipboard')),
                  );
                },
              ),
            for (final date in entities.dates)
              _buildChip(
                theme: theme,
                icon: CupertinoIcons.calendar,
                label: date,
                color: CupertinoColors.systemPurple,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: date));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied $date to clipboard')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        minimumSize: const Size(0, 32),
        onPressed: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchAction(String urlStr) async {
    try {
      final uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot open: $urlStr')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
