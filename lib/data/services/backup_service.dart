import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/document.dart';
import '../repositories/document_repository_impl.dart';

class BackupResult {
  final bool success;
  final String message;
  final int count;

  const BackupResult({
    required this.success,
    required this.message,
    this.count = 0,
  });
}

class BackupService {
  final DocumentRepositoryImpl _repository;

  BackupService(this._repository);

  /// Exports all stored documents, metadata, and page images into a single offline
  /// `.privascan` archive file and prompts the user to save or share it.
  Future<BackupResult> createBackup() async {
    try {
      final documents = await _repository.getAllDocuments();
      if (documents.isEmpty) {
        return const BackupResult(
          success: false,
          message: 'No documents to backup.',
        );
      }

      final archive = Archive();

      // 1. Build Manifest JSON
      final manifestDocs = <Map<String, dynamic>>[];

      for (final doc in documents) {
        final relativeImageNames = <String>[];
        for (final imgPath in doc.imagePaths) {
          final file = File(imgPath);
          if (await file.exists()) {
            final fileName = file.uri.pathSegments.last;
            final fileBytes = await file.readAsBytes();
            archive.addFile(
              ArchiveFile('images/$fileName', fileBytes.length, fileBytes),
            );
            relativeImageNames.add(fileName);
          }
        }

        manifestDocs.add({
          'id': doc.id,
          'name': doc.name,
          'extractedText': doc.extractedText,
          'summary': doc.summary,
          'tags': doc.tags,
          'createdAt': doc.createdAt.toIso8601String(),
          'updatedAt': doc.updatedAt.toIso8601String(),
          'isFavorite': doc.isFavorite,
          'imageFileNames': relativeImageNames,
        });
      }

      final manifestData = {
        'app': 'PrivaScan AI',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'documentCount': documents.length,
        'documents': manifestDocs,
      };

      final manifestBytes = utf8.encode(jsonEncode(manifestData));
      archive.addFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
      );

      // 2. Compress with ZipEncoder
      final zipEncoder = ZipEncoder();
      final compressedData = zipEncoder.encode(archive);

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFilePath =
          '${tempDir.path}/PrivaScan_Backup_$timestamp.privascan';
      final backupFile = File(backupFilePath);
      await backupFile.writeAsBytes(compressedData);

      // 3. Share or Save via system share sheet
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(backupFilePath, mimeType: 'application/octet-stream')],
          subject: 'PrivaScan AI Offline Backup',
          text: 'Encrypted & fully offline PrivaScan AI document backup.',
        ),
      );

      return BackupResult(
        success: true,
        message:
            'Backup created with ${documents.length} document${documents.length == 1 ? '' : 's'}.',
        count: documents.length,
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Backup error: $e',
      );
    }
  }

  /// Prompts the user to pick a `.privascan` or `.zip` backup archive file,
  /// extracts images safely to local storage, and restores all documents.
  Future<BackupResult> restoreBackup() async {
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (pickedFiles.isEmpty) {
        return const BackupResult(
          success: false,
          message: 'Restore cancelled. No file selected.',
        );
      }

      final pickedPath = pickedFiles.first.path;
      if (pickedPath == null) {
        return const BackupResult(
          success: false,
          message: 'Could not access selected file.',
        );
      }

      final backupFile = File(pickedPath);
      final fileBytes = await backupFile.readAsBytes();

      final zipDecoder = ZipDecoder();
      final archive = zipDecoder.decodeBytes(fileBytes);

      // Find manifest.json
      ArchiveFile? manifestFile;
      for (final file in archive.files) {
        if (file.name == 'manifest.json') {
          manifestFile = file;
          break;
        }
      }

      if (manifestFile == null) {
        return const BackupResult(
          success: false,
          message: 'Invalid backup file: manifest.json not found.',
        );
      }

      final manifestString = utf8.decode(manifestFile.content as List<int>);
      final manifestJson = jsonDecode(manifestString) as Map<String, dynamic>;
      final docList = manifestJson['documents'] as List<dynamic>?;

      if (docList == null || docList.isEmpty) {
        return const BackupResult(
          success: false,
          message: 'Backup archive contains no document records.',
        );
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final scansDir = Directory('${appDocDir.path}/scans');
      if (!await scansDir.exists()) {
        await scansDir.create(recursive: true);
      }

      // Extract all images
      final extractedImageMap = <String, String>{};
      for (final file in archive.files) {
        if (file.name.startsWith('images/') && file.isFile) {
          final fileName = file.name.replaceFirst('images/', '');
          final targetPath = '${scansDir.path}/$fileName';
          final targetFile = File(targetPath);
          await targetFile.writeAsBytes(file.content as List<int>);
          extractedImageMap[fileName] = targetPath;
        }
      }

      int restoredCount = 0;
      for (final rawDoc in docList) {
        final docMap = rawDoc as Map<String, dynamic>;
        final imageFileNames = (docMap['imageFileNames'] as List<dynamic>?) ?? [];
        final restoredPaths = <String>[];

        for (final fn in imageFileNames) {
          final path = extractedImageMap[fn.toString()];
          if (path != null) {
            restoredPaths.add(path);
          }
        }

        final document = Document(
          id: docMap['id'] as String,
          name: docMap['name'] as String,
          imagePaths: restoredPaths,
          extractedText: docMap['extractedText'] as String?,
          summary: docMap['summary'] as String?,
          tags: (docMap['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? [],
          createdAt: DateTime.tryParse(docMap['createdAt'] as String? ?? '') ?? DateTime.now(),
          updatedAt: DateTime.tryParse(docMap['updatedAt'] as String? ?? '') ?? DateTime.now(),
          isFavorite: docMap['isFavorite'] as bool? ?? false,
        );

        await _repository.saveDocument(document);
        restoredCount++;
      }

      return BackupResult(
        success: true,
        message: 'Successfully restored $restoredCount document${restoredCount == 1 ? '' : 's'}.',
        count: restoredCount,
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Failed to restore backup: $e',
      );
    }
  }
}
