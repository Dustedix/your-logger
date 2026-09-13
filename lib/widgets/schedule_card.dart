import 'package:flutter/material.dart';
import '../models/workout_schedule.dart';
import '../theme/app_theme.dart';

class ScheduleCard extends StatelessWidget {
  final WorkoutSchedule schedule;
  final int completedLogsCount;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.completedLogsCount,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = Color(
        int.tryParse(schedule.colorHex.replaceFirst('#', '0xFF')) ??
            0xFF10B981);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.surfaceHighlight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Tag, Scheduled Days & Menu
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        schedule.scheduledDays.isNotEmpty
                            ? schedule.scheduledDays
                                .map((d) => d.substring(0, 3))
                                .join(', ')
                            : 'Flexible Routine',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: schedule.scheduledDays.isNotEmpty
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: schedule.scheduledDays.isNotEmpty
                              ? accentColor
                              : AppTheme.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLighter,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$completedLogsCount logged',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          size: 18, color: AppTheme.textMuted),
                      padding: EdgeInsets.zero,
                      color: AppTheme.surfaceLighter,
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined,
                                  size: 16, color: AppTheme.textPrimary),
                              SizedBox(width: 8),
                              Text('Edit Schedule'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 16, color: AppTheme.accentRose),
                              SizedBox(width: 8),
                              Text('Delete Schedule',
                                  style:
                                      TextStyle(color: AppTheme.accentRose)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (val) {
                        if (val == 'edit') onEdit();
                        if (val == 'delete') onDelete();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Title
                Text(
                  schedule.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (schedule.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    schedule.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 14),
                // Exercise List Preview chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: schedule.exercises.take(4).map((ex) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLighter,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppTheme.surfaceHighlight.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '${ex.name} (${ex.defaultSets}×${ex.isTimeBased ? '${ex.defaultTimeSeconds}s' : '${ex.defaultReps}'})',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    );
                  }).toList()
                    ..addAll(
                      schedule.exercises.length > 4
                          ? [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLighter,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '+${schedule.exercises.length - 4} more',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ]
                          : [],
                    ),
                ),
                const SizedBox(height: 16),
                // Bottom Action Button: Log Now
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: accentColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_task, size: 18, color: accentColor),
                      const SizedBox(width: 8),
                      Text(
                        'Click to Log Session (Date, Sets & Reps)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
