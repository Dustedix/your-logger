import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../services/ai_coach_service.dart';
import '../theme/app_theme.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  late TabController _tabController;

  bool _isAnalyzing = false;
  String? _analysisError;

  // Chat Tab state
  final TextEditingController _chatInputCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();
  final List<Map<String, String>> _messages = [
    {
      'sender': 'coach',
      'text':
          'Hey! I\'m your personal AI Strength Coach. Ask me anything about your workout volume, progressive overload, plateau breakthroughs, or exercise technique!'
    }
  ];
  bool _isChatLoading = false;

  // Analysis focus controller (customizable directly on analysis card)
  late final TextEditingController _analysisFocusCtrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final profile = _storage.getProfile();
    _analysisFocusCtrl = TextEditingController(text: profile.trainingGoal);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatInputCtrl.dispose();
    _chatScrollCtrl.dispose();
    _analysisFocusCtrl.dispose();
    super.dispose();
  }

  void _showSettingsDialog() {
    final profile = _storage.getProfile();
    final keyCtrl = TextEditingController(text: profile.geminiApiKey);
    final weightCtrl = TextEditingController(
      text: profile.bodyWeightKg != null
          ? profile.bodyWeightKg.toString()
          : '',
    );
    final ageCtrl = TextEditingController(
      text: profile.age != null ? profile.age.toString() : '',
    );

    final goalCtrl = TextEditingController(text: profile.trainingGoal);
    String selectedExp = profile.experienceLevel;
    bool obscureKey = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome,
                                color: AppTheme.primary, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Coach Profile & Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.textMuted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Google Gemini API Key',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: keyCtrl,
                      obscureText: obscureKey,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Paste your Gemini API key (AIzaSy...)',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureKey ? Icons.visibility : Icons.visibility_off,
                            color: AppTheme.textMuted,
                            size: 20,
                          ),
                          onPressed: () {
                            setModalState(() => obscureKey = !obscureKey);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Free key available at https://aistudio.google.com/app/apikey',
                      style: TextStyle(fontSize: 11, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Bodyweight (kg)',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: weightCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  hintText: 'e.g. 74',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Age',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: ageCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. 26',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Primary Training Focus',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                        const Text('Tap preset or type custom',
                            style: TextStyle(fontSize: 10, color: AppTheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: goalCtrl,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. Hypertrophy, Strength, Core & Posture...',
                        prefixIcon: const Icon(Icons.track_changes, size: 18, color: AppTheme.primary),
                        suffixIcon: goalCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                                onPressed: () => setModalState(() => goalCtrl.clear()),
                              )
                            : null,
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          'Hypertrophy & Muscle Building',
                          'Strength & Progressive Overload',
                          'Fat Loss & Conditioning',
                          'Core, Endurance & Posture',
                          'Calisthenics & Bodyweight',
                        ].map((preset) {
                          final isSel = goalCtrl.text.trim().toLowerCase() == preset.toLowerCase();
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () => setModalState(() => goalCtrl.text = preset),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSel ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.surfaceLighter,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSel ? AppTheme.primary : AppTheme.surfaceHighlight,
                                  ),
                                ),
                                child: Text(
                                  preset,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    color: isSel ? AppTheme.primary : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Experience Level',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedExp,
                      dropdownColor: AppTheme.surfaceDark,
                      items: const [
                        DropdownMenuItem(
                            value: 'Beginner (< 1 year)',
                            child: Text('Beginner (< 1 year)')),
                        DropdownMenuItem(
                            value: 'Intermediate (1 - 3 years)',
                            child: Text('Intermediate (1 - 3 years)')),
                        DropdownMenuItem(
                            value: 'Advanced (3+ years)',
                            child: Text('Advanced (3+ years)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedExp = val);
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppTheme.primary,
                        ),
                        icon: const Icon(Icons.check, color: AppTheme.bgDark),
                        label: const Text(
                          'Save Profile',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.bgDark,
                          ),
                        ),
                        onPressed: () async {
                          final weight = double.tryParse(weightCtrl.text.trim());
                          final age = int.tryParse(ageCtrl.text.trim());
                          final customGoal = goalCtrl.text.trim().isEmpty
                              ? 'Hypertrophy & Muscle Building'
                              : goalCtrl.text.trim();
                          final updated = profile.copyWith(
                            geminiApiKey: keyCtrl.text.trim(),
                            bodyWeightKg: weight,
                            age: age,
                            trainingGoal: customGoal,
                            experienceLevel: selectedExp,
                          );
                          await _storage.saveProfile(updated);
                          _analysisFocusCtrl.text = customGoal;
                          if (ctx.mounted) Navigator.pop(ctx);
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _runAnalysis() async {
    final profile = _storage.getProfile();
    if (profile.geminiApiKey.trim().isEmpty) {
      _showSettingsDialog();
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
    });

    try {
      final logs = _storage.getLogs();
      final schedules = _storage.getSchedules();
      final customFocus = _analysisFocusCtrl.text.trim();

      final result = await AiCoachService.generateWorkoutAnalysis(
        logs: logs,
        schedules: schedules,
        profile: profile,
        customFocus: customFocus.isNotEmpty ? customFocus : null,
      );

      final updated = profile.copyWith(
        trainingGoal: customFocus.isNotEmpty ? customFocus : profile.trainingGoal,
        lastAiAnalysis: result,
        lastAiAnalysisDate: DateTime.now(),
      );
      await _storage.saveProfile(updated);
    } catch (e) {
      setState(() {
        _analysisError = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = presetText ?? _chatInputCtrl.text.trim();
    if (text.isEmpty) return;

    final profile = _storage.getProfile();
    if (profile.geminiApiKey.trim().isEmpty) {
      _showSettingsDialog();
      return;
    }

    if (presetText == null) {
      _chatInputCtrl.clear();
    }

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isChatLoading = true;
    });

    _scrollToBottom();

    try {
      final logs = _storage.getLogs();
      final schedules = _storage.getSchedules();

      final response = await AiCoachService.askCoach(
        question: text,
        logs: logs,
        schedules: schedules,
        profile: profile,
        chatHistory: _messages,
      );

      setState(() {
        _messages.add({'sender': 'coach', 'text': response});
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'sender': 'coach',
          'text':
              '⚠️ Error: ${e.toString().replaceAll("Exception: ", "")}\nTap the settings gear icon to verify your Gemini API key.'
        });
      });
    } finally {
      if (mounted) {
        setState(() {
          _isChatLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = _storage.getProfile();
    final hasApiKey = profile.geminiApiKey.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppTheme.primary, size: 22),
            SizedBox(width: 8),
            Text('Assistant Analytics & Coach'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Profile & API Key',
            icon: Stack(
              children: [
                const Icon(Icons.settings, color: AppTheme.textSecondary),
                if (!hasApiKey)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentRose,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showSettingsDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Workout Insights'),
            Tab(icon: Icon(Icons.chat_outlined), text: 'Ask Coach'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInsightsTab(profile, hasApiKey),
          _buildChatTab(hasApiKey),
        ],
      ),
    );
  }

  Widget _buildInsightsTab(UserProfile profile, bool hasApiKey) {
    final lastDate = profile.lastAiAnalysisDate;
    final formattedDate = lastDate != null
        ? DateFormat('MMM d, h:mm a').format(lastDate)
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero Coach Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primary.withValues(alpha: 0.22),
                AppTheme.secondary.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.psychology, color: AppTheme.primary, size: 26),
                      SizedBox(width: 8),
                      Text(
                        'Gemini AI Analytics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _showSettingsDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tune, size: 12, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            profile.trainingGoal.isNotEmpty
                                ? (profile.trainingGoal.contains('&')
                                    ? profile.trainingGoal.split('&').first.trim()
                                    : (profile.trainingGoal.length > 20
                                        ? '${profile.trainingGoal.substring(0, 18)}...'
                                        : profile.trainingGoal))
                                : 'Custom Focus',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Personalized progressive overload feedback, recovery analysis, and concrete targets based on your real workout logs.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),

              // Custom Primary Focus Input
              Row(
                children: [
                  const Icon(Icons.track_changes, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  const Text(
                    'Primary Focus for this Analysis',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (_analysisFocusCtrl.text.trim() != profile.trainingGoal.trim())
                    InkWell(
                      onTap: () => setState(() => _analysisFocusCtrl.text = profile.trainingGoal),
                      child: const Text(
                        'Reset to Default',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _analysisFocusCtrl,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Type your focus (e.g. Chest Hypertrophy, Squat PR, HIIT)...',
                  prefixIcon: const Icon(Icons.edit_note, size: 18, color: AppTheme.primary),
                  suffixIcon: _analysisFocusCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                          onPressed: () => setState(() => _analysisFocusCtrl.clear()),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              // Preset chips for quick 1-tap focus switching
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'Hypertrophy & Muscle Building',
                    'Strength & Progressive Overload',
                    'Fat Loss & Conditioning',
                    'Core, Endurance & Posture',
                    'Plateau Breakthrough',
                    'Calisthenics & Bodyweight',
                  ].map((preset) {
                    final isSel = _analysisFocusCtrl.text.trim().toLowerCase() == preset.toLowerCase();
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => setState(() => _analysisFocusCtrl.text = preset),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSel ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.surfaceLighter,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSel ? AppTheme.primary : AppTheme.surfaceHighlight,
                            ),
                          ),
                          child: Text(
                            preset,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              color: isSel ? AppTheme.primary : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isAnalyzing ? null : _runAnalysis,
                      icon: _isAnalyzing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.bgDark,
                              ),
                            )
                          : const Icon(Icons.auto_awesome,
                              color: AppTheme.bgDark, size: 18),
                      label: Text(
                        _isAnalyzing
                            ? 'Analyzing Logs...'
                            : (profile.lastAiAnalysis != null
                                ? 'Refresh Analysis ✨'
                                : 'Generate Analysis ✨'),
                        style: const TextStyle(
                          color: AppTheme.bgDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (!hasApiKey) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Set API Key',
                      icon: const Icon(Icons.key, color: AppTheme.secondary),
                      onPressed: _showSettingsDialog,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        if (_analysisError != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentRose.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accentRose),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppTheme.accentRose),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _analysisError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.accentRose,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),

        if (profile.lastAiAnalysis != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Coach Breakdown',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (formattedDate != null)
                Text(
                  'Updated: $formattedDate',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceHighlight),
            ),
            child: SelectableText(
              profile.lastAiAnalysis!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.55,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ] else if (!_isAnalyzing) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.bolt,
                      size: 56,
                      color: AppTheme.textMuted.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  const Text(
                    'No AI Review Generated Yet',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap "Generate Analysis" above to evaluate your progressive overload and workout history!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChatTab(bool hasApiKey) {
    const presetQuestions = [
      'Critique my push vs. pull balance',
      'How do I increase my bench press?',
      'Tips for longer plank hold times',
      'Should I add more sets or weight?',
    ];

    return Column(
      children: [
        // Preset question chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: presetQuestions.map((q) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  backgroundColor: AppTheme.surfaceDark,
                  side: const BorderSide(color: AppTheme.surfaceHighlight),
                  label: Text(q, style: const TextStyle(fontSize: 11)),
                  onPressed: _isChatLoading ? null : () => _sendMessage(q),
                ),
              );
            }).toList(),
          ),
        ),

        // Message Thread
        Expanded(
          child: ListView.builder(
            controller: _chatScrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, idx) {
              final msg = _messages[idx];
              final isCoach = msg['sender'] == 'coach';

              return Align(
                alignment:
                    isCoach ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.82,
                  ),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isCoach
                        ? AppTheme.surfaceDark
                        : AppTheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomLeft: isCoach
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                      bottomRight: !isCoach
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                    border: Border.all(
                      color: isCoach
                          ? AppTheme.surfaceHighlight
                          : AppTheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isCoach) ...[
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 14, color: AppTheme.primary),
                            SizedBox(width: 6),
                            Text(
                              'Coach Gemini',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      SelectableText(
                        msg['text'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        if (_isChatLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Coach is analyzing your workouts...',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),

        // Input bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceDark,
            border: Border(
              top: BorderSide(color: AppTheme.surfaceHighlight),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatInputCtrl,
                  style: const TextStyle(fontSize: 13),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Ask about form, sets, progressive overload...',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.bgDark,
                ),
                icon: const Icon(Icons.send, size: 20),
                onPressed: _isChatLoading ? null : () => _sendMessage(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
