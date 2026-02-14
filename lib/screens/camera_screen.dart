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
import '../services/torso_service.dart';

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
  bool _isChangingCamera = false; // ✅ Control maestro de UI
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
      ResolutionPreset.medium, // ✅ Ideal para el buffer del Moto E14
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  // ✅ Mejora: Eliminamos el error CameraException al importar de galería
  Future<void> _pickFromGallery() async {
    if (_isProcessing || _isChangingCamera) return;

    try {
      setState(() => _isChangingCamera = true); // ✅ Ocultamos preview para evitar error visual

      if (_controller.value.isInitialized) {
        await _controller.dispose();
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: AppConfig.imageQuality,
      );

      if (image != null) {
        _showSnackBar('🖼️ Procesando foto...', Colors.blue);
        await _startBackgroundProcessing(image);
      }
    } catch (e) {
      _showSnackBar('⚠️ Error al abrir galería', Colors.red);
      debugPrint("Error Galería: $e");
    } finally {
      // ✅ Reiniciamos la cámara suavemente al volver
      _initCamera(_selectedCameraIndex);
      await _initializeControllerFuture;
      if (mounted) {
        setState(() => _isChangingCamera = false);
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (widget.cameras.length < 2 || _isChangingCamera) return;

    setState(() => _isChangingCamera = true);

    try {
      await _controller.dispose();
      _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
      _initCamera(_selectedCameraIndex);
      await _initializeControllerFuture;
    } catch (e) {
      debugPrint("Error al girar cámara: $e");
    } finally {
      if (mounted) {
        setState(() => _isChangingCamera = false);
      }
    }
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
      await _controller.pausePreview(); // ✅ Evita el error BLASTBufferQueue

      final XFile image = await _controller.takePicture();
      await _startBackgroundProcessing(image);

    } catch (e) {
      _showSnackBar('⚠️ Error: $e', Colors.red);
    } finally {
      if (mounted) {
        await _controller.resumePreview();
      }
    }
  }

  Future<void> _startBackgroundProcessing(XFile image) async {
    setState(() => _isProcessing = true);

    try {
      final String currentPath = image.path;
      final File file = File(currentPath);
      final InputImage inputImage = InputImage.fromFile(file);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      final validFaces = faces.where((face) {
        return (face.headEulerAngleY ?? 0).abs() < 35;
      }).toList();

      if (validFaces.isEmpty) {
        _showSnackBar('ℹ️ Sin rostro claro', Colors.orange);
        setState(() => _isProcessing = false);
        return;
      }

      // 1. Procesamiento de Torso (Lógica de Gregorio)
      final String? torsoPath = await TorsoService.processTorso(currentPath);

      final Directory appDir = (await getExternalStorageDirectory())!;
      final String picMeRunPath = '${appDir.path}/PicMeRun';
      if (!Directory(picMeRunPath).existsSync()) {
        Directory(picMeRunPath).createSync(recursive: true);
      }

      // 2. Hash SHA-256 para evitar duplicados
      final result = await compute(_isolateImagePipeline, {
        'imagePath': currentPath,
        'appDir': picMeRunPath,
      });

      if (result != null) {
        // 3. Inserción con IDs de Seed (v5)
        final int photoId = await LocalDBService.instance.insertPhoto({
          'hash_photo': result['hash'],
          'event_id': 1,
          'photographer_id': 1,
          'file_url': result['path'],
          'taken_at': DateTime.now().toIso8601String(),
        });

        // 4. Registro en cola de envío
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
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            children: [
              TextSpan(text: 'Pic', style: TextStyle(color: Colors.black)),
              TextSpan(text: 'Me', style: TextStyle(color: Colors.red)),
              TextSpan(text: 'Run', style: TextStyle(color: Colors.black)),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined, color: Colors.black),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QueueScreen())
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isChangingCamera
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && _controller.value.isInitialized) {
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
                IconButton(
                    icon: const Icon(Icons.photo_library, color: Colors.white),
                    onPressed: _isProcessing || _isChangingCamera ? null : _pickFromGallery
                ),
                FloatingActionButton(
                    onPressed: _isProcessing || _isChangingCamera ? null : _takePicture,
                    backgroundColor: Colors.white,
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Icon(Icons.camera_alt, color: Colors.black)
                ),
                IconButton(
                    icon: const Icon(Icons.flip_camera_android, color: Colors.white),
                    onPressed: _isProcessing || _isChangingCamera ? null : _toggleCamera
                ),
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
    final String hash = sha256.convert(bytes).toString();
    final String path = '${data['appDir']}/IMG_$hash.jpg';
    await File(path).writeAsBytes(bytes);
    return {'path': path, 'hash': hash};
  } catch (e) {
    return null;
  }
}