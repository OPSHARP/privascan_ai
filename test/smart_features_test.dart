import 'package:flutter_test/flutter_test.dart';
import 'package:privascan_ai/data/services/document_classifier_service.dart';
import 'package:privascan_ai/data/services/table_detection_service.dart';
import 'package:privascan_ai/domain/entities/document.dart';

void main() {
  group('DocumentClassifierService & Categorization Heuristics', () {
    test('correctly identifies receipts from tax, invoice, total keywords', () {
      const receiptText = '''
        STARBUCKS COFFEE #1042
        TOTAL: \$14.50
        TAX: \$1.20
        THANK YOU FOR YOUR PAYMENT
        VISA ENDING IN 4421
      ''';
      final category = DocumentClassifierService.classify(
        text: receiptText,
        title: 'Starbucks Coffee',
      );
      expect(category.id, equals(DocumentClassifierService.receipts.id));
      expect(category.name, equals(DocumentClassifierService.receipts.name));
    });

    test('correctly identifies ID cards and passports from driver license, passport keywords', () {
      const idText = '''
        STATE DRIVER LICENSE
        DOB: 12/04/1990
        EXP: 12/04/2030
        NATIONAL IDENTIFICATION CARD
      ''';
      final category = DocumentClassifierService.classify(
        text: idText,
        title: 'Driver License',
      );
      expect(category.id, equals(DocumentClassifierService.ids.id));
      expect(category.name, equals(DocumentClassifierService.ids.name));
    });

    test('correctly identifies medical documents from prescription, clinic, patient keywords', () {
      const medicalText = '''
        METROPOLITAN HOSPITAL
        PATIENT: JANE DOE
        DIAGNOSIS: ACUTE BRONCHITIS
        RX: AMOXICILLIN 500MG
        DOCTOR: DR. SMITH MD
      ''';
      final category = DocumentClassifierService.classify(
        text: medicalText,
        title: 'Clinic Visit',
      );
      expect(category.id, equals(DocumentClassifierService.medical.id));
      expect(category.name, equals(DocumentClassifierService.medical.name));
    });

    test('correctly identifies legal contracts from agreement, terms, signature keywords', () {
      const legalText = '''
        NON-DISCLOSURE AGREEMENT
        BY AND BETWEEN THE PARTIES
        IN WITNESS WHEREOF, THE UNDERSIGNED HAVE EXECUTED THIS CONTRACT
        GOVERNING LAW AND JURISDICTION
      ''';
      final category = DocumentClassifierService.classify(
        text: legalText,
        title: 'NDA Agreement',
      );
      expect(category.id, equals(DocumentClassifierService.legal.id));
      expect(category.name, equals(DocumentClassifierService.legal.name));
    });

    test('correctly classifies meeting notes and agendas', () {
      const notesText = '''
        WEEKLY SPRINT PLANNING
        ACTION ITEMS AND AGENDA
        MEETING MINUTES FOR Q3
        TODO: COMPLETE CODE REVIEW
      ''';
      final category = DocumentClassifierService.classify(
        text: notesText,
        title: 'Sprint Notes',
      );
      expect(category.id, equals(DocumentClassifierService.notes.id));
      expect(category.name, equals(DocumentClassifierService.notes.name));
    });

    test('falls back to Other category for generic text', () {
      const genericText = 'The quick brown fox jumps over the lazy dog.';
      final category = DocumentClassifierService.classify(
        text: genericText,
        title: 'Untitled Scan',
      );
      expect(category.id, equals(DocumentClassifierService.other.id));
      expect(category.name, equals(DocumentClassifierService.other.name));
    });

    test('Document primaryCategory resolves correctly when explicit tag is set', () {
      final doc = Document(
        id: 'test-1',
        name: 'My Receipt',
        imagePaths: const ['/test.jpg'],
        tags: [DocumentClassifierService.receipts.id],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(doc.primaryCategory, equals(DocumentClassifierService.receipts.id));
    });

    test('Document primaryCategory returns null when no category tag is present', () {
      final doc = Document(
        id: 'test-2',
        name: 'Untagged Document',
        imagePaths: const ['/test.jpg'],
        tags: const ['custom_tag_1', 'custom_tag_2'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(doc.primaryCategory, isNull);
    });
  });

  group('Smart Auto-Naming (DocumentClassifierService.suggestTitle)', () {
    test('suggests title from header line and merchant name', () {
      const ocrText = '''
        BLUE BOTTLE COFFEE
        123 Market St, San Francisco
        Date: 10/24/2026
        Order #4412
        Total: \$8.75
      ''';
      final suggested = DocumentClassifierService.suggestTitle(
        text: ocrText,
        currentTitle: 'Scan 2026-10-22',
      );
      expect(suggested.isNotEmpty, isTrue);
      expect(suggested.toLowerCase().contains('blue bottle coffee'), isTrue);
    });

    test('suggests title with category prefix when category is provided', () {
      const ocrText = '''
        BLOOD TEST LAB REPORT
        Patient: Jane Doe
        Date: 15/09/2026
        WBC Count: Normal
      ''';
      final suggested = DocumentClassifierService.suggestTitle(
        text: ocrText,
        currentTitle: 'Document 1',
        category: DocumentClassifierService.medical,
      );
      expect(suggested.contains('Medical Report'), isTrue);
    });
  });

  group('TableDetectionService (Table Extraction & RFC 4180 CSV)', () {
    test('detects pipe-delimited tables and outputs valid CSV', () {
      const tableText = '''
        Item | Qty | Price | Total
        Apple | 2 | \$1.50 | \$3.00
        Banana | 5 | \$0.50 | \$2.50
      ''';
      final service = TableDetectionService();
      final result = service.detectTable(tableText);

      expect(result.hasTable, isTrue);
      expect(result.headers, equals(['Item', 'Qty', 'Price', 'Total']));
      expect(result.rows.length, equals(2));
      expect(result.csvContent.contains('Item,Qty,Price,Total'), isTrue);
      expect(result.csvContent.contains('Apple,2,\$1.50,\$3.00'), isTrue);
    });

    test('detects item-price invoice pattern without explicit delimiters', () {
      const invoiceText = '''
        Web Hosting 120.00
        Domain Name 15.00
        SSL Certificate 49.00
      ''';
      final service = TableDetectionService();
      final result = service.detectTable(invoiceText);

      expect(result.hasTable, isTrue);
      expect(result.rows.length, equals(3));
      expect(result.csvContent.contains('Web Hosting'), isTrue);
    });
  });
}
