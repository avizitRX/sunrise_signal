import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunrise_signal/providers/providers/settings_provider.dart';

import '../../models/log_model.dart';
import '../../providers/log_provider.dart';
import '../../services/auth_service.dart';
import '../../services/reminder_service.dart';
import '../../services/secure_storage_service.dart';
import '../../services/theme_service.dart';

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
  String _selectedWeekend = 'Sat & Sun'; // Default weekend setting

  final AuthService _authService = AuthService();
  final SecureStorageService _storageService = SecureStorageService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  int _easterEggCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBiometrics();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final passcodeSet = await _authService.isPasscodeSet();
    final biometricEnabled = await _authService.isBiometricEnabled();
    final reminderEnabled = await ReminderService.isReminderEnabled();
    final reminderTime = await ReminderService.getReminderTime();
    final savedWeekend = prefs.getString('weekend_mode') ?? 'Sat & Sun';

    if (mounted) {
      setState(() {
        _isPasscodeSet = passcodeSet;
        _isBiometricEnabled = biometricEnabled;
        _isReminderEnabled = reminderEnabled;
        _reminderTime = reminderTime;
        _selectedWeekend = savedWeekend;
      });
    }
  }

  Future<void> _checkBiometrics() async {
    bool canCheck = await _localAuth.canCheckBiometrics;
    bool isSupported = await _localAuth.isDeviceSupported();
    if (mounted) {
      setState(() {
        _hasBiometrics = canCheck && isSupported;
      });
    }
  }

  // --- BIOMETRIC TOGGLE (Guards BOTH ON and OFF) ---
  Future<void> _toggleBiometric(bool value) async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    bool authenticated = false;
    try {
      authenticated = await _localAuth.authenticate(
        localizedReason: value
            ? 'Authenticate to enable biometric protection'
            : 'Authenticate to disable biometric protection',
      );
    } catch (e) {
      debugPrint('Biometric Error: $e');
    }

    if (!mounted) return;

    if (authenticated) {
      HapticFeedback.lightImpact();
      if (value) {
        await _authService.enableBiometricLock();
        setState(() => _isBiometricEnabled = true);
        _showToast('Biometric lock enabled');
      } else {
        await _authService.disableBiometricLock();
        setState(() => _isBiometricEnabled = false);
        _showToast('Biometric lock removed');
      }
    } else {
      HapticFeedback.mediumImpact();
      _showToast('Authentication cancelled');
    }

    setState(() => _isAuthenticating = false);
  }

  // --- PASSCODE ---
  Future<void> _togglePasscode(bool value) async {
    if (value) {
      await showSetPasscodeDialog(context);
    } else {
      await _authService.removePasscode();
      setState(() => _isPasscodeSet = false);
      _showToast('Passcode removed');
    }
  }

  // --- REMINDERS ---
  Future<void> _toggleReminder(bool value) async {
    if (value) {
      await _pickTimeAndSetReminder();
    } else {
      await ReminderService.cancelReminders();
      setState(() {
        _isReminderEnabled = false;
        _reminderTime = null;
      });
      _showToast('Daily reminders turned off');
    }
  }

  Future<void> _pickTimeAndSetReminder() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 7, minute: 30),
    );

    if (pickedTime != null) {
      setState(() {
        _reminderTime = pickedTime;
        _isReminderEnabled = true;
      });
      await ReminderService().scheduleDailyReminder(
        hour: pickedTime.hour,
        minute: pickedTime.minute,
      );
      _showToast('Reminder set for ${pickedTime.format(context)}');
    }
  }

  // --- BACKUP & RESTORE ---
  Future<void> _exportLogs() async {
    final logProvider = Provider.of<LogProvider>(context, listen: false);
    final logs = logProvider.logs;

    if (logs.isEmpty) {
      _showToast('No logs available to export');
      return;
    }

    try {
      final logsJson = jsonEncode(
        logs.map((k, v) => MapEntry(k.toIso8601String(), v.toMap())),
      );
      final bytes = Uint8List.fromList(utf8.encode(logsJson));

      await FilePicker.saveFile(
        allowedExtensions: ['json'],
        type: FileType.custom,
        fileName: 'sunrise_signal_backup.json',
        bytes: bytes,
      );
      _showToast('Data exported successfully');
    } catch (e) {
      _showToast('Export cancelled');
    }
  }

  Future<void> _importLogs() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result.single.path != null) {
      try {
        final file = File(result.single.path!);
        final content = await file.readAsString();
        final Map<String, dynamic> decoded = jsonDecode(content);

        final imported = decoded.map((k, v) => MapEntry(
              DateTime.parse(k),
              LogModel.fromMap(v),
            ));

        await _storageService.saveLogs(imported);

        if (!mounted) return;
        await Provider.of<LogProvider>(context, listen: false).loadLogs();
        _showToast('All logs restored successfully!');
      } catch (e) {
        _showToast('Invalid backup file');
      }
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. ROUTINE & NOTIFICATIONS
          _buildSectionHeader('ROUTINE & TIMING'),
          _buildGroupContainer(
            isDark: isDark,
            children: [
              _buildSettingTile(
                icon: CupertinoIcons.bell_fill,
                iconColor: const Color(0xFFF59E0B),
                title: 'Daily Check-in Reminder',
                subtitle: _isReminderEnabled && _reminderTime != null
                    ? _reminderTime!.format(context)
                    : 'Off',
                trailing: CupertinoSwitch(
                  value: _isReminderEnabled,
                  activeTrackColor: theme.colorScheme.primary,
                  onChanged: _toggleReminder,
                ),
                onTap: () => _pickTimeAndSetReminder(),
              ),
              _buildDivider(isDark),
              _buildSettingTile(
                icon: CupertinoIcons.calendar,
                iconColor: const Color(0xFF38BDF8),
                title: 'First Day of Week',
                subtitle: Provider.of<SettingsProvider>(context).firstDayOfWeek,
                trailing: const Icon(CupertinoIcons.chevron_forward, size: 16),
                onTap: () => _showFirstDayPicker(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. PRIVACY & SECURITY
          _buildSectionHeader('PRIVACY & SECURITY'),
          _buildGroupContainer(
            isDark: isDark,
            children: [
              _buildSettingTile(
                icon: CupertinoIcons.lock_shield_fill,
                iconColor: theme.colorScheme.primary,
                title: 'Passcode Lock',
                subtitle: _isPasscodeSet ? 'Enabled' : 'Disabled',
                trailing: CupertinoSwitch(
                  value: _isPasscodeSet,
                  activeTrackColor: theme.colorScheme.primary,
                  onChanged: _togglePasscode,
                ),
              ),
              if (_hasBiometrics) ...[
                _buildDivider(isDark),
                _buildSettingTile(
                  icon: CupertinoIcons.viewfinder,
                  iconColor: const Color(0xFF10B981),
                  title: 'Biometric / Face ID',
                  subtitle: _isBiometricEnabled ? 'Required to unlock' : 'Disabled',
                  trailing: CupertinoSwitch(
                    value: _isBiometricEnabled,
                    activeTrackColor: theme.colorScheme.primary,
                    onChanged: _toggleBiometric,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // 3. APPEARANCE
          _buildSectionHeader('APPEARANCE'),
          _buildGroupContainer(
            isDark: isDark,
            children: [
              Consumer<ThemeService>(
                builder: (context, themeService, _) => _buildSettingTile(
                  icon: isDark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
                  iconColor: const Color(0xFFA855F7),
                  title: 'Dark Theme',
                  subtitle: themeService.isDarkMode ? 'Midnight Slate' : 'Morning Light',
                  trailing: CupertinoSwitch(
                    value: themeService.isDarkMode,
                    activeTrackColor: theme.colorScheme.primary,
                    onChanged: (val) => themeService.toggleDarkMode(val),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4. DATA MANAGEMENT
          _buildSectionHeader('DATA MANAGEMENT'),
          _buildGroupContainer(
            isDark: isDark,
            children: [
              _buildSettingTile(
                icon: CupertinoIcons.arrow_down_doc_fill,
                iconColor: const Color(0xFF0EA5E9),
                title: 'Export Backup',
                subtitle: 'Save records as a JSON file',
                trailing: const Icon(CupertinoIcons.chevron_forward, size: 16),
                onTap: _exportLogs,
              ),
              _buildDivider(isDark),
              _buildSettingTile(
                icon: CupertinoIcons.arrow_up_doc_fill,
                iconColor: const Color(0xFF10B981),
                title: 'Restore Data',
                subtitle: 'Import previous JSON logs',
                trailing: const Icon(CupertinoIcons.chevron_forward, size: 16),
                onTap: _importLogs,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Easter Egg & App Version
          Center(
            child: GestureDetector(
              onTap: () {
                _easterEggCount++;
                if (_easterEggCount == 7) {
                  HapticFeedback.heavyImpact();
                  _showAboutDialog();
                  _easterEggCount = 0;
                }
              },
              child: Text(
                'Sunrise Signal v2.2.0',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- WEEKEND SCHEDULE DIALOG ---
  void _showFirstDayPicker(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final options = ['Monday', 'Sunday', 'Saturday'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'First Day of Week',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose which day your calendar columns begin with.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ...options.map((opt) {
                  final isSelected = opt == settingsProvider.firstDayOfWeek;
                  return ListTile(
                    title: Text(opt, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: isSelected
                        ? Icon(CupertinoIcons.checkmark_alt,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () async {
                      await settingsProvider.setFirstDayOfWeek(opt);
                      HapticFeedback.selectionClick();
                      if (context.mounted) Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sunrise Signal'),
        content: const Text(
          'Engineered for men\'s morning health & longevity tracking.\n\nCrafted by Avizit Roy\navizitRX.com',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // --- UI BUILDER HELPERS ---
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildGroupContainer({
    required bool isDark,
    required List<Widget> children,
  }) {
    final cardColor = isDark ? const Color(0xFF161F2E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF263346) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17), // Keeps ripple cleanly inside the border
        child: Material(
          color: cardColor, // Establishes the true ink canvas
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      onTap: onTap,
      splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      hoverColor:
          isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
      trailing: trailing,
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 52,
      color: isDark ? const Color(0xFF263346) : const Color(0xFFF1F5F9),
    );
  }

  Future<void> showSetPasscodeDialog(BuildContext context) async {
    final codeCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Set Passcode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Enter Passcode'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Confirm Passcode'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (codeCtrl.text.isEmpty || codeCtrl.text != confirmCtrl.text) {
                _showToast('Passcodes do not match');
                return;
              }
              await _authService.setPasscode(codeCtrl.text);
              setState(() => _isPasscodeSet = true);
              Navigator.pop(context);
              _showToast('Passcode enabled');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
