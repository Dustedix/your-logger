import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/body_metric_log.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class LogWeightDialog extends StatefulWidget {
  final BodyMetricLog? initialMetric;

  const LogWeightDialog({super.key, this.initialMetric});

  static Future<bool?> show(BuildContext context, {BodyMetricLog? metric}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LogWeightDialog(initialMetric: metric),
    );
  }

  @override
  State<LogWeightDialog> createState() => _LogWeightDialogState();
}

class _LogWeightDialogState extends State<LogWeightDialog> {
  static const _uuid = Uuid();
  late DateTime _selectedDate;
  late TextEditingController _weightController;
  late TextEditingController _bfController;
  late TextEditingController _notesController;

  // Navy tape inputs
  bool _showNavyCalculator = false;
  late String _gender;
  late TextEditingController _heightController;
  late TextEditingController _neckController;
  late TextEditingController _waistController;
  late TextEditingController _hipController;
  double? _calculatedNavyBf;

  @override
  void initState() {
    super.initState();
    final storage = StorageService();
    final profile = storage.getProfile();
    final latest = storage.getLatestBodyMetric();

    _selectedDate = widget.initialMetric?.date ?? DateTime.now();

    final initialWeight = widget.initialMetric?.weightKg ??
        latest?.weightKg ??
        profile.bodyWeightKg ??
        70.0;
    _weightController =
        TextEditingController(text: initialWeight.toStringAsFixed(1));

    final initialBf = widget.initialMetric?.bodyFatPercentage ??
        latest?.bodyFatPercentage;
    _bfController = TextEditingController(
        text: initialBf != null ? initialBf.toStringAsFixed(1) : '');

    _notesController =
        TextEditingController(text: widget.initialMetric?.notes ?? '');

    _gender = profile.gender;
    _heightController = TextEditingController(
        text: profile.heightCm != null
            ? profile.heightCm!.toStringAsFixed(0)
            : '175');
    _neckController = TextEditingController(
        text: widget.initialMetric?.neckCm?.toStringAsFixed(1) ??
            latest?.neckCm?.toStringAsFixed(1) ??
            '38');
    _waistController = TextEditingController(
        text: widget.initialMetric?.waistCm?.toStringAsFixed(1) ??
            latest?.waistCm?.toStringAsFixed(1) ??
            '82');
    _hipController = TextEditingController(
        text: widget.initialMetric?.hipCm?.toStringAsFixed(1) ??
            latest?.hipCm?.toStringAsFixed(1) ??
            '95');

    _recomputeNavyBf();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _bfController.dispose();
    _notesController.dispose();
    _heightController.dispose();
    _neckController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    super.dispose();
  }

  void _recomputeNavyBf() {
    final h = double.tryParse(_heightController.text) ?? 0.0;
    final neck = double.tryParse(_neckController.text) ?? 0.0;
    final waist = double.tryParse(_waistController.text) ?? 0.0;
    final hip = double.tryParse(_hipController.text) ?? 0.0;

    double? res;
    if (_gender == 'Female') {
      res = BodyMetricLog.calculateNavyBodyFatWomen(
        heightCm: h,
        waistCm: waist,
        neckCm: neck,
        hipCm: hip,
      );
    } else {
      res = BodyMetricLog.calculateNavyBodyFatMen(
        heightCm: h,
        waistCm: waist,
        neckCm: neck,
      );
    }

    setState(() {
      _calculatedNavyBf = res;
    });
  }

  void _adjustWeight(double delta) {
    final current = double.tryParse(_weightController.text) ?? 70.0;
    final updated = (current + delta).clamp(20.0, 300.0);
    setState(() {
      _weightController.text = updated.toStringAsFixed(1);
    });
  }

  void _applyNavyBf() {
    if (_calculatedNavyBf != null) {
      setState(() {
        _bfController.text = _calculatedNavyBf!.toStringAsFixed(1);
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primary,
              surface: AppTheme.surfaceDark,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight')),
      );
      return;
    }

    final bf = double.tryParse(_bfController.text);
    final neck = double.tryParse(_neckController.text);
    final waist = double.tryParse(_waistController.text);
    final hip = double.tryParse(_hipController.text);
    final height = double.tryParse(_heightController.text);

    final storage = StorageService();

    // Update profile height and gender if changed
    final currentProfile = storage.getProfile();
    if ((height != null && height > 0 && height != currentProfile.heightCm) ||
        _gender != currentProfile.gender) {
      await storage.saveProfile(currentProfile.copyWith(
        heightCm: height,
        gender: _gender,
      ));
    }

    final metric = BodyMetricLog(
      id: widget.initialMetric?.id ?? _uuid.v4(),
      date: _selectedDate,
      weightKg: weight,
      bodyFatPercentage: (bf != null && bf > 0) ? bf : null,
      neckCm: neck,
      waistCm: waist,
      hipCm: _gender == 'Female' ? hip : null,
      notes: _notesController.text.trim(),
    );

    await storage.saveBodyMetric(metric);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final bf = double.tryParse(_bfController.text);
    final fatMass = (bf != null && bf > 0 && weight > 0)
        ? (weight * (bf / 100.0))
        : null;
    final leanMass = (fatMass != null) ? (weight - fatMass) : null;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.surfaceHighlight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceHighlight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.monitor_weight_outlined,
                    color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.initialMetric == null
                          ? 'Log Weight & Body Fat'
                          : 'Edit Weigh-In',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_month,
                    size: 20, color: AppTheme.primary),
                onPressed: _pickDate,
                tooltip: 'Change date',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Scrollable Body Inputs
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Weight Section
                  const Text(
                    'BODY WEIGHT (KG)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStepButton('-0.5', () => _adjustWeight(-0.5)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            suffixText: 'kg',
                            suffixStyle: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 16),
                            filled: true,
                            fillColor: AppTheme.surfaceLighter,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: AppTheme.surfaceHighlight),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: AppTheme.surfaceHighlight),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: AppTheme.primary),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStepButton('+0.5', () => _adjustWeight(0.5)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Body Fat % Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'BODY FAT % (OPTIONAL)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _showNavyCalculator = !_showNavyCalculator;
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                _showNavyCalculator
                                    ? Icons.expand_less
                                    : Icons.calculate_outlined,
                                size: 14,
                                color: AppTheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _showNavyCalculator
                                    ? 'Hide Calculator'
                                    : 'Navy Tape Calc',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bfController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. 16.5',
                      hintStyle: const TextStyle(color: AppTheme.textMuted),
                      suffixText: '%',
                      suffixStyle: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 16),
                      filled: true,
                      fillColor: AppTheme.surfaceLighter,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppTheme.surfaceHighlight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppTheme.surfaceHighlight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.secondary),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  // Expandable US Navy Tape Calculator
                  if (_showNavyCalculator) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLighter.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppTheme.secondary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.straighten,
                                  size: 16, color: AppTheme.secondary),
                              const SizedBox(width: 6),
                              const Text(
                                'US Navy Circumference Method',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondary,
                                ),
                              ),
                              const Spacer(),
                              // Gender Selector
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'Male',
                                    label: Text('M', style: TextStyle(fontSize: 11)),
                                  ),
                                  ButtonSegment(
                                    value: 'Female',
                                    label: Text('F', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                                selected: {_gender},
                                showSelectedIcon: false,
                                style: ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor:
                                      WidgetStateProperty.resolveWith((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return AppTheme.secondary
                                          .withValues(alpha: 0.25);
                                    }
                                    return AppTheme.surfaceDark;
                                  }),
                                ),
                                onSelectionChanged: (set) {
                                  setState(() {
                                    _gender = set.first;
                                    _recomputeNavyBf();
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMiniInput(
                                  'Height (cm)',
                                  _heightController,
                                  (val) => _recomputeNavyBf(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildMiniInput(
                                  'Neck (cm)',
                                  _neckController,
                                  (val) => _recomputeNavyBf(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMiniInput(
                                  'Waist (cm)',
                                  _waistController,
                                  (val) => _recomputeNavyBf(),
                                ),
                              ),
                              if (_gender == 'Female') ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildMiniInput(
                                    'Hips (cm)',
                                    _hipController,
                                    (val) => _recomputeNavyBf(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Result Row
                          Row(
                            children: [
                              const Icon(Icons.bolt,
                                  size: 16, color: AppTheme.accentAmber),
                              const SizedBox(width: 4),
                              Text(
                                _calculatedNavyBf != null
                                    ? 'Est. BF: ${_calculatedNavyBf!.toStringAsFixed(1)}%'
                                    : 'Fill in measurements',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              if (_calculatedNavyBf != null)
                                TextButton.icon(
                                  icon: const Icon(Icons.check, size: 14),
                                  label: const Text('Apply'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.primary,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                  ),
                                  onPressed: _applyNavyBf,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Lean vs Fat Mass breakdown card
                  if (leanMass != null && fatMass != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLighter,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text(
                                'LEAN MASS (LBM)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${leanMass.toStringAsFixed(1)} kg',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 24,
                            width: 1,
                            color: AppTheme.surfaceHighlight,
                          ),
                          Column(
                            children: [
                              const Text(
                                'FAT MASS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentRose,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${fatMass.toStringAsFixed(1)} kg',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Notes Section
                  const SizedBox(height: 14),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Optional notes (e.g. morning, fasted, post-leg day)...',
                      hintStyle: const TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.surfaceLighter,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppTheme.surfaceHighlight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppTheme.surfaceHighlight),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.surfaceHighlight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text(
                    'Save Weigh-In',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLighter,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.surfaceHighlight),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniInput(
    String label,
    TextEditingController controller,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppTheme.surfaceDark,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.surfaceHighlight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.surfaceHighlight),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
