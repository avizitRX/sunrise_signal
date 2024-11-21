import 'package:flutter/material.dart';

class SleepModel extends ChangeNotifier {
  double _sleepHours = 6.0;

  double get sleepHours => _sleepHours;

  set sleepHours(double value) {
    _sleepHours = value;
    notifyListeners();
  }
}
