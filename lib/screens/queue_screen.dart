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

  // ✅ NUEVO: Memoria para la Selección Múltiple
  final Set<int> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

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
        // Si al recargar ya no existen las fotos seleccionadas, limpiamos la memoria
        _selectedIds.removeWhere((id) => !_pendingTorsos.any((t) => t['photo_id'] == id));
      });
    }
  }

  // ✅ Nueva funcionalidad: Cargar logs del sistema
  Future<void> _loadAuditLogs() async {
    try {
      final String content = await LogService.getLogs();
      if (mounted) setState(() => _logContent = content);
    } catch (e) {
      if (mounted) setState(() => _logContent = "No hay registros de auditoría disponibles.");
    }
  }

  void _showSnackBar(String message, Color color) {
    final messenger = ScaffoldMessenger.of(context);

    // 🧹 LA ESCOBA MÁGICA: Borra cualquier cartelito viejo que siga en pantalla
    messenger.clearSnackBars();

    // 💬 Muestra el mensaje nuevo de inmediato
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating, // Hace que flote un poco (se ve más moderno)
        duration: const Duration(seconds: 2), // Lo bajamos a 2 segundos para que sea rápido
      ),
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

  // ✅ NUEVO: Lógica para manejar el toque (Selección múltiple)
  void _toggleSelection(int photoId) {
    setState(() {
      if (_selectedIds.contains(photoId)) {
        _selectedIds.remove(photoId);
      } else {
        _selectedIds.add(photoId);
      }
    });
  }

  // ✅ NUEVO: Lógica para seleccionar/deseleccionar todas
  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _pendingTorsos.length) {
        _selectedIds.clear(); // Si están todas, las deselecciona
      } else {
        _selectedIds.addAll(_pendingTorsos.map((t) => t['photo_id'] as int)); // Selecciona todas
      }
    });
  }

  // ✅ NUEVO: Lógica para eliminar en bloque
  Future<void> _deleteSelected() async {
    final bool confirm = await _showDeleteConfirmDialog(isBulk: true);
    if (!confirm) return;

    final int count = _selectedIds.length;

    try {
      // Borramos una por una de la base de datos (o podrías hacer una query masiva en LocalDBService si la tuvieras)
      for (int id in _selectedIds) {
        await LocalDBService.instance.deletePhoto(id);
      }

      setState(() {
        _pendingTorsos.removeWhere((t) => _selectedIds.contains(t['photo_id']));
        _selectedIds.clear(); // Limpiamos la memoria después de borrar
      });

      _showSnackBar("🗑️ $count foto(s) eliminada(s) correctamente", Colors.redAccent);
    } catch (e) {
      _showSnackBar("⚠️ Error al eliminar fotos en bloque: $e", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      // ✅ AppBar Dinámico: Cambia si estamos en Modo Selección
      appBar: _isSelectionMode
          ? AppBar(
        backgroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => setState(() => _selectedIds.clear()),
        ),
        title: Text("${_selectedIds.length} seleccionadas", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(
                _selectedIds.length == _pendingTorsos.length ? Icons.deselect : Icons.select_all,
                color: Colors.white),
            onPressed: _toggleSelectAll,
            tooltip: "Seleccionar Todas",
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 28),
            onPressed: _deleteSelected,
            tooltip: "Eliminar Seleccionadas",
          ),
        ],
      )
          : AppBar(
        title: const Text("Gestión de Imágenes", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2563EB),
          tabs: const [
            Tab(icon: Icon(Icons.cloud_queue), text: "Cola de Envío"),
            Tab(icon: Icon(Icons.analytics_outlined), text: "Auditoría"),
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
        // ✅ Evitamos cambiar de pestaña si estamos seleccionando
        physics: _isSelectionMode ? const NeverScrollableScrollPhysics() : const ScrollPhysics(),
        children: [
          // PESTAÑA 1: Tu Cola de Envío original
          _isSyncing ? _buildSyncingState() : (_pendingTorsos.isEmpty ? _buildEmptyState() : _buildQueueList()),

          // PESTAÑA 2: Dashboard de Auditoría Profesional (Estilo Terminal)
          _buildAuditDashboard(),
        ],
      ),
    );
  }

  Widget _buildQueueList() {
    return ListView.builder(
      key: ValueKey(_pendingTorsos.hashCode),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemCount: _pendingTorsos.length,
      itemBuilder: (context, index) {
        final item = _pendingTorsos[index];

        final String displayPath = item['torso_image_url'] ?? item['file_url'];
        final int photoId = item['photo_id'];
        DateTime date = DateTime.tryParse(item['created_at']) ?? DateTime.now();
        String hora = DateFormat('HH:mm').format(date);

        final bool isSelected = _selectedIds.contains(photoId);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: GestureDetector(
            // ✅ NUEVO: Lógica de toques
            onLongPress: () => _toggleSelection(photoId),
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(photoId); // Si ya estamos en modo selección, el toque normal selecciona/deselecciona
              } else {
                _showImagePreview(displayPath); // Si no, abre la foto grande
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                // ✅ Efecto visual de seleccionado
                border: isSelected ? Border.all(color: Colors.blueAccent, width: 2) : Border.all(color: Colors.transparent, width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      // ✅ Checkbox y Miniatura
                      Stack(
                        children: [
                          Container(
                            width: 100,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: FileImage(File(displayPath)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          if (_isSelectionMode)
                            Positioned(
                              top: 5,
                              left: 5,
                              child: Container(
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                                child: Icon(
                                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: isSelected ? Colors.blueAccent : Colors.grey,
                                  size: 24,
                                ),
                              ),
                            ),
                        ],
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
                              // ✅ Ocultamos el botón "Eliminar" individual si estamos en Modo Selección
                              if (!_isSelectionMode)
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
            ),
          ),
        );
      },
    );
  }

  // ✅ MODIFICADO: Dashboard de Auditoría con diseño de Terminal
  Widget _buildAuditDashboard() {
    return Container(
      color: Colors.black, // Fondo negro estilo terminal
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "--- INFORMACIÓN DE LAS IMÁGENES ---",
            style: TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _logContent.isEmpty ? "No hay registros disponibles." : _logContent,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5, // Interlineado para mejor lectura
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Se eliminó la función _auditStat porque ya no se usa en el nuevo diseño

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

  // ✅ MODIFICADO: Adaptado para mostrar mensaje según si es borrado individual o múltiple
  Future<bool> _showDeleteConfirmDialog({bool isBulk = false}) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isBulk ? "¿Eliminar ${_selectedIds.length} fotos?" : "¿Quieres eliminar la foto?"),
        content: const Text("Esta acción borrará las fotos originales permanentemente de tu celular."),
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