import 'dart:io';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class DetectedBarcode {
  final String rawValue;
  final BarcodeFormat format;
  final BarcodeType type;
  final String? displayValue;

  const DetectedBarcode({
    required this.rawValue,
    required this.format,
    required this.type,
    this.displayValue,
  });

  bool get isUrl =>
      type == BarcodeType.url ||
      rawValue.toLowerCase().startsWith('http://') ||
      rawValue.toLowerCase().startsWith('https://');

  bool get isUpi =>
      rawValue.toLowerCase().startsWith('upi://');

  bool get isEmail =>
      type == BarcodeType.email ||
      rawValue.toLowerCase().startsWith('mailto:');

  bool get isPhone =>
      type == BarcodeType.phone ||
      rawValue.toLowerCase().startsWith('tel:');

  String get formatLabel {
    switch (format) {
      case BarcodeFormat.qrCode:
        return 'QR Code';
      case BarcodeFormat.code128:
        return 'Code 128';
      case BarcodeFormat.code39:
        return 'Code 39';
      case BarcodeFormat.code93:
        return 'Code 93';
      case BarcodeFormat.codabar:
        return 'Codabar';
      case BarcodeFormat.ean13:
        return 'EAN-13';
      case BarcodeFormat.ean8:
        return 'EAN-8';
      case BarcodeFormat.itf:
        return 'ITF';
      case BarcodeFormat.upca:
        return 'UPC-A';
      case BarcodeFormat.upce:
        return 'UPC-E';
      case BarcodeFormat.pdf417:
        return 'PDF417';
      case BarcodeFormat.aztec:
        return 'Aztec';
      case BarcodeFormat.dataMatrix:
        return 'Data Matrix';
      default:
        return 'Barcode';
    }
  }
}

class BarcodeService {
  final BarcodeScanner _scanner = BarcodeScanner();

  /// Scans a local document image on-device for QR codes and barcodes.
  Future<List<DetectedBarcode>> scanImage(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) return [];

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final barcodes = await _scanner.processImage(inputImage);
      return barcodes
          .where((b) => b.rawValue != null && b.rawValue!.trim().isNotEmpty)
          .map((b) => DetectedBarcode(
                rawValue: b.rawValue!.trim(),
                format: b.format,
                type: b.type,
                displayValue: b.displayValue,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void dispose() {
    _scanner.close();
  }
}
