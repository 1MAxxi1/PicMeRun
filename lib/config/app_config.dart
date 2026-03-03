// Propósito: El panel de control central. Aquí guardamos las variables globales, URLs del
// servidor y configuraciones generales para no tenerlas dispersas por todo el código.

class AppConfig {
  // --- 🌐 INFRAESTRUCTURA (Cloudflare) ---

  // URL del Worker (Punto 9: File Setting)
  static const String workerUrl = 'https://morning-frog-acd5.gregorio-paz.workers.dev';

  // Timeout para evitar que la app se quede pegada (Punto 9: Esfuerzo)
  static const int connectionTimeoutSeconds = 30;

  // Credenciales de Cloudflare
  static const String accountId = 'c8c56ed4d9e53ff3722650d1085b1a49';
  static const String d1DatabaseId = '25f2ab26-87ba-47c3-81a0-a0e38596db21';
  static const String r2BucketName = 'picmerun-images';


  // --- 🤖 INTELIGENCIA ARTIFICIAL (ML Kit & Face Embeddings) ---

  // CONFIDENCIALIDAD DE DETECCIÓN (Gregorio sugirió > 90%)
  // Si ML Kit está menos seguro que esto, la cara se ignora para evitar falsos positivos.
  static double faceDetectionThreshold = 0.75;

  // TAMAÑO MÍNIMO DE CARA (Scale 0.0 a 1.0)
  // 0.1 significa que el rostro debe ocupar al menos el 10% de la imagen.
  // Ayuda a ignorar personas muy lejanas que saldrían pixeladas (Insight de Gregorio).
  static double minFaceSize = 0.1;

  // UMBRAL DE SIMILITUD (Clustering)
  // Define qué tan parecidos deben ser dos vectores para ser la misma persona.
  // 0.5 es el punto de partida; si crea muchas identidades del mismo, hay que bajarlo.
  static double identityMatchThreshold = 0.5;

  // LÍMITE DE PROCESAMIENTO
  // Máximo de rostros a extraer por cada fotografía capturada o subida.
  static int maxFacesPerPhoto = 8;


  // --- CONFIGURACIÓN DE UI/UX ---

  // Calidad de la imagen JPG al guardar (1-100)
  static int imageQuality = 85;

  // Resolución de la previsualización de cámara
  static bool useHighResPreview = false; // False = Medium para mejor rendimiento
}