import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CryptoKeyService {
  static const _photoKeyName = 'photo_encryption_key_v1';
  static const _storage = FlutterSecureStorage();

  // 32-byte AES-256 key
  static Future<Uint8List> getOrCreatePhotoKey() async {
    String? base64Key = await _storage.read(key: _photoKeyName);
    if (base64Key == null) {
      // Generate 32 random bytes using Dart's SecureRandom from the OS via Hive helper.
      // Reuse Hive key gen (cryptographically secure).
      final key = await _generate32Bytes();
      base64Key = base64Encode(key);
      await _storage.write(key: _photoKeyName, value: base64Key);
      return key;
    }
    return Uint8List.fromList(base64Decode(base64Key));
  }
  static Future<Uint8List> _generate32Bytes() async {
    // Generate 32 cryptographically secure random bytes using Random.secure().
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    return Uint8List.fromList(keyBytes);
  }
  }
