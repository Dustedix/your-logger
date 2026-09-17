import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_app/models/body_metric_log.dart';
import 'package:workout_app/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BodyMetricLog Math & US Navy Formula', () {
    test('Calculates Fat Mass and Lean Mass accurately', () {
      final log = BodyMetricLog(
        id: 'metric-1',
        date: DateTime(2026, 9, 15),
        weightKg: 80.0,
        bodyFatPercentage: 15.0,
      );

      // Fat mass: 80 * 0.15 = 12.0 kg
      expect(log.fatMassKg, 12.0);
      // Lean mass: 80 - 12 = 68.0 kg
      expect(log.leanMassKg, 68.0);
    });

    test('Lean Mass is null when body fat % is not provided', () {
      final log = BodyMetricLog(
        id: 'metric-2',
        date: DateTime(2026, 9, 15),
        weightKg: 75.0,
      );

      expect(log.fatMassKg, isNull);
      expect(log.leanMassKg, isNull);
    });

    test('US Navy formula for Men produces standard military estimate', () {
      // Standard reference: Height 178cm, Waist 84cm, Neck 38cm -> ~15.6%
      final bf = BodyMetricLog.calculateNavyBodyFatMen(
        heightCm: 178.0,
        waistCm: 84.0,
        neckCm: 38.0,
      );

      expect(bf, isNotNull);
      expect(bf!, closeTo(15.6, 0.5));
    });

    test('US Navy formula for Men returns null for impossible measurements', () {
      final bf = BodyMetricLog.calculateNavyBodyFatMen(
        heightCm: 180.0,
        waistCm: 35.0,
        neckCm: 40.0, // waist < neck
      );

      expect(bf, isNull);
    });

    test('US Navy formula for Women produces valid body fat estimate', () {
      // Standard reference: Height 165cm, Waist 70cm, Neck 34cm, Hips 96cm -> ~24.5%
      final bf = BodyMetricLog.calculateNavyBodyFatWomen(
        heightCm: 165.0,
        waistCm: 70.0,
        neckCm: 34.0,
        hipCm: 96.0,
      );

      expect(bf, isNotNull);
      expect(bf!, closeTo(24.5, 1.0));
    });

    test('BMI calculation computes weight / height^2', () {
      final log = BodyMetricLog(
        id: 'metric-bmi',
        date: DateTime.now(),
        weightKg: 72.0,
      );

      // 72 / (1.75 * 1.75) = 72 / 3.0625 = 23.51
      final bmi = log.calculateBmi(175.0);
      expect(bmi, isNotNull);
      expect(bmi!, closeTo(23.51, 0.05));
    });
  });

  group('StorageService Body Metrics Management', () {
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init('test_user');
      await storage.clearAllBodyMetrics();
    });

    test('Saves and retrieves body metrics sorted by date descending', () async {
      final m1 = BodyMetricLog(
        id: 'm1',
        date: DateTime(2026, 9, 10),
        weightKg: 75.0,
        bodyFatPercentage: 17.0,
      );
      final m2 = BodyMetricLog(
        id: 'm2',
        date: DateTime(2026, 9, 15),
        weightKg: 74.2,
        bodyFatPercentage: 16.5,
      );

      await storage.saveBodyMetric(m1);
      await storage.saveBodyMetric(m2);

      final metrics = storage.getBodyMetrics();
      expect(metrics.length, 2);
      expect(metrics[0].id, 'm2'); // Newer date first
      expect(metrics[1].id, 'm1');

      final latest = storage.getLatestBodyMetric();
      expect(latest?.id, 'm2');
      expect(latest?.weightKg, 74.2);
    });

    test('Syncs user profile bodyWeightKg when saving a metric', () async {
      final m = BodyMetricLog(
        id: 'm-sync',
        date: DateTime.now(),
        weightKg: 78.5,
      );

      await storage.saveBodyMetric(m);
      final profile = storage.getProfile();
      expect(profile.bodyWeightKg, 78.5);
    });

    test('Computes 7-day rolling weight average correctly', () async {
      final now = DateTime.now();
      await storage.saveBodyMetric(BodyMetricLog(
        id: 'w1',
        date: now.subtract(const Duration(days: 2)),
        weightKg: 75.0,
      ));
      await storage.saveBodyMetric(BodyMetricLog(
        id: 'w2',
        date: now.subtract(const Duration(days: 1)),
        weightKg: 74.0,
      ));
      // Older than 7 days (should not be included in 7-day average)
      await storage.saveBodyMetric(BodyMetricLog(
        id: 'w3',
        date: now.subtract(const Duration(days: 14)),
        weightKg: 80.0,
      ));

      final avg = storage.get7DayAverageWeight();
      expect(avg, isNotNull);
      // (75 + 74) / 2 = 74.5
      expect(avg!, 74.5);
    });

    test('Deletes body metric cleanly', () async {
      await storage.saveBodyMetric(BodyMetricLog(
        id: 'del-me',
        date: DateTime.now(),
        weightKg: 70.0,
      ));

      expect(storage.getBodyMetrics().length, 1);
      await storage.deleteBodyMetric('del-me');
      expect(storage.getBodyMetrics().length, 0);
    });
  });
}
