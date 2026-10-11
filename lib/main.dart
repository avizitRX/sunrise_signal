import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sunrise_signal/features/lock/lock_screen.dart';
import 'package:sunrise_signal/models/sleep_model.dart';
import 'package:sunrise_signal/providers/log_provider.dart';
import 'package:sunrise_signal/providers/providers/settings_provider.dart';
import 'package:sunrise_signal/services/reminder_service.dart';
import 'package:sunrise_signal/services/theme_service.dart';
import 'package:sunrise_signal/theme/app_theme.dart';

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
        ChangeNotifierProvider(create: (_) => LogProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeService>(context).isDarkMode;

    return MaterialApp(
      title: 'Sunrise Signal',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const LockScreenPage(),
    );
  }
}
