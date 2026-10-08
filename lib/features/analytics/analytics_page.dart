import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/log_model.dart';
import '../../services/secure_storage_service.dart';

enum TimeFilter { sevenDays, thirtyDays, oneYear, custom }

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final SecureStorageService _storageService = SecureStorageService();
  Map<DateTime, LogModel> _allLogs = {};
  List<LogModel> _filteredLogs = [];
  bool _isLoading = true;

  // Filter State
  TimeFilter _selectedFilter = TimeFilter.thirtyDays;
  DateTimeRange? _customRange;

  // Counts & Stats
  int _yesCount = 0;
  int _noCount = 0;
  double _averageSleep = 0.0;
  int _exerciseCount = 0;
  int _alcoholCount = 0;
  int _caffeineCount = 0;
  int _sexCount = 0;
  int _masturbateCount = 0;

  final Map<String, int> _stressDistribution = {
    'Low': 0,
    'Medium': 0,
    'High': 0,
  };

  final List<_SimpleInsight> _insights = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final logs = await _storageService.loadLogs();
    if (!mounted) return;
    _allLogs = logs;
    _applyFilter();
  }

  void _applyFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime startDate;
    DateTime endDate = today.add(const Duration(days: 1));

    switch (_selectedFilter) {
      case TimeFilter.sevenDays:
        startDate = today.subtract(const Duration(days: 7));
        break;
      case TimeFilter.thirtyDays:
        startDate = today.subtract(const Duration(days: 30));
        break;
      case TimeFilter.oneYear:
        startDate = DateTime(today.year - 1, today.month, today.day);
        break;
      case TimeFilter.custom:
        if (_customRange != null) {
          startDate = DateTime(
              _customRange!.start.year, _customRange!.start.month, _customRange!.start.day);
          endDate = DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day)
              .add(const Duration(days: 1));
        } else {
          startDate = today.subtract(const Duration(days: 30));
        }
        break;
    }

    _filteredLogs = _allLogs.entries
        .where((entry) {
          final d = entry.key;
          return d.isAfter(startDate.subtract(const Duration(seconds: 1))) && d.isBefore(endDate);
        })
        .map((e) => e.value)
        .toList();

    _computeStats();
  }

  void _computeStats() {
    _yesCount = _filteredLogs.where((e) => e.emoji == '🍆').length;
    _noCount = _filteredLogs.where((e) => e.emoji == '😔').length;

    if (_filteredLogs.isNotEmpty) {
      final totalSleep = _filteredLogs.fold<double>(0.0, (sum, e) => sum + e.sleepHours);
      _averageSleep = totalSleep / _filteredLogs.length;
    } else {
      _averageSleep = 0.0;
    }

    _stressDistribution['Low'] = 0;
    _stressDistribution['Medium'] = 0;
    _stressDistribution['High'] = 0;

    for (var log in _filteredLogs) {
      if (log.stressLevel != null && _stressDistribution.containsKey(log.stressLevel)) {
        _stressDistribution[log.stressLevel!] = _stressDistribution[log.stressLevel!]! + 1;
      }
    }

    _exerciseCount = _filteredLogs.where((e) => e.exercise == 'Yes').length;
    _alcoholCount = _filteredLogs.where((e) => e.alcoholIntake == 'Yes').length;
    _caffeineCount = _filteredLogs.where((e) => e.caffeineIntake == 'Yes').length;
    _sexCount =
        _filteredLogs.where((e) => e.sexualActivity == 'Sex' || e.sexualActivity == 'Both').length;
    _masturbateCount = _filteredLogs
        .where((e) => e.sexualActivity == 'Masturbation' || e.sexualActivity == 'Both')
        .length;

    _generateAccurateInsights();

    setState(() {
      _isLoading = false;
    });
  }

  void _generateAccurateInsights() {
    _insights.clear();

    if (_filteredLogs.length < 3) {
      _insights.add(
        const _SimpleInsight(
          title: 'Collecting Data',
          message:
              'Log at least 3-5 days in this timeframe to generate meaningful correlation patterns.',
          icon: CupertinoIcons.sparkles,
          type: _InsightType.info,
        ),
      );
      return;
    }

    (int, double)? getRate(bool Function(LogModel) condition) {
      final subset = _filteredLogs.where(condition).toList();
      if (subset.isEmpty) return null;
      final yes = subset.where((e) => e.emoji == '🍆').length;
      return (subset.length, (yes / subset.length) * 100);
    }

    // 1. SLEEP
    final sleep7Plus = getRate((e) => e.sleepHours >= 7.0);
    final sleepUnder7 = getRate((e) => e.sleepHours < 7.0);

    if (sleep7Plus != null && sleepUnder7 != null) {
      final diff = sleep7Plus.$2 - sleepUnder7.$2;
      if (diff >= 10) {
        _insights.add(
          _SimpleInsight(
            title: 'Sleep has a positive impact',
            message:
                'You wake up with morning wood ${sleep7Plus.$2.toStringAsFixed(0)}% of the time when sleeping ≥7 hours, vs only ${sleepUnder7.$2.toStringAsFixed(0)}% on shorter sleep.',
            icon: CupertinoIcons.moon_stars_fill,
            type: _InsightType.positive,
          ),
        );
      } else if (diff <= -10) {
        _insights.add(
          _SimpleInsight(
            title: 'Sleep variation noticed',
            message:
                'Morning wood occurred on ${sleepUnder7.$2.toStringAsFixed(0)}% of short sleep nights vs ${sleep7Plus.$2.toStringAsFixed(0)}% on longer nights.',
            icon: CupertinoIcons.moon_stars_fill,
            type: _InsightType.info,
          ),
        );
      }
    }

    // 2. EXERCISE
    final workout = getRate((e) => e.exercise == 'Yes');
    final noWorkout = getRate((e) => e.exercise == 'No');

    if (workout != null && noWorkout != null) {
      if (workout.$2 > noWorkout.$2 && (workout.$2 - noWorkout.$2) >= 8) {
        _insights.add(
          _SimpleInsight(
            title: 'Workouts boost vitality',
            message:
                'Physical activity increases morning wood frequency to ${workout.$2.toStringAsFixed(0)}% (compared to ${noWorkout.$2.toStringAsFixed(0)}% on rest days).',
            icon: CupertinoIcons.heart_fill,
            type: _InsightType.positive,
          ),
        );
      }
    }

    // 3. SEXUAL ACTIVITY
    final hadSex = getRate((e) => e.sexualActivity == 'Sex' || e.sexualActivity == 'Both');
    final hadMasturbate =
        getRate((e) => e.sexualActivity == 'Masturbation' || e.sexualActivity == 'Both');
    final hadNeither = getRate((e) => e.sexualActivity == 'None' || e.sexualActivity == null);

    if (hadSex != null && hadNeither != null) {
      _insights.add(
        _SimpleInsight(
          title: 'Partner Sex Pattern',
          message:
              'After partner sex, morning wood occurred on ${hadSex.$2.toStringAsFixed(0)}% of mornings (vs ${hadNeither.$2.toStringAsFixed(0)}% on days without sexual activity).',
          icon: CupertinoIcons.heart_fill,
          type: _InsightType.info,
        ),
      );
    }

    if (hadMasturbate != null && hadNeither != null) {
      final isHurting = (hadNeither.$2 - hadMasturbate.$2) >= 15;
      _insights.add(
        _SimpleInsight(
          title: 'Masturbation Pattern',
          message: isHurting
              ? 'Masturbation in the past 24h shows a dip in morning erections to ${hadMasturbate.$2.toStringAsFixed(0)}% (vs ${hadNeither.$2.toStringAsFixed(0)}% on rest days).'
              : 'Solo activity appears to have a stable ${hadMasturbate.$2.toStringAsFixed(0)}% morning wood occurrence rate.',
          icon: CupertinoIcons.hand_raised_fill,
          type: isHurting ? _InsightType.warning : _InsightType.info,
        ),
      );
    }

    // 4. ALCOHOL
    final drankAlcohol = getRate((e) => e.alcoholIntake == 'Yes');
    final noAlcohol = getRate((e) => e.alcoholIntake == 'No');

    if (drankAlcohol != null && noAlcohol != null) {
      if (noAlcohol.$2 > drankAlcohol.$2 && (noAlcohol.$2 - drankAlcohol.$2) >= 10) {
        _insights.add(
          _SimpleInsight(
            title: 'Alcohol disrupts morning frequency',
            message:
                'Morning wood rate dropped to ${drankAlcohol.$2.toStringAsFixed(0)}% after drinking alcohol, vs ${noAlcohol.$2.toStringAsFixed(0)}% on clean days.',
            icon: Icons.local_bar_rounded,
            type: _InsightType.warning,
          ),
        );
      }
    }

    // 5. STRESS
    final lowStress = getRate((e) => e.stressLevel == 'Low');
    final highStress = getRate((e) => e.stressLevel == 'High');

    if (lowStress != null && highStress != null) {
      if (lowStress.$2 > highStress.$2 && (lowStress.$2 - highStress.$2) >= 10) {
        _insights.add(
          _SimpleInsight(
            title: 'High stress suppresses mornings',
            message:
                'Low stress correlates with a ${lowStress.$2.toStringAsFixed(0)}% morning rate, dropping down to ${highStress.$2.toStringAsFixed(0)}% under high stress.',
            icon: CupertinoIcons.exclamationmark_triangle_fill,
            type: _InsightType.warning,
          ),
        );
      }
    }
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 14)),
            end: DateTime.now(),
          ),
    );
    if (range != null) {
      setState(() {
        _customRange = range;
        _selectedFilter = TimeFilter.custom;
      });
      _applyFilter();
    }
  }

  String _getFilterLabel() {
    switch (_selectedFilter) {
      case TimeFilter.sevenDays:
        return 'Past 7 Days';
      case TimeFilter.thirtyDays:
        return 'Past 30 Days';
      case TimeFilter.oneYear:
        return 'Past Year';
      case TimeFilter.custom:
        if (_customRange != null) {
          return '${DateFormat('M/d').format(_customRange!.start)} - ${DateFormat('M/d').format(_customRange!.end)}';
        }
        return 'Custom Range';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // 1. TIMEFRAME SELECTOR
                _buildTimeFilterBar(theme, isDark),
                const SizedBox(height: 16),

                // 2. MORNING WOOD PIE CHART
                _buildCard(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'Morning Wood Frequency',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_yesCount + _noCount} Days',
                            style: TextStyle(
                                fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildPieChart(theme, isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. REPORTED STRESS DISTRIBUTION
                _buildCard(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reported Stress Distribution',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),
                      _buildStressBarChart(isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. STATS SUMMARY CARD
                _buildCard(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Totals (${_getFilterLabel()})',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                              child: _buildBigStatBadge(
                                  '🍆 Yes', '$_yesCount', theme.colorScheme.primary, isDark)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildBigStatBadge(
                                  '😔 No', '$_noCount', Colors.blueGrey, isDark)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildBigStatBadge(
                                  '😴 Sleep',
                                  '${_averageSleep.toStringAsFixed(1)}h',
                                  const Color(0xFF38BDF8),
                                  isDark)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                              child: _buildBigStatBadge(
                                  '❤️ Sex', '$_sexCount', const Color(0xFFF43F5E), isDark)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildBigStatBadge(
                                  '✋ Solo', '$_masturbateCount', const Color(0xFFA855F7), isDark)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildBigStatBadge('💪 Workout', '$_exerciseCount',
                                  const Color(0xFF10B981), isDark)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 5. WHAT AFFECTS YOUR MORNINGS
                Row(
                  children: [
                    Icon(CupertinoIcons.sparkles, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'What Affects Your Mornings',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_insights.isEmpty)
                  _buildNoCorrelationsNotice(isDark)
                else
                  ..._insights.map((insight) => _buildInsightCard(insight, isDark)),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTER BAR
  // ---------------------------------------------------------------------------
  Widget _buildTimeFilterBar(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('7 Days', TimeFilter.sevenDays, theme, isDark),
          const SizedBox(width: 8),
          _buildFilterChip('30 Days', TimeFilter.thirtyDays, theme, isDark),
          const SizedBox(width: 8),
          _buildFilterChip('1 Year', TimeFilter.oneYear, theme, isDark),
          const SizedBox(width: 8),
          ActionChip(
            avatar: Icon(
              CupertinoIcons.calendar,
              size: 14,
              color: _selectedFilter == TimeFilter.custom
                  ? theme.colorScheme.primary
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            label: Text(_selectedFilter == TimeFilter.custom && _customRange != null
                ? '${DateFormat('M/d').format(_customRange!.start)}-${DateFormat('M/d').format(_customRange!.end)}'
                : 'Custom'),
            backgroundColor: _selectedFilter == TimeFilter.custom
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            side: BorderSide(
              color: _selectedFilter == TimeFilter.custom
                  ? theme.colorScheme.primary
                  : Colors.transparent,
            ),
            onPressed: _pickCustomRange,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, TimeFilter filter, ThemeData theme, bool isDark) {
    final isSelected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedFilter = filter);
        _applyFilter();
      },
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      side: BorderSide(color: isSelected ? theme.colorScheme.primary : Colors.transparent),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white70 : Colors.black87),
        fontSize: 13,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PIE CHART
  // ---------------------------------------------------------------------------
  Widget _buildPieChart(ThemeData theme, bool isDark) {
    final total = _yesCount + _noCount;
    if (total == 0) {
      return const SizedBox(
        height: 140,
        child: Center(
            child: Text('No entries in this timeframe.', style: TextStyle(color: Colors.grey))),
      );
    }

    final yesPercent = (_yesCount / total) * 100;
    final noPercent = (_noCount / total) * 100;

    return Row(
      children: [
        SizedBox(
          height: 130,
          width: 130,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 32,
              sections: [
                PieChartSectionData(
                  value: yesPercent,
                  color: theme.colorScheme.primary,
                  radius: 34,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: noPercent,
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  radius: 34,
                  showTitle: false,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendRow('Present (🍆)', '${yesPercent.toStringAsFixed(0)}% ($_yesCount)',
                  theme.colorScheme.primary),
              const SizedBox(height: 12),
              _buildLegendRow(
                'Absent (😔)',
                '${noPercent.toStringAsFixed(0)}% ($_noCount)',
                isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
            width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BAR CHART
  // ---------------------------------------------------------------------------
  Widget _buildStressBarChart(bool isDark) {
    final maxStress = _stressDistribution.values.fold<int>(0, (max, v) => v > max ? v : max);

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxStress == 0 ? 5 : maxStress + 1.8).toDouble(),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) {
                  const labels = ['Low', 'Medium', 'High'];
                  if (val.toInt() >= 0 && val.toInt() < labels.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        labels[val.toInt()],
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: [
            _buildBarWithNumber(0, _stressDistribution['Low']!, const Color(0xFF10B981), isDark),
            _buildBarWithNumber(1, _stressDistribution['Medium']!, const Color(0xFFF59E0B), isDark),
            _buildBarWithNumber(2, _stressDistribution['High']!, const Color(0xFFEF4444), isDark),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildBarWithNumber(int x, int count, Color color, bool isDark) {
    return BarChartGroupData(
      x: x,
      showingTooltipIndicators: count > 0 ? [0] : [],
      barRods: [
        BarChartRodData(
          toY: count.toDouble(),
          color: color,
          width: 28,
          borderRadius: BorderRadius.circular(6),
        )
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // AUTOSCALED STAT BADGE (Prevents Text Overflow)
  // ---------------------------------------------------------------------------
  Widget _buildBigStatBadge(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INSIGHT CARD
  // ---------------------------------------------------------------------------
  Widget _buildInsightCard(_SimpleInsight insight, bool isDark) {
    Color tagColor;
    String tagText;

    switch (insight.type) {
      case _InsightType.positive:
        tagColor = const Color(0xFF10B981);
        tagText = 'HELPS';
        break;
      case _InsightType.warning:
        tagColor = const Color(0xFFEF4444);
        tagText = 'HURTS';
        break;
      case _InsightType.info:
        tagColor = const Color(0xFF38BDF8);
        tagText = 'PATTERN';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(insight.icon, size: 20, color: tagColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        insight.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tagText,
                        style:
                            TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tagColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  insight.message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNoCorrelationsNotice(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Not enough variance in this timeframe to identify conclusive patterns. Try switching to "Past Year" or "30 Days".',
        style: TextStyle(fontSize: 13, color: Colors.grey),
      ),
    );
  }

  Widget _buildCard({required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: child,
    );
  }
}

enum _InsightType { positive, warning, info }

class _SimpleInsight {
  final String title;
  final String message;
  final IconData icon;
  final _InsightType type;

  const _SimpleInsight({
    required this.title,
    required this.message,
    required this.icon,
    required this.type,
  });
}
