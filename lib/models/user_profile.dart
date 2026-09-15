class UserProfile {
  final double? bodyWeightKg;
  final int? age;
  final String trainingGoal;
  final String experienceLevel;
  final String geminiApiKey;
  final String? lastAiAnalysis;
  final DateTime? lastAiAnalysisDate;

  const UserProfile({
    this.bodyWeightKg,
    this.age,
    this.trainingGoal = 'Hypertrophy & Muscle Building',
    this.experienceLevel = 'Intermediate',
    this.geminiApiKey = '',
    this.lastAiAnalysis,
    this.lastAiAnalysisDate,
  });

  UserProfile copyWith({
    double? bodyWeightKg,
    int? age,
    String? trainingGoal,
    String? experienceLevel,
    String? geminiApiKey,
    String? lastAiAnalysis,
    DateTime? lastAiAnalysisDate,
  }) {
    return UserProfile(
      bodyWeightKg: bodyWeightKg ?? this.bodyWeightKg,
      age: age ?? this.age,
      trainingGoal: trainingGoal ?? this.trainingGoal,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      lastAiAnalysis: lastAiAnalysis ?? this.lastAiAnalysis,
      lastAiAnalysisDate: lastAiAnalysisDate ?? this.lastAiAnalysisDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bodyWeightKg': bodyWeightKg,
      'age': age,
      'trainingGoal': trainingGoal,
      'experienceLevel': experienceLevel,
      'geminiApiKey': geminiApiKey,
      'lastAiAnalysis': lastAiAnalysis,
      'lastAiAnalysisDate': lastAiAnalysisDate?.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      bodyWeightKg: json['bodyWeightKg'] != null
          ? (json['bodyWeightKg'] as num).toDouble()
          : null,
      age: json['age'] as int?,
      trainingGoal: json['trainingGoal'] as String? ??
          'Hypertrophy & Muscle Building',
      experienceLevel:
          json['experienceLevel'] as String? ?? 'Intermediate',
      geminiApiKey: json['geminiApiKey'] as String? ?? '',
      lastAiAnalysis: json['lastAiAnalysis'] as String?,
      lastAiAnalysisDate: json['lastAiAnalysisDate'] != null
          ? DateTime.tryParse(json['lastAiAnalysisDate'] as String)
          : null,
    );
  }
}
