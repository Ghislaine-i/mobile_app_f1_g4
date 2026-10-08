import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../services/deadline_status.dart';
import '../theme.dart';
import '../widgets/ui_helpers.dart';
import 'home_shell.dart';
import 'task_details_screen.dart';
import 'task_form_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key, required this.onTab});
  final TabSelect onTab;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];
  Map<int, TeamMember> _members = {};
  bool _loading = true;
  bool _failed = false;
  String _query = '';
  DeadlineStatus? _filter; // null means All

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

  Future<void> _edit(Task task) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)),
    );
    if (!mounted) return;
    showSnack(context, message);
    _load();
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
      appBar: AppBar(title: const Text('Tasks')),
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
          : _content(),
    );
  }

  Widget _content() {
    final now = DateTime.now();
    final query = _query.trim().toLowerCase();
    final visible = _tasks.where((t) {
      if (query.isNotEmpty && !t.title.toLowerCase().contains(query)) {
        return false;
      }
      return _filter == null ||
          calculateDeadlineStatus(t, now).deadlineStatus == _filter;
    }).toList()..sort((a, b) => a.dueAt.compareTo(b.dueAt));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search tasks',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _chip('All', null),
              for (final deadlineStatus in DeadlineStatus.values)
                _chip(deadlineStatus.label, deadlineStatus),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: visible.isEmpty ? _empty() : _list(visible, now),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, DeadlineStatus? deadlineStatus) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == deadlineStatus,
      showCheckmark: false,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: _filter == deadlineStatus ? Colors.white : AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => setState(() => _filter = deadlineStatus),
    ),
  );

  // Scrollable so pull-to-refresh works on an empty list too.
  Widget _empty() {
    final noTasks = _tasks.isEmpty;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 60),
        EmptyState(
          icon: noTasks ? Icons.assignment_outlined : Icons.search_off,
          title: noTasks ? 'No tasks yet' : 'No matching tasks',
          message: noTasks
              ? 'Tap the + button to create your first task.'
              : 'Try a different search or filter.',
        ),
      ],
    );
  }

  Widget _list(List<Task> tasks, DateTime now) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final task = tasks[i];
        final member = _members[task.assigneeId];
        final deadlineStatus = calculateDeadlineStatus(
          task,
          now,
        ).deadlineStatus;
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _open(task),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
              child: Row(
                children: [
                  MemberAvatar(member),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${member?.name ?? 'Unknown'} · ${dueDateLabel(task)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            DeadlineStatusBadge(deadlineStatus),
                            StatusChip(task.status),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Task menu',
                    onSelected: (_) => _edit(task),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
