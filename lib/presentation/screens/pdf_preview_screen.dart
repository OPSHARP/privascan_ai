import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/services/pdf_service.dart';
import '../../data/services/vip_service.dart';
import '../widgets/signature_stamp_dialog.dart';
import 'vip_pass_screen.dart';

class PdfPreviewScreen extends StatefulWidget {
  final String documentName;
  final List<String> imagePaths;
  final String? extractedText;

  const PdfPreviewScreen({
    super.key,
    required this.documentName,
    required this.imagePaths,
    this.extractedText,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  final PdfService _pdfService = PdfService();
  Uint8List? _pdfBytes;
  bool _isGenerating = true;
  String? _error;

  PdfQuality _quality = PdfQuality.high;
  bool _includeTextPage = false;
  String? _watermarkText;

  // VIP Features
  String? _password;
  Uint8List? _signatureBytes;
  Uint8List? _stampBytes;
  String? _stampTitle;

  bool get _hasText =>
      widget.extractedText != null &&
      widget.extractedText!.trim().isNotEmpty &&
      !widget.extractedText!.contains('No readable text found');

  @override
  void initState() {
    super.initState();
    _includeTextPage = _hasText;
    _generatePdf();
  }

  Future<void> _generatePdf() async {
    try {
      final bytes = await _pdfService.generatePdf(
        widget.imagePaths,
        quality: _quality,
        extractedText: widget.extractedText,
        includeTextPage: _includeTextPage,
        documentTitle: widget.documentName,
        watermarkText: _watermarkText,
        password: _password,
        signatureBytes: _signatureBytes,
        stampBytes: _stampBytes,
      );
      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _exportPlainText() async {
    if (!_hasText) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final sanitizedName =
          widget.documentName.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
      final textFile = File('${tempDir.path}/$sanitizedName.txt');
      await textFile.writeAsString(widget.extractedText!);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(textFile.path, mimeType: 'text/plain')],
          subject: '${widget.documentName} - Extracted Text',
          text: 'Extracted text transcript from PrivaScan AI',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _showWatermarkDialog() {
    final controller = TextEditingController(text: _watermarkText ?? '');
    const presets = [
      'FOR KYC ONLY',
      'CONFIDENTIAL',
      'COPY',
      'SAMPLE',
      'DO NOT SHARE',
      'ORIGINAL',
    ];

    showCupertinoDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return CupertinoAlertDialog(
            title: const Text('Document Watermark'),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stamp diagonal semi-transparent security watermark across all pages. Protects IDs & docs from misuse.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: presets.map((preset) {
                      final isSelected =
                          controller.text.trim().toUpperCase() == preset;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            controller.text = preset;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? CupertinoColors.activeBlue
                                : CupertinoColors.systemGrey5,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            preset,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : null,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: controller,
                    placeholder: 'Or enter custom watermark',
                    clearButtonMode: OverlayVisibilityMode.editing,
                  ),
                ],
              ),
            ),
            actions: [
              if (_watermarkText != null)
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  child: const Text('Remove'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _watermarkText = null;
                      _isGenerating = true;
                    });
                    _generatePdf();
                  },
                ),
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(ctx),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('Apply'),
                onPressed: () {
                  final text = controller.text.trim();
                  Navigator.pop(ctx);
                  setState(() {
                    _watermarkText = text.isEmpty ? null : text;
                    _isGenerating = true;
                  });
                  _generatePdf();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPasswordDialog() async {
    final isVip = VipService.instance.isVip;
    if (!isVip) {
      final upgraded = await VipPassScreen.show(
        context,
        triggerPerk: 'Password Protected Encrypted PDF',
      );
      if (!upgraded && !VipService.instance.isVip) return;
    }
    if (!mounted) return;

    final controller = TextEditingController(text: _password ?? '');
    var obscure = true;

    showCupertinoDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return CupertinoAlertDialog(
            title: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.lock_shield_fill,
                  color: Color(0xFFFFB300),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text('Encrypt PDF (VIP)'),
              ],
            ),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Standard ISO 32000 128-bit PDF encryption. Acrobat, Google Drive & Chrome will require this password to view or print the file.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: controller,
                    placeholder: 'Enter document password',
                    obscureText: obscure,
                    suffix: CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        obscure ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                        size: 18,
                        color: CupertinoColors.systemGrey,
                      ),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (_password != null)
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  child: const Text('Remove Lock'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _password = null;
                      _isGenerating = true;
                    });
                    _generatePdf();
                  },
                ),
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(ctx),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('Encrypt PDF'),
                onPressed: () {
                  final pass = controller.text.trim();
                  if (pass.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password cannot be empty')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  setState(() {
                    _password = pass;
                    _isGenerating = true;
                  });
                  _generatePdf();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSignatureStampPicker() async {
    final isVip = VipService.instance.isVip;
    if (!isVip) {
      final upgraded = await VipPassScreen.show(
        context,
        triggerPerk: 'Custom Digital Signature & Stamp',
      );
      if (!upgraded && !VipService.instance.isVip) return;
    }
    if (!mounted) return;

    final result = await SignatureStampDialog.show(context);
    if (result != null && mounted) {
      setState(() {
        if (result.isSignature) {
          _signatureBytes = result.bytes;
        } else {
          _stampBytes = result.bytes;
          _stampTitle = result.title;
        }
        _isGenerating = true;
      });
      _generatePdf();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.documentName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leadingWidth: 80,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(CupertinoIcons.back), Text('Back')],
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Tooltip(
            message: _password != null ? 'Password Protected' : 'Encrypt PDF (VIP)',
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              onPressed: _showPasswordDialog,
              child: Icon(
                _password != null
                    ? CupertinoIcons.lock_shield_fill
                    : CupertinoIcons.lock,
                color: _password != null ? const Color(0xFFFFB300) : null,
                size: 22,
              ),
            ),
          ),
          Tooltip(
            message: _watermarkText != null
                ? 'Watermark: $_watermarkText'
                : 'Add Security Watermark',
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              onPressed: _showWatermarkDialog,
              child: Icon(
                _watermarkText != null
                    ? CupertinoIcons.checkmark_seal_fill
                    : CupertinoIcons.checkmark_seal,
                color: _watermarkText != null
                    ? CupertinoColors.activeBlue
                    : null,
                size: 22,
              ),
            ),
          ),
          if (_hasText)
            Tooltip(
              message: 'Export Text (.txt)',
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                onPressed: _exportPlainText,
                child: const Icon(CupertinoIcons.doc_plaintext, size: 22),
              ),
            ),
          if (_pdfBytes != null)
            CupertinoButton(
              padding: const EdgeInsets.only(left: 6, right: 16),
              child: const Icon(CupertinoIcons.share),
              onPressed: () async {
                await Printing.sharePdf(
                  bytes: _pdfBytes!,
                  filename: '${widget.documentName}.pdf',
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSettingsHeader(theme, isDark),
          Expanded(child: _buildBody(theme, isDark)),
        ],
      ),
    );
  }

  Widget _buildSettingsHeader(ThemeData theme, bool isDark) {
    final sizeKb =
        _pdfBytes != null ? (_pdfBytes!.length / 1024).round() : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Quality',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CupertinoSlidingSegmentedControl<PdfQuality>(
                  groupValue: _quality,
                  backgroundColor: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFE5E5EA),
                  children: const {
                    PdfQuality.lossless300Dpi: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.sparkles,
                              size: 11, color: Color(0xFFFFB300)),
                          SizedBox(width: 3),
                          Text('300 DPI',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    PdfQuality.high: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text('High', style: TextStyle(fontSize: 11)),
                    ),
                    PdfQuality.medium: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text('Balanced', style: TextStyle(fontSize: 11)),
                    ),
                    PdfQuality.compact: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text('Compact', style: TextStyle(fontSize: 11)),
                    ),
                  },
                  onValueChanged: (newQuality) async {
                    if (newQuality == null || newQuality == _quality) return;
                    if (newQuality == PdfQuality.lossless300Dpi &&
                        !VipService.instance.isVip) {
                      final upgraded = await VipPassScreen.show(
                        context,
                        triggerPerk: 'High-Res 300 DPI Lossless Scans',
                      );
                      if (!upgraded && !VipService.instance.isVip) return;
                    }
                    if (!mounted) return;
                    setState(() {
                      _quality = newQuality;
                      _isGenerating = true;
                    });
                    _generatePdf();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Tools Row: Watermark, Sign & Stamp (VIP), Password (VIP)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _showSignatureStampPicker,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.signature,
                        size: 16,
                        color: (_signatureBytes != null || _stampBytes != null)
                            ? const Color(0xFF2563EB)
                            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _signatureBytes != null
                              ? 'Signed'
                              : (_stampBytes != null
                                  ? 'Stamped'
                                  : 'Sign & Stamp (VIP)'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (_signatureBytes != null || _stampBytes != null)
                                ? const Color(0xFF2563EB)
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _showPasswordDialog,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Icon(
                        _password != null
                            ? CupertinoIcons.lock_shield_fill
                            : CupertinoIcons.lock,
                        size: 16,
                        color: _password != null
                            ? const Color(0xFFFFB300)
                            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _password != null ? 'Password Protected' : 'Encrypt PDF (VIP)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _password != null
                                ? const Color(0xFFFFB300)
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (sizeKb != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${sizeKb > 1024 ? (sizeKb / 1024).toStringAsFixed(1) : sizeKb} ${sizeKb > 1024 ? 'MB' : 'KB'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),

          // Active VIP Badges (removable)
          if (_password != null || _signatureBytes != null || _stampBytes != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (_password != null)
                  _buildActiveBadge(
                    icon: CupertinoIcons.lock_shield_fill,
                    color: const Color(0xFFFFB300),
                    label: 'Password Protected',
                    onRemove: () {
                      setState(() {
                        _password = null;
                        _isGenerating = true;
                      });
                      _generatePdf();
                    },
                  ),
                if (_signatureBytes != null)
                  _buildActiveBadge(
                    icon: CupertinoIcons.signature,
                    color: const Color(0xFF2563EB),
                    label: 'Digital Signature',
                    onRemove: () {
                      setState(() {
                        _signatureBytes = null;
                        _isGenerating = true;
                      });
                      _generatePdf();
                    },
                  ),
                if (_stampBytes != null)
                  _buildActiveBadge(
                    icon: CupertinoIcons.checkmark_seal_fill,
                    color: CupertinoColors.activeGreen,
                    label: _stampTitle ?? 'Official Stamp',
                    onRemove: () {
                      setState(() {
                        _stampBytes = null;
                        _stampTitle = null;
                        _isGenerating = true;
                      });
                      _generatePdf();
                    },
                  ),
              ],
            ),
          ],

          if (_hasText) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.doc_text_search,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Append OCR Text Page',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                CupertinoSwitch(
                  value: _includeTextPage,
                  onChanged: (val) {
                    setState(() {
                      _includeTextPage = val;
                      _isGenerating = true;
                    });
                    _generatePdf();
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveBadge({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              CupertinoIcons.clear_circled_solid,
              size: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_isGenerating) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CupertinoActivityIndicator(radius: 20),
            const SizedBox(height: 24),
            Text(
              'Rendering PDF...',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.imagePaths.length} page${widget.imagePaths.length == 1 ? '' : 's'}${_includeTextPage ? ' + 1 transcript' : ''}',
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 20),
              Text(
                'Failed to generate PDF',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 32),
              CupertinoButton.filled(
                onPressed: () {
                  setState(() {
                    _isGenerating = true;
                    _error = null;
                  });
                  _generatePdf();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // When encrypted, display secure locked preview card so Android's native unauthenticated PdfRenderer does not error
    if (_password != null && _pdfBytes != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E28) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFB300).withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.lock_shield_fill,
                    size: 38,
                    color: Color(0xFFFFB300),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Password-Protected PDF Ready',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Encrypted with standard ISO 32000-1 128-bit security handler. Recipients in Adobe Acrobat, Google Drive, or Chrome will be prompted to enter this password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(CupertinoIcons.share, size: 18),
                    label: const Text(
                      'Share Encrypted PDF',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      await Printing.sharePdf(
                        bytes: _pdfBytes!,
                        filename: '${widget.documentName}_encrypted.pdf',
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _showPasswordDialog,
                  child: const Text(
                    'Change or Remove Password',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PdfPreview(
      key: ValueKey(
        'pdf_${_quality.name}_${_includeTextPage}_${_pdfBytes?.length}_${_signatureBytes != null}_${_stampBytes != null}',
      ),
      build: (format) async => _pdfBytes!,
      allowSharing: false, // Handled in AppBar for clean UI
      allowPrinting: true,
      canChangePageFormat: false,
      pdfFileName: '${widget.documentName}.pdf',
      onError: (context, error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load PDF preview',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
