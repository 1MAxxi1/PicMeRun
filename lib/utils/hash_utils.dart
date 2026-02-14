import 'dart:io';
import 'package:crypto/crypto.dart'; // Librería de criptografía

class HashUtils {
  /// Lee un archivo y devuelve su "Huella Digital" única (MD5)
  static Future<String> getFileMd5(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return '';

    // Leemos los bytes del archivo
    final bytes = await file.readAsBytes();

    // Calculamos el Hash
    final digest = md5.convert(bytes);

    // Devolvemos el código hexadecimal (ej: "a3f9e2...")
    return digest.toString();
  }
}