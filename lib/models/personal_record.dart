class PersonalRecord {
  final String exerciseName;
  final double maxWeightKg;
  final int maxWeightReps;
  final int maxHoldSeconds;
  final double estimated1RM;
  final DateTime? achievedDate;
  final bool isTimeBased;

  const PersonalRecord({
    required this.exerciseName,
    this.maxWeightKg = 0.0,
    this.maxWeightReps = 0,
    this.maxHoldSeconds = 0,
    this.estimated1RM = 0.0,
    this.achievedDate,
    this.isTimeBased = false,
  });

  bool get hasRecord => isTimeBased ? maxHoldSeconds > 0 : maxWeightKg > 0;

  String get summary => formatSummary();

  String formatSummary() {
    if (!hasRecord) return 'No PR yet';
    if (isTimeBased) {
      final timeStr = maxHoldSeconds >= 60
          ? '${maxHoldSeconds ~/ 60}m${maxHoldSeconds % 60 > 0 ? " ${maxHoldSeconds % 60}s" : ""}'
          : '${maxHoldSeconds}s';
      final extraWeight = maxWeightKg > 0 ? ' (+${maxWeightKg.toStringAsFixed(1)}kg)' : '';
      return '$timeStr$extraWeight';
    } else {
      final wtStr = maxWeightKg % 1 == 0
          ? maxWeightKg.toInt().toString()
          : maxWeightKg.toStringAsFixed(1);
      final oneRmStr = estimated1RM > maxWeightKg
          ? ' (1RM ~${estimated1RM.round()}kg)'
          : '';
      return '$wtStr kg × $maxWeightReps$oneRmStr';
    }
  }

  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'maxWeightKg': maxWeightKg,
        'maxWeightReps': maxWeightReps,
        'maxHoldSeconds': maxHoldSeconds,
        'estimated1RM': estimated1RM,
        'achievedDate': achievedDate?.toIso8601String(),
        'isTimeBased': isTimeBased,
      };

  factory PersonalRecord.fromJson(Map<String, dynamic> json) => PersonalRecord(
        exerciseName: json['exerciseName'] as String? ?? '',
        maxWeightKg: (json['maxWeightKg'] as num?)?.toDouble() ?? 0.0,
        maxWeightReps: (json['maxWeightReps'] as num?)?.toInt() ?? 0,
        maxHoldSeconds: (json['maxHoldSeconds'] as num?)?.toInt() ?? 0,
        estimated1RM: (json['estimated1RM'] as num?)?.toDouble() ?? 0.0,
        achievedDate: json['achievedDate'] != null
            ? DateTime.tryParse(json['achievedDate'] as String)
            : null,
        isTimeBased: json['isTimeBased'] as bool? ?? false,
      );
}

class ExerciseLastPerformance {
  final String exerciseName;
  final DateTime completedDate;
  final String routineTitle;
  final List<ExerciseSetPerformance> sets;
  final bool isSuperset;
  final String? supersetName;

  const ExerciseLastPerformance({
    required this.exerciseName,
    required this.completedDate,
    required this.routineTitle,
    required this.sets,
    this.isSuperset = false,
    this.supersetName,
  });

  ExerciseSetPerformance? getSet(int setIndex) {
    if (setIndex >= 0 && setIndex < sets.length) {
      return sets[setIndex];
    }
    return null;
  }

  String? formatSet(int setNumber) {
    final idx = setNumber - 1;
    if (idx < 0 || idx >= sets.length) return null;
    final s = sets[idx];
    if (s.isTimeBased) return '${s.timeSeconds}s';
    return '${s.weightKg > 0 ? "${s.weightKg.toStringAsFixed(1)}kg × " : ""}${s.reps}';
  }
}

class ExerciseSetPerformance {
  final int setNumber;
  final int reps;
  final int timeSeconds;
  final double weightKg;
  final int supersetReps;
  final int supersetTimeSeconds;
  final double supersetWeightKg;
  final bool isTimeBased;
  final bool supersetIsTimeBased;

  const ExerciseSetPerformance({
    required this.setNumber,
    this.reps = 0,
    this.timeSeconds = 0,
    this.weightKg = 0.0,
    this.supersetReps = 0,
    this.supersetTimeSeconds = 0,
    this.supersetWeightKg = 0.0,
    this.isTimeBased = false,
    this.supersetIsTimeBased = false,
  });
}
