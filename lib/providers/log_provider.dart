import 'package:flutter/foundation.dart';

import '../models/log_model.dart';
import '../services/secure_storage_service.dart';

class LogProvider extends ChangeNotifier {
  final SecureStorageService _storageService = SecureStorageService();
  Map<DateTime, LogModel> _logs = {};
  bool _isLoading = true;

  Map<DateTime, LogModel> get logs => _logs;
  bool get isLoading => _isLoading;

  LogProvider() {
    loadLogs();
  }

  DateTime _normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

  Future<void> loadLogs() async {
    _isLoading = true;
    notifyListeners();
    _logs = await _storageService.loadLogs();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveLog(
    DateTime date, {
    required String emoji,
    required double sleep,
    String? stress,
    String? exercise,
    String? alcoholIntake,
    String? caffeineIntake,
    String? sexualActivity,
  }) async {
    final normalized = _normalizeDate(date);
    _logs[normalized] = LogModel(
      emoji: emoji,
      sleepHours: sleep,
      stressLevel: stress,
      exercise: exercise,
      alcoholIntake: alcoholIntake,
      caffeineIntake: caffeineIntake,
      sexualActivity: sexualActivity,
    );

    await _storageService.saveLogs(_logs);
    notifyListeners(); // Updates Calendar and Analytics everywhere!
  }

  Future<void> removeLog(DateTime date) async {
    final normalized = _normalizeDate(date);
    _logs.remove(normalized);
    await _storageService.saveLogs(_logs);
    notifyListeners(); // Instantly updates Calendar and Analytics!
  }

  LogModel? getLogForDate(DateTime date) {
    return _logs[_normalizeDate(date)];
  }
}
