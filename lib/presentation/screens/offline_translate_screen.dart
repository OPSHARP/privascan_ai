import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/services/translation_service.dart';
import '../../data/services/tts_service.dart';

class OfflineTranslateScreen extends StatefulWidget {
  final String initialText;

  const OfflineTranslateScreen({
    super.key,
    this.initialText = '',
  });

  @override
  State<OfflineTranslateScreen> createState() => _OfflineTranslateScreenState();
}

class _OfflineTranslateScreenState extends State<OfflineTranslateScreen> {
  final TextEditingController _inputController = TextEditingController();
  final TranslationService _translationService = TranslationService();
  final TtsService _ttsService = TtsService.instance;
  final List<Map<String, dynamic>> _languages = TranslationService.supportedLanguages;

  // 0 is Auto Detect, 2 is Hindi (default)
  int _sourceIndex = 0;
  int _targetIndex = 2; // Hindi
  String _translatedText = '';
  String? _detectedLangLabel;
  bool _isTranslating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialText.isNotEmpty) {
      _inputController.text = widget.initialText;
    }
    _ttsService.init();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _ttsService.stop();
    super.dispose();
  }

  Future<void> _performTranslation() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter or paste some text to translate.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    setState(() {
      _isTranslating = true;
      _errorMessage = null;
      _detectedLangLabel = null;
    });

    try {
      TranslateLanguage srcLang;
      if (_sourceIndex == 0) {
        // Auto detect language
        final detected = await _translationService.detectLanguage(text);
        if (detected == null) {
          setState(() {
            _isTranslating = false;
            _errorMessage = 'Could not detect language automatically. Please select source language manually.';
          });
          return;
        }
        srcLang = detected;
        for (final entry in _languages) {
          if (entry['lang'] == detected) {
            _detectedLangLabel = entry['label'] as String;
            break;
          }
        }
      } else {
        srcLang = _languages[_sourceIndex]['lang'] as TranslateLanguage;
      }

      final tgtLang = _languages[_targetIndex]['lang'] as TranslateLanguage;
      final result = await _translationService.translateText(text, srcLang, tgtLang);

      if (!mounted) return;
      setState(() {
        _isTranslating = false;
        _translatedText = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTranslating = false;
        _errorMessage = 'Translation failed. Make sure you have downloaded required language packs.';
      });
    }
  }

  void _swapLanguages() {
    if (_sourceIndex == 0) {
      // Cannot swap when Auto Detect is source
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a specific source language to swap.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      final oldSource = _sourceIndex;
      _sourceIndex = _targetIndex;
      _targetIndex = oldSource;

      // Also swap texts if translated exists
      if (_translatedText.isNotEmpty) {
        final oldInput = _inputController.text;
        _inputController.text = _translatedText;
        _translatedText = oldInput;
      }
    });
  }

  void _showLanguagePicker({required bool isSource}) {
    HapticFeedback.selectionClick();
    final pickerLangs = isSource
        ? _languages
        : _languages.where((l) => l['code'] != 'auto').toList();

    int tempIndex = isSource
        ? _sourceIndex
        : pickerLangs.indexWhere((l) => l['label'] == _languages[_targetIndex]['label']);
    if (tempIndex < 0) tempIndex = 0;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: CupertinoColors.separator.resolveFrom(context),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  Text(
                    isSource ? 'Select Source Language' : 'Select Target Language',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      setState(() {
                        if (isSource) {
                          _sourceIndex = tempIndex;
                        } else {
                          final selectedLabel = pickerLangs[tempIndex]['label'] as String;
                          _targetIndex = _languages.indexWhere((l) => l['label'] == selectedLabel);
                        }
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(initialItem: tempIndex),
                itemExtent: 42,
                onSelectedItemChanged: (idx) => tempIndex = idx,
                children: pickerLangs
                    .map(
                      (l) => Center(
                        child: Text(
                          l['label'] as String,
                          style: const TextStyle(fontSize: 17),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _inputController.text = data.text!;
      });
      _performTranslation();
    }
  }

  void _speakTranslatedText() {
    if (_translatedText.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    final langCode = _languages[_targetIndex]['code'] as String?;
    _ttsService.speak(_translatedText, languageCode: langCode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sourceLabel = _languages[_sourceIndex]['label'] as String;
    final targetLabel = _languages[_targetIndex]['label'] as String;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Offline Translator',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.checkmark_shield_fill, color: Color(0xFF10B981), size: 14),
                SizedBox(width: 4),
                Text(
                  '100% Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Language Selector Bar
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Source
                    Expanded(
                      child: InkWell(
                        onTap: () => _showLanguagePicker(isSource: true),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'FROM',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      sourceLabel,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(CupertinoIcons.chevron_down, size: 14),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Swap Button
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.arrow_right_arrow_left,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      onPressed: _swapLanguages,
                      tooltip: 'Swap Languages',
                    ),

                    // Target
                    Expanded(
                      child: InkWell(
                        onTap: () => _showLanguagePicker(isSource: false),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'TO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      targetLabel,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(CupertinoIcons.chevron_down, size: 14),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Source Input Box
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Enter Text',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          Row(
                            children: [
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                onPressed: _pasteFromClipboard,
                                child: const Row(
                                  children: [
                                    Icon(CupertinoIcons.doc_on_clipboard, size: 16),
                                    SizedBox(width: 4),
                                    Text('Paste', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              if (_inputController.text.isNotEmpty)
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  onPressed: () {
                                    setState(() {
                                      _inputController.clear();
                                      _translatedText = '';
                                      _detectedLangLabel = null;
                                      _errorMessage = null;
                                    });
                                  },
                                  child: const Icon(CupertinoIcons.clear_circled_solid, size: 18),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    TextField(
                      controller: _inputController,
                      maxLines: 5,
                      minLines: 3,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                      decoration: InputDecoration(
                        hintText: 'Type, paste, or scan text to translate instantly...',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Translate Action Button
              Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _isTranslating ? null : _performTranslation,
                  child: _isTranslating
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CupertinoActivityIndicator(color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              'Translating On-Device...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.globe, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Translate Now',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // Error banner if any
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.red, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 13, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Detected language indicator
              if (_detectedLangLabel != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.sparkles, color: Color(0xFF3B82F6), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Auto Detected: $_detectedLangLabel',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Translated Result Card
              if (_translatedText.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Translation ($targetLabel)',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(CupertinoIcons.speaker_2_fill, size: 18),
                                  tooltip: 'Listen via TTS',
                                  color: theme.colorScheme.primary,
                                  onPressed: _speakTranslatedText,
                                ),
                                IconButton(
                                  icon: const Icon(CupertinoIcons.doc_on_doc, size: 18),
                                  tooltip: 'Copy Translation',
                                  color: theme.colorScheme.primary,
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: _translatedText));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Translation copied to clipboard!'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(CupertinoIcons.share, size: 18),
                                  tooltip: 'Share',
                                  color: theme.colorScheme.primary,
                                  onPressed: () {
                                    SharePlus.instance.share(
                                      ShareParams(
                                        text: _translatedText,
                                        subject: 'Translated via PrivaScan AI',
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          _translatedText,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Bottom Privacy Footnote
              Center(
                child: Text(
                  '🔒 100% Private: All translations run on-device using ML Kit.\nZero data is sent to external cloud servers.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
