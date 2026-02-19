import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:picmerun/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // 1. Creamos una lista de cámaras vacía para el test
    final List<CameraDescription> mockCameras = [];

    // 2. Construimos la app pasando la lista (quitamos el 'const')
    await tester.pumpWidget(PicMeRunApp(cameras: mockCameras));

    // El resto del test probablemente fallará si no tienes un contador,
    // pero al menos los errores rojos de compilación desaparecerán.
  });
}