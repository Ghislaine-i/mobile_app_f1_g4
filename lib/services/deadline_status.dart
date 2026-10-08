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
