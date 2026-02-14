import 'dart:ui';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageProcessor {
  // Función principal para recortar
  static Future<Map<String, Uint8List>> cropFaceAndTorso(String imagePath, Rect faceRect) async {
    // 1. Cargamos la imagen original
    final bytes = await File(imagePath).readAsBytes();
    final originalImage = img.decodeImage(bytes);

    if (originalImage == null) return {};

    // 2. Recorte de Cara
    final face = img.copyCrop(
      originalImage,
      x: faceRect.left.toInt(),
      y: faceRect.top.toInt(),
      width: faceRect.width.toInt(),
      height: faceRect.height.toInt(),
    );

    // 3. Recorte de Torso (Estimación de Ingeniería)
    // Bajamos una distancia proporcional al tamaño de la cara
    final torso = img.copyCrop(
      originalImage,
      x: (faceRect.left - faceRect.width * 0.5).toInt(), // Más ancho que la cara
      y: (faceRect.top + faceRect.height * 1.2).toInt(), // Iniciamos debajo de la barbilla
      width: (faceRect.width * 2).toInt(),
      height: (faceRect.height * 3).toInt(), // Área del pecho/dorsal
    );

    return {
      'face': Uint8List.fromList(img.encodeJpg(face)),
      'torso': Uint8List.fromList(img.encodeJpg(torso)),
    };
  }
}