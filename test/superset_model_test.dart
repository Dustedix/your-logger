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

    test('Tri-Set (3 movements) correctly computes badge, volume, and reps', () {
      final triSetEx = Exercise(
        id: 'tri-arms',
        name: 'Bicep Curl',
        targetMuscle: 'Biceps',
        defaultSets: 3,
        defaultReps: 10,
        defaultWeightKg: 15.0,
        isSuperset: true,
        supersetMovements: [
          SupersetMovement(
            id: 'tri-m2',
            name: 'Triceps Pushdown',
            targetMuscle: 'Triceps',
            defaultReps: 12,
            defaultWeightKg: 20.0,
          ),
          SupersetMovement(
            id: 'tri-m3',
            name: 'Hammer Curl',
            targetMuscle: 'Forearms',
            defaultReps: 8,
            defaultWeightKg: 12.0,
          ),
        ],
      );

      expect(triSetEx.totalMovements, 3);
      expect(triSetEx.supersetBadgeTitle, 'Tri-Set');
      expect(triSetEx.allExerciseNames,
          ['Bicep Curl', 'Triceps Pushdown', 'Hammer Curl']);

      // Test JSON roundtrip
      final json = triSetEx.toJson();
      final restored = Exercise.fromJson(json);
      expect(restored.totalMovements, 3);
      expect(restored.supersetBadgeTitle, 'Tri-Set');
      expect(restored.supersetMovements.length, 2);
      expect(restored.supersetMovements[1].name, 'Hammer Curl');

      // Test WorkoutLog math with 3 movements
      final log = ExerciseCompletionLog(
        exerciseId: triSetEx.id,
        exerciseName: triSetEx.name,
        targetMuscle: triSetEx.targetMuscle,
        isSuperset: true,
        supersetMovements: triSetEx.supersetMovements,
        sets: [
          ExerciseSetLog(
            setNumber: 1,
            reps: 10,
            weightKg: 15.0, // 150 kg
            completed: true,
            subMovements: [
              SubMovementSetLog(
                movementId: 'tri-m2',
                name: 'Triceps Pushdown',
                targetMuscle: 'Triceps',
                reps: 12,
                weightKg: 20.0, // 240 kg
                completed: true,
              ),
              SubMovementSetLog(
                movementId: 'tri-m3',
                name: 'Hammer Curl',
                targetMuscle: 'Forearms',
                reps: 8,
                weightKg: 12.0, // 96 kg
                completed: true,
              ),
            ],
          ),
        ],
      );

      // Volume: 150 + 240 + 96 = 486 kg
      expect(log.totalVolume, 486.0);
      expect(log.totalReps, 30); // 10 + 12 + 8
      expect(log.formatSetText(log.sets.first), contains('8 reps @ 12.0kg'));
    });

    test('Giant Set (4 movements) correctly handles PR detection and badge', () {
      final giantSetEx = Exercise(
        id: 'giant-legs',
        name: 'Squats',
        targetMuscle: 'Quads',
        defaultSets: 4,
        defaultReps: 10,
        defaultWeightKg: 80.0,
        isSuperset: true,
        supersetMovements: [
          SupersetMovement(
            id: 'g-2',
            name: 'Leg Press',
            targetMuscle: 'Quads',
            defaultReps: 12,
            defaultWeightKg: 120.0,
          ),
          SupersetMovement(
            id: 'g-3',
            name: 'Walking Lunges',
            targetMuscle: 'Glutes',
            defaultReps: 20,
            defaultWeightKg: 20.0,
          ),
          SupersetMovement(
            id: 'g-4',
            name: 'Calf Raises',
            targetMuscle: 'Calves',
            defaultReps: 25,
            defaultWeightKg: 40.0,
          ),
        ],
      );

      expect(giantSetEx.totalMovements, 4);
      expect(giantSetEx.supersetBadgeTitle, 'Giant Set (4)');

      final exLog = ExerciseCompletionLog(
        exerciseId: giantSetEx.id,
        exerciseName: giantSetEx.name,
        targetMuscle: giantSetEx.targetMuscle,
        isSuperset: true,
        supersetMovements: giantSetEx.supersetMovements,
        sets: [
          ExerciseSetLog(
            setNumber: 1,
            reps: 10,
            weightKg: 80.0,
            completed: true,
            subMovements: [
              SubMovementSetLog(
                movementId: 'g-2',
                name: 'Leg Press',
                targetMuscle: 'Quads',
                reps: 12,
                weightKg: 120.0,
              ),
              SubMovementSetLog(
                movementId: 'g-3',
                name: 'Walking Lunges',
                targetMuscle: 'Glutes',
                reps: 20,
                weightKg: 20.0,
              ),
              SubMovementSetLog(
                movementId: 'g-4',
                name: 'Calf Raises',
                targetMuscle: 'Calves',
                reps: 25,
                weightKg: 40.0,
                isPersonalRecord: true, // Movement 4 has a PR!
              ),
            ],
          ),
        ],
      );

      expect(exLog.hasPersonalRecord, true);

      final workoutLog = WorkoutLog(
        id: 'w-log-1',
        scheduleId: 'sched-1',
        scheduleTitle: 'Leg Destroyer',
        completedDate: DateTime.now(),
        durationMinutes: 45,
        exerciseLogs: [exLog],
      );

      expect(workoutLog.prExerciseNames, contains('Calf Raises'));
    });

    test('AMRAP (As Many Reps As Possible) model serialization & formatting', () {
      final amrapEx = Exercise(
        id: 'amrap-pushups',
        name: 'Push-Ups',
        targetMuscle: 'Chest',
        defaultSets: 3,
        defaultReps: 0,
        isAmrap: true,
        defaultWeightKg: 0.0,
      );

      expect(amrapEx.isAmrap, true);
      final exJson = amrapEx.toJson();
      expect(exJson['isAmrap'], true);

      final decodedEx = Exercise.fromJson(exJson);
      expect(decodedEx.isAmrap, true);

      // SubMovement AMRAP
      final subM = SupersetMovement(
        id: 'sub-amrap',
        name: 'Chin-Ups',
        targetMuscle: 'Back',
        isAmrap: true,
      );
      expect(subM.isAmrap, true);
      final subJson = subM.toJson();
      expect(subJson['isAmrap'], true);
      final decodedSub = SupersetMovement.fromJson(subJson);
      expect(decodedSub.isAmrap, true);

      // ExerciseCompletionLog formatSetText with AMRAP
      final setLog = ExerciseSetLog(
        setNumber: 1,
        reps: 18,
        weightKg: 0.0,
        isAmrap: true,
        subMovements: [
          SubMovementSetLog(
            movementId: 'sub-amrap',
            name: 'Chin-Ups',
            targetMuscle: 'Back',
            reps: 12,
            weightKg: 0.0,
            isAmrap: true,
          ),
        ],
      );

      final compLog = ExerciseCompletionLog(
        exerciseId: 'amrap-pushups',
        exerciseName: 'Push-Ups',
        targetMuscle: 'Chest',
        isAmrap: true,
        isSuperset: true,
        supersetMovements: [subM],
        sets: [setLog],
      );

      final text = compLog.formatSetText(setLog);
      expect(text, contains('18 reps (AMRAP)'));
      expect(text, contains('12 reps (AMRAP)'));

      // Backward compatibility: missing isAmrap key defaults to false
      final legacyJson = {
        'id': 'legacy-ex',
        'name': 'Squat',
        'targetMuscle': 'Quads',
        'defaultSets': 3,
        'defaultReps': 10,
      };
      final legacyEx = Exercise.fromJson(legacyJson);
      expect(legacyEx.isAmrap, false);
    });
  });
}


