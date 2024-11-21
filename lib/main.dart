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
  const MyApp({Key? key}) : super(key: key);

  Future<bool> _shouldShowLockScreen() async {
    final authService = AuthService();
    final isPasscodeSet = await authService.isPasscodeSet();
    final isBiometricEnabled = await authService.isBiometricEnabled();
    return isPasscodeSet || isBiometricEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Lock Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: FutureBuilder<bool>(
        future: _shouldShowLockScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data == true) {
            return const LockScreenPage();
          } else {
            return const CalendarPage(); // Your main page after unlocking
          }
        },
      ),
    );
  }
}
