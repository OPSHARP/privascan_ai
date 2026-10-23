import 'dart:io';
import 'package:hive/hive.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/document.dart';
import '../../domain/repositories/document_repository.dart';
import '../models/document_model.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  late Box<DocumentModel> _documentsBox;

  Future<void> init() async {
    _documentsBox = await Hive.openBox<DocumentModel>(
      AppConstants.documentsBox,
    );

    // Auto-cleanup items in Trash older than 30 days
    try {
      final now = DateTime.now();
      final trashedModels = _documentsBox.values
          .where((m) => m.tags.contains(AppConstants.trashTag))
          .toList();
      for (final model in trashedModels) {
        if (now.difference(model.updatedAt).inDays >= 30) {
          await deleteDocument(model.id);
        }
      }
    } catch (_) {}
  }

  @override
  Future<List<Document>> getAllDocuments() async {
    final documents = _documentsBox.values
        .where((model) => !model.tags.contains(AppConstants.trashTag))
        .map((model) => model.toEntity())
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return documents;
  }

  @override
  Future<Document?> getDocumentById(String id) async {
    final model = _documentsBox.get(id);
    return model?.toEntity();
  }

  @override
  Future<void> saveDocument(Document document) async {
    final model = DocumentModel.fromEntity(document);
    await _documentsBox.put(document.id, model);
  }

  @override
  Future<void> updateDocument(Document document) async {
    final model = DocumentModel.fromEntity(document);
    await _documentsBox.put(document.id, model);
  }

  @override
  Future<void> deleteDocument(String id) async {
    final model = _documentsBox.get(id);
    if (model != null) {
      for (final path in model.imagePaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // shortcut: ignore filesystem deletion failure so Hive database entry is always deleted
        }
      }
    }
    await _documentsBox.delete(id);
  }

  @override
  Future<void> deleteAllDocuments() async {
    final models = _documentsBox.values.toList();
    for (final model in models) {
      for (final path in model.imagePaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // shortcut: ignore filesystem deletion failure so Hive database clear is always completed
        }
      }
    }
    await _documentsBox.clear();
  }

  @override
  Future<List<Document>> searchDocuments(String query) async {
    final lowercaseQuery = query.toLowerCase();
    final documents = _documentsBox.values
        .where((model) => !model.tags.contains(AppConstants.trashTag))
        .where(
          (model) =>
              model.name.toLowerCase().contains(lowercaseQuery) ||
              (model.extractedText?.toLowerCase().contains(
                    lowercaseQuery,
                  ) ??
                  false) ||
              (model.summary?.toLowerCase().contains(lowercaseQuery) ??
                  false),
        )
        .map((model) => model.toEntity())
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return documents;
  }

  @override
  Future<List<Document>> getDocumentsByTag(String tagId) async {
    final documents = _documentsBox.values
        .where((model) => !model.tags.contains(AppConstants.trashTag))
        .where((model) => model.tags.contains(tagId))
        .map((model) => model.toEntity())
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return documents;
  }

  @override
  Future<List<Document>> getTrashDocuments() async {
    final documents = _documentsBox.values
        .where((model) => model.tags.contains(AppConstants.trashTag))
        .map((model) => model.toEntity())
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return documents;
  }

  @override
  Future<void> moveToTrash(String id) async {
    final model = _documentsBox.get(id);
    if (model != null) {
      final doc = model.toEntity();
      final tags = List<String>.from(doc.tags);
      if (!tags.contains(AppConstants.trashTag)) {
        tags.add(AppConstants.trashTag);
      }
      final updatedDoc = doc.copyWith(tags: tags, updatedAt: DateTime.now());
      await _documentsBox.put(id, DocumentModel.fromEntity(updatedDoc));
    }
  }

  @override
  Future<void> restoreDocument(String id) async {
    final model = _documentsBox.get(id);
    if (model != null) {
      final doc = model.toEntity();
      final tags = List<String>.from(doc.tags)..remove(AppConstants.trashTag);
      final updatedDoc = doc.copyWith(tags: tags, updatedAt: DateTime.now());
      await _documentsBox.put(id, DocumentModel.fromEntity(updatedDoc));
    }
  }

  @override
  Future<void> emptyTrash() async {
    final trashed = _documentsBox.values
        .where((model) => model.tags.contains(AppConstants.trashTag))
        .toList();
    for (final model in trashed) {
      await deleteDocument(model.id);
    }
  }
}

