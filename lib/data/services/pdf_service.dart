import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_encryption_service.dart';

enum PdfQuality {
  lossless300Dpi, // 300 DPI Lossless (VIP) - uncompressed original fidelity
  high, // Standard high resolution
  medium, // Balanced compression (max 1400px, 80% JPEG quality)
  compact, // Optimized for email/messaging (max 900px, 60% JPEG quality)
}

class _PdfCompressParams {
  final String path;
  final PdfQuality quality;

  const _PdfCompressParams(this.path, this.quality);
}

Uint8List _compressImageForPdf(_PdfCompressParams params) {
  final file = File(params.path);
  final bytes = file.readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  final maxDim = params.quality == PdfQuality.medium ? 1400 : 900;
  final jpgQuality = params.quality == PdfQuality.medium ? 80 : 60;

  img.Image resized = decoded;
  if (decoded.width > maxDim || decoded.height > maxDim) {
    if (decoded.width > decoded.height) {
      resized = img.copyResize(decoded, width: maxDim);
    } else {
      resized = img.copyResize(decoded, height: maxDim);
    }
  }

  return Uint8List.fromList(img.encodeJpg(resized, quality: jpgQuality));
}

class PdfService {
  /// Generates a PDF document from a list of image file paths.
  /// Each image is placed on its own A4 page, scaled to fit.
  /// Supports quality presets (including 300 DPI Lossless VIP),
  /// password-protected standard encryption (VIP),
  /// custom digital signature & stamp overlays (VIP), and OCR transcript page.
  Future<Uint8List> generatePdf(
    List<String> imagePaths, {
    PdfQuality quality = PdfQuality.high,
    String? extractedText,
    bool includeTextPage = false,
    String? documentTitle,
    String? watermarkText,
    String? password,
    Uint8List? signatureBytes,
    Uint8List? stampBytes,
  }) async {
    final doc = pw.Document(
      title: documentTitle,
    );

    // Apply standard PDF password encryption (VIP feature)
    if (password != null && password.trim().isNotEmpty) {
      StandardPdfEncryption.create(
        doc.document,
        userPassword: password.trim(),
      );
    }

    pw.MemoryImage? signatureImage;
    if (signatureBytes != null && signatureBytes.isNotEmpty) {
      signatureImage = pw.MemoryImage(signatureBytes);
    }

    pw.MemoryImage? stampImage;
    if (stampBytes != null && stampBytes.isNotEmpty) {
      stampImage = pw.MemoryImage(stampBytes);
    }

    for (var i = 0; i < imagePaths.length; i++) {
      final path = imagePaths[i];
      final file = File(path);
      if (!await file.exists()) continue;

      Uint8List imageBytes;
      if (quality == PdfQuality.lossless300Dpi || quality == PdfQuality.high) {
        // Full resolution, uncompressed/lossless sensor bytes
        imageBytes = await file.readAsBytes();
      } else {
        imageBytes = await compute(
          _compressImageForPdf,
          _PdfCompressParams(path, quality),
        );
      }

      final image = pw.MemoryImage(imageBytes);
      final isLastPage = i == imagePaths.length - 1;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Stack(
              alignment: pw.Alignment.center,
              children: [
                pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),

                // Optional Watermark
                if (watermarkText != null && watermarkText.trim().isNotEmpty)
                  pw.Center(
                    child: pw.Transform.rotate(
                      angle: -0.785398,
                      child: pw.Text(
                        watermarkText.trim().toUpperCase(),
                        style: pw.TextStyle(
                          color: const PdfColor(0.5, 0.5, 0.5, 0.28),
                          fontSize: 48,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Custom Official Stamp Overlay (Top-Right on pages)
                if (stampImage != null)
                  pw.Positioned(
                    top: 24,
                    right: 24,
                    child: pw.Container(
                      width: 110,
                      height: 110,
                      child: pw.Image(stampImage, fit: pw.BoxFit.contain),
                    ),
                  ),

                // Custom Digital Signature Overlay (Bottom-Right on last page)
                if (signatureImage != null && isLastPage)
                  pw.Positioned(
                    bottom: 30,
                    right: 30,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Container(
                          width: 140,
                          height: 60,
                          child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                        ),
                        pw.Container(
                          width: 140,
                          height: 1,
                          color: PdfColors.grey700,
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Authorized Digital Signature',
                          style: const pw.TextStyle(
                            fontSize: 7,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    if (includeTextPage &&
        extractedText != null &&
        extractedText.trim().isNotEmpty) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      documentTitle ?? 'Extracted Text Transcript',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'PrivaScan AI',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Paragraph(
                text: extractedText.trim(),
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 2.5),
              ),
            ];
          },
        ),
      );
    }

    return doc.save();
  }
}
