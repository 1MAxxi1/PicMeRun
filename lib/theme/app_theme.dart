// Propósito: El manual de estilo. Guarda la paleta de colores, tamaños de
// fuentes y estilos de botones para que la app se vea idéntica en todas sus pantallas.

import 'package:flutter/material.dart';

class AppTheme {
  //  Colores Principales de la Marca
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color backgroundDark = Color(0xFF1E293B);

  //  Colores de Estado (Éxito, Error, Advertencia)
  static const Color success = Colors.green;
  static const Color error = Colors.redAccent;
  static const Color warning = Colors.orange;
  static const Color warningDark = Color(0xFFE65100); // Naranja oscuro para textos

  //  Colores de la Terminal (Auditoría)
  static const Color terminalBackground = Colors.black;
  static const Color terminalText = Colors.greenAccent;

  //  Estilos de Texto Reutilizables (Para no repetir código)
  static const TextStyle terminalStyle = TextStyle(
    color: terminalText,
    fontFamily: 'monospace',
    fontSize: 12,
    height: 1.5,
  );

  static const TextStyle terminalTitleStyle = TextStyle(
    color: terminalText,
    fontWeight: FontWeight.bold,
    fontFamily: 'monospace',
    fontSize: 14,
  );
}