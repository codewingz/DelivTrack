import 'dart:async';
import 'package:deliv_track/features/auth/data/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.failure});
  final AuthFailure? failure;
  Completer<void>? gate;
  final signUps = <({String name, String email, String password})>[];
  final signIns = <({String email, String password})>[];
  final resets = <String>[];

  Future<void> _finish() async {
    await gate?.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> signUp({required String name, required String email, required String password}) {
    signUps.add((name: name, email: email, password: password));
    return _finish();
  }

  @override
  Future<void> signIn({required String email, required String password}) {
    signIns.add((email: email, password: password));
    return _finish();
  }

  @override
  Future<void> sendPasswordReset({required String email}) {
    resets.add(email);
    return _finish();
  }
}
