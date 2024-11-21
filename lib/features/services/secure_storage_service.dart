import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sunrise_signal/models/log_model.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Load logs from secure storage
  Future<Map<DateTime, LogModel>> loadLogs() async {
    final logsJson = await _storage.read(key: 'logs');
    if (logsJson == null || logsJson.isEmpty) {
      return {}; // No logs stored
    }

    final Map<String, dynamic> decodedLogs = jsonDecode(logsJson);
    return decodedLogs.map((key, value) {
      final date = DateTime.parse(key);
      final logModel = LogModel.fromMap(Map<String, dynamic>.from(value));
      return MapEntry(date, logModel);
    });
  }

  // Save logs to secure storage
  Future<void> saveLogs(Map<DateTime, LogModel> logs) async {
    final logsJson = jsonEncode(
      logs.map((key, value) => MapEntry(key.toIso8601String(), value.toMap())),
    );
    await _storage.write(key: 'logs', value: logsJson);
  }
}
