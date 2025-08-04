import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class PhotoService {
  static final ImagePicker _picker = ImagePicker();

  // Încarcă poză + adaugă timestamp
  static Future<String?> takeAndSavePhotoWithTimestamp() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // Add compression to reduce file size
      );
      if (photo == null) return null;

      final bytes = await photo.readAsBytes();
      final img.Image? original = img.decodeImage(bytes);
      if (original == null) return null;

      final now = DateTime.now();
      final text = "${_formatNumber(now.day)}.${_formatNumber(now.month)}.${now.year} "
                   "${_formatNumber(now.hour)}:${_formatNumber(now.minute)}";

      img.drawString(
        original,
        text,
        font: img.arial48,    // Fontul predefinit
        x: 10,
        y: original.height - 50,
        color: img.ColorRgba8(255, 255, 255, 250)      // white
      );

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'lock_${now.millisecondsSinceEpoch}.jpg';
      final path = p.join(appDir.path, fileName);

      await File(path).writeAsBytes(img.encodeJpg(original, quality: 85));
      return path;
    } catch (e) {
      print('Error taking photo: $e'); // Add error logging
      return null;
    }
  }

  // Renamed for clarity
  static String _formatNumber(int n) => n.toString().padLeft(2, '0');
}
