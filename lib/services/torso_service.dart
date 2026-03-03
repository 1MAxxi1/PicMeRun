// Propósito: Especialista en recortes corporales. Lógica dedicada a
// extraer y procesar exclusivamente el torso de los corredores.

import 'dart:io';

class TorsoService {
  //  COMENTAMOS LA IA DE POSES PARA EVITAR ENREDOS
  // static final PoseDetector _poseDetector = ...

  static Future<String?> processTorso(String imagePath) async {
    //  Por ahora, devolvemos la misma ruta de la imagen original.
    // Esto cumple con el requisito de Gregorio de priorizar la cara
    // y evita que se generen archivos '_torso.jpg' con recortes de pechos.
    return imagePath;
  }
}