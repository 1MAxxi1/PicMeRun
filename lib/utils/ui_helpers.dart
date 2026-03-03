// Propósito: El constructor de pop-ups. Guarda los diseños de alertas, cuadros de
// diálogo (ej. "¿Estás seguro de eliminar?") y mensajes flotantes (Snackbars) para reutilizarlos.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:picmerun/theme/app_theme.dart';

class UIHelpers {

  //  1. Snackbar Global (Para usar en toda la app)
  static void showSnackBar(BuildContext context, String message, Color color) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  //  2. Visor de Imágenes en Pantalla Completa
  static void showImagePreview(BuildContext context, String imagePath) {
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

  //  3. Confirmación de Borrado Inteligente
  static Future<bool> showDeleteConfirmDialog(BuildContext context, {bool isBulk = false, int count = 0}) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isBulk ? "¿Eliminar $count fotos?" : "¿Quieres eliminar la foto?"),
        content: const Text("Esta acción borrará las fotos originales permanentemente de tu celular."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))
          ),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("BORRAR", style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    ) ?? false;
  }
}