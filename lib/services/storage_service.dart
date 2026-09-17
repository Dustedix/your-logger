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
import '../models/user_profile.dart';
import '../models/personal_record.dart';
import '../models/body_metric_log.dart';

class SyncResult {
  final bool success;
  final int count;
  final String? error;
  const SyncResult({required this.success, this.count = 0, this.error});
}

class StorageService extends ChangeNotifier {
  static final _uuid = const Uuid();

  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;
  StreamSubscription? _schedulesSub;
  StreamSubscription? _logsSub;
  StreamSubscription? _metricsSub;
  String? _activeUser;

  String? get activeUser => _activeUser;

  String get _keySchedules => _activeUser != null && _activeUser!.isNotEmpty
      ? 'workout_schedules_v1_$_activeUser'
      : 'workout_schedules_v1';

  String get _keyLogs => _activeUser != null && _activeUser!.isNotEmpty
      ? 'workout_logs_v1_$_activeUser'
      : 'workout_logs_v1';

  String get _keyBodyMetrics => _activeUser != null && _activeUser!.isNotEmpty
      ? 'workout_body_metrics_v1_$_activeUser'
      : 'workout_body_metrics_v1';

  String get _keyHasSeeded => _activeUser != null && _activeUser!.isNotEmpty
      ? 'workout_has_seeded_v1_$_activeUser'
      : 'workout_has_seeded_v1';

  String get _keyProfile => _activeUser != null && _activeUser!.isNotEmpty
      ? 'workout_user_profile_v1_$_activeUser'
      : 'workout_user_profile_v1';

  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;
  FirebaseFirestore? get _firestore =>
      _isFirebaseReady ? FirebaseFirestore.instance : null;

  CollectionReference<Map<String, dynamic>>? get _schedulesCollection {
    if (!_isFirebaseReady || _firestore == null) return null;
    if (_activeUser != null && _activeUser!.isNotEmpty) {
      return _firestore!.collection('users').doc(_activeUser!).collection('schedules');
    }
    return _firestore!.collection('schedules');
  }

  CollectionReference<Map<String, dynamic>>? get _logsCollection {
    if (!_isFirebaseReady || _firestore == null) return null;
    if (_activeUser != null && _activeUser!.isNotEmpty) {
      return _firestore!.collection('users').doc(_activeUser!).collection('logs');
    }
    return _firestore!.collection('logs');
  }

  CollectionReference<Map<String, dynamic>>? get _metricsCollection {
    if (!_isFirebaseReady || _firestore == null) return null;
    if (_activeUser != null && _activeUser!.isNotEmpty) {
      return _firestore!.collection('users').doc(_activeUser!).collection('body_metrics');
    }
    return _firestore!.collection('body_metrics');
  }

  Future<void> init([String? initialUser]) async {
    _prefs ??= await SharedPreferences.getInstance();
    _activeUser = initialUser?.trim().toLowerCase();
    await _seedDefaultsIfEmpty();
    if (_isFirebaseReady) {
      startRealtimeSync();
    }
  }

  /// Switches active user namespace and restarts realtime sync
  Future<void> switchUser(String? username) async {
    _schedulesSub?.cancel();
    _logsSub?.cancel();
    _metricsSub?.cancel();
    _activeUser = username?.trim().toLowerCase();

    if (_activeUser != null && _activeUser!.isNotEmpty) {
      // Migrate legacy default data if this user is totally empty and legacy data exists
      final userSchedules = _prefs?.getString(_keySchedules);
      if (userSchedules == null || userSchedules.isEmpty || userSchedules == '[]') {
        final legacySchedules = _prefs?.getString('workout_schedules_v1');
        if (legacySchedules != null && legacySchedules.isNotEmpty && legacySchedules != '[]') {
          await _prefs?.setString(_keySchedules, legacySchedules);
          final legacyLogs = _prefs?.getString('workout_logs_v1');
          if (legacyLogs != null) {
            await _prefs?.setString(_keyLogs, legacyLogs);
          }
          await _prefs?.setBool(_keyHasSeeded, true);
        }
      }
      await _seedDefaultsIfEmpty();
    }

    if (_isFirebaseReady) {
      startRealtimeSync();
    }
    notifyListeners();
  }

  /// Starts listening to real-time Cloud Firestore updates
  void startRealtimeSync() {
    if (!_isFirebaseReady) return;
    _schedulesSub?.cancel();
    _logsSub?.cancel();
    _metricsSub?.cancel();

    final schedCol = _schedulesCollection;
    if (schedCol != null) {
      _schedulesSub = schedCol.snapshots().listen(
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
    }

    final logCol = _logsCollection;
    if (logCol != null) {
      _logsSub = logCol.snapshots().listen(
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

    final metricsCol = _metricsCollection;
    if (metricsCol != null) {
      _metricsSub = metricsCol.snapshots().listen(
        (snapshot) {
          final cloudMetrics = snapshot.docs
              .map((doc) => BodyMetricLog.fromJson(doc.data()))
              .toList();
          cloudMetrics.sort((a, b) => b.date.compareTo(a.date));
          final encoded = jsonEncode(cloudMetrics.map((m) => m.toJson()).toList());
          _prefs?.setString(_keyBodyMetrics, encoded);
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Firestore realtime body_metrics notice: $e');
        },
      );
    }
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
      final schedCol = _schedulesCollection;
      if (schedCol != null) {
        final schedules = getSchedules();
        for (final s in schedules) {
          await schedCol.doc(s.id).set(s.toJson(), SetOptions(merge: true));
          count++;
        }
      }

      final logCol = _logsCollection;
      if (logCol != null) {
        final logs = getLogs();
        for (final l in logs) {
          await logCol.doc(l.id).set(l.toJson(), SetOptions(merge: true));
          count++;
        }
      }

      final metricsCol = _metricsCollection;
      if (metricsCol != null) {
        final metrics = getBodyMetrics();
        for (final m in metrics) {
          await metricsCol.doc(m.id).set(m.toJson(), SetOptions(merge: true));
          count++;
        }
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
      final schedCol = _schedulesCollection;
      if (schedCol != null) {
        final schedSnap = await schedCol.get();
        if (schedSnap.docs.isNotEmpty) {
          final cloudSchedules = schedSnap.docs
              .map((doc) => WorkoutSchedule.fromJson(doc.data()))
              .toList();
          await saveAllSchedules(cloudSchedules);
        } else {
          // If cloud collection is empty, push our local seeded routines to cloud
          await pushAllToCloud();
        }
      }

      final logCol = _logsCollection;
      if (logCol != null) {
        final logSnap = await logCol.get();
        if (logSnap.docs.isNotEmpty) {
          final cloudLogs = logSnap.docs
              .map((doc) => WorkoutLog.fromJson(doc.data()))
              .toList();
          await saveAllLogs(cloudLogs);
        }
      }

      final metricsCol = _metricsCollection;
      if (metricsCol != null) {
        final metricSnap = await metricsCol.get();
        if (metricSnap.docs.isNotEmpty) {
          final cloudMetrics = metricSnap.docs
              .map((doc) => BodyMetricLog.fromJson(doc.data()))
              .toList();
          await saveAllBodyMetrics(cloudMetrics);
        }
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

    // Initial demo completed log
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

    final schedCol = _schedulesCollection;
    if (schedCol != null) {
      try {
        await schedCol.doc(schedule.id).set(schedule.toJson(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore saveSchedule notice: $e');
      }
    }
  }

  Future<void> deleteSchedule(String scheduleId) async {
    final list = getSchedules();
    list.removeWhere((s) => s.id == scheduleId);
    await saveAllSchedules(list);

    final schedCol = _schedulesCollection;
    if (schedCol != null) {
      try {
        await schedCol.doc(scheduleId).delete();
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

    final logCol = _logsCollection;
    if (logCol != null) {
      try {
        await logCol.doc(log.id).set(log.toJson(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore saveLog notice: $e');
      }
    }
  }

  Future<void> deleteLog(String logId) async {
    final list = getLogs();
    list.removeWhere((l) => l.id == logId);
    await saveAllLogs(list);

    final logCol = _logsCollection;
    if (logCol != null) {
      try {
        await logCol.doc(logId).delete();
      } catch (e) {
        debugPrint('Firestore deleteLog notice: $e');
      }
    }
  }

  List<WorkoutLog> getLogsForSchedule(String scheduleId) {
    return getLogs().where((l) => l.scheduleId == scheduleId).toList();
  }

  /// Clears all logs locally (used for testing or resetting data)
  Future<void> clearAllLogs() async {
    await saveAllLogs([]);
  }

  /// Clears all body metrics locally (used for testing or resetting data)
  Future<void> clearAllBodyMetrics() async {
    await saveAllBodyMetrics([]);
  }

  /// Epley 1RM formula calculation
  static double calculateEpley1RM(double weightKg, int reps) {
    if (reps <= 1) return weightKg;
    return weightKg * (1 + (reps / 30.0));
  }

  // BODY WEIGHT & COMPOSITION METRICS

  /// Retrieves all body metric logs sorted by date descending
  List<BodyMetricLog> getBodyMetrics() {
    final jsonStr = _prefs?.getString(_keyBodyMetrics);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      final metrics = list
          .map((item) => BodyMetricLog.fromJson(item as Map<String, dynamic>))
          .toList();
      metrics.sort((a, b) => b.date.compareTo(a.date));
      return metrics;
    } catch (_) {
      return [];
    }
  }

  /// Saves full list of body metrics locally
  Future<void> saveAllBodyMetrics(List<BodyMetricLog> metrics) async {
    metrics.sort((a, b) => b.date.compareTo(a.date));
    final encoded = jsonEncode(metrics.map((m) => m.toJson()).toList());
    await _prefs?.setString(_keyBodyMetrics, encoded);
    notifyListeners();
  }

  /// Saves or updates a single body metric log and syncs to Firestore
  Future<void> saveBodyMetric(BodyMetricLog metric) async {
    final metrics = getBodyMetrics();
    final index = metrics.indexWhere((m) => m.id == metric.id);
    if (index >= 0) {
      metrics[index] = metric;
    } else {
      metrics.insert(0, metric);
    }
    await saveAllBodyMetrics(metrics);

    // Keep latest weight synchronized with UserProfile
    if (metric.weightKg > 0) {
      final profile = getProfile();
      await saveProfile(profile.copyWith(bodyWeightKg: metric.weightKg));
    }

    final col = _metricsCollection;
    if (col != null) {
      try {
        await col.doc(metric.id).set(metric.toJson(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore saveBodyMetric error: $e');
      }
    }
  }

  /// Deletes a body metric log locally and in Firestore
  Future<void> deleteBodyMetric(String metricId) async {
    final metrics = getBodyMetrics()..removeWhere((m) => m.id == metricId);
    await saveAllBodyMetrics(metrics);

    final col = _metricsCollection;
    if (col != null) {
      try {
        await col.doc(metricId).delete();
      } catch (e) {
        debugPrint('Firestore deleteBodyMetric error: $e');
      }
    }
  }

  /// Returns the most recent body metric log
  BodyMetricLog? getLatestBodyMetric() {
    final metrics = getBodyMetrics();
    return metrics.isNotEmpty ? metrics.first : null;
  }

  /// Calculates rolling 7-day average weight in kg
  double? get7DayAverageWeight() {
    final metrics = getBodyMetrics();
    if (metrics.isEmpty) return null;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent =
        metrics.where((m) => m.date.isAfter(cutoff) && m.weightKg > 0).toList();
    if (recent.isEmpty) return metrics.first.weightKg;
    final sum = recent.fold(0.0, (acc, m) => acc + m.weightKg);
    return sum / recent.length;
  }

  // USER PROFILE & AI SETTINGS
  UserProfile getProfile() {
    final jsonStr = _prefs?.getString(_keyProfile);
    if (jsonStr == null || jsonStr.isEmpty) {
      return const UserProfile();
    }
    try {
      final Map<String, dynamic> map = jsonDecode(jsonStr);
      return UserProfile.fromJson(map);
    } catch (_) {
      return const UserProfile();
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    final encoded = jsonEncode(profile.toJson());
    await _prefs?.setString(_keyProfile, encoded);
    notifyListeners();
  }

  // PERSONAL RECORDS & HISTORICAL PERFORMANCE

  /// Retrieves the most recent previous performance for a given exercise name.
  ExerciseLastPerformance? getLastPerformance(String exerciseName) {
    final cleanName = exerciseName.trim().toLowerCase();
    if (cleanName.isEmpty) return null;

    final logs = getLogs();
    for (final log in logs) {
      for (final ex in log.exerciseLogs) {
        final matchesPrimary = ex.exerciseName.trim().toLowerCase() == cleanName;
        final subMovementIndex = ex.isSuperset
            ? ex.supersetMovements.indexWhere(
                (m) => m.name.trim().toLowerCase() == cleanName)
            : -1;

        if (matchesPrimary) {
          final setPerformances = ex.sets.where((s) => s.completed).map((s) {
            return ExerciseSetPerformance(
              setNumber: s.setNumber,
              reps: s.reps,
              timeSeconds: s.timeSeconds,
              weightKg: s.weightKg,
              isTimeBased: ex.isTimeBased,
            );
          }).toList();

          if (setPerformances.isNotEmpty) {
            return ExerciseLastPerformance(
              exerciseName: ex.exerciseName,
              completedDate: log.completedDate,
              routineTitle: log.scheduleTitle,
              sets: setPerformances,
              isSuperset: ex.isSuperset,
              supersetName: ex.supersetName,
            );
          }
        } else if (subMovementIndex >= 0) {
          final subMovement = ex.supersetMovements[subMovementIndex];
          final setPerformances = ex.sets.where((s) => s.completed).map((s) {
            final subSet = subMovementIndex < s.subMovements.length
                ? s.subMovements[subMovementIndex]
                : null;
            return ExerciseSetPerformance(
              setNumber: s.setNumber,
              reps: subSet?.reps ?? 0,
              timeSeconds: subSet?.timeSeconds ?? 0,
              weightKg: subSet?.weightKg ?? 0.0,
              isTimeBased: subMovement.isTimeBased,
            );
          }).toList();

          if (setPerformances.isNotEmpty) {
            return ExerciseLastPerformance(
              exerciseName: subMovement.name,
              completedDate: log.completedDate,
              routineTitle: log.scheduleTitle,
              sets: setPerformances,
              isSuperset: true,
              supersetName: subMovement.name,
            );
          }
        }
      }
    }
    return null;
  }

  /// Calculates the all-time personal record (Max Weight, 1RM, Hold time) for an exercise.
  PersonalRecord getPersonalRecord(String exerciseName) {
    final cleanName = exerciseName.trim().toLowerCase();
    final logs = getLogs();

    double maxWeight = 0.0;
    int maxWeightReps = 0;
    int maxHoldSeconds = 0;
    double maxEstimated1RM = 0.0;
    DateTime? recordDate;
    bool isTimeBased = false;

    for (final log in logs) {
      for (final ex in log.exerciseLogs) {
        if (ex.exerciseName.trim().toLowerCase() == cleanName) {
          isTimeBased = ex.isTimeBased;
          for (final s in ex.sets) {
            if (!s.completed) continue;

            if (ex.isTimeBased) {
              if (s.timeSeconds > maxHoldSeconds ||
                  (s.timeSeconds == maxHoldSeconds && s.weightKg > maxWeight)) {
                maxHoldSeconds = s.timeSeconds;
                maxWeight = s.weightKg;
                recordDate = log.completedDate;
              }
            } else {
              // Epley 1RM formula: weight * (1 + reps / 30)
              final epley1RM = s.reps > 1 ? s.weightKg * (1 + (s.reps / 30.0)) : s.weightKg;

              if (s.weightKg > maxWeight || (s.weightKg == maxWeight && s.reps > maxWeightReps)) {
                maxWeight = s.weightKg;
                maxWeightReps = s.reps;
                recordDate = log.completedDate;
              }

              if (epley1RM > maxEstimated1RM) {
                maxEstimated1RM = epley1RM;
              }
            }
          }
        }

        if (ex.isSuperset) {
          for (int i = 0; i < ex.supersetMovements.length; i++) {
            final subM = ex.supersetMovements[i];
            if (subM.name.trim().toLowerCase() == cleanName) {
              isTimeBased = subM.isTimeBased;
              for (final s in ex.sets) {
                if (!s.completed || i >= s.subMovements.length) continue;
                final subSet = s.subMovements[i];

                if (subM.isTimeBased) {
                  if (subSet.timeSeconds > maxHoldSeconds ||
                      (subSet.timeSeconds == maxHoldSeconds &&
                          subSet.weightKg > maxWeight)) {
                    maxHoldSeconds = subSet.timeSeconds;
                    maxWeight = subSet.weightKg;
                    recordDate = log.completedDate;
                  }
                } else {
                  final epley1RM = subSet.reps > 1
                      ? subSet.weightKg * (1 + (subSet.reps / 30.0))
                      : subSet.weightKg;

                  if (subSet.weightKg > maxWeight ||
                      (subSet.weightKg == maxWeight &&
                          subSet.reps > maxWeightReps)) {
                    maxWeight = subSet.weightKg;
                    maxWeightReps = subSet.reps;
                    recordDate = log.completedDate;
                  }

                  if (epley1RM > maxEstimated1RM) {
                    maxEstimated1RM = epley1RM;
                  }
                }
              }
            }
          }
        }
      }
    }

    return PersonalRecord(
      exerciseName: exerciseName,
      maxWeightKg: maxWeight,
      maxWeightReps: maxWeightReps,
      maxHoldSeconds: maxHoldSeconds,
      estimated1RM: maxEstimated1RM > 0 ? maxEstimated1RM : maxWeight,
      achievedDate: recordDate,
      isTimeBased: isTimeBased,
    );
  }

  /// Checks if a current set achieves a new personal record.
  bool checkIsNewPR({
    required String exerciseName,
    required double weightKg,
    required int reps,
    required int timeSeconds,
    required bool isTimeBased,
  }) {
    final existingPR = getPersonalRecord(exerciseName);
    if (!existingPR.hasRecord) {
      return isTimeBased ? timeSeconds > 0 : weightKg > 0;
    }

    if (isTimeBased) {
      if (timeSeconds > existingPR.maxHoldSeconds) return true;
      if (timeSeconds == existingPR.maxHoldSeconds && weightKg > existingPR.maxWeightKg) {
        return true;
      }
      return false;
    } else {
      if (weightKg > existingPR.maxWeightKg) return true;
      if (weightKg == existingPR.maxWeightKg && reps > existingPR.maxWeightReps) {
        return true;
      }
      return false;
    }
  }

  /// Returns personal records for all recorded exercises.
  List<PersonalRecord> getAllPersonalRecords() {
    final logs = getLogs();
    final exerciseNames = <String>{};
    for (final log in logs) {
      for (final ex in log.exerciseLogs) {
        if (ex.exerciseName.trim().isNotEmpty) {
          exerciseNames.add(ex.exerciseName.trim());
        }
        if (ex.isSuperset) {
          for (final m in ex.supersetMovements) {
            if (m.name.trim().isNotEmpty) {
              exerciseNames.add(m.name.trim());
            }
          }
        }
      }
    }

    final records = exerciseNames
        .map((name) => getPersonalRecord(name))
        .where((pr) => pr.hasRecord)
        .toList();

    records.sort((a, b) => b.maxWeightKg.compareTo(a.maxWeightKg));
    return records;
  }
}
