// Propósito: La sala de espera. Muestra la lista visual de las fotos que
// están haciendo fila para irse a la nube de Cloudflare y la auditoría.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:picmerun/widgets/queue_item_card.dart';
import 'package:picmerun/theme/app_theme.dart';
import 'package:picmerun/utils/ui_helpers.dart';
import 'package:picmerun/controllers/queue_controller.dart';
import 'package:picmerun/screens/log_view_screen.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // INSTANCIAMOS EL CONTROLADOR (El Cerebro)
  final QueueController _controller = QueueController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Escuchamos si cambias de pestaña para actualizar la barra de arriba
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              // Solo mostramos el botón de Subir a la Nube si estamos en la pestaña 0 (Cola)
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
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            physics: _controller.isSelectionMode
                ? const NeverScrollableScrollPhysics()
                : const ScrollPhysics(),
            children: [
              _controller.isSyncing
                  ? _buildSyncingState()
                  : (_controller.pendingTorsos.isEmpty
                  ? _buildEmptyState()
                  : _buildQueueList()),

              // ✅ INCRUSTACIÓN: Llamamos al panel profesional
              const LogViewScreen(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQueueList() {
    return ListView.builder(
      // 🚀 MEJORA SENIOR: Eliminamos el ValueKey(hashCode) que destruía y
      // recreaba TODA la lista en cada tap. Ahora Flutter recicla suavemente.
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemCount: _controller.pendingTorsos.length,

      // 🚀 MAGIA ANTI-OOM: Le decimos a la lista que destruya de la RAM
      // inmediatamente cualquier tarjeta que ya no sea visible en la pantalla.
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,

      itemBuilder: (context, index) {
        final item = _controller.pendingTorsos[index];

        final String displayPath = item['torso_image_url'] ?? item['file_url'];
        final int photoId = item['photo_id'];

        String dateString = item['created_at'] ?? '';
        if (dateString.isNotEmpty && !dateString.contains('Z')) {
          dateString = dateString.replaceAll(' ', 'T') + 'Z';
        }

        DateTime date = DateTime.tryParse(dateString)?.toLocal() ?? DateTime.now();
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