//log que esta en gestion de imagenes

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:async'; // ✅ Necesario para el Completer

class LogService {
  // ✅ Lock para evitar escrituras simultáneas (Race Conditions)
  static Completer<void>? _writingTask;

  static Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    final logDir = Directory('${directory.path}/PicMeRun');

    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    return File('${logDir.path}/app_logs.txt');
  }

  // ✅ Escribe un mensaje de forma secuencial (Ideal para Ráfagas)
  static Future<void> write(String message) async {
    // Si hay una escritura en curso, esperamos a que termine
    while (_writingTask != null) {
      await _writingTask!.future;
    }

    _writingTask = Completer<void>();

    try {
      final file = await _localFile;
      final timestamp = DateTime.now().toLocal().toString().split('.')[0];

      // Escribimos en el archivo físico
      await file.writeAsString('$timestamp: $message\n', mode: FileMode.append, flush: true);

      debugPrint("LOG: $message");
    } catch (e) {
      debugPrint("Error escribiendo log: $e");
    } finally {
      // ✅ Liberamos el lock para la siguiente foto de la ráfaga
      final task = _writingTask;
      _writingTask = null;
      task?.complete();
    }
  }

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

  static Future<void> clear() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        await file.writeAsString('', flush: true);
        debugPrint("Logs de PicMeRun limpiados correctamente.");
      }
    } catch (e) {
      debugPrint("Error al limpiar logs: $e");
    }
  }
}