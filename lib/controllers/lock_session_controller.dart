import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/lock_item.dart';
import '../services/door_detection_service.dart';
import '../services/photo_service.dart';
import '../services/logging_service.dart';

// This helper function is ready to be run in an isolate.
Future<bool> _isDoorInIsolate(String path) {
  return DoorDetectionService.isDoor(path);
}

class LockSessionController extends ChangeNotifier {
  late Box<LockItem> _itemsBox;
  final _uuid = const Uuid();

  List<LockItem> get items => _itemsBox.values.toList();

  // --- Add these getters to restore the missing properties ---

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
    // Check if the box is empty and add default items if needed.
    if (_itemsBox.isEmpty) {
      LoggingService.info('Box is empty, populating with default items.');
      final defaultItems = [
        LockItem(id: 'primary', name: 'Front Door'),
        LockItem(id: 'secondary', name: 'Garage Door'),
        LockItem(id: 'tertiary', name: 'Back Door'),
      ];
      // Use put() to add items. The key is the item's ID.
      for (var item in defaultItems) {
        await _itemsBox.put(item.id, item);
      }
    }
    LoggingService.info('${_itemsBox.length} items loaded from Hive.');
    notifyListeners();
  }

  // --- Add this new method ---
  Future<void> addItem(String name) async {
    final newItem = LockItem(
      id: _uuid.v4(), // Generate a unique ID
      name: name,
    );
    await _itemsBox.put(newItem.id, newItem);
    LoggingService.info('Added new item: $name');
    notifyListeners();
  }

  Future<String?> lockItem(String id) async {
    // Capture to temp, do not save yet
    final capture = await PhotoService.capturePhoto();
    if (capture == null) return "Photo cancelled.";

    // Validate in background isolate
    final isDoor = await PhotoService.isValidDoor(capture.tempPath);
    if (!isDoor) {
      await PhotoService.deleteIfExists(capture.tempPath);
      return "Door not detected. Please retake the photo facing the door.";
    }

    // Valid: process + encrypt + save to persistent storage
    final savedPath = await PhotoService.processEncryptAndSave(capture.bytes);
    // Always cleanup the temp capture
    await PhotoService.deleteIfExists(capture.tempPath);

    if (savedPath == null) {
      return "Failed to save photo. Try again.";
    }

    final item = _itemsBox.get(id);
    if (item != null) {
      item.isLocked = true;
      item.photoPath = savedPath;
      item.timestamp = DateTime.now();
      await item.save(); // Use .save() because LockItem extends HiveObject
      LoggingService.info('Locked item: ${item.name}');
      notifyListeners();
    }
    return null;
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

  /// Resets the state of all items and deletes associated photos.
  Future<void> clearAllData() async {
    LoggingService.warning('Resetting all item states and deleting photos.');

    // Iterate through all items in the box without deleting the entries.
    for (var item in _itemsBox.values) {
      // 1. Delete the associated photo file from storage if it exists.
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

      // 2. Reset the item's properties to their default state.
      item.isLocked = false;
      item.photoPath = null;
      item.timestamp = null;

      // 3. Save the updated item back to the database.
      await item.save();
    }

    LoggingService.info('All items have been reset.');
    // Update the UI to reflect the changes.
    notifyListeners();
  }
}
