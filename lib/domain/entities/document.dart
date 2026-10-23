import 'package:equatable/equatable.dart';

class Document extends Equatable {
  final String id;
  final String name;
  final List<String> imagePaths;
  final String? extractedText;
  final String? summary;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;

  const Document({
    required this.id,
    required this.name,
    required this.imagePaths,
    this.extractedText,
    this.summary,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isFavorite = false,
  });

  Document copyWith({
    String? id,
    String? name,
    List<String>? imagePaths,
    String? extractedText,
    String? summary,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
  }) {
    return Document(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePaths: imagePaths ?? this.imagePaths,
      extractedText: extractedText ?? this.extractedText,
      summary: summary ?? this.summary,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    imagePaths,
    extractedText,
    summary,
    tags,
    createdAt,
    updatedAt,
    isFavorite,
  ];

  /// Returns the primary category tag id if assigned (e.g. category_receipts), or null.
  String? get primaryCategory {
    for (final tag in tags) {
      if (tag.startsWith('category_')) {
        return tag;
      }
    }
    return null;
  }

  /// Returns a snippet containing the search query with surrounding context,
  /// or null if the query is not found in the extracted text.
  String? getSearchSnippet(String query, {int contextLength = 35}) {
    if (extractedText == null || extractedText!.isEmpty || query.trim().isEmpty) {
      return null;
    }
    final lowerText = extractedText!.toLowerCase();
    final lowerQuery = query.toLowerCase().trim();
    final index = lowerText.indexOf(lowerQuery);
    if (index == -1) return null;

    final start = (index - contextLength).clamp(0, extractedText!.length);
    final end = (index + lowerQuery.length + contextLength).clamp(0, extractedText!.length);

    String snippet = extractedText!
        .substring(start, end)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (start > 0) snippet = '...$snippet';
    if (end < extractedText!.length) snippet = '$snippet...';
    return snippet;
  }
}
