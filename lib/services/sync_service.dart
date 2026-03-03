// Propósito: El "Cartero". Toma las fotos pendientes de la base de datos y las
// empuja por internet (HTTP) hacia el servidor de Cloudflare, manejando tiempos de espera (timeouts).

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:picmerun/config/app_config.dart';
import 'package:picmerun/services/local_db_service.dart';
import 'package:path/path.dart' as p;
import 'package:picmerun/services/log_service.dart';

class SyncService {
  //  Mantenemos tu URL directa para asegurar la conexión
  final String _backendUrl = 'https://morning-frog-acd5.gregorio-paz.workers.dev/upload';

  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  /// Sincroniza los torsos pendientes en la cola de procesamiento de Gregorio
  Future<int> uploadPendingTorsos() async {
    final pendingTorsos = await LocalDBService.instance.getPendingTorsos();

    if (pendingTorsos.isEmpty) {
      // Usamos el Log de la app en lugar de un print oculto
      await LogService.write(" PicMeRun: No hay torsos pendientes de envío.");
      return 0;
    }

    await LogService.write(" Iniciando sincronización de ${pendingTorsos.length} archivos...");
    int subidosCount = 0;

    for (var torso in pendingTorsos) {
      bool exito = await _uploadOneTorso(torso);
      if (exito) {
        subidosCount++;
      }
    }

    await LogService.write(" Sincronización finalizada. Total subidos: $subidosCount");
    return subidosCount;
  }

  /// Sube un archivo individual cumpliendo con los requisitos del Worker
  Future<bool> _uploadOneTorso(Map<String, dynamic> torso) async {
    try {
      final File imageFile = File(torso['file_url'] ?? torso['torso_image_url']);

      //  FIX 1: Unificamos la validación. Si no existe, avisa Y limpia la base de datos.
      if (!imageFile.existsSync()) {
        await LogService.write(" Archivo fantasma detectado. Limpiando ID: ${torso['photo_id']}");
        await LocalDBService.instance.deletePhoto(torso['photo_id']);
        return false;
      }

      var request = http.MultipartRequest('POST', Uri.parse(_backendUrl));

      String fileName = p.basename(imageFile.path);
      String hash = fileName.split('_').last.replaceAll('.jpg', '');

      request.fields['file_hash'] = hash;
      request.fields['photo_id'] = torso['photo_id'].toString();
      request.fields['timestamp'] = DateTime.now().toIso8601String();
      request.fields['match_threshold'] = AppConfig.identityMatchThreshold.toString();

      var multipartFile = await http.MultipartFile.fromPath('image', imageFile.path);
      request.files.add(multipartFile);

      await LogService.write(" Subiendo a Cloudflare: Hash $hash...");

      // Límite estricto de 15 segundos para evitar que la app se congele si no hay 4G
      var streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final respData = jsonDecode(response.body);

        if (respData['success'] == true) {
          await LogService.write(" ÉXITO: Archivo $hash recibido por Cloudflare D1.");
          // Cambiar el estado a 'done' para que desaparezca de la cola
          await LocalDBService.instance.updateTorsoStatus(torso['id'], 'done');
          return true;
        } else {
          await LogService.write(" Servidor rechazó el archivo: ${respData['message']}");
        }
      } else {
        await LogService.write(" Error HTTP ${response.statusCode}: Servidor no disponible.");
      }
    } catch (e) {
      //  FIX 2: Capturamos fallos de red (timeouts, sin internet) en la terminal de la app
      await LogService.write(" Fallo crítico de red (Revisar conexión): $e");
    }
    return false;
  }
}