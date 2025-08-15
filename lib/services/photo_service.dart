import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'door_detection_service.dart';
import 'logging_service.dart';

class PhotoService {
  static const String _photosFolder = 'lock_photos';

  /// Enhanced capture method with targeting validation
  static Future<String?> captureAndValidateDoorWithTargeting(CameraController controller) async {
    try {
      LoggingService.info('Step 1: Capturing photo...');
      final XFile imageFile = await controller.takePicture();
      
      LoggingService.info('Step 2: Decoding image...');
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? decodedImage = img.decodeImage(imageBytes);
      
      if (decodedImage == null) {
        LoggingService.error('Failed to decode captured image');
        await _cleanupTempFile(imageFile.path);
        return null;
      }

      LoggingService.info('Step 3: Validating door targeting...');
      
      // FIXED: Enhanced targeting validation
      final bool isValidDoor = await _validateDoorTargeting(decodedImage);
      
      if (isValidDoor) {
        LoggingService.info('✅ Valid door detected in target area');
        final savedPath = await _saveValidPhoto(imageBytes);
        await _cleanupTempFile(imageFile.path);
        return savedPath;
      } else {
        LoggingService.warning('❌ Invalid door targeting or no door in target area');
        await _cleanupTempFile(imageFile.path);
        return null;
      }
    } catch (e, st) {
      LoggingService.error('Photo capture and validation failed', e, st);
      return null;
    }
  }

  /// ENHANCED: Stricter door targeting validation
  static Future<bool> _validateDoorTargeting(img.Image image) async {
    try {
      LoggingService.info('🎯 Validating door targeting with strict criteria...');
      
      // Use high-confidence door detection
      final allDetections = await DoorDetectionService.detectObjects(image);
      LoggingService.info('🔍 Total detections: ${allDetections.length}');
      
      // Filter for doors only with high confidence
      final doorDetections = allDetections.where((d) => 
        d.label.toLowerCase() == 'door' && 
        d.confidence >= 0.70 // VERY HIGH threshold for targeting
      ).toList();
      
      if (doorDetections.isEmpty) {
        LoggingService.info('❌ No high-confidence doors detected in targeting area');
        return false;
      }

      // Define target area (same as overlay: 70% width, 60% height, centered)
      final targetWidth = image.width * 0.7;
      final targetHeight = image.height * 0.6;
      final targetLeft = (image.width - targetWidth) / 2;
      final targetTop = (image.height - targetHeight) / 2;
      final targetRight = targetLeft + targetWidth;
      final targetBottom = targetTop + targetHeight;

      // Check if any door meets ALL criteria
      for (final door in doorDetections) {
        final doorCenterX = door.x + door.w / 2;
        final doorCenterY = door.y + door.h / 2;
        
        // Must be centered in target area
        final centerInTarget = doorCenterX >= targetLeft && 
                               doorCenterX <= targetRight &&
                               doorCenterY >= targetTop && 
                               doorCenterY <= targetBottom;

        // Must fill significant portion of target area
        final doorArea = door.w * door.h;
        final targetArea = targetWidth * targetHeight;
        final areaRatio = doorArea / targetArea;

        // STRICT criteria for door locking
        final meetsAllCriteria = centerInTarget && 
                                areaRatio >= 0.35 && // Must fill 35% of target area
                                door.confidence >= 0.75 && // 75% confidence minimum
                                door.w >= 100 && // Minimum width
                                door.h >= 150; // Minimum height

        if (meetsAllCriteria) {
          LoggingService.info('✅ Perfect door found:');
          LoggingService.info('   Confidence: ${(door.confidence * 100).toStringAsFixed(1)}%');
          LoggingService.info('   Area ratio: ${(areaRatio * 100).toStringAsFixed(1)}%');
          LoggingService.info('   Size: ${door.w.round()}x${door.h.round()}');
          return true;
        } else {
          LoggingService.info('⚠️ Door found but doesn\'t meet criteria:');
          LoggingService.info('   Centered: $centerInTarget');
          LoggingService.info('   Area ratio: ${(areaRatio * 100).toStringAsFixed(1)}% (need 35%+)');
          LoggingService.info('   Confidence: ${(door.confidence * 100).toStringAsFixed(1)}% (need 75%+)');
        }
      }

      LoggingService.info('❌ No doors meet all strict targeting criteria');
      return false;
    } catch (e) {
      LoggingService.error('Door targeting validation failed', e);
      return false;
    }
  }

  /// Saves a validated photo to permanent storage
  static Future<String> _saveValidPhoto(Uint8List imageBytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final photosDir = Directory(path.join(directory.path, _photosFolder));
    
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'door_$timestamp.jpg';
    final filePath = path.join(photosDir.path, fileName);
    
    final file = File(filePath);
    await file.writeAsBytes(imageBytes);
    
    LoggingService.info('Photo saved: $filePath');
    return filePath;
  }

  /// Cleans up temporary files
  static Future<void> _cleanupTempFile(String tempPath) async {
    try {
      final file = File(tempPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      LoggingService.warning('Failed to cleanup temp file: $tempPath', e);
    }
  }

  /// FIXED: Enhanced method to delete photos when unlocking
  static Future<void> deletePhoto(String? photoPath) async {
    if (photoPath == null || photoPath.isEmpty) return;
    
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
        LoggingService.info('Photo deleted: $photoPath');
      }
    } catch (e) {
      LoggingService.warning('Failed to delete photo: $photoPath', e);
    }
  }

  /// Cleans up old photos (older than 30 days)
  static Future<void> cleanupOldPhotos() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final photosDir = Directory(path.join(directory.path, _photosFolder));
      
      if (!await photosDir.exists()) return;

      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final files = await photosDir.list().toList();
      
      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await file.delete();
            LoggingService.info('Cleaned up old photo: ${file.path}');
          }
        }
      }
    } catch (e) {
      LoggingService.warning('Failed to cleanup old photos', e);
    }
  }
}
