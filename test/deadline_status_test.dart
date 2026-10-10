import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_f1_g4/models/models.dart';
import 'package:mobile_app_f1_g4/services/deadline_status.dart';

Task taskDue(DateTime dueAt, {String status = 'To Do'}) => Task(
  title: 'T',
  assigneeId: 1,
  priority: 'Low',
  status: status,
  dueAt: dueAt.toUtc(),
  updatedAt: DateTime(2025),
);

void main() {
  final now = DateTime(2025, 6, 10, 12);

  test('completed task is Completed even when late', () {
    final t = taskDue(
      now.subtract(const Duration(days: 3)),
      status: 'Completed',
    );
    expect(
      calculateDeadlineStatus(t, now).deadlineStatus,
      DeadlineStatus.completed,
    );
  });

  test('deadline exactly now is Overdue', () {
    expect(
      calculateDeadlineStatus(taskDue(now), now).deadlineStatus,
      DeadlineStatus.overdue,
    );
  });

  test('deadline one minute ago is Overdue with reason', () {
    final r = calculateDeadlineStatus(
      taskDue(now.subtract(const Duration(days: 2))),
      now,
    );
    expect(r.deadlineStatus, DeadlineStatus.overdue);
    expect(r.reason, 'Overdue by 2 days');
  });

  test('exactly 24 hours left is At Risk (inclusive)', () {
    final r = calculateDeadlineStatus(
      taskDue(now.add(const Duration(hours: 24))),
      now,
    );
    expect(r.deadlineStatus, DeadlineStatus.atRisk);
  });

  test('24 hours and one minute left is On Track', () {
    final due = now.add(const Duration(hours: 24, minutes: 1));
    expect(
      calculateDeadlineStatus(taskDue(due), now).deadlineStatus,
      DeadlineStatus.onTrack,
    );
  });

  test('one second left is At Risk', () {
    final due = now.add(const Duration(seconds: 1));
    final r = calculateDeadlineStatus(taskDue(due), now);
    expect(r.deadlineStatus, DeadlineStatus.atRisk);
    expect(r.reason, 'Due in 1 minute');
  });

  test('due in 5 hours reason', () {
    final r = calculateDeadlineStatus(
      taskDue(now.add(const Duration(hours: 5))),
      now,
    );
    expect(r.reason, 'Due in 5 hours');
  });

  test('task due today is At Risk (deadline is start of next day)', () {
    final deadline = deadlineForDate(DateTime(2025, 6, 10));
    expect(deadline.toLocal(), DateTime(2025, 6, 11));
    expect(
      calculateDeadlineStatus(taskDue(deadline), now).deadlineStatus,
      DeadlineStatus.atRisk,
    );
  });

  test('date round trip', () {
    final date = DateTime(2025, 12, 31);
    expect(dateForDeadline(deadlineForDate(date)), date);
  });

  test('counts add up to the total', () {
    final tasks = [
      taskDue(now.subtract(const Duration(hours: 1))),
      taskDue(now.add(const Duration(hours: 2))),
      taskDue(now.add(const Duration(days: 9))),
      taskDue(now, status: 'Completed'),
    ];
    final counts = countTasksByDeadlineStatus(tasks, now);
    expect(counts.values.reduce((a, b) => a + b), tasks.length);
    expect(counts[DeadlineStatus.overdue], 1);
    expect(counts[DeadlineStatus.atRisk], 1);
    expect(counts[DeadlineStatus.onTrack], 1);
    expect(counts[DeadlineStatus.completed], 1);
  });
}
