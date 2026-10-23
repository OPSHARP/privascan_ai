import 'package:flutter_test/flutter_test.dart';
import 'package:privascan_ai/data/services/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AiService aiService;

  setUp(() {
    aiService = AiService();
  });

  group('AiService - Entity Detection', () {
    test('detects email, phone, url, amount, and date from text', () {
      const sample = '''
        Invoice #1042 issued on 15/04/2026.
        Please contact support@example.com or call 555-019-2834.
        The total due is \$450.00.
        Visit https://privascan.app for payment guidelines.
      ''';

      final entities = AiService.detectEntities(sample);

      expect(entities.isNotEmpty, isTrue);
      expect(entities.emails, contains('support@example.com'));
      expect(entities.phones, contains('555-019-2834'));
      expect(entities.amounts, contains('\$450.00'));
      expect(entities.urls, contains('https://privascan.app'));
      expect(entities.dates, contains('15/04/2026'));
    });

    test('returns empty entity lists for plain text without entities', () {
      const sample = 'This is simple plain text without any contact or financial metadata.';
      final entities = AiService.detectEntities(sample);
      expect(entities.isEmpty, isTrue);
    });
  });

  group('AiService - Extractive Summarizer', () {
    test('generates Quick Summary with sentence weighting', () async {
      const sample = '''
        Artificial intelligence has advanced document workflows significantly.
        Privacy-first scanning ensures sensitive receipts and contracts never leave the user device.
        On-device processing eliminates cloud subscription costs and prevents data leaks.
        Document indexing enables instant search and offline access anywhere.
      ''';

      final summary = await aiService.generateSummary(sample, 'Quick Summary');

      expect(summary, isNotEmpty);
      expect(summary.contains('•'), isTrue);
    });

    test('extracts key entities summary format', () async {
      const sample = 'Payment of \$120.50 sent to billing@service.com on 2026-10-21.';
      final result = await aiService.generateSummary(sample, 'Key Entities');

      expect(result, contains('Structured Key Entities'));
      expect(result, contains('billing@service.com'));
    });

    test('answers custom question by semantic term matching', () async {
      const sample = '''
        The annual membership fee is \$120.
        All cancellations must be submitted 30 days before renewal.
        Customer support is available Monday through Friday.
      ''';

      final answer = await aiService.answerCustomQuestion(sample, 'What is the fee?');
      expect(answer, contains('Relevant excerpt found:'));
      expect(answer, contains('\$120'));
    });
  });
}
