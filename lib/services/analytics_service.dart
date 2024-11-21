class AnalyticsService {
  String getDetailedAdvice(Map<String, dynamic> log) {
    final sleep = int.tryParse(log['sleep'] ?? '0') ?? 0;
    final stress = log['stress'] ?? 'Medium';
    final exercise = log['exercise'] ?? 'No';
    final intake = log['intake'] ?? 'No';

    String advice = '';

    if (sleep < 6) {
      advice += "Try to get more than 6 hours of sleep.\n";
    }
    if (stress == 'High') {
      advice += "Manage your stress through relaxation techniques.\n";
    }
    if (exercise == 'No') {
      advice += "Exercise can boost your overall energy levels.\n";
    }
    if (intake == 'Yes') {
      advice += "Reduce alcohol and caffeine intake.\n";
    }
    return advice;
  }
}
