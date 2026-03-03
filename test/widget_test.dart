// Propósito: Control de calidad automatizado (Smoke Test). Verifica que la
// aplicación logre arrancar en memoria correctamente sin colapsar antes de mandarla a producción.

import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:picmerun/main.dart';

void main() {
  testWidgets('PicMeRun App Boot - Smoke Test', (WidgetTester tester) async {
    // 1. Simulamos un entorno donde el celular (temporalmente) no tiene cámaras
    final List<CameraDescription> mockCameras = [];

    // 2. Encendemos la app en el entorno de pruebas de Flutter
    await tester.pumpWidget(PicMeRunApp(cameras: mockCameras));

    // 3. LA PRUEBA: Simplemente verificamos que el "esqueleto" de la app se logró construir.
    // Si la app tuviera un error fatal de inicio, el test colapsaría antes de llegar aquí.
    expect(find.byType(PicMeRunApp), findsOneWidget);
  });
}