import '../models/models.dart';

enum DeadlineStatus {
  onTrack('On Track'),
  atRisk('At Risk'),
  overdue('Overdue'),
  completed('Completed');

  const DeadlineStatus(this.label);
  final String label;
}

class DeadlineStatusResult {
  final DeadlineStatus deadlineStatus;
  final String reason;
  const DeadlineStatusResult(this.deadlineStatus, this.reason);
}

// The deadline is the start of the day after the chosen date (local time).
DateTime deadlineForDate(DateTime date) =>
    DateTime(date.year, date.month, date.day + 1).toUtc();

// Reverse of deadlineForDate: the date the user picked.
DateTime dateForDeadline(DateTime dueAt) {
  final local = dueAt.toLocal();
  return DateTime(local.year, local.month, local.day - 1);
}

// The one deadline status rule used everywhere. Pass the same `now` for a whole screen.
DeadlineStatusResult calculateDeadlineStatus(Task task, DateTime now) {
  if (task.isCompleted) {
    return const DeadlineStatusResult(
      DeadlineStatus.completed,
      'This task is completed.',
    );
  }
  final left = task.dueAt.difference(now);
  if (!left.isNegative && left != Duration.zero) {
    final reason = 'Due in ${_span(left)}';
    if (left <= const Duration(hours: 24)) {
      return DeadlineStatusResult(DeadlineStatus.atRisk, reason);
    }
    return DeadlineStatusResult(DeadlineStatus.onTrack, reason);
  }
  return DeadlineStatusResult(
    DeadlineStatus.overdue,
    'Overdue by ${_span(left.abs())}',
  );
}

String _span(Duration d) {
  if (d.inDays >= 1) return _plural(d.inDays, 'day');
  if (d.inHours >= 1) return _plural(d.inHours, 'hour');
  return _plural(d.inMinutes < 1 ? 1 : d.inMinutes, 'minute');
}

String _plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'}';

Map<DeadlineStatus, int> countTasksByDeadlineStatus(
  List<Task> tasks,
  DateTime now,
) {
  final counts = {for (final s in DeadlineStatus.values) s: 0};
  for (final task in tasks) {
    final deadlineStatus = calculateDeadlineStatus(task, now).deadlineStatus;
    counts[deadlineStatus] = counts[deadlineStatus]! + 1;
  }
  return counts;
}
