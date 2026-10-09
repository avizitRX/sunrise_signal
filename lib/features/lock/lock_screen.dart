import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sunrise_signal/features/calendar/calendar_page.dart';

import '../../services/auth_service.dart';

class LockScreenPage extends StatefulWidget {
  const LockScreenPage({super.key});

  @override
  LockScreenPageState createState() => LockScreenPageState();
}

class LockScreenPageState extends State<LockScreenPage> {
  final AuthService _authService = AuthService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isPasscodeSet = false;
  bool _isBiometricEnabled = false;
  bool _isLoading = true;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    // Ensure the first frame renders before initiating auth checks
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSecurity();
    });
  }

  Future<void> _initializeSecurity() async {
    final passcodeSet = await _authService.isPasscodeSet();
    final biometricEnabled = await _authService.isBiometricEnabled();

    if (!mounted) return;

    // If no security is configured, bypass the lock screen entirely
    if (!passcodeSet && !biometricEnabled) {
      _navigateToCalendar();
      return;
    }

    setState(() {
      _isPasscodeSet = passcodeSet;
      _isBiometricEnabled = biometricEnabled;
      _isLoading = false;
    });

    // Automatically prompt for biometrics if enabled
    if (_isBiometricEnabled) {
      _authenticateWithBiometrics();
    }
  }

  void _navigateToCalendar() {
    Navigator.pushAndRemoveUntil<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const CalendarPage(),
      ),
      (Route<dynamic> route) => false,
    );
  }

  // Authenticate using biometrics
  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    try {
      bool isAuthenticated = await _localAuth.authenticate(
        localizedReason: "Authenticate to unlock Sunrise Signal",
      );

      if (!mounted) return;

      if (isAuthenticated) {
        _navigateToCalendar();
      }
    } on PlatformException catch (e) {
      debugPrint('Biometric error: $e');
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  // Authenticate using passcode
  Future<void> _authenticateWithPasscode() async {
    final passcodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Passcode"),
        content: TextField(
          controller: passcodeController,
          obscureText: true,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Passcode",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final entered = passcodeController.text.trim();
              final isCorrect = await _authService.verifyPasscode(entered);

              if (!context.mounted) return;

              if (isCorrect) {
                Navigator.pop(context); // Close dialog
                _navigateToCalendar();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Incorrect passcode'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text("Unlock"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC),
        body: const Center(child: CupertinoActivityIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Shield Badge
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.lock_shield_fill,
                    size: 60,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Sunrise Signal Locked',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Authenticate to access your morning records.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 36),

                // Biometrics Button (if available)
                if (_isBiometricEnabled) ...[
                  FilledButton.icon(
                    onPressed: _isAuthenticating ? null : _authenticateWithBiometrics,
                    icon: const Icon(CupertinoIcons.viewfinder),
                    label: const Text("Unlock with Biometrics"),
                  ),
                  const SizedBox(height: 12),
                ],

                // Passcode Option
                if (_isPasscodeSet)
                  OutlinedButton.icon(
                    onPressed: _authenticateWithPasscode,
                    icon: const Icon(CupertinoIcons.padlock_solid),
                    label: const Text("Enter Passcode"),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
