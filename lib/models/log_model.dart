class LogModel {
  String emoji;
  double sleepHours;
  String? stressLevel;
  String? exercise;
  String? alcoholIntake;
  String? caffeineIntake;
  String? sexualActivity;

  LogModel({
    required this.emoji,
    required this.sleepHours,
    this.stressLevel,
    this.exercise,
    this.alcoholIntake,
    this.caffeineIntake,
    this.sexualActivity,
  });

  factory LogModel.fromMap(Map<String, dynamic> map) {
    return LogModel(
      emoji: map['emoji'],
      sleepHours: (map['sleepHours'] as num).toDouble(),
      stressLevel: map['stressLevel'],
      exercise: map['exercise'],
      alcoholIntake: map['alcoholIntake'],
      caffeineIntake: map['caffeineIntake'],
      sexualActivity: map['sexualActivity'] ?? 'None',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'emoji': emoji,
      'sleepHours': sleepHours,
      'stressLevel': stressLevel,
      'exercise': exercise,
      'alcoholIntake': alcoholIntake,
      'caffeineIntake': caffeineIntake,
      'sexualActivity': sexualActivity,
    };
  }
}
