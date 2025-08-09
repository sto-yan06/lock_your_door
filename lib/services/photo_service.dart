import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:cryptography/cryptography.dart';

import 'crypto_key_service.dart';
import 'logging_service.dart';
import 'door_detection_service.dart';

class PhotoCapture {
  final String tempPath;      // image_picker temp file path
  final Uint8List bytes;      // raw capture bytes
  PhotoCapture(this.tempPath, this.bytes);
}

/// compute() worker: encode JPEG, encrypt AES-GCM(256) and write file
Future<bool> _processEncryptAndSaveImage(Map<String, dynamic> raw) async {
  try {
    final Uint8List inputBytes = raw['inputBytes'];
    final String overlayText = raw['overlayText'];
    final String outPath = raw['outPath'];
    final Uint8List keyBytes = raw['keyBytes'];

    final original = img.decodeImage(inputBytes);
    if (original == null) return false;

    img.drawString(
      original,
      overlayText,
      font: img.arial24,
      x: 12,
      y: original.height - 40,
      color: img.ColorRgba8(255, 255, 255, 240),
    );

    final jpegBytes = Uint8List.fromList(img.encodeJpg(original, quality: 85));

    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce(); // 12 bytes
    final box = await algorithm.encrypt(
      jpegBytes,
      secretKey: SecretKey(keyBytes),
      nonce: nonce,
    );

    final out = BytesBuilder()
      ..add(nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);

    await File(outPath).writeAsBytes(out.takeBytes(), flush: true);
    return true;
  } catch (_) {
    return false;
  }
}

/// compute() worker: run door detection by path (kept simple)
Future<bool> _isDoorInIsolate(String path) async {
  return DoorDetectionService.isDoor(path);
}

class PhotoService {
  static final ImagePicker _picker = ImagePicker();

  // 1) Capture a photo to a temp file but DO NOT persist it.
  static Future<PhotoCapture?> capturePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null) return null;
    final bytes = await photo.readAsBytes();
    return PhotoCapture(photo.path, bytes);
  }

  // 2) Validate the temp capture is a door (off the UI thread).
  static Future<bool> isValidDoor(String tempPath) {
    return compute(_isDoorInIsolate, tempPath);
  }

  // 3) If valid, process + encrypt + save to app docs. Returns final path.
  static Future<String?> processEncryptAndSave(Uint8List inputBytes) async {
    try {
      final keyBytes = await CryptoKeyService.getOrCreatePhotoKey();
      final now = DateTime.now();
      final overlay =
          '${_two(now.day)}.${_two(now.month)}.${now.year} ${_two(now.hour)}:${_two(now.minute)}';

      final appDir = await getApplicationDocumentsDirectory();
      final outPath = p.join(appDir.path, 'lock_${now.millisecondsSinceEpoch}.jpg.enc');

      final ok = await compute(_processEncryptAndSaveImage, {
        'inputBytes': inputBytes,
        'overlayText': overlay,
        'outPath': outPath,
        'keyBytes': keyBytes,
      });

      if (!ok) return null;
      LoggingService.info('Encrypted photo saved at $outPath');
      return outPath;
    } catch (e, s) {
      LoggingService.error('processEncryptAndSave failed', e, s);
      return null;
    }
  }

  // 4) Decrypt for display
  static Future<Uint8List?> loadDecryptedImageBytes(String path) async {
    try {
      final data = await File(path).readAsBytes();
      if (data.length < 12 + 16) return null;

      final nonce = data.sublist(0, 12);
      final macBytes = data.sublist(data.length - 16);
      final cipherText = data.sublist(12, data.length - 16);

      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: SecretKey(await CryptoKeyService.getOrCreatePhotoKey()),
      );
      return Uint8List.fromList(clear);
    } catch (e) {
      LoggingService.warning('Failed to decrypt $path: $e');
      return null;
    }
  }

  // 5) Best-effort temp cleanup
  static Future<void> deleteIfExists(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
