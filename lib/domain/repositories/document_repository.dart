import '../entities/document.dart';

abstract class DocumentRepository {
  Future<List<Document>> getAllDocuments();
  Future<Document?> getDocumentById(String id);
  Future<void> saveDocument(Document document);
  Future<void> updateDocument(Document document);
  Future<void> deleteDocument(String id);
  Future<void> deleteAllDocuments();
  Future<List<Document>> searchDocuments(String query);
  Future<List<Document>> getDocumentsByTag(String tagId);
  Future<List<Document>> getTrashDocuments();
  Future<void> moveToTrash(String id);
  Future<void> restoreDocument(String id);
  Future<void> emptyTrash();
}
