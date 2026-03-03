// Propósito: El "Cerebro" de la galería. Se encarga de buscar, ordenar y eliminar
// las fotos físicas y sus registros en la base de datos, manteniendo la vista libre de lógica pesada.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:picmerun/services/storage_service.dart';
import 'package:picmerun/services/local_db_service.dart';

class GalleryController extends ChangeNotifier {
  final StorageService _storage = StorageService();

  List<File> originalFiles = [];
  List<File> faceFiles = [];
  bool isLoading = true;

  // Carga inicial de las dos galerías
  Future<void> loadGalleries() async {
    isLoading = true;
    notifyListeners();

    try {
      String originalDir = await _storage.getPath(false);
      String facesDir = await _storage.getPath(true);

      originalFiles = _getSortedFiles(originalDir);
      faceFiles = _getSortedFiles(facesDir);
    } catch (e) {
      debugPrint("Error cargando galerías: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Lee la carpeta y ordena por fecha (las más nuevas primero)
  List<File> _getSortedFiles(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) return [];

    final files = dir.listSync().whereType<File>().toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  // Borrado Inteligente (Arreglado para LIMPIA_ y MARCOS_)
  Future<bool> deletePhotoPair(File selectedFile) async {
    try {
      final String path = selectedFile.path;
      final String fileName = path.split('/').last;

      String originalDir = await _storage.getPath(false);
      String auditDir = await _storage.getPath(true);

      File? originalFile;
      File? auditFile;
      String timestamp = "";

      // Lógica para encontrar a la "gemela" según los nombres de la nueva cámara
      if (fileName.startsWith("MARCOS_")) {
        auditFile = selectedFile;
        timestamp = fileName.replaceFirst("MARCOS_", "");
        originalFile = File('$originalDir/LIMPIA_$timestamp');
      } else if (fileName.startsWith("LIMPIA_")) {
        originalFile = selectedFile;
        timestamp = fileName.replaceFirst("LIMPIA_", "");
        auditFile = File('$auditDir/MARCOS_$timestamp');
      } else {
        originalFile = selectedFile; // Fallback por si hay fotos muy antiguas
      }

      // 1. Borrado físico en el disco del celular
      if (originalFile != null && await originalFile.exists()) await originalFile.delete();
      if (auditFile != null && await auditFile.exists()) await auditFile.delete();

      // 2. Borrado en SQLite (Nuestra cámara guarda la ruta de MARCOS_ en file_url)
      if (auditFile != null) {
        await LocalDBService.instance.deletePhotoByPath(auditFile.path);
      }

      // 3. Recargar las listas para que la UI se actualice
      await loadGalleries();
      return true;
    } catch (e) {
      debugPrint("Error en borrado: $e");
      return false;
    }
  }
}