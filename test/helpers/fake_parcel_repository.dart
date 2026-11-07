import 'dart:async';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/core/ids/order_number.dart';
import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:deliv_track/features/parcels/data/parcel_repository.dart';
import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_input.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/features/parcels/domain/payment.dart';
import 'package:deliv_track/utils/text.dart';
import 'package:deliv_track/features/parcels/domain/payment_rules.dart';

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
  int received = 0,
  String? notes,
  String? returnedDate,
  String? returnReason,
  bool paymentReviewRequired = false,
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
    receivedPaisa: received,
    outstandingPaisa: outstandingFor(expectedPaisa: expected, receivedPaisa: received),
    paymentStatus: payment ??
        paymentStatusFor(isFree: method == CollectionMethod.giftFree, expectedPaisa: expected, receivedPaisa: received),
    status: status,
    notes: notes,
    returnedDate: returnedDate,
    returnReason: returnReason,
    paymentReviewRequired: paymentReviewRequired,
  );
}

/// [old] with a few fields replaced.
Parcel _changed(Parcel old, {int? received, ParcelStatus? status, String? notes, String? payDate, String? returnedDate, String? returnReason, bool? review}) => testParcel(
      id: old.id,
      sequence: old.orderSequence,
      method: old.method,
      service: old.service,
      otherName: old.otherServiceName,
      reference: old.postalReference,
      charge: old.deliveryChargePaisa,
      packedGrams: old.packedWeightGrams,
      sendingDate: old.sendingDate,
      payDate: payDate ?? old.estimatedPaymentDate,
      status: status ?? old.status,
      items: old.items,
      received: received ?? old.receivedPaisa,
      notes: notes ?? old.notes,
      returnedDate: returnedDate ?? old.returnedDate,
      returnReason: returnReason ?? old.returnReason,
      paymentReviewRequired: review ?? old.paymentReviewRequired,
    );

/// In-memory repository: keeps parcels (newest first), records created inputs, can fail or wait.
class FakeParcelRepository implements ParcelRepository {
  FakeParcelRepository({this.failure, List<Parcel> initial = const []}) : _parcels = [...initial];

  AppFailure? failure;
  Completer<void>? gate;
  final created = <ParcelInput>[];
  final updated = <({String id, ParcelInput input})>[];
  int creates = 0;
  int updates = 0;
  int watchAllCalls = 0;
  int paymentRecords = 0;
  final payments = <String, List<Payment>>{};
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
  Future<void> update(String id, ParcelInput input) async {
    updates++;
    await gate?.future;
    if (failure != null) throw failure!;
    final index = _parcels.indexWhere((p) => p.id == id);
    if (index < 0) throw const AppFailure('This parcel no longer exists.');
    final old = _parcels[index];
    updated.add((id: id, input: input));
    _parcels[index] = testParcel(
      id: id,
      sequence: old.orderSequence,
      customerName: input.customer.name,
      customerPhone: input.customer.phone,
      customerAddress: input.customer.address,
      method: input.method,
      service: input.service,
      otherName: input.otherServiceName,
      reference: input.postalReference.trim(),
      charge: input.deliveryChargePaisa,
      packedGrams: input.packedWeightGrams,
      sendingDate: old.sendingDate,
      payDate: input.estimatedPaymentDate,
      status: input.status,
      items: input.items,
    );
    _changes.add(null);
  }

  int _index(String parcelId) {
    final index = _parcels.indexWhere((p) => p.id == parcelId);
    if (index < 0) throw const AppFailure('This parcel no longer exists.');
    return index;
  }

  String get _today => pakistanDate(DateTime.now().toUtc());

  @override
  Future<void> recordPayment(String parcelId, {required int amountPaisa, required PaymentType type, String? note, String? receivedOn}) async {
    paymentRecords++;
    await gate?.future;
    if (failure != null) throw failure!;
    final cleanNote = collapseSpaces(note ?? '');
    final problem = paymentProblem(amountPaisa: amountPaisa, note: cleanNote);
    if (problem != null) throw AppFailure(problem);
    final index = _index(parcelId);
    final old = _parcels[index];
    if (receivedOn != null && receivedOn.compareTo(old.sendingDate) < 0) throw const AppFailure('The received date cannot be before the sending date.');
    if (old.method == CollectionMethod.giftFree) throw const AppFailure('A Gift / Free parcel has no payment to receive.');
    if (old.status == ParcelStatus.returned) throw const AppFailure("A returned parcel can't take payments.");
    if (amountPaisa > old.outstandingPaisa) throw const AppFailure('Cannot exceed outstanding amount.');
    _parcels[index] = _changed(old, received: old.receivedPaisa + amountPaisa);
    final when = receivedOn == null ? DateTime.now() : DateTime.parse('${receivedOn}T07:00:00Z');
    (payments[parcelId] ??= []).insert(0, Payment(id: 'pay-$paymentRecords', amountPaisa: amountPaisa, type: type, note: cleanNote.isEmpty ? null : cleanNote, receivedAt: when));
    _changes.add(null);
  }

  final returns = <({String id, String date, String? reason})>[];
  final notesSaved = <({String id, String notes})>[];
  final payDates = <({String id, String? date})>[];
  final corrections = <({String parcelId, String paymentId, int amount, String reason})>[];

  @override
  Future<void> markReturned(String parcelId, {required String date, String? reason}) async {
    await gate?.future;
    if (failure != null) throw failure!;
    final index = _index(parcelId);
    final old = _parcels[index];
    if (old.status != ParcelStatus.sent) throw const AppFailure('Only a Sent parcel can be marked as returned.');
    if (date.compareTo(old.sendingDate) < 0) throw const AppFailure('The returned date cannot be before the sending date.');
    final clean = collapseSpaces(reason ?? '');
    returns.add((id: parcelId, date: date, reason: clean.isEmpty ? null : clean));
    _parcels[index] = _changed(old,
        status: ParcelStatus.returned, returnedDate: date, returnReason: clean.isEmpty ? null : clean, review: old.receivedPaisa > 0 || old.outstandingPaisa > 0);
    _changes.add(null);
  }

  @override
  Future<void> setNotes(String parcelId, String notes) async {
    await gate?.future;
    if (failure != null) throw failure!;
    final index = _index(parcelId);
    if (notes.trim().length > 500) throw const AppFailure('Use at most 500 characters.');
    notesSaved.add((id: parcelId, notes: notes.trim()));
    _parcels[index] = _changed(_parcels[index], notes: notes.trim());
    _changes.add(null);
  }

  @override
  Future<void> setPayLaterDate(String parcelId, String? date) async {
    await gate?.future;
    if (failure != null) throw failure!;
    final index = _index(parcelId);
    final old = _parcels[index];
    if (date != null && date.compareTo(_today) < 0) throw const AppFailure('Choose today or a later date.');
    if (old.method != CollectionMethod.payLater) throw const AppFailure('Only a Pay Later parcel has a payment date.');
    payDates.add((id: parcelId, date: date));
    // `null` clears the date, so rebuild without _changed (which keeps the old one).
    _parcels[index] = testParcel(
      id: old.id,
      sequence: old.orderSequence,
      method: old.method,
      service: old.service,
      reference: old.postalReference,
      charge: old.deliveryChargePaisa,
      sendingDate: old.sendingDate,
      payDate: date,
      status: old.status,
      items: old.items,
      received: old.receivedPaisa,
      notes: old.notes,
    );
    _changes.add(null);
  }

  @override
  Future<void> correctPayment(String parcelId, String paymentId, {required int correctedAmountPaisa, required String reason}) async {
    await gate?.future;
    if (failure != null) throw failure!;
    final index = _index(parcelId);
    final old = _parcels[index];
    final list = payments[parcelId] ?? [];
    final original = list.where((p) => p.id == paymentId).firstOrNull;
    if (original == null) throw const AppFailure('This payment no longer exists.');
    if (list.any((p) => p.reversalOfPaymentId == paymentId)) throw const AppFailure('This payment was already corrected.');
    final clean = collapseSpaces(reason);
    if (clean.length < 5) throw const AppFailure('Give a reason (at least 5 characters).');
    if (correctedAmountPaisa == original.amountPaisa) throw const AppFailure('The corrected amount is the same as the payment.');
    final received = old.receivedPaisa - original.amountPaisa + correctedAmountPaisa;
    if (received > old.expectedPaisa) throw const AppFailure('The total received cannot exceed the order total.');
    corrections.add((parcelId: parcelId, paymentId: paymentId, amount: correctedAmountPaisa, reason: clean));
    _parcels[index] = _changed(old, received: received);
    final now = DateTime.now();
    list.insert(0, Payment(id: 'rev_$paymentId', amountPaisa: -original.amountPaisa, type: original.type, note: null, receivedAt: now, reversalOfPaymentId: paymentId, correctionReason: clean));
    if (correctedAmountPaisa > 0) {
      list.insert(0, Payment(id: 'cor_$paymentId', amountPaisa: correctedAmountPaisa, type: original.type, note: null, receivedAt: now, correctionOfPaymentId: paymentId));
    }
    payments[parcelId] = list;
    _changes.add(null);
  }

  @override
  Stream<List<Payment>> watchPayments(String parcelId) async* {
    yield List.of(payments[parcelId] ?? const []);
    await for (final _ in _changes.stream) {
      yield List.of(payments[parcelId] ?? const []);
    }
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
