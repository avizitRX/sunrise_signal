import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../providers/log_provider.dart';
import '../analytics/analytics_page.dart';
import '../settings/settings_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _normalizeDate(_focusedDay);
    _notificationInitialization();
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

  void _logEntryBottomSheet(DateTime date) {
    final logProvider = Provider.of<LogProvider>(context, listen: false);
    final existingLog = logProvider.getLogForDate(date);

    double sleepHours = existingLog?.sleepHours ?? 7.0;
    String selectedEmoji = existingLog?.emoji ?? '🍆';
    String stressLevel = existingLog?.stressLevel ?? 'Low';

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
      backgroundColor: isDark ? const Color(0xFF161F2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
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
                                await logProvider.removeLog(date);
                                if (context.mounted) Navigator.pop(context);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sleep Duration',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                            '${sleepHours.toStringAsFixed(1)} hrs',
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
                        value: sleepHours.clamp(1.0, 12.0),
                        onChanged: (val) {
                          setModalState(() => sleepHours = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('Stress Level (Past 24h)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'Low',
                              label: Text('Low', style: TextStyle(fontWeight: FontWeight.w600))),
                          ButtonSegment(
                              value: 'Medium',
                              label: Text('Medium', style: TextStyle(fontWeight: FontWeight.w600))),
                          ButtonSegment(
                              value: 'High',
                              label: Text('High', style: TextStyle(fontWeight: FontWeight.w600))),
                        ],
                        selected: {stressLevel},
                        onSelectionChanged: (set) => setModalState(() => stressLevel = set.first),
                      ),
                      const SizedBox(height: 20),
                      const Text('Lifestyle Habits (Past 24h)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
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
                      Row(
                        children: [
                          Expanded(
                            child: _HabitPill(
                              label: 'Workout',
                              icon: CupertinoIcons.heart_fill,
                              isSelected: exercise,
                              onTap: () => setModalState(() => exercise = !exercise),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HabitPill(
                              label: 'Alcohol',
                              icon: Icons.local_bar_rounded,
                              isSelected: alcoholIntake,
                              onTap: () => setModalState(() => alcoholIntake = !alcoholIntake),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HabitPill(
                              label: 'Caffeine',
                              icon: Icons.coffee_rounded,
                              isSelected: caffeineIntake,
                              onTap: () => setModalState(() => caffeineIntake = !caffeineIntake),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      FilledButton(
                        onPressed: () async {
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

                          await logProvider.saveLog(
                            date,
                            emoji: selectedEmoji,
                            sleep: sleepHours,
                            stress: stressLevel,
                            exercise: exercise ? 'Yes' : 'No',
                            alcoholIntake: alcoholIntake ? 'Yes' : 'No',
                            caffeineIntake: caffeineIntake ? 'Yes' : 'No',
                            sexualActivity: calculatedSexActivity,
                          );
                          if (context.mounted) Navigator.pop(context);
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<LogProvider>(
      builder: (context, logProvider, _) {
        final logs = logProvider.logs;

        // Compute Month Stats directly from provider
        final monthLogs = logs.entries
            .where((e) => e.key.year == _focusedDay.year && e.key.month == _focusedDay.month)
            .map((e) => e.value)
            .toList();

        final monthYes = monthLogs.where((l) => l.emoji == '🍆').length;
        final monthNo = monthLogs.where((l) => l.emoji == '😔').length;
        final monthTotal = monthYes + monthNo;
        final monthRate = monthTotal == 0 ? 0.0 : (monthYes / monthTotal);
        final monthAvgSleep = monthLogs.isEmpty
            ? 0.0
            : (monthLogs.fold<double>(0, (sum, l) => sum + l.sleepHours) / monthLogs.length);

        final selectedLog = _selectedDay != null ? logProvider.getLogForDate(_selectedDay!) : null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sunrise Signal'),
            actions: [
              IconButton(
                icon: const Icon(CupertinoIcons.chart_bar_alt_fill),
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const AnalyticsPage())),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.gear_alt_fill),
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const SettingsPage())),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Calendar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161F2E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF263346) : const Color(0xFFE2E8F0),
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
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                    },
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
                      if (logs.containsKey(normalized)) {
                        return [logs[normalized]!.emoji];
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

                // Month Snapshot Card
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    key: ValueKey('month_${_focusedDay.year}_${_focusedDay.month}_$monthTotal'),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161F2E) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF263346) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${DateFormat('MMMM yyyy').format(_focusedDay)} Snapshot',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              monthTotal == 0
                                  ? '0% rate'
                                  : '${(monthRate * 100).toStringAsFixed(0)}% rate',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: monthRate,
                            minHeight: 6,
                            backgroundColor:
                                isDark ? const Color(0xFF263346) : const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMonthStatPill(
                                'Present',
                                '$monthYes',
                                '🍆',
                                theme.colorScheme.primary,
                                isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMonthStatPill(
                                'Absent',
                                '$monthNo',
                                '😔',
                                Colors.blueGrey,
                                isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMonthStatPill(
                                'Avg Sleep',
                                '${monthAvgSleep.toStringAsFixed(1)}h',
                                '😴',
                                const Color(0xFF38BDF8),
                                isDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Selected Day Inspector Card
                if (_selectedDay != null)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      key: ValueKey('day_${_selectedDay!.toIso8601String()}_${selectedLog?.emoji}'),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161F2E) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF263346) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('EEEE, MMM d').format(_selectedDay!),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              InkWell(
                                onTap: () => _logEntryBottomSheet(_selectedDay!),
                                child: Text(
                                  selectedLog != null ? 'Edit Log' : 'Add Log',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (selectedLog == null)
                            Text(
                              'No record logged for this day. Tap to add your morning status.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            )
                          else
                            Row(
                              children: [
                                Text(selectedLog.emoji, style: const TextStyle(fontSize: 26)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedLog.emoji == '🍆'
                                            ? 'Morning Wood Present'
                                            : 'No Morning Wood Reported',
                                        style: const TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${selectedLog.sleepHours.toStringAsFixed(1)} hrs sleep • Stress: ${selectedLog.stressLevel ?? "Low"}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthStatPill(String label, String value, String icon, Color color, bool isDark) {
    return _BouncingButton(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// MICRO-INTERACTION WRAPPERS
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
              : (isDark ? const Color(0xFF161F2E) : const Color(0xFFF1F5F9)),
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
              : (isDark ? const Color(0xFF161F2E) : const Color(0xFFF1F5F9)),
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
