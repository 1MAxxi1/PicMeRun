import 'package:flutter/material.dart';
import 'package:picmerun/screens/internal_gallery_screen.dart';

class CameraBottomControls extends StatelessWidget {
  final double selectedPixels;
  final ValueChanged<double> onPixelsChanged;
  final VoidCallback onTakeBurst;
  final VoidCallback onTakePicture;
  final VoidCallback onToggleCamera;
  final bool isBursting;
  final bool isChangingCamera;

  const CameraBottomControls({
    super.key,
    required this.selectedPixels,
    required this.onPixelsChanged,
    required this.onTakeBurst,
    required this.onTakePicture,
    required this.onToggleCamera,
    required this.isBursting,
    required this.isChangingCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
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
                selected: {selectedPixels},
                onSelectionChanged: (newSelection) => onPixelsChanged(newSelection.first),
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
                    onLongPress: onTakeBurst,
                    child: FloatingActionButton(
                        onPressed: onTakePicture,
                        backgroundColor: isBursting ? Colors.orange : Colors.white,
                        elevation: 4,
                        child: isBursting
                            ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3))
                            : const Icon(Icons.camera_alt, color: Colors.black, size: 30)
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: IconButton(
                        icon: const Icon(Icons.flip_camera_android, color: Colors.white, size: 30),
                        onPressed: isChangingCamera ? null : onToggleCamera
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}