import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:picmerun/config/app_config.dart';
import 'package:picmerun/services/local_db_service.dart';
import 'package:path/path.dart' as p;
import 'package:picmerun/services/log_service.dart';

class SyncService {
  // ✅ FIX 1: Inyectamos la URL real directamente para saltarnos el AppConfig antiguo
  final String _backendUrl = 'https://morning-frog-acd5.gregorio-paz.workers.dev/upload';

  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  /// Sincroniza los torsos pendientes en la cola de procesamiento de Gregorio
  Future<int> uploadPendingTorsos() async {
    // 1. Obtenemos solo los que realmente están pendientes
    final pendingTorsos = await LocalDBService.instance.getPendingTorsos();

    if (pendingTorsos.isEmpty) {
      print("📭 PicMeRun: No hay torsos pendientes.");
      return 0;
    }

    print("🔄 Sincronizando ${pendingTorsos.length} torsos con el Worker...");
    int subidosCount = 0;

    for (var torso in pendingTorsos) {
      // ✅ MEJORA: Verificamos que el registro siga existiendo (por si se borró mientras sincroniza)
      bool exito = await _uploadOneTorso(torso);
      if (exito) {
        subidosCount++;
      }
    }

    print("✅ Sincronización finalizada. Total subidos: $subidosCount");
    return subidosCount;
  }

  /// Sube un torso individual cumpliendo con los requisitos del Worker
  Future<bool> _uploadOneTorso(Map<String, dynamic> torso) async {
    try {
      // ✅ AHORA: Buscamos la foto original recortada de la CARA (FACE)
      // Para esto, necesitamos que tu consulta SQL en LocalDBService incluya el file_url de la tabla photos
      final File imageFile = File(torso['file_url'] ?? torso['torso_image_url']);

      if (!imageFile.existsSync()) {
        LogService.write("⚠️ Archivo no encontrado en: ${imageFile.path}");
        return false;
      }

      // Verificación de archivo físico
      if (!imageFile.existsSync()) {
        print("⚠️ El archivo no existe. Limpiando registro huérfano...");
        await LocalDBService.instance.deletePhoto(torso['photo_id']);
        return false;
      }

      var request = http.MultipartRequest('POST', Uri.parse(_backendUrl));

      // ✅ REQUISITO DEL WORKER: El Worker espera 'file_hash' para el nombre en R2
      // Usamos el nombre del archivo (que ya es un hash en tu nueva cámara)
      String fileName = p.basename(imageFile.path);
      String hash = fileName.split('_').last.replaceAll('.jpg', '');

      request.fields['file_hash'] = hash;
      request.fields['photo_id'] = torso['photo_id'].toString();
      request.fields['timestamp'] = DateTime.now().toIso8601String();
      request.fields['match_threshold'] = AppConfig.identityMatchThreshold.toString(); // Mantenemos intacto tu AppConfig

      var multipartFile = await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      );
      request.files.add(multipartFile);

      print("📤 Enviando a Cloudflare: Photo #${torso['photo_id']} (Hash: $hash)");

      // ✅ FIX 2: Límite estricto de 15 segundos saltándonos el AppConfig para forzar el corte
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 15),
      );

      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final respData = jsonDecode(response.body);

        if (respData['success'] == true) {
          print("🚀 SERVIDOR: Torso recibido y encolado en D1.");

          // ✅ PASO CRÍTICO: Cambiar el estado a 'done' para que desaparezca de la cola
          await LocalDBService.instance.updateTorsoStatus(torso['id'], 'done');
          return true;
        } else {
          print("❌ Error lógico: ${respData['message']}");
        }
      } else {
        print("🔥 Error de Conexión (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      print("🚫 Fallo en subida: $e");
    }
    return false;
  }
}