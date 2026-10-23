import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class SupportedLanguage {
  final TranslateLanguage language;
  final String englishName;
  final String nativeName;
  final String flag;

  const SupportedLanguage({
    required this.language,
    required this.englishName,
    required this.nativeName,
    required this.flag,
  });

  String get displayName => '$englishName ($nativeName)';
}

class TranslationLanguages {
  static const List<SupportedLanguage> popularLanguages = [
    SupportedLanguage(
      language: TranslateLanguage.hindi,
      englishName: 'Hindi',
      nativeName: 'हिन्दी',
      flag: '🇮🇳',
    ),
    SupportedLanguage(
      language: TranslateLanguage.english,
      englishName: 'English',
      nativeName: 'English',
      flag: '🇺🇸',
    ),
    SupportedLanguage(
      language: TranslateLanguage.spanish,
      englishName: 'Spanish',
      nativeName: 'Español',
      flag: '🇪🇸',
    ),
    SupportedLanguage(
      language: TranslateLanguage.french,
      englishName: 'French',
      nativeName: 'Français',
      flag: '🇫🇷',
    ),
    SupportedLanguage(
      language: TranslateLanguage.german,
      englishName: 'German',
      nativeName: 'Deutsch',
      flag: '🇩🇪',
    ),
    SupportedLanguage(
      language: TranslateLanguage.japanese,
      englishName: 'Japanese',
      nativeName: '日本語',
      flag: '🇯🇵',
    ),
    SupportedLanguage(
      language: TranslateLanguage.chinese,
      englishName: 'Chinese',
      nativeName: '中文',
      flag: '🇨🇳',
    ),
    SupportedLanguage(
      language: TranslateLanguage.arabic,
      englishName: 'Arabic',
      nativeName: 'العربية',
      flag: '🇸🇦',
    ),
    SupportedLanguage(
      language: TranslateLanguage.portuguese,
      englishName: 'Portuguese',
      nativeName: 'Português',
      flag: '🇧🇷',
    ),
    SupportedLanguage(
      language: TranslateLanguage.russian,
      englishName: 'Russian',
      nativeName: 'Русский',
      flag: '🇷🇺',
    ),
    SupportedLanguage(
      language: TranslateLanguage.italian,
      englishName: 'Italian',
      nativeName: 'Italiano',
      flag: '🇮🇹',
    ),
    SupportedLanguage(
      language: TranslateLanguage.korean,
      englishName: 'Korean',
      nativeName: '한국어',
      flag: '🇰🇷',
    ),
    SupportedLanguage(
      language: TranslateLanguage.bengali,
      englishName: 'Bengali',
      nativeName: 'বাংলা',
      flag: '🇮🇳',
    ),
    SupportedLanguage(
      language: TranslateLanguage.telugu,
      englishName: 'Telugu',
      nativeName: 'తెలుగు',
      flag: '🇮🇳',
    ),
    SupportedLanguage(
      language: TranslateLanguage.marathi,
      englishName: 'Marathi',
      nativeName: 'मराठी',
      flag: '🇮🇳',
    ),
    SupportedLanguage(
      language: TranslateLanguage.tamil,
      englishName: 'Tamil',
      nativeName: 'தமிழ்',
      flag: '🇮🇳',
    ),
    SupportedLanguage(
      language: TranslateLanguage.urdu,
      englishName: 'Urdu',
      nativeName: 'اردو',
      flag: '🇵🇰',
    ),
    SupportedLanguage(
      language: TranslateLanguage.gujarati,
      englishName: 'Gujarati',
      nativeName: 'ગુજરાતી',
      flag: '🇮🇳',
    ),
    SupportedLanguage(
      language: TranslateLanguage.kannada,
      englishName: 'Kannada',
      nativeName: 'ಕನ್ನಡ',
      flag: '🇮🇳',
    ),
    SupportedLanguage(
      language: TranslateLanguage.indonesian,
      englishName: 'Indonesian',
      nativeName: 'Bahasa Indonesia',
      flag: '🇮🇩',
    ),
    SupportedLanguage(
      language: TranslateLanguage.turkish,
      englishName: 'Turkish',
      nativeName: 'Türkçe',
      flag: '🇹🇷',
    ),
    SupportedLanguage(
      language: TranslateLanguage.vietnamese,
      englishName: 'Vietnamese',
      nativeName: 'Tiếng Việt',
      flag: '🇻🇳',
    ),
    SupportedLanguage(
      language: TranslateLanguage.dutch,
      englishName: 'Dutch',
      nativeName: 'Nederlands',
      flag: '🇳🇱',
    ),
    SupportedLanguage(
      language: TranslateLanguage.polish,
      englishName: 'Polish',
      nativeName: 'Polski',
      flag: '🇵🇱',
    ),
    SupportedLanguage(
      language: TranslateLanguage.thai,
      englishName: 'Thai',
      nativeName: 'ไทย',
      flag: '🇹🇭',
    ),
    SupportedLanguage(
      language: TranslateLanguage.ukrainian,
      englishName: 'Ukrainian',
      nativeName: 'Українська',
      flag: '🇺🇦',
    ),
    SupportedLanguage(
      language: TranslateLanguage.swedish,
      englishName: 'Swedish',
      nativeName: 'Svenska',
      flag: '🇸🇪',
    ),
  ];

  static SupportedLanguage fromBcpCode(String bcpCode) {
    return popularLanguages.firstWhere(
      (lang) => lang.language.bcpCode == bcpCode,
      orElse: () {
        final lang = TranslateLanguage.values.firstWhere(
          (l) => l.bcpCode == bcpCode,
          orElse: () => TranslateLanguage.hindi,
        );
        return SupportedLanguage(
          language: lang,
          englishName: _capitalize(lang.name),
          nativeName: _capitalize(lang.name),
          flag: '🌐',
        );
      },
    );
  }

  static SupportedLanguage fromTranslateLanguage(TranslateLanguage lang) {
    return popularLanguages.firstWhere(
      (l) => l.language == lang,
      orElse: () => SupportedLanguage(
        language: lang,
        englishName: _capitalize(lang.name),
        nativeName: _capitalize(lang.name),
        flag: '🌐',
      ),
    );
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
