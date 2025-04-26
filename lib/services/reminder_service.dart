import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class ReminderService {
  static const String _reminderKey = 'isReminderEnabled';
  static const _secureStorage = FlutterSecureStorage();

  // Initialization
  Future<void> initNotifications() async {
    // Timezone Initialization
    tz.initializeTimeZones();
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));

    // Notification Initialization
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    AndroidInitializationSettings initializationSettingsAndroid =
        const AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  // Notifications Detail Setup
  NotificationDetails notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminder_channel',
        'Daily Reminder',
        channelDescription: 'Daily reminder notifications',
        importance: Importance.low,
        priority: Priority.low,
      ),
    );
  }

  // Show notification
  // Future<void> showNotification({
  //   int id = 0,
  //   String title = 'Did you wake up with morning wood?',
  // }) async {
  //   return FlutterLocalNotificationsPlugin().show(
  //     0,
  //     title,
  //     null,
  //     _notificationDetails(),
  //   );
  // }

  // Schedule daily reminders
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    // Get the current date and time in device's local timezone
    final now = tz.TZDateTime.now(tz.local);

    // Schedule the notification
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    await FlutterLocalNotificationsPlugin().zonedSchedule(
      0,
      'Did you wake up with morning wood?',
      'Open the app to log your morning wood.',
      scheduledDate,
      notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Repeat Everyday
      matchDateTimeComponents: DateTimeComponents.time,
    );

    await _saveReminderState(true);
  }

  // Cancel all reminders
  static Future<void> cancelReminders() async {
    await FlutterLocalNotificationsPlugin().cancelAll();

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
