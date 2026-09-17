import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/exercise.dart';
import '../models/workout_schedule.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class ScheduleEditorScreen extends StatefulWidget {
  final WorkoutSchedule? scheduleToEdit;

  const ScheduleEditorScreen({super.key, this.scheduleToEdit});

  @override
  State<ScheduleEditorScreen> createState() => _ScheduleEditorScreenState();
}

class _SubMovementDraft {
  final TextEditingController nameCtrl;
  final TextEditingController muscleCtrl;
  final TextEditingController repsCtrl;
  final TextEditingController timeCtrl;
  final TextEditingController weightCtrl;
  bool isTimeBased;

  _SubMovementDraft({
    String name = '',
    String muscle = 'General',
    int reps = 10,
    int timeSeconds = 60,
    double weightKg = 0.0,
    this.isTimeBased = false,
  })  : nameCtrl = TextEditingController(text: name),
        muscleCtrl = TextEditingController(text: muscle),
        repsCtrl = TextEditingController(text: reps.toString()),
        timeCtrl = TextEditingController(text: timeSeconds.toString()),
        weightCtrl = TextEditingController(
          text: weightKg == 0
              ? '0'
              : (weightKg % 1 == 0
                  ? weightKg.toInt().toString()
                  : weightKg.toString()),
        );

  void dispose() {
    nameCtrl.dispose();
    muscleCtrl.dispose();
    repsCtrl.dispose();
    timeCtrl.dispose();
    weightCtrl.dispose();
  }
}

class _ScheduleEditorScreenState extends State<ScheduleEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  static final _uuid = const Uuid();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  late List<String> _selectedDays;
  late List<Exercise> _exercises;
  late String _selectedColorHex;

  final List<String> _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  final List<String> _colorOptions = [
    '#10B981', // Emerald
    '#06B6D4', // Cyan
    '#F59E0B', // Amber
    '#8B5CF6', // Purple
    '#EC4899', // Pink
    '#3B82F6', // Blue
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.scheduleToEdit;
    _titleController = TextEditingController(text: s?.title ?? '');
    _descriptionController =
        TextEditingController(text: s?.description ?? '');
    _selectedDays = List.from(s?.scheduledDays ?? []);
    _exercises = List.from(s?.exercises ?? []);
    _selectedColorHex = s?.colorHex ?? '#10B981';

    if (_exercises.isEmpty && s == null) {
      // Add one empty template exercise
      _exercises.add(
        Exercise(
          id: _uuid.v4(),
          name: 'Bench Press',
          targetMuscle: 'Chest',
          defaultSets: 3,
          defaultReps: 10,
          defaultWeightKg: 50.0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Widget _buildSubMovementDraftCard({
    required _SubMovementDraft draft,
    required int index,
    required int totalDrafts,
    required VoidCallback onRemove,
    required void Function(VoidCallback) setDialogState,
  }) {
    final movNum = index + 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const Divider(height: 1, color: AppTheme.surfaceHighlight),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, size: 13, color: AppTheme.accentAmber),
                  const SizedBox(width: 4),
                  Text(
                    'MOVEMENT $movNum (BACK-TO-BACK)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentAmber,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (totalDrafts > 1)
              IconButton(
                tooltip: 'Remove Movement $movNum',
                icon: const Icon(Icons.close, size: 16, color: AppTheme.accentRose),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onRemove,
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: draft.nameCtrl,
          decoration: InputDecoration(
            labelText: 'Movement $movNum Name',
            hintText: movNum == 2
                ? 'e.g. Triceps Pushdowns'
                : 'e.g. Lateral Raises, Planks',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: draft.muscleCtrl,
          decoration: InputDecoration(
            labelText: 'Movement $movNum Target Muscle',
            hintText: 'e.g. Triceps, Delts, Core',
          ),
        ),
        const SizedBox(height: 12),

        // Movement Type Selector
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setDialogState(() => draft.isTimeBased = false),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: !draft.isTimeBased
                        ? AppTheme.accentAmber.withValues(alpha: 0.15)
                        : AppTheme.surfaceLighter,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: !draft.isTimeBased
                          ? AppTheme.accentAmber
                          : AppTheme.surfaceHighlight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Reps & Sets',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: !draft.isTimeBased
                            ? AppTheme.accentAmber
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => setDialogState(() => draft.isTimeBased = true),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: draft.isTimeBased
                        ? AppTheme.secondary.withValues(alpha: 0.15)
                        : AppTheme.surfaceLighter,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: draft.isTimeBased
                          ? AppTheme.secondary
                          : AppTheme.surfaceHighlight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Timed Hold',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: draft.isTimeBased
                            ? AppTheme.secondary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: draft.isTimeBased ? draft.timeCtrl : draft.repsCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: draft.isTimeBased ? 'Hold (s)' : 'Reps',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: draft.weightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddExerciseDialog({Exercise? existing, int? editIndex}) {
    bool isSuperset = existing?.isSuperset ?? false;

    // Movement 1 (Primary) controllers
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final muscleCtrl =
        TextEditingController(text: existing?.targetMuscle ?? 'General');
    final setsCtrl =
        TextEditingController(text: (existing?.defaultSets ?? 3).toString());
    final repsCtrl =
        TextEditingController(text: (existing?.defaultReps ?? 10).toString());
    final timeCtrl = TextEditingController(
        text: (existing?.defaultTimeSeconds ?? 60).toString());
    final weightCtrl = TextEditingController(
        text: (existing?.defaultWeightKg ?? 0.0).toString());
    bool isTimeBased = existing?.isTimeBased ?? false;

    // Sub-movements (Movement 2, 3, etc.) drafts
    final drafts = <_SubMovementDraft>[];
    if (existing != null && existing.isSuperset) {
      if (existing.supersetMovements.isNotEmpty) {
        for (final sm in existing.supersetMovements) {
          drafts.add(_SubMovementDraft(
            name: sm.name,
            muscle: sm.targetMuscle,
            reps: sm.defaultReps,
            timeSeconds: sm.defaultTimeSeconds,
            weightKg: sm.defaultWeightKg,
            isTimeBased: sm.isTimeBased,
          ));
        }
      } else if (existing.supersetName?.isNotEmpty ?? false) {
        drafts.add(_SubMovementDraft(
          name: existing.supersetName!,
          muscle: existing.supersetTargetMuscle ?? 'General',
          reps: existing.supersetReps ?? 10,
          timeSeconds: existing.supersetTimeSeconds ?? 60,
          weightKg: existing.supersetWeightKg ?? 0.0,
          isTimeBased: existing.supersetIsTimeBased,
        ));
      }
    }
    if (isSuperset && drafts.isEmpty) {
      drafts.add(_SubMovementDraft(name: '', muscle: 'General'));
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isSuperset ? Icons.bolt : Icons.fitness_center,
                    color: isSuperset ? AppTheme.accentAmber : AppTheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(existing == null ? 'Add Exercise' : 'Edit Exercise'),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mode Switcher: Normal vs Superset / Paired
                      const Text(
                        'Workout Structure',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => isSuperset = false),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !isSuperset
                                      ? AppTheme.primary.withValues(alpha: 0.2)
                                      : AppTheme.surfaceLighter,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: !isSuperset
                                        ? AppTheme.primary
                                        : AppTheme.surfaceHighlight,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.fitness_center,
                                        size: 15,
                                        color: !isSuperset
                                            ? AppTheme.primary
                                            : AppTheme.textMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Normal',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: !isSuperset
                                            ? AppTheme.primary
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  isSuperset = true;
                                  if (drafts.isEmpty) {
                                    drafts.add(_SubMovementDraft(
                                        name: '', muscle: 'General'));
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSuperset
                                      ? AppTheme.accentAmber.withValues(alpha: 0.2)
                                      : AppTheme.surfaceLighter,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSuperset
                                        ? AppTheme.accentAmber
                                        : AppTheme.surfaceHighlight,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.bolt,
                                        size: 16,
                                        color: isSuperset
                                            ? AppTheme.accentAmber
                                            : AppTheme.textMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      drafts.length <= 1
                                          ? '⚡ Superset (Pair)'
                                          : (drafts.length == 2
                                              ? '⚡ Tri-Set (3)'
                                              : '⚡ Giant Set (${drafts.length + 1})'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isSuperset
                                            ? AppTheme.accentAmber
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Section Header for Movement 1
                      if (isSuperset) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'MOVEMENT 1 (PRIMARY)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: isSuperset
                              ? 'Movement 1 Name'
                              : 'Exercise Name',
                          hintText: isSuperset
                              ? 'e.g. Bicep Curls'
                              : 'e.g. Plank, Bench Press, Squats',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: muscleCtrl,
                        decoration: InputDecoration(
                          labelText: isSuperset
                              ? 'Movement 1 Target Muscle'
                              : 'Target Muscle',
                          hintText: 'e.g. Chest, Biceps, Core',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Movement 1 Type Selector: Reps vs Timed
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  setDialogState(() => isTimeBased = false),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !isTimeBased
                                      ? AppTheme.primary.withValues(alpha: 0.15)
                                      : AppTheme.surfaceLighter,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: !isTimeBased
                                        ? AppTheme.primary
                                        : AppTheme.surfaceHighlight,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Reps & Sets',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: !isTimeBased
                                          ? AppTheme.primary
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  setDialogState(() => isTimeBased = true),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isTimeBased
                                      ? AppTheme.secondary.withValues(alpha: 0.15)
                                      : AppTheme.surfaceLighter,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isTimeBased
                                        ? AppTheme.secondary
                                        : AppTheme.surfaceHighlight,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Timed Hold',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isTimeBased
                                          ? AppTheme.secondary
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: isTimeBased ? timeCtrl : repsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isTimeBased ? 'Hold (s)' : 'Reps',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: weightCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Weight (kg)',
                              ),
                            ),
                          ),
                        ],
                      ),

                      // If Superset is enabled: ARBITRARY SUB-MOVEMENTS (2, 3, 4+)
                      if (isSuperset) ...[
                        for (int i = 0; i < drafts.length; i++)
                          _buildSubMovementDraftCard(
                            draft: drafts[i],
                            index: i,
                            totalDrafts: drafts.length,
                            onRemove: () {
                              setDialogState(() {
                                final removed = drafts.removeAt(i);
                                removed.dispose();
                              });
                            },
                            setDialogState: setDialogState,
                          ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              drafts.add(_SubMovementDraft(
                                  name: '', muscle: 'General'));
                            });
                          },
                          icon: const Icon(Icons.add,
                              size: 16, color: AppTheme.accentAmber),
                          label: Text(
                            '+ Add Movement ${drafts.length + 2} (${drafts.length == 1 ? "Make Tri-Set" : "Giant Set"})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentAmber,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: AppTheme.accentAmber
                                    .withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),
                      const Divider(
                          height: 1, color: AppTheme.surfaceHighlight),
                      const SizedBox(height: 14),

                      // Shared Total Sets / Rounds
                      TextField(
                        controller: setsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isSuperset
                              ? 'Total Paired / Superset Rounds'
                              : 'Total Sets',
                          hintText: '3',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSuperset
                        ? AppTheme.accentAmber
                        : AppTheme.primary,
                    foregroundColor: AppTheme.bgDark,
                  ),
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;

                    final sets = int.tryParse(setsCtrl.text) ?? 3;
                    final reps = int.tryParse(repsCtrl.text) ?? 10;
                    final time = int.tryParse(timeCtrl.text) ?? 60;
                    final weight = double.tryParse(weightCtrl.text) ?? 0.0;
                    final muscle = muscleCtrl.text.trim().isEmpty
                        ? 'General'
                        : muscleCtrl.text.trim();

                    // Map drafts to SupersetMovement objects
                    final subMovements = drafts.map((d) {
                      final sName = d.nameCtrl.text.trim();
                      final sMuscle = d.muscleCtrl.text.trim().isEmpty
                          ? 'General'
                          : d.muscleCtrl.text.trim();
                      final sReps = int.tryParse(d.repsCtrl.text) ?? 10;
                      final sTime = int.tryParse(d.timeCtrl.text) ?? 60;
                      final sWeight = double.tryParse(d.weightCtrl.text) ?? 0.0;
                      return SupersetMovement(
                        id: _uuid.v4(),
                        name: sName.isNotEmpty ? sName : 'Movement',
                        targetMuscle: sMuscle,
                        isTimeBased: d.isTimeBased,
                        defaultReps: sReps,
                        defaultTimeSeconds: sTime,
                        defaultWeightKg: sWeight,
                      );
                    }).toList();

                    final hasSubMovements =
                        isSuperset && subMovements.isNotEmpty;

                    setState(() {
                      final newEx = Exercise(
                        id: existing?.id ?? _uuid.v4(),
                        name: name,
                        targetMuscle: muscle,
                        isTimeBased: isTimeBased,
                        defaultSets: sets,
                        defaultReps: reps,
                        defaultTimeSeconds: time,
                        defaultWeightKg: weight,
                        isSuperset: hasSubMovements,
                        supersetMovements:
                            hasSubMovements ? subMovements : const [],
                        supersetName: hasSubMovements
                            ? subMovements.first.name
                            : null,
                        supersetTargetMuscle: hasSubMovements
                            ? subMovements.first.targetMuscle
                            : null,
                        supersetIsTimeBased: hasSubMovements
                            ? subMovements.first.isTimeBased
                            : false,
                        supersetReps: hasSubMovements
                            ? subMovements.first.defaultReps
                            : null,
                        supersetTimeSeconds: hasSubMovements
                            ? subMovements.first.defaultTimeSeconds
                            : null,
                        supersetWeightKg: hasSubMovements
                            ? subMovements.first.defaultWeightKg
                            : null,
                      );

                      if (editIndex != null) {
                        _exercises[editIndex] = newEx;
                      } else {
                        _exercises.add(newEx);
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    isSuperset ? 'Save Paired Routine' : 'Save Exercise',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) return;
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one exercise to the schedule.'),
          backgroundColor: AppTheme.accentRose,
        ),
      );
      return;
    }

    final schedule = WorkoutSchedule(
      id: widget.scheduleToEdit?.id ?? _uuid.v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      colorHex: _selectedColorHex,
      scheduledDays: _selectedDays,
      exercises: _exercises,
      createdAt: widget.scheduleToEdit?.createdAt ?? DateTime.now(),
    );

    await StorageService().saveSchedule(schedule);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.scheduleToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Schedule' : 'New Workout Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppTheme.primary),
            onPressed: _saveSchedule,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title input
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Schedule Title',
                hintText: 'e.g. Push Day A, Upper Body Strength',
                prefixIcon: Icon(Icons.fitness_center),
              ),
              validator: (val) => (val == null || val.trim().isEmpty)
                  ? 'Please enter a schedule title'
                  : null,
            ),
            const SizedBox(height: 14),
            // Description input
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description / Notes',
                hintText: 'e.g. Focus on chest pressing power and triceps pump',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            // Accent Color Picker
            const Text(
              'Color Tag',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: _colorOptions.map((hex) {
                final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                final isSelected = _selectedColorHex == hex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColorHex = hex),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 18, color: Colors.black)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // Target Days of Week
            const Text(
              'Scheduled Days (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _weekDays.map((day) {
                final isSelected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(day.substring(0, 3)),
                  selected: isSelected,
                  selectedColor: AppTheme.primary.withValues(alpha: 0.25),
                  checkmarkColor: AppTheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: AppTheme.surfaceDark,
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.surfaceHighlight,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDays.add(day);
                      } else {
                        _selectedDays.remove(day);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            // Exercises List Header
            Row(
              children: [
                const Icon(Icons.list_alt, size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Exercises in Schedule',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showAddExerciseDialog(),
                  icon: const Icon(Icons.add, size: 16, color: Colors.black),
                  label: const Text('Add Exercise'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_exercises.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceHighlight),
                ),
                child: const Center(
                  child: Text(
                    'No exercises added yet.\nClick "+ Add Exercise" to start building this routine!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: _exercises.length,
                onReorderItem: (oldIdx, newIdx) {
                  setState(() {
                    final item = _exercises.removeAt(oldIdx);
                    _exercises.insert(newIdx, item);
                  });
                },
                itemBuilder: (context, idx) {
                  final ex = _exercises[idx];
                  return Container(
                    key: ValueKey(ex.id),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.surfaceHighlight),
                    ),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: idx,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.drag_handle,
                                color: AppTheme.textMuted, size: 20),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: ex.isSuperset
                                ? AppTheme.accentAmber.withValues(alpha: 0.18)
                                : (ex.isTimeBased
                                    ? AppTheme.secondary.withValues(alpha: 0.15)
                                    : AppTheme.primary.withValues(alpha: 0.15)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            ex.isSuperset
                                ? Icons.bolt
                                : (ex.isTimeBased
                                    ? Icons.timer
                                    : Icons.fitness_center),
                            size: 16,
                            color: ex.isSuperset
                                ? AppTheme.accentAmber
                                : (ex.isTimeBased
                                    ? AppTheme.secondary
                                    : AppTheme.primary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      ex.isSuperset
                                          ? ex.allExerciseNames.join(' + ')
                                          : ex.name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: ex.isSuperset
                                            ? AppTheme.accentAmber
                                            : AppTheme.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (ex.isSuperset) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentAmber
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: AppTheme.accentAmber
                                                .withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        ex.supersetBadgeTitle.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.accentAmber,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ex.isSuperset
                                    ? '${ex.defaultSets} rounds • ${[
                                        '1: ${ex.targetMuscle} (${ex.isTimeBased ? "${ex.defaultTimeSeconds}s" : "${ex.defaultReps}r"}${ex.defaultWeightKg > 0 ? " @ ${ex.defaultWeightKg}kg" : ""})',
                                        for (int m = 0;
                                            m < ex.supersetMovements.length;
                                            m++)
                                          '${m + 2}: ${ex.supersetMovements[m].targetMuscle} (${ex.supersetMovements[m].isTimeBased ? "${ex.supersetMovements[m].defaultTimeSeconds}s" : "${ex.supersetMovements[m].defaultReps}r"}${ex.supersetMovements[m].defaultWeightKg > 0 ? " @ ${ex.supersetMovements[m].defaultWeightKg}kg" : ""})',
                                      ].join(' + ')}'
                                    : (ex.isTimeBased
                                        ? '${ex.targetMuscle} • ${ex.defaultSets} sets × ${ex.defaultTimeSeconds}s hold ${ex.defaultWeightKg > 0 ? '(+${ex.defaultWeightKg}kg)' : ''}'
                                        : '${ex.targetMuscle} • ${ex.defaultSets} sets × ${ex.defaultReps} reps • ${ex.defaultWeightKg}kg'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              size: 18, color: AppTheme.textSecondary),
                          onPressed: () => _showAddExerciseDialog(
                              existing: ex, editIndex: idx),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: AppTheme.accentRose),
                          onPressed: () {
                            setState(() {
                              _exercises.removeAt(idx);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _saveSchedule,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                isEditing ? 'Update Schedule' : 'Create Workout Schedule',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
