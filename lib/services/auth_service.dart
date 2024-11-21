import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> setPasscode(String passcode) async {
    await _secureStorage.write(key: 'passcode', value: passcode);
  }

  Future<String?> getPasscode() async {
    return await _secureStorage.read(key: 'passcode');
  }

  Future<void> removePasscode() async {
    await _secureStorage.delete(key: 'passcode');
  }

  Future<bool> isPasscodeSet() async {
    return await _secureStorage.containsKey(key: 'passcode');
  }

  Future<void> enableBiometricLock() async {
    await _secureStorage.write(key: 'biometricLock', value: 'enabled');
  }

  Future<void> disableBiometricLock() async {
    await _secureStorage.delete(key: 'biometricLock');
  }

  Future<bool> isBiometricEnabled() async {
    final value = await _secureStorage.read(key: 'biometricLock');
    return value == 'enabled';
  }
}
