import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:privascan_ai/domain/entities/document.dart';
import 'package:privascan_ai/data/services/translation_languages.dart';

void main() {
  group('Document Full-Text OCR Search Snippet', () {
    test('returns surrounding snippet when query matches extracted OCR text', () {
      final doc = Document(
        id: 'doc-1',
        name: 'Invoice #1024',
        imagePaths: const ['/dummy/path.jpg'],
        extractedText: 'Company ABC. Total amount due is \$1,450.00 for services rendered in March 2026. Payment due upon receipt.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final snippet = doc.getSearchSnippet('1,450.00', contextLength: 20);
      expect(snippet, isNotNull);
      expect(snippet!.contains('1,450.00'), isTrue);
      expect(snippet.contains('amount due'), isTrue);
    });

    test('case-insensitive match for OCR search', () {
      final doc = Document(
        id: 'doc-2',
        name: 'Doctor Note',
        imagePaths: const ['/dummy/doc.jpg'],
        extractedText: 'Patient diagnosed with Acute Bronchitis. Prescribed Amoxicillin 500mg twice daily.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final snippet = doc.getSearchSnippet('amoxicillin');
      expect(snippet, isNotNull);
      expect(snippet!.toLowerCase().contains('amoxicillin'), isTrue);
    });

    test('returns null when query is not in extractedText', () {
      final doc = Document(
        id: 'doc-3',
        name: 'Receipt',
        imagePaths: const ['/dummy/receipt.jpg'],
        extractedText: 'Coffee Shop: 1 Espresso, \$4.50',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final snippet = doc.getSearchSnippet('Dentist');
      expect(snippet, isNull);
    });

    test('returns null when extractedText is empty', () {
      final doc = Document(
        id: 'doc-4',
        name: 'Blank Scan',
        imagePaths: const ['/dummy/blank.jpg'],
        extractedText: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final snippet = doc.getSearchSnippet('test');
      expect(snippet, isNull);
    });
  });

  group('TranslationLanguages Catalog', () {
    test('popular languages list includes key languages with flags and native names', () {
      expect(TranslationLanguages.popularLanguages.isNotEmpty, isTrue);

      final hindi = TranslationLanguages.popularLanguages.firstWhere(
        (l) => l.language == TranslateLanguage.hindi,
      );
      expect(hindi.englishName, equals('Hindi'));
      expect(hindi.nativeName, equals('हिन्दी'));
      expect(hindi.flag, equals('🇮🇳'));

      final spanish = TranslationLanguages.popularLanguages.firstWhere(
        (l) => l.language == TranslateLanguage.spanish,
      );
      expect(spanish.englishName, equals('Spanish'));
      expect(spanish.flag, equals('🇪🇸'));
    });

    test('fromBcpCode correctly resolves known language code', () {
      final lang = TranslationLanguages.fromBcpCode('ja');
      expect(lang.language, equals(TranslateLanguage.japanese));
      expect(lang.englishName, equals('Japanese'));
      expect(lang.flag, equals('🇯🇵'));
    });

    test('fromBcpCode falls back gracefully for unknown code', () {
      final lang = TranslationLanguages.fromBcpCode('unknown_code');
      expect(lang, isNotNull);
      expect(lang.displayName.isNotEmpty, isTrue);
    });
  });
}
