import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/deadline_status.dart';
import '../theme.dart';
import '../widgets/ui_helpers.dart';
import 'task_form_screen.dart';

class TaskDetailsScreen extends StatefulWidget {
  const TaskDetailsScreen({super.key, required this.taskId});
  final int taskId;

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  Task? _task;
  TeamMember? _assignee;
  List<TaskNote> _notes = [];
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
      final task = await db.getTask(widget.taskId);
      final assignee = task == null
          ? null
          : await db.getMember(task.assigneeId);
      final notes = task == null
          ? <TaskNote>[]
          : await db.getTaskNotes(task.id!);
      if (!mounted) return;
      setState(() {
        _task = task;
        _assignee = assignee;
        _notes = notes;
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

  Future<void> _edit() async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => TaskFormScreen(task: _task)),
    );
    if (!mounted || message == null) return;
    await _load();
    if (mounted) showSnack(context, message);
  }

  Future<void> _editNote([TaskNote? note]) async {
    final current = AuthService.instance.currentMember;
    final task = _task;
    if (current == null || task?.id == null) return;
    final body = await showDialog<String>(
      context: context,
      builder: (context) => _TaskNoteDialog(note: note),
    );
    if (body == null || !mounted) return;
    try {
      if (note == null) {
        await DatabaseService.instance.insertTaskNote(
          taskId: task!.id!,
          authorMemberId: current.id!,
          authorName: current.name,
          body: body,
        );
      } else {
        final changed = await DatabaseService.instance.updateTaskNote(
          id: note.id!,
          authorMemberId: current.id!,
          body: body,
        );
        if (changed == 0) throw StateError('Note is no longer editable.');
      }
      await _load();
      if (mounted) {
        showSnack(context, note == null ? 'Note added' : 'Note updated');
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Could not save the note.');
    }
  }

  Future<void> _deleteNote(TaskNote note) async {
    final current = AuthService.instance.currentMember;
    if (current?.id == null || note.id == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Delete note?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      final deleted = await DatabaseService.instance.deleteTaskNote(
        id: note.id!,
        authorMemberId: current!.id!,
      );
      if (deleted == 0) throw StateError('Note is no longer editable.');
      await _load();
      if (mounted) showSnack(context, 'Note deleted');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not delete the note.');
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete task?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await DatabaseService.instance.deleteTask(widget.taskId);
      if (mounted) Navigator.pop(context, 'Task deleted');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not delete the task.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task details'),
        actions: [
          if (_task != null)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? _edit() : _delete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? ErrorState(onRetry: _load)
          : _task == null
          ? const Center(child: Text('This task no longer exists.'))
          : _content(_task!),
    );
  }

  Widget _content(Task task) {
    final result = calculateDeadlineStatus(task, DateTime.now());
    final color = AppColors.deadlineStatus(result.deadlineStatus);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DeadlineStatusBadge(result.deadlineStatus),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task.description,
                style: const TextStyle(color: AppColors.muted, fontSize: 15),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row(
                      Icons.person_outline,
                      'Assigned to',
                      _assignee?.name ?? 'Unknown',
                    ),
                    _row(
                      Icons.calendar_today_outlined,
                      'Due date',
                      dueDateLabel(task),
                    ),
                    _row(Icons.flag_outlined, 'Priority', task.priority),
                    _row(Icons.list_alt_outlined, 'Status', task.status),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.deadlineStatusSoft(result.deadlineStatus),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deadline status: ${result.deadlineStatus.label}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(result.reason, style: TextStyle(color: color)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: SectionTitle('Notes')),
                TextButton.icon(
                  onPressed: () => _editNote(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add note'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_notes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No notes yet.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            for (final note in _notes) _noteCard(note),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _edit, child: const Text('Edit task')),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Icon(icon, size: 20, color: AppColors.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
              SizedBox(
                width: 112,
                child: Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _noteCard(TaskNote note) {
    final memberId = AuthService.instance.currentMember?.id;
    final canEdit = note.id != null && note.authorMemberId == memberId;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.authorName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (canEdit)
                  PopupMenuButton<String>(
                    tooltip: 'Note actions',
                    onSelected: (action) =>
                        action == 'edit' ? _editNote(note) : _deleteNote(note),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            Text(note.body),
          ],
        ),
      ),
    );
  }
}

class _TaskNoteDialog extends StatefulWidget {
  const _TaskNoteDialog({this.note});
  final TaskNote? note;

  @override
  State<_TaskNoteDialog> createState() => _TaskNoteDialogState();
}

class _TaskNoteDialogState extends State<_TaskNoteDialog> {
  late final _body = TextEditingController(text: widget.note?.body);

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  void _save() {
    final value = _body.text.trim();
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AppAlertDialog(
    title: Text(widget.note == null ? 'Add note' : 'Edit note'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _body,
            autofocus: true,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Note',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          DialogActionButtons(
            primaryLabel: 'Save',
            onPrimary: _save,
            onCancel: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}
