import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityUtils {
  // Pepper statis sistem untuk menambah entropi keamanan hashing
  static const String _systemPepper = 'ELearning_SuperApp_SecP3pp3r_2026';

  /// Melakukan hashing password dengan SHA-256 + Salt + Pepper
  static String hashPassword(String rawPassword, {String salt = ''}) {
    final input = '$_systemPepper:${salt.trim()}:$rawPassword';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Memverifikasi kecocokan password dengan hash tersimpan
  static bool verifyPassword(String rawPassword, String storedHash, {String salt = ''}) {
    if (storedHash.isEmpty) return false;
    final computedHash = hashPassword(rawPassword, salt: salt);
    // Timing-safe constant-time comparison
    if (computedHash.length != storedHash.length) return false;
    int result = 0;
    for (int i = 0; i < computedHash.length; i++) {
      result |= computedHash.codeUnitAt(i) ^ storedHash.codeUnitAt(i);
    }
    return result == 0;
  }
}
