// Propósito: El "Director de Orquesta" de la foto. Cuando se toma una
// imagen, este servicio activa la Inteligencia Artificial (Google ML Kit), filtra las
// caras válidas y guarda todo en la base de datos

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:picmerun/services/local_db_service.dart';
import 'package:picmerun/services/log_service.dart';
import 'package:picmerun/services/storage_service.dart';
import 'package:picmerun/services/image_audit_service.dart';

class CameraProcessingService {
  // Inicializamos la IA aquí adentro, protegiéndola de la interfaz gráfica
  static final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: true,
      enableClassification: true,
      minFaceSize: 0.20,
    ),
  );

  // El motor principal que procesa la foto en segundo plano
  static Future<void> processPhoto(XFile image, double selectedPixels) async {
    Future.microtask(() async {
      try {
        final File tempFile = File(image.path);
        final double sizeInMbOriginal = tempFile.lengthSync() / (1024 * 1024);
        final String weightLogOriginal = "${sizeInMbOriginal.toStringAsFixed(2)}MB";

        final storage = StorageService();
        final String originalsDir = await storage.getPath(false);
        final String facesDir = await storage.getPath(true);
        final String ts = DateTime.now().millisecondsSinceEpoch.toString();

        final String cleanPath = '$originalsDir/LIMPIA_$ts.jpg';
        final String auditPath = '$facesDir/MARCOS_$ts.jpg';

        // 1. La IA detecta las caras
        final List<Face> allFaces = await _faceDetector.processImage(InputImage.fromFile(tempFile));

        // 2. Filtramos la biometría
        final List<Face> validFaces = [];
        for (Face face in allFaces) {
          if (face.boundingBox.width < 75) continue;
          if (face.headEulerAngleY != null && face.headEulerAngleY!.abs() < 35.0) {
            validFaces.add(face);
          }
        }

        // 3. Mandamos al Isolate a dibujar la telemetría (Llamando al servicio que creaste antes)
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

        // 4. Guardamos en la Base de Datos y escribimos el Log
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

          String telemetryLog = validFaces.isEmpty
              ? "Sin datos"
              : validFaces.map((f) {
            return "[Ang: ${f.headEulerAngleY?.abs().toStringAsFixed(1)}° | ${f.boundingBox.width.toInt()}px]";
          }).join(", ");

          await LogService.write("Foto #$photoId | Caras: ${validFaces.length} | Detalles: $telemetryLog | Res: $finalRes | Peso: $finalWeight");
        }
      } catch (e) {
        await LogService.write("Error background: $e");
      }
    });
  }

  // Limpiamos la memoria al cerrar
  static void dispose() {
    _faceDetector.close();
  }
}