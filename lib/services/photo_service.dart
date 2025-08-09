import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'logging_service.dart';

/// A top-level function required for running in an isolate via compute().
/// This function handles all heavy image processing and file I/O.
Future<bool> _processAndSaveImage(Map<String, dynamic> params) async {
  try {
    final Uint8List imageBytes = params['bytes'];
    final String text = params['text'];
    final String path = params['path'];

    // 1. Decode the image (CPU intensive)
    final img.Image? original = img.decodeImage(imageBytes);
    if (original == null) return false;

    // 2. Draw the timestamp onto the image (CPU intensive)
    img.drawString(
      original,
      text,
      font: img.arial48,
      x: 10,
      y: original.height - 50,
      color: img.ColorRgba8(255, 255, 255, 250),
    );

    // 3. Re-encode the image to JPG format (CPU intensive)
    final processedBytes = img.encodeJpg(original, quality: 85);

    // 4. Write the file to disk (I/O operation)
    await File(path).writeAsBytes(processedBytes);
    return true;
  } catch (e) {
    // Cannot use LoggingService here as it's not safe across isolates.
    // Return false and let the main thread handle logging.
    return false;
  }
}

class PhotoService {
  static final ImagePicker _picker = ImagePicker();

  // Încarcă poză + adaugă timestamp
  static Future<String?> takeAndSavePhotoWithTimestamp() async {
    try {
      // 1. Pick image (this is a UI operation, must be on the main thread)
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo == null) return null;

      // 2. Prepare all necessary data on the main thread
      final bytes = await photo.readAsBytes();
      final now = DateTime.now();
      final text = "${_formatNumber(now.day)}.${_formatNumber(now.month)}.${now.year} "
                   "${_formatNumber(now.hour)}:${_formatNumber(now.minute)}";
      
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'lock_${now.millisecondsSinceEpoch}.jpg';
      final path = p.join(appDir.path, fileName);

      final params = {
        'bytes': bytes,
        'text': text,
        'path': path,
      };

      // 3. Offload all heavy work to the background isolate
      final success = await compute(_processAndSaveImage, params);

      if (success) {
        LoggingService.info('Photo saved successfully at $path');
        return path;
      } else {
        LoggingService.error('Failed to process and save photo in isolate.');
        return null;
      }
    } catch (e, s) {
      LoggingService.error('Error taking photo', e, s);
      return null;
    }
  }

  // Renamed for clarity
  static String _formatNumber(int n) => n.toString().padLeft(2, '0');
}
