import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/workout_schedule.dart';
import '../models/workout_log.dart';
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
          ),
        ),
      );
    }).toList();
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
      final currentSets = _exerciseLogs[exerciseIndex].sets;
      final lastReps = currentSets.isNotEmpty ? currentSets.last.reps : 10;
      final lastTime =
          currentSets.isNotEmpty ? currentSets.last.timeSeconds : 60;
      final lastWeight =
          currentSets.isNotEmpty ? currentSets.last.weightKg : 0.0;
      currentSets.add(
        ExerciseSetLog(
          setNumber: currentSets.length + 1,
          reps: lastReps,
          timeSeconds: lastTime,
          weightKg: lastWeight,
          completed: true,
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.black),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Logged "${widget.schedule.title}" successfully!',
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

  Widget _buildExerciseCard(int exerciseIndex) {
    final exerciseLog = _exerciseLogs[exerciseIndex];
    final isTimeBased = exerciseLog.isTimeBased;

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
                          Flexible(
                            child: Text(
                              exerciseLog.exerciseName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (isTimeBased) ...[
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          exerciseLog.targetMuscle,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addSetToExercise(exerciseIndex),
                  icon:
                      const Icon(Icons.add, size: 16, color: AppTheme.primary),
                  label: const Text(
                    'Add Set',
                    style: TextStyle(
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
                const SizedBox(
                  width: 36,
                  child: Text('SET',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted)),
                ),
                const SizedBox(width: 6),
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
              return _buildSetRow(exerciseIndex, setIndex, set);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSetRow(int exerciseIndex, int setIndex, ExerciseSetLog set) {
    final isTimeBased = _exerciseLogs[exerciseIndex].isTimeBased;
    final weightCtrl =
        _getWeightCtrl(exerciseIndex, setIndex, set.weightKg);
    final repsCtrl = _getRepsCtrl(exerciseIndex, setIndex, set.reps);
    final timeCtrl =
        _getTimeCtrl(exerciseIndex, setIndex, set.timeSeconds);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
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
