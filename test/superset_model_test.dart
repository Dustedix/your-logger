import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/models/exercise.dart';
import 'package:workout_app/models/workout_log.dart';

void main() {
  group('Exercise Model & Superset Serialization', () {
    test('Standard exercise serializes and deserializes cleanly', () {
      final ex = Exercise(
        id: 'ex-bench',
        name: 'Barbell Bench Press',
        targetMuscle: 'Chest',
        defaultSets: 4,
        defaultReps: 8,
        defaultWeightKg: 80.0,
      );

      final json = ex.toJson();
      final fromJson = Exercise.fromJson(json);

      expect(fromJson.id, 'ex-bench');
      expect(fromJson.name, 'Barbell Bench Press');
      expect(fromJson.isSuperset, false);
      expect(fromJson.supersetName, isNull);
    });

    test('Superset exercise preserves paired movement properties', () {
      final superset = Exercise(
        id: 'ex-arms-superset',
        name: 'Dumbbell Bicep Curls',
        targetMuscle: 'Biceps',
        defaultSets: 3,
        defaultReps: 12,
        defaultWeightKg: 14.0,
        isSuperset: true,
        supersetName: 'Triceps Overhead Extension',
        supersetTargetMuscle: 'Triceps',
        supersetIsTimeBased: false,
        supersetReps: 12,
        supersetWeightKg: 20.0,
      );

      final json = superset.toJson();
      final fromJson = Exercise.fromJson(json);

      expect(fromJson.isSuperset, true);
      expect(fromJson.name, 'Dumbbell Bicep Curls');
      expect(fromJson.supersetName, 'Triceps Overhead Extension');
      expect(fromJson.supersetTargetMuscle, 'Triceps');
      expect(fromJson.supersetReps, 12);
      expect(fromJson.supersetWeightKg, 20.0);
    });

    test('Backward compatibility: legacy JSON without superset fields defaults cleanly', () {
      final legacyJson = {
        'id': 'legacy-squat',
        'name': 'Barbell Back Squat',
        'targetMuscle': 'Legs',
        'defaultSets': 5,
        'defaultReps': 5,
        'defaultWeightKg': 100.0,
      };

      final exercise = Exercise.fromJson(legacyJson);
      expect(exercise.isSuperset, false);
      expect(exercise.supersetName, isNull);
      expect(exercise.supersetReps, 10);
    });
  });

  group('WorkoutLog Superset Volume Math', () {
    test('ExerciseCompletionLog calculates combined superset volume correctly', () {
      final log = ExerciseCompletionLog(
        exerciseId: 'superset-chest-back',
        exerciseName: 'Dumbbell Bench Press',
        targetMuscle: 'Chest',
        isSuperset: true,
        supersetName: 'Chest Supported Rows',
        supersetTargetMuscle: 'Back',
        sets: [
          ExerciseSetLog(
            setNumber: 1,
            reps: 10,
            weightKg: 25.0, // 250 kg volume
            supersetReps: 10,
            supersetWeightKg: 30.0, // 300 kg volume
            completed: true,
          ),
          ExerciseSetLog(
            setNumber: 2,
            reps: 10,
            weightKg: 25.0, // 250 kg volume
            supersetReps: 10,
            supersetWeightKg: 30.0, // 300 kg volume
            completed: true,
          ),
        ],
      );

      // Total volume should be (250 + 300) * 2 = 1100 kg
      expect(log.totalVolume, 1100.0);
      expect(log.totalReps, 40); // (10 + 10) * 2 = 40 reps
      expect(log.completedSets, 2);
    });

    test('formatSetText formats superset sets with both movements', () {
      final log = ExerciseCompletionLog(
        exerciseId: 'ss-1',
        exerciseName: 'Bicep Curl',
        targetMuscle: 'Biceps',
        isSuperset: true,
        supersetName: 'Tricep Dip',
        supersetTargetMuscle: 'Triceps',
        sets: [],
      );

      final set = ExerciseSetLog(
        setNumber: 1,
        reps: 12,
        weightKg: 15.0,
        supersetReps: 15,
        supersetWeightKg: 0.0,
      );

      final text = log.formatSetText(set);
      expect(text, contains('12 reps @ 15.0kg'));
      expect(text, contains('15 reps'));
    });
  });
}
