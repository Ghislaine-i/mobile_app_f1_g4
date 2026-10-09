import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/deadline_status.dart';
import '../theme.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];

String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

// The due date shown to users is the day they picked, not the deadline instant.
String dueDateLabel(Task task) => formatDate(dateForDeadline(task.dueAt));

String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}

void showSnack(BuildContext context, String? message) {
  if (message == null) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AppAlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message),
          const SizedBox(height: 20),
          DialogActionButtons(
            primaryLabel: confirmLabel,
            onPrimary: () => Navigator.pop(context, true),
            destructive: destructive,
            onCancel: () => Navigator.pop(context, false),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({super.key, required this.title, required this.content});

  final Widget title;
  final Widget content;

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    constraints: const BoxConstraints(maxWidth: 480),
    title: title,
    content: SizedBox(width: double.maxFinite, child: content),
  );
}

class DialogActionButtons extends StatelessWidget {
  const DialogActionButtons({
    super.key,
    this.primaryLabel,
    this.onPrimary,
    this.destructive = false,
    required this.onCancel,
    this.cancelLabel = 'Cancel',
  });

  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool destructive;
  final VoidCallback onCancel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (primaryLabel != null)
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onPrimary,
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                  )
                : null,
            child: Text(primaryLabel!),
          ),
        ),
      SizedBox(
        width: double.infinity,
        child: TextButton(onPressed: onCancel, child: Text(cancelLabel)),
      ),
    ],
  );
}

class DeadlineStatusBadge extends StatelessWidget {
  const DeadlineStatusBadge(this.deadlineStatus, {super.key});
  final DeadlineStatus deadlineStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.deadlineStatusSoft(deadlineStatus),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        deadlineStatus.label,
        style: TextStyle(
          color: AppColors.deadlineStatus(deadlineStatus),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// Workflow status chip. Neutral colors keep it apart from the Deadline status badge.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    );
  }
}

class MemberAvatar extends StatelessWidget {
  const MemberAvatar(this.member, {super.key, this.radius = 20});
  final TeamMember? member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final m = member;
    final color = m?.id == null
        ? AppColors.muted
        : AppColors.avatars[m!.id! % AppColors.avatars.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        m?.initials ?? '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.primary.withValues(alpha: .5)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load data.'),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
  );
}
