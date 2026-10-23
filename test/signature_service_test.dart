import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privascan_ai/data/services/signature_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('privascan_sig_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('SignatureService saves, retrieves, and deletes signature files', () async {
    final service = SignatureService.instance;
    final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

    // Initially empty
    final initialList = await service.getSavedSignatures();
    expect(initialList.isEmpty, isTrue);

    // Save a signature
    final saved = await service.saveSignature(dummyBytes);
    expect(saved.id.isNotEmpty, isTrue);
    expect(File(saved.filePath).existsSync(), isTrue);

    // Retrieve saved signatures
    final updatedList = await service.getSavedSignatures();
    expect(updatedList.length, equals(1));
    expect(updatedList.first.id, equals(saved.id));
    expect(File(updatedList.first.filePath).existsSync(), isTrue);

    // Delete the signature
    final deleted = await service.deleteSignature(saved.filePath);
    expect(deleted, isTrue);

    // Verify deletion
    final finalList = await service.getSavedSignatures();
    expect(finalList.isEmpty, isTrue);
  });
}
