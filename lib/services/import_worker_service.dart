import 'dart:io';
import 'package:flutter/foundation.dart';
import 'local_db_service.dart';
import 'camera_processing_service.dart';
import 'log_service.dart';
import 'package:image_picker/image_picker.dart';

class ImportWorkerService {
  static final ImportWorkerService instance = ImportWorkerService._internal();
  ImportWorkerService._internal();

  bool _isProcessing = false;

  // El Bucle Principal (El "Worker" tipo Celery)
  Future<void> startProcessing(double targetPixels) async {
    if (_isProcessing) return;

    try {
      _isProcessing = true;
      // Retraso seguro de 1 segundo para asegurar que la DB ya tiene los datos asimilados
      await Future.delayed(const Duration(seconds: 1));

      await LogService.write("👷 Worker: Motor encendido.");

      while (true) {
        final task = await LocalDBService.instance.getNextImportTask();

        if (task == null) {
          print("✅ Worker: Cola vacía. No hay más fotos 'pending'.");
          break; // Sale del bucle while y apaga el motor
        }

        final int id = task['id'];
        final String filePath = task['file_path'];

        try {
          // Marcamos la tarea como 'processing'
          await LocalDBService.instance.updateImportStatus(id, 'processing');
          print("📸 Worker: Procesando foto ID $id - Ruta: $filePath");

          final File imageFile = File(filePath);

          if (await imageFile.exists()) {
            final XFile xFileForProcessing = XFile(imageFile.path);

            // 🚀 LLAMADA AL MOTOR DE IA Y RESIZE
            await CameraProcessingService.processPhoto(xFileForProcessing, targetPixels);

            // Marcamos como completada
            await LocalDBService.instance.updateImportStatus(id, 'completed');
            print("✔ Foto $id procesada con éxito.");
          } else {
            // Manejo de error si FilePicker devuelve un URI temporal no válido
            await LocalDBService.instance.updateImportStatus(id, 'failed', error: "El archivo no existe en el disco");
            print("❌ Error en foto $id: El archivo no existe.");
          }
        } catch (e) {
          print("❌ Error en foto $id: $e");
          await LocalDBService.instance.updateImportStatus(id, 'failed', error: e.toString());
        }

        // Respiro de 200ms para evitar sobrecargar el procesador del Moto G35
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (e) {
      print("🚨 Error Crítico en el Worker: $e");
    } finally {
      // Liberamos el motor para que pueda volver a arrancar después
      _isProcessing = false;
      print("👷 Worker: Motor apagado y listo para la siguiente tanda.");
    }
  }

  // Método para consultar si el obrero está activo (útil para la UI)
  bool get isProcessing => _isProcessing;
}