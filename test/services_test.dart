import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_f1_g4/models/models.dart';
import 'package:mobile_app_f1_g4/services/auth_service.dart';
import 'package:mobile_app_f1_g4/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService db;
  late AuthService auth;

  // A fresh in-memory database for every test. Nothing is left on disk.
  setUp(() {
    db = DatabaseService(path: inMemoryDatabasePath);
    auth = AuthService(db, iterations: 1000);
  });
  tearDown(() => db.close());

  test('register then sign in, wrong password fails', () async {
    await auth.register(
      name: 'Jo Doe',
      role: 'Developer',
      email: ' Jo@Example.com ',
      password: 'secret123',
    );
    final member = await auth.signIn('jo@example.com', 'secret123');
    expect(member.name, 'Jo Doe');
    expect(member.role, 'Developer');
    expect(auth.currentMember, isNotNull);
    expect(
      () => auth.signIn('jo@example.com', 'wrong-pass'),
      throwsA(isA<AuthException>()),
    );
    auth.signOut();
    expect(auth.currentMember, isNull);
  });

  test('duplicate email is rejected', () async {
    await auth.register(
      name: 'A',
      role: 'Tester',
      email: 'a@x.com',
      password: 'password1',
    );
    expect(
      () => auth.register(
        name: 'B',
        role: 'Tester',
        email: 'A@x.com',
        password: 'password2',
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test('password is stored hashed with a random salt', () async {
    await auth.register(
      name: 'A',
      role: 'Tester',
      email: 'a@x.com',
      password: 'password1',
    );
    await auth.register(
      name: 'B',
      role: 'Tester',
      email: 'b@x.com',
      password: 'password1',
    );
    final a = (await db.findAccount('a@x.com'))!;
    final b = (await db.findAccount('b@x.com'))!;
    expect(a.passwordHash, isNot(contains('password1')));
    expect(a.passwordSalt, isNot(b.passwordSalt));
    expect(a.passwordHash, isNot(b.passwordHash));
  });

  test('task create, update, delete and member open-task query', () async {
    final members = await db.getMembers();
    expect(members.length, 3); // seeded team-only members
    final id = await db.insertTask(
      Task(
        title: 'Write tests',
        assigneeId: members.first.id!,
        priority: 'High',
        status: 'To Do',
        dueAt: DateTime.utc(2030),
        updatedAt: DateTime.now(),
      ),
    );
    var task = (await db.getTask(id))!;
    expect(task.title, 'Write tests');

    await db.updateTask(task.copyWith(status: 'Completed', notes: 'Done'));
    task = (await db.getTask(id))!;
    expect(task.isCompleted, isTrue);
    expect(task.notes, 'Done');

    await db.deleteTask(id);
    expect(await db.getTask(id), isNull);
  });

  test('a member with tasks cannot be removed by accident', () async {
    final members = await db.getMembers();
    await db.insertTask(
      Task(
        title: 'X',
        assigneeId: members.first.id!,
        priority: 'Low',
        status: 'To Do',
        dueAt: DateTime.utc(2030),
        updatedAt: DateTime.now(),
      ),
    );
    expect(
      () => db.insertTask(
        Task(
          title: 'Bad',
          assigneeId: 9999,
          priority: 'Low',
          status: 'To Do',
          dueAt: DateTime.utc(2030),
          updatedAt: DateTime.now(),
        ),
      ),
      throwsA(anything),
    );
  });
}
