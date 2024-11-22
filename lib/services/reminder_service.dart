import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ReminderService {
  static const String _reminderKey = 'isReminderEnabled';
  static const _secureStorage = FlutterSecureStorage();

  // Schedule daily reminders
  static Future<void> scheduleDailyReminder() async {
    String localTimeZone =
        await AwesomeNotifications().getLocalTimeZoneIdentifier();

    AwesomeNotifications().isNotificationAllowed().then(
      (isAllowed) {
        if (!isAllowed) {
          AwesomeNotifications().requestPermissionToSendNotifications();
        }
      },
    );

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 1,
        channelKey: 'reminder',
        title: 'Did you wake up with morning wood?',
        wakeUpScreen: false,
        category: NotificationCategory.Reminder,
        autoDismissible: false,
      ),
      schedule: NotificationCalendar(
        allowWhileIdle: true,
        preciseAlarm: true,
        hour: 5,
        minute: 0,
        second: 0,
        millisecond: 0,
        repeats: true,
        timeZone: localTimeZone,
      ),
    );

    await _saveReminderState(true);
  }

  // Cancel all reminders
  static Future<void> cancelReminders() async {
    await AwesomeNotifications().cancelAllSchedules();

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
