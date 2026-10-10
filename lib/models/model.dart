const roles = ['Project Manager', 'Developer', 'Designer', 'Tester'];
const priorities = ['Low', 'Medium', 'High'];
const statuses = ['To Do', 'In Progress', 'Completed'];

class TeamMember {
  final int? id;
  final String name;
  final String role;

  const TeamMember({this.id, required this.name, required this.role});

  // First letters of the first two words, for avatars.
  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  factory TeamMember.fromMap(Map<String, Object?> map) => TeamMember(
    id: map['id'] as int,
    name: map['name'] as String,
    role: map['role'] as String,
  );

  Map<String, Object?> toMap() => {'name': name, 'role': role};
}

class Account {
  final int memberId;
  final String email;
  final String passwordHash;
  final String passwordSalt;

  const Account({
    required this.memberId,
    required this.email,
    required this.passwordHash,
    required this.passwordSalt,
  });

  factory Account.fromMap(Map<String, Object?> map) => Account(
    memberId: map['team_member_id'] as int,
    email: map['email'] as String,
    passwordHash: map['password_hash'] as String,
    passwordSalt: map['password_salt'] as String,
  );
}

class TaskNote {
  final int? id;
  final int taskId;
  final int? authorMemberId;
  final String authorName;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskNote({
    this.id,
    required this.taskId,
    required this.authorMemberId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskNote.fromMap(Map<String, Object?> map) => TaskNote(
    id: map['id'] as int,
    taskId: map['task_id'] as int,
    authorMemberId: map['author_member_id'] as int?,
    authorName: map['author_name'] as String,
    body: map['body'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      map['created_at'] as int,
      isUtc: true,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      map['updated_at'] as int,
      isUtc: true,
    ),
  );
}

class Task {
  final int? id;
  final String title;
  final String description;
  final int assigneeId;
  final String priority;
  final String status;
  final DateTime dueAt; // UTC instant when the deadline ends
  final String notes;
  final DateTime updatedAt;

  const Task({
    this.id,
    required this.title,
    this.description = '',
    required this.assigneeId,
    required this.priority,
    required this.status,
    required this.dueAt,
    this.notes = '',
    required this.updatedAt,
  });

  bool get isCompleted => status == 'Completed';

  Task copyWith({String? status, String? notes}) => Task(
    id: id,
    title: title,
    description: description,
    assigneeId: assigneeId,
    priority: priority,
    status: status ?? this.status,
    dueAt: dueAt,
    notes: notes ?? this.notes,
    updatedAt: updatedAt,
  );

  factory Task.fromMap(Map<String, Object?> map) => Task(
    id: map['id'] as int,
    title: map['title'] as String,
    description: map['description'] as String,
    assigneeId: map['assignee_id'] as int,
    priority: map['priority'] as String,
    status: map['status'] as String,
    dueAt: DateTime.fromMillisecondsSinceEpoch(
      map['due_at'] as int,
      isUtc: true,
    ),
    notes: map['notes'] as String,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      map['updated_at'] as int,
      isUtc: true,
    ),
  );

  Map<String, Object?> toMap() => {
    'title': title,
    'description': description,
    'assignee_id': assigneeId,
    'priority': priority,
    'status': status,
    'due_at': dueAt.millisecondsSinceEpoch,
    'notes': notes,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };
}
