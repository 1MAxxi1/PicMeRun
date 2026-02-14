# 🛠 Guía de Instalación y Configuración - PicMeRun

Este documento contiene los pasos detallados para configurar el entorno y ejecutar la aplicación correctamente.

## 1. Requisitos del Sistema
* **Flutter SDK**: >= 3.0.0.
* **Dart SDK**: >= 3.0.0.
* **Plataforma**: Recomendado dispositivo físico Android (para pruebas de cámara e IA).

## 2. Pasos de Instalación
1. **Descargar el proyecto**:
   `git clone [URL_REPOSITORIO]`
2. **Instalar dependencias**:
   `flutter pub get`
3. **Limpiar caché (Opcional si hay errores)**:
   `flutter clean` seguido de `flutter pub get`.

## 3. Configuración de Credenciales
Para que la sincronización con la nube funcione, debes editar el archivo:
`lib/config/app_config.dart`

Actualiza los siguientes valores:
* `baseUrl`: URL de tu Cloudflare Worker.
* `apiKey`: Tu clave de acceso si está configurada.
* `minConfidence`: Ajustado a `0.72` (según requerimiento de detección de torso).

## 4. Permisos de Dispositivo
Asegúrate de que el dispositivo tenga acceso a:
* **Cámara**: Para capturar a los corredores.
* **Internet**: Para subir fotos a Cloudflare R2/D1.
* **Almacenamiento**: Para guardar la cola de envío en SQLite.