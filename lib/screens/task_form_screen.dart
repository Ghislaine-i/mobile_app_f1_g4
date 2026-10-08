import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../services/deadline_status.dart';
import '../widgets/ui_helpers.dart';

// One form for both create and edit. Pops with a message after a good save.
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, this.task});
  final Task? task;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title);
  late final _description = TextEditingController(
    text: widget.task?.description,
  );
  late int? _assigneeId = widget.task?.assigneeId;
  late String _priority = widget.task?.priority ?? 'Medium';
  late String _status = widget.task?.status ?? 'To Do';
  late DateTime? _dueDate = widget.task == null
      ? null
      : dateForDeadline(widget.task!.dueAt);

  List<TeamMember> _members = [];
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  bool _dateError = false;

  bool get _editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await DatabaseService.instance.getMembers();
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Could not load team members.');
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _dueDate = picked;
      _dateError = false;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final valid = _formKey.currentState!.validate();
    setState(() => _dateError = _dueDate == null);
    if (!valid || _dueDate == null) return;

    setState(() => _saving = true);
    final task = Task(
      id: widget.task?.id,
      title: _title.text.trim(),
      description: _description.text.trim(),
      assigneeId: _assigneeId!,
      priority: _priority,
      status: _status,
      dueAt: deadlineForDate(_dueDate!),
      notes: widget.task?.notes ?? '',
      updatedAt: DateTime.now(),
    );
    try {
      final db = DatabaseService.instance;
      if (_editing) {
        await db.updateTask(task);
      } else {
        await db.insertTask(task);
      }
      if (!mounted) return;
      Navigator.pop(context, _editing ? 'Task updated' : 'Task created');
    } catch (_) {
      if (!mounted) return;
      // Keep everything the user typed so they can try again.
      setState(() => _saving = false);
      showSnack(context, 'Could not save the task. Please try again.');
    }
  }

  Future<void> _askToLeave() async {
    final leave = await confirmDialog(
      context,
      title: 'Discard changes?',
      message: 'Your changes have not been saved.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (leave && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askToLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_editing ? 'Edit task' : 'Create task')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: () => _dirty = true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _title,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Task title',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter a title.'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _description,
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Description (optional)',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int>(
                          initialValue: _assigneeId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Assign to',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          items: [
                            for (final m in _members)
                              DropdownMenuItem(
                                value: m.id,
                                child: Text(
                                  '${m.name} (${m.role})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() {
                            _assigneeId = v;
                            _dirty = true;
                          }),
                          validator: (v) =>
                              v == null ? 'Choose a team member.' : null,
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Due date',
                              prefixIcon: const Icon(
                                Icons.calendar_today_outlined,
                              ),
                              suffixIcon: const Icon(Icons.edit_calendar),
                              errorText: _dateError
                                  ? 'Choose a due date.'
                                  : null,
                            ),
                            child: Text(
                              _dueDate == null
                                  ? 'Select date'
                                  : formatDate(_dueDate!),
                              style: TextStyle(
                                color: _dueDate == null
                                    ? Theme.of(context).hintColor
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _priority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                            prefixIcon: Icon(Icons.flag_outlined),
                          ),
                          items: [
                            for (final p in priorities)
                              DropdownMenuItem(value: p, child: Text(p)),
                          ],
                          onChanged: (v) => setState(() {
                            _priority = v!;
                            _dirty = true;
                          }),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            prefixIcon: Icon(Icons.list_alt_outlined),
                          ),
                          items: [
                            for (final s in statuses)
                              DropdownMenuItem(value: s, child: Text(s)),
                          ],
                          onChanged: (v) => setState(() {
                            _status = v!;
                            _dirty = true;
                          }),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(_editing ? 'Save changes' : 'Create task'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
