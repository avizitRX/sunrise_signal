import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sunrise_signal/features/calendar/calendar_page.dart';
import 'package:sunrise_signal/features/lock/lock_screen.dart';
import 'package:sunrise_signal/services/reminder_service.dart';
import 'package:sunrise_signal/services/theme_service.dart';
import 'models/sleep_model.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create ThemeService instance
  final themeService = ThemeService();
  await themeService.loadTheme();

  // Init Notifications
  ReminderService().initNotifications();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SleepModel()),
        ChangeNotifierProvider(create: (_) => themeService),
      ],
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
    return MaterialApp(
      title: 'Sunrise Signal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.dark,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.brown,
          surfaceTintColor: Colors.brown,
        ),
      ),
      themeMode: Provider.of<ThemeService>(context, listen: true).isDarkMode
          ? ThemeMode.dark
          : ThemeMode.light,
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
