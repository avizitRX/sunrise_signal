import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ReminderService {
  static const String _reminderKey = 'isReminderEnabled';
  static const _secureStorage = FlutterSecureStorage();

  // Schedule daily reminders
  static Future<void> scheduleDailyReminder() async {
    await _saveReminderState(true);
  }

  // Cancel all reminders
  static Future<void> cancelReminders() async {
    await _saveReminderState(false);
  }

  // Save the reminder state in secure storage
  static Future<void> _saveReminderState(bool isEnabled) async {
    await _secureStorage.write(
      key: _reminderKey,
      value: isEnabled.toString(),
    );
  }

  // Check if the reminder is enabled
  static Future<bool> isReminderEnabled() async {
    final state = await _secureStorage.read(key: _reminderKey);
    return state == 'true';
  }
}
