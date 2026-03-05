// Propósito: La vista inmersiva de la cámara con sistema de importación masiva
// optimizado para estabilidad y feedback visual constante.

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:picmerun/screens/queue_screen.dart';
import 'package:picmerun/screens/internal_gallery_screen.dart';
import 'package:picmerun/screens/log_view_screen.dart';
import 'package:picmerun/services/face_service.dart';
import 'package:picmerun/services/log_service.dart';
import 'package:picmerun/services/camera_processing_service.dart';
import 'package:picmerun/services/local_db_service.dart';
import 'package:picmerun/services/import_worker_service.dart';
import 'package:sqflite/sqflite.dart';

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

  double _selectedPixels = 1800.0;
  Offset? _focusPoint;

  String _importProgress = "";

  @override
  void initState() {
    super.initState();
    _initCamera(_selectedCameraIndex);
    FaceService().loadModel();
    LogService.write("🚀 PicMeRun 2.1.");
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
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isNotEmpty) {
        List<String> paths = images.map((img) => img.path).toList();

        // 1. Mandamos a guardar a la base de datos
        await LocalDBService.instance.enqueueImportTasks(paths);
        await LogService.write("Fotos encoladas para procesamiento: ${images.length}");

        // 2. Le damos tiempo a SQLite para asentar los datos
        await Future.delayed(const Duration(milliseconds: 500));

        // 3. Despertamos al Worker
        ImportWorkerService.instance.startProcessing(_selectedPixels);

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("🚀 PicMeRun: Procesando ${images.length} fotos en la cola."))
        );
      }
    } catch (e) {
      await LogService.write("Error al encolar: $e");
    }
  }

  Future<void> _importMultiplePhotosForTesting() async {
    if (_isProcessing) return;

    // 🚀 1. ENCENDEMOS EL LETRERO: Avisamos que Drive está trabajando
    setState(() {
      _isProcessing = true;
      _importProgress = "Descargando desde Drive...";
    });

    try {
      // Selección y descarga de archivos (Aquí es donde el Moto G35 se toma su tiempo)
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );

      if (result == null || result.files.isEmpty) return;

      // 2. PASAMOS TODO A LA COLA
      List<String> paths = result.files
          .where((file) => file.path != null)
          .map((file) => file.path!)
          .toList();

      if (paths.isNotEmpty) {
        // Cambiamos el mensaje rápido
        setState(() => _importProgress = "Encolando ${paths.length} fotos...");

        await LocalDBService.instance.enqueueImportTasks(paths);
        await LogService.write("📂 Drive/Explorador: ${paths.length} fotos encoladas.");

        await Future.delayed(const Duration(milliseconds: 500));

        ImportWorkerService.instance.startProcessing(_selectedPixels);

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("🚀 Procesando ${paths.length} archivos en segundo plano..."))
        );
      }
    } catch (e) {
      await LogService.write("❌ Error en selector de archivos: $e");
    } finally {
      // 🚀 3. APAGAMOS EL LETRERO: La descarga terminó, ahora el StreamBuilder toma el control
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _importProgress = "";
        });
      }
    }
  }

  // --- FLUJO CÁMARA ---

  Future<void> _handleTapToFocus(TapDownDetails details, BoxConstraints constraints) async {
    if (_isChangingCamera) return;
    final offset = Offset(details.localPosition.dx / constraints.maxWidth, details.localPosition.dy / constraints.maxHeight);
    setState(() => _focusPoint = details.localPosition);
    try { await _controller.setFocusPoint(offset); await _controller.setFocusMode(FocusMode.auto); } catch (e) { LogService.write("Error foco: $e"); }
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _focusPoint = null);
  }

  Future<void> _takeBurst() async {
    // 🚀 Quitamos _isProcessing para que pueda disparar siempre
    if (_isChangingCamera || _isBursting) return;
    setState(() => _isBursting = true);
    await LogService.write("📸 RÁFAGA iniciada.");

    List<String> burstPaths = [];
    for (int i = 0; i < 3; i++) {
      try {
        await _initializeControllerFuture;
        final XFile image = await _controller.takePicture();
        burstPaths.add(image.path); // Anotamos en la libreta en orden
        await Future.delayed(const Duration(milliseconds: 150));
      } catch (e) { LogService.write("❌ Error ráfaga [$i]: $e"); }
    }

    // 🚀 Mandamos las 3 fotos juntas a la cola del Obrero
    if (burstPaths.isNotEmpty) {
      await LocalDBService.instance.enqueueImportTasks(burstPaths);
      ImportWorkerService.instance.startProcessing(_selectedPixels);
    }

    setState(() => _isBursting = false);
  }

  Future<void> _takePicture() async {
    // 🚀 Quitamos _isProcessing para que la cámara nunca se bloquee
    if (_isChangingCamera || _isBursting) return;
    try {
      await _initializeControllerFuture;
      final XFile image = await _controller.takePicture();

      // 🚀 Mandamos la foto directo a la cola
      await LocalDBService.instance.enqueueImportTasks([image.path]);
      ImportWorkerService.instance.startProcessing(_selectedPixels);

    } catch (e) { LogService.write("❌ Error captura: $e"); }
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
    CameraProcessingService.dispose();
    super.dispose();
  }

  // MÉTODO AUXILIAR PARA EL STREAM DE LA COLA
  // MÉTODO AUXILIAR PARA EL STREAM DE LA COLA
  Stream<Map<String, int>> _getQueueStream() async* {
    while (true) {
      final db = await LocalDBService.instance.database;

      final total = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM import_processing_queue')) ?? 0;

      // 🚀 CAMBIO SENIOR: Sumamos los 'completed' y los 'failed'.
      // Si una foto falla, la contamos como "procesada" para que la cola avance y no se trabe.
      final processed = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM import_processing_queue WHERE status = 'completed' OR status = 'failed'")) ?? 0;

      yield {'total': total, 'processed': processed};

      // 🧹 AUTO-LIMPIEZA MÁGICA: Si ya terminó todo el lote, vaciamos la tabla de la DB.
      // Así evitamos que se acumulen "fantasmas" para la próxima importación.
      if (total > 0 && total == processed) {
        await LocalDBService.instance.clearQueue();
      }

      await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // VISTA PREVIA CÁMARA
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

          // INTERFAZ SUPERIOR
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 28),
                        onPressed: _isProcessing ? null : _showImportMenu,
                      ),
                    ),
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

          // ✅ NUEVO INDICADOR DE PROGRESO CON STREAMBUILDER
          // ✅ NUEVO INDICADOR DE PROGRESO CON STREAMBUILDER
          StreamBuilder<Map<String, int>>(
              stream: _getQueueStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();

                final total = snapshot.data!['total'] ?? 0;
                final processed = snapshot.data!['processed'] ?? 0; // Usamos processed

                // Si no hay nada en cola, o ya terminó todo, no mostramos nada
                if (total == 0 || total == processed) return const SizedBox.shrink();

                return Positioned(
                  top: 100, left: 0, right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.redAccent, width: 2),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2)),
                          const SizedBox(width: 15),
                          Text(
                            "Cola: $processed / $total fotos",
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
          ),

          // INDICADOR DE PROGRESO TRADICIONAL
          if (_isProcessing)
            Positioned(
              top: 160, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[900]?.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    "Drive: $_importProgress",
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),

          // 3. CONTROLES INFERIORES
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: SegmentedButton<double>(
                      style: SegmentedButton.styleFrom(
                        backgroundColor: Colors.black54,
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