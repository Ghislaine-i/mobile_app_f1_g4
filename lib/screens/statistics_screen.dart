import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../services/deadline_status.dart';
import '../theme.dart';
import '../widgets/ui_helpers.dart';
import 'task_details_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<Task> _tasks = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tasks = await DatabaseService.instance.getTasks();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _open(Task task) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: task.id!)),
    );
    if (!mounted) return;
    showSnack(context, message);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task statistics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? ErrorState(onRetry: _load)
          : RefreshIndicator(onRefresh: _load, child: _content()),
    );
  }

  Widget _content() {
    final now = DateTime.now();
    final counts = countTasksByDeadlineStatus(_tasks, now);
    final maxCount = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    // Upcoming = not completed and the deadline is still ahead.
    final upcoming =
        _tasks.where((t) => !t.isCompleted && t.dueAt.isAfter(now)).toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Tasks by deadline status'),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      maxY: (maxCount + 1).toDouble(),
                      alignment: BarChartAlignment.spaceAround,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        topTitles: const AxisTitles(),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) => SideTitleWidget(
                              meta: meta,
                              child: Text(
                                DeadlineStatus.values[value.toInt()].label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        enabled: false,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => Colors.transparent,
                          tooltipPadding: EdgeInsets.zero,
                          tooltipMargin: 2,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                              BarTooltipItem(
                                '${rod.toY.toInt()}',
                                const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                        ),
                      ),
                      barGroups: [
                        for (final deadlineStatus in DeadlineStatus.values)
                          BarChartGroupData(
                            x: deadlineStatus.index,
                            showingTooltipIndicators: const [0],
                            barRods: [
                              BarChartRodData(
                                toY: counts[deadlineStatus]!.toDouble(),
                                color: AppColors.deadlineStatus(deadlineStatus),
                                width: 34,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Upcoming deadlines'),
                const SizedBox(height: 8),
                if (upcoming.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No upcoming deadlines.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                for (final task in upcoming)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.event_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(dueDateLabel(task)),
                    trailing: DeadlineStatusBadge(
                      calculateDeadlineStatus(task, now).deadlineStatus,
                    ),
                    onTap: () => _open(task),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
