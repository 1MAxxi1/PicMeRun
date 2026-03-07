import 'package:flutter/material.dart';
import 'package:picmerun/screens/queue_screen.dart';
import 'package:picmerun/screens/log_view_screen.dart';

class CameraTopBar extends StatelessWidget {
  final VoidCallback onImportPressed;
  final bool isProcessing;

  const CameraTopBar({
    super.key,
    required this.onImportPressed,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
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
                  onPressed: isProcessing ? null : onImportPressed,
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
    );
  }
}
