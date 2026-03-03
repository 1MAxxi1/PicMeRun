// Propósito: La vista inmersiva de la cámara. Su único trabajo es dibujar los
// botones, mostrar lo que ve el lente de hardware y avisarle a los servicios cuando el
// usuario presiona el disparador.

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
import 'package:picmerun/services/camera_processing_service.dart'; // <-- El Nuevo Cerebro

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
  Offset? _focusPoint;

  @override
  void initState() {
    super.initState();
    _initCamera(_selectedCameraIndex);
    FaceService().loadModel();
    LogService.write("🚀 Sesión v10.9 - Arquitectura Limpia (MVC) Activa.");
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

  // 🧠 ESTE ES EL GRAN CAMBIO: Derivamos todo el trabajo pesado al nuevo servicio
  Future<void> _startBackgroundProcessing(XFile image) async {
    await CameraProcessingService.processPhoto(image, _selectedPixels);
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
    CameraProcessingService.dispose(); // <-- Usamos el servicio para cerrar la IA
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