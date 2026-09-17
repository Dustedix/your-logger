import 'exercise.dart';

class SubMovementSetLog {
  String? movementId;
  String? name;
  String? targetMuscle;
  bool isTimeBased;
  int reps;
  int timeSeconds;
  double weightKg;
  bool completed;
  bool isPersonalRecord;

  SubMovementSetLog({
    this.movementId,
    this.name,
    this.targetMuscle,
    this.isTimeBased = false,
    this.reps = 10,
    this.timeSeconds = 60,
    this.weightKg = 0.0,
    this.completed = true,
    this.isPersonalRecord = false,
  });

  Map<String, dynamic> toJson() => {
        if (movementId != null) 'movementId': movementId,
        if (name != null) 'name': name,
        if (targetMuscle != null) 'targetMuscle': targetMuscle,
        'isTimeBased': isTimeBased,
        'reps': reps,
        'timeSeconds': timeSeconds,
        'weightKg': weightKg,
        'completed': completed,
        'isPersonalRecord': isPersonalRecord,
      };

  factory SubMovementSetLog.fromJson(Map<String, dynamic> json) =>
      SubMovementSetLog(
        movementId: json['movementId'] as String?,
        name: json['name'] as String?,
        targetMuscle: json['targetMuscle'] as String?,
        isTimeBased: json['isTimeBased'] as bool? ?? false,
        reps: (json['reps'] as num?)?.toInt() ?? 10,
        timeSeconds: (json['timeSeconds'] as num?)?.toInt() ?? 60,
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0.0,
        completed: json['completed'] as bool? ?? true,
        isPersonalRecord: json['isPersonalRecord'] as bool? ?? false,
      );

  SubMovementSetLog copy() => SubMovementSetLog(
        movementId: movementId,
        name: name,
        targetMuscle: targetMuscle,
        isTimeBased: isTimeBased,
        reps: reps,
        timeSeconds: timeSeconds,
        weightKg: weightKg,
        completed: completed,
        isPersonalRecord: isPersonalRecord,
      );
}

class ExerciseSetLog {
  int setNumber;
  int reps;
  int timeSeconds; // For time-based exercises like Plank
  double weightKg;
  bool completed;
  bool isPersonalRecord;

  // Multi-movement paired metrics (Movement 2, Movement 3, etc.)
  List<SubMovementSetLog> subMovements;

  ExerciseSetLog({
    required this.setNumber,
    this.reps = 10,
    this.timeSeconds = 60,
    this.weightKg = 0.0,
    this.completed = true,
    this.isPersonalRecord = false,
    List<SubMovementSetLog>? subMovements,
    // Legacy single paired fields for backward compatibility
    int? supersetReps,
    int? supersetTimeSeconds,
    double? supersetWeightKg,
    bool? supersetIsPersonalRecord,
  }) : subMovements = subMovements ??
            (supersetReps != null ||
                    supersetWeightKg != null ||
                    supersetTimeSeconds != null ||
                    (supersetIsPersonalRecord ?? false)
                ? [
                    SubMovementSetLog(
                      reps: supersetReps ?? 10,
                      timeSeconds: supersetTimeSeconds ?? 60,
                      weightKg: supersetWeightKg ?? 0.0,
                      isPersonalRecord: supersetIsPersonalRecord ?? false,
                    )
                  ]
                : []);

  // Backward-compatible getters and setters for Movement 2
  int get supersetReps =>
      subMovements.isNotEmpty ? subMovements.first.reps : 10;
  set supersetReps(int val) {
    if (subMovements.isEmpty) {
      subMovements.add(SubMovementSetLog(reps: val));
    } else {
      subMovements.first.reps = val;
    }
  }

  int get supersetTimeSeconds =>
      subMovements.isNotEmpty ? subMovements.first.timeSeconds : 60;
  set supersetTimeSeconds(int val) {
    if (subMovements.isEmpty) {
      subMovements.add(SubMovementSetLog(timeSeconds: val));
    } else {
      subMovements.first.timeSeconds = val;
    }
  }

  double get supersetWeightKg =>
      subMovements.isNotEmpty ? subMovements.first.weightKg : 0.0;
  set supersetWeightKg(double val) {
    if (subMovements.isEmpty) {
      subMovements.add(SubMovementSetLog(weightKg: val));
    } else {
      subMovements.first.weightKg = val;
    }
  }

  bool get supersetIsPersonalRecord =>
      subMovements.isNotEmpty ? subMovements.first.isPersonalRecord : false;
  set supersetIsPersonalRecord(bool val) {
    if (subMovements.isEmpty) {
      subMovements.add(SubMovementSetLog(isPersonalRecord: val));
    } else {
      subMovements.first.isPersonalRecord = val;
    }
  }

  Map<String, dynamic> toJson() => {
        'setNumber': setNumber,
        'reps': reps,
        'timeSeconds': timeSeconds,
        'weightKg': weightKg,
        'completed': completed,
        'isPersonalRecord': isPersonalRecord,
        'subMovements': subMovements.map((s) => s.toJson()).toList(),
        // Legacy keys for backward compatibility
        'supersetReps': supersetReps,
        'supersetTimeSeconds': supersetTimeSeconds,
        'supersetWeightKg': supersetWeightKg,
        'supersetIsPersonalRecord': supersetIsPersonalRecord,
      };

  factory ExerciseSetLog.fromJson(Map<String, dynamic> json) {
    List<SubMovementSetLog> subMovements = [];
    if (json['subMovements'] != null && json['subMovements'] is List) {
      subMovements = (json['subMovements'] as List)
          .map((s) => SubMovementSetLog.fromJson(s as Map<String, dynamic>))
          .toList();
    } else if (json['supersetReps'] != null ||
        json['supersetWeightKg'] != null) {
      subMovements = [
        SubMovementSetLog(
          reps: (json['supersetReps'] as num?)?.toInt() ?? 10,
          timeSeconds: (json['supersetTimeSeconds'] as num?)?.toInt() ?? 60,
          weightKg: (json['supersetWeightKg'] as num?)?.toDouble() ?? 0.0,
          isPersonalRecord:
              json['supersetIsPersonalRecord'] as bool? ?? false,
        )
      ];
    }

    return ExerciseSetLog(
      setNumber: (json['setNumber'] as num?)?.toInt() ?? 1,
      reps: (json['reps'] as num?)?.toInt() ?? 10,
      timeSeconds: (json['timeSeconds'] as num?)?.toInt() ?? 60,
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0.0,
      completed: json['completed'] as bool? ?? true,
      isPersonalRecord: json['isPersonalRecord'] as bool? ?? false,
      subMovements: subMovements,
    );
  }

  ExerciseSetLog copy() => ExerciseSetLog(
        setNumber: setNumber,
        reps: reps,
        timeSeconds: timeSeconds,
        weightKg: weightKg,
        completed: completed,
        isPersonalRecord: isPersonalRecord,
        subMovements: subMovements.map((s) => s.copy()).toList(),
      );
}

class ExerciseCompletionLog {
  final String exerciseId;
  final String exerciseName;
  final String targetMuscle;
  final bool isTimeBased;
  final List<ExerciseSetLog> sets;
  final String notes;

  // Superset / Tri-Set / Giant Set support
  final bool isSuperset;
  final List<SupersetMovement> supersetMovements;

  final String? _legacySupersetName;
  final String? _legacySupersetTargetMuscle;
  final bool _legacySupersetIsTimeBased;

  ExerciseCompletionLog({
    required this.exerciseId,
    required this.exerciseName,
    this.targetMuscle = 'General',
    this.isTimeBased = false,
    required this.sets,
    this.notes = '',
    this.isSuperset = false,
    List<SupersetMovement>? supersetMovements,
    String? supersetName,
    String? supersetTargetMuscle,
    bool supersetIsTimeBased = false,
  })  : _legacySupersetName = supersetName,
        _legacySupersetTargetMuscle = supersetTargetMuscle,
        _legacySupersetIsTimeBased = supersetIsTimeBased,
        supersetMovements = supersetMovements ??
            (isSuperset && supersetName != null && supersetName.isNotEmpty
                ? [
                    SupersetMovement(
                      id: '${exerciseId}_sub_1',
                      name: supersetName,
                      targetMuscle: supersetTargetMuscle ?? 'General',
                      isTimeBased: supersetIsTimeBased,
                    )
                  ]
                : const []);

  // Backward-compatible getters
  String? get supersetName => supersetMovements.isNotEmpty
      ? supersetMovements.first.name
      : _legacySupersetName;

  String? get supersetTargetMuscle => supersetMovements.isNotEmpty
      ? supersetMovements.first.targetMuscle
      : _legacySupersetTargetMuscle;

  bool get supersetIsTimeBased => supersetMovements.isNotEmpty
      ? supersetMovements.first.isTimeBased
      : _legacySupersetIsTimeBased;

  List<String> get allExerciseNames => [
        exerciseName,
        ...supersetMovements.map((m) => m.name),
      ];

  int get totalMovements => 1 + supersetMovements.length;

  String get supersetBadgeTitle {
    if (!isSuperset || supersetMovements.isEmpty) return 'Superset';
    final count = totalMovements;
    if (count == 2) return 'Superset';
    if (count == 3) return 'Tri-Set';
    return 'Giant Set ($count)';
  }

  int get totalReps => sets.fold(0, (sum, s) {
        if (!s.completed) return sum;
        int count = !isTimeBased ? s.reps : 0;
        for (int i = 0; i < s.subMovements.length; i++) {
          final isTime = i < supersetMovements.length
              ? supersetMovements[i].isTimeBased
              : false;
          if (!isTime) {
            count += s.subMovements[i].reps;
          }
        }
        return sum + count;
      });

  int get totalTimeSeconds => sets.fold(0, (sum, s) {
        if (!s.completed) return sum;
        int count = isTimeBased ? s.timeSeconds : 0;
        for (int i = 0; i < s.subMovements.length; i++) {
          final isTime = i < supersetMovements.length
              ? supersetMovements[i].isTimeBased
              : false;
          if (isTime) {
            count += s.subMovements[i].timeSeconds;
          }
        }
        return sum + count;
      });

  int get completedSets => sets.where((s) => s.completed).length;

  bool get hasPersonalRecord => sets.any((s) =>
      s.isPersonalRecord || s.subMovements.any((sub) => sub.isPersonalRecord));

  double get totalVolume => sets.fold(0.0, (sum, s) {
        if (!s.completed) return sum;
        double v = !isTimeBased ? (s.reps * s.weightKg) : 0.0;
        for (int i = 0; i < s.subMovements.length; i++) {
          final isTime = i < supersetMovements.length
              ? supersetMovements[i].isTimeBased
              : false;
          if (!isTime) {
            v += (s.subMovements[i].reps * s.subMovements[i].weightKg);
          }
        }
        return sum + v;
      });

  String formatSetText(ExerciseSetLog s) {
    final parts = <String>[];
    if (isTimeBased) {
      final sec = s.timeSeconds;
      final timeStr = sec >= 60
          ? '${sec ~/ 60}m${sec % 60 > 0 ? " ${sec % 60}s" : ""}'
          : '${sec}s';
      final weightStr = s.weightKg > 0 ? ' (+${s.weightKg}kg)' : '';
      parts.add('$timeStr$weightStr');
    } else {
      final weightStr = s.weightKg > 0 ? ' @ ${s.weightKg}kg' : '';
      parts.add('${s.reps} reps$weightStr');
    }

    if (isSuperset) {
      for (int i = 0; i < s.subMovements.length; i++) {
        final subSet = s.subMovements[i];
        final isTime = i < supersetMovements.length
            ? supersetMovements[i].isTimeBased
            : false;
        if (isTime) {
          final sec = subSet.timeSeconds;
          final timeStr = sec >= 60
              ? '${sec ~/ 60}m${sec % 60 > 0 ? " ${sec % 60}s" : ""}'
              : '${sec}s';
          final weightStr =
              subSet.weightKg > 0 ? ' (+${subSet.weightKg}kg)' : '';
          parts.add('$timeStr$weightStr');
        } else {
          final weightStr =
              subSet.weightKg > 0 ? ' @ ${subSet.weightKg}kg' : '';
          parts.add('${subSet.reps} reps$weightStr');
        }
      }
    }

    return parts.join(' + ');
  }

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'targetMuscle': targetMuscle,
        'isTimeBased': isTimeBased,
        'sets': sets.map((s) => s.toJson()).toList(),
        'notes': notes,
        'isSuperset': isSuperset,
        'supersetMovements':
            supersetMovements.map((m) => m.toJson()).toList(),
        // Legacy keys
        'supersetName': supersetName,
        'supersetTargetMuscle': supersetTargetMuscle,
        'supersetIsTimeBased': supersetIsTimeBased,
      };

  factory ExerciseCompletionLog.fromJson(Map<String, dynamic> json) {
    final isSup = json['isSuperset'] as bool? ?? false;
    List<SupersetMovement> movements = [];

    if (json['supersetMovements'] != null &&
        json['supersetMovements'] is List) {
      movements = (json['supersetMovements'] as List)
          .map((m) => SupersetMovement.fromJson(m as Map<String, dynamic>))
          .toList();
    } else if (isSup && json['supersetName'] != null) {
      movements = [
        SupersetMovement(
          id: '${json['exerciseId'] ?? "ex"}_sub_1',
          name: json['supersetName'] as String? ?? 'Movement 2',
          targetMuscle:
              json['supersetTargetMuscle'] as String? ?? 'General',
          isTimeBased: json['supersetIsTimeBased'] as bool? ?? false,
        )
      ];
    }

    return ExerciseCompletionLog(
      exerciseId: json['exerciseId'] as String? ?? '',
      exerciseName: json['exerciseName'] as String? ?? 'Exercise',
      targetMuscle: json['targetMuscle'] as String? ?? 'General',
      isTimeBased: json['isTimeBased'] as bool? ?? false,
      sets: (json['sets'] as List<dynamic>?)
              ?.map((s) => ExerciseSetLog.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes'] as String? ?? '',
      isSuperset: isSup,
      supersetMovements: movements,
      supersetName: json['supersetName'] as String?,
      supersetTargetMuscle: json['supersetTargetMuscle'] as String?,
      supersetIsTimeBased: json['supersetIsTimeBased'] as bool? ?? false,
    );
  }
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

  bool get hasPersonalRecord => exerciseLogs.any((e) => e.hasPersonalRecord);

  List<String> get prExerciseNames {
    final list = <String>[];
    for (final e in exerciseLogs) {
      if (e.sets.any((s) => s.isPersonalRecord)) {
        list.add(e.exerciseName);
      }
      if (e.isSuperset) {
        for (int i = 0; i < e.supersetMovements.length; i++) {
          final name = e.supersetMovements[i].name;
          if (e.sets.any((s) =>
              i < s.subMovements.length && s.subMovements[i].isPersonalRecord)) {
            list.add(name);
          }
        }
      }
    }
    return list;
  }

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
