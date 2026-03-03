import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:picmerun/widgets/queue_item_card.dart';
import 'package:picmerun/theme/app_theme.dart';
import 'package:picmerun/utils/ui_helpers.dart';
import 'package:picmerun/controllers/queue_controller.dart'; // ✅ IMPORTAMOS EL NUEVO CEREBRO

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 🧠 INSTANCIAMOS EL CONTROLADOR (El Cerebro)
  final QueueController _controller = QueueController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Un pequeño truco Senior: Escuchamos si cambias de pestaña para actualizar la barra de arriba
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose(); // 🧹 Limpiamos la memoria al salir de la pantalla
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🪄 MAGIA: ListenableBuilder escucha al controlador y redibuja la UI automáticamente
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: AppTheme.backgroundLight,
          appBar: _controller.isSelectionMode
              ? AppBar(
            backgroundColor: AppTheme.backgroundDark,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              // 🗣️ La pantalla no piensa, solo le avisa al controlador
              onPressed: _controller.clearSelection,
            ),
            title: Text("${_controller.selectedIds.length} seleccionadas",
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: Icon(
                    _controller.selectedIds.length == _controller.pendingTorsos.length
                        ? Icons.deselect
                        : Icons.select_all,
                    color: Colors.white),
                onPressed: _controller.toggleSelectAll,
                tooltip: "Seleccionar Todas",
              ),
              IconButton(
                icon: const Icon(
                    Icons.delete_forever, color: AppTheme.error, size: 28),
                onPressed: () => _controller.deleteSelected(context),
                tooltip: "Eliminar Seleccionadas",
              ),
            ],
          )
              : AppBar(
            title: const Text("Gestión de Imágenes",
                style: TextStyle(fontWeight: FontWeight.bold)),
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryBlue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryBlue,
              tabs: const [
                Tab(icon: Icon(Icons.cloud_queue), text: "Cola de Envío"),
                Tab(icon: Icon(Icons.analytics_outlined), text: "Auditoría"),
              ],
            ),
            actions: [
              if (!_controller.isSyncing && _controller.pendingTorsos.isNotEmpty &&
                  _tabController.index == 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.cloud_upload_rounded, size: 28,
                        color: AppTheme.primaryBlue),
                    onPressed: () => _controller.handleSync(context),
                  ),
                ),
              if (_tabController.index == 1)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.error),
                  onPressed: _controller.clearAuditLogs,
                )
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            physics: _controller.isSelectionMode
                ? const NeverScrollableScrollPhysics()
                : const ScrollPhysics(),
            children: [
              // 🗣️ La UI le pregunta al controlador en qué estado estamos
              _controller.isSyncing
                  ? _buildSyncingState()
                  : (_controller.pendingTorsos.isEmpty
                  ? _buildEmptyState()
                  : _buildQueueList()),
              _buildAuditDashboard(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQueueList() {
    return ListView.builder(
      key: ValueKey(_controller.pendingTorsos.hashCode),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemCount: _controller.pendingTorsos.length,
      itemBuilder: (context, index) {
        final item = _controller.pendingTorsos[index];

        final String displayPath = item['torso_image_url'] ?? item['file_url'];
        final int photoId = item['photo_id'];
        DateTime date = DateTime.tryParse(item['created_at']) ?? DateTime.now();
        String hora = DateFormat('HH:mm').format(date);

        final bool isSelected = _controller.selectedIds.contains(photoId);

        return QueueItemCard(
          photoId: photoId,
          displayPath: displayPath,
          hora: hora,
          isSelected: isSelected,
          isSelectionMode: _controller.isSelectionMode,
          onLongPress: () => _controller.toggleSelection(photoId),
          onTap: () {
            if (_controller.isSelectionMode) {
              _controller.toggleSelection(photoId);
            } else {
              UIHelpers.showImagePreview(context, displayPath);
            }
          },
          onDelete: () async {
            final bool confirm = await UIHelpers.showDeleteConfirmDialog(context);
            if (confirm) await _controller.processDeletion(context, photoId);
          },
        );
      },
    );
  }

  Widget _buildAuditDashboard() {
    return Container(
      color: AppTheme.terminalBackground,
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "--- INFORMACIÓN DE LAS IMÁGENES ---",
            style: AppTheme.terminalTitleStyle,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _controller.logContent.isEmpty
                    ? "No hay registros disponibles."
                    : _controller.logContent,
                style: AppTheme.terminalStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
              color: AppTheme.primaryBlue, strokeWidth: 5),
          const SizedBox(height: 24),
          const Text("Sincronizando...",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text("No cierres la app por favor",
              style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: const Icon(
                Icons.cloud_done_outlined, size: 80, color: AppTheme.success),
          ),
          const SizedBox(height: 24),
          const Text("¡No tienes fotos para enviar!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}