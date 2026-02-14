import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:picmerun/services/local_db_service.dart';
import 'package:picmerun/services/sync_service.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  // ✅ Usamos una lista inmutable para evitar persistencia de datos antiguos en caché
  List<Map<String, dynamic>> _pendingTorsos = [];
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  // ✅ Carga estricta: Solo lo que la DB diga que está 'pending'
  Future<void> _loadQueue() async {
    final data = await LocalDBService.instance.getPendingTorsos();
    if (mounted) {
      setState(() {
        // Creamos una copia nueva de la lista para forzar el refresco de UI
        _pendingTorsos = List<Map<String, dynamic>>.from(data);
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 2)),
    );
  }

  void _showImagePreview(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.file(File(imagePath), fit: BoxFit.contain),
            ),
            Positioned(
              top: 10, right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Mejora en Sincronización: Limpieza post-envío
  Future<void> _handleSync() async {
    if (_pendingTorsos.isEmpty) return;

    setState(() => _isSyncing = true);

    try {
      // 1. Ejecutar subida (El SyncService marcará como 'done' en DB)
      await SyncService().uploadPendingTorsos();

      // 2. RECARGA OBLIGATORIA: Traer la verdad absoluta de la DB
      await _loadQueue();

      _showSnackBar("✅ Sincronización finalizada", Colors.green);
    } catch (e) {
      _showSnackBar("⚠️ Error sincronizando: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Cola de Envío", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (!_isSyncing && _pendingTorsos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cloud_upload, size: 28),
              onPressed: _handleSync,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isSyncing
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _pendingTorsos.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        // ✅ El ValueKey con el Hash de la lista previene que los items borrados vuelvan a aparecer por error de renderizado
        key: ValueKey(_pendingTorsos.hashCode),
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _pendingTorsos.length,
        itemBuilder: (context, index) {
          final item = _pendingTorsos[index];
          final int photoId = item['photo_id'];

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: GestureDetector(
                onTap: () => _showImagePreview(item['torso_image_url']),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(item['torso_image_url']),
                    width: 60, height: 60, fit: BoxFit.cover,
                  ),
                ),
              ),
              title: Text("Torso de Foto #$photoId", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Pendiente de envío"),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent),
                onPressed: () async {
                  final bool confirm = await _showDeleteConfirmDialog();
                  if (confirm) {
                    await _processDeletion(photoId);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ Borrado atómico: Limpia Disco, DB y Memoria RAM
  Future<void> _processDeletion(int photoId) async {
    try {
      // 1. Borrado físico y en DB local (Usando el método robusto v5)
      await LocalDBService.instance.deletePhoto(photoId);

      // 2. Limpieza inmediata en UI para que no haya latencia
      setState(() {
        _pendingTorsos.removeWhere((t) => t['photo_id'] == photoId);
      });

      _showSnackBar("🗑️ Eliminado correctamente", Colors.redAccent);
    } catch (e) {
      _showSnackBar("⚠️ Error al eliminar: $e", Colors.red);
    }
  }

  Future<bool> _showDeleteConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar?"),
        content: const Text("Se borrará la foto y su recorte permanentemente de este dispositivo."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("NO")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("SÍ", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text("Cola vacía", style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          const Text("Todas tus fotos han sido enviadas o eliminadas."),
        ],
      ),
    );
  }
}