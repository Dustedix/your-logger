import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/exercise.dart';
import '../models/workout_schedule.dart';
import '../models/workout_log.dart';

class SyncResult {
  final bool success;
  final int count;
  final String? error;
  const SyncResult({required this.success, this.count = 0, this.error});
}

class StorageService extends ChangeNotifier {
  static const String _keySchedules = 'workout_schedules_v1';
  static const String _keyLogs = 'workout_logs_v1';
  static const String _keyHasSeeded = 'workout_has_seeded_v1';
  static final _uuid = const Uuid();

  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;
  StreamSubscription? _schedulesSub;
  StreamSubscription? _logsSub;

  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;
  FirebaseFirestore? get _firestore =>
      _isFirebaseReady ? FirebaseFirestore.instance : null;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _seedDefaultsIfEmpty();
    if (_isFirebaseReady) {
      startRealtimeSync();
    }
  }

  /// Starts listening to real-time Cloud Firestore updates
  void startRealtimeSync() {
    if (!_isFirebaseReady) return;
    _schedulesSub?.cancel();
    _logsSub?.cancel();

    _schedulesSub = _firestore?.collection('schedules').snapshots().listen(
      (snapshot) {
        final cloudSchedules = snapshot.docs
            .map((doc) => WorkoutSchedule.fromJson(doc.data()))
            .toList();
        final encoded =
            jsonEncode(cloudSchedules.map((s) => s.toJson()).toList());
        _prefs?.setString(_keySchedules, encoded);
        _prefs?.setBool(_keyHasSeeded, true);
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Firestore realtime schedules notice: $e');
      },
    );

    _logsSub = _firestore?.collection('logs').snapshots().listen(
      (snapshot) {
        final cloudLogs = snapshot.docs
            .map((doc) => WorkoutLog.fromJson(doc.data()))
            .toList();
        cloudLogs.sort((a, b) => b.completedDate.compareTo(a.completedDate));
        final encoded = jsonEncode(cloudLogs.map((l) => l.toJson()).toList());
        _prefs?.setString(_keyLogs, encoded);
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Firestore realtime logs notice: $e');
      },
    );
  }

  /// Pushes all local schedules and logs to Cloud Firestore with error reporting
  Future<SyncResult> pushAllToCloud() async {
    if (!_isFirebaseReady) {
      return const SyncResult(
        success: false,
        error: 'Firebase is not initialized (Firebase.apps is empty).',
      );
    }
    int count = 0;
    try {
      final schedules = getSchedules();
      for (final s in schedules) {
        await _firestore
            ?.collection('schedules')
            .doc(s.id)
            .set(s.toJson(), SetOptions(merge: true));
        count++;
      }
      final logs = getLogs();
      for (final l in logs) {
        await _firestore
            ?.collection('logs')
            .doc(l.id)
            .set(l.toJson(), SetOptions(merge: true));
        count++;
      }
      return SyncResult(success: true, count: count);
    } catch (e) {
      debugPrint('Firestore push error: $e');
      return SyncResult(success: false, count: count, error: e.toString());
    }
  }

  /// Synchronizes schedules and logs with Cloud Firestore
  Future<void> syncFromCloud() async {
    if (!_isFirebaseReady) return;
    try {
      final schedSnap = await _firestore?.collection('schedules').get();
      if (schedSnap != null && schedSnap.docs.isNotEmpty) {
        final cloudSchedules = schedSnap.docs
            .map((doc) => WorkoutSchedule.fromJson(doc.data()))
            .toList();
        await saveAllSchedules(cloudSchedules);
      } else {
        // If cloud collection is empty, push our local seeded routines to cloud
        await pushAllToCloud();
      }

      final logSnap = await _firestore?.collection('logs').get();
      if (logSnap != null && logSnap.docs.isNotEmpty) {
        final cloudLogs = logSnap.docs
            .map((doc) => WorkoutLog.fromJson(doc.data()))
            .toList();
        await saveAllLogs(cloudLogs);
      }
    } catch (e) {
      debugPrint('Firestore sync notice (offline or read restricted): $e');
    }
  }

  Future<void> _seedDefaultsIfEmpty() async {
    final hasSeeded = _prefs?.getBool(_keyHasSeeded) ?? false;
    final existing = _prefs?.getString(_keySchedules);
    if (hasSeeded || (existing != null && existing.isNotEmpty && existing != '[]')) {
      if (!hasSeeded) {
        await _prefs?.setBool(_keyHasSeeded, true);
      }
      return;
    }
      final defaultSchedules = [
        WorkoutSchedule(
          id: _uuid.v4(),
          title: 'Push Day (Chest, Shoulders, Triceps)',
          description: 'Focus on horizontal and vertical pushing hypertrophy.',
          colorHex: '#10B981', // Emerald
          scheduledDays: ['Monday', 'Thursday'],
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
          exercises: [
            Exercise(
              id: _uuid.v4(),
              name: 'Barbell Bench Press',
              targetMuscle: 'Chest',
              defaultSets: 4,
              defaultReps: 8,
              defaultWeightKg: 60.0,
              notes: 'Keep shoulder blades retracted and elbows at 45 deg.',
            ),
            Exercise(
              id: _uuid.v4(),
              name: 'Incline Dumbbell Press',
              targetMuscle: 'Upper Chest',
              defaultSets: 3,
              defaultReps: 10,
              defaultWeightKg: 22.0,
            ),
            Exercise(
              id: _uuid.v4(),
              name: 'Overhead Shoulder Press',
              targetMuscle: 'Shoulders',
              defaultSets: 3,
              defaultReps: 10,
              defaultWeightKg: 40.0,
            ),
            Exercise(
              id: _uuid.v4(),
              name: 'Triceps Rope Pushdown',
              targetMuscle: 'Triceps',
              defaultSets: 3,
              defaultReps: 12,
              defaultWeightKg: 25.0,
            ),
          ],
        ),
        WorkoutSchedule(
          id: _uuid.v4(),
          title: 'Pull Day (Back, Rear Delts, Biceps)',
          description: 'Vertical and horizontal pulling power and arm volume.',
          colorHex: '#06B6D4', // Cyan
          scheduledDays: ['Tuesday', 'Friday'],
          createdAt: DateTime.now().subtract(const Duration(days: 6)),
          exercises: [
            Exercise(
              id: _uuid.v4(),
              name: 'Barbell Bent-Over Row',
              targetMuscle: 'Back',
              defaultSets: 4,
              defaultReps: 8,
              defaultWeightKg: 65.0,
            ),
            Exercise(
              id: _uuid.v4(),
              name: 'Lat Pulldown',
              targetMuscle: 'Lats',
              defaultSets: 3,
              defaultReps: 10,
              defaultWeightKg: 55.0,
            ),
            Exercise(
              id: _uuid.v4(),
              name: 'Face Pulls',
              targetMuscle: 'Rear Delts',
              defaultSets: 3,
              defaultReps: 15,
              defaultWeightKg: 20.0,
            ),
            Exercise(
              id: _uuid.v4(),
              name: 'Incline Dumbbell Bicep Curl',
              targetMuscle: 'Biceps',
              defaultSets: 3,
              defaultReps: 12,
              defaultWeightKg: 14.0,
            ),
          ],
        ),
        WorkoutSchedule(
          id: _uuid.v4(),
          title: 'Legs & Core Power',
          description: 'Squats, posterior chain development, and core stability.',
          colorHex: '#F59E0B', // Amber
          scheduledDays: ['Wednesday', 'Saturday'],
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          exercises: [
            Exercise(
              id: _uuid.v4(),
              name: 'Barbell Back Squat',
              targetMuscle: 'Quads & Glutes',
              defaultSets: 4,
              defaultReps: 8,
              defaultWeightKg: 85.0,
            ),
            Exercise(
              id: _uuid.v4(),
              name: 'Romanian Deadlift (RDL)',
              targetMuscle: 'Hamstrings',
              defaultSets: 3,
              defaultReps: 10,
              defaultWeightKg: 70.0,
            ),
            Exercise(
              id: _uuid.v4(),
              name: 'Leg Extension',
              targetMuscle: 'Quads',
              defaultSets: 3,
              defaultReps: 12,
              defaultWeightKg: 45.0,
            ),
            Exercise(
              id: _uuid.v4(),
              name: 'Hanging Leg Raises',
              targetMuscle: 'Core',
              defaultSets: 3,
              defaultReps: 15,
              defaultWeightKg: 0.0,
            ),
            Exercise(
              id: _uuid.v4(),
              name: 'Front Plank Hold',
              targetMuscle: 'Core',
              isTimeBased: true,
              defaultSets: 3,
              defaultTimeSeconds: 60,
              defaultWeightKg: 0.0,
              notes: 'Keep hips aligned, squeeze glutes and brace core.',
            ),
          ],
        ),
      ];

      await saveAllSchedules(defaultSchedules);

      // Also create one initial completed log for yesterday as a demo
      final push = defaultSchedules[0];
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final initialLog = WorkoutLog(
        id: _uuid.v4(),
        scheduleId: push.id,
        scheduleTitle: push.title,
        completedDate: yesterday,
        durationMinutes: 50,
        overallNotes: 'Great session, felt strong on bench press.',
        exerciseLogs: push.exercises.map((e) {
          return ExerciseCompletionLog(
            exerciseId: e.id,
            exerciseName: e.name,
            targetMuscle: e.targetMuscle,
            sets: List.generate(
              e.defaultSets,
              (index) => ExerciseSetLog(
                setNumber: index + 1,
                reps: e.defaultReps,
                weightKg: e.defaultWeightKg,
                completed: true,
              ),
            ),
          );
        }).toList(),
      );
      await saveLog(initialLog);
      await _prefs?.setBool(_keyHasSeeded, true);
  }

  // SCHEDULES
  List<WorkoutSchedule> getSchedules() {
    final jsonStr = _prefs?.getString(_keySchedules);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((item) => WorkoutSchedule.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAllSchedules(List<WorkoutSchedule> schedules) async {
    final encoded = jsonEncode(schedules.map((s) => s.toJson()).toList());
    await _prefs?.setString(_keySchedules, encoded);
    notifyListeners();
  }

  Future<void> saveSchedule(WorkoutSchedule schedule) async {
    final list = getSchedules();
    final index = list.indexWhere((s) => s.id == schedule.id);
    if (index >= 0) {
      list[index] = schedule;
    } else {
      list.insert(0, schedule);
    }
    await saveAllSchedules(list);

    if (_isFirebaseReady) {
      try {
        await _firestore
            ?.collection('schedules')
            .doc(schedule.id)
            .set(schedule.toJson(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore saveSchedule notice: $e');
      }
    }
  }

  Future<void> deleteSchedule(String scheduleId) async {
    final list = getSchedules();
    list.removeWhere((s) => s.id == scheduleId);
    await saveAllSchedules(list);

    if (_isFirebaseReady) {
      try {
        await _firestore?.collection('schedules').doc(scheduleId).delete();
      } catch (e) {
        debugPrint('Firestore deleteSchedule notice: $e');
      }
    }
  }

  // WORKOUT LOGS
  List<WorkoutLog> getLogs() {
    final jsonStr = _prefs?.getString(_keyLogs);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      final logs = list.map((item) => WorkoutLog.fromJson(item)).toList();
      logs.sort((a, b) => b.completedDate.compareTo(a.completedDate));
      return logs;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAllLogs(List<WorkoutLog> logs) async {
    final encoded = jsonEncode(logs.map((l) => l.toJson()).toList());
    await _prefs?.setString(_keyLogs, encoded);
    notifyListeners();
  }

  Future<void> saveLog(WorkoutLog log) async {
    final list = getLogs();
    final index = list.indexWhere((l) => l.id == log.id);
    if (index >= 0) {
      list[index] = log;
    } else {
      list.insert(0, log);
    }
    await saveAllLogs(list);

    if (_isFirebaseReady) {
      try {
        await _firestore
            ?.collection('logs')
            .doc(log.id)
            .set(log.toJson(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore saveLog notice: $e');
      }
    }
  }

  Future<void> deleteLog(String logId) async {
    final list = getLogs();
    list.removeWhere((l) => l.id == logId);
    await saveAllLogs(list);

    if (_isFirebaseReady) {
      try {
        await _firestore?.collection('logs').doc(logId).delete();
      } catch (e) {
        debugPrint('Firestore deleteLog notice: $e');
      }
    }
  }

  List<WorkoutLog> getLogsForSchedule(String scheduleId) {
    return getLogs().where((l) => l.scheduleId == scheduleId).toList();
  }
}
