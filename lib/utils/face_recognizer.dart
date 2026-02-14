import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceRecognizer {
  Interpreter? _interpreter;

  // DATOS TÉCNICOS DEL MODELO
  // MobileFaceNet estándar usa entrada de 112x112 píxeles
  static const int inputSize = 112;
  // La salida suele ser un vector de 192 dimensiones (a veces 128)
  int outputSize = 192;

  /// 1. Carga el modelo en memoria (Llamar al iniciar la app)
  Future<void> loadModel() async {
    try {
      // Opciones para mejorar rendimiento en Android (GPU/CPU)
      final options = InterpreterOptions();

      // Carga desde assets
      _interpreter = await Interpreter.fromAsset(
          'assets/mobilefacenet.tflite',
          options: options
      );

      // Verificación de dimensiones automática
      // Esto ajusta el tamaño de salida si tu modelo es de 128 o 192
      var outputTensor = _interpreter!.getOutputTensor(0);
      outputSize = outputTensor.shape.last;

      debugPrint("✅ CEREBRO IA: Modelo cargado correctamente.");
      debugPrint("ℹ️ Input esperado: ${_interpreter!.getInputTensor(0).shape}");
      debugPrint("ℹ️ Output detectado: $outputSize dimensiones");

    } catch (e) {
      debugPrint("❌ ERROR FATAL IA: No se pudo cargar el modelo.");
      debugPrint("Detalles: $e");
    }
  }

  /// 2. Procesa la imagen y devuelve el Vector (Embedding)
  List<double> extractEmbedding(Uint8List faceBytes) {
    if (_interpreter == null) {
      debugPrint("⚠️ Advertencia: El modelo no está cargado.");
      return [];
    }

    try {
      // A. Decodificar la imagen (de bytes a bitmap)
      img.Image? originalImage = img.decodeImage(faceBytes);
      if (originalImage == null) return [];

      // B. Redimensionar a 112x112 (Requisito estricto de MobileFaceNet)
      img.Image resizedImage = img.copyResize(
          originalImage,
          width: inputSize,
          height: inputSize
      );

      // C. Preprocesamiento matemático (Normalización)
      // Convertimos píxeles [0-255] a flotantes [-1, 1]
      var input = _imageToFloat32(resizedImage);

      // D. Ajustar la forma del input a [1, 112, 112, 3]
      var inputTensor = input.reshape([1, inputSize, inputSize, 3]);

      // E. Preparar el contenedor de salida
      var outputTensor = List.filled(1 * outputSize, 0.0).reshape([1, outputSize]);

      // F. EJECUTAR INFERENCIA (El momento de la verdad)
      _interpreter!.run(inputTensor, outputTensor);

      // G. Aplanar y devolver el vector
      return List<double>.from(outputTensor[0]);

    } catch (e) {
      debugPrint("❌ Error al generar embedding: $e");
      return [];
    }
  }

  /// Función auxiliar: Convierte píxeles a Float32 normalizado
  Float32List _imageToFloat32(img.Image image) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);

        // Normalización estándar MobileFaceNet: (Valor - 128) / 128
        // Esto pone los valores entre -1.0 y 1.0
        buffer[pixelIndex++] = (pixel.r - 128) / 128.0;
        buffer[pixelIndex++] = (pixel.g - 128) / 128.0;
        buffer[pixelIndex++] = (pixel.b - 128) / 128.0;
      }
    }
    return convertedBytes;
  }

  /// Liberar memoria al cerrar la app
  void close() {
    _interpreter?.close();
  }
}