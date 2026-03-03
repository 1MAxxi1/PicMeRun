// Propósito: Gestión de cámara con aislamiento total de archivos y optimización de peso.
// 1. Cola de Envío: Recibe la captura redimensionada y limpia (ahorro de datos).
// 2. Galería PicMeRun-Caras: Recibe la versión redimensionada con auditoría visual.
// 3. Importación: Permite inyectar fotos de la galería o múltiples archivos (Drive) para testing.

import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:picmerun/services/local_db_service.dart';
import 'package:picmerun/screens/queue_screen.dart';
import 'package:picmerun/screens/internal_gallery_screen.dart';
import 'package:picmerun/screens/log_view_screen.dart';
import 'package:picmerun/services/face_service.dart';
import 'package:picmerun/services/log_service.dart';
import 'package:picmerun/services/storage_service.dart';
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

  bool _isProcessing = false;
  bool _isChangingCamera = false;
  bool _isBursting = false;
  int _selectedCameraIndex = 0;

  double _currentZoomLevel = 1.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _baseZoomLevel = 1.0;

  // ✅ NUEVO: La resolución por defecto ahora es 1800
  double _selectedPixels = 1800.0;
  late FaceDetector _faceDetector;
  Offset? _focusPoint;

  @override
  void initState() {
    super.initState();
    _setupFaceDetector();
    _initCamera(_selectedCameraIndex);
    FaceService().loadModel();
    LogService.write("🚀 Sesión v10.8 - UI Inmersiva y Resoluciones Ultra.");
  }

  void _setupFaceDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
        enableClassification: true,
        minFaceSize: 0.20,
      ),
    );
  }

  void _initCamera(int cameraIndex) {
    _controller = CameraController(
      widget.cameras[cameraIndex],
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _initializeControllerFuture = _controller.initialize().then((_) async {
      try { await _controller.setFocusMode(FocusMode.auto); } catch (e) { debugPrint("Foco no disponible: $e"); }
      _minAvailableZoom = await _controller.getMinZoomLevel();
      _maxAvailableZoom = await _controller.getMaxZoomLevel();
      if (mounted) setState(() {});
    });
  }

  // --- MENÚ DE IMPORTACIÓN ---

  void _showImportMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Importar Imágenes", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
                title: const Text("Fotos de la Galería", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _importFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder, color: Colors.orangeAccent),
                title: const Text("Explorador / Drive", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _importMultiplePhotosForTesting();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importFromGallery() async {
    if (_isProcessing) return;
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isNotEmpty) {
        setState(() => _isProcessing = true);
        await LogService.write("📸 Importando ${images.length} fotos de la Galería...");

        int processedCount = 0;
        for (var image in images) {
          _startBackgroundProcessing(image);
          await Future.delayed(const Duration(milliseconds: 1500));
          processedCount++;
        }
        await LogService.write("✅ Importación de Galería finalizada: $processedCount fotos procesadas.");
      }
    } catch (e) {
      await LogService.write("🚨 Error importando de Galería: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _importMultiplePhotosForTesting() async {
    if (_isProcessing) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );

    if (result == null || result.files.isEmpty) return;

    setState(() => _isProcessing = true);
    await LogService.write("📂 Importando ${result.files.length} archivos (Drive/Carpetas)...");

    try {
      int processedCount = 0;
      for (var file in result.files) {
        if (file.path != null) {
          final XFile xFile = XFile(file.path!);
          _startBackgroundProcessing(xFile);
          await Future.delayed(const Duration(milliseconds: 1500));
          processedCount++;
        }
      }
      await LogService.write("✅ Importación masiva finalizada: $processedCount archivos procesados.");
    } catch (e) {
      await LogService.write("🚨 Error importando archivos: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- FLUJO CÁMARA Y PROCESAMIENTO ---

  Future<void> _handleTapToFocus(TapDownDetails details, BoxConstraints constraints) async {
    if (_isChangingCamera) return;
    final offset = Offset(details.localPosition.dx / constraints.maxWidth, details.localPosition.dy / constraints.maxHeight);
    setState(() => _focusPoint = details.localPosition);
    try { await _controller.setFocusPoint(offset); await _controller.setFocusMode(FocusMode.auto); } catch (e) { LogService.write("Error foco: $e"); }
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _focusPoint = null);
  }

  Future<void> _takeBurst() async {
    if (_isProcessing || _isChangingCamera || _isBursting) return;
    setState(() => _isBursting = true);
    await LogService.write("🔥 RÁFAGA: Iniciada.");
    for (int i = 0; i < 3; i++) {
      try {
        await _initializeControllerFuture;
        final XFile image = await _controller.takePicture();
        _startBackgroundProcessing(image);
        await Future.delayed(const Duration(milliseconds: 150));
      } catch (e) { LogService.write("❌ Error ráfaga [$i]: $e"); }
    }
    setState(() => _isBursting = false);
  }

  Future<void> _takePicture() async {
    if (_isProcessing || _isChangingCamera || _isBursting) return;
    try {
      await _initializeControllerFuture;
      final XFile image = await _controller.takePicture();
      _startBackgroundProcessing(image);
    } catch (e) { LogService.write("❌ Error captura: $e"); }
  }

  Future<void> _startBackgroundProcessing(XFile image) async {
    Future.microtask(() async {
      try {
        final File tempFile = File(image.path);
        final double sizeInMbOriginal = tempFile.lengthSync() / (1024 * 1024);
        final String weightLogOriginal = "${sizeInMbOriginal.toStringAsFixed(2)}MB";

        final storage = StorageService();
        final String originalsDir = await storage.getPath(false);
        final String facesDir = await storage.getPath(true);
        final String ts = DateTime.now().millisecondsSinceEpoch.toString();

        final String cleanPath = '$originalsDir/LIMPIA_$ts.jpg';
        final String auditPath = '$facesDir/MARCOS_$ts.jpg';

        final List<Face> allFaces = await _faceDetector.processImage(InputImage.fromFile(tempFile));

        final List<Face> validFaces = [];
        for (Face face in allFaces) {
          if (face.boundingBox.width < 75) {
            continue;
          }

          if (face.headEulerAngleY != null && face.headEulerAngleY!.abs() < 35.0) {
            validFaces.add(face);
          }
        }

        final resultAudit = await compute(_isolateAuditPipeline, {
          'rawPath': tempFile.path,
          'cleanSavePath': cleanPath,
          'auditSavePath': auditPath,
          'targetArea': _selectedPixels,
          'faces': validFaces.map((f) {
            return {
              'left': f.boundingBox.left,
              'top': f.boundingBox.top,
              'right': f.boundingBox.right,
              'bottom': f.boundingBox.bottom,
              'angleY': f.headEulerAngleY ?? 0.0,
              'faceWidth': f.boundingBox.width,
            };
          }).toList(),
        });

        if (resultAudit != null) {
          final int photoId = await LocalDBService.instance.insertPhoto({
            'hash_photo': resultAudit['cleanHash'],
            'event_id': 1,
            'photographer_id': 1,
            'file_url': auditPath,
            'taken_at': DateTime.now().toIso8601String(),
          });

          await LocalDBService.instance.insertTorsoQueue({
            'photo_id': photoId,
            'torso_image_url': cleanPath,
            'status': 'pending',
          });

          final String finalRes = resultAudit['final_resolution'];
          final String finalWeight = resultAudit['cleanSizeMb'] + "MB";

          String telemetryLog = validFaces.isEmpty
              ? "Sin datos"
              : validFaces.map((f) {
            return "[Ang: ${f.headEulerAngleY?.abs().toStringAsFixed(1)}° | ${f.boundingBox.width.toInt()}px]";
          }).join(", ");

          await LogService.write("Foto #$photoId | Caras: ${validFaces.length} | Detalles: $telemetryLog | Res: $finalRes | Peso: $finalWeight");
        }
      } catch (e) {
        await LogService.write("🚨 Error background: $e");
      }
    });
  }

  Future<void> _toggleCamera() async {
    if (widget.cameras.length < 2 || _isChangingCamera) return;
    setState(() => _isChangingCamera = true);
    try {
      await _controller.dispose();
      _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
      _initCamera(_selectedCameraIndex);
      await _initializeControllerFuture;
    } catch (e) { LogService.write("Error giro: $e"); }
    finally { if (mounted) setState(() => _isChangingCamera = false); }
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceDetector.close();
    super.dispose();
  }

  // ✅ NUEVO: Interfaz inmersiva a pantalla completa usando Stack
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fondo negro por si la cámara tarda en cargar
      // Eliminamos el AppBar tradicional
      body: Stack(
        fit: StackFit.expand, // Expande los elementos de la pila a toda la pantalla
        children: [

          // 1. CAPA DE FONDO: LA CÁMARA
          _isChangingCamera
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && _controller.value.isInitialized) {
                return LayoutBuilder(builder: (context, constraints) {
                  return GestureDetector(
                    onTapDown: (details) => _handleTapToFocus(details, constraints),
                    onScaleStart: (details) => _baseZoomLevel = _currentZoomLevel,
                    onScaleUpdate: (details) {
                      double zoom = _baseZoomLevel * details.scale;
                      if (zoom < _minAvailableZoom) zoom = _minAvailableZoom;
                      if (zoom > _maxAvailableZoom) zoom = _maxAvailableZoom;
                      if (zoom > 8.0) zoom = 8.0;
                      setState(() => _currentZoomLevel = zoom);
                      _controller.setZoomLevel(zoom);
                    },
                    child: Stack(
                      children: [
                        // Aseguramos que la vista previa ocupe todo el fondo
                        SizedBox.expand(child: CameraPreview(_controller)),
                        if (_focusPoint != null)
                          Positioned(
                            left: _focusPoint!.dx - 25,
                            top: _focusPoint!.dy - 25,
                            child: Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    ),
                  );
                });
              }
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            },
          ),

          // 2. CAPA SUPERIOR: BOTONES FLOTANTES DE ARRIBA (Reemplaza el AppBar)
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea( // Protege de los bordes del teléfono (notch)
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Botón Importar
                    Container(
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 28),
                        onPressed: _isProcessing ? null : _showImportMenu,
                      ),
                    ),

                    // Título Flotante
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(text: 'Pic', style: TextStyle(color: Colors.white)),
                            TextSpan(text: 'Me', style: TextStyle(color: Colors.red)),
                            TextSpan(text: 'Run', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),

                    // Botones Logs y Nube
                    Row(
                      children: [
                        Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: IconButton(
                            icon: const Icon(Icons.terminal, color: Colors.white),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LogViewScreen())),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: IconButton(
                            icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QueueScreen())),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),

          // 3. CAPA INFERIOR: BOTONES FLOTANTES DE ABAJO
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Selector de Resoluciones (Actualizado a 1800, 2100, 2400)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: SegmentedButton<double>(
                      style: SegmentedButton.styleFrom(
                        backgroundColor: Colors.black54, // Cristal ahumado
                        selectedBackgroundColor: Colors.red,
                        selectedForegroundColor: Colors.white,
                        foregroundColor: Colors.white,
                      ),
                      segments: const [
                        ButtonSegment(value: 1800.0, label: Text("1800px")),
                        ButtonSegment(value: 2100.0, label: Text("2100px")),
                        ButtonSegment(value: 2400.0, label: Text("2400px")),
                      ],
                      selected: {_selectedPixels},
                      onSelectionChanged: (newSelection) => setState(() => _selectedPixels = newSelection.first),
                    ),
                  ),

                  // Controles de Cámara
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20, top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: IconButton(
                              icon: const Icon(Icons.collections, color: Colors.white, size: 30),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const InternalGalleryScreen()))
                          ),
                        ),
                        GestureDetector(
                          onLongPress: _takeBurst,
                          child: FloatingActionButton(
                              onPressed: _takePicture,
                              backgroundColor: _isBursting ? Colors.orange : Colors.white,
                              elevation: 4,
                              child: _isProcessing || _isBursting
                                  ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3))
                                  : const Icon(Icons.camera_alt, color: Colors.black, size: 30)
                          ),
                        ),
                        Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: IconButton(
                              icon: const Icon(Icons.flip_camera_android, color: Colors.white, size: 30),
                              onPressed: _isProcessing || _isChangingCamera ? null : _toggleCamera
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<Map<String, dynamic>?> _isolateAuditPipeline(Map<String, dynamic> data) async {
  try {
    final File rawFile = File(data['rawPath']);
    final Uint8List bytes = await rawFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) return null;

    double origWidth = originalImage.width.toDouble();
    double origHeight = originalImage.height.toDouble();
    double longestSide = max(origWidth, origHeight); // Buscamos el lado más largo
    double targetPixels = data['targetArea'];
    double scale = 1.0;

    // Si la foto no mide exactamente lo que pediste, la obligamos (encogiendo o estirando)
    if (longestSide != targetPixels) {
      scale = targetPixels / longestSide;
      if (origWidth >= origHeight) {
        // Si es Horizontal, clavamos el Ancho a tu objetivo
        originalImage = img.copyResize(originalImage, width: targetPixels.toInt(), interpolation: img.Interpolation.linear);
      } else {
        // Si es Vertical, clavamos el Alto a tu objetivo
        originalImage = img.copyResize(originalImage, height: targetPixels.toInt(), interpolation: img.Interpolation.linear);
      }
    }

    final String finalResolution = "${originalImage.width}x${originalImage.height}";

    final String cleanSavePath = data['cleanSavePath'];
    final Uint8List cleanBytes = Uint8List.fromList(img.encodeJpg(originalImage, quality: 90));
    await File(cleanSavePath).writeAsBytes(cleanBytes);
    final String cleanHash = sha256.convert(cleanBytes).toString();

    final img.BitmapFont font = img.arial48;
    final List<dynamic> faces = data['faces'];

    for (var face in faces) {
      int left = (face['left'] * scale).toInt();
      int top = (face['top'] * scale).toInt();
      int right = (face['right'] * scale).toInt();
      int bottom = (face['bottom'] * scale).toInt();

      final double angleY = (face['angleY'] as double).abs();
      final double faceWidth = face['faceWidth'];

      String textSize = "${faceWidth.toInt()}px";
      String textAngle = "A: ${angleY.toStringAsFixed(1)}";

      img.drawRect(originalImage, x1: left, y1: top, x2: right, y2: bottom, color: img.ColorRgb8(0, 255, 0), thickness: 4);
      img.drawString(originalImage, textSize, font: font, x: left, y: top - 110, color: img.ColorRgb8(0, 255, 0));
      img.drawString(originalImage, textAngle, font: font, x: left, y: top - 55, color: img.ColorRgb8(255, 50, 50));
    }

    String info = "${(cleanBytes.length / (1024 * 1024)).toStringAsFixed(2)}MB | $finalResolution";
    img.drawString(originalImage, info, font: font, x: originalImage.width - 650, y: originalImage.height - 70, color: img.ColorRgb8(0, 255, 0));

    final String auditSavePath = data['auditSavePath'];
    final Uint8List auditBytes = Uint8List.fromList(img.encodeJpg(originalImage, quality: 90));
    await File(auditSavePath).writeAsBytes(auditBytes);
    final String auditHash = sha256.convert(auditBytes).toString();

    return {
      'cleanHash': cleanHash,
      'auditHash': auditHash,
      'final_resolution': finalResolution,
      'cleanSizeMb': (cleanBytes.length / (1024 * 1024)).toStringAsFixed(2),
    };
  } catch (e) { return null; }
}