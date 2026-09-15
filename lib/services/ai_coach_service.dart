import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/workout_log.dart';
import '../models/workout_schedule.dart';
import '../models/user_profile.dart';

class AiCoachService {
  static const String _geminiModel = 'gemini-3.6-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent';

  /// Generates a comprehensive AI Workout Analysis using Gemini
  static Future<String> generateWorkoutAnalysis({
    required List<WorkoutLog> logs,
    required List<WorkoutSchedule> schedules,
    required UserProfile profile,
  }) async {
    final apiKey = profile.geminiApiKey.trim();
    if (apiKey.isEmpty) {
      throw Exception(
        'Gemini API key is not set. Please tap the Settings icon to enter your Google Gemini API key.',
      );
    }

    final prompt = _buildAnalysisPrompt(logs, schedules, profile);
    return _callGeminiApi(apiKey: apiKey, prompt: prompt);
  }

  /// Sends a direct fitness question to the AI Coach
  static Future<String> askCoach({
    required String question,
    required List<WorkoutLog> logs,
    required List<WorkoutSchedule> schedules,
    required UserProfile profile,
    List<Map<String, String>> chatHistory = const [],
  }) async {
    final apiKey = profile.geminiApiKey.trim();
    if (apiKey.isEmpty) {
      throw Exception(
        'Gemini API key is not set. Please tap the Settings icon to enter your Google Gemini API key.',
      );
    }

    final contextPrompt = _buildContextPrompt(logs, schedules, profile);
    final fullPrompt = '''
You are "Your Log AI Coach" — an elite, supportive, scientific strength and conditioning coach and biomechanics specialist.
Always format your answers in clear, modern Markdown with bold key takeaways, bullet points, and concise actionable steps.

User Profile:
- Goal: ${profile.trainingGoal}
- Experience: ${profile.experienceLevel}
${profile.bodyWeightKg != null ? "- Bodyweight: ${profile.bodyWeightKg} kg" : ""}
${profile.age != null ? "- Age: ${profile.age}" : ""}

User's Training Context:
$contextPrompt

User Question:
$question
''';

    return _callGeminiApi(apiKey: apiKey, prompt: fullPrompt);
  }

  static String _buildAnalysisPrompt(
    List<WorkoutLog> logs,
    List<WorkoutSchedule> schedules,
    UserProfile profile,
  ) {
    final contextPrompt = _buildContextPrompt(logs, schedules, profile);

    return '''
You are "Your Log AI Coach", a certified elite strength coach, hypertrophy specialist, and biomechanics expert.
Perform a comprehensive, motivating, and highly analytical review of the user's workout logs and training progress.

User Profile:
- Primary Goal: ${profile.trainingGoal}
- Experience Level: ${profile.experienceLevel}
${profile.bodyWeightKg != null ? "- Bodyweight: ${profile.bodyWeightKg} kg" : ""}
${profile.age != null ? "- Age: ${profile.age}" : ""}

User's Logged History:
$contextPrompt

Please structure your review strictly using these 4 clear markdown sections:

### 1. 📈 Progressive Overload & Volume Analysis
- Highlight whether weights, reps, and overall tonnage are increasing across recent sessions.
- Mention specific exercises where progression is strong, or where plateaus might be forming.

### 2. ⚖️ Muscle Split & Training Balance
- Evaluate frequency and volume balance between muscle groups (e.g., Push vs. Pull vs. Legs/Core).
- Mention plank or core endurance trends if timed exercises were logged.

### 3. 🛡️ Recovery, Fatigue & Form Pointers
- Analyze session density, workout frequency, and recovery windows between hard sessions.
- Provide 1 key biomechanical form cue for their staple compound lifts.

### 4. 🎯 Actionable Targets for Next Week
- Give 2 to 3 specific, measurable goals for upcoming sessions (e.g. "+2.5kg on Bench Press for 8 reps", "Aim for 75s plank without hip sagging", or extra set volume).

Tone: Energetic, encouraging, scientific, direct, and concise. Use bold text for key metrics.
''';
  }

  static String _buildContextPrompt(
    List<WorkoutLog> logs,
    List<WorkoutSchedule> schedules,
    UserProfile profile,
  ) {
    if (logs.isEmpty) {
      return 'The user has not logged any completed workout sessions yet. They have ${schedules.length} routines created: ${schedules.map((s) => s.title).join(", ")}.';
    }

    final dateFormat = DateFormat('MMM d, yyyy');
    final recentLogs = logs.take(10).toList();

    final buffer = StringBuffer();
    buffer.writeln('Total Completed Sessions Recorded: ${logs.length}');
    buffer.writeln('Recent Sessions Summary (Most recent first):');

    for (int i = 0; i < recentLogs.length; i++) {
      final log = recentLogs[i];
      buffer.writeln(
        '- Date: ${dateFormat.format(log.completedDate)} | Routine: "${log.scheduleTitle}" | Duration: ${log.durationMinutes} min | Volume: ${log.totalVolumeKg.toStringAsFixed(1)} kg | Sets: ${log.totalCompletedSets} | Reps: ${log.totalCompletedReps}',
      );
      for (final ex in log.exerciseLogs) {
        final setsSummary = ex.sets.map((s) {
          if (s.timeSeconds != null && s.timeSeconds! > 0) {
            return '${s.timeSeconds}s${s.weightKg > 0 ? " (+${s.weightKg}kg)" : ""}';
          }
          return '${s.reps}x${s.weightKg}kg';
        }).join(', ');
        buffer.writeln('    * ${ex.exerciseName} (${ex.targetMuscle}): $setsSummary');
      }
      if (log.overallNotes != null && log.overallNotes!.isNotEmpty) {
        buffer.writeln('    * Notes: "${log.overallNotes}"');
      }
    }

    return buffer.toString();
  }

  static Future<String> _callGeminiApi({
    required String apiKey,
    required String prompt,
  }) async {
    final uri = Uri.parse('$_baseUrl?key=$apiKey');

    final payload = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1500,
      }
    };

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final first = candidates[0] as Map<String, dynamic>;
          final content = first['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text'] as String?;
            if (text != null && text.isNotEmpty) {
              return text;
            }
          }
        }
        return 'Received an empty response from Gemini. Please try again.';
      } else {
        final errorBody = response.body;
        debugPrint('Gemini API Error: ${response.statusCode} - $errorBody');
        if (response.statusCode == 400) {
          throw Exception(
            'Invalid API key or request. Please check your Gemini API key in Settings.',
          );
        } else if (response.statusCode == 403) {
          throw Exception(
            'Access denied. Please ensure your Gemini API key has Generative Language API enabled in Google AI Studio.',
          );
        } else if (response.statusCode == 429) {
          throw Exception(
            'Gemini API rate limit reached. Please wait a moment before trying again.',
          );
        }
        throw Exception(
          'Gemini API returned code ${response.statusCode}. Please try again later.',
        );
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error connecting to Gemini: $e');
    }
  }
}
