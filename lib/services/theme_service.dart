import 'package:flutter/material.dart';
import 'package:sunrise_signal/services/secure_storage_service.dart';

class ThemeService extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  Future<void> loadTheme() async {
    final secureStorage = SecureStorageService();
    final value = await secureStorage.read(key: 'isDarkMode');
    if (value != null) {
      _isDarkMode = value.toLowerCase() == 'true';
    } else {
      // Default to light mode if no value is stored
      _isDarkMode = false;
    }
    notifyListeners();
  }

  void toggleDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();

    final secureStorage = SecureStorageService();
    await secureStorage.write(key: 'isDarkMode', value: isDarkMode.toString());
  }
}
