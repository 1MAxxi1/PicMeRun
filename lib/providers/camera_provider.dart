import 'package:flutter/material.dart';

class CameraProvider extends ChangeNotifier {
  // 🧠 1. LAS VARIABLES PRIVADAS (El estado real)
  double _selectedPixels = 1800.0;
  bool _isBursting = false;
  bool _isChangingCamera = false;
  bool _isProcessing = false;

  // 👁️ 2. LOS GETTERS (Para que la UI pueda leer los valores)
  double get selectedPixels => _selectedPixels;
  bool get isBursting => _isBursting;
  bool get isChangingCamera => _isChangingCamera;
  bool get isProcessing => _isProcessing;

  // 🕹️ 3. LOS MÉTODOS (Para cambiar los valores y avisarle a la pantalla)

  void setPixels(double pixels) {
    _selectedPixels = pixels;
    notifyListeners(); // 🚀 ¡Esta es la magia! Le avisa a Flutter que redibuje SOLO lo necesario.
  }

  void setBursting(bool value) {
    _isBursting = value;
    notifyListeners();
  }

  void setChangingCamera(bool value) {
    _isChangingCamera = value;
    notifyListeners();
  }

  void setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }
}