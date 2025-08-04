import 'package:shared_preferences/shared_preferences.dart';

class ReminderService {
  static const String _reminderKey = 'door_lock_reminder';
  static const String _lastReminderKey = 'last_reminder_time';

  // Set reminder enabled/disabled
  static Future<void> setReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reminderKey, enabled);
  }

  // Check if reminder is enabled
  static Future<bool> isReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_reminderKey) ?? false;
  }

  // Set last reminder time
  static Future<void> setLastReminderTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastReminderKey, time.toIso8601String());
  }

  // Get last reminder time
  static Future<DateTime?> getLastReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_lastReminderKey);
    if (timeStr != null) {
      return DateTime.tryParse(timeStr);
    }
    return null;
  }

  // Check if reminder should be shown (based on time elapsed)
  static Future<bool> shouldShowReminder() async {
    final isEnabled = await isReminderEnabled();
    if (!isEnabled) return false;

    final lastTime = await getLastReminderTime();
    if (lastTime == null) return true;

    final now = DateTime.now();
    final difference = now.difference(lastTime);
    
    // Show reminder if more than 4 hours have passed
    return difference.inHours >= 4;
  }
}