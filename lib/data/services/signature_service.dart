import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class SavedSignature {
  final String id;
  final String filePath;
  final DateTime createdAt;

  const SavedSignature({
    required this.id,
    required this.filePath,
    required this.createdAt,
  });
}

class SignatureService {
  SignatureService._();
  static final SignatureService instance = SignatureService._();

  Future<Directory> _getSignaturesDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final sigDir = Directory(p.join(docsDir.path, 'signatures'));
    if (!await sigDir.exists()) {
      await sigDir.create(recursive: true);
    }
    return sigDir;
  }

  Future<SavedSignature> saveSignature(Uint8List bytes) async {
    final dir = await _getSignaturesDir();
    final id = const Uuid().v4();
    final filePath = p.join(dir.path, 'sig_$id.png');
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return SavedSignature(
      id: id,
      filePath: filePath,
      createdAt: DateTime.now(),
    );
  }

  Future<List<SavedSignature>> getSavedSignatures() async {
    try {
      final dir = await _getSignaturesDir();
      final entities = dir.listSync();
      final List<SavedSignature> list = [];
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.png')) {
          final stat = entity.statSync();
          final id = entity.uri.pathSegments.last
              .replaceAll('.png', '')
              .replaceAll('sig_', '');
          list.add(
            SavedSignature(
              id: id,
              filePath: entity.path,
              createdAt: stat.modified,
            ),
          );
        }
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<bool> deleteSignature(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }
}
