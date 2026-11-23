import 'dart:async';

import 'package:deliv_track/features/settings/data/sender_profile_repository.dart';
import 'package:deliv_track/features/settings/domain/sender_profile.dart';

class FakeSenderProfileRepository implements SenderProfileRepository {
  FakeSenderProfileRepository({SenderProfile? initial}) : _profile = initial {
    _controller.add(_profile);
  }

  SenderProfile? _profile;
  final _controller = StreamController<SenderProfile?>.broadcast();
  int saveCount = 0;

  @override
  Future<SenderProfile?> getProfile() async => _profile;

  @override
  Stream<SenderProfile?> watchProfile() => _controller.stream;

  @override
  Future<void> saveProfile(SenderProfile profile) async {
    saveCount++;
    _profile = profile;
    _controller.add(profile);
  }

  void dispose() {
    _controller.close();
  }
}

class FailingSenderProfileRepository implements SenderProfileRepository {
  @override
  Future<SenderProfile?> getProfile() async => throw Exception('Network error');

  @override
  Stream<SenderProfile?> watchProfile() =>
      Stream.error(Exception('Network error'));

  @override
  Future<void> saveProfile(SenderProfile profile) async =>
      throw Exception('Network error');
}
