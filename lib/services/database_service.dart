import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

class EmailTakenException implements Exception {}

class MemberHasTasksException implements Exception {}

class MemberHasLoginException implements Exception {}

class DatabaseService {
  // Pass a path (for example inMemoryDatabasePath) in tests.
  DatabaseService({this.path});

  static final instance = DatabaseService();

  final String? path;
  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final file = path ?? join(await getDatabasesPath(), 'tracker.db');
    return openDatabase(
      file,
      version: 2,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE team_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        role TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        team_member_id INTEGER NOT NULL UNIQUE
          REFERENCES team_members(id) ON DELETE CASCADE,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        assignee_id INTEGER NOT NULL
          REFERENCES team_members(id) ON DELETE RESTRICT,
        priority TEXT NOT NULL,
        status TEXT NOT NULL,
        due_at INTEGER NOT NULL,
        notes TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )''');
    await _createTaskNotes(db);
    // Fictional team-only members. No passwords are seeded.
    for (final m in const [
      TeamMember(name: 'Sarah Lee', role: 'Designer'),
      TeamMember(name: 'Michael Kim', role: 'Developer'),
      TeamMember(name: 'Emily Wong', role: 'Tester'),
    ]) {
      await db.insert('team_members', m.toMap());
    }
  }

  Future<void> _upgradeTables(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createTaskNotes(db);
      await db.execute('''
        INSERT INTO task_notes (
          task_id, author_member_id, author_name, body, created_at, updated_at
        )
        SELECT id, NULL, 'Team', notes, updated_at, updated_at
        FROM tasks WHERE trim(notes) <> ''
      ''');
    }
  }

  Future<void> _createTaskNotes(Database db) async {
    await db.execute('''
      CREATE TABLE task_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        author_member_id INTEGER REFERENCES team_members(id) ON DELETE SET NULL,
        author_name TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // Accounts

  Future<Account?> findAccount(String email) async {
    final db = await _database;
    final rows = await db.query(
      'accounts',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    return rows.isEmpty ? null : Account.fromMap(rows.first);
  }

  Future<TeamMember> createAccountWithMember({
    required String name,
    required String role,
    required String email,
    required String passwordHash,
    required String passwordSalt,
  }) async {
    final db = await _database;
    return db.transaction((txn) async {
      final taken = await txn.query(
        'accounts',
        where: 'email = ?',
        whereArgs: [email],
        limit: 1,
      );
      if (taken.isNotEmpty) throw EmailTakenException();
      final member = TeamMember(name: name, role: role);
      final id = await txn.insert('team_members', member.toMap());
      await txn.insert('accounts', {
        'team_member_id': id,
        'email': email,
        'password_hash': passwordHash,
        'password_salt': passwordSalt,
      });
      return TeamMember(id: id, name: name, role: role);
    });
  }

  // Members

  Future<List<TeamMember>> getMembers() async {
    final db = await _database;
    final rows = await db.query('team_members', orderBy: 'name COLLATE NOCASE');
    return rows.map(TeamMember.fromMap).toList();
  }

  Future<TeamMember?> getMember(int id) async {
    final db = await _database;
    final rows = await db.query(
      'team_members',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : TeamMember.fromMap(rows.first);
  }

  Future<Set<int>> getMemberIdsWithLogin() async {
    final db = await _database;
    final rows = await db.query('accounts', columns: ['team_member_id']);
    return rows.map((r) => r['team_member_id'] as int).toSet();
  }

  Future<int> insertMember(TeamMember member) async {
    final db = await _database;
    return db.insert('team_members', member.toMap());
  }

  Future<void> updateMember(TeamMember member) async {
    final db = await _database;
    await db.update(
      'team_members',
      member.toMap(),
      where: 'id = ?',
      whereArgs: [member.id],
    );
  }

  Future<void> deleteMember(int id) async {
    final db = await _database;
    await db.transaction((txn) async {
      final accounts = await txn.query(
        'accounts',
        columns: ['team_member_id'],
        where: 'team_member_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (accounts.isNotEmpty) throw MemberHasLoginException();
      final tasks = await txn.rawQuery(
        'SELECT COUNT(*) AS count FROM tasks WHERE assignee_id = ?',
        [id],
      );
      if ((tasks.first['count'] as int) > 0) {
        throw MemberHasTasksException();
      }
      await txn.delete('team_members', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteAccountMember(int id) async {
    final db = await _database;
    await db.transaction((txn) async {
      final accounts = await txn.query(
        'accounts',
        columns: ['team_member_id'],
        where: 'team_member_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (accounts.isEmpty) throw MemberHasLoginException();

      final tasks = await txn.rawQuery(
        'SELECT COUNT(*) AS count FROM tasks WHERE assignee_id = ?',
        [id],
      );
      if ((tasks.first['count'] as int) > 0) {
        throw MemberHasTasksException();
      }
      await txn.delete('team_members', where: 'id = ?', whereArgs: [id]);
    });
  }

  // Tasks

  Future<List<Task>> getTasks() async {
    final db = await _database;
    final rows = await db.query('tasks', orderBy: 'due_at ASC');
    return rows.map(Task.fromMap).toList();
  }

  Future<Task?> getTask(int id) async {
    final db = await _database;
    final rows = await db.query('tasks', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Task.fromMap(rows.first);
  }

  Map<String, Object?> _taskValues(Task task) => {
    ...task.toMap(),
    'updated_at': DateTime.now().millisecondsSinceEpoch,
  };

  Future<int> insertTask(Task task) async {
    final db = await _database;
    return db.insert('tasks', _taskValues(task));
  }

  Future<void> updateTask(Task task) async {
    final db = await _database;
    await db.update(
      'tasks',
      _taskValues(task),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> deleteTask(int id) async {
    final db = await _database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TaskNote>> getTaskNotes(int taskId) async {
    final db = await _database;
    final rows = await db.query(
      'task_notes',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'created_at ASC, id ASC',
    );
    return rows.map(TaskNote.fromMap).toList();
  }

  Future<int> insertTaskNote({
    required int taskId,
    required int authorMemberId,
    required String authorName,
    required String body,
  }) async {
    final db = await _database;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return db.insert('task_notes', {
      'task_id': taskId,
      'author_member_id': authorMemberId,
      'author_name': authorName,
      'body': body,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<int> updateTaskNote({
    required int id,
    required int authorMemberId,
    required String body,
  }) async {
    final db = await _database;
    return db.update(
      'task_notes',
      {
        'body': body,
        'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      },
      where: 'id = ? AND author_member_id = ?',
      whereArgs: [id, authorMemberId],
    );
  }

  Future<int> deleteTaskNote({
    required int id,
    required int authorMemberId,
  }) async {
    final db = await _database;
    return db.delete(
      'task_notes',
      where: 'id = ? AND author_member_id = ?',
      whereArgs: [id, authorMemberId],
    );
  }
}
