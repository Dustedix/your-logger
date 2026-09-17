import 'dart:math' as math;

class BodyMetricLog {
  final String id;
  final DateTime date;
  final double weightKg;
  final double? bodyFatPercentage;
  final double? neckCm;
  final double? waistCm;
  final double? hipCm;
  final String notes;

  const BodyMetricLog({
    required this.id,
    required this.date,
    required this.weightKg,
    this.bodyFatPercentage,
    this.neckCm,
    this.waistCm,
    this.hipCm,
    this.notes = '',
  });

  /// Fat Mass in kg: weightKg * (bodyFatPercentage / 100)
  double? get fatMassKg {
    if (bodyFatPercentage == null || bodyFatPercentage! <= 0) return null;
    return weightKg * (bodyFatPercentage! / 100.0);
  }

  /// Lean Body Mass (LBM) in kg: weightKg - fatMassKg
  double? get leanMassKg {
    final fm = fatMassKg;
    if (fm == null) return null;
    return weightKg - fm;
  }

  /// Body Mass Index (BMI)
  double? calculateBmi(double? heightCm) {
    if (heightCm == null || heightCm <= 0) return null;
    final heightM = heightCm / 100.0;
    return weightKg / (heightM * heightM);
  }

  /// Calculates Body Fat % for Men using the US Navy Circumference Method.
  /// Height, waist, and neck are in centimeters.
  static double? calculateNavyBodyFatMen({
    required double heightCm,
    required double waistCm,
    required double neckCm,
  }) {
    if (heightCm <= 0 || waistCm <= 0 || neckCm <= 0) return null;
    final diff = waistCm - neckCm;
    if (diff <= 0) return null;

    final logDiff = math.log(diff) / math.ln10;
    final logHeight = math.log(heightCm) / math.ln10;

    final denom = 1.0324 - (0.19077 * logDiff) + (0.15456 * logHeight);
    if (denom <= 0) return null;

    final bf = (495.0 / denom) - 450.0;
    return bf.clamp(3.0, 65.0);
  }

  /// Calculates Body Fat % for Women using the US Navy Circumference Method.
  /// Height, waist, neck, and hips are in centimeters.
  static double? calculateNavyBodyFatWomen({
    required double heightCm,
    required double waistCm,
    required double neckCm,
    required double hipCm,
  }) {
    if (heightCm <= 0 || waistCm <= 0 || neckCm <= 0 || hipCm <= 0) return null;
    final sumDiff = waistCm + hipCm - neckCm;
    if (sumDiff <= 0) return null;

    final logSumDiff = math.log(sumDiff) / math.ln10;
    final logHeight = math.log(heightCm) / math.ln10;

    final denom = 1.29579 - (0.35004 * logSumDiff) + (0.22100 * logHeight);
    if (denom <= 0) return null;

    final bf = (495.0 / denom) - 450.0;
    return bf.clamp(8.0, 65.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'weightKg': weightKg,
        'bodyFatPercentage': bodyFatPercentage,
        'neckCm': neckCm,
        'waistCm': waistCm,
        'hipCm': hipCm,
        'notes': notes,
      };

  factory BodyMetricLog.fromJson(Map<String, dynamic> json) => BodyMetricLog(
        id: json['id'] as String? ?? '',
        date: json['date'] != null
            ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
            : DateTime.now(),
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0.0,
        bodyFatPercentage: (json['bodyFatPercentage'] as num?)?.toDouble(),
        neckCm: (json['neckCm'] as num?)?.toDouble(),
        waistCm: (json['waistCm'] as num?)?.toDouble(),
        hipCm: (json['hipCm'] as num?)?.toDouble(),
        notes: json['notes'] as String? ?? '',
      );
}
