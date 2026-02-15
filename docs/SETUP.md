Guía de Ejecución Rápida: PicMeRun

Preparación del Entorno (SDK)

instalación de:

-Android studio
-Flutter

Despliegue: Ubicar el SDK en `C:\src\flutter` 
Variables de Entorno (PATH):
   - Buscar "Variables de entorno" en Windows > Editar Path y agregar uno nuevo.
   - Agregar: `C:\src\flutter\bin`.
Modo Desarrollador: Activar en Configuración de Windows para permitir *Symlinks* de plugins.

Configuración de Android & Licencias
Command-line Tools: En Android Studio ir a `Settings > Languages & Frameworks > Android SDK > SDK Tools`. Instalar **Android SDK Command-line Tools (latest)**.
Validación: Ejecutar `flutter doctor` en terminal.
Licencias: Ejecutar `flutter doctor --android-licenses` y aceptar todos los términos (`y`).

Configuración del IDE
-Plugins: Instalar Flutter y Dart desde `Settings > Plugins` y reiniciar.
-Vincular SDK: En `Settings > Languages & Frameworks > Flutter`, definir la ruta `C:\src\flutter`.
-Dependencias: Ejecutar `flutter pub get` en la terminal del proyecto.

Ejecución
-Conectar dispositivo físico (Modo Depuración USB activo).
-Ejecutar limpieza: `flutter clean`.
-Lanzar aplicación: `flutter run --release` 


