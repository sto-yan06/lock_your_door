import 'package:flutter/material.dart';
import '../services/photo_service.dart';
import '../services/lock_status_service.dart';
import '../models/lock_status.dart';

class LockSessionController extends ChangeNotifier {
  bool isLocked = false;
  String? lastPhotoPath;
  DateTime? lastTimestamp;

  LockSessionController() {
    _loadInitialStatus();
  }

  // Load status on app start
  Future<void> _loadInitialStatus() async {
    final status = await LockStatusService.getStatus();
    isLocked = status.isLocked;
    lastPhotoPath = status.photoPath;
    lastTimestamp = status.timestamp;
    notifyListeners();
  }

  // Start lock session (take photo + save status)
  Future<void> startLockSession() async {
    final photoPath = await PhotoService.takeAndSavePhotoWithTimestamp();

    if (photoPath != null) {
      lastPhotoPath = photoPath;
      lastTimestamp = DateTime.now();
      isLocked = true;

      await LockStatusService.setLocked(photoPath);
      notifyListeners();
    }
  }

  // Unlock session manually
  Future<void> unlock() async {
    await LockStatusService.setUnlocked();
    isLocked = false;
    lastPhotoPath = null;
    lastTimestamp = null;
    notifyListeners();
  }

  // Clear all stored data
  Future<void> clearAllData() async {
    // Clear all stored data
    await unlock();
  }

  // Get current lock status (optional public getter)
  LockStatus get currentStatus => LockStatus(
        isLocked: isLocked,
        photoPath: lastPhotoPath,
        timestamp: lastTimestamp,
      );
}
