import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sunrise_signal/features/calendar/calendar_page.dart';
import 'models/sleep_model.dart';

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sunrise Signal',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: const CalendarPage(),
    );
  }
}
