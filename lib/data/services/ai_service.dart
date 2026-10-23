import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class ExtractedEntities {
  final List<String> dates;
  final List<String> emails;
  final List<String> phones;
  final List<String> amounts;
  final List<String> urls;

  const ExtractedEntities({
    this.dates = const [],
    this.emails = const [],
    this.phones = const [],
    this.amounts = const [],
    this.urls = const [],
  });

  bool get isEmpty =>
      dates.isEmpty &&
      emails.isEmpty &&
      phones.isEmpty &&
      amounts.isEmpty &&
      urls.isEmpty;

  bool get isNotEmpty => !isEmpty;
}

class AiService {
  Future<String> generateSummary(String text, String template) async {
    await Future.delayed(const Duration(seconds: 1));

    switch (template) {
      case 'Quick Summary':
        return _generateQuickSummary(text);
      case 'Action Items':
        return _generateActionItems(text);
      case 'Key Entities':
        return _extractKeyEntities(text);
      default:
        return _generateCustomSummary(text);
    }
  }

  Future<String> answerCustomQuestion(String text, String question) async {
    await Future.delayed(const Duration(seconds: 1));
    return _generateCustomAnswer(text, question);
  }

  Future<String> translateText(String text, TranslateLanguage source, TranslateLanguage target) async {
    if (text.isEmpty) return '';

    debugPrint('[AiService] Starting translation: ${source.bcpCode} → ${target.bcpCode}');
    debugPrint('[AiService] Text length: ${text.length} characters');

    final modelManager = OnDeviceTranslatorModelManager();

    // Check and download source language model
    final isSourceDownloaded = await modelManager.isModelDownloaded(source.bcpCode);
    debugPrint('[AiService] Source model (${source.bcpCode}) downloaded: $isSourceDownloaded');
    if (!isSourceDownloaded) {
      debugPrint('[AiService] Downloading source model (${source.bcpCode})...');
      try {
        await modelManager.downloadModel(source.bcpCode);
        debugPrint('[AiService] ✅ Source model downloaded.');
      } catch (e) {
        debugPrint('[AiService] ❌ Source model download failed: $e');
        throw Exception(
          'Failed to download the ${source.name} language model. '
          'Please check your internet connection and try again.\n\nDetails: $e',
        );
      }
    }

    // Check and download target language model
    final isTargetDownloaded = await modelManager.isModelDownloaded(target.bcpCode);
    debugPrint('[AiService] Target model (${target.bcpCode}) downloaded: $isTargetDownloaded');
    if (!isTargetDownloaded) {
      debugPrint('[AiService] Downloading target model (${target.bcpCode})...');
      try {
        await modelManager.downloadModel(target.bcpCode);
        debugPrint('[AiService] ✅ Target model downloaded.');
      } catch (e) {
        debugPrint('[AiService] ❌ Target model download failed: $e');
        throw Exception(
          'Failed to download the ${target.name} language model. '
          'Please check your internet connection and try again.\n\nDetails: $e',
        );
      }
    }

    // Perform translation
    debugPrint('[AiService] Creating translator...');
    final translator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );

    try {
      debugPrint('[AiService] Translating text...');
      final String response = await translator.translateText(text);
      debugPrint('[AiService] ✅ Translation complete (${response.length} chars).');
      return response;
    } catch (e) {
      debugPrint('[AiService] ❌ Translation failed: $e');
      throw Exception(
        'Translation failed. The on-device ML model could not translate this text.\n\n'
        'Tip: Try with a shorter text or ensure the text is in English.\n\nDetails: $e',
      );
    } finally {
      translator.close();
    }
  }

  String _generateQuickSummary(String text) {
    final rawSentences = text
        .split(RegExp(r'(?<=[.!?\n])\s+'))
        .map((s) => s.trim())
        .where((s) => s.length > 15)
        .toList();

    if (rawSentences.isEmpty) return 'No substantive text content available.';
    if (rawSentences.length <= 3) {
      final b = StringBuffer('Summary Overview:\n');
      for (final s in rawSentences) {
        b.writeln('• $s');
      }
      return b.toString();
    }

    // Stopwords for English/common documents
    const stopwords = {
      'the', 'is', 'at', 'which', 'on', 'a', 'an', 'and', 'or', 'in', 'of',
      'to', 'for', 'with', 'as', 'by', 'that', 'this', 'it', 'from', 'be',
      'are', 'was', 'were', 'has', 'have', 'had', 'been', 'will', 'would',
      'can', 'could', 'should', 'all', 'any', 'but', 'not', 'you', 'we', 'they'
    };

    // Calculate word frequencies
    final wordFreq = <String, int>{};
    for (final s in rawSentences) {
      final words = s.toLowerCase().split(RegExp(r'[^a-zA-Z0-9]+'));
      for (final w in words) {
        if (w.length > 2 && !stopwords.contains(w)) {
          wordFreq[w] = (wordFreq[w] ?? 0) + 1;
        }
      }
    }

    // Score sentences by word importance
    final scored = <int, double>{};
    for (int i = 0; i < rawSentences.length; i++) {
      final words = rawSentences[i].toLowerCase().split(RegExp(r'[^a-zA-Z0-9]+'));
      double score = 0;
      for (final w in words) {
        if (wordFreq.containsKey(w)) {
          score += wordFreq[w]!;
        }
      }
      final wordCount = words.where((w) => w.isNotEmpty).length;
      scored[i] = wordCount > 0 ? (score / wordCount) : 0;
    }

    // Pick top scoring sentences while preserving chronological reading order
    final topIndices = scored.keys.toList()
      ..sort((a, b) => scored[b]!.compareTo(scored[a]!));
    final selectedIndices = topIndices.take(3).toList()..sort();

    final summary = StringBuffer('Key Summary Highlights:\n\n');
    for (final idx in selectedIndices) {
      summary.writeln('• ${rawSentences[idx]}');
    }

    final totalWords = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    summary.writeln('\n📊 Context: $totalWords total words · est. ${(totalWords / 200).ceil()} min read');
    return summary.toString();
  }

  String _generateActionItems(String text) {
    final actionPatterns = [
      RegExp(
        r'\b(must|should|need to|required to|will|shall|going to)\s+(.+?)(?:\.|,|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(todo|task|action|item)\s*[:\-]?\s*(.+?)(?:\n|$)',
        caseSensitive: false,
      ),
    ];

    final actions = <String>[];
    for (final pattern in actionPatterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        final action = match.group(0)?.trim();
        if (action != null && action.isNotEmpty) {
          actions.add(action);
        }
      }
    }

    final result = StringBuffer();
    result.writeln('Action Items & Directives:\n');

    if (actions.isEmpty) {
      result.writeln('• Review document for pending deliverables');
      result.writeln('• Identify scheduled milestones or deadlines');
      result.writeln('• Follow up on stakeholders mentioned');
    } else {
      for (final action in actions.take(5)) {
        result.writeln(
          '• ${action.substring(0, action.length > 100 ? 100 : action.length)}',
        );
      }
    }

    return result.toString();
  }

  static ExtractedEntities detectEntities(String text) {
    if (text.isEmpty) return const ExtractedEntities();

    final datePattern = RegExp(
      r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2})\b',
    );
    final emailPattern = RegExp(
      r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
    );
    final phonePattern = RegExp(
      r'(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b',
    );
    final moneyPattern = RegExp(
      r'[$€£₹]\s*[\d,]+\.?\d*|\b[\d,]+\.?\d*\s*(?:USD|EUR|INR|GBP)\b',
      caseSensitive: false,
    );
    final urlPattern = RegExp(
      r'https?://[^\s/$.?#].[^\s]*|www\.[^\s]+',
      caseSensitive: false,
    );

    final dates = datePattern
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();
    final emails = emailPattern
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();
    final phones = phonePattern
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();
    final amounts = moneyPattern
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();
    final urls = urlPattern
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();

    return ExtractedEntities(
      dates: dates,
      emails: emails,
      phones: phones,
      amounts: amounts,
      urls: urls,
    );
  }

  String _extractKeyEntities(String text) {
    final entities = detectEntities(text);

    final result = StringBuffer();
    result.writeln('Structured Key Entities:\n');

    if (entities.dates.isNotEmpty) {
      result.writeln('📅 Dates: ${entities.dates.take(3).join(", ")}');
    }
    if (entities.emails.isNotEmpty) {
      result.writeln('✉️ Emails: ${entities.emails.take(3).join(", ")}');
    }
    if (entities.phones.isNotEmpty) {
      result.writeln('📞 Phones: ${entities.phones.take(3).join(", ")}');
    }
    if (entities.amounts.isNotEmpty) {
      result.writeln('💰 Financial: ${entities.amounts.take(3).join(", ")}');
    }
    if (entities.urls.isNotEmpty) {
      result.writeln('🌐 Web Links: ${entities.urls.take(3).join(", ")}');
    }

    if (entities.isEmpty) {
      result.writeln('No specific contact, financial, or date entities found.');
      result.writeln('Scanned text appears to be unstructured prose.');
    }

    return result.toString();
  }

  String _generateCustomSummary(String text) {
    final words = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final result = StringBuffer();
    result.writeln('Document Metrics & Analysis:\n');
    result.writeln('• Word Count: ${words.length}');
    result.writeln('• Character Count: ${text.length}');
    result.writeln('• Paragraphs: ${text.split(RegExp(r'\n\s*\n')).length}');

    final firstLines = text
        .split('\n')
        .take(3)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (firstLines.isNotEmpty) {
      result.writeln('\nOpening lines:');
      for (final line in firstLines) {
        result.writeln(
          '• ${line.trim().substring(0, line.length > 80 ? 80 : line.length)}',
        );
      }
    }

    return result.toString();
  }

  String _generateCustomAnswer(String text, String question) {
    final cleanQuestion = question.trim();
    if (cleanQuestion.isEmpty) return 'Please enter a question.';

    // Extract query terms (excluding common question words)
    const questionStopwords = {
      'what', 'when', 'where', 'who', 'whom', 'which', 'why', 'how',
      'is', 'are', 'was', 'were', 'the', 'a', 'an', 'in', 'of', 'for', 'about'
    };
    final queryTerms = cleanQuestion
        .toLowerCase()
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((t) => t.length > 2 && !questionStopwords.contains(t))
        .toSet();

    final sentences = text
        .split(RegExp(r'(?<=[.!?\n])\s+'))
        .map((s) => s.trim())
        .where((s) => s.length > 10)
        .toList();

    if (sentences.isEmpty) return 'No text content available to answer your question.';

    // Score sentences by matching query terms
    int bestScore = 0;
    String? bestSentence;

    for (final s in sentences) {
      final lowerSentence = s.toLowerCase();
      int score = 0;
      for (final term in queryTerms) {
        if (lowerSentence.contains(term)) {
          score += 2;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestSentence = s;
      }
    }

    if (bestSentence != null && bestScore > 0) {
      return 'Relevant excerpt found:\n\n"$bestSentence"';
    }

    final lowerQ = cleanQuestion.toLowerCase();
    if (lowerQ.contains('date') || lowerQ.contains('when')) {
      final datePattern = RegExp(r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2})\b');
      final dates = datePattern.allMatches(text).map((m) => m.group(0)).toSet();
      if (dates.isNotEmpty) {
        return 'Dates detected in document: ${dates.join(", ")}';
      }
    }

    if (lowerQ.contains('money') || lowerQ.contains('cost') || lowerQ.contains('price')) {
      final moneyPattern = RegExp(r'\$[\d,]+\.?\d*|\d+[\d,]*\s*(?:USD|EUR|INR|GBP)', caseSensitive: false);
      final amounts = moneyPattern.allMatches(text).map((m) => m.group(0)).toSet();
      if (amounts.isNotEmpty) {
        return 'Financial amounts found: ${amounts.join(", ")}';
      }
    }

    return 'No direct match found for "$cleanQuestion" in this document. Try rephrasing or check the Extracted Text tab.';
  }
}
