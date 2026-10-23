import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Backup Archive Encoding and Decoding', () {
    test('ZipEncoder and ZipDecoder preserve manifest.json and binary image files', () {
      final archive = Archive();

      // Add manifest.json
      final manifestMap = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'documents': [
          {
            'id': 'doc-123',
            'name': 'Test Invoice',
            'imageFileNames': ['img_0.jpg'],
            'extractedText': 'Invoice Total \$100',
            'tags': ['category_receipts'],
          }
        ]
      };
      final manifestBytes = utf8.encode(jsonEncode(manifestMap));
      archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

      // Add dummy image
      final dummyImageBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      archive.addFile(ArchiveFile('images/img_0.jpg', dummyImageBytes.length, dummyImageBytes));

      // Encode
      final encoder = ZipEncoder();
      final compressed = encoder.encode(archive);
      expect(compressed, isNotNull);
      expect(compressed.length, greaterThan(0));

      // Decode
      final decoder = ZipDecoder();
      final decodedArchive = decoder.decodeBytes(compressed);

      ArchiveFile? decodedManifest;
      ArchiveFile? decodedImage;

      for (final f in decodedArchive.files) {
        if (f.name == 'manifest.json') decodedManifest = f;
        if (f.name == 'images/img_0.jpg') decodedImage = f;
      }

      expect(decodedManifest, isNotNull);
      expect(decodedImage, isNotNull);

      // Verify content extraction
      final contentBytes = decodedManifest!.content as List<int>;
      final decodedString = utf8.decode(contentBytes);
      final parsedJson = jsonDecode(decodedString) as Map<String, dynamic>;
      expect(parsedJson['version'], equals(1));
      expect(parsedJson['documents'][0]['name'], equals('Test Invoice'));

      final imageContent = decodedImage!.content as List<int>;
      expect(imageContent, equals(dummyImageBytes));
    });
  });
}
