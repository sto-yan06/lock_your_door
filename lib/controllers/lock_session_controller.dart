import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:camera/camera.dart'; // Add this import
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

  /// Reports the last activity timestamp of the primary door.
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

  // UPDATED: Use the new dual capture method with camera controller
  Future<String?> lockItemWithCamera(String id, CameraController controller) async {
    try {
      // Use the new dual capture method
      final savedPath = await PhotoService.captureAndValidateDoor(controller);
      
      if (savedPath != null) {
        // Door detected and photo saved
        final item = _itemsBox.get(id);
        if (item != null) {
          item.isLocked = true;
          item.photoPath = savedPath;
          item.timestamp = DateTime.now();
          await item.save();
          LoggingService.info('Locked item: ${item.name}');
          notifyListeners();
        }
        return null; // Success
      } else {
        return "Door not detected. Please retake the photo facing the door.";
      }
    } catch (e) {
      LoggingService.error('Failed to lock item with camera: $e');
      return "Failed to capture photo. Try again.";
    }
  }

  // DEPRECATED: Keep old method for backward compatibility, but mark it
  @Deprecated('Use lockItemWithCamera instead')
  Future<String?> lockItem(String id) async {
    // This method is no longer used since we removed the old PhotoService methods
    return "Please use the camera interface to lock items.";
  }

  Future<void> unlockItem(String id) async {
    final item = _itemsBox.get(id);
    if (item != null) {
      item.isLocked = false;
      await item.save();
      LoggingService.info('Unlocked item: ${item.name}');
      notifyListeners();
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
      item.timestamp = null;
      await item.save();
    }

    LoggingService.info('All items have been reset.');
    notifyListeners();
  }
}
