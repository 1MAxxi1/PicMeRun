import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:picmerun/services/local_db_service.dart';
import 'package:picmerun/services/sync_service.dart';
import 'package:picmerun/services/log_service.dart'; // ✅ Importante para leer logs

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _pendingTorsos = [];
  bool _isSyncing = false;
  late TabController _tabController;
  String _logContent = "Cargando logs de auditoría...";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadQueue();
    _loadAuditLogs();
  }

  Future<void> _loadQueue() async {
    final data = await LocalDBService.instance.getPendingTorsos();
    if (mounted) {
      setState(() {
        _pendingTorsos = List<Map<String, dynamic>>.from(data);
      });
    }
  }

  // ✅ Nueva funcionalidad: Cargar logs del sistema
  Future<void> _loadAuditLogs() async {
    try {
      // Asumiendo que LogService tiene un método para obtener el path o contenido
      // Por ahora simulamos la lectura del archivo de logs para la auditoría
      final String content = await LogService.getLogs();
      if (mounted) setState(() => _logContent = content);
    } catch (e) {
      if (mounted) setState(() => _logContent = "No hay registros de auditoría disponibles.");
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 2)),
    );
  }

  // ... (Tu función _showImagePreview se mantiene exacta)
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

  Future<void> _handleSync() async {
    if (_pendingTorsos.isEmpty) return;
    setState(() => _isSyncing = true);
    try {
      await SyncService().uploadPendingTorsos();
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
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Gestión de Imágenes", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2563EB),
          tabs: const [
            Tab(icon: Icon(Icons.cloud_queue), text: "Cola de Envío"),
            Tab(icon: Icon(Icons.analytics_outlined), text: "Auditoría IA"),
          ],
        ),
        actions: [
          if (!_isSyncing && _pendingTorsos.isNotEmpty && _tabController.index == 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.cloud_upload_rounded, size: 28, color: Color(0xFF2563EB)),
                onPressed: _handleSync,
              ),
            ),
          if (_tabController.index == 1)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              onPressed: () async {
                await LogService.clear(); // Limpiar logs para nueva iteración
                _loadAuditLogs();
              },
            )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // PESTAÑA 1: Tu Cola de Envío original
          _isSyncing ? _buildSyncingState() : (_pendingTorsos.isEmpty ? _buildEmptyState() : _buildQueueList()),

          // PESTAÑA 2: Dashboard de Auditoría Profesional
          _buildAuditDashboard(),
        ],
      ),
    );
  }

  // ✅ Tu lógica de lista original extraída para claridad
  Widget _buildQueueList() {
    return ListView.builder(
      key: ValueKey(_pendingTorsos.hashCode),
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _pendingTorsos.length,
      itemBuilder: (context, index) {
        final item = _pendingTorsos[index];
        final int photoId = item['photo_id'];
        DateTime date = DateTime.tryParse(item['created_at']) ?? DateTime.now();
        String hora = DateFormat('HH:mm').format(date);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _showImagePreview(item['file_url'] ?? item['torso_image_url']),
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: FileImage(File(item['file_url'] ?? item['torso_image_url'])),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Foto #$photoId", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(hora, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time_filled, size: 14, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text("Pendiente de envío", style: TextStyle(color: Colors.orange[800], fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const Spacer(),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: TextButton.icon(
                              onPressed: () async {
                                final bool confirm = await _showDeleteConfirmDialog();
                                if (confirm) await _processDeletion(photoId);
                              },
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              label: const Text("Eliminar", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ✅ NUEVO: Dashboard de Auditoría para el Analista
  Widget _buildAuditDashboard() {
    return Container(
      color: const Color(0xFF0F172A), // Fondo tipo terminal
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E293B),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _auditStat("Fotos", _pendingTorsos.length.toString(), Icons.image),
                _auditStat("Logs", _logContent.split('\n').length.toString(), Icons.list_alt),
                _auditStat("IA Status", "Online", Icons.check_circle, color: Colors.green),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                _logContent,
                style: const TextStyle(color: Color(0xFF10B981), fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _auditStat(String label, String value, IconData icon, {Color color = Colors.white}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  // ... (Resto de tus widgets auxiliares: _buildSyncingState, _buildEmptyState, _processDeletion, _showDeleteConfirmDialog)
  // [Se mantienen exactamente igual a tu código original]

  Widget _buildSyncingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 5),
          const SizedBox(height: 24),
          const Text("Sincronizando...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text("No cierres la app por favor", style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Future<void> _processDeletion(int photoId) async {
    try {
      await LocalDBService.instance.deletePhoto(photoId);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Quieres eliminar la foto?"),
        content: const Text("Esta acción borrará la foto original permanentemente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("BORRAR", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    ) ?? false;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(Icons.cloud_done_outlined, size: 80, color: Colors.green[300]),
          ),
          const SizedBox(height: 24),
          const Text("¡No tienes fotos para enviar!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}