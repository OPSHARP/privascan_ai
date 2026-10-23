class AppConstants {
  static const String appName = 'PrivaScan AI';
  static const String appVersion = '1.0.6';

  static const int freeDailySummaryLimit = 3;

  static const int ocrTimeoutMs = 1500;
  static const int aiResponseTimeoutMs = 3000;

  static const int maxRamUsageMB = 450;
  static const int baseBinarySizeMB = 40;

  static const String dbName = 'privascan_db';
  static const String documentsBox = 'documents';
  static const String settingsBox = 'settings';
  static const String tagsBox = 'tags';
  static const String trashTag = 'system_trash';

  static const String themeModeKey = 'theme_mode';
  static const String targetLanguageKey = 'target_language';

  static const List<String> filterOptions = [
    'Original',
    'Magic Color',
    'B&W',
    'Grayscale',
  ];

  static const List<String> aiActionTemplates = [
    'Quick Summary',
    'Action Items',
    'Key Entities',
    'Custom',
  ];
}
