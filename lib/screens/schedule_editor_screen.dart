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

  void _showAddExerciseDialog({Exercise? existing, int? editIndex}) {
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

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add Exercise' : 'Edit Exercise'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Exercise Name',
                        hintText: 'e.g. Plank, Bench Press, Wall Sit',
                      ),
                      onChanged: (val) {
                        // Helpful auto-suggestion for Plank / Wall Sit
                        final lower = val.toLowerCase();
                        if ((lower.contains('plank') ||
                                lower.contains('wall sit') ||
                                lower.contains('hold')) &&
                            !isTimeBased) {
                          setDialogState(() {
                            isTimeBased = true;
                            if (muscleCtrl.text == 'General') {
                              muscleCtrl.text = 'Core';
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: muscleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Target Muscle',
                        hintText: 'e.g. Core, Chest, Legs',
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Exercise Type Selector: Reps vs Timed
                    const Text(
                      'Tracking Mode',
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
                            onTap: () => setDialogState(() => isTimeBased = false),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isTimeBased
                                    ? AppTheme.primary.withValues(alpha: 0.2)
                                    : AppTheme.surfaceLighter,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: !isTimeBased
                                      ? AppTheme.primary
                                      : AppTheme.surfaceHighlight,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.repeat,
                                      size: 16,
                                      color: !isTimeBased
                                          ? AppTheme.primary
                                          : AppTheme.textMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Reps & Sets',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: !isTimeBased
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
                            onTap: () => setDialogState(() => isTimeBased = true),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isTimeBased
                                    ? AppTheme.secondary.withValues(alpha: 0.2)
                                    : AppTheme.surfaceLighter,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isTimeBased
                                      ? AppTheme.secondary
                                      : AppTheme.surfaceHighlight,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.timer,
                                      size: 16,
                                      color: isTimeBased
                                          ? AppTheme.secondary
                                          : AppTheme.textMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Timed (Plank)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isTimeBased
                                          ? AppTheme.secondary
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
                    const SizedBox(height: 14),
                    // Sets and Reps/Duration
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: setsCtrl,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Sets'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!isTimeBased)
                          Expanded(
                            child: TextField(
                              controller: repsCtrl,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(labelText: 'Reps/Set'),
                            ),
                          )
                        else
                          Expanded(
                            child: TextField(
                              controller: timeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Seconds',
                                suffixText: 'sec',
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (isTimeBased) ...[
                      const SizedBox(height: 8),
                      // Quick duration presets
                      Wrap(
                        spacing: 6,
                        children: [30, 45, 60, 90, 120].map((sec) {
                          return ActionChip(
                            label: Text('${sec}s'),
                            padding: EdgeInsets.zero,
                            labelStyle: const TextStyle(fontSize: 11),
                            backgroundColor: AppTheme.surfaceLighter,
                            onPressed: () {
                              setDialogState(() {
                                timeCtrl.text = sec.toString();
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: weightCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: isTimeBased
                            ? 'Extra Weight (Optional, kg)'
                            : 'Weight (kg/lbs)',
                        hintText: '0',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
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
                      );
                      if (editIndex != null) {
                        _exercises[editIndex] = newEx;
                      } else {
                        _exercises.add(newEx);
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save Exercise'),
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
                            color: ex.isTimeBased
                                ? AppTheme.secondary.withValues(alpha: 0.15)
                                : AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            ex.isTimeBased ? Icons.timer : Icons.fitness_center,
                            size: 16,
                            color: ex.isTimeBased
                                ? AppTheme.secondary
                                : AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ex.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ex.isTimeBased
                                    ? '${ex.targetMuscle} • ${ex.defaultSets} sets × ${ex.defaultTimeSeconds}s hold ${ex.defaultWeightKg > 0 ? '(+${ex.defaultWeightKg}kg)' : ''}'
                                    : '${ex.targetMuscle} • ${ex.defaultSets} sets × ${ex.defaultReps} reps • ${ex.defaultWeightKg}kg',
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
