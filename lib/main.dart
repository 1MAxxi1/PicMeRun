import 'package:picmerun/services/face_service.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:picmerun/screens/camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FaceService().loadModel();

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

        // ✅ CORRECCIÓN: Usamos CardThemeData en lugar de CardTheme
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