import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceService {
  static final FaceService _instance = FaceService._internal();
  factory FaceService() => _instance;
  FaceService._internal();

  Interpreter? _interpreter;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      print('✅ Modelo MobileFaceNet cargado correctamente.');
    } catch (e) {
      print('❌ Error cargando el modelo: $e');
    }
  }

  // NUEVO: Filtro de Calidad Senior
  // Verifica si el recorte es digno de ser procesado
  bool isValidFace(img.Image faceImage) {
    // 1. Filtro de Tamaño: Si el recorte es muy pequeño (ej. corredor al fondo), se descarta.
    // Un rostro útil para clustering debería tener al menos 80x80 píxeles.
    if (faceImage.width < 80 || faceImage.height < 80) {
      print('⚠️ Rostro descartado: Muy pequeño (${faceImage.width}x${faceImage.height})');
      return false;
    }

    // 2. Filtro de Proporción: Los rostros suelen ser cuadrados/ovales.
    // Si es muy ancho o muy alto (como un codo), se descarta.
    double aspect = faceImage.width / faceImage.height;
    if (aspect < 0.6 || aspect > 1.4) {
      print('⚠️ Rostro descartado: Proporción errónea (Posible falso positivo)');
      return false;
    }

    return true;
  }

  List<double> getFaceEmbedding(img.Image faceImage) {
    if (_interpreter == null) return [];

    // Aplicar validación antes de la inferencia
    if (!isValidFace(faceImage)) return [];

    var input = List.generate(1, (i) => List.generate(112, (y) =>
        List.generate(112, (x) => List.generate(3, (c) => 0.0))));

    // Redimensionar si no viene de 112x112
    img.Image resized = img.copyResize(faceImage, width: 112, height: 112);

    for (var y = 0; y < 112; y++) {
      for (var x = 0; x < 112; x++) {
        var pixel = resized.getPixel(x, y);
        // Normalización optimizada para MobileFaceNet
        input[0][y][x][0] = (pixel.r - 128) / 128.0;
        input[0][y][x][1] = (pixel.g - 128) / 128.0;
        input[0][y][x][2] = (pixel.b - 128) / 128.0;
      }
    }

    var output = List.filled(1 * 192, 0.0).reshape([1, 192]);
    _interpreter!.run(input, output);

    return List<double>.from(output[0]);
  }
}