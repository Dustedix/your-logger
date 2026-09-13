import 'package:flutter/material.dart';
import '../models/workout_schedule.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/schedule_card.dart';
import 'log_session_screen.dart';
import 'schedule_editor_screen.dart';

class SchedulesTab extends StatefulWidget {
  final VoidCallback onDataChanged;

  const SchedulesTab({super.key, required this.onDataChanged});

  @override
  State<SchedulesTab> createState() => _SchedulesTabState();
}

class _SchedulesTabState extends State<SchedulesTab> {
  final StorageService _storage = StorageService();

  void _openLogSession(WorkoutSchedule schedule) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LogSessionScreen(schedule: schedule),
      ),
    );

    if (result == true) {
      widget.onDataChanged();
      setState(() {});
    }
  }

  void _openScheduleEditor([WorkoutSchedule? schedule]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleEditorScreen(scheduleToEdit: schedule),
      ),
    );

    if (result == true) {
      widget.onDataChanged();
      setState(() {});
    }
  }

  void _confirmDelete(WorkoutSchedule schedule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Schedule?'),
        content: Text('Are you sure you want to delete "${schedule.title}"?'),
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
              await _storage.deleteSchedule(schedule.id);
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

  void _showCloudSyncDialog() {
    bool isSyncing = false;
    String? statusMessage;
    bool isError = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.cloud_done, color: AppTheme.secondary),
                SizedBox(width: 8),
                Text('Firebase Cloud Sync', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connected Project: workout-tracker-171d1',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 12),
                Text(
                  'Local Routines: ${_storage.getSchedules().length}\n'
                  'Recorded Sessions: ${_storage.getLogs().length}',
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),
                if (statusMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isError
                          ? AppTheme.accentRose.withValues(alpha: 0.15)
                          : AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isError ? AppTheme.accentRose : AppTheme.primary,
                      ),
                    ),
                    child: Text(
                      statusMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isError ? AppTheme.accentRose : AppTheme.primary,
                      ),
                    ),
                  ),
                if (isSyncing)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(color: AppTheme.secondary),
                    ),
                  )
                else
                  const Text(
                    'Tap "Sync Now" to push local workouts to Firestore and pull any updates from your phone.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSyncing ? null : () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: isSyncing
                    ? null
                    : () async {
                        setModalState(() {
                          isSyncing = true;
                          statusMessage = null;
                        });
                        final result = await _storage.pushAllToCloud();
                        if (result.success) {
                          await _storage.syncFromCloud();
                          widget.onDataChanged();
                          setState(() {});
                          setModalState(() {
                            isSyncing = false;
                            isError = false;
                            statusMessage =
                                'Successfully synced ${result.count} items to Firestore!';
                          });
                        } else {
                          setModalState(() {
                            isSyncing = false;
                            isError = true;
                            statusMessage = 'Sync failed:\n${result.error}';
                          });
                        }
                      },
                icon: const Icon(Icons.sync, color: Colors.black, size: 18),
                label: const Text('Sync Now', style: TextStyle(color: Colors.black)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedules = _storage.getSchedules();
    final allLogs = _storage.getLogs();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Workout Schedules'),
            Text(
              'Select a routine to record completed sets & reps',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Firebase Cloud Sync',
            icon: const Icon(Icons.cloud_sync, color: AppTheme.secondary, size: 24),
            onPressed: () => _showCloudSyncDialog(),
          ),
          IconButton(
            tooltip: 'Add Schedule',
            icon: const Icon(Icons.add_circle, color: AppTheme.primary, size: 28),
            onPressed: () => _openScheduleEditor(),
          ),
        ],
      ),
      body: schedules.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fitness_center,
                      size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'No Workout Schedules Found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your first routine to start tracking your workouts!',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _openScheduleEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Schedule'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => setState(() {}),
              color: AppTheme.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Quick Summary Banner
                  _buildStatsBanner(schedules.length, allLogs.length),
                  const SizedBox(height: 12),
                  // Prominent Cloud Sync Bar
                  InkWell(
                    onTap: () => _showCloudSyncDialog(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.secondary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_sync,
                              size: 22, color: AppTheme.secondary),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Firebase Cloud Sync',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Project: workout-tracker-171d1 • Tap to sync now',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.secondary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sync, size: 14, color: Colors.black),
                                SizedBox(width: 4),
                                Text(
                                  'Sync',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text(
                        'Your Routines (Tap to Log)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...schedules.map((sched) {
                    final logsCount = _storage.getLogsForSchedule(sched.id).length;
                    return ScheduleCard(
                      schedule: sched,
                      completedLogsCount: logsCount,
                      onTap: () => _openLogSession(sched),
                      onEdit: () => _openScheduleEditor(sched),
                      onDelete: () => _confirmDelete(sched),
                    );
                  }),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('New Schedule',
            style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _openScheduleEditor(),
      ),
    );
  }

  Widget _buildStatsBanner(int totalSchedules, int totalLogs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.surfaceDark,
            AppTheme.surfaceLighter.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceHighlight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBannerStat(
            '$totalSchedules',
            'Routines',
            Icons.dashboard_customize,
            AppTheme.secondary,
          ),
          Container(width: 1, height: 36, color: AppTheme.surfaceHighlight),
          _buildBannerStat(
            '$totalLogs',
            'Workouts Done',
            Icons.verified,
            AppTheme.primary,
          ),
          Container(width: 1, height: 36, color: AppTheme.surfaceHighlight),
          _buildBannerStat(
            totalLogs > 0 ? 'Active' : 'Get Started',
            'Status',
            Icons.local_fire_department,
            AppTheme.accentAmber,
          ),
        ],
      ),
    );
  }

  Widget _buildBannerStat(
      String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
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
