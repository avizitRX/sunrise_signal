import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:sunrise_signal/features/calendar/calendar_page.dart';

import '../../services/auth_service.dart';

class LockScreenPage extends StatefulWidget {
  const LockScreenPage({super.key});

  @override
  _LockScreenPageState createState() => _LockScreenPageState();
}

class _LockScreenPageState extends State<LockScreenPage> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isPasscodeSet = false;
  bool _isBiometricEnabled = false;

  String _storedPasscode = "";

  @override
  void initState() {
    super.initState();
    _loadPasscode();
    _checkBiometricAvailability();
  }

  // Load the passcode from secure storage
  Future<void> _loadPasscode() async {
    String? passcode = await _secureStorage.read(key: 'passcode');
    setState(() {
      _isPasscodeSet = passcode != null && passcode.isNotEmpty;
      _storedPasscode = passcode ?? "";
    });
  }

  // Check if biometric authentication is activated
  Future<void> _checkBiometricAvailability() async {
    final AuthService authService = AuthService();
    setState(() async {
      _isBiometricEnabled = await authService.isBiometricEnabled();
    });
  }

  // Function to authenticate using passcode
  Future<void> _authenticateWithPasscode() async {
    String enteredPasscode = "";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Passcode"),
        content: TextField(
          obscureText: true,
          decoration: const InputDecoration(hintText: "Passcode"),
          onChanged: (value) {
            enteredPasscode = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (enteredPasscode == _storedPasscode) {
                Navigator.pushAndRemoveUntil<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const CalendarPage(),
                  ),
                  (Route<dynamic> route) => false,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Incorrect passcode')));
              }
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // Function to authenticate using biometrics
  Future<void> _authenticateWithBiometrics() async {
    try {
      bool isAuthenticated = await _localAuth.authenticate(
        localizedReason: "Please authenticate to unlock",
        options: const AuthenticationOptions(stickyAuth: true),
      );

      if (isAuthenticated) {
        Navigator.pushAndRemoveUntil<void>(
          context,
          MaterialPageRoute<void>(
            builder: (BuildContext context) => const CalendarPage(),
          ),
          (Route<dynamic> route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric authentication failed')));
      }
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lock Screen"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isPasscodeSet)
              ElevatedButton(
                onPressed: _authenticateWithPasscode,
                child: const Text("Unlock with Passcode"),
              ),
            if (_isBiometricEnabled)
              ElevatedButton(
                onPressed: _authenticateWithBiometrics,
                child: const Text("Unlock with Biometrics"),
              ),
          ],
        ),
      ),
    );
  }
}
