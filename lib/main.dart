import 'package:picmerun/services/face_service.dart';
import 'package:picmerun/services/storage_service.dart'; // ✅ Importamos el nuevo servicio
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:picmerun/screens/camera_screen.dart';

Future<void> main() async {
  // Asegura que los bindings de Flutter estén listos
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 1. Inicializamos las carpetas de las galerías en el almacenamiento
  final storage = StorageService();
  await storage.initStorage();

  // ✅ 2. Cargamos el modelo de IA para detección de rostros
  await FaceService().loadModel();

  // ✅ 3. Detectamos las cámaras disponibles en el moto g35
  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("⚠️ No se detectaron cámaras: $e");
  }

  runApp(PicMeRunApp(cameras: cameras));
}

class PicMeRunApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const PicMeRunApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PicMeRun',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          surface: const Color(0xFFF8FAFC),
        ),
        useMaterial3: true,

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),

        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 2.0,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16.0)),
          ),
        ),
      ),
      home: CameraScreen(cameras: cameras),
    );
  }
}