// Propósito: La vitrina de fotos. Una interfaz "tonta" que solo dibuja la cuadrícula
// de imágenes preguntándole a su controlador qué fotos existen, ahora con vista deslizable,
// optimización extrema de memoria RAM y 🚀 Selección Múltiple Avanzada.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🚀 Para la vibración al seleccionar
import 'package:picmerun/controllers/gallery_controller.dart';

class InternalGalleryScreen extends StatefulWidget {
  const InternalGalleryScreen({super.key});

  @override
  State<InternalGalleryScreen> createState() => _InternalGalleryScreenState();
}

class _InternalGalleryScreenState extends State<InternalGalleryScreen> {
  final GalleryController _controller = GalleryController();

  // 🚀 NUEVA MEJORA SENIOR: Memoria de fotos seleccionadas
  final Set<File> _selectedFiles = {};

  // Saber si estamos en modo "Selección" o modo normal
  bool get _isSelectionMode => _selectedFiles.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.loadGalleries();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- MÉTODOS DE SELECCIÓN ---

  void _toggleSelection(File file) {
    setState(() {
      if (_selectedFiles.contains(file)) {
        _selectedFiles.remove(file);
      } else {
        _selectedFiles.add(file);
      }
    });
    HapticFeedback.lightImpact(); // Micro-UX: Pequeña vibración al tocar
  }

  void _clearSelection() {
    setState(() {
      _selectedFiles.clear();
    });
  }

  // 🚀 EJECUCIÓN DEL BORRADO MÚLTIPLE
  Future<void> _confirmDeleteSelected() async {
    final int count = _selectedFiles.length;
    final bool? delete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("¿Eliminar $count fotos?", style: const TextStyle(color: Colors.red)),
        content: const Text("Se borrarán las fotos originales y sus versiones procesadas. Esta acción no se puede deshacer."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar", style: TextStyle(color: Colors.grey))
          ),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Eliminar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (delete == true) {
      // Le pasamos el lote al Cerebro
      final success = await _controller.deleteMultiplePhotos(_selectedFiles);

      if (mounted) {
        _clearSelection(); // Salimos del modo selección
        ScaffoldMessenger.of(context).clearSnackBars();

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("🚀 $count fotos eliminadas con éxito."),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("❌ Error al eliminar las fotos."),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              )
          );
        }
      }
    }
  }

  // BOTÓN NUCLEAR (Intacto)
  Future<void> _confirmDeleteAll() async {
    final bool? delete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar TODAS las fotos?", style: TextStyle(color: Colors.red)),
        content: const Text("Se borrarán absolutamente todas las fotos (Originales y Caras) del almacenamiento del teléfono y de la base de datos. Esta acción no se puede deshacer."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar", style: TextStyle(color: Colors.grey))
          ),
          TextButton(
              style: TextButton.styleFrom(backgroundColor: Colors.red[50]),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("¡Sí, eliminar TODO!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (delete == true) {
      final success = await _controller.deleteAllPhotos();

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🚀 Papelera vaciada. Teléfono limpio."),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              // 🚀 APPBAR CONTEXTUAL: Cambia si estamos seleccionando
              backgroundColor: _isSelectionMode ? Colors.blueGrey[900] : Colors.white,
              foregroundColor: _isSelectionMode ? Colors.white : Colors.black87,

              leading: _isSelectionMode
                  ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection, // Botón para cancelar selección
              )
                  : null, // Si no hay selección, muestra el botón de "Atrás" normal

              title: Text(
                _isSelectionMode ? "${_selectedFiles.length} seleccionadas" : "Galerías PicMeRun",
                style: TextStyle(color: _isSelectionMode ? Colors.white : Colors.black87),
              ),

              actions: [
                if (_isSelectionMode)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: _confirmDeleteSelected,
                  )
                else if (_controller.originalFiles.isNotEmpty || _controller.faceFiles.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 28),
                    tooltip: 'Eliminar todas las fotos',
                    onPressed: _confirmDeleteAll,
                  ),
              ],
              bottom: TabBar(
                indicatorColor: _isSelectionMode ? Colors.white : Colors.red,
                labelColor: _isSelectionMode ? Colors.white : Colors.red,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(icon: Icon(Icons.photo_outlined), text: "Originales"),
                  Tab(icon: Icon(Icons.face_retouching_natural), text: "Caras"),
                ],
              ),
            ),
            body: _controller.isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.red))
                : TabBarView(
              children: [
                _buildGrid(_controller.originalFiles),
                _buildGrid(_controller.faceFiles),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<File> files) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text("Aún no hay fotos aquí.", style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("¡Ve a capturar algunos corredores!", style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final isSelected = _selectedFiles.contains(file);

        return GestureDetector(
          // 🚀 MAGIA UX: Mantener presionado activa la selección
          onLongPress: () => _toggleSelection(file),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(file); // Si ya estamos seleccionando, un toque normal marca/desmarca
            } else {
              _showFullScreen(files, index); // Si no, abre la foto grande
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: file.path,
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  cacheWidth: 400, // 🛡️ Protección OOM intacta
                ),
              ),
              // 🚀 CAPA VISUAL: Si está seleccionada, la oscurecemos y ponemos el Check
              if (isSelected)
                Container(
                  color: Colors.black54, // Oscurece la foto
                  child: const Center(
                    child: Icon(Icons.check_circle, color: Colors.blueAccent, size: 40),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showFullScreen(List<File> files, int initialIndex) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => FullScreenViewer(
        files: files,
        initialIndex: initialIndex,
        // Al borrar desde pantalla completa, recargamos la galería si es exitoso
        onDelete: (file) async {
          await _confirmDeleteSingle(file);
        },
      ),
    ));
  }

  // Modificamos ligeramente el borrado individual para que funcione perfecto con la pantalla completa
  Future<void> _confirmDeleteSingle(File file) async {
    final bool? delete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar de forma permanente?"),
        content: const Text("Se borrará la foto original y su versión de auditoría."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (delete == true) {
      final success = await _controller.deletePhotoPair(file);
      if (mounted) {
        Navigator.pop(context); // Cierra la pantalla completa
        ScaffoldMessenger.of(context).clearSnackBars();
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Limpieza completa"), backgroundColor: Colors.green, duration: Duration(seconds: 1)));
        }
      }
    }
  }
}

// NUEVO WIDGET: Visor de Pantalla Completa Deslizable (PageView)
// =========================================================================
class FullScreenViewer extends StatefulWidget {
  final List<File> files;
  final int initialIndex;
  final Function(File) onDelete;

  const FullScreenViewer({
    super.key,
    required this.files,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  State<FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<FullScreenViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "${_currentIndex + 1} / ${widget.files.length}",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => widget.onDelete(widget.files[_currentIndex]),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.files.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final file = widget.files[index];
          return Center(
            child: Hero(
              tag: file.path,
              child: InteractiveViewer(
                child: Image.file(file),
              ),
            ),
          );
        },
      ),
    );
  }
}