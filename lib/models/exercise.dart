class Exercise {
  final String id;
  final String name;
  final String targetMuscle;
  final bool isTimeBased; // True for Plank, Wall Sit, Static Holds
  final int defaultSets;
  final int defaultReps;
  final int defaultTimeSeconds; // In seconds (e.g. 60s)
  final double defaultWeightKg;
  final String notes;

  // Superset (paired back-to-back exercise in 1 set)
  final bool isSuperset;
  final String? supersetName;
  final String? supersetTargetMuscle;
  final bool supersetIsTimeBased;
  final int? supersetReps;
  final int? supersetTimeSeconds;
  final double? supersetWeightKg;

  Exercise({
    required this.id,
    required this.name,
    this.targetMuscle = 'General',
    this.isTimeBased = false,
    this.defaultSets = 3,
    this.defaultReps = 10,
    this.defaultTimeSeconds = 60,
    this.defaultWeightKg = 0.0,
    this.notes = '',
    this.isSuperset = false,
    this.supersetName,
    this.supersetTargetMuscle,
    this.supersetIsTimeBased = false,
    this.supersetReps = 10,
    this.supersetTimeSeconds = 60,
    this.supersetWeightKg = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetMuscle': targetMuscle,
        'isTimeBased': isTimeBased,
        'defaultSets': defaultSets,
        'defaultReps': defaultReps,
        'defaultTimeSeconds': defaultTimeSeconds,
        'defaultWeightKg': defaultWeightKg,
        'notes': notes,
        'isSuperset': isSuperset,
        'supersetName': supersetName,
        'supersetTargetMuscle': supersetTargetMuscle,
        'supersetIsTimeBased': supersetIsTimeBased,
        'supersetReps': supersetReps,
        'supersetTimeSeconds': supersetTimeSeconds,
        'supersetWeightKg': supersetWeightKg,
      };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Exercise',
        targetMuscle: json['targetMuscle'] as String? ?? 'General',
        isTimeBased: json['isTimeBased'] as bool? ?? false,
        defaultSets: (json['defaultSets'] as num?)?.toInt() ?? 3,
        defaultReps: (json['defaultReps'] as num?)?.toInt() ?? 10,
        defaultTimeSeconds:
            (json['defaultTimeSeconds'] as num?)?.toInt() ?? 60,
        defaultWeightKg: (json['defaultWeightKg'] as num?)?.toDouble() ?? 0.0,
        notes: json['notes'] as String? ?? '',
        isSuperset: json['isSuperset'] as bool? ?? false,
        supersetName: json['supersetName'] as String?,
        supersetTargetMuscle: json['supersetTargetMuscle'] as String?,
        supersetIsTimeBased: json['supersetIsTimeBased'] as bool? ?? false,
        supersetReps: (json['supersetReps'] as num?)?.toInt() ?? 10,
        supersetTimeSeconds:
            (json['supersetTimeSeconds'] as num?)?.toInt() ?? 60,
        supersetWeightKg:
            (json['supersetWeightKg'] as num?)?.toDouble() ?? 0.0,
      );

  Exercise copyWith({
    String? id,
    String? name,
    String? targetMuscle,
    bool? isTimeBased,
    int? defaultSets,
    int? defaultReps,
    int? defaultTimeSeconds,
    double? defaultWeightKg,
    String? notes,
    bool? isSuperset,
    String? supersetName,
    String? supersetTargetMuscle,
    bool? supersetIsTimeBased,
    int? supersetReps,
    int? supersetTimeSeconds,
    double? supersetWeightKg,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      targetMuscle: targetMuscle ?? this.targetMuscle,
      isTimeBased: isTimeBased ?? this.isTimeBased,
      defaultSets: defaultSets ?? this.defaultSets,
      defaultReps: defaultReps ?? this.defaultReps,
      defaultTimeSeconds: defaultTimeSeconds ?? this.defaultTimeSeconds,
      defaultWeightKg: defaultWeightKg ?? this.defaultWeightKg,
      notes: notes ?? this.notes,
      isSuperset: isSuperset ?? this.isSuperset,
      supersetName: supersetName ?? this.supersetName,
      supersetTargetMuscle: supersetTargetMuscle ?? this.supersetTargetMuscle,
      supersetIsTimeBased: supersetIsTimeBased ?? this.supersetIsTimeBased,
      supersetReps: supersetReps ?? this.supersetReps,
      supersetTimeSeconds: supersetTimeSeconds ?? this.supersetTimeSeconds,
      supersetWeightKg: supersetWeightKg ?? this.supersetWeightKg,
    );
  }
}
