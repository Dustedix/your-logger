class SupersetMovement {
  final String id;
  final String name;
  final String targetMuscle;
  final bool isTimeBased;
  final int defaultReps;
  final int defaultTimeSeconds;
  final double defaultWeightKg;

  const SupersetMovement({
    required this.id,
    required this.name,
    this.targetMuscle = 'General',
    this.isTimeBased = false,
    this.defaultReps = 10,
    this.defaultTimeSeconds = 60,
    this.defaultWeightKg = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetMuscle': targetMuscle,
        'isTimeBased': isTimeBased,
        'defaultReps': defaultReps,
        'defaultTimeSeconds': defaultTimeSeconds,
        'defaultWeightKg': defaultWeightKg,
      };

  factory SupersetMovement.fromJson(Map<String, dynamic> json) =>
      SupersetMovement(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Movement',
        targetMuscle: json['targetMuscle'] as String? ?? 'General',
        isTimeBased: json['isTimeBased'] as bool? ?? false,
        defaultReps: (json['defaultReps'] as num?)?.toInt() ?? 10,
        defaultTimeSeconds:
            (json['defaultTimeSeconds'] as num?)?.toInt() ?? 60,
        defaultWeightKg: (json['defaultWeightKg'] as num?)?.toDouble() ?? 0.0,
      );

  SupersetMovement copyWith({
    String? id,
    String? name,
    String? targetMuscle,
    bool? isTimeBased,
    int? defaultReps,
    int? defaultTimeSeconds,
    double? defaultWeightKg,
  }) =>
      SupersetMovement(
        id: id ?? this.id,
        name: name ?? this.name,
        targetMuscle: targetMuscle ?? this.targetMuscle,
        isTimeBased: isTimeBased ?? this.isTimeBased,
        defaultReps: defaultReps ?? this.defaultReps,
        defaultTimeSeconds: defaultTimeSeconds ?? this.defaultTimeSeconds,
        defaultWeightKg: defaultWeightKg ?? this.defaultWeightKg,
      );
}

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

  // Superset / Tri-Set / Giant Set support (any number of paired movements)
  final bool isSuperset;
  final List<SupersetMovement> supersetMovements;

  final String? _legacySupersetName;
  final String? _legacySupersetTargetMuscle;
  final bool _legacySupersetIsTimeBased;
  final int? _legacySupersetReps;
  final int? _legacySupersetTimeSeconds;
  final double? _legacySupersetWeightKg;

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
    List<SupersetMovement>? supersetMovements,
    String? supersetName,
    String? supersetTargetMuscle,
    bool supersetIsTimeBased = false,
    int? supersetReps,
    int? supersetTimeSeconds,
    double? supersetWeightKg,
  })  : _legacySupersetName = supersetName,
        _legacySupersetTargetMuscle = supersetTargetMuscle,
        _legacySupersetIsTimeBased = supersetIsTimeBased,
        _legacySupersetReps = supersetReps,
        _legacySupersetTimeSeconds = supersetTimeSeconds,
        _legacySupersetWeightKg = supersetWeightKg,
        supersetMovements = supersetMovements ??
            (isSuperset && supersetName != null && supersetName.isNotEmpty
                ? [
                    SupersetMovement(
                      id: '${id}_sub_1',
                      name: supersetName,
                      targetMuscle: supersetTargetMuscle ?? 'General',
                      isTimeBased: supersetIsTimeBased,
                      defaultReps: supersetReps ?? 10,
                      defaultTimeSeconds: supersetTimeSeconds ?? 60,
                      defaultWeightKg: supersetWeightKg ?? 0.0,
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

  int? get supersetReps => supersetMovements.isNotEmpty
      ? supersetMovements.first.defaultReps
      : _legacySupersetReps;

  int? get supersetTimeSeconds => supersetMovements.isNotEmpty
      ? supersetMovements.first.defaultTimeSeconds
      : _legacySupersetTimeSeconds;

  double? get supersetWeightKg => supersetMovements.isNotEmpty
      ? supersetMovements.first.defaultWeightKg
      : _legacySupersetWeightKg;

  int get totalMovements => 1 + supersetMovements.length;

  String get supersetBadgeTitle {
    if (!isSuperset || supersetMovements.isEmpty) return 'Superset';
    final count = totalMovements;
    if (count == 2) return 'Superset';
    if (count == 3) return 'Tri-Set';
    return 'Giant Set ($count)';
  }

  List<String> get allExerciseNames => [
        name,
        ...supersetMovements.map((m) => m.name),
      ];

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
        'supersetMovements':
            supersetMovements.map((m) => m.toJson()).toList(),
        // Legacy fields for backward compatibility
        'supersetName': supersetName,
        'supersetTargetMuscle': supersetTargetMuscle,
        'supersetIsTimeBased': supersetIsTimeBased,
        'supersetReps': supersetReps,
        'supersetTimeSeconds': supersetTimeSeconds,
        'supersetWeightKg': supersetWeightKg,
      };

  factory Exercise.fromJson(Map<String, dynamic> json) {
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
          id: '${json['id'] ?? "ex"}_sub_1',
          name: json['supersetName'] as String? ?? 'Movement 2',
          targetMuscle:
              json['supersetTargetMuscle'] as String? ?? 'General',
          isTimeBased: json['supersetIsTimeBased'] as bool? ?? false,
          defaultReps: (json['supersetReps'] as num?)?.toInt() ?? 10,
          defaultTimeSeconds:
              (json['supersetTimeSeconds'] as num?)?.toInt() ?? 60,
          defaultWeightKg:
              (json['supersetWeightKg'] as num?)?.toDouble() ?? 0.0,
        )
      ];
    }

    return Exercise(
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
      isSuperset: isSup,
      supersetMovements: movements,
      supersetName: json['supersetName'] as String?,
      supersetTargetMuscle: json['supersetTargetMuscle'] as String?,
      supersetIsTimeBased: json['supersetIsTimeBased'] as bool? ?? false,
      supersetReps: (json['supersetReps'] as num?)?.toInt() ?? 10,
      supersetTimeSeconds:
          (json['supersetTimeSeconds'] as num?)?.toInt() ?? 60,
      supersetWeightKg:
          (json['supersetWeightKg'] as num?)?.toDouble() ?? 0.0,
    );
  }

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
    List<SupersetMovement>? supersetMovements,
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
      supersetMovements: supersetMovements ?? this.supersetMovements,
      supersetName: supersetName ?? this.supersetName,
      supersetTargetMuscle:
          supersetTargetMuscle ?? this.supersetTargetMuscle,
      supersetIsTimeBased: supersetIsTimeBased ?? this.supersetIsTimeBased,
      supersetReps: supersetReps ?? this.supersetReps,
      supersetTimeSeconds:
          supersetTimeSeconds ?? this.supersetTimeSeconds,
      supersetWeightKg: supersetWeightKg ?? this.supersetWeightKg,
    );
  }
}
