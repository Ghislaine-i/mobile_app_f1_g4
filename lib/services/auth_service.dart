import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';

import '../models/models.dart';
import 'database_service.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
}

const _hashIterations = 600000;

// Runs in a separate isolate so the UI stays smooth while hashing.
Future<List<int>> _hashPassword(
  String password,
  List<int> salt,
  int iterations,
) {
  return Isolate.run(() async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final key = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    return key.extractBytes();
  });
}

class AuthService {
  AuthService(this._db, {this.iterations = _hashIterations});

  static final instance = AuthService(DatabaseService.instance);

  final DatabaseService _db;
  final int iterations;

  // The logged-in user lives in memory only, so each launch starts at login.
  TeamMember? currentMember;

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  Future<void> register({
    required String name,
    required String role,
    required String email,
    required String password,
  }) async {
    final cleanEmail = normalizeEmail(email);
    if (await _db.findAccount(cleanEmail) != null) {
      throw const AuthException('This email is already registered.');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final hash = await _hashPassword(password, salt, iterations);
    try {
      await _db.createAccountWithMember(
        name: name.trim(),
        role: role,
        email: cleanEmail,
        passwordHash: base64Encode(hash),
        passwordSalt: base64Encode(salt),
      );
    } on EmailTakenException {
      throw const AuthException('This email is already registered.');
    }
  }

  Future<TeamMember> signIn(String email, String password) async {
    const wrong = AuthException('Wrong email or password.');
    final account = await _db.findAccount(normalizeEmail(email));
    if (account == null) throw wrong;
    final salt = base64Decode(account.passwordSalt);
    final hash = await _hashPassword(password, salt, iterations);
    final saved = base64Decode(account.passwordHash);
    if (!constantTimeBytesEquality.equals(hash, saved)) throw wrong;
    final member = await _db.getMember(account.memberId);
    if (member == null) throw wrong;
    currentMember = member;
    return member;
  }

  Future<void> refreshCurrent() async {
    final id = currentMember?.id;
    if (id == null) return;
    currentMember = await _db.getMember(id) ?? currentMember;
  }

  Future<void> deleteCurrentAccount() async {
    final id = currentMember?.id;
    if (id == null) throw const AuthException('No account is signed in.');
    await _db.deleteAccountMember(id);
    currentMember = null;
  }

  void signOut() => currentMember = null;
}
