import 'package:flutter/cupertino.dart';

class DocumentCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const DocumentCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

class DocumentClassifierService {
  static const DocumentCategory receipts = DocumentCategory(
    id: 'category_receipts',
    name: 'Receipts & Invoices',
    icon: CupertinoIcons.doc_plaintext,
    color: Color(0xFF10B981), // Emerald green
  );

  static const DocumentCategory ids = DocumentCategory(
    id: 'category_ids',
    name: 'IDs & Official',
    icon: CupertinoIcons.person_crop_square_fill,
    color: Color(0xFF3B82F6), // Blue
  );

  static const DocumentCategory medical = DocumentCategory(
    id: 'category_medical',
    name: 'Medical',
    icon: CupertinoIcons.heart_fill,
    color: Color(0xFFEF4444), // Red
  );

  static const DocumentCategory legal = DocumentCategory(
    id: 'category_legal',
    name: 'Contracts & Legal',
    icon: CupertinoIcons.briefcase_fill,
    color: Color(0xFF8B5CF6), // Purple
  );

  static const DocumentCategory notes = DocumentCategory(
    id: 'category_notes',
    name: 'Notes & Study',
    icon: CupertinoIcons.pencil_outline,
    color: Color(0xFFF59E0B), // Amber
  );

  static const DocumentCategory other = DocumentCategory(
    id: 'category_other',
    name: 'Other',
    icon: CupertinoIcons.folder_fill,
    color: Color(0xFF6B7280), // Slate grey
  );

  static const List<DocumentCategory> allCategories = [
    receipts,
    ids,
    medical,
    legal,
    notes,
    other,
  ];

  static DocumentCategory getCategoryById(String? id) {
    if (id == null) return other;
    return allCategories.firstWhere(
      (cat) => cat.id == id || cat.name.toLowerCase() == id.toLowerCase(),
      orElse: () => other,
    );
  }

  /// Categorizes a document based on its title and extracted OCR text using fast on-device keyword heuristics.
  static DocumentCategory classify({String? title, String? text}) {
    final combined = '${title ?? ''} ${text ?? ''}'.toLowerCase();
    if (combined.trim().isEmpty) return other;

    // 1. Receipts & Invoices
    final receiptKeywords = [
      'receipt',
      'invoice',
      'subtotal',
      'total amount',
      'grand total',
      'total:',
      'total',
      'tax invoice',
      'sales tax',
      'tax:',
      'tax',
      'gstin',
      'vat',
      'cashier',
      'pos',
      'billed to',
      'payment received',
      'payment',
      'amount paid',
      'balance due',
      'itemized',
      'qty',
      'bill to',
      'order no',
      'transaction',
      'visa',
      'mastercard',
    ];
    int receiptScore = _countMatches(combined, receiptKeywords);

    // 2. IDs & Official documents
    final idKeywords = [
      'passport',
      'driving license',
      'driver license',
      'identity card',
      'national id',
      'republic of',
      'citizen',
      'date of birth',
      'dob:',
      'expiry date',
      'issued by',
      'aadhaar',
      'pan card',
      'voter id',
      'social security',
      'identification',
      'ssn',
      'card no',
    ];
    int idScore = _countMatches(combined, idKeywords);

    // 3. Medical records & prescriptions
    final medicalKeywords = [
      'patient',
      'hospital',
      'clinic',
      'prescription',
      'rx',
      'doctor',
      'dr.',
      'diagnosis',
      'blood pressure',
      'laboratory',
      'mg tablet',
      'dosage',
      'pharmacy',
      'physician',
      'clinical',
      'symptoms',
      'treatment',
    ];
    int medicalScore = _countMatches(combined, medicalKeywords);

    // 4. Contracts & Legal agreements
    final legalKeywords = [
      'agreement',
      'contract',
      'hereby',
      'witnesseth',
      'signatory',
      'in witness whereof',
      'party of the first',
      'party of the second',
      'lease agreement',
      'terms and conditions',
      'confidentiality',
      'nondisclosure',
      'tenant',
      'landlord',
      'indemnify',
      'governing law',
    ];
    int legalScore = _countMatches(combined, legalKeywords);

    // 5. Notes & Study material
    final notesKeywords = [
      'lecture',
      'chapter',
      'homework',
      'assignment',
      'syllabus',
      'notes',
      'study guide',
      'exam',
      'quiz',
      'semester',
      'exercise',
      'page number',
      'agenda',
      'meeting',
      'todo',
      'action items',
      'minutes',
    ];
    int notesScore = _countMatches(combined, notesKeywords);

    // Determine highest score
    final scores = {
      receipts: receiptScore,
      ids: idScore,
      medical: medicalScore,
      legal: legalScore,
      notes: notesScore,
    };

    var bestCategory = other;
    int maxScore = 0;

    scores.forEach((category, score) {
      if (score > maxScore) {
        maxScore = score;
        bestCategory = category;
      }
    });

    return maxScore > 0 ? bestCategory : other;
  }

  static int _countMatches(String text, List<String> keywords) {
    int count = 0;
    for (final kw in keywords) {
      if (text.contains(kw)) {
        count++;
      }
    }
    return count;
  }

  /// Generates a clean, contextual document title based on extracted OCR text, date, and category.
  static String suggestTitle({
    required String text,
    String? currentTitle,
    DocumentCategory? category,
  }) {
    if (text.trim().isEmpty) {
      final now = DateTime.now();
      return currentTitle ?? 'Scan ${now.month}/${now.day}/${now.year}';
    }

    final cat = category ?? classify(text: text, title: currentTitle);
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.length >= 3 && !RegExp(r'^[0-9\W]+$').hasMatch(l))
        .toList();

    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateStr = '${months[now.month - 1]} ${now.day}';

    // 1. Receipts & Invoices
    if (cat.id == receipts.id) {
      if (lines.isNotEmpty) {
        String vendor = lines.first;
        if (vendor.length > 24) vendor = vendor.substring(0, 24).trim();
        vendor = _toTitleCase(vendor);
        return '$vendor Receipt - $dateStr';
      }
      return 'Receipt - $dateStr';
    }

    // 2. IDs & Official
    if (cat.id == ids.id) {
      final lower = text.toLowerCase();
      if (lower.contains('passport')) return 'Passport - $dateStr';
      if (lower.contains('driver')) return 'Driver License - $dateStr';
      if (lower.contains('aadhaar')) return 'Aadhaar Card - $dateStr';
      if (lower.contains('pan')) return 'PAN Card - $dateStr';
      if (lower.contains('voter')) return 'Voter ID - $dateStr';
      return 'Identity Card - $dateStr';
    }

    // 3. Medical
    if (cat.id == medical.id) {
      final lower = text.toLowerCase();
      String medType = 'Medical Report';
      if (lower.contains('prescription') || lower.contains('rx')) {
        medType = 'Prescription';
      }
      if (lines.isNotEmpty) {
        String clinic = lines.first;
        if (clinic.length > 24) clinic = clinic.substring(0, 24).trim();
        clinic = _toTitleCase(clinic);
        return '$clinic - $medType';
      }
      return '$medType - $dateStr';
    }

    // 4. Contracts & Legal
    if (cat.id == legal.id) {
      final lower = text.toLowerCase();
      if (lower.contains('non-disclosure') || lower.contains('nda')) {
        return 'Non-Disclosure Agreement';
      }
      if (lower.contains('lease')) return 'Lease Agreement';
      if (lower.contains('contract')) return 'Contract - $dateStr';
      return 'Legal Agreement - $dateStr';
    }

    // 5. Notes & Study
    if (cat.id == notes.id) {
      if (lines.isNotEmpty) {
        String title = lines.first;
        if (title.length > 26) title = title.substring(0, 26).trim();
        return '${_toTitleCase(title)} - Notes';
      }
      return 'Study Notes - $dateStr';
    }

    // Fallback: Use top line if reasonable length
    if (lines.isNotEmpty) {
      String fallback = lines.first;
      if (fallback.length > 24) fallback = fallback.substring(0, 24).trim();
      return '${_toTitleCase(fallback)} - $dateStr';
    }

    return 'Document - $dateStr';
  }

  static String _toTitleCase(String input) {
    if (input.isEmpty) return input;
    return input.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
