import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class PhotoPreviewScreen extends StatefulWidget {
  final String imagePath;
  const PhotoPreviewScreen({super.key, required this.imagePath});

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  bool _isSaving = false;

  // Lógica Senior: Subida asíncrona no bloqueante
  Future<void> _uploadPhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    final String imagePath = widget.imagePath;

    // 1. Cerramos la pantalla de inmediato para volver a la cámara
    Navigator.pop(context);

    // 2. Notificamos al usuario
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 15),
            Text('Sincronizando foto en segundo plano...'),
          ],
        ),
        duration: Duration(seconds: 3),
      ),
    );

    // 3. Proceso de fondo (Aquí irá tu integración con la nube de Gregorio)
    try {
      await Future.delayed(const Duration(seconds: 4)); // Simulación de red

      messenger.showSnackBar(
        const SnackBar(
          content: Text('¡Foto de corredor subida con éxito!'),
          backgroundColor: Colors.green,
        ),
      );
      print("INFO: Imagen $imagePath procesada con éxito.");
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error al subir: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _savePhoto() async {
    setState(() => _isSaving = true);
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String photosDir = path.join(appDir.path, 'PicMeRun_Photos');
      final Directory dir = Directory(photosDir);

      if (!await dir.exists()) await dir.create(recursive: true);

      final String fileName = 'RUNNER_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String newPath = path.join(photosDir, fileName);

      await File(widget.imagePath).copy(newPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Guardada localmente: $fileName'), backgroundColor: Colors.blue),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Confirmar Captura'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Image.file(File(widget.imagePath), fit: BoxFit.contain),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            color: Colors.black.withOpacity(0.8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBtn(Icons.save, 'Local', _isSaving ? null : _savePhoto, Colors.grey),
                _buildBtn(Icons.cloud_upload, 'Subir a Nube', _uploadPhoto, Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBtn(IconData icon, String label, VoidCallback? action, Color color) {
    return Column(
      children: [
        FloatingActionButton(
          onPressed: action,
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}