import 'package:flutter/material.dart';
import '../models/workout_log.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/history_card.dart';

class HistoryTab extends StatefulWidget {
  final VoidCallback onDataChanged;

  const HistoryTab({super.key, required this.onDataChanged});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final StorageService _storage = StorageService();
  String _selectedFilterScheduleId = 'ALL';

  void _confirmDeleteLog(WorkoutLog log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session Log?'),
        content: Text(
            'Are you sure you want to delete the log for "${log.scheduleTitle}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRose,
            ),
            onPressed: () async {
              await _storage.deleteLog(log.id);
              widget.onDataChanged();
              setState(() {});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedules = _storage.getSchedules();
    final allLogs = _storage.getLogs();

    final filteredLogs = _selectedFilterScheduleId == 'ALL'
        ? allLogs
        : allLogs.where((l) => l.scheduleId == _selectedFilterScheduleId).toList();

    final totalVolume =
        allLogs.fold(0.0, (sum, log) => sum + log.totalVolumeKg);
    final totalSets =
        allLogs.fold(0, (sum, log) => sum + log.totalCompletedSets);
    final totalReps =
        allLogs.fold(0, (sum, log) => sum + log.totalCompletedReps);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Workout Logbook'),
            Text(
              'History of completed sessions, dates & reps',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Aggregate Stats Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceHighlight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem('${allLogs.length}', 'Sessions',
                      Icons.check_circle, AppTheme.primary),
                ),
                Container(width: 1, height: 32, color: AppTheme.surfaceHighlight),
                Expanded(
                  child: _buildStatItem(
                      '$totalSets', 'Sets', Icons.layers, AppTheme.secondary),
                ),
                Container(width: 1, height: 32, color: AppTheme.surfaceHighlight),
                Expanded(
                  child: _buildStatItem('$totalReps', 'Reps', Icons.repeat,
                      AppTheme.accentAmber),
                ),
                if (totalVolume > 0) ...[
                  Container(
                      width: 1, height: 32, color: AppTheme.surfaceHighlight),
                  Expanded(
                    child: _buildStatItem(
                        '${(totalVolume / 1000).toStringAsFixed(1)}t',
                        'Volume',
                        Icons.fitness_center,
                        AppTheme.primaryLight),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Schedule Filter Chips
          if (schedules.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Sessions'),
                    selected: _selectedFilterScheduleId == 'ALL',
                    selectedColor: AppTheme.primary.withValues(alpha: 0.25),
                    labelStyle: TextStyle(
                      color: _selectedFilterScheduleId == 'ALL'
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                      fontWeight: _selectedFilterScheduleId == 'ALL'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    backgroundColor: AppTheme.surfaceDark,
                    side: BorderSide(
                      color: _selectedFilterScheduleId == 'ALL'
                          ? AppTheme.primary
                          : AppTheme.surfaceHighlight,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilterScheduleId = 'ALL');
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ...schedules.map((s) {
                    final isSel = _selectedFilterScheduleId == s.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s.title),
                        selected: isSel,
                        selectedColor: AppTheme.primary.withValues(alpha: 0.25),
                        labelStyle: TextStyle(
                          color: isSel
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                          fontWeight:
                              isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: AppTheme.surfaceDark,
                        side: BorderSide(
                          color: isSel
                              ? AppTheme.primary
                              : AppTheme.surfaceHighlight,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedFilterScheduleId = s.id);
                          }
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // List of History Cards
          if (filteredLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.surfaceHighlight),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: AppTheme.textMuted),
                    SizedBox(height: 12),
                    Text(
                      'No Workout Logs Yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tap any routine in the Schedules tab to log your sets & reps.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filteredLogs.map(
              (log) => HistoryCard(
                log: log,
                onDelete: () => _confirmDeleteLog(log),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String val, String label, IconData icon, Color color) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                val,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}
