import 'exercise.dart';

class WorkoutSchedule {
  final String id;
  final String title;
  final String description;
  final String colorHex;
  final List<String> scheduledDays;
  final List<Exercise> exercises;
  final DateTime createdAt;

  WorkoutSchedule({
    required this.id,
    required this.title,
    this.description = '',
    this.colorHex = '#10B981', // Default emerald green
    this.scheduledDays = const [],
    this.exercises = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'colorHex': colorHex,
        'scheduledDays': scheduledDays,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory WorkoutSchedule.fromJson(Map<String, dynamic> json) =>
      WorkoutSchedule(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Workout Routine',
        description: json['description'] as String? ?? '',
        colorHex: json['colorHex'] as String? ?? '#10B981',
        scheduledDays: (json['scheduledDays'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        exercises: (json['exercises'] as List<dynamic>?)
                ?.map((e) => Exercise.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  WorkoutSchedule copyWith({
    String? id,
    String? title,
    String? description,
    String? colorHex,
    List<String>? scheduledDays,
    List<Exercise>? exercises,
    DateTime? createdAt,
  }) {
    return WorkoutSchedule(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      colorHex: colorHex ?? this.colorHex,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      exercises: exercises ?? this.exercises,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
