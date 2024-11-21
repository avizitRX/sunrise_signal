import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sunrise_signal/features/analytics/analytics_page.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../models/log_model.dart';
import '../../models/sleep_model.dart';
import '../services/secure_storage_service.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final SecureStorageService _storageService = SecureStorageService();
  Map<DateTime, LogModel> _logs = {};
  final DateTime _focusedDay = DateTime.now();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await _storageService.loadLogs();
    setState(() {
      _logs = logs;
    });
  }

  Future<void> _saveLog(
    DateTime date, {
    required String emoji,
    required double sleep,
    String? stress,
    String? exercise,
    String? alcoholIntake,
    String? caffeineIntake,
  }) async {
    _logs[date] = LogModel(
      emoji: emoji,
      sleepHours: sleep,
      stressLevel: stress,
      exercise: exercise,
      alcoholIntake: alcoholIntake,
      caffeineIntake: caffeineIntake,
    );
    await _storageService.saveLogs(_logs);
    setState(() {});
  }

  void _logEntryBottomSheet(DateTime date) {
    String? stressLevel;
    bool exercise = false;
    bool alcoholIntake = false;
    bool caffeineIntake = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        date.toLocal().toString().split(' ')[0],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'DID YOU WAKE UP WITH MORNING WOOD?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Consumer<SleepModel>(
                        builder: (context, sleepModel, child) {
                          return Column(
                            children: [
                              const Text('Sleep (hours):'),
                              Slider(
                                min: 1,
                                max: 12,
                                divisions: 22,
                                label: sleepModel.sleepHours.toStringAsFixed(1),
                                value: sleepModel.sleepHours,
                                onChanged: (double value) {
                                  sleepModel.sleepHours = value;
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: stressLevel,
                        decoration:
                            const InputDecoration(labelText: 'Stress Level'),
                        items: ['Low', 'Medium', 'High']
                            .map((level) => DropdownMenuItem(
                                  value: level,
                                  child: Text(level),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            stressLevel = value;
                          });
                        },
                        validator: (value) => value == null
                            ? 'Please select a stress level'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: const Text('Exercise Yesterday?'),
                        value: exercise,
                        onChanged: (bool? value) {
                          setState(() {
                            exercise = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: const Text('Alcohol Intake?'),
                        value: alcoholIntake,
                        onChanged: (bool? value) {
                          setState(() {
                            alcoholIntake = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: const Text('Caffeine Intake?'),
                        value: caffeineIntake,
                        onChanged: (bool? value) {
                          setState(() {
                            caffeineIntake = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () {
                              final sleepModel = Provider.of<SleepModel>(
                                  context,
                                  listen: false);

                              if (_formKey.currentState?.validate() ?? false) {
                                _saveLog(
                                  date,
                                  emoji: '😔',
                                  sleep: sleepModel.sleepHours,
                                  stress: stressLevel,
                                  exercise: exercise ? 'Yes' : 'No',
                                  alcoholIntake: alcoholIntake ? 'Yes' : 'No',
                                  caffeineIntake: caffeineIntake ? 'Yes' : 'No',
                                );
                                Navigator.pop(context);
                              }
                            },
                            child: const Text(
                              '😔 No',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              backgroundColor: Colors.green,
                            ),
                            onPressed: () {
                              final sleepModel = Provider.of<SleepModel>(
                                  context,
                                  listen: false);

                              if (_formKey.currentState?.validate() ?? false) {
                                _saveLog(
                                  date,
                                  emoji: '🍆',
                                  sleep: sleepModel.sleepHours,
                                  stress: stressLevel,
                                  exercise: exercise ? 'Yes' : 'No',
                                  alcoholIntake: alcoholIntake ? 'Yes' : 'No',
                                  caffeineIntake: caffeineIntake ? 'Yes' : 'No',
                                );
                                Navigator.pop(context);
                              }
                            },
                            child: const Text(
                              '🍆 Yes',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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

  void _showFutureDateError() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Invalid Date'),
          content: const Text('You cannot select a future date.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
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
        title: const Text('Sunrise Signal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _exportLogs,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _importLogs,
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AnalyticsPage()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: TableCalendar(
          calendarStyle: const CalendarStyle(
            selectedDecoration: BoxDecoration(
              color: Colors.red,
            ),
          ),
          focusedDay: _focusedDay,
          rowHeight: 100,
          firstDay: DateTime(2000),
          lastDay: DateTime(2100),
          calendarFormat: CalendarFormat.month,
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          onDaySelected: (selectedDay, _) {
            if (selectedDay.isAfter(DateTime.now())) {
              _showFutureDateError();
            } else {
              // _logEntryDialog(selectedDay);
              _logEntryBottomSheet(selectedDay);
            }
          },
          eventLoader: (date) {
            if (_logs.containsKey(date)) {
              return [_logs[date]!.emoji];
            }
            return [];
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (events.isNotEmpty) {
                return Positioned(
                  bottom: 1,
                  child: Container(
                    margin: const EdgeInsets.only(
                      top: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: events
                          .map((event) => Text(
                                event.toString(),
                                style: const TextStyle(fontSize: 18),
                              ))
                          .toList(),
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }
}
