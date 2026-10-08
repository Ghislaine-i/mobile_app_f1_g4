import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme.dart';
import '../widgets/member_dialog.dart';
import '../widgets/ui_helpers.dart';
import 'home_shell.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key, required this.onTab});
  final TabSelect onTab;

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  List<TeamMember> _members = [];
  Set<int> _withLogin = {};
  Map<int, int> _openTasks = {};
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
      final members = await db.getMembers();
      final withLogin = await db.getMemberIdsWithLogin();
      final tasks = await db.getTasks();
      // Open task count is calculated, not stored.
      final open = <int, int>{};
      for (final t in tasks.where((t) => !t.isCompleted)) {
        open[t.assigneeId] = (open[t.assigneeId] ?? 0) + 1;
      }
      if (!mounted) return;
      setState(() {
        _members = members;
        _withLogin = withLogin;
        _openTasks = open;
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

  Future<void> _add() async {
    final member = await showDialog<TeamMember>(
      context: context,
      builder: (_) => const MemberDialog(title: 'Add team member'),
    );
    if (member == null) return;
    try {
      await DatabaseService.instance.insertMember(member);
      if (!mounted) return;
      showSnack(context, 'Member added');
      _load();
    } catch (_) {
      if (mounted) showSnack(context, 'Could not add the member.');
    }
  }

  Future<void> _edit(TeamMember current) async {
    if (_withLogin.contains(current.id)) {
      if (mounted) {
        showSnack(context, 'Edit login accounts from the profile screen.');
      }
      return;
    }
    final member = await showDialog<TeamMember>(
      context: context,
      builder: (_) => MemberDialog(title: 'Edit member', member: current),
    );
    if (member == null) return;
    try {
      await DatabaseService.instance.updateMember(member);
      await AuthService.instance.refreshCurrent();
      if (!mounted) return;
      showSnack(context, 'Member updated');
      _load();
    } catch (_) {
      if (mounted) showSnack(context, 'Could not update the member.');
    }
  }

  Future<void> _delete(TeamMember member) async {
    final hasLogin = _withLogin.contains(member.id);
    if (hasLogin || member.id == AuthService.instance.currentMember?.id) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: const Text('Delete team member?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Delete ${member.name}? This cannot be undone.'),
            const SizedBox(height: 20),
            DialogActionButtons(
              primaryLabel: 'Delete',
              onPrimary: () => Navigator.pop(context, true),
              destructive: true,
              onCancel: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || member.id == null) return;
    try {
      await DatabaseService.instance.deleteMember(member.id!);
      if (!mounted) return;
      showSnack(context, 'Member deleted');
      await _load();
    } on MemberHasTasksException {
      if (mounted) {
        showSnack(context, 'Reassign or delete this member’s tasks first.');
      }
    } on MemberHasLoginException {
      if (mounted) {
        showSnack(context, 'Delete login accounts from the profile screen.');
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Could not delete the member.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = AuthService.instance.currentMember?.id;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team members'),
        actions: [
          IconButton(
            tooltip: 'Add member',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: _add,
          ),
        ],
      ),
      drawer: AppDrawer(onTab: widget.onTab),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? ErrorState(onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: _members.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final m = _members[i];
                  final open = _openTasks[m.id] ?? 0;
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                      leading: MemberAvatar(m, radius: 22),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              m.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (m.id == myId) ...[
                            const SizedBox(width: 6),
                            const Text(
                              '(you)',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '${m.role} · $open open ${open == 1 ? 'task' : 'tasks'}'
                        '${_withLogin.contains(m.id) ? '' : ' · No login'}',
                      ),
                      trailing: _withLogin.contains(m.id)
                          ? null
                          : PopupMenuButton<String>(
                              tooltip: 'Member menu',
                              onSelected: (action) {
                                if (action == 'edit') _edit(m);
                                if (action == 'delete') _delete(m);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                if (m.id != myId)
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Color(0xFFB91C1C),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
