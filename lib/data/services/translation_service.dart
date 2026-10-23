import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationService {
  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();
  final LanguageIdentifier _languageIdentifier =
      LanguageIdentifier(confidenceThreshold: 0.3);

  /// All supported languages with display labels for dropdown
  static const List<Map<String, dynamic>> supportedLanguages = [
    {'label': 'Auto Detect', 'code': 'auto', 'lang': null},
    {'label': 'English', 'code': 'en', 'lang': TranslateLanguage.english},
    {'label': 'Hindi', 'code': 'hi', 'lang': TranslateLanguage.hindi},
    {'label': 'Spanish', 'code': 'es', 'lang': TranslateLanguage.spanish},
    {'label': 'French', 'code': 'fr', 'lang': TranslateLanguage.french},
    {'label': 'German', 'code': 'de', 'lang': TranslateLanguage.german},
    {'label': 'Italian', 'code': 'it', 'lang': TranslateLanguage.italian},
    {'label': 'Portuguese', 'code': 'pt', 'lang': TranslateLanguage.portuguese},
    {'label': 'Russian', 'code': 'ru', 'lang': TranslateLanguage.russian},
    {'label': 'Chinese', 'code': 'zh', 'lang': TranslateLanguage.chinese},
    {'label': 'Japanese', 'code': 'ja', 'lang': TranslateLanguage.japanese},
    {'label': 'Korean', 'code': 'ko', 'lang': TranslateLanguage.korean},
    {'label': 'Arabic', 'code': 'ar', 'lang': TranslateLanguage.arabic},
    {'label': 'Bengali', 'code': 'bn', 'lang': TranslateLanguage.bengali},
    {'label': 'Gujarati', 'code': 'gu', 'lang': TranslateLanguage.gujarati},
    {'label': 'Kannada', 'code': 'kn', 'lang': TranslateLanguage.kannada},
    {'label': 'Marathi', 'code': 'mr', 'lang': TranslateLanguage.marathi},
    {'label': 'Tamil', 'code': 'ta', 'lang': TranslateLanguage.tamil},
    {'label': 'Telugu', 'code': 'te', 'lang': TranslateLanguage.telugu},
    {'label': 'Urdu', 'code': 'ur', 'lang': TranslateLanguage.urdu},
    {'label': 'Turkish', 'code': 'tr', 'lang': TranslateLanguage.turkish},
    {'label': 'Vietnamese', 'code': 'vi', 'lang': TranslateLanguage.vietnamese},
    {'label': 'Thai', 'code': 'th', 'lang': TranslateLanguage.thai},
    {'label': 'Indonesian', 'code': 'id', 'lang': TranslateLanguage.indonesian},
    {'label': 'Malay', 'code': 'ms', 'lang': TranslateLanguage.malay},
    {'label': 'Dutch', 'code': 'nl', 'lang': TranslateLanguage.dutch},
    {'label': 'Polish', 'code': 'pl', 'lang': TranslateLanguage.polish},
    {'label': 'Romanian', 'code': 'ro', 'lang': TranslateLanguage.romanian},
    {'label': 'Swedish', 'code': 'sv', 'lang': TranslateLanguage.swedish},
    {'label': 'Czech', 'code': 'cs', 'lang': TranslateLanguage.czech},
    {'label': 'Ukrainian', 'code': 'uk', 'lang': TranslateLanguage.ukrainian},
  ];

  /// BCP code → TranslateLanguage mapping for auto-detect resolution
  static TranslateLanguage? languageFromBcp(String bcpCode) {
    for (final entry in supportedLanguages) {
      if (entry['code'] == bcpCode && entry['lang'] != null) {
        return entry['lang'] as TranslateLanguage;
      }
    }
    return null;
  }

  Future<bool> isModelDownloaded(TranslateLanguage language) async {
    return await _modelManager.isModelDownloaded(language.bcpCode);
  }

  Future<void> downloadModel(TranslateLanguage language) async {
    await _modelManager.downloadModel(language.bcpCode);
  }

  /// Auto-detect the language of the given text
  Future<TranslateLanguage?> detectLanguage(String text) async {
    if (text.trim().isEmpty) return null;
    try {
      final String langCode = await _languageIdentifier.identifyLanguage(text);
      if (langCode == 'und') return null; // undetermined
      return languageFromBcp(langCode);
    } catch (_) {
      return null;
    }
  }

  Future<String> translateText(
      String text, TranslateLanguage source, TranslateLanguage target) async {
    if (text.isEmpty) return '';
    if (source == target) return text;

    final isSourceDownloaded = await isModelDownloaded(source);
    final isTargetDownloaded = await isModelDownloaded(target);

    if (!isSourceDownloaded) {
      await downloadModel(source);
    }
    if (!isTargetDownloaded) {
      await downloadModel(target);
    }

    final translator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );

    try {
      final String response = await translator.translateText(text);
      return response;
    } finally {
      translator.close();
    }
  }

  Future<void> deleteModel(TranslateLanguage language) async {
    await _modelManager.deleteModel(language.bcpCode);
  }

  void dispose() {
    _languageIdentifier.close();
  }
}
