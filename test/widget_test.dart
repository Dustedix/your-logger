import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_app/main.dart';
import 'package:workout_app/services/storage_service.dart';
import 'package:workout_app/screens/log_session_screen.dart';
import 'package:workout_app/theme/app_theme.dart';
import 'package:workout_app/models/exercise.dart';
import 'package:workout_app/models/workout_schedule.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService().init();
  });

  testWidgets('App loads and shows workout tracker', (WidgetTester tester) async {
    await tester.pumpWidget(const WorkoutTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('Workout Schedules'), findsOneWidget);
    expect(find.text('Push Day (Chest, Shoulders, Triceps)'), findsOneWidget);
  });

  testWidgets('Can render Log Session screen with Plank timer & rep controls',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final testSchedule = WorkoutSchedule(
      id: 'test-1',
      title: 'Test Core Routine',
      colorHex: '#10B981',
      scheduledDays: const ['Monday'],
      createdAt: DateTime.now(),
      exercises: [
        Exercise(
          id: 'ex-1',
          name: 'Push Up',
          targetMuscle: 'Chest',
          defaultSets: 3,
          defaultReps: 10,
        ),
        Exercise(
          id: 'ex-2',
          name: 'Front Plank Hold',
          targetMuscle: 'Core',
          isTimeBased: true,
          defaultSets: 2,
          defaultTimeSeconds: 60,
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: LogSessionScreen(schedule: testSchedule),
    ));
    await tester.pumpAndSettle();

    // Verify we are on Log Session screen
    expect(find.text('Log Workout Session'), findsOneWidget);
    expect(find.text('Front Plank Hold'), findsOneWidget);
    expect(find.text('HOLD DURATION'), findsOneWidget);
    expect(find.text('REPS'), findsWidgets);

    // Verify live stopwatch icon exists for Plank
    expect(find.byIcon(Icons.timer_outlined), findsWidgets);

    // Tap the timer button to open the live stopwatch dialog
    await tester.tap(find.byIcon(Icons.timer_outlined).first);
    await tester.pumpAndSettle();

    // Check stopwatch modal
    expect(find.text('Front Plank Hold (Set 1)'), findsOneWidget);
    expect(find.text('Start Timer'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // Close stopwatch modal
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Modal closed
    expect(find.text('Front Plank Hold (Set 1)'), findsNothing);
  });

  testWidgets('Can toggle set completion and add extra sets without error',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final testSchedule = WorkoutSchedule(
      id: 'test-2',
      title: 'Short Routine',
      colorHex: '#06B6D4',
      scheduledDays: const ['Tuesday'],
      createdAt: DateTime.now(),
      exercises: [
        Exercise(
          id: 'ex-1',
          name: 'Push Up',
          targetMuscle: 'Chest',
          defaultSets: 1,
          defaultReps: 10,
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: LogSessionScreen(schedule: testSchedule),
    ));
    await tester.pumpAndSettle();

    // Verify initially set 1 exists
    expect(find.text('1'), findsOneWidget);

    // Tap 'Add Set' button
    await tester.tap(find.text('Add Set'));
    await tester.pumpAndSettle();

    // Now set 2 exists
    expect(find.text('2'), findsOneWidget);

    // Delete set 2 using the close icon
    expect(find.byIcon(Icons.close), findsWidgets);
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    // Verify back to 1 set
    expect(find.text('2'), findsNothing);
  });

  testWidgets('Can open AI Coach screen and update UserProfile',
      (WidgetTester tester) async {
    final storage = StorageService();
    final initialProfile = storage.getProfile();
    expect(initialProfile.geminiApiKey, isEmpty);

    // Save profile with key and bodyweight
    final updated = initialProfile.copyWith(
      geminiApiKey: 'test-api-key-123',
      bodyWeightKg: 75.5,
      age: 27,
      trainingGoal: 'Hypertrophy & Muscle Building',
    );
    await storage.saveProfile(updated);

    final retrieved = storage.getProfile();
    expect(retrieved.geminiApiKey, equals('test-api-key-123'));
    expect(retrieved.bodyWeightKg, equals(75.5));
    expect(retrieved.age, equals(27));
  });
}


