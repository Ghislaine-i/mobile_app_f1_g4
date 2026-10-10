import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/deadline_status.dart';
import '../theme.dart';
import '../widgets/ui_helpers.dart';
import 'home_shell.dart';
import 'statistics_screen.dart';
import 'task_details_screen.dart';
import 'task_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onTab});
  final TabSelect onTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Task> _tasks = [];
  Map<int, TeamMember> _members = {};
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = DatabaseService.instance;
      final tasks = await db.getTasks();
      final members = await db.getMembers();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _members = {for (final m in members) m.id!: m};
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

  Future<void> _create() async {
    final message = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const TaskFormScreen()));
    if (!mounted) return;
    showSnack(context, message);
    _load();
  }

  Future<void> _openTask(Task task) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: task.id!)),
    );
    if (mounted) _load();
  }

  Future<void> _openStatistics() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const StatisticsScreen()));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final name = AuthService.instance.currentMember?.firstName ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      drawer: AppDrawer(onTab: widget.onTab),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        tooltip: 'Create task',
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? ErrorState(onRetry: _load)
          : RefreshIndicator(onRefresh: _load, child: _content(name)),
    );
  }

  Widget _content(String name) {
    final now = DateTime.now();
    final counts = countTasksByDeadlineStatus(_tasks, now);
    final total = _tasks.length;
    final completed = counts[DeadlineStatus.completed]!;
    final progress = total == 0 ? 0.0 : completed / total;
    final recent = [..._tasks]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        Text(
          '${greeting()}, $name',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Here's what is happening with your project.",
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        _ProgressCard(total: total, completed: completed, progress: progress),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2,
          children: [
            for (final deadlineStatus in DeadlineStatus.values)
              _CountCard(
                deadlineStatus: deadlineStatus,
                count: counts[deadlineStatus]!,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _openStatistics,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SectionTitle('Task overview'),
                      Text(
                        'Statistics',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Donut(counts: counts, total: total),
                ],
              ),
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
                const SectionTitle('Recent task updates'),
                const SizedBox(height: 8),
                if (recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No tasks yet. Tap + to create one.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                for (final task in recent.take(4))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: MemberAvatar(_members[task.assigneeId]),
                    title: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('Updated ${timeAgo(task.updatedAt)}'),
                    onTap: () => _openTask(task),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.total,
    required this.completed,
    required this.progress,
  });
  final int total;
  final int completed;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$total ${total == 1 ? 'task' : 'tasks'} in total',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completed completed',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.deadlineStatus, required this.count});
  final DeadlineStatus deadlineStatus;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.deadlineStatus(deadlineStatus);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.deadlineStatusSoft(deadlineStatus),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            deadlineStatus.label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Donut extends StatelessWidget {
  const _Donut({required this.counts, required this.total});
  final Map<DeadlineStatus, int> counts;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  centerSpaceRadius: 42,
                  sectionsSpace: total == 0 ? 0 : 2,
                  sections: total == 0
                      ? [
                          PieChartSectionData(
                            value: 1,
                            color: AppColors.border,
                            radius: 16,
                            showTitle: false,
                          ),
                        ]
                      : [
                          for (final deadlineStatus in DeadlineStatus.values)
                            if (counts[deadlineStatus]! > 0)
                              PieChartSectionData(
                                value: counts[deadlineStatus]!.toDouble(),
                                color: AppColors.deadlineStatus(deadlineStatus),
                                radius: 16,
                                showTitle: false,
                              ),
                        ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$total',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'Tasks',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            children: [
              for (final deadlineStatus in DeadlineStatus.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.deadlineStatus(deadlineStatus),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(deadlineStatus.label)),
                      Text(
                        '${counts[deadlineStatus]}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
