import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class LogService {
  // ✅ Obtiene la ruta del archivo de logs de forma centralizada
  static Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    final logDir = Directory('${directory.path}/PicMeRun');

    // Crea la carpeta si no existe para evitar errores de "File not found"
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    return File('${logDir.path}/app_logs.txt');
  }

  // ✅ Escribe un mensaje con timestamp
  static Future<void> write(String message) async {
    try {
      final file = await _localFile;
      final timestamp = DateTime.now().toLocal().toString().split('.')[0];

      // Escribe en el archivo físico
      await file.writeAsString('$timestamp: $message\n', mode: FileMode.append);

      // También lo muestra en la consola de debug del IDE
      debugPrint("LOG: $message");
    } catch (e) {
      debugPrint("Error escribiendo log: $e");
    }
  }

  // ✅ Lee todos los logs para la pantalla de Auditoría IA
  static Future<String> getLogs() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        return contents.isEmpty ? "El archivo de logs está vacío." : contents;
      }
      return "No se ha generado ningún registro de auditoría aún.";
    } catch (e) {
      return "Error al leer los logs: $e";
    }
  }

  // ✅ Limpia el historial para iniciar una nueva iteración de pruebas
  static Future<void> clear() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        await file.writeAsString(''); // Limpia el contenido sin borrar el archivo
        debugPrint("Logs de PicMeRun limpiados correctamente.");
      }
    } catch (e) {
      debugPrint("Error al limpiar logs: $e");
    }
  }
}