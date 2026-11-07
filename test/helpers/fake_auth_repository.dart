import 'dart:async';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/auth/data/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.failure, this.signedIn = false, this.name});

  final AppFailure? failure;
  Completer<void>? gate;
  final signUps = <({String name, String email, String password})>[];
  final signIns = <({String email, String password})>[];
  final resets = <String>[];
  int signOuts = 0;
  int verifyCalls = 0;

  bool signedIn;
  String? name;
  final _signedInController = StreamController<bool>.broadcast();
  final _nameController = StreamController<String?>.broadcast();

  /// Simulates an auth change that did not come from this app's own calls
  /// (e.g. the server revoked the session after a password reset elsewhere).
  void emitSignedIn(bool value, {String? name}) {
    signedIn = value;
    this.name = value ? (name ?? this.name) : null;
    _signedInController.add(value);
  }

  void emitName(String? name) {
    this.name = name;
    _nameController.add(name);
  }

  Future<void> _finish() async {
    await gate?.future;
    if (failure != null) throw failure!;
  }

  @override
  bool get isSignedIn => signedIn;

  @override
  Stream<bool> get signedInChanges => _signedInController.stream;

  @override
  String? get displayName => name;

  @override
  Stream<String?> get displayNameChanges => _nameController.stream;

  @override
  Future<void> signUp({required String name, required String email, required String password}) async {
    signUps.add((name: name, email: email, password: password));
    await _finish();
    emitSignedIn(true, name: name);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signIns.add((email: email, password: password));
    await _finish();
    emitSignedIn(true);
  }

  @override
  Future<void> sendPasswordReset({required String email}) {
    resets.add(email);
    return _finish();
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    emitSignedIn(false);
  }

  @override
  Future<void> verifySession() async => verifyCalls++;
}
