// Propósito: La vista inmersiva de la cámara con sistema de importación masiva
// optimizado para estabilidad, Clean Code y feedback visual constante.
// 🚀 INCLUYE: Gestión de Ciclo de Vida (Ahorro de batería y prevención de pantalla negra).

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// Importamos nuestros widgets UI modulares
import 'package:picmerun/widgets/camera_top_bar.dart';
import 'package:picmerun/widgets/camera_bottom_controls.dart';
import 'package:picmerun/widgets/queue_progress_indicator.dart';

// Importamos los servicios
import 'package:picmerun/services/face_service.dart';
import 'package:picmerun/services/log_service.dart';
import 'package:picmerun/services/camera_processing_service.dart';
import 'package:picmerun/services/local_db_service.dart';
import 'package:picmerun/services/import_worker_service.dart';
import 'package:picmerun/providers/camera_provider.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});

  @override
  // 🚀 MAGIA SENIOR 1: Agregamos "WidgetsBindingObserver" para que esta pantalla
  // escuche los eventos del sistema operativo (minimizar, llamadas, etc.)
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  int _selectedCameraIndex = 0;

  double _currentZoomLevel = 1.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _baseZoomLevel = 1.0;

  Offset? _focusPoint;
  String _importProgress = "";

  @override
  void initState() {
    super.initState();
    // 🚀 MAGIA SENIOR 2: Nos suscribimos al "Radar" del teléfono al iniciar
    WidgetsBinding.instance.addObserver(this);

    _initCamera(_selectedCameraIndex);
    FaceService().loadModel();
    LogService.write("🚀 PicMeRun 2.3 - Lifecycle Edition.");
  }

  // 🚀 MAGIA SENIOR 3: El Detector de Eventos
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si el controlador aún no está listo, evitamos que la app explote
    try {
      if (!_controller.value.isInitialized) return;
    } catch (e) {
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // ⏸️ LA APP SE MINIMIZÓ: Apagamos el lente inmediatamente para ahorrar batería
      _controller.dispose();
      LogService.write("⏸️ App minimizada: Cámara apagada para ahorrar batería.");
    } else if (state == AppLifecycleState.resumed) {
      // ▶️ LA APP VOLVIÓ A PRIMER PLANO: Encendemos el lente de nuevo
      LogService.write("▶️ App en primer plano: Reiniciando cámara.");
      _initCamera(_selectedCameraIndex);
      // Forzamos un redibujado de la pantalla para que el visor vuelva a aparecer
      setState(() {});
    }
  }

  @override
  void dispose() {
    // 🚀 MAGIA SENIOR 4: Nos desuscribimos del Radar al cerrar la pantalla
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    CameraProcessingService.dispose();
    super.dispose();
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
    final provider = context.read<CameraProvider>();
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isNotEmpty) {
        List<String> paths = images.map((img) => img.path).toList();
        await LocalDBService.instance.enqueueImportTasks(paths);
        await LogService.write("Fotos encoladas para procesamiento: ${images.length}");
        await Future.delayed(const Duration(milliseconds: 500));

        ImportWorkerService.instance.startProcessing(provider.selectedPixels);

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("🚀 PicMeRun: Procesando ${images.length} fotos en la cola."))
        );
      }
    } catch (e) {
      await LogService.write("Error al encolar: $e");
    }
  }

  Future<void> _importMultiplePhotosForTesting() async {
    final provider = context.read<CameraProvider>();
    if (provider.isProcessing) return;

    provider.setProcessing(true);
    setState(() {
      _importProgress = "Descargando desde Drive...";
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );

      if (result == null || result.files.isEmpty) return;

      List<String> paths = result.files.where((file) => file.path != null).map((file) => file.path!).toList();

      if (paths.isNotEmpty) {
        setState(() => _importProgress = "Encolando ${paths.length} fotos...");
        await LocalDBService.instance.enqueueImportTasks(paths);
        await LogService.write("📂 Drive/Explorador: ${paths.length} fotos encoladas.");
        await Future.delayed(const Duration(milliseconds: 500));

        ImportWorkerService.instance.startProcessing(provider.selectedPixels);

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("🚀 Procesando ${paths.length} archivos en segundo plano..."))
        );
      }
    } catch (e) {
      await LogService.write("❌ Error en selector de archivos: $e");
    } finally {
      if (mounted) {
        context.read<CameraProvider>().setProcessing(false);
        setState(() {
          _importProgress = "";
        });
      }
    }
  }

  // --- FLUJO CÁMARA (LÓGICA) ---

  Future<void> _handleTapToFocus(TapDownDetails details, BoxConstraints constraints) async {
    if (context.read<CameraProvider>().isChangingCamera) return;
    final offset = Offset(details.localPosition.dx / constraints.maxWidth, details.localPosition.dy / constraints.maxHeight);
    setState(() => _focusPoint = details.localPosition);
    try { await _controller.setFocusPoint(offset); await _controller.setFocusMode(FocusMode.auto); } catch (e) { LogService.write("Error foco: $e"); }
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _focusPoint = null);
  }

  Future<void> _takeBurst() async {
    final provider = context.read<CameraProvider>();
    if (provider.isChangingCamera || provider.isBursting) return;

    provider.setBursting(true);
    await LogService.write("📸 RÁFAGA iniciada.");

    HapticFeedback.mediumImpact();

    List<String> burstPaths = [];
    for (int i = 0; i < 3; i++) {
      try {
        await _initializeControllerFuture;
        final XFile image = await _controller.takePicture();
        burstPaths.add(image.path);
        HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 150));
      } catch (e) { LogService.write("❌ Error ráfaga [$i]: $e"); }
    }

    if (burstPaths.isNotEmpty) {
      await LocalDBService.instance.enqueueImportTasks(burstPaths);
      ImportWorkerService.instance.startProcessing(provider.selectedPixels);
    }

    if (mounted) context.read<CameraProvider>().setBursting(false);
  }

  Future<void> _takePicture() async {
    final provider = context.read<CameraProvider>();
    if (provider.isChangingCamera || provider.isBursting) return;

    try {
      await _initializeControllerFuture;
      HapticFeedback.mediumImpact();
      final XFile image = await _controller.takePicture();

      await LocalDBService.instance.enqueueImportTasks([image.path]);
      ImportWorkerService.instance.startProcessing(provider.selectedPixels);
    } catch (e) { LogService.write("❌ Error captura: $e"); }
  }

  Future<void> _toggleCamera() async {
    final provider = context.read<CameraProvider>();
    if (widget.cameras.length < 2 || provider.isChangingCamera) return;

    provider.setChangingCamera(true);
    try {
      await _controller.dispose();
      _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
      _initCamera(_selectedCameraIndex);
      await _initializeControllerFuture;
    } catch (e) { LogService.write("Error giro: $e"); }
    finally {
      if (mounted) context.read<CameraProvider>().setChangingCamera(false);
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final cameraState = context.watch<CameraProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          cameraState.isChangingCamera
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
                            left: _focusPoint!.dx - 25, top: _focusPoint!.dy - 25,
                            child: Container(width: 50, height: 50, decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), shape: BoxShape.circle)),
                          ),
                      ],
                    ),
                  );
                });
              }
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            },
          ),

          CameraTopBar(
            isProcessing: cameraState.isProcessing,
            onImportPressed: _showImportMenu,
          ),

          const QueueProgressIndicator(),

          if (cameraState.isProcessing)
            Positioned(
              top: 160, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(color: Colors.blueGrey[900]?.withOpacity(0.8), borderRadius: BorderRadius.circular(30)),
                  child: Text("Drive: $_importProgress", style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
              ),
            ),

          CameraBottomControls(
            selectedPixels: cameraState.selectedPixels,
            isBursting: cameraState.isBursting,
            isChangingCamera: cameraState.isChangingCamera,
            onPixelsChanged: (newVal) => context.read<CameraProvider>().setPixels(newVal),
            onTakeBurst: _takeBurst,
            onTakePicture: _takePicture,
            onToggleCamera: _toggleCamera,
          ),
        ],
      ),
    );
  }
}