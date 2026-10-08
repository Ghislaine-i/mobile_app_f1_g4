import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/ui_helpers.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'statistics_screen.dart';
import 'task_list_screen.dart';
import 'team_screen.dart';

typedef TabSelect = void Function(int index);

// Holds the bottom navigation. Tabs are rebuilt on switch and on app resume,
// so they reload fresh data.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() => _version++);
  }

  void _select(int index) => setState(() {
    _tab = index;
    _version++;
  });

  Widget _page() {
    final key = ValueKey('$_tab-$_version');
    return switch (_tab) {
      0 => DashboardScreen(key: key, onTab: _select),
      1 => TaskListScreen(key: key, onTab: _select),
      2 => TeamScreen(key: key, onTab: _select),
      _ => ProfileScreen(key: key, onTab: _select),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _page(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Team',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Side menu shared by the four tabs.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.onTab});
  final TabSelect onTab;

  @override
  Widget build(BuildContext context) {
    final member = AuthService.instance.currentMember;

    Widget item(IconData icon, String label, VoidCallback onTap) => ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      onTap: () {
        Navigator.pop(context); // close the drawer
        onTap();
      },
    );

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  MemberAvatar(member, radius: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member?.name ?? '',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          member?.role ?? '',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            item(Icons.home_outlined, 'Dashboard', () => onTab(0)),
            item(Icons.checklist_outlined, 'Tasks', () => onTab(1)),
            item(Icons.groups_outlined, 'Team members', () => onTab(2)),
            item(Icons.bar_chart_outlined, 'Task statistics', () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
              );
            }),
            item(Icons.person_outline, 'Profile', () => onTab(3)),
          ],
        ),
      ),
    );
  }
}

// Greeting text based on the hour of day.
String greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}
