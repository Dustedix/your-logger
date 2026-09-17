import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_app/models/personal_record.dart';
import 'package:workout_app/models/workout_log.dart';
import 'package:workout_app/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PersonalRecord & Last Performance Models', () {
    test('Calculates Epley 1RM accurately for multiple reps', () {
      // 100kg x 10 reps -> 100 * (1 + 10/30) = 133.33kg
      final epley = StorageService.calculateEpley1RM(100.0, 10);
      expect(epley, closeTo(133.33, 0.01));
    });

    test('Epley 1RM equals weight for single rep', () {
      final epley = StorageService.calculateEpley1RM(120.0, 1);
      expect(epley, 120.0);
    });

    test('PersonalRecord summary formats weight and estimated 1RM', () {
      final pr = PersonalRecord(
        exerciseName: 'Bench Press',
        maxWeightKg: 100.0,
        maxWeightReps: 8,
        estimated1RM: 126.7,
        achievedDate: DateTime(2026, 9, 15),
      );

      expect(pr.isTimeBased, false);
      expect(pr.summary, contains('100 kg × 8'));
      expect(pr.summary, contains('1RM ~127kg'));
    });

    test('PersonalRecord summary formats time-based holds', () {
      final pr = PersonalRecord(
        exerciseName: 'Plank',
        maxHoldSeconds: 90,
        achievedDate: DateTime(2026, 9, 15),
        isTimeBased: true,
      );

      expect(pr.isTimeBased, true);
      expect(pr.summary, contains('1m 30s'));
    });

    test('ExerciseLastPerformance formats ghost text nicely', () {
      final perf = ExerciseLastPerformance(
        exerciseName: 'Overhead Press',
        completedDate: DateTime(2026, 9, 10),
        routineTitle: 'Push Routine',
        sets: const [
          ExerciseSetPerformance(
            setNumber: 1,
            reps: 8,
            weightKg: 50.0,
          ),
          ExerciseSetPerformance(
            setNumber: 2,
            timeSeconds: 45,
            isTimeBased: true,
          ),
        ],
      );

      expect(perf.formatSet(1), '50.0kg × 8');
      expect(perf.formatSet(2), '45s');
      expect(perf.formatSet(3), isNull);
    });
  });

  group('WorkoutLog PR Recognition', () {
    test('hasPersonalRecord returns true when any set has isPersonalRecord flag', () {
      final log = WorkoutLog(
        id: 'log-1',
        scheduleId: 'sched-1',
        scheduleTitle: 'Push Day',
        completedDate: DateTime.now(),
        durationMinutes: 45,
        exerciseLogs: [
          ExerciseCompletionLog(
            exerciseId: 'ex-1',
            exerciseName: 'Incline Dumbbell Press',
            targetMuscle: 'Chest',
            sets: [
              ExerciseSetLog(
                setNumber: 1,
                reps: 10,
                weightKg: 30.0,
                completed: true,
                isPersonalRecord: true,
              ),
            ],
          ),
        ],
      );

      expect(log.hasPersonalRecord, true);
      expect(log.prExerciseNames, contains('Incline Dumbbell Press'));
    });

    test('Detects PR on superset paired movement', () {
      final log = WorkoutLog(
        id: 'log-2',
        scheduleId: 'sched-2',
        scheduleTitle: 'Arms Blast',
        completedDate: DateTime.now(),
        durationMinutes: 30,
        exerciseLogs: [
          ExerciseCompletionLog(
            exerciseId: 'ex-ss',
            exerciseName: 'Bicep Curl',
            targetMuscle: 'Biceps',
            isSuperset: true,
            supersetName: 'Hammer Curl',
            supersetTargetMuscle: 'Forearms',
            sets: [
              ExerciseSetLog(
                setNumber: 1,
                reps: 12,
                weightKg: 14.0,
                supersetReps: 12,
                supersetWeightKg: 18.0,
                completed: true,
                supersetIsPersonalRecord: true,
              ),
            ],
          ),
        ],
      );

      expect(log.hasPersonalRecord, true);
      expect(log.prExerciseNames, contains('Hammer Curl'));
    });
  });

  group('StorageService PR & Performance Retrieval', () {
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init('test_user');
      await storage.clearAllLogs();
    });

    test('getPersonalRecord accurately finds highest weight and 1RM', () async {
      // Add first workout
      await storage.saveLog(WorkoutLog(
        id: 'log-hist-1',
        scheduleId: 's1',
        scheduleTitle: 'Leg Day',
        completedDate: DateTime(2026, 9, 1),
        durationMinutes: 40,
        exerciseLogs: [
          ExerciseCompletionLog(
            exerciseId: 'sq',
            exerciseName: 'Barbell Squat',
            targetMuscle: 'Legs',
            sets: [
              ExerciseSetLog(
                setNumber: 1,
                reps: 5,
                weightKg: 100.0,
                completed: true,
              ),
              ExerciseSetLog(
                setNumber: 2,
                reps: 3,
                weightKg: 110.0,
                completed: true,
              ),
            ],
          ),
        ],
      ));

      // Add second workout with higher weight
      await storage.saveLog(WorkoutLog(
        id: 'log-hist-2',
        scheduleId: 's1',
        scheduleTitle: 'Leg Day',
        completedDate: DateTime(2026, 9, 8),
        durationMinutes: 45,
        exerciseLogs: [
          ExerciseCompletionLog(
            exerciseId: 'sq',
            exerciseName: 'Barbell Squat',
            targetMuscle: 'Legs',
            sets: [
              ExerciseSetLog(
                setNumber: 1,
                reps: 5,
                weightKg: 115.0,
                completed: true,
              ),
            ],
          ),
        ],
      ));

      final pr = storage.getPersonalRecord('Barbell Squat');
      expect(pr.hasRecord, true);
      expect(pr.maxWeightKg, 115.0);
      expect(pr.maxWeightReps, 5);
      // Epley: 115 * (1 + 5/30) = 115 * 1.16667 = 134.167
      expect(pr.estimated1RM, closeTo(134.16, 0.1));
    });

    test('getLastPerformance retrieves most recent session sets', () async {
      await storage.saveLog(WorkoutLog(
        id: 'session-1',
        scheduleId: 's1',
        scheduleTitle: 'Upper',
        completedDate: DateTime(2026, 9, 5),
        durationMinutes: 40,
        exerciseLogs: [
          ExerciseCompletionLog(
            exerciseId: 'bp',
            exerciseName: 'Dumbbell Bench Press',
            targetMuscle: 'Chest',
            sets: [
              ExerciseSetLog(setNumber: 1, reps: 10, weightKg: 24.0, completed: true),
            ],
          ),
        ],
      ));

      await storage.saveLog(WorkoutLog(
        id: 'session-2',
        scheduleId: 's1',
        scheduleTitle: 'Upper',
        completedDate: DateTime(2026, 9, 12),
        durationMinutes: 45,
        exerciseLogs: [
          ExerciseCompletionLog(
            exerciseId: 'bp',
            exerciseName: 'Dumbbell Bench Press',
            targetMuscle: 'Chest',
            sets: [
              ExerciseSetLog(setNumber: 1, reps: 8, weightKg: 28.0, completed: true),
              ExerciseSetLog(setNumber: 2, reps: 7, weightKg: 28.0, completed: true),
            ],
          ),
        ],
      ));

      final lastPerf = storage.getLastPerformance('Dumbbell Bench Press');
      expect(lastPerf, isNotNull);
      expect(lastPerf!.sets.length, 2);
      expect(lastPerf.formatSet(1), '28.0kg × 8');
      expect(lastPerf.formatSet(2), '28.0kg × 7');
    });

    test('checkIsNewPR returns true for beating weight or duration', () async {
      await storage.saveLog(WorkoutLog(
        id: 'session-1',
        scheduleId: 's1',
        scheduleTitle: 'Upper',
        completedDate: DateTime(2026, 9, 5),
        durationMinutes: 40,
        exerciseLogs: [
          ExerciseCompletionLog(
            exerciseId: 'pl',
            exerciseName: 'Plank',
            targetMuscle: 'Core',
            isTimeBased: true,
            sets: [
              ExerciseSetLog(setNumber: 1, timeSeconds: 60, completed: true),
            ],
          ),
        ],
      ));

      // 50s is not a new PR
      expect(
        storage.checkIsNewPR(
          exerciseName: 'Plank',
          weightKg: 0,
          reps: 0,
          timeSeconds: 50,
          isTimeBased: true,
        ),
        false,
      );
      // 75s is a new PR
      expect(
        storage.checkIsNewPR(
          exerciseName: 'Plank',
          weightKg: 0,
          reps: 0,
          timeSeconds: 75,
          isTimeBased: true,
        ),
        true,
      );
    });
  });
}
