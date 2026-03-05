// Propósito: El "Cerebro" de la cola de envíos. Decide qué fotos están
// pendientes, maneja la selección múltiple y le ordena al servicio de red cuándo
// empezar a subir archivos.

import 'package:flutter/material.dart';
import 'package:picmerun/services/local_db_service.dart';
import 'package:picmerun/services/sync_service.dart';
import 'package:picmerun/services/log_service.dart';
import 'package:picmerun/theme/app_theme.dart';
import 'package:picmerun/utils/ui_helpers.dart';

class QueueController extends ChangeNotifier {
  // 1. EL ESTADO (Las variables que antes estaban en la pantalla)
  List<Map<String, dynamic>> pendingTorsos = [];
  bool isSyncing = false;
  String logContent = "Cargando logs de auditoría...";
  final Set<int> selectedIds = {};

  bool get isSelectionMode => selectedIds.isNotEmpty;

  // 2. INICIALIZACIÓN (Lo que se ejecuta al abrir la pantalla)
  QueueController() {
    loadQueue();
    loadAuditLogs();
  }

  // 3. LA LÓGICA DE NEGOCIO Y BASE DE DATOS
  Future<void> loadQueue() async {
    final data = await LocalDBService.instance.getPendingTorsos();
    pendingTorsos = List<Map<String, dynamic>>.from(data);
    selectedIds.removeWhere((id) => !pendingTorsos.any((t) => t['photo_id'] == id));

    notifyListeners(); // Le avisa a la pantalla que debe redibujarse
  }

  Future<void> loadAuditLogs() async {
    try {
      logContent = await LogService.getLogs();
    } catch (e) {
      logContent = "No hay registros de auditoría disponibles.";
    }
    notifyListeners();
  }

  Future<void> clearAuditLogs() async {
    await LogService.clear();
    await loadAuditLogs();
  }

  Future<void> handleSync(BuildContext context) async {
    if (pendingTorsos.isEmpty) return;

    isSyncing = true;
    notifyListeners();

    try {
      await SyncService().uploadPendingTorsos();
      await loadQueue();
      if (context.mounted) UIHelpers.showSnackBar(context, "Sincronización finalizada", AppTheme.success);
    } catch (e) {
      if (context.mounted) UIHelpers.showSnackBar(context, "Error sincronizando: $e", AppTheme.error);
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  // LA LÓGICA DE SELECCIÓN (Multi-Select)
  void toggleSelection(int photoId) {
    if (selectedIds.contains(photoId)) {
      selectedIds.remove(photoId);
    } else {
      selectedIds.add(photoId);
    }
    notifyListeners();
  }

  void toggleSelectAll() {
    if (selectedIds.length == pendingTorsos.length) {
      selectedIds.clear();
    } else {
      selectedIds.addAll(pendingTorsos.map((t) => t['photo_id'] as int));
    }
    notifyListeners();
  }

  void clearSelection() {
    selectedIds.clear();
    notifyListeners();
  }

  // 5. LA LÓGICA DE ELIMINACIÓN
  Future<void> deleteSelected(BuildContext context) async {
    final bool confirm = await UIHelpers.showDeleteConfirmDialog(context, isBulk: true, count: selectedIds.length);
    if (!confirm) return;

    final int count = selectedIds.length;

    try {
      for (int id in selectedIds) {
        await LocalDBService.instance.deletePhoto(id);
      }

      pendingTorsos.removeWhere((t) => selectedIds.contains(t['photo_id']));
      selectedIds.clear();
      notifyListeners();

      if (context.mounted) UIHelpers.showSnackBar(context, " $count foto(s) eliminada(s) correctamente", AppTheme.error);
    } catch (e) {
      if (context.mounted) UIHelpers.showSnackBar(context, " Error al eliminar fotos en bloque: $e", AppTheme.error);
    }
  }

  Future<void> processDeletion(BuildContext context, int photoId) async {
    try {
      await LocalDBService.instance.deletePhoto(photoId);
      pendingTorsos.removeWhere((t) => t['photo_id'] == photoId);
      notifyListeners();

      if (context.mounted) UIHelpers.showSnackBar(context, " Eliminado correctamente", AppTheme.error);
    } catch (e) {
      if (context.mounted) UIHelpers.showSnackBar(context, " Error al eliminar: $e", AppTheme.error);
    }
  }
}