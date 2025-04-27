import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_auth/local_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:sunrise_signal/services/theme_service.dart';
import '../../services/auth_service.dart';
import '../../services/reminder_service.dart';
import '../../services/secure_storage_service.dart';
import '../../models/log_model.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isPasscodeSet = false;
  bool _hasBiometrics = false;
  bool _isBiometricEnabled = false;
  bool _isReminderEnabled = false;
  TimeOfDay? _reminderTime;
  bool _isAuthenticating = false;

  final AuthService _authService = AuthService();
  final SecureStorageService _storageService = SecureStorageService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  Map<DateTime, LogModel> _logs = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBiometrics();
    _loadLogs();
  }

  Future<void> _loadSettings() async {
    final passcodeSet = await _authService.isPasscodeSet();
    final biometricEnabled = await _authService.isBiometricEnabled();
    final reminderEnabled = await ReminderService.isReminderEnabled();
    final reminderTime = await ReminderService.getReminderTime();
    setState(() {
      _isPasscodeSet = passcodeSet;
      _isBiometricEnabled = biometricEnabled;
      _isReminderEnabled = reminderEnabled;
      _reminderTime = reminderTime;
    });
  }

  Future<void> _checkBiometrics() async {
    bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
    bool isDeviceSupported = await _localAuth.isDeviceSupported();
    if (mounted) {
      setState(() {
        _hasBiometrics = canCheckBiometrics && isDeviceSupported;
      });
    }
  }

  Future<void> _loadLogs() async {
    final logs = await _storageService.loadLogs();
    setState(() {
      _logs = logs;
    });
  }

  Future<void> _togglePasscode(bool value) async {
    if (value) {
      await showSetPasscodeDialog(context);
    } else {
      await _authService.removePasscode();
      setState(() {
        _isPasscodeSet = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passcode removed successfully!')),
      );
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
    });

    bool authenticated = false;
    try {
      authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate using your device lock to continue',
        options: const AuthenticationOptions(biometricOnly: true),
      );
    } catch (e) {
      print('Authentication error: $e');
    }

    if (!mounted) {
      setState(() {
        _isAuthenticating = false;
      });
      return;
    }

    if (authenticated) {
      if (value) {
        await _enableBiometricLock();
        setState(() {
          _isAuthenticating = false;
        });
      } else {
        await _authService.disableBiometricLock();
        setState(() {
          _isBiometricEnabled = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disabled Biometric/Device Lock!')),
        );
        setState(() {
          _isAuthenticating = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication failed')),
      );
      setState(() {
        _isAuthenticating = false;
      });
    }
  }

  Future<bool> _requestNotificationPermission() async {
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    bool? notificationPermission = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    if (notificationPermission == null || !notificationPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Notification permission is required to enable reminders.'),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _toggleReminder(bool value) async {
    if (value) {
      await _pickTimeAndSetReminder();
    } else {
      await ReminderService.cancelReminders();
      setState(() {
        _isReminderEnabled = false;
        _reminderTime = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily reminder disabled.')),
      );
    }
  }

  Future<void> _pickTimeAndSetReminder() async {
    bool permissionGranted = await _requestNotificationPermission();
    if (!permissionGranted) return; // Stop if no permission

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? TimeOfDay.now(),
    );

    if (pickedTime != null) {
      setState(() {
        _reminderTime = pickedTime;
      });
      await ReminderService().scheduleDailyReminder(
        hour: pickedTime.hour,
        minute: pickedTime.minute,
      );
      setState(() {
        _isReminderEnabled = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily reminder set!')),
      );
    }
  }

  Future<void> showSetPasscodeDialog(BuildContext context) async {
    final TextEditingController passcodeController = TextEditingController();
    final TextEditingController confirmPasscodeController =
        TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Passcode'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passcodeController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Enter Passcode',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmPasscodeController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Passcode',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final String passcode = passcodeController.text.trim();
                final String confirmPasscode =
                    confirmPasscodeController.text.trim();

                if (passcode.isEmpty || confirmPasscode.isEmpty) {
                  _showErrorDialog(context, 'Passcode cannot be blank.');
                  return;
                }

                if (passcode != confirmPasscode) {
                  _showErrorDialog(context, 'Passcodes do not match.');
                  return;
                }

                await _authService.setPasscode(passcode);
                setState(() {
                  _isPasscodeSet = true;
                });

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passcode set successfully!')),
                );
              },
              child: const Text('Set Passcode'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _enableBiometricLock() async {
    await _authService.enableBiometricLock();
    setState(() {
      _isBiometricEnabled = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enabled Biometric/Device Lock!')),
    );
  }

  Future<void> _exportLogs() async {
    bool hasUserAborted = true;
    String? pickedSaveFilePath;

    try {
      // Prepare logs into bytes
      final logsJson = jsonEncode(
        _logs.map(
          (key, value) => MapEntry(key.toIso8601String(), value.toMap()),
        ),
      );
      final Uint8List logsBytes = Uint8List.fromList(utf8.encode(logsJson));

      // Show "Save As" dialog
      pickedSaveFilePath = await FilePicker.platform.saveFile(
        allowedExtensions: ['json'],
        type: FileType.custom,
        dialogTitle: 'Export your logs',
        fileName: 'sunrise_signal_data_export.json',
        bytes: logsBytes,
      );

      hasUserAborted = pickedSaveFilePath == null;
    } on PlatformException catch (e) {
      _logException('Unsupported operation: $e');
    } catch (e) {
      _logException('Error: $e');
    }

    if (!mounted) return;

    if (hasUserAborted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export cancelled.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs exported successfully!')),
      );
    }
  }

  void _logException(String message) {
    debugPrint('Exception: $message');
  }

  Future<void> _importLogs() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final Map<String, dynamic> decodedLogs = jsonDecode(content);
      final importedLogs = decodedLogs.map((key, value) => MapEntry(
            DateTime.parse(key),
            LogModel.fromMap(value),
          ));
      setState(() {
        _logs = importedLogs;
      });
      await _storageService.saveLogs(_logs);

      showImportSuccessDialog(context);
    }
  }

  void showImportSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: const Text('Your data has been imported successfully!'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                SystemNavigator.pop();
              },
              child: const Text('Restart App'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int flag = 0;
    bool locked = true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: const Text('Daily Reminder'),
            subtitle: Text(
              _isReminderEnabled && _reminderTime != null
                  ? _reminderTime!.format(context)
                  : 'Off',
            ),
            trailing: Switch(
              value: _isReminderEnabled,
              onChanged: (value) async {
                if (value) {
                  await _pickTimeAndSetReminder();
                } else {
                  await _toggleReminder(false);
                }
              },
            ),
            onTap: () async {
              if (!_isReminderEnabled) {
                await _pickTimeAndSetReminder();
              }
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Enable Passcode Lock'),
            trailing: Switch(
              value: _isPasscodeSet,
              onChanged: _togglePasscode,
            ),
          ),
          if (_hasBiometrics)
            ListTile(
              title: const Text('Enable Biometric/Device Lock'),
              trailing: Switch(
                value: _isBiometricEnabled,
                onChanged: _toggleBiometric,
              ),
            ),
          const Divider(),
          ListTile(
            title: const Text('Dark Theme'),
            trailing: Consumer<ThemeService>(
              builder: (context, themeService, _) => Switch(
                value: themeService.isDarkMode,
                onChanged: (value) {
                  themeService.toggleDarkMode(value);
                },
              ),
            ),
          ),
          const Divider(),
          ListTile(
            title: GestureDetector(
              onTap: _exportLogs,
              child: const Text('Export Data', style: TextStyle(fontSize: 16)),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportLogs,
            ),
          ),
          ListTile(
            title: GestureDetector(
              onTap: _importLogs,
              child: const Text('Import Data', style: TextStyle(fontSize: 16)),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.upload),
              onPressed: _importLogs,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              if (flag > 8) {
                locked = false;
              }
              flag++;
            },
            onLongPress: () {
              if (!locked) {
                showDialog<String>(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    content: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Developed by Avizit Roy\nWebsite: avizitRX.com',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'Close'),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }
            },
            child: const Center(
              child: Text('Sunrise Signal v2.0.0'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
