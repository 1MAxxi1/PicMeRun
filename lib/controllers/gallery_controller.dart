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

  // 🚀 NUEVA MEJORA SENIOR: Borrado Múltiple (Estilo Google Photos)
  // Recibe un "Set" (lista sin duplicados) de fotos y las destruye en lote
  // recargando la UI una sola vez al terminar para ahorrar batería y RAM.
  Future<bool> deleteMultiplePhotos(Set<File> filesToDelete) async {
    if (filesToDelete.isEmpty) return false;

    isLoading = true;
    notifyListeners();

    try {
      String originalDir = await _storage.getPath(false);
      String auditDir = await _storage.getPath(true);

      for (var selectedFile in filesToDelete) {
        final String path = selectedFile.path;
        final String fileName = path.split('/').last;

        File? originalFile;
        File? auditFile;
        String timestamp = "";

        // Encontramos la gemela
        if (fileName.startsWith("MARCOS_")) {
          auditFile = selectedFile;
          timestamp = fileName.replaceFirst("MARCOS_", "");
          originalFile = File('$originalDir/LIMPIA_$timestamp');
        } else if (fileName.startsWith("LIMPIA_")) {
          originalFile = selectedFile;
          timestamp = fileName.replaceFirst("LIMPIA_", "");
          auditFile = File('$auditDir/MARCOS_$timestamp');
        } else {
          originalFile = selectedFile;
        }

        // Destrucción física
        if (originalFile != null && await originalFile.exists()) await originalFile.delete();
        if (auditFile != null && await auditFile.exists()) await auditFile.delete();

        // Destrucción en BD
        if (auditFile != null) {
          await LocalDBService.instance.deletePhotoByPath(auditFile.path);
        }
      }

      // 🧹 Recargamos una sola vez al terminar la masacre
      await loadGalleries();
      return true;
    } catch (e) {
      debugPrint("❌ Error en borrado múltiple: $e");
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 🚀 NUEVA MEJORA SENIOR: El "Botón Nuclear"
  // Borra TODAS las fotos de las carpetas y limpia la base de datos de un solo golpe.
  Future<bool> deleteAllPhotos() async {
    isLoading = true;
    notifyListeners(); // Mostramos el loader en pantalla mientras destruimos todo

    try {
      // 1. Limpiamos la Base de Datos usando la lista de fotos con rostros (MARCOS_)
      // ya que la base de datos guarda la ruta de las fotos procesadas.
      for (var file in faceFiles) {
        await LocalDBService.instance.deletePhotoByPath(file.path);
      }

      // 2. Arrasamos con las carpetas físicas
      String originalDir = await _storage.getPath(false);
      String facesDir = await _storage.getPath(true);

      final origDirObj = Directory(originalDir);
      if (origDirObj.existsSync()) {
        for (var file in origDirObj.listSync()) {
          if (file is File) await file.delete();
        }
      }

      final faceDirObj = Directory(facesDir);
      if (faceDirObj.existsSync()) {
        for (var file in faceDirObj.listSync()) {
          if (file is File) await file.delete();
        }
      }

      // 3. Vaciamos las listas en memoria RAM
      originalFiles.clear();
      faceFiles.clear();

      return true;
    } catch (e) {
      debugPrint("❌ Error en borrado masivo: $e");
      return false;
    } finally {
      isLoading = false;
      notifyListeners(); // Quitamos el loader y mostramos el "Empty State" hermoso que hicimos
    }
  }
}