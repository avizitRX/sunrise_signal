import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
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
  bool _isBiometricEnabled = false;
  bool _isReminderEnabled = false;
  TimeOfDay? _reminderTime;

  final AuthService _authService = AuthService();
  final SecureStorageService _storageService = SecureStorageService();
  Map<DateTime, LogModel> _logs = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
    if (value) {
      await _enableBiometricLock();
    } else {
      await _authService.disableBiometricLock();
      setState(() {
        _isBiometricEnabled = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric lock disabled.')),
      );
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
      const SnackBar(content: Text('Biometric lock enabled successfully!')),
    );
  }

  Future<void> _exportLogs() async {
    AndroidDeviceInfo build = await DeviceInfoPlugin().androidInfo;
    PermissionStatus permissionStatus;

    // Request storage permission
    if (build.version.sdkInt >= 30) {
      permissionStatus = await Permission.manageExternalStorage.request();
    } else {
      permissionStatus = await Permission.storage.request();
    }

    if (permissionStatus.isGranted) {
      try {
        // Access the Downloads folder
        final directory = Directory('/storage/emulated/0/Download');

        // Ensure the directory exists
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }

        // Create the file path
        final filePath = '${directory.path}/sunrise_signal_data_export.json';

        // Write the logs to the file
        final file = File(filePath);
        final logsJson = jsonEncode(
          _logs.map(
              (key, value) => MapEntry(key.toIso8601String(), value.toMap())),
        );
        await file.writeAsString(logsJson);

        // Notify the user of success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Logs exported successfully! File saved in Downloads folder.'),
          ),
        );
      } catch (e) {
        // Notify the user of any errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export logs: $e')),
        );
      }
    } else {
      // Notify the user if permission is denied
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Storage permission is required to export logs.'),
        ),
      );
    }
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
          ListTile(
            title: const Text('Enable Biometric Lock'),
            trailing: Switch(
              value: _isBiometricEnabled,
              onChanged: _toggleBiometric,
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
        ],
      ),
    );
  }
}
