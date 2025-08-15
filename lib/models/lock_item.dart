import 'dart:io';
import 'package:hive/hive.dart';
import '../services/logging_service.dart';

part 'lock_item.g.dart';

@HiveType(typeId: 0)
class LockItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  bool isLocked;

  @HiveField(3)
  DateTime? lockedAt;

  @HiveField(4)
  String? photoPath;

  @HiveField(5)
  DateTime? unlockedAt;

  LockItem({
    required this.id,
    required this.name,
    this.isLocked = false,
    this.lockedAt,
    this.photoPath,
    this.unlockedAt,
  });

  /// FIXED: Add timestamp getter for backward compatibility
  DateTime? get timestamp => lockedAt ?? unlockedAt;

  /// ENHANCED: Lock with photo and validation
  Future<void> lockWithPhoto(String newPhotoPath) async {
    try {
      // Validate photo file exists
      final photoFile = File(newPhotoPath);
      if (!await photoFile.exists()) {
        throw Exception('Photo file does not exist: $newPhotoPath');
      }

      // Clean up old photo if it exists
      await _cleanupOldPhoto();

      // Update lock state
      photoPath = newPhotoPath;
      isLocked = true;
      lockedAt = DateTime.now();
      unlockedAt = null;

      // Save to Hive
      await save();
      
      LoggingService.info('✅ Item locked with photo: $name');
    } catch (e) {
      LoggingService.error('Failed to lock item with photo', e);
      rethrow;
    }
  }

  /// FIXED: Enhanced unlock with proper photo cleanup
  Future<void> unlock() async {
    try {
      LoggingService.info('🔓 Unlocking item: $name');
      
      // Clean up photo BEFORE updating state
      await _cleanupOldPhoto();
      
      // Update unlock state
      isLocked = false;
      unlockedAt = DateTime.now();
      photoPath = null; // Clear photo path
      
      // Save to Hive
      await save();
      
      LoggingService.info('✅ Item unlocked and photo cleaned up: $name');
    } catch (e) {
      LoggingService.error('❌ Failed to unlock item', e);
      rethrow;
    }
  }

  /// ENHANCED: Cleanup old photo with better error handling
  Future<void> _cleanupOldPhoto() async {
    if (photoPath == null || photoPath!.isEmpty) return;

    try {
      final oldFile = File(photoPath!);
      if (await oldFile.exists()) {
        await oldFile.delete();
        LoggingService.info('🗑️ Deleted old photo: $photoPath');
      } else {
        LoggingService.warning('📁 Photo file not found (already deleted?): $photoPath');
      }
    } catch (e) {
      // Don't throw - photo cleanup failure shouldn't break unlock
      LoggingService.warning('⚠️ Failed to delete old photo: $photoPath', e);
    }
  }

  /// ENHANCED: Delete with cleanup
  @override
  Future<void> delete() async {
    try {
      // Clean up photo before deleting the item
      await _cleanupOldPhoto();
      
      // Delete from Hive
      await super.delete();
      
      LoggingService.info('🗑️ Item deleted with photo cleanup: $name');
    } catch (e) {
      LoggingService.error('Failed to delete item', e);
      rethrow;
    }
  }

  // Getters for UI
  String get statusText => isLocked ? 'Locked' : 'Unlocked';
  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;
  
  Duration? get lockDuration {
    if (!isLocked || lockedAt == null) return null;
    return DateTime.now().difference(lockedAt!);
  }

  String get lockDurationText {
    final duration = lockDuration;
    if (duration == null) return '';
    
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ago';
    } else if (duration.inHours < 24) {
      return '${duration.inHours}h ago';
    } else {
      return '${duration.inDays}d ago';
    }
  }
}