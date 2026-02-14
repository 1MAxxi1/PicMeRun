import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;

class TorsoService {
  static final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(model: PoseDetectionModel.base, mode: PoseDetectionMode.single),
  );

  static Future<String?> processTorso(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final List<Pose> poses = await _poseDetector.processImage(inputImage);

    if (poses.isEmpty) return null;

    final pose = poses.first;
    // Puntos clave de Gregorio: Hombros y Caderas
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftShoulder == null || rightShoulder == null) return null;

    // 1. Cargamos la imagen original
    final bytes = await File(imagePath).readAsBytes();
    final originalImage = img.decodeImage(bytes);
    if (originalImage == null) return null;

    // 2. Calculamos el área del torso con PADDING (Margen extra)
    // Usamos el punto más alto de los hombros y el más bajo de las caderas
    double minX = min(leftShoulder.x, rightShoulder.x);
    double maxX = max(leftShoulder.x, rightShoulder.x);
    double minY = min(leftShoulder.y, rightShoulder.y);
    double maxY = (leftHip != null && rightHip != null)
        ? max(leftHip.y, rightHip.y)
        : minY + (maxX - minX) * 1.5; // Estimación si no ve la cadera

    // ✅ MEJORA SENIOR: Añadimos un 25% de margen para no cortar brazos ni dorsales
    double width = maxX - minX;
    double height = maxY - minY;

    int cropX = (minX - (width * 0.25)).clamp(0, originalImage.width.toDouble()).toInt();
    int cropY = (minY - (height * 0.20)).clamp(0, originalImage.height.toDouble()).toInt();
    int cropW = (width * 1.5).clamp(1, originalImage.width - cropX).toInt();
    int cropH = (height * 1.6).clamp(1, originalImage.height - cropY).toInt();

    // 3. Realizamos el recorte
    final croppedTorso = img.copyCrop(originalImage, x: cropX, y: cropY, width: cropW, height: cropH);

    // 4. Guardamos el recorte
    final String torsoPath = imagePath.replaceFirst('.jpg', '_torso.jpg');
    await File(torsoPath).writeAsBytes(img.encodeJpg(croppedTorso));

    return torsoPath;
  }
}