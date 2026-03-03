// Propósito: La vitrina de fotos. Una interfaz "tonta" que solo dibuja la cuadrícula
// de imágenes preguntándole a su controlador qué fotos existen.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:picmerun/controllers/gallery_controller.dart'; // <-- El Nuevo Cerebro

class InternalGalleryScreen extends StatefulWidget {
  const InternalGalleryScreen({super.key});

  @override
  State<InternalGalleryScreen> createState() => _InternalGalleryScreenState();
}

class _InternalGalleryScreenState extends State<InternalGalleryScreen> {
  // Instanciamos el Controlador
  final GalleryController _controller = GalleryController();

  @override
  void initState() {
    super.initState();
    // Le pedimos al controlador que busque las fotos al abrir la pantalla
    _controller.loadGalleries();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder redibuja la pantalla automáticamente cuando el controlador avisa
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
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
            body: _controller.isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.red))
                : TabBarView(
              children: [
                _buildGrid(_controller.originalFiles),
                _buildGrid(_controller.faceFiles),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<File> files) {
    if (files.isEmpty) {
      return const Center(child: Text("Galería vacía", style: TextStyle(fontSize: 16, color: Colors.grey)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return GestureDetector(
          onTap: () => _showFullScreen(file),
          child: Hero(
            tag: file.path,
            child: Image.file(file, fit: BoxFit.cover),
          ),
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
      // La vista solo le avisa al cerebro que haga el trabajo sucio
      final success = await _controller.deletePhotoPair(file);

      if (mounted) {
        Navigator.pop(context); // Cierra la pantalla completa
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Limpieza completa"), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error al eliminar"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}