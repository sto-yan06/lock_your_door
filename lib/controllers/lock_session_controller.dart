import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:camera/camera.dart';
import '../models/lock_item.dart';
import '../services/photo_service.dart';
import '../services/logging_service.dart';

class LockSessionController extends ChangeNotifier {
  late Box<LockItem> _itemsBox;
  final _uuid = const Uuid();

  List<LockItem> get items => _itemsBox.values.toList();

  /// Returns the primary lock item from the database.
  LockItem? get _primaryItem => _itemsBox.get('primary');

  /// Reports the lock status of the primary door.
  bool get isLocked => _primaryItem?.isLocked ?? false;

  /// FIXED: Use the timestamp getter
  DateTime? get lastTimestamp => _primaryItem?.timestamp;

  /// Reports the last photo path of the primary door.
  String? get lastPhotoPath => _primaryItem?.photoPath;

  LockSessionController() {
    _itemsBox = Hive.box<LockItem>('lock_items');
  }

  Future<void> loadInitialData() async {
    if (_itemsBox.isEmpty) {
      LoggingService.info('Box is empty, populating with default items.');
      final defaultItems = [
        LockItem(id: 'primary', name: 'Front Door'),
        LockItem(id: 'secondary', name: 'Garage Door'),
        LockItem(id: 'tertiary', name: 'Back Door'),
      ];
      for (var item in defaultItems) {
        await _itemsBox.put(item.id, item);
      }
    }
    LoggingService.info('${_itemsBox.length} items loaded from Hive.');
    notifyListeners();
  }

  Future<void> addItem(String name) async {
    final newItem = LockItem(
      id: _uuid.v4(),
      name: name,
    );
    await _itemsBox.put(newItem.id, newItem);
    LoggingService.info('Added new item: $name');
    notifyListeners();
  }

  Future<String?> lockItemWithCamera(String id, CameraController controller) async {
    try {
      final savedPath = await PhotoService.captureAndValidateDoorWithTargeting(controller);
      
      if (savedPath != null) {
        final item = _itemsBox.get(id);
        if (item != null) {
          await item.lockWithPhoto(savedPath);
          LoggingService.info('Locked item: ${item.name}');
          notifyListeners();
        }
        return null; // Success
      } else {
        return "Door not detected or not properly positioned. Please retake the photo with the door in the target area.";
      }
    } catch (e) {
      LoggingService.error('Failed to lock item with camera: $e');
      return "Failed to capture photo. Try again.";
    }
  }

  @Deprecated('Use lockItemWithCamera instead')
  Future<String?> lockItem(String id) async {
    return "Please use the camera interface to lock items.";
  }

  Future<void> unlockItem(String id) async {
    try {
      final item = _itemsBox.get(id);
      if (item != null) {
        LoggingService.info('🔓 Unlocking item: ${item.name}');
        await item.unlock();
        LoggingService.info('✅ Item unlocked with photo cleanup: ${item.name}');
        notifyListeners();
      }
    } catch (e) {
      LoggingService.error('Failed to unlock item', e);
      rethrow;
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      final item = _itemsBox.get(id);
      if (item != null) {
        LoggingService.info('🗑️ Deleting item: ${item.name}');
        await item.delete();
        LoggingService.info('✅ Item deleted with photo cleanup: ${item.name}');
        notifyListeners();
      }
    } catch (e) {
      LoggingService.error('Failed to delete item', e);
      rethrow;
    }
  }

  Future<void> clearAllData() async {
    LoggingService.warning('Resetting all item states and deleting photos.');

    for (var item in _itemsBox.values) {
      if (item.photoPath != null) {
        try {
          final photoFile = File(item.photoPath!);
          if (await photoFile.exists()) {
            await photoFile.delete();
            LoggingService.debug('Deleted photo: ${item.photoPath}');
          }
        } catch (e) {
          LoggingService.warning('Could not delete photo file: ${item.photoPath}', e);
        }
      }

      item.isLocked = false;
      item.photoPath = null;
      // FIXED: Set both timestamp fields to null
      item.lockedAt = null;
      item.unlockedAt = null;
      await item.save();
    }

    LoggingService.info('All items have been reset.');
    notifyListeners();
  }
}
