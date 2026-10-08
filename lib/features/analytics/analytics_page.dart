import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/log_model.dart';
import '../../providers/log_provider.dart';

enum TimeFilter { sevenDays, thirtyDays, oneYear, custom }

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  // Filter State
  TimeFilter _selectedFilter = TimeFilter.thirtyDays;
  DateTimeRange? _customRange;

  // Calculation Container
  late _AnalyticsData _data;

  // ---------------------------------------------------------------------------
  // PURE CALCULATION ENGINE (No setState called inside!)
  // ---------------------------------------------------------------------------
  _AnalyticsData _computeData(Map<DateTime, LogModel> allLogs) {
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

    final filteredLogs = allLogs.entries
        .where((entry) {
          final d = entry.key;
          return d.isAfter(startDate.subtract(const Duration(seconds: 1))) && d.isBefore(endDate);
        })
        .map((e) => e.value)
        .toList();

    final yesCount = filteredLogs.where((e) => e.emoji == '🍆').length;
    final noCount = filteredLogs.where((e) => e.emoji == '😔').length;

    final avgSleep = filteredLogs.isNotEmpty
        ? (filteredLogs.fold<double>(0.0, (sum, e) => sum + e.sleepHours) / filteredLogs.length)
        : 0.0;

    final stressMap = {'Low': 0, 'Medium': 0, 'High': 0};
    for (var log in filteredLogs) {
      if (log.stressLevel != null && stressMap.containsKey(log.stressLevel)) {
        stressMap[log.stressLevel!] = stressMap[log.stressLevel!]! + 1;
      }
    }

    final exerciseCount = filteredLogs.where((e) => e.exercise == 'Yes').length;
    final alcoholCount = filteredLogs.where((e) => e.alcoholIntake == 'Yes').length;
    final caffeineCount = filteredLogs.where((e) => e.caffeineIntake == 'Yes').length;
    final sexCount =
        filteredLogs.where((e) => e.sexualActivity == 'Sex' || e.sexualActivity == 'Both').length;
    final masturbateCount = filteredLogs
        .where((e) => e.sexualActivity == 'Masturbation' || e.sexualActivity == 'Both')
        .length;

    final insights = _generateHumorousInsights(filteredLogs, avgSleep);

    return _AnalyticsData(
      filteredLogs: filteredLogs,
      yesCount: yesCount,
      noCount: noCount,
      avgSleep: avgSleep,
      exerciseCount: exerciseCount,
      alcoholCount: alcoholCount,
      caffeineCount: caffeineCount,
      sexCount: sexCount,
      masturbateCount: masturbateCount,
      stressMap: stressMap,
      insights: insights,
    );
  }

  List<_SimpleInsight> _generateHumorousInsights(List<LogModel> entries, double avgSleep) {
    final insights = <_SimpleInsight>[];

    if (entries.length < 3) {
      insights.add(
        const _SimpleInsight(
          title: 'Not enough data yet 🕵️‍♂️',
          message:
              'Our diagnostic engines need at least 3-5 days in this timeframe to figure out what makes your morning engine purr.',
          icon: CupertinoIcons.sparkles,
          type: _InsightType.info,
        ),
      );
      return insights;
    }

    (int, double)? getRate(bool Function(LogModel) condition) {
      final subset = entries.where(condition).toList();
      if (subset.isEmpty) return null;
      final yes = subset.where((e) => e.emoji == '🍆').length;
      return (subset.length, (yes / subset.length) * 100);
    }

    // 1. Sleep
    final sleep7Plus = getRate((e) => e.sleepHours >= 7.0);
    final sleepUnder7 = getRate((e) => e.sleepHours < 7.0);

    if (sleep7Plus != null && sleepUnder7 != null) {
      final diff = sleep7Plus.$2 - sleepUnder7.$2;
      if (diff >= 10) {
        insights.add(
          _SimpleInsight(
            title: 'Sleep is your secret superpower 🛌',
            message:
                'Your testosterone factory works night shifts! You saluted ${sleep7Plus.$2.toStringAsFixed(0)}% of mornings with 7+ hours of sleep, vs only ${sleepUnder7.$2.toStringAsFixed(0)}% when short on sleep.',
            icon: CupertinoIcons.moon_stars_fill,
            type: _InsightType.positive,
          ),
        );
      }
    }

    // 2. Workout
    final workout = getRate((e) => e.exercise == 'Yes');
    final noWorkout = getRate((e) => e.exercise == 'No');

    if (workout != null && noWorkout != null && (workout.$2 - noWorkout.$2) >= 8) {
      insights.add(
        _SimpleInsight(
          title: 'Pumping iron = Pumping blood 🏋️‍♂️',
          message:
              'Working out pushed your morning signals up to ${workout.$2.toStringAsFixed(0)}% (vs ${noWorkout.$2.toStringAsFixed(0)}% on rest days). The plumbing approves.',
          icon: CupertinoIcons.heart_fill,
          type: _InsightType.positive,
        ),
      );
    }

    // 3. Sexual Activity
    final hadSex = getRate((e) => e.sexualActivity == 'Sex' || e.sexualActivity == 'Both');
    final hadMasturbate =
        getRate((e) => e.sexualActivity == 'Masturbation' || e.sexualActivity == 'Both');
    final hadNeither = getRate((e) => e.sexualActivity == 'None' || e.sexualActivity == null);

    if (hadSex != null && hadNeither != null) {
      insights.add(
        _SimpleInsight(
          title: 'The Post-Game Report ❤️',
          message:
              'Partner sex led to a ${hadSex.$2.toStringAsFixed(0)}% morning wake-up call (compared to ${hadNeither.$2.toStringAsFixed(0)}% during downtime). System recovery is functioning as intended.',
          icon: CupertinoIcons.heart_fill,
          type: _InsightType.info,
        ),
      );
    }

    if (hadMasturbate != null && hadNeither != null) {
      final isHurting = (hadNeither.$2 - hadMasturbate.$2) >= 15;
      insights.add(
        _SimpleInsight(
          title: isHurting ? 'Solo mission tax ✋' : 'Solo flight confirmed ✈️',
          message: isHurting
              ? 'Flying solo pulled morning responses down to ${hadMasturbate.$2.toStringAsFixed(0)}% (vs ${hadNeither.$2.toStringAsFixed(0)}% on rest days). Classic biological cooldown.'
              : 'Solo activity maintains an even ${hadMasturbate.$2.toStringAsFixed(0)}% morning rate. Standard reload speed.',
          icon: CupertinoIcons.hand_raised_fill,
          type: isHurting ? _InsightType.warning : _InsightType.info,
        ),
      );
    }

    // 4. Alcohol
    final drankAlcohol = getRate((e) => e.alcoholIntake == 'Yes');
    final noAlcohol = getRate((e) => e.alcoholIntake == 'No');

    if (drankAlcohol != null && noAlcohol != null && (noAlcohol.$2 - drankAlcohol.$2) >= 10) {
      insights.add(
        _SimpleInsight(
          title: 'Whiskey dick is real 🍺',
          message:
              'Alcohol dropped your morning readiness down to ${drankAlcohol.$2.toStringAsFixed(0)}% (vs ${noAlcohol.$2.toStringAsFixed(0)}% without drinks). Booze snoozed your alarm.',
          icon: Icons.local_bar_rounded,
          type: _InsightType.warning,
        ),
      );
    }

    // 5. Stress
    final lowStress = getRate((e) => e.stressLevel == 'Low');
    final highStress = getRate((e) => e.stressLevel == 'High');

    if (lowStress != null && highStress != null && (lowStress.$2 - highStress.$2) >= 10) {
      insights.add(
        _SimpleInsight(
          title: 'Cortisol is the ultimate mood killer 🧘‍♂️',
          message:
              'Stress hijacked your mornings down to ${highStress.$2.toStringAsFixed(0)}% (vs ${lowStress.$2.toStringAsFixed(0)}% when chill). Your nerves are taking up all the bandwidth.',
          icon: CupertinoIcons.exclamationmark_triangle_fill,
          type: _InsightType.warning,
        ),
      );
    }

    return insights;
  }

  String _getHumorousStatus(double rate) {
    if (rate >= 75) return 'Flagpole is on active duty 🫡';
    if (rate >= 50) return 'Healthy biological radio signal 📡';
    if (rate >= 25) return 'Battery saver mode active 🪫';
    return 'Dormant volcano status 🌋';
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

    return Consumer<LogProvider>(
      builder: (context, logProvider, _) {
        if (logProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CupertinoActivityIndicator()),
          );
        }

        // Pure calculation: Safe to run during build because it does NOT call setState!
        _data = _computeData(logProvider.logs);

        final total = _data.yesCount + _data.noCount;
        final successRate = total == 0 ? 0.0 : (_data.yesCount / total) * 100;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Signal Analytics'),
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: ListView(
              key: ValueKey('analytics_${_selectedFilter}_${_data.filteredLogs.length}'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildTimeFilterBar(theme, isDark),
                const SizedBox(height: 16),

                // Frequency Pie Chart
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
                            '$total Days',
                            style: TextStyle(
                                fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getHumorousStatus(successRate),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPieChart(theme, isDark, total, successRate),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Stress Distribution
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
                      _buildStressBarChart(isDark, _data.stressMap),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Totals
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
                              child: _buildBigStatBadge('🍆 Yes', '${_data.yesCount}',
                                  theme.colorScheme.primary, isDark)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildBigStatBadge(
                                  '😔 No', '${_data.noCount}', Colors.blueGrey, isDark)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildBigStatBadge(
                                  '😴 Sleep',
                                  '${_data.avgSleep.toStringAsFixed(1)}h',
                                  const Color(0xFF38BDF8),
                                  isDark)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                              child: _buildBigStatBadge(
                                  '❤️ Sex', '${_data.sexCount}', const Color(0xFFF43F5E), isDark)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildBigStatBadge('✋ Solo', '${_data.masturbateCount}',
                                  const Color(0xFFA855F7), isDark)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildBigStatBadge('💪 Workout', '${_data.exerciseCount}',
                                  const Color(0xFF10B981), isDark)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Insights
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
                if (_data.insights.isEmpty)
                  _buildNoCorrelationsNotice(isDark)
                else
                  ..._data.insights.map((insight) => _buildInsightCard(insight, isDark)),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

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
                : (isDark ? const Color(0xFF161F2E) : const Color(0xFFF1F5F9)),
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
      },
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      backgroundColor: isDark ? const Color(0xFF161F2E) : const Color(0xFFF1F5F9),
      side: BorderSide(color: isSelected ? theme.colorScheme.primary : Colors.transparent),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white70 : Colors.black87),
        fontSize: 13,
      ),
    );
  }

  Widget _buildPieChart(ThemeData theme, bool isDark, int total, double yesPercent) {
    if (total == 0) {
      return const SizedBox(
        height: 140,
        child: Center(
            child: Text('No entries in this timeframe.', style: TextStyle(color: Colors.grey))),
      );
    }

    final noPercent = 100 - yesPercent;

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
                  color: isDark ? const Color(0xFF263346) : const Color(0xFFCBD5E1),
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
              _buildLegendRow(
                  'Present (🍆)',
                  '${yesPercent.toStringAsFixed(0)}% (${_data.yesCount})',
                  theme.colorScheme.primary),
              const SizedBox(height: 12),
              _buildLegendRow(
                'Absent (😔)',
                '${noPercent.toStringAsFixed(0)}% (${_data.noCount})',
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

  Widget _buildStressBarChart(bool isDark, Map<String, int> stressMap) {
    final maxStress = stressMap.values.fold<int>(0, (max, v) => v > max ? v : max);

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
            _buildBarWithNumber(0, stressMap['Low']!, const Color(0xFF10B981), isDark),
            _buildBarWithNumber(1, stressMap['Medium']!, const Color(0xFFF59E0B), isDark),
            _buildBarWithNumber(2, stressMap['High']!, const Color(0xFFEF4444), isDark),
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
        color: isDark ? const Color(0xFF161F2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF263346) : const Color(0xFFE2E8F0),
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
        color: isDark ? const Color(0xFF161F2E) : Colors.white,
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
        color: isDark ? const Color(0xFF161F2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF263346) : const Color(0xFFE2E8F0),
        ),
      ),
      child: child,
    );
  }
}

class _AnalyticsData {
  final List<LogModel> filteredLogs;
  final int yesCount;
  final int noCount;
  final double avgSleep;
  final int exerciseCount;
  final int alcoholCount;
  final int caffeineCount;
  final int sexCount;
  final int masturbateCount;
  final Map<String, int> stressMap;
  final List<_SimpleInsight> insights;

  _AnalyticsData({
    required this.filteredLogs,
    required this.yesCount,
    required this.noCount,
    required this.avgSleep,
    required this.exerciseCount,
    required this.alcoholCount,
    required this.caffeineCount,
    required this.sexCount,
    required this.masturbateCount,
    required this.stressMap,
    required this.insights,
  });
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
