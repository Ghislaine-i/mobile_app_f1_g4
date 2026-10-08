import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme.dart';
import '../widgets/member_dialog.dart';
import '../widgets/ui_helpers.dart';
import 'home_shell.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onTab});
  final TabSelect onTab;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _edit(TeamMember current) async {
    final member = await showDialog<TeamMember>(
      context: context,
      builder: (_) => MemberDialog(title: 'Edit profile', member: current),
    );
    if (member == null) return;
    try {
      await DatabaseService.instance.updateMember(member);
      await AuthService.instance.refreshCurrent();
      if (!mounted) return;
      setState(() {});
      showSnack(context, 'Profile updated');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not update the profile.');
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: const Text('Delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Your account and team profile will be permanently deleted. '
              'This cannot be undone. Reassign or delete your tasks first.',
            ),
            const SizedBox(height: 20),
            DialogActionButtons(
              primaryLabel: 'Delete account',
              onPrimary: () => Navigator.pop(context, true),
              destructive: true,
              onCancel: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AuthService.instance.deleteCurrentAccount();
      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } on MemberHasTasksException {
      if (mounted) {
        showSnack(context, 'Reassign or delete your tasks before deleting.');
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Could not delete the account.');
    }
  }

  void _settings() {
    showDialog<void>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: const Text('App settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Storage: on this device only'),
            const SizedBox(height: 8),
            const Text('At Risk window: 24 hours before the deadline'),
            const SizedBox(height: 8),
            const Text('Deadline: the end of the selected due date'),
            const SizedBox(height: 12),
            const Text(
              'Example: a task due today is At Risk for most of the day.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            DialogActionButtons(
              onCancel: () => Navigator.pop(context),
              cancelLabel: 'Close',
            ),
          ],
        ),
      ),
    );
  }

  void _about() {
    showDialog<void>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: const Text('About'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Project & Task Tracker app\nVersion 1.0.0\n\n'
              'Plan tasks, assign them to your team and see which ones need '
              'attention. All data stays on this device.',
            ),
            const SizedBox(height: 20),
            DialogActionButtons(
              onCancel: () => Navigator.pop(context),
              cancelLabel: 'Close',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final member = AuthService.instance.currentMember;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      drawer: AppDrawer(onTab: widget.onTab),
      body: member == null
          ? const SizedBox()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 8),
                Center(child: MemberAvatar(member, radius: 44)),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    member.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    member.role,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.edit_outlined,
                          color: AppColors.primary,
                        ),
                        title: const Text('Edit profile'),
                        onTap: () => _edit(member),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.settings_outlined,
                          color: AppColors.primary,
                        ),
                        title: const Text('App settings'),
                        onTap: _settings,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.info_outline,
                          color: AppColors.primary,
                        ),
                        title: const Text('About'),
                        onTap: _about,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.logout,
                          color: Color(0xFFB91C1C),
                        ),
                        title: const Text(
                          'Sign out',
                          style: TextStyle(color: Color(0xFFB91C1C)),
                        ),
                        onTap: () => signOutToLogin(context),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFB91C1C),
                        ),
                        title: const Text(
                          'Delete account',
                          style: TextStyle(color: Color(0xFFB91C1C)),
                        ),
                        onTap: _deleteAccount,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
