import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sunrise_signal/features/analytics/analytics_page.dart';
import 'package:sunrise_signal/features/settings/settings_page.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../../models/log_model.dart';
import '../../models/sleep_model.dart';
import '../../services/secure_storage_service.dart';

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

  Future<void> _removeLog(DateTime date) async {
    _logs.remove(date);
    await _storageService.saveLogs(_logs);
    setState(() {});
  }

  void _logEntryBottomSheet(DateTime date) {
    String? stressLevel;
    bool exercise = false;
    bool alcoholIntake = false;
    bool caffeineIntake = false;
    String? emoji = '😔';

    // Check if there is already an entry for the selected date
    final existingLog = _logs[date];
    if (existingLog != null) {
      stressLevel = existingLog.stressLevel;
      emoji = existingLog.emoji;
      exercise = existingLog.exercise == 'Yes';
      alcoholIntake = existingLog.alcoholIntake == 'Yes';
      caffeineIntake = existingLog.caffeineIntake == 'Yes';
    }

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
                        DateFormat('d MMMM yyyy').format(date.toLocal()),
                        style: const TextStyle(
                          fontSize: 16,
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
                        title: const Text('Exercised Yesterday?'),
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
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
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(100),
                                color: Colors.red,
                              ),
                              child: const Center(
                                child: Text(
                                  'NO',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(-20, 0),
                            child: GestureDetector(
                              onTap: () {
                                final sleepModel = Provider.of<SleepModel>(
                                    context,
                                    listen: false);

                                if (_formKey.currentState?.validate() ??
                                    false) {
                                  _saveLog(
                                    date,
                                    emoji: '🍆',
                                    sleep: sleepModel.sleepHours,
                                    stress: stressLevel,
                                    exercise: exercise ? 'Yes' : 'No',
                                    alcoholIntake: alcoholIntake ? 'Yes' : 'No',
                                    caffeineIntake:
                                        caffeineIntake ? 'Yes' : 'No',
                                  );
                                  Navigator.pop(context);
                                }
                              },
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(100),
                                  color: Colors.red,
                                ),
                                child: const Center(
                                  child: Text(
                                    'YES',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (existingLog != null) ...[
                        ElevatedButton.icon(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                          onPressed: () {
                            // Confirm deletion of the log
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Delete Log Entry?'),
                                  content: const Text(
                                      'Are you sure you want to delete this entry?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        _removeLog(date);
                                        Navigator.pop(context);
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          label: const Text(
                            'Delete Entry',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
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
            icon: const Icon(Icons.analytics),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AnalyticsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: TableCalendar(
        calendarStyle: const CalendarStyle(
          selectedDecoration: BoxDecoration(
            color: Colors.red,
          ),
        ),
        focusedDay: _focusedDay,
        rowHeight: MediaQuery.of(context).size.height * 0.12,
        firstDay: DateTime(2000),
        lastDay: DateTime(2100),
        calendarFormat: CalendarFormat.month,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
        onDaySelected: (selectedDay, _) {
          // Normalize the selectedDay and DateTime.now() to ignore time
          final normalizedSelectedDay =
              DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
          final normalizedToday = DateTime(
              DateTime.now().year, DateTime.now().month, DateTime.now().day);

          if (normalizedSelectedDay.isAfter(normalizedToday)) {
            _showFutureDateError();
          } else {
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
                        .map(
                          (event) => Text(
                            event.toString(),
                            style: const TextStyle(fontSize: 18),
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }
}
