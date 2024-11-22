import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/secure_storage_service.dart';
import '../../models/log_model.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final SecureStorageService _storageService = SecureStorageService();
  Map<DateTime, LogModel> _logs = {};
  int _yesCount = 0;
  int _noCount = 0;
  double _averageSleep = 0;
  final Map<String, int> _stressDistribution = {
    'Low': 0,
    'Medium': 0,
    'High': 0
  };
  int _exerciseYesCount = 0;
  int _exerciseNoCount = 0;
  int _alcoholYesCount = 0;
  int _alcoholNoCount = 0;
  int _caffeineYesCount = 0;
  int _caffeineNoCount = 0;
  String _suggestions = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final logs = await _storageService.loadLogs();
    setState(() {
      _logs = logs;

      // Count morning wood days based on emoji
      _yesCount = logs.values.where((log) => log.emoji == '🍆').length;
      _noCount = logs.values.where((log) => log.emoji == '😔').length;

      // Calculate average sleep hours
      final totalSleep =
          logs.values.map((log) => log.sleepHours).reduce((a, b) => a + b);
      _averageSleep = logs.isEmpty ? 0 : totalSleep / logs.length;

      // Track stress level distribution
      for (var log in logs.values) {
        final stress = log.stressLevel;
        if (stress != null && _stressDistribution.containsKey(stress)) {
          _stressDistribution[stress] = _stressDistribution[stress]! + 1;
        }
      }

      // Track exercise, alcohol, and caffeine counts
      _exerciseYesCount =
          logs.values.where((log) => log.exercise == 'Yes').length;
      _exerciseNoCount =
          logs.values.where((log) => log.exercise == 'No').length;
      _alcoholYesCount =
          logs.values.where((log) => log.alcoholIntake == 'Yes').length;
      _alcoholNoCount =
          logs.values.where((log) => log.alcoholIntake == 'No').length;
      _caffeineYesCount =
          logs.values.where((log) => log.caffeineIntake == 'Yes').length;
      _caffeineNoCount =
          logs.values.where((log) => log.caffeineIntake == 'No').length;

      // Generate suggestions
      _suggestions = _generateSuggestions();
    });
  }

  String _generateSuggestions() {
    List<String> suggestions = [];

    // Morning Wood suggestions
    if (_yesCount > _noCount) {
      suggestions.add(
          "🍆 You are having a healthy frequency of morning wood. Continue maintaining a balanced lifestyle to keep it up.");
    } else if (_noCount > _yesCount) {
      suggestions.add(
          "😔 Consider factors that might affect your morning wood, such as sleep, stress, vitamin-D consumption, and diet. A healthier lifestyle can improve this.");
    } else {
      suggestions.add(
          "😔 The balance between morning wood and no morning wood is neutral. Keep track of factors like sleep, stress, vitamin-D consumption, and diet for improvement.");
    }

    // Sleep suggestions
    if (_averageSleep < 7) {
      suggestions.add(
          "😴 Your average sleep is below the recommended 7-8 hours. Try to improve your sleep duration by maintaining a consistent sleep schedule.");
    } else {
      suggestions.add("😴 Great job! You're getting a good amount of sleep.");
    }

    // Stress suggestions based on percentage
    final totalStressEntries =
        _stressDistribution.values.reduce((a, b) => a + b);
    if (totalStressEntries > 0) {
      final highStressPercent =
          (_stressDistribution['High']! / totalStressEntries) * 100;
      final mediumStressPercent =
          (_stressDistribution['Medium']! / totalStressEntries) * 100;
      final lowStressPercent =
          (_stressDistribution['Low']! / totalStressEntries) * 100;

      if (highStressPercent > 50) {
        suggestions.add(
            "😩 You seem to be experiencing high stress often. Consider incorporating relaxation techniques like deep breathing, meditation, or yoga.");
      } else if (mediumStressPercent > 50) {
        suggestions.add(
            "😩 Moderate stress levels are common. Try to find moments for relaxation during the day to reduce stress.");
      } else if (highStressPercent + mediumStressPercent > 50) {
        suggestions.add(
            "😩 Your stress levels seem NOT to be optimal. Try to find moments for relaxation during the day to reduce stress.");
      } else {
        suggestions.add(
            "😩 Your stress levels seem to be under control. Keep up the good work!");
      }
    } else {
      suggestions.add("😩 There is no data on your stress levels.");
    }

    // Exercise suggestions
    if (_exerciseYesCount < _exerciseNoCount) {
      suggestions.add(
          "💪 Try to incorporate more exercise into your routine. Regular physical activity can improve your overall health.");
    } else {
      suggestions.add("💪 Great job on maintaining regular exercise.");
    }

    // Alcohol suggestions
    if (_alcoholYesCount > _alcoholNoCount) {
      suggestions.add(
          "🍷 Consider reducing your alcohol intake. Excessive alcohol consumption can negatively impact your health.");
    } else {
      suggestions.add("🍷 Good job on keeping your alcohol intake in check.");
    }

    // Caffeine suggestions
    if (_caffeineYesCount > _caffeineNoCount) {
      suggestions.add(
          "☕ Try to limit your caffeine intake. Excessive caffeine can disrupt your sleep and increase stress.");
    } else {
      suggestions.add("☕ Good job on managing your caffeine consumption.");
    }

    // Return the suggestions as a concatenated string
    return suggestions.join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    // Morning Wood Chart
                    const Text(
                      'Morning Wood Distribution',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _buildPieChart(),
                    const SizedBox(height: 20),

                    // Summary Cards
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSummaryCard(
                            '🍆 Days', _yesCount.toString(), Colors.green),
                        _buildSummaryCard(
                            '😔 Days', _noCount.toString(), Colors.red),
                        _buildSummaryCard(
                            '😴 Avg Sleep',
                            '${_averageSleep.toStringAsFixed(1)} hrs',
                            Colors.blue),
                      ],
                    ),
                    Row(
                      children: [
                        _buildSummaryCard('💪 Exercise',
                            _exerciseYesCount.toString(), Colors.orange),
                        _buildSummaryCard('🍷 Alcohol',
                            _alcoholYesCount.toString(), Colors.purple),
                        _buildSummaryCard('☕ Caffeine',
                            _caffeineYesCount.toString(), Colors.brown),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),

                const SizedBox(
                  height: 20,
                ),

                // Stress Level Chart
                const Text(
                  'Stress Level Distribution',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _buildStressBarChart(),
                const SizedBox(height: 20),

                const SizedBox(
                  height: 20,
                ),

                // Suggestions
                const Text(
                  'Suggestions to Improve',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  _suggestions,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.5),
        margin: const EdgeInsets.all(2),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 15, 0, 15),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStressBarChart() {
    final stressData = _stressDistribution.entries.map((entry) {
      final index = ['Low', 'Medium', 'High'].indexOf(entry.key);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: Colors.orange,
            width: 20,
          ),
        ],
      );
    }).toList();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const labels = ['Low', 'Medium', 'High'];
                  if (value.toInt() >= 0 && value.toInt() < labels.length) {
                    return Text(labels[value.toInt()]);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: stressData,
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    final total = _yesCount + _noCount;
    final yesPercent = total == 0 ? 0.0 : (_yesCount / total) * 100;
    final noPercent = total == 0 ? 0.0 : (_noCount / total) * 100;

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(
              value: yesPercent.toDouble(),
              color: Colors.green,
              title: '${yesPercent.toStringAsFixed(1)}%',
              radius: 50,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              value: noPercent.toDouble(),
              color: Colors.red,
              title: '${noPercent.toStringAsFixed(1)}%',
              radius: 50,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
          sectionsSpace: 2,
          centerSpaceRadius: 40,
        ),
      ),
    );
  }
}
