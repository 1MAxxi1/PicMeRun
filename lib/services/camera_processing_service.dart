// Propósito: Cuando se toma una imagen, este servicio activa la Inteligencia Artificial
// (Google ML Kit), filtra las caras válidas y guarda todo en la base de datos.
// Optimizado para procesamiento masivo (Protocolo V12.0).

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:picmerun/services/local_db_service.dart';
import 'package:picmerun/services/log_service.dart';
import 'package:picmerun/services/storage_service.dart';
import 'package:picmerun/services/image_audit_service.dart';

class CameraProcessingService {
  // En fotografía deportiva, la velocidad es clave para que el hardware no sufra.
  static final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: false, // Desactivamos puntos faciales innecesarios para ganar velocidad
      enableClassification: false, // No necesitamos saber si sonríe o tiene ojos abiertos
      minFaceSize: 0.1,
    ),
  );

  static Future<void> processPhoto(XFile image, double selectedPixels) async {
    try {
      final File tempFile = File(image.path);

      // Verificamos existencia antes de procesar
      if (!await tempFile.exists()) return;

      final storage = StorageService();
      final String originalsDir = await storage.getPath(false);
      final String facesDir = await storage.getPath(true);
      final String ts = DateTime.now().millisecondsSinceEpoch.toString();

      final String cleanPath = '$originalsDir/LIMPIA_$ts.jpg';
      final String auditPath = '$facesDir/MARCOS_$ts.jpg';

      // 1. Detección de caras (ML Kit nativo)
      final List<Face> allFaces = await _faceDetector.processImage(InputImage.fromFile(tempFile));

      // 2. Filtramos la biometría
      final List<Face> validFaces = [];
      for (Face face in allFaces) {
        // Filtro por tamaño (mínimo 50px de ancho)
        if (face.boundingBox.width < 50) continue;

        // Filtro por ángulo (perfil hasta 80°)
        if (face.headEulerAngleY != null && face.headEulerAngleY!.abs() < 80.0) {
          validFaces.add(face);
        }
      }

      // 3. Mandamos al Isolate a dibujar
      final resultAudit = await compute(ImageAuditService.isolateAuditPipeline, {
        'rawPath': tempFile.path,
        'cleanSavePath': cleanPath,
        'auditSavePath': auditPath,
        'targetArea': selectedPixels,
        'faces': validFaces.map((f) {
          return {
            'left': f.boundingBox.left,
            'top': f.boundingBox.top,
            'right': f.boundingBox.right,
            'bottom': f.boundingBox.bottom,
            'angleY': f.headEulerAngleY ?? 0.0,
            'faceWidth': f.boundingBox.width,
          };
        }).toList(),
      });

      // Guardamos en la Base de Datos y escribimos el Log Profesional
      if (resultAudit != null) {
        final int photoId = await LocalDBService.instance.insertPhoto({
          'hash_photo': resultAudit['cleanHash'],
          'event_id': 1,
          'photographer_id': 1,
          'file_url': auditPath,
          'taken_at': DateTime.now().toIso8601String(),
        });

        await LocalDBService.instance.insertTorsoQueue({
          'photo_id': photoId,
          'torso_image_url': cleanPath,
          'status': 'pending',
        });

        final String finalRes = resultAudit['final_resolution'];
        final String finalWeight = resultAudit['cleanSizeMb'] + "MB";

        //  MEJORA 3: Formateo limpio para que coincida con el Regex de tu pantalla de logs
        String telemetryLog = validFaces.isEmpty
            ? "Sin datos"
            : validFaces.map((f) {
          // Eliminamos el símbolo ° para facilitar el procesamiento de texto
          return "[ANG: ${f.headEulerAngleY?.abs().toStringAsFixed(1)} | ${f.boundingBox.width.toInt()} PX]";
        }).join(", ");

        await LogService.write(" Foto #$photoId | Caras: ${validFaces.length} | Detalles: $telemetryLog | Res: $finalRes | Peso: $finalWeight");
      }
    } catch (e) {
      await LogService.write(" Error background: $e");
    }
  }

  // Limpiamos la memoria al cerrar
  static void dispose() {
    _faceDetector.close();
  }
}