import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

enum FilterType { original, magicColor, blackAndWhite, grayscale }

class _FilterParams {
  final String imagePath;
  final FilterType filter;
  final String dirPath;

  const _FilterParams(this.imagePath, this.filter, this.dirPath);
}

String _runFilterTask(_FilterParams params) {
  final file = File(params.imagePath);
  final bytes = file.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) throw Exception('Failed to decode image');

  img.Image filteredImage;
  switch (params.filter) {
    case FilterType.original:
      filteredImage = image;
      break;
    case FilterType.magicColor:
      final result = img.Image.from(image);
      img.adjustColor(result, contrast: 1.2, saturation: 1.1);
      img.normalize(result, min: 0, max: 255);
      filteredImage = result;
      break;
    case FilterType.blackAndWhite:
      final result = img.grayscale(image);
      img.normalize(result, min: 0, max: 255);
      final binary = img.Image(width: result.width, height: result.height);
      for (int y = 0; y < result.height; y++) {
        for (int x = 0; x < result.width; x++) {
          final pixel = result.getPixel(x, y);
          final luminance = pixel.luminance.toInt();
          final binaryValue = luminance > 128 ? 255 : 0;
          binary.setPixel(
            x,
            y,
            img.ColorRgb8(binaryValue, binaryValue, binaryValue),
          );
        }
      }
      filteredImage = binary;
      break;
    case FilterType.grayscale:
      filteredImage = img.grayscale(image);
      break;
  }

  final fileName = '${const Uuid().v4()}.jpg';
  final filePath = '${params.dirPath}/$fileName';
  final jpgBytes = img.encodeJpg(filteredImage, quality: 90);
  File(filePath).writeAsBytesSync(jpgBytes);
  return filePath;
}

class ImageService {
  Future<String> applyFilter(String imagePath, FilterType filter) async {
    final directory = await getApplicationDocumentsDirectory();
    return await compute(
      _runFilterTask,
      _FilterParams(imagePath, filter, directory.path),
    );
  }

  Future<String> _saveImage(img.Image image) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${const Uuid().v4()}.jpg';
    final filePath = '${directory.path}/$fileName';

    final jpgBytes = img.encodeJpg(image, quality: 90);
    final file = File(filePath);
    await file.writeAsBytes(jpgBytes);

    return filePath;
  }

  Future<String> cropAndCorrectPerspective(
    String imagePath,
    List<CropOffset> corners,
  ) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    final minX = corners
        .map((c) => c.dx)
        .reduce((a, b) => a < b ? a : b)
        .toInt();
    final minY = corners
        .map((c) => c.dy)
        .reduce((a, b) => a < b ? a : b)
        .toInt();
    final maxX = corners
        .map((c) => c.dx)
        .reduce((a, b) => a > b ? a : b)
        .toInt();
    final maxY = corners
        .map((c) => c.dy)
        .reduce((a, b) => a > b ? a : b)
        .toInt();

    final width = maxX - minX;
    final height = maxY - minY;

    if (width <= 0 || height <= 0) {
      return imagePath;
    }

    final cropped = img.copyCrop(
      image,
      x: minX.clamp(0, image.width - 1),
      y: minY.clamp(0, image.height - 1),
      width: width.clamp(1, image.width),
      height: height.clamp(1, image.height),
    );

    return await _saveImage(cropped);
  }

  Future<String> stampOverlay(
    String targetImagePath,
    Uint8List overlayBytes, {
    double relativeX = 0.55,
    double relativeY = 0.75,
    double relativeWidth = 0.35,
    double? relativeHeight,
  }) async {
    final targetFile = File(targetImagePath);
    final targetBytes = await targetFile.readAsBytes();
    final targetImg = img.decodeImage(targetBytes);
    final overlayImg = img.decodeImage(overlayBytes);

    if (targetImg == null || overlayImg == null) {
      return targetImagePath;
    }

    final targetOverlayWidth =
        math.max(1, (targetImg.width * relativeWidth).round());
    final int targetOverlayHeight;
    if (relativeHeight != null && relativeHeight > 0) {
      targetOverlayHeight =
          math.max(1, (targetImg.height * relativeHeight).round());
    } else {
      final aspect = overlayImg.height / overlayImg.width;
      targetOverlayHeight = math.max(1, (targetOverlayWidth * aspect).round());
    }

    final resizedOverlay = img.copyResize(
      overlayImg,
      width: targetOverlayWidth,
      height: targetOverlayHeight,
      interpolation: img.Interpolation.linear,
    );

    final maxX = math.max(0, targetImg.width - resizedOverlay.width);
    final maxY = math.max(0, targetImg.height - resizedOverlay.height);
    final posX = (targetImg.width * relativeX).round().clamp(0, maxX);
    final posY = (targetImg.height * relativeY).round().clamp(0, maxY);

    img.compositeImage(
      targetImg,
      resizedOverlay,
      dstX: posX,
      dstY: posY,
    );

    final jpgBytes = img.encodeJpg(targetImg, quality: 92);
    await targetFile.writeAsBytes(jpgBytes);
    return targetImagePath;
  }
}

class CropOffset {
  final double dx;
  final double dy;

  const CropOffset(this.dx, this.dy);
}
