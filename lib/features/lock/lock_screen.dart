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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSecurity();
    });
  }

  Future<void> _initializeSecurity() async {
    final passcodeSet = await _authService.isPasscodeSet();
    final biometricEnabled = await _authService.isBiometricEnabled();

    if (!mounted) return;

    // If no security is configured, bypass the lock screen immediately
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
    if (!mounted) return;
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const CalendarPage(),
      ),
    );
  }

  // Authenticate using biometrics
  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    try {
      final isAuthenticated = await _localAuth.authenticate(
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
    final bool? unlocked = await showDialog<bool>(
      context: context,
      builder: (context) => _PasscodeDialog(authService: _authService),
    );

    if (unlocked == true && mounted) {
      _navigateToCalendar();
    }
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
                if (_isBiometricEnabled) ...[
                  FilledButton.icon(
                    onPressed: _isAuthenticating ? null : _authenticateWithBiometrics,
                    icon: const Icon(CupertinoIcons.viewfinder),
                    label: const Text("Unlock with Biometrics"),
                  ),
                  const SizedBox(height: 12),
                ],
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

/// Separate StatefulWidget ensures the controller lifecycle is tied to the dialog's
/// true unmount lifecycle, preventing "used after being disposed" errors.
class _PasscodeDialog extends StatefulWidget {
  final AuthService authService;

  const _PasscodeDialog({required this.authService});

  @override
  State<_PasscodeDialog> createState() => _PasscodeDialogState();
}

class _PasscodeDialogState extends State<_PasscodeDialog> {
  late final TextEditingController _passcodeController;
  bool _invalidPasscode = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _passcodeController = TextEditingController();
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    final entered = _passcodeController.text.trim();
    final isCorrect = await widget.authService.verifyPasscode(entered);

    if (!mounted) return;

    if (isCorrect) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _invalidPasscode = true;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Enter Passcode"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _passcodeController,
            obscureText: true,
            keyboardType: TextInputType.number,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            onChanged: (text) {
              if (_invalidPasscode && text.isNotEmpty) {
                setState(() => _invalidPasscode = false);
              }
            },
            decoration: const InputDecoration(
              hintText: "Passcode",
              border: OutlineInputBorder(),
            ),
          ),
          if (_invalidPasscode)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'Incorrect Password!',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: _isChecking ? null : _submit,
          child: _isChecking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("Unlock"),
        ),
      ],
    );
  }
}
