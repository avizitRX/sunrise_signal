import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/log_model.dart';
import '../../services/auth_service.dart';
import '../../services/secure_storage_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isPasscodeSet = false;
  bool _isBiometricEnabled = false;
  final AuthService _authService = AuthService();
  final SecureStorageService _storageService = SecureStorageService();
  Map<DateTime, LogModel> _logs = {};

  @override
  void initState() {
    super.initState();
    _loadLockStatus();
    _loadLogs();
  }

  Future<void> _loadLockStatus() async {
    final passcodeSet = await _authService.isPasscodeSet();
    final biometricEnabled = await _authService.isBiometricEnabled();
    setState(() {
      _isPasscodeSet = passcodeSet;
      _isBiometricEnabled = biometricEnabled;
    });
  }

  Future<void> _loadLogs() async {
    final logs = await _storageService.loadLogs();
    setState(() {
      _logs = logs;
    });
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
                Navigator.pop(context); // Close the dialog without saving
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

                // Save the passcode securely
                await _authService.setPasscode(passcode);

                // Update state
                setState(() {
                  _isPasscodeSet = true;
                });

                // Close the dialog
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

  Future<void> _removeLock() async {
    await _authService.removePasscode();
    await _authService.disableBiometricLock();
    setState(() {
      _isPasscodeSet = false;
      _isBiometricEnabled = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App lock removed successfully!')),
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
        final directory = Directory(
            '/storage/emulated/0/Download'); // Path to Downloads folder

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
                  'Logs exported successfully! File saved in Downloads folder.')),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs imported successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'App Lock',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: !_isPasscodeSet
                    ? () => showSetPasscodeDialog(context)
                    : null,
                child: const Text('Set Passcode'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: !_isBiometricEnabled
                    ? () async {
                        await _enableBiometricLock();
                      }
                    : null,
                child: const Text('Enable Biometric Lock'),
              ),
              const SizedBox(height: 16),
              if (_isPasscodeSet || _isBiometricEnabled)
                ElevatedButton(
                  onPressed: _removeLock,
                  child: const Text('Remove App Lock'),
                ),
              const SizedBox(height: 22),
              const Text(
                'Backup & Restore',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Export Data'),
                onPressed: _exportLogs,
              ),
              const SizedBox(
                height: 16,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload),
                label: const Text('Import Data'),
                onPressed: _importLogs,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
