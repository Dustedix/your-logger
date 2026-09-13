class ExerciseSetLog {
  int setNumber;
  int reps;
  int timeSeconds; // For time-based exercises like Plank
  double weightKg;
  bool completed;

  ExerciseSetLog({
    required this.setNumber,
    this.reps = 10,
    this.timeSeconds = 60,
    this.weightKg = 0.0,
    this.completed = true,
  });

  Map<String, dynamic> toJson() => {
        'setNumber': setNumber,
        'reps': reps,
        'timeSeconds': timeSeconds,
        'weightKg': weightKg,
        'completed': completed,
      };

  factory ExerciseSetLog.fromJson(Map<String, dynamic> json) => ExerciseSetLog(
        setNumber: (json['setNumber'] as num?)?.toInt() ?? 1,
        reps: (json['reps'] as num?)?.toInt() ?? 10,
        timeSeconds: (json['timeSeconds'] as num?)?.toInt() ?? 60,
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0.0,
        completed: json['completed'] as bool? ?? true,
      );

  ExerciseSetLog copy() => ExerciseSetLog(
        setNumber: setNumber,
        reps: reps,
        timeSeconds: timeSeconds,
        weightKg: weightKg,
        completed: completed,
      );
}

class ExerciseCompletionLog {
  final String exerciseId;
  final String exerciseName;
  final String targetMuscle;
  final bool isTimeBased;
  final List<ExerciseSetLog> sets;
  final String notes;

  ExerciseCompletionLog({
    required this.exerciseId,
    required this.exerciseName,
    this.targetMuscle = 'General',
    this.isTimeBased = false,
    required this.sets,
    this.notes = '',
  });

  int get totalReps => sets.fold(
      0, (sum, s) => sum + (s.completed && !isTimeBased ? s.reps : 0));

  int get totalTimeSeconds => sets.fold(
      0, (sum, s) => sum + (s.completed && isTimeBased ? s.timeSeconds : 0));

  int get completedSets => sets.where((s) => s.completed).length;

  double get totalVolume => sets.fold(
      0.0, (sum, s) => sum + (s.completed ? (s.reps * s.weightKg) : 0.0));

  String formatSetText(ExerciseSetLog s) {
    if (isTimeBased) {
      final sec = s.timeSeconds;
      String timeStr;
      if (sec >= 60) {
        final m = sec ~/ 60;
        final rem = sec % 60;
        timeStr = rem > 0 ? '${m}m ${rem}s' : '${m}m';
      } else {
        timeStr = '${sec}s';
      }
      final weightStr = s.weightKg > 0 ? ' (+${s.weightKg}kg)' : '';
      return '$timeStr$weightStr';
    } else {
      final weightStr = s.weightKg > 0 ? ' @ ${s.weightKg}kg' : '';
      return '${s.reps} reps$weightStr';
    }
  }

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'targetMuscle': targetMuscle,
        'isTimeBased': isTimeBased,
        'sets': sets.map((s) => s.toJson()).toList(),
        'notes': notes,
      };

  factory ExerciseCompletionLog.fromJson(Map<String, dynamic> json) =>
      ExerciseCompletionLog(
        exerciseId: json['exerciseId'] as String? ?? '',
        exerciseName: json['exerciseName'] as String? ?? 'Exercise',
        targetMuscle: json['targetMuscle'] as String? ?? 'General',
        isTimeBased: json['isTimeBased'] as bool? ?? false,
        sets: (json['sets'] as List<dynamic>?)
                ?.map((s) => ExerciseSetLog.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        notes: json['notes'] as String? ?? '',
      );
}

class WorkoutLog {
  final String id;
  final String scheduleId;
  final String scheduleTitle;
  final DateTime completedDate;
  final int durationMinutes;
  final List<ExerciseCompletionLog> exerciseLogs;
  final String overallNotes;

  WorkoutLog({
    required this.id,
    required this.scheduleId,
    required this.scheduleTitle,
    required this.completedDate,
    this.durationMinutes = 45,
    required this.exerciseLogs,
    this.overallNotes = '',
  });

  int get totalCompletedSets =>
      exerciseLogs.fold(0, (sum, e) => sum + e.completedSets);

  int get totalCompletedReps =>
      exerciseLogs.fold(0, (sum, e) => sum + e.totalReps);

  double get totalVolumeKg =>
      exerciseLogs.fold(0.0, (sum, e) => sum + e.totalVolume);

  Map<String, dynamic> toJson() => {
        'id': id,
        'scheduleId': scheduleId,
        'scheduleTitle': scheduleTitle,
        'completedDate': completedDate.toIso8601String(),
        'durationMinutes': durationMinutes,
        'exerciseLogs': exerciseLogs.map((e) => e.toJson()).toList(),
        'overallNotes': overallNotes,
      };

  factory WorkoutLog.fromJson(Map<String, dynamic> json) => WorkoutLog(
        id: json['id'] as String? ?? '',
        scheduleId: json['scheduleId'] as String? ?? '',
        scheduleTitle: json['scheduleTitle'] as String? ?? 'Workout Session',
        completedDate: json['completedDate'] != null
            ? DateTime.tryParse(json['completedDate'] as String) ??
                DateTime.now()
            : DateTime.now(),
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 45,
        exerciseLogs: (json['exerciseLogs'] as List<dynamic>?)
                ?.map((e) =>
                    ExerciseCompletionLog.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        overallNotes: json['overallNotes'] as String? ?? '',
      );
}
