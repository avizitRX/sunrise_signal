import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sunrise_signal/features/calendar/calendar_page.dart';
import 'package:sunrise_signal/features/lock/lock_screen.dart';
import 'models/sleep_model.dart';
import 'services/auth_service.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => SleepModel(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _shouldShowLockScreen() async {
    final authService = AuthService();
    final isPasscodeSet = await authService.isPasscodeSet();
    final isBiometricEnabled = await authService.isBiometricEnabled();
    return isPasscodeSet || isBiometricEnabled;
  }

  @override
  Widget build(BuildContext context) {
    AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelGroupKey: 'reminder_group',
          channelKey: 'reminder',
          channelName: 'Reminder',
          channelDescription: 'Notification channel for reminders',
          defaultColor: Colors.red,
          ledColor: Colors.white,
          playSound: false,
          enableVibration: false,
          enableLights: false,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
            channelGroupKey: 'reminder_group',
            channelGroupName: 'Reminder Group')
      ],
      debug: false,
    );

    return MaterialApp(
      title: 'Sunrise Signal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
        ),
      ),
      home: FutureBuilder<bool>(
        future: _shouldShowLockScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data == true) {
            return const LockScreenPage();
          } else {
            return const CalendarPage();
          }
        },
      ),
    );
  }
}
