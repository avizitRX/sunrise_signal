import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/log_model.dart';
import '../../models/sleep_model.dart';
import '../../services/secure_storage_service.dart';
import '../analytics/analytics_page.dart';
import '../settings/settings_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final SecureStorageService _storageService = SecureStorageService();
  Map<DateTime, LogModel> _logs = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadLogs();
    _notificationInitialization();
  }

  Future<void> _loadLogs() async {
    final logs = await _storageService.loadLogs();
    setState(() {
      _logs = logs;
    });
  }

  Future<void> _notificationInitialization() async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);
  }

  DateTime _normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

  Future<void> _saveLog(
    DateTime date, {
    required String emoji,
    required double sleep,
    String? stress,
    String? exercise,
    String? alcoholIntake,
    String? caffeineIntake,
    String? sexualActivity,
  }) async {
    final normalized = _normalizeDate(date);
    _logs[normalized] = LogModel(
      emoji: emoji,
      sleepHours: sleep,
      stressLevel: stress,
      exercise: exercise,
      alcoholIntake: alcoholIntake,
      caffeineIntake: caffeineIntake,
      sexualActivity: sexualActivity,
    );
    await _storageService.saveLogs(_logs);
    setState(() {});
  }

  Future<void> _removeLog(DateTime date) async {
    final normalized = _normalizeDate(date);
    _logs.remove(normalized);
    await _storageService.saveLogs(_logs);
    setState(() {});
  }

  void _logEntryBottomSheet(DateTime date) {
    final normalized = _normalizeDate(date);
    final existingLog = _logs[normalized];

    // Form states
    String selectedEmoji = existingLog?.emoji ?? '🍆';
    String stressLevel = existingLog?.stressLevel ?? 'Low';

    // Parse sexual activity to support selecting both independently
    final currentSexActivity = existingLog?.sexualActivity ?? 'None';
    bool hadSex = currentSexActivity == 'Sex' || currentSexActivity == 'Both';
    bool didMasturbate = currentSexActivity == 'Masturbation' || currentSexActivity == 'Both';

    bool exercise = existingLog?.exercise == 'Yes';
    bool alcoholIntake = existingLog?.alcoholIntake == 'Yes';
    bool caffeineIntake = existingLog?.caffeineIntake == 'Yes';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Consumer<SleepModel>(
              builder: (context, sleepModel, _) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 12,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Drag Handle
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white24 : Colors.black12,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          // Date badge + Delete action
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  DateFormat('EEEE, MMM d').format(date).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 0.8,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              if (existingLog != null)
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(CupertinoIcons.trash,
                                      color: Colors.redAccent, size: 18),
                                  onPressed: () async {
                                    await _removeLog(date);
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Title
                          const Text(
                            'Did you wake up with morning wood?',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // 24-Hour Scope Notice
                          Row(
                            children: [
                              Icon(CupertinoIcons.clock_fill,
                                  size: 14, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Log all inputs based on the past 24 hours',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // YES / NO Cards
                          Row(
                            children: [
                              Expanded(
                                child: _YesNoCard(
                                  title: 'YES',
                                  emoji: '🍆',
                                  isSelected: selectedEmoji == '🍆',
                                  activeColor: theme.colorScheme.primary,
                                  onTap: () => setModalState(() => selectedEmoji = '🍆'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _YesNoCard(
                                  title: 'NO',
                                  emoji: '😔',
                                  isSelected: selectedEmoji == '😔',
                                  activeColor: const Color(0xFF64748B),
                                  onTap: () => setModalState(() => selectedEmoji = '😔'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),

                          // Sleep Duration
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Sleep Duration',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(
                                '${sleepModel.sleepHours.toStringAsFixed(1)} hrs',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            min: 1,
                            max: 12,
                            divisions: 22,
                            value: sleepModel.sleepHours.clamp(1.0, 12.0),
                            onChanged: (val) {
                              setModalState(() => sleepModel.sleepHours = val);
                            },
                          ),
                          const SizedBox(height: 12),

                          // Stress Level (Past 24h)
                          const Text('Stress Level (Past 24h)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            style: _customSegmentedStyle(context),
                            segments: const [
                              ButtonSegment(
                                  value: 'Low',
                                  label:
                                      Text('Low', style: TextStyle(fontWeight: FontWeight.w600))),
                              ButtonSegment(
                                  value: 'Medium',
                                  label: Text('Medium',
                                      style: TextStyle(fontWeight: FontWeight.w600))),
                              ButtonSegment(
                                  value: 'High',
                                  label:
                                      Text('High', style: TextStyle(fontWeight: FontWeight.w600))),
                            ],
                            selected: {stressLevel},
                            onSelectionChanged: (set) =>
                                setModalState(() => stressLevel = set.first),
                          ),
                          const SizedBox(height: 20),

                          // Lifestyle Habits (Past 24h)
                          const Text('Lifestyle Habits (Past 24h)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),

                          // Row 1: Sexual Habits (Independent Multi-select)
                          Row(
                            children: [
                              Expanded(
                                child: _HabitPill(
                                  label: 'Sex',
                                  icon: CupertinoIcons.heart_fill,
                                  isSelected: hadSex,
                                  onTap: () => setModalState(() => hadSex = !hadSex),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _HabitPill(
                                  label: 'Masturbate',
                                  icon: CupertinoIcons.hand_raised_fill,
                                  isSelected: didMasturbate,
                                  onTap: () => setModalState(() => didMasturbate = !didMasturbate),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Row 2: Physical & Substance Habits
                          Row(
                            children: [
                              Expanded(
                                child: _HabitPill(
                                  label: 'Workout',
                                  icon: Icons.fitness_center_rounded,
                                  isSelected: exercise,
                                  onTap: () => setModalState(() => exercise = !exercise),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _HabitPill(
                                  label: 'Alcohol',
                                  icon: Icons
                                      .local_bar_rounded, // Material icon retained (best match)
                                  isSelected: alcoholIntake,
                                  onTap: () => setModalState(() => alcoholIntake = !alcoholIntake),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _HabitPill(
                                  label: 'Caffeine',
                                  icon: Icons.coffee_rounded, // Material icon retained (best match)
                                  isSelected: caffeineIntake,
                                  onTap: () =>
                                      setModalState(() => caffeineIntake = !caffeineIntake),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),

                          // Save Button
                          FilledButton(
                            onPressed: () {
                              String calculatedSexActivity;
                              if (hadSex && didMasturbate) {
                                calculatedSexActivity = 'Both';
                              } else if (hadSex) {
                                calculatedSexActivity = 'Sex';
                              } else if (didMasturbate) {
                                calculatedSexActivity = 'Masturbation';
                              } else {
                                calculatedSexActivity = 'None';
                              }

                              _saveLog(
                                date,
                                emoji: selectedEmoji,
                                sleep: sleepModel.sleepHours,
                                stress: stressLevel,
                                exercise: exercise ? 'Yes' : 'No',
                                alcoholIntake: alcoholIntake ? 'Yes' : 'No',
                                caffeineIntake: caffeineIntake ? 'Yes' : 'No',
                                sexualActivity: calculatedSexActivity,
                              );
                              Navigator.pop(context);
                            },
                            child: const Text('Save Record'),
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
      },
    );
  }

  // Segmented Button Theme Helper
  ButtonStyle _customSegmentedStyle(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return theme.colorScheme.primary;
        }
        return isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return isDark ? Colors.white70 : Colors.black87;
      }),
      side: WidgetStateProperty.all(BorderSide.none),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sunrise Signal'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.chart_bar_alt_fill),
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsPage())),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.gear_alt_fill),
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: TableCalendar(
              firstDay: DateTime(2023),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              currentDay: DateTime.now(),
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                leftChevronIcon: Icon(Icons.chevron_left, size: 20),
                rightChevronIcon: Icon(Icons.chevron_right, size: 20),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                selectedDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                final normalizedSelectedDay = _normalizeDate(selectedDay);
                final normalizedToday = _normalizeDate(DateTime.now());

                if (normalizedSelectedDay.isAfter(normalizedToday)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text('Cannot log entries for future dates.'),
                    ),
                  );
                  return;
                }

                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });

                _logEntryBottomSheet(selectedDay);
              },
              eventLoader: (date) {
                final normalized = _normalizeDate(date);
                if (_logs.containsKey(normalized)) {
                  return [_logs[normalized]!.emoji];
                }
                return [];
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return null;
                  return Positioned(
                    bottom: 4,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Text(
                            events.first.toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// MICRO-INTERACTION WRAPPER (Scale Down On Tap)
// ---------------------------------------------------------
class _BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _BouncingButton({required this.child, required this.onTap});

  @override
  State<_BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<_BouncingButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------
// ANIMATED YES/NO TOGGLE CARDS
// ---------------------------------------------------------
class _YesNoCard extends StatelessWidget {
  final String title;
  final String emoji;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _YesNoCard({
    required this.title,
    required this.emoji,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _BouncingButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// ANIMATED HABIT PILL BUTTONS
// ---------------------------------------------------------
class _HabitPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _HabitPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _BouncingButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 140),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
