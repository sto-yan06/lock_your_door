import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import '../services/photo_service.dart';
import '../services/lock_status_service.dart';
import '../models/lock_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LockItem {
  final String id;
  String name;
  bool isLocked;
  String? photoPath;
  DateTime? timestamp;

  LockItem({
    required this.id,
    required this.name,
    this.isLocked = false,
    this.photoPath,
    this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isLocked': isLocked,
        'photoPath': photoPath,
        'timestamp': timestamp?.toIso8601String(),
      };

  factory LockItem.fromJson(Map<String, dynamic> json) => LockItem(
        id: json['id'] as String,
        name: json['name'] as String,
        isLocked: json['isLocked'] as bool? ?? false,
        photoPath: json['photoPath'] as String?,
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'])
            : null,
      );
}

class LockSessionController extends ChangeNotifier {
  static const _extraItemsKey = 'extra_lock_items_v1';

  // Single-item legacy fields (kept for backward compatibility with other views)
  bool isLocked = false;
  String? lastPhotoPath;
  DateTime? lastTimestamp;

  // New multi-item list
  final List<LockItem> items = [];

  LockSessionController() {
    _loadInitialStatus();
  }

  // Load status on app start
  Future<void> _loadInitialStatus() async {
    final status = await LockStatusService.getStatus();
    // Create (or update) primary item (Door 1)
    final primary = LockItem(
      id: 'primary',
      name: 'Door 1',
      isLocked: status.isLocked,
      photoPath: status.photoPath,
      timestamp: status.timestamp,
    );
    items.add(primary);
    await _loadExtraItems();         // <- load saved extra doors
    // Mirror legacy fields
    isLocked = primary.isLocked;
    lastPhotoPath = primary.photoPath;
    lastTimestamp = primary.timestamp;
    notifyListeners();
  }

  Future<void> _loadExtraItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_extraItemsKey);
    if (raw == null) return;
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      for (final e in decoded) {
        try {
          final item = LockItem.fromJson(Map<String, dynamic>.from(e));
          if (item.id != 'primary') {
            items.add(item);
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _saveExtraItems() async {
    final prefs = await SharedPreferences.getInstance();
    final extra = items
        .where((e) => e.id != 'primary')
        .map((e) => e.toJson())
        .toList();
    await prefs.setString(_extraItemsKey, jsonEncode(extra));
  }

  // Add a new lockable item (not persisted yet)
  void addItem(String name) {
    final id = DateTime.now().millisecondsSinceEpoch.toString() +
        '_' +
        Random().nextInt(9999).toString();
    items.add(LockItem(id: id, name: name));
    _saveExtraItems();               // <- persist
    notifyListeners();
  }

  Future<void> lockItem(String id) async {
    final item = items.firstWhere((e) => e.id == id);
    final photoPath = await PhotoService.takeAndSavePhotoWithTimestamp();
    if (photoPath == null) return;
    item.isLocked = true;
    item.photoPath = photoPath;
    item.timestamp = DateTime.now();
    if (id == 'primary') {
      await LockStatusService.setLocked(photoPath);
      isLocked = true;
      lastPhotoPath = photoPath;
      lastTimestamp = item.timestamp;
    } else {
      await _saveExtraItems();
    }
    notifyListeners();
  }

  Future<void> unlockItem(String id) async {
    final item = items.firstWhere((e) => e.id == id);
    item.isLocked = false;
    item.photoPath = null;
    item.timestamp = null;
    if (id == 'primary') {
      await LockStatusService.setUnlocked();
      isLocked = false;
      lastPhotoPath = null;
      lastTimestamp = null;
    } else {
      await _saveExtraItems();
    }
    notifyListeners();
  }

  // Legacy single-door APIs (map to primary item)
  Future<void> startLockSession() async {
    await lockItem('primary');
  }

  // Unlock session manually
  Future<void> unlock() async {
    await unlockItem('primary');
  }

  // Clear all stored data
  Future<void> clearAllData() async {
    await unlockItem('primary');
    // Clear non-primary in-memory
    items.removeWhere((e) => e.id != 'primary');
    await _saveExtraItems();
    notifyListeners();
  }

  // Get current lock status (optional public getter)
  LockStatus get currentStatus => LockStatus(
        isLocked: isLocked,
        photoPath: lastPhotoPath,
        timestamp: lastTimestamp,
      );
}
