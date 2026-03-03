import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:crypto/crypto.dart';
import 'dart:math';

class ImageAuditService {
  // ✅ ISOLATE MAESTRO: Dibuja la telemetría real sobre la imagen de auditoría
  // Al ser estática, se puede llamar desde cualquier parte sin instanciar la clase
  static Future<Map<String, dynamic>?> isolateAuditPipeline(Map<String, dynamic> data) async {
    try {
      final File rawFile = File(data['rawPath']);
      final Uint8List bytes = await rawFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return null;

      double origWidth = originalImage.width.toDouble();
      double origHeight = originalImage.height.toDouble();
      double longestSide = max(origWidth, origHeight);
      double targetPixels = data['targetArea'];
      double scale = 1.0;

      if (longestSide != targetPixels) {
        scale = targetPixels / longestSide;
        if (origWidth >= origHeight) {
          originalImage = img.copyResize(originalImage, width: targetPixels.toInt(), interpolation: img.Interpolation.linear);
        } else {
          originalImage = img.copyResize(originalImage, height: targetPixels.toInt(), interpolation: img.Interpolation.linear);
        }
      }

      final String finalResolution = "${originalImage.width}x${originalImage.height}";

      final String cleanSavePath = data['cleanSavePath'];
      final Uint8List cleanBytes = Uint8List.fromList(img.encodeJpg(originalImage, quality: 90));
      await File(cleanSavePath).writeAsBytes(cleanBytes);
      final String cleanHash = sha256.convert(cleanBytes).toString();

      final img.BitmapFont font = img.arial48;
      final List<dynamic> faces = data['faces'];

      for (var face in faces) {
        int left = (face['left'] * scale).toInt();
        int top = (face['top'] * scale).toInt();
        int right = (face['right'] * scale).toInt();
        int bottom = (face['bottom'] * scale).toInt();

        final double angleY = (face['angleY'] as double).abs();
        final double faceWidth = face['faceWidth'];

        String textSize = "${faceWidth.toInt()}px";
        String textAngle = "A: ${angleY.toStringAsFixed(1)}";

        img.drawRect(originalImage, x1: left, y1: top, x2: right, y2: bottom, color: img.ColorRgb8(0, 255, 0), thickness: 4);
        img.drawString(originalImage, textSize, font: font, x: left, y: top - 110, color: img.ColorRgb8(0, 255, 0));
        img.drawString(originalImage, textAngle, font: font, x: left, y: top - 55, color: img.ColorRgb8(255, 50, 50));
      }

      String info = "${(cleanBytes.length / (1024 * 1024)).toStringAsFixed(2)}MB | $finalResolution";
      img.drawString(originalImage, info, font: font, x: originalImage.width - 650, y: originalImage.height - 70, color: img.ColorRgb8(0, 255, 0));

      final String auditSavePath = data['auditSavePath'];
      final Uint8List auditBytes = Uint8List.fromList(img.encodeJpg(originalImage, quality: 90));
      await File(auditSavePath).writeAsBytes(auditBytes);
      final String auditHash = sha256.convert(auditBytes).toString();

      return {
        'cleanHash': cleanHash,
        'auditHash': auditHash,
        'final_resolution': finalResolution,
        'cleanSizeMb': (cleanBytes.length / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) { return null; }
  }
}