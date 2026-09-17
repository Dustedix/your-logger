class UserProfile {
  final double? bodyWeightKg;
  final double? heightCm;
  final String gender; // 'Male' or 'Female'
  final int? age;
  final String trainingGoal;
  final String experienceLevel;
  final String geminiApiKey;
  final String? lastAiAnalysis;
  final DateTime? lastAiAnalysisDate;

  const UserProfile({
    this.bodyWeightKg,
    this.heightCm,
    this.gender = 'Male',
    this.age,
    this.trainingGoal = 'Hypertrophy & Muscle Building',
    this.experienceLevel = 'Intermediate',
    this.geminiApiKey = '',
    this.lastAiAnalysis,
    this.lastAiAnalysisDate,
  });

  UserProfile copyWith({
    double? bodyWeightKg,
    double? heightCm,
    String? gender,
    int? age,
    String? trainingGoal,
    String? experienceLevel,
    String? geminiApiKey,
    String? lastAiAnalysis,
    DateTime? lastAiAnalysisDate,
  }) {
    return UserProfile(
      bodyWeightKg: bodyWeightKg ?? this.bodyWeightKg,
      heightCm: heightCm ?? this.heightCm,
      gender: gender ?? this.gender,
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
      'heightCm': heightCm,
      'gender': gender,
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
      heightCm: json['heightCm'] != null
          ? (json['heightCm'] as num).toDouble()
          : null,
      gender: json['gender'] as String? ?? 'Male',
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
