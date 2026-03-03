import 'dart:io';
import 'package:flutter/material.dart';
import 'package:picmerun/theme/app_theme.dart'; // ✅ IMPORTAMOS TU TEMA GLOBAL

class QueueItemCard extends StatelessWidget {
  final int photoId;
  final String displayPath;
  final String hora;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  const QueueItemCard({
    super.key,
    required this.photoId,
    required this.displayPath,
    required this.hora,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onLongPress: onLongPress,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
            // ✅ USAMOS AppTheme.primaryBlue para el borde cuando está seleccionada
                ? Border.all(color: AppTheme.primaryBlue, width: 2)
                : Border.all(color: Colors.transparent, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: IntrinsicHeight(
              child: Row(
                children: [
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
                      if (isSelectionMode)
                        Positioned(
                          top: 5,
                          left: 5,
                          child: Container(
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                            child: Icon(
                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              // ✅ USAMOS AppTheme.primaryBlue para el check de selección
                              color: isSelected ? AppTheme.primaryBlue : Colors.grey,
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
                              // ✅ USAMOS AppTheme.warning para el icono del relojito
                              const Icon(Icons.access_time_filled, size: 14, color: AppTheme.warning),
                              const SizedBox(width: 4),
                              // ✅ USAMOS AppTheme.warningDark para el texto naranja
                              Text("Pendiente de envío", style: TextStyle(color: AppTheme.warningDark, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const Spacer(),
                          if (!isSelectionMode)
                            Align(
                              alignment: Alignment.bottomRight,
                              child: TextButton.icon(
                                onPressed: onDelete,
                                // ✅ USAMOS AppTheme.error para el basurero
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                                // ✅ USAMOS AppTheme.error para el texto "Eliminar"
                                label: const Text("Eliminar", style: TextStyle(color: AppTheme.error, fontSize: 12)),
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
  }
}