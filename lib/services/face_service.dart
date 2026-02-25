import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceService {
  static final FaceService _instance = FaceService._internal();
  factory FaceService() => _instance;
  FaceService._internal();

  Interpreter? _interpreter;

  // ✅ Carga del modelo MobileFaceNet para clustering
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      print('✅ Modelo MobileFaceNet cargado correctamente.');
    } catch (e) {
      print('❌ Error cargando el modelo: $e');
    }
  }

  // ✅ FILTRO DE CALIDAD: Ajustado para corredores lejanos
  bool isValidFace(img.Image faceImage) {
    // 1. Filtro de Tamaño: Bajamos de 80 a 40px para captar gente a lo lejos.
    // Un rostro de 40x40 en el moto g35 ya permite extraer rasgos básicos.
    if (faceImage.width < 40 || faceImage.height < 40) {
      // Log interno para depuración (opcional)
      // print('⚠️ Rostro descartado: Muy pequeño (${faceImage.width}x${faceImage.height})');
      return false;
    }

    // 2. Filtro de Proporción: Los corredores a veces inclinan la cabeza.
    // Flexibilizamos el ratio para evitar falsos descartes en movimiento.
    double aspect = faceImage.width / faceImage.height;
    if (aspect < 0.5 || aspect > 1.8) {
      return false;
    }

    return true;
  }

  // ✅ Generación de Face Embedding para reconocimiento
  List<double> getFaceEmbedding(img.Image faceImage) {
    if (_interpreter == null) return [];

    // Aplicar validación de calidad antes de procesar
    if (!isValidFace(faceImage)) return [];

    // Preparación del buffer de entrada (112x112x3)
    var input = List.generate(1, (i) => List.generate(112, (y) =>
        List.generate(112, (x) => List.generate(3, (c) => 0.0))));

    // Redimensionar el recorte al tamaño que requiere el modelo
    img.Image resized = img.copyResize(faceImage, width: 112, height: 112);

    for (var y = 0; y < 112; y++) {
      for (var x = 0; x < 112; x++) {
        var pixel = resized.getPixel(x, y);
        // Normalización estándar: (pixel - 128) / 128
        input[0][y][x][0] = (pixel.r - 128) / 128.0;
        input[0][y][x][1] = (pixel.g - 128) / 128.0;
        input[0][y][x][2] = (pixel.b - 128) / 128.0;
      }
    }

    // Buffer de salida para el vector de 192 dimensiones
    var output = List.filled(1 * 192, 0.0).reshape([1, 192]);

    try {
      _interpreter!.run(input, output);
    } catch (e) {
      print('❌ Error en inferencia TFLite: $e');
      return [];
    }

    return List<double>.from(output[0]);
  }
}