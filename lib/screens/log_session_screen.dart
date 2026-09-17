import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/workout_schedule.dart';
import '../models/workout_log.dart';
import '../models/personal_record.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class LogSessionScreen extends StatefulWidget {
  final WorkoutSchedule schedule;

  const LogSessionScreen({super.key, required this.schedule});

  @override
  State<LogSessionScreen> createState() => _LogSessionScreenState();
}

class _LogSessionScreenState extends State<LogSessionScreen> {
  late DateTime _selectedDate;
  int _durationMinutes = 45;
  final TextEditingController _notesController = TextEditingController();
  final Map<String, TextEditingController> _controllers = {};

  // Working state for each exercise's sets
  late List<ExerciseCompletionLog> _exerciseLogs;
  bool _isSaving = false;

  final Map<String, ExerciseLastPerformance?> _lastPerformanceCache = {};
  final Map<String, PersonalRecord> _prCache = {};

  TextEditingController _getWeightCtrl(int exIdx, int setIdx, double val) {
    final k = 'w_${exIdx}_$setIdx';
    var ctrl = _controllers[k];
    if (ctrl == null) {
      ctrl = TextEditingController(
        text: val == 0
            ? '0'
            : (val % 1 == 0 ? val.toInt().toString() : val.toString()),
      );
      _controllers[k] = ctrl;
    }
    return ctrl;
  }

  TextEditingController _getRepsCtrl(int exIdx, int setIdx, int val) {
    final k = 'r_${exIdx}_$setIdx';
    var ctrl = _controllers[k];
    if (ctrl == null) {
      ctrl = TextEditingController(text: val.toString());
      _controllers[k] = ctrl;
    }
    return ctrl;
  }

  TextEditingController _getTimeCtrl(int exIdx, int setIdx, int val) {
    final k = 't_${exIdx}_$setIdx';
    var ctrl = _controllers[k];
    if (ctrl == null) {
      ctrl = TextEditingController(text: '${val}s');
      _controllers[k] = ctrl;
    }
    return ctrl;
  }

  TextEditingController _getSubMovementWeightCtrl(
      int exIdx, int setIdx, int mIdx, double val) {
    final k = 'smw_${exIdx}_${setIdx}_$mIdx';
    var ctrl = _controllers[k];
    if (ctrl == null) {
      ctrl = TextEditingController(
        text: val == 0
            ? '0'
            : (val % 1 == 0 ? val.toInt().toString() : val.toString()),
      );
      _controllers[k] = ctrl;
    }
    return ctrl;
  }

  TextEditingController _getSubMovementRepsCtrl(
      int exIdx, int setIdx, int mIdx, int val) {
    final k = 'smr_${exIdx}_${setIdx}_$mIdx';
    var ctrl = _controllers[k];
    if (ctrl == null) {
      ctrl = TextEditingController(text: val.toString());
      _controllers[k] = ctrl;
    }
    return ctrl;
  }

  TextEditingController _getSubMovementTimeCtrl(
      int exIdx, int setIdx, int mIdx, int val) {
    final k = 'smt_${exIdx}_${setIdx}_$mIdx';
    var ctrl = _controllers[k];
    if (ctrl == null) {
      ctrl = TextEditingController(text: '${val}s');
      _controllers[k] = ctrl;
    }
    return ctrl;
  }


  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _exerciseLogs = widget.schedule.exercises.map((exercise) {
      return ExerciseCompletionLog(
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        targetMuscle: exercise.targetMuscle,
        isTimeBased: exercise.isTimeBased,
        isSuperset: exercise.isSuperset,
        supersetName: exercise.supersetName,
        supersetTargetMuscle: exercise.supersetTargetMuscle,
        supersetIsTimeBased: exercise.supersetIsTimeBased,
        supersetMovements: exercise.supersetMovements,
        sets: List.generate(
          exercise.defaultSets > 0 ? exercise.defaultSets : 3,
          (index) => ExerciseSetLog(
            setNumber: index + 1,
            reps: exercise.defaultReps > 0 ? exercise.defaultReps : 10,
            timeSeconds: exercise.defaultTimeSeconds > 0
                ? exercise.defaultTimeSeconds
                : 60,
            weightKg: exercise.defaultWeightKg,
            completed: true,
            subMovements: exercise.supersetMovements.map((sm) {
              return SubMovementSetLog(
                movementId: sm.id,
                name: sm.name,
                targetMuscle: sm.targetMuscle,
                isTimeBased: sm.isTimeBased,
                reps: sm.defaultReps > 0 ? sm.defaultReps : 10,
                timeSeconds:
                    sm.defaultTimeSeconds > 0 ? sm.defaultTimeSeconds : 60,
                weightKg: sm.defaultWeightKg,
                completed: true,
              );
            }).toList(),
            supersetReps: (exercise.supersetReps ?? 0) > 0
                ? exercise.supersetReps!
                : 10,
            supersetTimeSeconds: (exercise.supersetTimeSeconds ?? 0) > 0
                ? exercise.supersetTimeSeconds!
                : 60,
            supersetWeightKg: exercise.supersetWeightKg ?? 0.0,
          ),
        ),
      );
    }).toList();
    _loadPerformanceAndPRs();
  }

  void _loadPerformanceAndPRs() {
    final storage = StorageService();
    for (final exercise in widget.schedule.exercises) {
      final key = exercise.name.trim().toLowerCase();
      _lastPerformanceCache[key] = storage.getLastPerformance(exercise.name);
      _prCache[key] = storage.getPersonalRecord(exercise.name);

      if (exercise.isSuperset) {
        for (final sm in exercise.supersetMovements) {
          if (sm.name.trim().isNotEmpty) {
            final sKey = sm.name.trim().toLowerCase();
            _lastPerformanceCache[sKey] = storage.getLastPerformance(sm.name);
            _prCache[sKey] = storage.getPersonalRecord(sm.name);
          }
        }
        if (exercise.supersetName?.isNotEmpty ?? false) {
          final legacyKey = exercise.supersetName!.trim().toLowerCase();
          _lastPerformanceCache[legacyKey] =
              storage.getLastPerformance(exercise.supersetName!);
          _prCache[legacyKey] =
              storage.getPersonalRecord(exercise.supersetName!);
        }
      }
    }
  }

  bool _isSetPR(String exName, double weight, int reps, int timeSeconds,
      bool isTimeBased) {
    final pr = _prCache[exName.trim().toLowerCase()];
    if (pr == null || !pr.hasRecord) {
      return isTimeBased ? timeSeconds > 0 : weight > 0;
    }
    if (isTimeBased) {
      if (timeSeconds > pr.maxHoldSeconds) return true;
      if (timeSeconds == pr.maxHoldSeconds && weight > pr.maxWeightKg) {
        return true;
      }
      return false;
    } else {
      if (weight > pr.maxWeightKg) return true;
      if (weight == pr.maxWeightKg && reps > pr.maxWeightReps) return true;
      return false;
    }
  }

  String? _formatLastSetText(String exName, int setIndex, bool isTimeBased) {
    final lastPerf = _lastPerformanceCache[exName.trim().toLowerCase()];
    if (lastPerf == null || lastPerf.sets.isEmpty) return null;

    final set = lastPerf.getSet(setIndex) ?? lastPerf.sets.last;
    if (isTimeBased) {
      final t = set.timeSeconds;
      final w = set.weightKg > 0
          ? ' (+${set.weightKg % 1 == 0 ? set.weightKg.toInt() : set.weightKg}kg)'
          : '';
      return 'Last: ${t}s$w';
    } else {
      final w = set.weightKg % 1 == 0 ? set.weightKg.toInt() : set.weightKg;
      return 'Last: ${w}kg × ${set.reps}';
    }
  }

  String? _formatLastSubMovementSetText(
      String subName, int setIndex, bool isTimeBased) {
    final lastPerf = _lastPerformanceCache[subName.trim().toLowerCase()];
    if (lastPerf == null || lastPerf.sets.isEmpty) return null;

    final set = lastPerf.getSet(setIndex) ?? lastPerf.sets.last;
    if (isTimeBased) {
      final t = set.timeSeconds;
      final w = set.weightKg > 0
          ? ' (+${set.weightKg % 1 == 0 ? set.weightKg.toInt() : set.weightKg}kg)'
          : '';
      return 'Last: ${t}s$w';
    } else {
      final w = set.weightKg % 1 == 0 ? set.weightKg.toInt() : set.weightKg;
      return 'Last: ${w}kg × ${set.reps}';
    }
  }

  Widget _buildExerciseHeaderStats(ExerciseCompletionLog exerciseLog) {
    final lastPerf =
        _lastPerformanceCache[exerciseLog.exerciseName.trim().toLowerCase()];
    final pr = _prCache[exerciseLog.exerciseName.trim().toLowerCase()];

    final hasLast = lastPerf != null && lastPerf.sets.isNotEmpty;
    final hasPR = pr != null && pr.hasRecord;

    if (!hasLast && !hasPR) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHighlight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '✨ First time tracking this exercise',
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    String? daysAgoText;
    if (hasLast) {
      final diffDays =
          DateTime.now().difference(lastPerf.completedDate).inDays;
      daysAgoText = diffDays == 0
          ? 'today'
          : diffDays == 1
              ? 'yesterday'
              : '${diffDays}d ago';
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (hasLast)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLighter,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.surfaceHighlight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history,
                    size: 11, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Last: ${lastPerf.sets.length} sets ($daysAgoText)',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        if (hasPR)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, size: 11, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  'PR: ${pr.formatSummary()}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primary,
              onPrimary: Colors.black,
              surface: AppTheme.surfaceDark,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addSetToExercise(int exerciseIndex) {
    setState(() {
      final exLog = _exerciseLogs[exerciseIndex];
      final currentSets = exLog.sets;
      final lastReps = currentSets.isNotEmpty ? currentSets.last.reps : 10;
      final lastTime =
          currentSets.isNotEmpty ? currentSets.last.timeSeconds : 60;
      final lastWeight =
          currentSets.isNotEmpty ? currentSets.last.weightKg : 0.0;
      final lastSuperReps =
          currentSets.isNotEmpty ? currentSets.last.supersetReps : 10;
      final lastSuperTime =
          currentSets.isNotEmpty ? currentSets.last.supersetTimeSeconds : 60;
      final lastSuperWeight =
          currentSets.isNotEmpty ? currentSets.last.supersetWeightKg : 0.0;

      final newSubMovements = <SubMovementSetLog>[];
      if (currentSets.isNotEmpty && currentSets.last.subMovements.isNotEmpty) {
        for (final sm in currentSets.last.subMovements) {
          newSubMovements.add(
            SubMovementSetLog(
              movementId: sm.movementId,
              name: sm.name,
              targetMuscle: sm.targetMuscle,
              isTimeBased: sm.isTimeBased,
              reps: sm.reps,
              timeSeconds: sm.timeSeconds,
              weightKg: sm.weightKg,
              completed: true,
            ),
          );
        }
      } else if (exLog.supersetMovements.isNotEmpty) {
        for (final sm in exLog.supersetMovements) {
          newSubMovements.add(
            SubMovementSetLog(
              movementId: sm.id,
              name: sm.name,
              targetMuscle: sm.targetMuscle,
              isTimeBased: sm.isTimeBased,
              reps: sm.defaultReps > 0 ? sm.defaultReps : 10,
              timeSeconds:
                  sm.defaultTimeSeconds > 0 ? sm.defaultTimeSeconds : 60,
              weightKg: sm.defaultWeightKg,
              completed: true,
            ),
          );
        }
      }

      currentSets.add(
        ExerciseSetLog(
          setNumber: currentSets.length + 1,
          reps: lastReps,
          timeSeconds: lastTime,
          weightKg: lastWeight,
          completed: true,
          subMovements: newSubMovements,
          supersetReps: lastSuperReps,
          supersetTimeSeconds: lastSuperTime,
          supersetWeightKg: lastSuperWeight,
        ),
      );
    });
  }

  void _removeSet(int exerciseIndex, int setIndex) {
    setState(() {
      final currentSets = _exerciseLogs[exerciseIndex].sets;
      if (currentSets.length > 1) {
        currentSets.removeAt(setIndex);
        // Renumber remaining sets
        for (int i = 0; i < currentSets.length; i++) {
          currentSets[i].setNumber = i + 1;
        }
        // Invalidate cached controllers for this exercise so they re-sync
        _controllers.removeWhere((k, _) => k.contains('_${exerciseIndex}_'));
      }
    });
  }

  Future<void> _saveWorkout() async {
    setState(() => _isSaving = true);

    final newPRs = <String>[];
    for (final ex in _exerciseLogs) {
      bool exPR = false;
      for (final s in ex.sets) {
        if (!s.completed) continue;

        if (_isSetPR(ex.exerciseName, s.weightKg, s.reps, s.timeSeconds,
            ex.isTimeBased)) {
          s.isPersonalRecord = true;
          exPR = true;
        }

        if (ex.isSuperset) {
          for (final sm in s.subMovements) {
            final smName = sm.name ?? '';
            if (smName.isNotEmpty &&
                _isSetPR(smName, sm.weightKg, sm.reps, sm.timeSeconds,
                    sm.isTimeBased)) {
              sm.isPersonalRecord = true;
              if (!newPRs.contains(smName)) {
                newPRs.add(smName);
              }
            }
          }
          if (s.subMovements.isNotEmpty) {
            s.supersetIsPersonalRecord = s.subMovements.first.isPersonalRecord;
          } else if (ex.supersetName?.isNotEmpty ?? false) {
            if (_isSetPR(
                ex.supersetName!,
                s.supersetWeightKg,
                s.supersetReps,
                s.supersetTimeSeconds,
                ex.supersetIsTimeBased)) {
              s.supersetIsPersonalRecord = true;
              if (!newPRs.contains(ex.supersetName!)) {
                newPRs.add(ex.supersetName!);
              }
            }
          }
        }
      }
      if (exPR && !newPRs.contains(ex.exerciseName)) {
        newPRs.add(ex.exerciseName);
      }
    }

    final log = WorkoutLog(
      id: const Uuid().v4(),
      scheduleId: widget.schedule.id,
      scheduleTitle: widget.schedule.title,
      completedDate: _selectedDate,
      durationMinutes: _durationMinutes,
      exerciseLogs: _exerciseLogs,
      overallNotes: _notesController.text.trim(),
    );

    await StorageService().saveLog(log);

    if (!mounted) return;

    final hasPR = newPRs.isNotEmpty;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: hasPR ? Colors.amber[700]! : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            Icon(hasPR ? Icons.emoji_events : Icons.check_circle,
                color: Colors.black),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasPR
                    ? '🏆 ${newPRs.length} New PR${newPRs.length > 1 ? "s" : ""} on ${newPRs.join(", ")}!'
                    : 'Logged "${widget.schedule.title}" successfully!',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Workout Session'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveWorkout,
            icon: const Icon(Icons.check, color: AppTheme.primary),
            label: const Text(
              'Save',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 16),
                _buildDateAndDurationSection(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.fitness_center,
                        size: 20, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Exercises & Sets',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_exerciseLogs.length} exercises',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(_exerciseLogs.length, (index) {
                  return _buildExerciseCard(index);
                }),
                const SizedBox(height: 12),
                _buildNotesCard(),
                const SizedBox(height: 80), // Extra space for sticky button
              ],
            ),
          ),
          _buildBottomSaveBar(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.surfaceDark,
            AppTheme.surfaceLighter.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceHighlight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.bolt,
              color: AppTheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.schedule.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (widget.schedule.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.schedule.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateAndDurationSection() {
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceHighlight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Session Details',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Date picker tile
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLighter,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.surfaceHighlight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month,
                            size: 20, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isToday ? 'Date (Today)' : 'Completion Date',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              Text(
                                dateFormat.format(_selectedDate),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down,
                            color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Duration picker
              Expanded(
                flex: 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLighter,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.surfaceHighlight),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: AppTheme.textSecondary,
                        onPressed: _durationMinutes > 5
                            ? () => setState(() => _durationMinutes -= 5)
                            : null,
                      ),
                      Column(
                        children: [
                          const Text('Duration',
                              style: TextStyle(
                                  fontSize: 10, color: AppTheme.textMuted)),
                          Text(
                            '$_durationMinutes min',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: AppTheme.textSecondary,
                        onPressed: () =>
                            setState(() => _durationMinutes += 5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openPlankStopwatch(
      int exerciseIndex, int setIndex, ExerciseSetLog set) {
    int elapsed = 0;
    bool isRunning = false;
    Timer? timer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setTimerState) {
            void toggleTimer() {
              if (isRunning) {
                timer?.cancel();
                setTimerState(() => isRunning = false);
              } else {
                setTimerState(() => isRunning = true);
                timer = Timer.periodic(const Duration(seconds: 1), (t) {
                  setTimerState(() => elapsed++);
                });
              }
            }

            final mins = elapsed ~/ 60;
            final secs = elapsed % 60;
            final timeDisplay =
                '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.timer, color: AppTheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_exerciseLogs[exerciseIndex].exerciseName} (Set ${set.setNumber})',
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Hold your plank & record exact duration',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLighter,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isRunning
                            ? AppTheme.secondary
                            : AppTheme.surfaceHighlight,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      timeDisplay,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: AppTheme.textPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: toggleTimer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRunning
                              ? AppTheme.accentRose
                              : AppTheme.secondary,
                          foregroundColor: Colors.black,
                        ),
                        icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
                        label: Text(isRunning
                            ? 'Pause'
                            : (elapsed > 0 ? 'Resume' : 'Start Timer')),
                      ),
                      if (elapsed > 0 && !isRunning) ...[
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () {
                            setTimerState(() => elapsed = 0);
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    timer?.cancel();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    timer?.cancel();
                    setState(() {
                      if (elapsed > 0) {
                        set.timeSeconds = elapsed;
                      }
                      set.completed = true;
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text(elapsed > 0 ? 'Save ${elapsed}s' : 'Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMovementMiniInputs({
    required bool isTime,
    required double weight,
    required TextEditingController weightCtrl,
    required int reps,
    required TextEditingController repsCtrl,
    required int timeSeconds,
    required TextEditingController timeCtrl,
    required ValueChanged<double> onWeightChanged,
    required ValueChanged<int> onRepsChanged,
    required ValueChanged<int> onTimeChanged,
    required Color color,
    required String movementTitle,
    required int exerciseIndex,
    required int setIndex,
    required ExerciseSetLog set,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Weight Stepper Box
        Container(
          width: 82,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.surfaceLighter,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.surfaceHighlight),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: weight >= 2.5
                    ? () {
                        final nw = (weight - 2.5).clamp(0.0, 999.0);
                        onWeightChanged(nw);
                        weightCtrl.text = nw == 0
                            ? '0'
                            : (nw % 1 == 0
                                ? nw.toInt().toString()
                                : nw.toStringAsFixed(1));
                      }
                    : null,
                child: const SizedBox(
                  width: 20,
                  height: 34,
                  child: Icon(Icons.remove,
                      size: 12, color: AppTheme.textSecondary),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: weightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    suffixText: 'k',
                    suffixStyle:
                        TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                  onChanged: (val) {
                    final p = double.tryParse(val);
                    if (p != null) onWeightChanged(p);
                  },
                ),
              ),
              InkWell(
                onTap: () {
                  final nw = weight + 2.5;
                  onWeightChanged(nw);
                  weightCtrl.text = nw % 1 == 0
                      ? nw.toInt().toString()
                      : nw.toStringAsFixed(1);
                },
                child: const SizedBox(
                  width: 20,
                  height: 34,
                  child: Icon(Icons.add,
                      size: 12, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Reps / Timed Hold Stepper Box
        Container(
          width: 82,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.surfaceLighter,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.surfaceHighlight),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: isTime
                    ? (timeSeconds >= 10
                        ? () {
                            final nt = (timeSeconds - 5).clamp(5, 3600);
                            onTimeChanged(nt);
                            timeCtrl.text = '${nt}s';
                          }
                        : null)
                    : (reps > 1
                        ? () {
                            final nr = reps - 1;
                            onRepsChanged(nr);
                            repsCtrl.text = nr.toString();
                          }
                        : null),
                child: const SizedBox(
                  width: 20,
                  height: 34,
                  child: Icon(Icons.remove,
                      size: 12, color: AppTheme.textSecondary),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: isTime ? timeCtrl : repsCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    suffixText: isTime ? '' : 'r',
                    suffixStyle:
                        const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                  onChanged: (val) {
                    if (isTime) {
                      final cleaned = val.replaceAll(RegExp(r'[^0-9]'), '');
                      final p = int.tryParse(cleaned);
                      if (p != null && p > 0) onTimeChanged(p);
                    } else {
                      final p = int.tryParse(val);
                      if (p != null && p > 0) onRepsChanged(p);
                    }
                  },
                ),
              ),
              InkWell(
                onTap: () {
                  if (isTime) {
                    final nt = timeSeconds + 5;
                    onTimeChanged(nt);
                    timeCtrl.text = '${nt}s';
                  } else {
                    final nr = reps + 1;
                    onRepsChanged(nr);
                    repsCtrl.text = nr.toString();
                  }
                },
                child: const SizedBox(
                  width: 20,
                  height: 34,
                  child: Icon(Icons.add,
                      size: 12, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _ensureSubMovements(ExerciseCompletionLog exLog, ExerciseSetLog set) {
    if (exLog.supersetMovements.isNotEmpty &&
        set.subMovements.length < exLog.supersetMovements.length) {
      for (int i = set.subMovements.length;
          i < exLog.supersetMovements.length;
          i++) {
        final smDef = exLog.supersetMovements[i];
        set.subMovements.add(
          SubMovementSetLog(
            movementId: smDef.id,
            name: smDef.name,
            targetMuscle: smDef.targetMuscle,
            isTimeBased: smDef.isTimeBased,
            reps: smDef.defaultReps > 0 ? smDef.defaultReps : 10,
            timeSeconds:
                smDef.defaultTimeSeconds > 0 ? smDef.defaultTimeSeconds : 60,
            weightKg: smDef.defaultWeightKg,
            completed: true,
          ),
        );
      }
    }
  }

  Widget _buildSupersetRow(
      int exerciseIndex, int setIndex, ExerciseSetLog set) {
    final exerciseLog = _exerciseLogs[exerciseIndex];
    _ensureSubMovements(exerciseLog, set);

    final isTime1 = exerciseLog.isTimeBased;

    final wCtrl1 = _getWeightCtrl(exerciseIndex, setIndex, set.weightKg);
    final rCtrl1 = _getRepsCtrl(exerciseIndex, setIndex, set.reps);
    final tCtrl1 = _getTimeCtrl(exerciseIndex, setIndex, set.timeSeconds);

    final lastText1 = _formatLastSetText(
      exerciseLog.exerciseName,
      setIndex,
      isTime1,
    );

    final isPR1 = set.completed &&
        _isSetPR(
          exerciseLog.exerciseName,
          set.weightKg,
          set.reps,
          set.timeSeconds,
          isTime1,
        );

    final subMovementWidgets = <Widget>[];
    final ghostAndPRChips = <Widget>[];

    if (lastText1 != null) {
      ghostAndPRChips.add(
        Text(
          '1: $lastText1',
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    if (isPR1) {
      ghostAndPRChips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            '1: PR!',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // Process all chained sub-movements
    for (int m = 0; m < set.subMovements.length; m++) {
      final subLog = set.subMovements[m];
      final subDef = m < exerciseLog.supersetMovements.length
          ? exerciseLog.supersetMovements[m]
          : null;
      final subName = (subLog.name?.isNotEmpty == true)
          ? subLog.name!
          : (subDef?.name.isNotEmpty == true
              ? subDef!.name
              : (m == 0 && exerciseLog.supersetName?.isNotEmpty == true
                  ? exerciseLog.supersetName!
                  : 'Movement ${m + 2}'));
      final subIsTime = subDef?.isTimeBased ?? subLog.isTimeBased;

      final wCtrlSub = _getSubMovementWeightCtrl(
          exerciseIndex, setIndex, m, subLog.weightKg);
      final rCtrlSub =
          _getSubMovementRepsCtrl(exerciseIndex, setIndex, m, subLog.reps);
      final tCtrlSub = _getSubMovementTimeCtrl(
          exerciseIndex, setIndex, m, subLog.timeSeconds);

      final lastTextSub =
          _formatLastSubMovementSetText(subName, setIndex, subIsTime);
      final isPRSub = set.completed &&
          _isSetPR(
            subName,
            subLog.weightKg,
            subLog.reps,
            subLog.timeSeconds,
            subIsTime,
          );

      if (lastTextSub != null) {
        ghostAndPRChips.add(
          Text(
            '${m + 2}: $lastTextSub',
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }
      if (isPRSub) {
        ghostAndPRChips.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${m + 2}: PR!',
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      }

      subMovementWidgets.add(const SizedBox(height: 8));
      subMovementWidgets.add(
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, size: 11, color: AppTheme.accentAmber),
                  const SizedBox(width: 2),
                  Text(
                    '${m + 2}. $subName',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentAmber,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Spacer(),
            _buildMovementMiniInputs(
              isTime: subIsTime,
              weight: subLog.weightKg,
              weightCtrl: wCtrlSub,
              reps: subLog.reps,
              repsCtrl: rCtrlSub,
              timeSeconds: subLog.timeSeconds,
              timeCtrl: tCtrlSub,
              onWeightChanged: (w) => setState(() {
                subLog.weightKg = w;
                if (m == 0) set.supersetWeightKg = w;
              }),
              onRepsChanged: (r) => setState(() {
                subLog.reps = r;
                if (m == 0) set.supersetReps = r;
              }),
              onTimeChanged: (t) => setState(() {
                subLog.timeSeconds = t;
                if (m == 0) set.supersetTimeSeconds = t;
              }),
              color: AppTheme.accentAmber,
              movementTitle: subName,
              exerciseIndex: exerciseIndex,
              setIndex: setIndex,
              set: set,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: setIndex % 2 == 1
          ? AppTheme.surfaceLighter.withValues(alpha: 0.2)
          : Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Round Number Badge
          SizedBox(
            width: 36,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: set.completed
                    ? AppTheme.accentAmber.withValues(alpha: 0.18)
                    : AppTheme.surfaceLighter,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: set.completed
                      ? AppTheme.accentAmber.withValues(alpha: 0.5)
                      : AppTheme.surfaceHighlight,
                ),
              ),
              child: Text(
                '${set.setNumber}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: set.completed
                      ? AppTheme.accentAmber
                      : AppTheme.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // All Paired Movements (Movement 1 + SubMovements)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Movement 1 Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '1. ${exerciseLog.exerciseName}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    _buildMovementMiniInputs(
                      isTime: isTime1,
                      weight: set.weightKg,
                      weightCtrl: wCtrl1,
                      reps: set.reps,
                      repsCtrl: rCtrl1,
                      timeSeconds: set.timeSeconds,
                      timeCtrl: tCtrl1,
                      onWeightChanged: (w) => setState(() => set.weightKg = w),
                      onRepsChanged: (r) => setState(() => set.reps = r),
                      onTimeChanged: (t) => setState(() => set.timeSeconds = t),
                      color: AppTheme.primary,
                      movementTitle: exerciseLog.exerciseName,
                      exerciseIndex: exerciseIndex,
                      setIndex: setIndex,
                      set: set,
                    ),
                  ],
                ),
                ...subMovementWidgets,
                if (ghostAndPRChips.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 3,
                    children: ghostAndPRChips,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Checkbox & Delete
          SizedBox(
            width: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      set.completed = !set.completed;
                    });
                  },
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: set.completed
                          ? AppTheme.accentAmber
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: set.completed
                            ? AppTheme.accentAmber
                            : AppTheme.surfaceHighlight,
                        width: 1.5,
                      ),
                    ),
                    child: set.completed
                        ? const Icon(Icons.check,
                            size: 16, color: Colors.black)
                        : null,
                  ),
                ),
                if (_exerciseLogs[exerciseIndex].sets.length > 1) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _removeSet(exerciseIndex, setIndex),
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close,
                          size: 16, color: AppTheme.accentRose),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(int exerciseIndex) {
    final exerciseLog = _exerciseLogs[exerciseIndex];
    final isTimeBased = exerciseLog.isTimeBased;
    final isSuperset = exerciseLog.isSuperset;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceHighlight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isSuperset) ...[
                            const Icon(Icons.bolt,
                                size: 16, color: AppTheme.accentAmber),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              isSuperset
                                  ? exerciseLog.allExerciseNames.join(' + ')
                                  : exerciseLog.exerciseName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSuperset
                                    ? AppTheme.accentAmber
                                    : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (isSuperset) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentAmber
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AppTheme.accentAmber
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                exerciseLog.supersetBadgeTitle.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentAmber,
                                ),
                              ),
                            ),
                          ] else if (isTimeBased) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.secondary
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.timer,
                                      size: 11, color: AppTheme.secondary),
                                  SizedBox(width: 3),
                                  Text(
                                    'TIMED HOLD',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isSuperset
                                  ? '1: ${exerciseLog.targetMuscle}'
                                  : exerciseLog.targetMuscle,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.secondary,
                              ),
                            ),
                          ),
                          if (isSuperset) ...[
                            for (int m = 0;
                                m < exerciseLog.supersetMovements.length;
                                m++)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentAmber
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${m + 2}: ${exerciseLog.supersetMovements[m].targetMuscle}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.accentAmber,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildExerciseHeaderStats(exerciseLog),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addSetToExercise(exerciseIndex),
                  icon:
                      const Icon(Icons.add, size: 16, color: AppTheme.primary),
                  label: Text(
                    isSuperset ? 'Add Round' : 'Add Set',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor:
                        AppTheme.primary.withValues(alpha: 0.1),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.surfaceHighlight),
          // Set Column Headers
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: AppTheme.bgDark.withValues(alpha: 0.4),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(isSuperset ? 'ROUND' : 'SET',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSuperset
                              ? AppTheme.accentAmber
                              : AppTheme.textMuted)),
                ),
                const SizedBox(width: 6),
                if (isSuperset) ...[
                  Expanded(
                    child: Text(
                        exerciseLog.totalMovements == 2
                            ? 'PAIRED MOVEMENTS (1 & 2)'
                            : 'PAIRED MOVEMENTS (${exerciseLog.totalMovements})',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted)),
                  ),
                ] else ...[
                  Expanded(
                    flex: isTimeBased ? 3 : 3,
                    child: Text(
                        isTimeBased ? 'EXTRA WT (KG)' : 'WEIGHT (KG)',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: isTimeBased ? 4 : 3,
                    child: Text(
                        isTimeBased ? 'HOLD DURATION' : 'REPS',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted)),
                  ),
                ],
                const SizedBox(width: 6),
                const SizedBox(
                  width: 64,
                  child: Text('DONE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted)),
                ),
              ],
            ),
          ),
          // List of Sets
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: exerciseLog.sets.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, color: AppTheme.surfaceHighlight),
            itemBuilder: (context, setIndex) {
              final set = exerciseLog.sets[setIndex];
              return isSuperset
                  ? _buildSupersetRow(exerciseIndex, setIndex, set)
                  : _buildSetRow(exerciseIndex, setIndex, set);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSetRow(int exerciseIndex, int setIndex, ExerciseSetLog set) {
    final exerciseName = _exerciseLogs[exerciseIndex].exerciseName;
    final isTimeBased = _exerciseLogs[exerciseIndex].isTimeBased;
    final weightCtrl =
        _getWeightCtrl(exerciseIndex, setIndex, set.weightKg);
    final repsCtrl = _getRepsCtrl(exerciseIndex, setIndex, set.reps);
    final timeCtrl =
        _getTimeCtrl(exerciseIndex, setIndex, set.timeSeconds);

    final lastSetText = _formatLastSetText(exerciseName, setIndex, isTimeBased);
    final isPR = set.completed &&
        _isSetPR(
          exerciseName,
          set.weightKg,
          set.reps,
          set.timeSeconds,
          isTimeBased,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
          // Set Badge
          SizedBox(
            width: 36,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: set.completed
                    ? (isTimeBased
                        ? AppTheme.secondary.withValues(alpha: 0.15)
                        : AppTheme.primary.withValues(alpha: 0.15))
                    : AppTheme.surfaceLighter,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${set.setNumber}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: set.completed
                      ? (isTimeBased ? AppTheme.secondary : AppTheme.primary)
                      : AppTheme.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Weight Controls (Optional for plank/time-based, default for reps)
          Expanded(
            flex: isTimeBased ? 3 : 3,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLighter,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.surfaceHighlight),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: set.weightKg >= 2.5
                        ? () {
                            setState(() {
                              set.weightKg = (set.weightKg - 2.5)
                                  .clamp(0.0, 999.0);
                              weightCtrl.text = set.weightKg == 0
                                  ? '0'
                                  : (set.weightKg % 1 == 0
                                      ? set.weightKg.toInt().toString()
                                      : set.weightKg.toStringAsFixed(1));
                            });
                          }
                        : null,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(8)),
                    child: const SizedBox(
                      width: 26,
                      height: 38,
                      child: Icon(Icons.remove,
                          size: 13, color: AppTheme.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('w_${exerciseIndex}_$setIndex'),
                      controller: weightCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val);
                        if (parsed != null) set.weightKg = parsed;
                      },
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        set.weightKg += 2.5;
                        weightCtrl.text = set.weightKg % 1 == 0
                            ? set.weightKg.toInt().toString()
                            : set.weightKg.toStringAsFixed(1);
                      });
                    },
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(8)),
                    child: const SizedBox(
                      width: 26,
                      height: 38,
                      child: Icon(Icons.add,
                          size: 13, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Reps OR Timed Duration Controls
          if (!isTimeBased)
            Expanded(
              flex: 3,
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLighter,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.surfaceHighlight),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: set.reps > 1
                          ? () {
                              setState(() {
                                set.reps -= 1;
                                repsCtrl.text = set.reps.toString();
                              });
                            }
                          : null,
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(8)),
                      child: const SizedBox(
                        width: 26,
                        height: 38,
                        child: Icon(Icons.remove,
                            size: 13, color: AppTheme.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('r_${exerciseIndex}_$setIndex'),
                        controller: repsCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null && parsed > 0) {
                            set.reps = parsed;
                          }
                        },
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          set.reps += 1;
                          repsCtrl.text = set.reps.toString();
                        });
                      },
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(8)),
                      child: const SizedBox(
                        width: 26,
                        height: 38,
                        child: Icon(Icons.add,
                          size: 13, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // Timed hold control with stopwatch launcher
            Expanded(
              flex: 4,
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLighter,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.surfaceHighlight),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: set.timeSeconds >= 10
                          ? () {
                              setState(() {
                                set.timeSeconds = (set.timeSeconds - 5)
                                    .clamp(5, 3600);
                                timeCtrl.text = '${set.timeSeconds}s';
                              });
                            }
                          : null,
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(8)),
                      child: const SizedBox(
                        width: 22,
                        height: 38,
                        child: Icon(Icons.remove,
                            size: 12, color: AppTheme.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('t_${exerciseIndex}_$setIndex'),
                        controller: timeCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.secondary,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        onChanged: (val) {
                          final cleaned =
                              val.replaceAll(RegExp(r'[^0-9]'), '');
                          final parsed = int.tryParse(cleaned);
                          if (parsed != null && parsed > 0) {
                            set.timeSeconds = parsed;
                          }
                        },
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          set.timeSeconds += 5;
                          timeCtrl.text = '${set.timeSeconds}s';
                        });
                      },
                      child: const SizedBox(
                        width: 22,
                        height: 38,
                        child: Icon(Icons.add,
                            size: 12, color: AppTheme.textSecondary),
                      ),
                    ),
                    // Live Plank Stopwatch Button
                    InkWell(
                      onTap: () async {
                        _openPlankStopwatch(exerciseIndex, setIndex, set);
                        timeCtrl.text = '${set.timeSeconds}s';
                      },
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(8)),
                      child: Container(
                        width: 26,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.12),
                          borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(7)),
                        ),
                        child: const Icon(Icons.timer_outlined,
                            size: 16, color: AppTheme.secondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 6),
          // Done Checkbox & Direct Delete Icon (Fixed 64px width - Zero Overflow!)
          SizedBox(
            width: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      set.completed = !set.completed;
                    });
                  },
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: set.completed
                          ? (isTimeBased
                              ? AppTheme.secondary
                              : AppTheme.primary)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: set.completed
                            ? (isTimeBased
                                ? AppTheme.secondary
                                : AppTheme.primary)
                            : AppTheme.surfaceHighlight,
                        width: 1.5,
                      ),
                    ),
                    child: set.completed
                        ? const Icon(Icons.check,
                            size: 16, color: Colors.black)
                        : null,
                  ),
                ),
                if (_exerciseLogs[exerciseIndex].sets.length > 1) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _removeSet(exerciseIndex, setIndex),
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close,
                          size: 16, color: AppTheme.accentRose),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      if (lastSetText != null || isPR) ...[
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 42),
          child: Row(
            children: [
              if (lastSetText != null) ...[
                const Icon(Icons.history, size: 11, color: AppTheme.textMuted),
                const SizedBox(width: 3),
                Text(
                  lastSetText,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (isPR) ...[
                if (lastSetText != null) const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department,
                          size: 10, color: Colors.white),
                      SizedBox(width: 2),
                      Text(
                        'NEW PR!',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ],
  ),
);
  }

  Widget _buildNotesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceHighlight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note, size: 20, color: AppTheme.secondary),
              SizedBox(width: 8),
              Text(
                'Session Notes (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            maxLines: 2,
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'e.g. Felt great on chest, struggled slightly on last rep of bench...',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSaveBar() {
    final totalCompletedSets =
        _exerciseLogs.fold(0, (sum, e) => sum + e.completedSets);
    final totalCompletedReps =
        _exerciseLogs.fold(0, (sum, e) => sum + e.totalReps);
    final totalHoldSeconds =
        _exerciseLogs.fold(0, (sum, e) => sum + e.totalTimeSeconds);

    final summaryText = totalHoldSeconds > 0
        ? '$totalCompletedSets sets • $totalCompletedReps reps • ${totalHoldSeconds}s hold'
        : '$totalCompletedSets sets • $totalCompletedReps reps done';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(
          top: BorderSide(color: AppTheme.surfaceHighlight),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  summaryText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  DateFormat('yyyy-MM-dd').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveWorkout,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.check_circle_outline, color: Colors.black),
            label: Text(_isSaving ? 'Saving...' : 'Finish & Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
