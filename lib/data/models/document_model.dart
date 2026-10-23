import 'package:hive/hive.dart';
import '../../domain/entities/document.dart';

part 'document_model.g.dart';

@HiveType(typeId: 0)
class DocumentModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late List<String> imagePaths;

  @HiveField(3)
  String? extractedText;

  @HiveField(4)
  String? summary;

  @HiveField(5)
  late List<String> tags;

  @HiveField(6)
  late DateTime createdAt;

  @HiveField(7)
  late DateTime updatedAt;

  @HiveField(8)
  late bool isFavorite;

  DocumentModel();

  factory DocumentModel.fromEntity(Document document) {
    return DocumentModel()
      ..id = document.id
      ..name = document.name
      ..imagePaths = document.imagePaths
      ..extractedText = document.extractedText
      ..summary = document.summary
      ..tags = document.tags
      ..createdAt = document.createdAt
      ..updatedAt = document.updatedAt
      ..isFavorite = document.isFavorite;
  }

  Document toEntity() {
    return Document(
      id: id,
      name: name,
      imagePaths: imagePaths,
      extractedText: extractedText,
      summary: summary,
      tags: tags,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isFavorite: isFavorite,
    );
  }
}
