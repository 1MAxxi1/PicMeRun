import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageService {
  // Nombres de las carpetas principales
  static const String folderOriginals = "PicMeRun-Originals";
  static const String folderFaces = "PicMeRun-Caras";

  Future<void> initStorage() async {
    // 1. Obtenemos la ruta base del almacenamiento externo (SD o emulada)
    final directory = await getExternalStorageDirectory();

    if (directory != null) {
      // 2. Definimos las rutas completas
      final String pathOriginals = '${directory.path}/$folderOriginals';
      final String pathFaces = '${directory.path}/$folderFaces';

      // 3. Creamos las carpetas si no existen
      await Directory(pathOriginals).create(recursive: true);
      await Directory(pathFaces).create(recursive: true);

      print("✅ Carpetas creadas en: ${directory.path}");
    }
  }

  // Helper para obtener la ruta de guardado rápido
  Future<String> getPath(bool isAudit) async {
    final directory = await getExternalStorageDirectory();
    final folder = isAudit ? folderFaces : folderOriginals;
    return '${directory!.path}/$folder';
  }
}