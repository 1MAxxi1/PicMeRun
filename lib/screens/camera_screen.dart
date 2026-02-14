import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';
import 'package:picmerun/services/local_db_service.dart';
import 'package:picmerun/screens/queue_screen.dart';
import 'package:picmerun/services/face_service.dart';
import 'package:picmerun/config/app_config.dart';
import '../services/torso_service.dart'; // Asegúrate de que la ruta sea correcta

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final ImagePicker _picker = ImagePicker();

  bool _isProcessing = false;
  bool _isChangingCamera = false;
  int _selectedCameraIndex = 0;

  late FaceDetector _faceDetector;

  @override
  void initState() {
    super.initState();
    _setupFaceDetector();
    _initCamera(_selectedCameraIndex);
    FaceService().loadModel();
  }

  void _setupFaceDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
        enableClassification: true,
        minFaceSize: AppConfig.minFaceSize,
      ),
    );
  }

  void _initCamera(int cameraIndex) {
    _controller = CameraController(
      widget.cameras[cameraIndex],
      AppConfig.useHighResPreview ? ResolutionPreset.high : ResolutionPreset.medium,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: AppConfig.imageQuality,
      );

      if (image != null) {
        _showSnackBar('🖼️ Procesando foto de la maratón...', Colors.blue);
        _startBackgroundProcessing(image);
      }
    } catch (e) {
      _showSnackBar('⚠️ Error al abrir galería', Colors.red);
    }
  }

  Future<void> _toggleCamera() async {
    if (widget.cameras.length < 2) return;
    setState(() => _isChangingCamera = true);
    await _controller.dispose();
    _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    _initCamera(_selectedCameraIndex);
    try {
      await _initializeControllerFuture;
    } catch (e) {
      debugPrint("Error al girar cámara: $e");
    }
    if (mounted) setState(() => _isChangingCamera = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_isProcessing || _isChangingCamera) return;
    try {
      await _initializeControllerFuture;
      final XFile image = await _controller.takePicture();
      _startBackgroundProcessing(image);
    } catch (e) {
      _showSnackBar('⚠️ Error al capturar', Colors.red);
    }
  }

  Future<void> _startBackgroundProcessing(XFile image) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final File file = File(image.path);
      final InputImage inputImage = InputImage.fromFile(file);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      // Filtro de calidad frontal
      final validFaces = faces.where((face) {
        final bool isFrontal = (face.headEulerAngleY ?? 0).abs() < 35;
        return isFrontal;
      }).toList();

      if (validFaces.isEmpty) {
        _showSnackBar('ℹ️ Sin rostro claro', Colors.orange);
        setState(() => _isProcessing = false);
        return;
      }

      // 1. Procesar Torso (Llamada Estática Corregida)
      final String? torsoPath = await TorsoService.processTorso(image.path);

      final Directory appDir = (await getExternalStorageDirectory())!;
      final String picMeRunPath = '${appDir.path}/PicMeRun';
      if (!Directory(picMeRunPath).existsSync()) Directory(picMeRunPath).createSync(recursive: true);

      // 2. Pipeline de imagen (Hash SHA-256 para evitar duplicados en Cloudflare)
      final result = await compute(_isolateImagePipeline, {
        'imagePath': image.path,
        'appDir': picMeRunPath,
      });

      if (result != null) {
        // 3. Inserción en tabla Photos (Arquitectura 7 tablas)
        final int photoId = await LocalDBService.instance.insertPhoto({
          'hash_photo': result['hash'],
          'event_id': 1, // Evento de prueba
          'photographer_id': 1, // Fotógrafo de prueba
          'file_url': result['path'],
          'taken_at': DateTime.now().toIso8601String(),
        });

        // 4. Guardar en la cola de procesamiento si el torso fue exitoso
        if (torsoPath != null) {
          await LocalDBService.instance.insertTorsoQueue({
            'photo_id': photoId,
            'torso_image_url': torsoPath,
            'status': 'pending',
          });
        }
      }
      _showSnackBar('✅ Captura procesada correctamente', Colors.green);

    } catch (e) {
      _showSnackBar('⚠️ Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("PicMeRun"),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QueueScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller);
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(icon: const Icon(Icons.photo_library, color: Colors.white), onPressed: _pickFromGallery),
                FloatingActionButton(onPressed: _takePicture, backgroundColor: Colors.white, child: const Icon(Icons.camera_alt, color: Colors.black)),
                IconButton(icon: const Icon(Icons.flip_camera_android, color: Colors.white), onPressed: _toggleCamera),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<Map<String, dynamic>?> _isolateImagePipeline(Map<String, dynamic> data) async {
  try {
    final File file = File(data['imagePath']);
    final Uint8List bytes = await file.readAsBytes();

    // Generar Hash real para la tabla photos
    final String hash = sha256.convert(bytes).toString();
    final String path = '${data['appDir']}/IMG_$hash.jpg';

    await File(path).writeAsBytes(bytes);

    return {'path': path, 'hash': hash};
  } catch (e) {
    return null;
  }
}