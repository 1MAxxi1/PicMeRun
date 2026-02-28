//galeria de la app picmerun donde esta galeria con fotos originales y galeria picmerun-caras que ahi estan las
//fotos originales + bounding box

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:picmerun/services/storage_service.dart';
import 'package:picmerun/services/local_db_service.dart';

class InternalGalleryScreen extends StatefulWidget {
  const InternalGalleryScreen({super.key});

  @override
  State<InternalGalleryScreen> createState() => _InternalGalleryScreenState();
}

class _InternalGalleryScreenState extends State<InternalGalleryScreen> {
  final StorageService _storage = StorageService();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text("Galerías PicMeRun"),
          bottom: const TabBar(
            indicatorColor: Colors.red,
            labelColor: Colors.red,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.photo_outlined), text: "PicMeRun-Originales"),
              Tab(icon: Icon(Icons.face_retouching_natural), text: "PicMeRun-Caras"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGrid(isAudit: false),
            _buildGrid(isAudit: true),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid({required bool isAudit}) {
    return FutureBuilder<String>(
      future: _storage.getPath(isAudit),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final directory = Directory(snapshot.data!);
        if (!directory.existsSync()) return const Center(child: Text("Sin capturas"));

        final files = directory.listSync().whereType<File>().toList();

        if (files.isEmpty) {
          return const Center(child: Text("Galería vacía"));
        }

        // Ordenamos por fecha para ver las últimas primero
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4
          ),
          itemCount: files.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _showFullScreen(files[index]),
              child: Hero(
                tag: files[index].path,
                child: Image.file(files[index], fit: BoxFit.cover),
              ),
            );
          },
        );
      },
    );
  }

  void _showFullScreen(File file) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(file),
            ),
          ],
        ),
        body: Center(
          child: Hero(
            tag: file.path,
            child: InteractiveViewer(
              child: Image.file(file),
            ),
          ),
        ),
      ),
    ));
  }

  // ✅ MEJORA: Borrado Inteligente y Sincronizado (Original + Auditoría + DB)
  Future<void> _confirmDelete(File file) async {
    final bool? delete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar de forma permanente?"),
        content: const Text("Se borrará la foto original, su versión de auditoría y el registro en la base de datos."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar")
          ),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Eliminar", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (delete == true) {
      try {
        final storage = StorageService();
        final String path = file.path;
        final String fileName = path.split('/').last;

        String originalDir = await storage.getPath(false);
        String auditDir = await storage.getPath(true);

        File? originalFile;
        File? auditFile;

        // Identificar quién es quién para borrar la pareja
        if (fileName.startsWith("AUDIT_")) {
          auditFile = file;
          // Reconstruimos la ruta de la original quitando el prefijo
          originalFile = File('$originalDir/${fileName.replaceFirst("AUDIT_", "")}');
        } else {
          originalFile = file;
          // Reconstruimos la ruta de la auditoría añadiendo el prefijo
          auditFile = File('$auditDir/AUDIT_$fileName');
        }

        // 1. Borrado en SQLite (Siempre basado en la ruta de la original)
        await LocalDBService.instance.deletePhotoByPath(originalFile.path);

        // 2. Borrado físico de AMBOS archivos
        if (await originalFile.exists()) await originalFile.delete();
        if (await auditFile.exists()) await auditFile.delete();

        if (mounted) {
          Navigator.pop(context); // Salir de pantalla completa
          setState(() {}); // Refrescar la cuadrícula
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🗑️ Limpieza completa: Archivos y registros eliminados"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al eliminar: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}