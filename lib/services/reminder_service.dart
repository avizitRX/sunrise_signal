import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ReminderService {
  static const String _reminderKey = 'isReminderEnabled';
  static const String _reminderHourKey = 'reminderHour';
  static const String _reminderMinuteKey = 'reminderMinute';
  static const _secureStorage = FlutterSecureStorage();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialization
  Future<void> initNotifications() async {
    tz.initializeTimeZones();

    // 1. Receive the TimezoneInfo object
    final TimezoneInfo timezoneInfo = await FlutterTimezone.getLocalTimezone();

    // 2. Extract the String name to pass into tz.getLocation()
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    // Note: If `.name` isn't available on your object, try `timezoneInfo.identifier` or `timezoneInfo.toString()`
  }

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

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: 0,
      title: 'Did you wake up with morning wood?',
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    await _saveReminderState(true);
    await _saveReminderTime(hour, minute);
  }

  static Future<void> cancelReminders() async {
    await FlutterLocalNotificationsPlugin().cancelAll();
    await _saveReminderState(false);
    await _deleteReminderTime();
  }

  static Future<void> _saveReminderState(bool isEnabled) async {
    await _secureStorage.write(
      key: _reminderKey,
      value: isEnabled.toString(),
    );
  }

  static Future<void> _saveReminderTime(int hour, int minute) async {
    await _secureStorage.write(key: _reminderHourKey, value: hour.toString());
    await _secureStorage.write(key: _reminderMinuteKey, value: minute.toString());
  }

  static Future<void> _deleteReminderTime() async {
    await _secureStorage.delete(key: _reminderHourKey);
    await _secureStorage.delete(key: _reminderMinuteKey);
  }

  static Future<bool> isReminderEnabled() async {
    final state = await _secureStorage.read(key: _reminderKey);
    return state == 'true';
  }

  static Future<TimeOfDay?> getReminderTime() async {
    final hourStr = await _secureStorage.read(key: _reminderHourKey);
    final minuteStr = await _secureStorage.read(key: _reminderMinuteKey);

    if (hourStr != null && minuteStr != null) {
      return TimeOfDay(
        hour: int.parse(hourStr),
        minute: int.parse(minuteStr),
      );
    }
    return null;
  }
}
