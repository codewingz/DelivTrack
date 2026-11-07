import 'dart:async';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/core/ids/order_number.dart';
import 'package:deliv_track/features/parcels/data/parcel_repository.dart';
import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_input.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';

/// A saved parcel for tests (override what a test cares about).
Parcel testParcel({
  String id = 'p1',
  int sequence = 1,
  String customerName = 'Ali Raza',
  String customerPhone = '0300 1111111',
  String customerAddress = 'House 5, Street 2, Sahiwal',
  CollectionMethod method = CollectionMethod.postalCollection,
  PostalService service = PostalService.vpp,
  String? otherName,
  String reference = 'VPP 12345',
  int? charge = 15050,
  int? packedGrams,
  String sendingDate = '2026-11-07',
  String? payDate,
  ParcelStatus status = ParcelStatus.sent,
  PaymentStatus? payment,
  List<ParcelItem>? items,
}) {
  final lines = items ?? [ParcelItem.pieces(productId: 'x', productName: 'Mango Box', quantity: 2, unitPricePaisa: 250000)];
  final expected = method == CollectionMethod.giftFree ? 0 : lines.fold(0, (sum, i) => sum + i.lineTotalPaisa);
  return Parcel(
    id: id,
    orderNumber: formatOrderNumber(sequence),
    orderSequence: sequence,
    customerId: 'c1',
    customerName: customerName,
    customerPhone: customerPhone,
    customerAddress: customerAddress,
    items: lines,
    method: method,
    service: service,
    otherServiceName: otherName,
    postalReference: reference,
    deliveryChargePaisa: charge,
    packedWeightGrams: packedGrams,
    sendingDate: sendingDate,
    estimatedPaymentDate: payDate,
    expectedPaisa: expected,
    receivedPaisa: 0,
    outstandingPaisa: expected,
    paymentStatus: payment ?? (method == CollectionMethod.giftFree ? PaymentStatus.notRequired : PaymentStatus.pending),
    status: status,
  );
}

/// In-memory repository: keeps parcels (newest first), records created inputs, can fail or wait.
class FakeParcelRepository implements ParcelRepository {
  FakeParcelRepository({this.failure, List<Parcel> initial = const []}) : _parcels = [...initial];

  AppFailure? failure;
  Completer<void>? gate;
  final created = <ParcelInput>[];
  int creates = 0;
  int watchAllCalls = 0;
  final List<Parcel> _parcels;
  final _changes = StreamController<void>.broadcast();

  List<Parcel> get parcels => List.unmodifiable(_parcels);

  List<Parcel> _sorted() => [..._parcels]..sort((a, b) => b.orderSequence.compareTo(a.orderSequence));

  void emitError(Object error) => _changes.addError(error);

  @override
  Future<String> create(ParcelInput input) async {
    creates++;
    await gate?.future;
    if (failure != null) throw failure!;
    created.add(input);
    final sequence = _parcels.length + 1;
    _parcels.add(testParcel(
      id: 'parcel-$sequence',
      sequence: sequence,
      customerName: input.customer.name,
      customerPhone: input.customer.phone,
      customerAddress: input.customer.address,
      method: input.method,
      service: input.service,
      otherName: input.otherServiceName,
      reference: input.postalReference.trim(),
      charge: input.deliveryChargePaisa,
      packedGrams: input.packedWeightGrams,
      payDate: input.estimatedPaymentDate,
      status: input.status,
      items: input.items,
    ));
    _changes.add(null);
    return 'parcel-$sequence';
  }

  @override
  Stream<List<Parcel>> watchAll() async* {
    watchAllCalls++;
    yield _sorted();
    await for (final _ in _changes.stream) {
      yield _sorted();
    }
  }

  @override
  Stream<Parcel?> watch(String id) async* {
    Parcel? find() => _parcels.where((p) => p.id == id).firstOrNull;
    yield find();
    await for (final _ in _changes.stream) {
      yield find();
    }
  }
}
