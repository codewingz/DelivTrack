import 'dart:async';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/parcels/data/parcel_repository.dart';
import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_input.dart';

/// Records what the form asks it to create; can be told to fail or to wait.
class FakeParcelRepository implements ParcelRepository {
  FakeParcelRepository({this.failure});

  AppFailure? failure;
  Completer<void>? gate;
  final created = <ParcelInput>[];
  int creates = 0;

  @override
  Future<String> create(ParcelInput input) async {
    creates++;
    await gate?.future;
    if (failure != null) throw failure!;
    created.add(input);
    return 'parcel-${created.length}';
  }

  @override
  Stream<List<Parcel>> watchAll() => Stream.value(const []);

  @override
  Stream<Parcel?> watch(String id) => Stream.value(null);
}
