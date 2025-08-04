import 'package:shared_preferences/shared_preferences.dart';
import '../models/lock_status.dart';

class LockStatusService {
  static const _lockedKey = 'door_locked';
  static const _timestampKey = 'lock_timestamp'; // TimeStamp over Photo
  static const _photoPathKey = 'lock_photo_path'; //Path to get the latest photo

  // Set door as locked
  static Future<void> setLocked(String photoPath) async{
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockedKey, true);
    await prefs.setString(_timestampKey, DateTime.now().toIso8601String());
    await prefs.setString(_photoPathKey, photoPath);
  }

  // Set door as unlocked (pornirea aplicatiei)
  static Future<void> setUnlocked() async{

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockedKey, false);
    await prefs.remove(_timestampKey);
    await prefs.remove(_photoPathKey);
  }

  // Return Current Status
  static Future<LockStatus> getStatus() async{
    final prefs = await SharedPreferences.getInstance();
    final isLocked = prefs.getBool(_lockedKey) ?? false;
    final photoPath = prefs.getString(_photoPathKey);
    final timestampStr = prefs.getString(_timestampKey);
    DateTime? timestamp;
    if (timestampStr != null){
      timestamp = DateTime.tryParse(timestampStr);
    }

    return LockStatus(
      isLocked: isLocked,
      photoPath: photoPath,
      timestamp: timestamp,

    );
  }
}