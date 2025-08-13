import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'door_detection_service.dart';
import 'logging_service.dart';

class PhotoService {
  /// Captures a photo, validates if it's a door, and saves it if valid.
  static Future<String?> captureAndValidateDoor(CameraController controller) async {
    try {
      LoggingService.info("Step 1: Capturing photo...");
      final highResPhoto = await controller.takePicture();
      final highResBytes = await File(highResPhoto.path).readAsBytes();

      LoggingService.info("Step 2: Decoding image...");
      final originalImage = img.decodeImage(highResBytes);
      if (originalImage == null) {
        await File(highResPhoto.path).delete();
        LoggingService.error("Failed to decode captured image.");
        return null;
      }
      
      LoggingService.info("Step 3: Running AI door detection...");
      final isDoor = await DoorDetectionService.isDoorImage(originalImage, doorConfidence: 0.5);
      
      if (isDoor) {
        LoggingService.info("✅ Door detected! Saving photo...");
        final savedPath = await _persist(highResBytes);
        await File(highResPhoto.path).delete(); // Clean up temp file
        LoggingService.info("Photo saved to: $savedPath");
        return savedPath;
      } else {
        LoggingService.warning("❌ Not a door. Discarding photo.");
        await File(highResPhoto.path).delete();
        return null;
      }
      
    } catch (e, stackTrace) {
      LoggingService.error('Capture & Validation process failed.', e, stackTrace);
      return null;
    }
  }
  
  /// Saves photo bytes to the app's documents directory.
  static Future<String> _persist(Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'door_photos'));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final file = File(p.join(folder.path, 'door_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    await file.writeAsBytes(bytes);
    return file.path;
  }
  
  /// Gets all saved door photos
  static Future<List<String>> getSavedPhotos() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(directory.path, 'door_photos'));
      
      if (!await photosDir.exists()) {
        return [];
      }
      
      final files = await photosDir.list().toList();
      final photoFiles = files
          .where((file) => file is File && file.path.endsWith('.jpg'))
          .map((file) => file.path)
          .toList();
      
      // Sort by newest first
      photoFiles.sort((a, b) => b.compareTo(a));
      return photoFiles;
    } catch (e) {
      LoggingService.error('Failed to get saved photos: $e');
      return [];
    }
  }
  
  /// Deletes a saved photo
  static Future<bool> deletePhoto(String photoPath) async {
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
        LoggingService.info('Photo deleted: $photoPath');
        return true;
      }
      return false;
    } catch (e) {
      LoggingService.error('Failed to delete photo: $e');
      return false;
    }
  }
}
