import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CloudService {
  // Aquí pondremos la URL de tu Cloudflare Worker cuando lo creemos
  static const String _workerUrl = 'https://tu-worker.workers.dev/upload';

  static Future<bool> uploadRunnerData({
    required Uint8List originalBytes,
    required Uint8List faceBytes,
    required Uint8List torsoBytes,
    required List<double> faceEmbedding, // Para el Punto 2 (Vectores)
  }) async {
    try {
      // 1. Convertimos los bytes a Base64 para que viajen como texto
      final payload = jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'image_original': base64Encode(originalBytes),
        'image_face': base64Encode(faceBytes),
        'image_torso': base64Encode(torsoBytes),
        'embedding': faceEmbedding, // El ADN del corredor
      });

      // 2. Enviamos el paquete a Cloudflare
      final response = await http.post(
        Uri.parse(_workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );

      if (response.statusCode == 200) {
        print("Sincronización exitosa con Cloudflare D1/R2");
        return true;
      } else {
        print("Error en el servidor: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error de red: $e");
      return false;
    }
  }
}