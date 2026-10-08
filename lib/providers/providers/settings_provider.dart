import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

class SettingsProvider extends ChangeNotifier {
  String _firstDayOfWeek = 'Monday';

  String get firstDayOfWeek => _firstDayOfWeek;

  StartingDayOfWeek get startingDayOfWeek {
    switch (_firstDayOfWeek) {
      case 'Sunday':
        return StartingDayOfWeek.sunday;
      case 'Saturday':
        return StartingDayOfWeek.saturday;
      case 'Monday':
      default:
        return StartingDayOfWeek.monday;
    }
  }

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _firstDayOfWeek = prefs.getString('first_day_of_week') ?? 'Monday';
    notifyListeners();
  }

  Future<void> setFirstDayOfWeek(String day) async {
    _firstDayOfWeek = day;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('first_day_of_week', day);
    notifyListeners(); // Instantly reorders columns in TableCalendar!
  }
}
