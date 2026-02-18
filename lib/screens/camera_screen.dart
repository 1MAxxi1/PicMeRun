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
import 'package:picmerun/services/log_service.dart';
import '../services/torso_service.dart';
import 'dart:math';

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

  double _currentZoomLevel = 1.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _baseZoomLevel = 1.0;

  double _selectedPixels = 1600.0;
  late FaceDetector _faceDetector;

  @override
  void initState() {
    super.initState();
    _setupFaceDetector();
    _initCamera(_selectedCameraIndex);
    FaceService().loadModel();
    LogService.write("Sesión de cámara iniciada");
  }

  void _setupFaceDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
        enableContours: true,
        enableClassification: true,
        minFaceSize: 0.05,
      ),
    );
  }

  void _initCamera(int cameraIndex) {
    _controller = CameraController(
      widget.cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    _initializeControllerFuture = _controller.initialize().then((_) async {
      await _controller.setFocusMode(FocusMode.auto);
      _minAvailableZoom = await _controller.getMinZoomLevel();
      _maxAvailableZoom = await _controller.getMaxZoomLevel();
      if (mounted) setState(() {});
    });
  }

  Future<void> _pickMassiveFromGallery() async {
    if (_isProcessing || _isChangingCamera) return;
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: AppConfig.imageQuality,
      );
      if (images.isNotEmpty) {
        await LogService.clear();
        await LogService.write("=== INICIO IMPORTACIÓN MASIVA | Objetivo: ${_selectedPixels.toInt()} px totales ===");
        setState(() => _isChangingCamera = true);
        _showSnackBar('📥 Procesando lote...', Colors.blue);
        for (var i = 0; i < images.length; i++) {
          await _startBackgroundProcessing(images[i]);
        }
        _showSnackBar('✅ Lote completado exitosamente', Colors.green);
      }
    } catch (e) {
      LogService.write("Error en Importación Masiva: $e");
    } finally {
      if (mounted) setState(() => _isChangingCamera = false);
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
      LogService.write("Error al girar cámara: $e");
    } finally {
      if (mounted) setState(() => _isChangingCamera = false);
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

      // ✅ MEJORA: No pausamos el preview indefinidamente para evitar que se "pegue"
      final XFile image = await _controller.takePicture();

      // Procesamos en segundo plano sin detener la UI
      _startBackgroundProcessing(image);
    } catch (e) {
      LogService.write("Error en captura: $e");
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _startBackgroundProcessing(XFile image) async {
    setState(() => _isProcessing = true);
    try {
      final String originalPath = image.path;
      final InputImage inputImage = InputImage.fromFile(File(originalPath));
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      int carasDetectadas = faces.length;

      final Directory appDir = (await getApplicationDocumentsDirectory());
      final String picMeRunPath = '${appDir.path}/PicMeRun';
      if (!Directory(picMeRunPath).existsSync()) {
        Directory(picMeRunPath).createSync(recursive: true);
      }

      final result = await compute(_isolateImagePipeline, {
        'imagePath': originalPath,
        'appDir': picMeRunPath,
        'targetArea': _selectedPixels,
        'faceRect': faces.isNotEmpty ? {
          'left': faces.first.boundingBox.left,
          'top': faces.first.boundingBox.top,
          'width': faces.first.boundingBox.width,
          'height': faces.first.boundingBox.height,
        } : null
      });

      if (result != null) {
        // ✅ MEJORA: Guardamos la ruta ORIGINAL para que en la cola se vea tal cual la tomaste
        final int photoId = await LocalDBService.instance.insertPhoto({
          'hash_photo': result['hash'],
          'event_id': 1,
          'photographer_id': 1,
          'file_url': originalPath, // 📸 Vista previa original
          'taken_at': DateTime.now().toIso8601String(),
        });

        String statusIcon = carasDetectadas > 0 ? "✅" : "❌";
        await LogService.write(
            "Foto #$photoId | Caras: $carasDetectadas $statusIcon | Res: ${result['resolution']} | Archivo: ${image.name}"
        );

        await LocalDBService.instance.insertTorsoQueue({
          'photo_id': photoId,
          'torso_image_url': result['path'], // Enviamos la versión pequeña
          'status': 'pending',
        });
      }
    } catch (e) {
      LogService.write("Fallo en procesamiento de ${image.name}: $e");
    } finally {
      // ✅ IMPORTANTE: Liberamos el estado para que el botón de disparo se reactive
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            children: [
              TextSpan(text: 'Pic', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'Me', style: TextStyle(color: Colors.red)),
              TextSpan(text: 'Run', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
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
                if (snapshot.connectionState == ConnectionState.done && _controller.value.isInitialized) {
                  return GestureDetector(
                    onScaleStart: (details) => _baseZoomLevel = _currentZoomLevel,
                    onScaleUpdate: (details) {
                      double zoom = _baseZoomLevel * details.scale;
                      if (zoom < _minAvailableZoom) zoom = _minAvailableZoom;
                      if (zoom > _maxAvailableZoom) zoom = _maxAvailableZoom;
                      if (zoom > 8.0) zoom = 8.0;
                      setState(() => _currentZoomLevel = zoom);
                      _controller.setZoomLevel(zoom);
                    },
                    child: CameraPreview(_controller),
                  );
                }
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SegmentedButton<double>(
              style: SegmentedButton.styleFrom(
                backgroundColor: Colors.grey[900],
                selectedBackgroundColor: Colors.red,
                selectedForegroundColor: Colors.white,
                foregroundColor: Colors.grey[400],
              ),
              segments: const [
                ButtonSegment(value: 1400.0, label: Text("1400px")),
                ButtonSegment(value: 1600.0, label: Text("1600px")),
                ButtonSegment(value: 1700.0, label: Text("1700px")),
              ],
              selected: {_selectedPixels},
              onSelectionChanged: (newSelection) {
                setState(() => _selectedPixels = newSelection.first);
                LogService.write("Objetivo: ${_selectedPixels.toInt()} px totales");
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.only(bottom: 30, top: 10),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                    icon: const Icon(Icons.photo_library, color: Colors.white, size: 30),
                    onPressed: _isProcessing || _isChangingCamera ? null : _pickMassiveFromGallery
                ),
                FloatingActionButton(
                    onPressed: _isProcessing || _isChangingCamera ? null : _takePicture,
                    backgroundColor: Colors.white,
                    child: _isProcessing
                        ? const SizedBox(
                        width: 25,
                        height: 25,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3)
                    )
                        : const Icon(Icons.camera_alt, color: Colors.black, size: 30)
                ),
                IconButton(
                    icon: const Icon(Icons.flip_camera_android, color: Colors.white, size: 30),
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
    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) return null;

    double targetArea = data['targetArea'] ?? 1600.0;
    double aspectRatio = originalImage.width / originalImage.height;
    int newWidth = sqrt(targetArea * aspectRatio).round();
    if (newWidth < 1) newWidth = 1;

    img.Image resizedImage = img.copyResize(originalImage, width: newWidth);

    int finalArea = resizedImage.width * resizedImage.height;
    final String resString = "${resizedImage.width}x${resizedImage.height} ($finalArea px)";

    final Uint8List finalBytes = Uint8List.fromList(img.encodeJpg(resizedImage));
    final String hash = sha256.convert(finalBytes).toString();
    final String path = '${data['appDir']}/IMG_PROCESSED_$hash.jpg';

    await File(path).writeAsBytes(finalBytes);

    return {'path': path, 'hash': hash, 'resolution': resString};
  } catch (e) { return null; }
}