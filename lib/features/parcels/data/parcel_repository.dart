import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/data/changed_keys.dart';
import '../../../core/errors/firestore_failure.dart';
import '../../../core/ids/order_number.dart';
import '../../../core/money/money.dart';
import '../../../core/time/pakistan_time.dart';
import '../../../utils/text.dart';
import '../domain/parcel.dart';
import '../domain/parcel_enums.dart';
import '../domain/parcel_input.dart';
import '../domain/payment.dart';
import '../domain/payment_rules.dart';
import '../../../utils/postal_reference.dart';

abstract class ParcelRepository {
  /// All of the signed-in user's parcels, newest first. Archived parcels are left out unless
  /// [includeArchived] is set: archiving is organisational, so money totals use the full list while
  /// counts and lists use the active parcels.
  Stream<List<Parcel>> watchAll({bool includeArchived = false});

  /// The archived parcels, newest first.
  Stream<List<Parcel>> watchArchived();

  /// Ids of stored parcels that can't be read (damaged or unknown values). They are left out of every
  /// list and total, so the app shows a notice with these ids instead of failing as a whole.
  Stream<List<String>> watchUnreadable();

  /// Hides a parcel that has nothing left to chase (a draft, a returned parcel, or one that owes
  /// nothing). Its order number stays reserved; [restore] brings it back. Throws [AppFailure].
  Future<void> archive(String parcelId);

  /// Brings an archived parcel back to the lists.
  Future<void> restore(String parcelId);

  /// One parcel, or null if it does not exist.
  Stream<Parcel?> watch(String id);

  /// Creates the parcel with the next order number. Returns the new parcel's id.
  /// Throws [AppFailure] (invalid input, reference already used, no connection...).
  Future<String> create(ParcelInput input);

  /// Edits an existing parcel. The order number, sending date and creation time never change;
  /// payments already received are kept. Writes an audit-log entry with the changed fields.
  /// Throws [AppFailure] (not found, reference already used, no connection...).
  Future<void> update(String id, ParcelInput input);

  /// A parcel's payments, newest first.
  Stream<List<Payment>> watchPayments(String parcelId);

  /// The Pakistan dates ("yyyy-MM-dd") on which each parcel received money. Payments that were
  /// reversed by a correction do not count. Parcels without payments are left out of the result.
  Future<Map<String, Set<String>>> paymentDates(Iterable<String> parcelIds);

  /// Every payment (and reversal) of each parcel, newest first. Parcels without payments are left out.
  Future<Map<String, List<Payment>>> paymentsFor(Iterable<String> parcelIds);

  /// Records a payment and moves the parcel's received / outstanding / payment status in one
  /// transaction. Throws [AppFailure] (amount not above 0 or above the outstanding balance, Gift / Free
  /// or returned parcel, note too long, no connection...).
  ///
  /// [receivedOn] ("yyyy-MM-dd", Pakistan date) records a payment that arrived earlier: not in the
  /// future and not before the sending date. Without it the payment is stamped with the server time.
  Future<void> recordPayment(
    String parcelId, {
    required int amountPaisa,
    required PaymentType type,
    String? note,
    String? receivedOn,
  });

  /// Marks a Sent parcel as returned on [date] ("yyyy-MM-dd"). Nothing is refunded automatically:
  /// a parcel that received or still owes money is flagged for payment review.
  Future<void> markReturned(
    String parcelId, {
    required String date,
    String? reason,
  });

  /// Completes a returned parcel's payment review: records how it was settled ([resolution]), a required
  /// [note] (5-200 characters) and the [date] of the decision. Nothing is refunded, adjusted or deleted:
  /// the payment history is untouched, and any refund is a separate matter outside the app.
  Future<void> completePaymentReview(
    String parcelId, {
    required ReviewResolution resolution,
    required String note,
    required String date,
  });

  /// Saves the parcel's notes (at most 500 characters); empty removes them.
  Future<void> setNotes(String parcelId, String notes);

  /// Changes or clears (null) a Pay Later parcel's estimated payment date. A date must be today or later.
  Future<void> setPayLaterDate(String parcelId, String? date);

  /// Corrects a payment without editing it: a negative twin cancels it and, when [correctedAmountPaisa]
  /// is above 0, a replacement payment is recorded, all in one transaction. [reason] is required.
  ///
  /// The replacement keeps the original "received on" date unless [receivedOn] ("yyyy-MM-dd", not in the
  /// future, not before the sending date) names a new one, so the amount, the date or both can be fixed.
  /// The original payment, the reversal (with the reason and when it was made) and the replacement all
  /// stay in the history.
  Future<void> correctPayment(
    String parcelId,
    String paymentId, {
    required int correctedAmountPaisa,
    required String reason,
    String? receivedOn,
  });
}

/// Data lives under `users/{uid}/parcels`; Firestore rules allow only that user.
///
/// * Order numbers come from `users/{uid}/counters/orders`, read and bumped in the same
///   transaction that writes the parcel, so two saves can never share a number.
/// * A postal reference may be used once per service: `users/{uid}/postal_refs/{key}` guard
///   documents are written in the same transaction.
class FirestoreParcelRepository implements ParcelRepository {
  FirestoreParcelRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this.clock = const Clock(),
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Clock clock;

  DocumentReference<Map<String, dynamic>> get _userDoc {
    final user = _auth.currentUser;
    if (user == null) throw const AppFailure('Please log in again.');
    return _firestore.collection('users').doc(user.uid);
  }

  CollectionReference<Map<String, dynamic>> get _parcels =>
      _userDoc.collection('parcels');
  DocumentReference<Map<String, dynamic>> get _counter =>
      _userDoc.collection('counters').doc('orders');

  /// Guard document for a service + reference ("Other" services are told apart by their name).
  DocumentReference<Map<String, dynamic>> _guard(
    PostalService service,
    String? otherName,
    String normalizedReference,
  ) {
    final serviceKey = service == PostalService.other
        ? 'Other-${collapseSpaces(otherName ?? '').toLowerCase()}'
        : service.value;
    return _userDoc
        .collection('postal_refs')
        .doc(
          '${Uri.encodeComponent(serviceKey)}__${Uri.encodeComponent(normalizedReference)}',
        );
  }

  @override
  Stream<List<Parcel>> watchAll({bool includeArchived = false}) =>
      _watchParcels(archived: includeArchived ? null : false);

  @override
  Stream<List<Parcel>> watchArchived() => _watchParcels(archived: true);

  Stream<List<Parcel>> _watchParcels({required bool? archived}) => _parcels
      .orderBy('orderSequence', descending: true)
      .snapshots()
      .map(
        (snapshot) => [
          for (final parcel in _read(snapshot).parcels)
            if (archived == null || parcel.isArchived == archived) parcel,
        ],
      )
      .withFirestoreFailures();

  @override
  Stream<List<String>> watchUnreadable() => _parcels
      .snapshots()
      .map((snapshot) => _read(snapshot).unreadableIds)
      .withFirestoreFailures();

  ({List<Parcel> parcels, List<String> unreadableIds}) _read(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final result = Parcel.readAll([
      for (final doc in snapshot.docs) MapEntry(doc.id, doc.data()),
    ]);
    // Remember what each parcel's payment history looked like, so cached payments can be checked.
    for (final parcel in result.parcels) {
      _paymentSignatures[parcel.id] = parcel.paymentsSignature;
    }
    return result;
  }

  // Payments already read in this session. An entry is used only while the parcel's signature (received
  // money + last payment id) is the one the entry was read under; any payment or correction changes it.
  // Bounded, and keyed by user so accounts never share entries.
  final _paymentSignatures = <String, String>{};
  final _paymentCache =
      <String, ({String signature, List<Payment> payments})>{};
  static const _maxCachedParcels = 5000;

  /// Diagnostic counter: how many payment sub-collections were read from Firestore (the rest came from the cache).
  int paymentQueries = 0;

  @override
  Stream<Parcel?> watch(String id) => _parcels
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? Parcel.fromMap(doc.id, doc.data()!) : null)
      .withFirestoreFailures();

  @override
  Future<String> create(ParcelInput input) async {
    final problems = input.problems(today: pakistanDate(clock.nowUtc()));
    if (problems.isNotEmpty) throw AppFailure(problems.first);

    try {
      final parcelRef = _parcels.doc();
      final normalizedReference = normalizePostalReference(
        input.postalReference,
      );
      final guard = normalizedReference.isEmpty
          ? null
          : _guard(input.service, input.otherServiceName, normalizedReference);

      return await _retryWhenDenied(
        () => _firestore.runTransaction((tx) async {
          final counter = await tx.get(_counter);
          final sequence =
              (counter.exists ? counter['lastSequence'] as int : 0) + 1;
          final orderNumber = formatOrderNumber(sequence);

          if (guard != null) {
            final existing = await tx.get(guard);
            if (existing.exists) {
              throw AppFailure(
                'This postal reference is already used on ${existing['orderNumber']}.',
              );
            }
          }

          tx.set(_counter, {'lastSequence': sequence});
          tx.set(
            parcelRef,
            _newParcelFields(
              input,
              orderNumber,
              sequence,
              normalizedReference,
              guard?.id,
            ),
          );
          if (guard != null) {
            tx.set(guard, {
              'parcelId': parcelRef.id,
              'orderNumber': orderNumber,
            });
          }
          return parcelRef.id;
        }),
      );
    } on FirebaseException catch (e) {
      throw firestoreFailure(e);
    }
  }

  static const _maxAttempts = 5;
  static final _jitter = Random();

  /// Two writes at the same moment both read the same document. The mobile SDK commits with an
  /// "unchanged since read" precondition, but Firestore checks the rules first, so the loser is
  /// answered "permission-denied" (not the retryable "aborted"). Verified against the real backend
  /// (5 parallel saves: one wins per round, all succeed within 5 attempts). So a denied attempt is
  /// retried a few times with a fresh read; a genuine denial fails the same way every time and is
  /// reported after the last attempt.
  Future<T> _retryWhenDenied<T>(Future<T> Function() attempt) async {
    for (var tries = 1; ; tries++) {
      try {
        return await attempt();
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied' || tries >= _maxAttempts) {
          throw firestoreFailure(e);
        }
        await Future<void>.delayed(
          Duration(milliseconds: 25 * tries + _jitter.nextInt(75)),
        );
      }
    }
  }

  @override
  Future<void> update(String id, ParcelInput input) async {
    final problems = input.problems();
    if (problems.isNotEmpty) throw AppFailure(problems.first);

    try {
      final parcelRef = _parcels.doc(id);
      final auditRef = _userDoc.collection('audit_logs').doc();
      final normalizedReference = normalizePostalReference(
        input.postalReference,
      );
      final newGuard = normalizedReference.isEmpty
          ? null
          : _guard(input.service, input.otherServiceName, normalizedReference);

      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(parcelRef);
        if (!snapshot.exists) {
          throw const AppFailure('This parcel no longer exists.');
        }
        final before = snapshot.data()!;
        _requireNotArchived(before);

        if (before['parcelStatus'] == ParcelStatus.returned.value) {
          throw const AppFailure("A returned parcel can't be edited.");
        }
        final received = before['receivedPaisa'] as int;
        final wasFree =
            before['collectionMethod'] == CollectionMethod.giftFree.value;
        final isFree = input.method == CollectionMethod.giftFree;
        if (received > 0 && wasFree != isFree) {
          throw const AppFailure(
            "The parcel type can't change between Gift / Free and a paid type after a payment was received.",
          );
        }

        final oldReference = before['postalReferenceNormalized'] as String;
        final oldGuard = oldReference.isEmpty
            ? null
            : _guard(
                PostalService.fromValue(before['postalServiceType'] as String),
                before['otherPostalServiceName'] as String?,
                oldReference,
              );

        if (newGuard != null && newGuard.path != oldGuard?.path) {
          final existing = await tx.get(newGuard);
          if (existing.exists) {
            throw AppFailure(
              'This postal reference is already used on ${existing['orderNumber']}.',
            );
          }
        }

        final expected = input.expectedPaisa;
        final updated = _editableFields(
          input,
          normalizedReference,
          expected,
          received,
          isFree,
        );
        // The guard document id is stored on the parcel; the rules tie the two together.
        if (newGuard?.path != oldGuard?.path) {
          updated['postalGuardId'] = newGuard?.id;
        }
        final changed = changedKeys(
          before,
          {...before, ...updated}..removeWhere((key, value) => value == null),
        );
        if (changed.isEmpty) return;

        if (oldGuard != null && oldGuard.path != newGuard?.path) {
          tx.delete(oldGuard);
        }
        if (newGuard != null && newGuard.path != oldGuard?.path) {
          tx.set(newGuard, {
            'parcelId': id,
            'orderNumber': before['orderNumber'],
          });
        }
        tx.update(parcelRef, {
          for (final entry in updated.entries)
            entry.key: entry.value ?? FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(auditRef, {
          'entityType': 'parcel',
          'entityId': id,
          'action': 'update',
          'orderNumber': before['orderNumber'],
          'changedFields': changed,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw firestoreFailure(e);
    }
  }

  @override
  Stream<List<Payment>> watchPayments(String parcelId) => _parcels
      .doc(parcelId)
      .collection('payments')
      .orderBy('receivedAt', descending: true)
      .snapshots()
      .map((snapshot) => [for (final doc in snapshot.docs) ?_paymentFrom(doc)])
      .withFirestoreFailures();

  @override
  Future<Map<String, List<Payment>>> paymentsFor(
    Iterable<String> parcelIds,
  ) async {
    final uid = _auth.currentUser?.uid;
    final result = <String, List<Payment>>{};
    final missing = <String>[];
    for (final id in parcelIds) {
      final signature = _paymentSignatures[id];
      final cached = _paymentCache['$uid/$id'];
      if (signature != null &&
          cached != null &&
          cached.signature == signature) {
        if (cached.payments.isNotEmpty) result[id] = List.of(cached.payments);
      } else {
        missing.add(id);
      }
    }
    try {
      // A few parcels at a time, so a long list does not open hundreds of requests at once.
      for (var start = 0; start < missing.length; start += 10) {
        final batch = missing.skip(start).take(10).toList();
        // The signature is taken before reading: if a payment lands meanwhile, the entry just reads as stale.
        final signatures = [for (final id in batch) _paymentSignatures[id]];
        paymentQueries += batch.length;
        final snapshots = await Future.wait([
          for (final id in batch)
            _parcels
                .doc(id)
                .collection('payments')
                .orderBy('receivedAt', descending: true)
                .get(),
        ]);
        for (final (index, snapshot) in snapshots.indexed) {
          final payments = [
            for (final doc in snapshot.docs) ?_paymentFrom(doc),
          ];
          final signature = signatures[index];
          if (signature != null) {
            if (_paymentCache.length >= _maxCachedParcels) {
              _paymentCache.clear();
            }
            _paymentCache['$uid/${batch[index]}'] = (
              signature: signature,
              payments: payments,
            );
          }
          if (payments.isNotEmpty) result[batch[index]] = payments;
        }
      }
    } on FirebaseException catch (e) {
      throw firestoreFailure(e);
    }
    return result;
  }

  @override
  Future<Map<String, Set<String>>> paymentDates(
    Iterable<String> parcelIds,
  ) async {
    final payments = await paymentsFor(parcelIds);
    return {
      for (final entry in payments.entries)
        if (_receivedDates(entry.value).isNotEmpty)
          entry.key: _receivedDates(entry.value),
    };
  }

  /// Pakistan dates of the payments that still count (a reversed payment does not).
  static Set<String> _receivedDates(List<Payment> payments) {
    final reversed = {
      for (final payment in payments) ?payment.reversalOfPaymentId,
    };
    return {
      for (final payment in payments)
        if (payment.amountPaisa > 0 && !reversed.contains(payment.id))
          pakistanDate(payment.receivedAt),
    };
  }

  /// A stored payment, or null when its document is damaged (it then counts for nothing, never as money).
  static Payment? _paymentFrom(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    try {
      return Payment(
        id: doc.id,
        amountPaisa: doc['amountPaisa'] as int,
        type: PaymentType.fromValue(doc['paymentType'] as String),
        note: doc.data()['note'] as String?,
        receivedAt: (doc['receivedAt'] as Timestamp).toDate(),
        reversalOfPaymentId: doc.data()['reversalOfPaymentId'] as String?,
        correctionReason: doc.data()['correctionReason'] as String?,
        correctionOfPaymentId: doc.data()['correctionOfPaymentId'] as String?,
      );
    } on TypeError {
      return null;
    } on StateError {
      return null;
    }
  }

  @override
  Future<void> recordPayment(
    String parcelId, {
    required int amountPaisa,
    required PaymentType type,
    String? note,
    String? receivedOn,
  }) async {
    final cleanNote = collapseSpaces(note ?? '');
    final problem = paymentProblem(amountPaisa: amountPaisa, note: cleanNote);
    if (problem != null) throw AppFailure(problem);
    final today = pakistanDate(clock.nowUtc());
    if (receivedOn != null && !_isDate(receivedOn)) {
      throw const AppFailure('Enter a valid date.');
    }
    if (receivedOn != null && receivedOn.compareTo(today) > 0) {
      throw const AppFailure('The received date cannot be in the future.');
    }

    final parcelRef = _parcels.doc(parcelId);
    final paymentRef = parcelRef.collection('payments').doc();
    try {
      await _retryWhenDenied(
        () => _firestore.runTransaction((tx) async {
          final snapshot = await tx.get(parcelRef);
          if (!snapshot.exists) {
            throw const AppFailure('This parcel no longer exists.');
          }
          final parcel = snapshot.data()!;
          _requireNotArchived(parcel);
          if (parcel['parcelStatus'] == ParcelStatus.returned.value) {
            throw const AppFailure("A returned parcel can't take payments.");
          }
          final isFree =
              parcel['collectionMethod'] == CollectionMethod.giftFree.value;
          if (isFree) {
            throw const AppFailure(
              'A Gift / Free parcel has no payment to receive.',
            );
          }

          if (receivedOn != null &&
              receivedOn.compareTo(parcel['sendingDateLocal'] as String) < 0) {
            throw AppFailure(
              'The received date cannot be before the sending date (${formatDate(parcel['sendingDateLocal'] as String)}).',
            );
          }

          final outstanding = parcel['outstandingPaisa'] as int;
          if (amountPaisa > outstanding) {
            throw AppFailure(
              'Cannot exceed outstanding ${formatRupees(outstanding)}.',
            );
          }

          final expected = parcel['productAmountExpectedPaisa'] as int;
          final received = (parcel['receivedPaisa'] as int) + amountPaisa;
          tx.update(parcelRef, {
            'receivedPaisa': received,
            'outstandingPaisa': outstandingFor(
              expectedPaisa: expected,
              receivedPaisa: received,
            ),
            'paymentStatus': paymentStatusFor(
              isFree: isFree,
              expectedPaisa: expected,
              receivedPaisa: received,
            ).value,
            'lastPaymentId': paymentRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.set(paymentRef, {
            'amountPaisa': amountPaisa,
            'paymentType': type.value,
            if (cleanNote.isNotEmpty) 'note': cleanNote,
            'receivedAt': receivedOn == null || receivedOn == today
                ? FieldValue.serverTimestamp()
                : _noonPakistan(receivedOn),
            'recordedAt': FieldValue.serverTimestamp(),
          });
        }),
      );
    } on FirebaseException catch (e) {
      throw firestoreFailure(e);
    }
  }

  static bool _isDate(String value) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);

  /// 12:00 Pakistan time of a "yyyy-MM-dd" date (07:00 UTC): a time that falls on that Pakistan day.
  static Timestamp _noonPakistan(String date) {
    final parts = date.split('-').map(int.parse).toList();
    return Timestamp.fromDate(DateTime.utc(parts[0], parts[1], parts[2], 7));
  }

  void _audit(
    Transaction tx,
    String action,
    String parcelId,
    String orderNumber,
    List<String> changedFields,
  ) {
    tx.set(_userDoc.collection('audit_logs').doc(), {
      'entityType': 'parcel',
      'entityId': parcelId,
      'action': action,
      'orderNumber': orderNumber,
      'changedFields': changedFields,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static void _requireNotArchived(Map<String, dynamic> parcel) {
    if (parcel['isArchived'] == true) {
      throw const AppFailure('This parcel is archived. Restore it first.');
    }
  }

  @override
  Future<void> archive(String parcelId) =>
      _setArchived(parcelId, archived: true);

  @override
  Future<void> restore(String parcelId) =>
      _setArchived(parcelId, archived: false);

  Future<void> _setArchived(String parcelId, {required bool archived}) async {
    final parcelRef = _parcels.doc(parcelId);
    try {
      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(parcelRef);
        if (!snapshot.exists) {
          throw const AppFailure('This parcel no longer exists.');
        }
        final parcel = snapshot.data()!;
        final isArchived = parcel['isArchived'] == true;
        if (isArchived == archived) return;
        if (archived &&
            parcel['parcelStatus'] == ParcelStatus.sent.value &&
            (parcel['outstandingPaisa'] as int) > 0) {
          throw const AppFailure(
            "A parcel that still has money to collect can't be archived.",
          );
        }
        if (archived && parcel['paymentReviewRequired'] == true) {
          throw const AppFailure(
            "A parcel can't be archived until its payment review is completed.",
          );
        }
        tx.update(parcelRef, {
          'isArchived': archived ? true : FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _audit(
          tx,
          archived ? 'archive' : 'restore',
          parcelId,
          parcel['orderNumber'] as String,
          ['isArchived'],
        );
      });
    } on FirebaseException catch (e) {
      throw firestoreFailure(e);
    }
  }

  @override
  Future<void> markReturned(
    String parcelId, {
    required String date,
    String? reason,
  }) async {
    final cleanReason = collapseSpaces(reason ?? '');
    final today = pakistanDate(clock.nowUtc());
    if (!_isDate(date)) throw const AppFailure('Enter a valid date.');
    if (date.compareTo(today) > 0) {
      throw const AppFailure('The returned date cannot be in the future.');
    }
    if (cleanReason.length > 200) {
      throw const AppFailure('Use at most 200 characters.');
    }

    final parcelRef = _parcels.doc(parcelId);
    try {
      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(parcelRef);
        if (!snapshot.exists) {
          throw const AppFailure('This parcel no longer exists.');
        }
        final parcel = snapshot.data()!;
        _requireNotArchived(parcel);
        if (parcel['parcelStatus'] != ParcelStatus.sent.value) {
          throw const AppFailure(
            'Only a Sent parcel can be marked as returned.',
          );
        }
        final sending = parcel['sendingDateLocal'] as String;
        if (date.compareTo(sending) < 0) {
          throw AppFailure(
            'The returned date cannot be before the sending date (${formatDate(sending)}).',
          );
        }

        final needsReview =
            (parcel['receivedPaisa'] as int) > 0 ||
            (parcel['outstandingPaisa'] as int) > 0;
        tx.update(parcelRef, {
          'parcelStatus': ParcelStatus.returned.value,
          'returnedDateLocal': date,
          if (cleanReason.isNotEmpty) 'returnReason': cleanReason,
          'paymentReviewRequired': needsReview,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _audit(tx, 'return', parcelId, parcel['orderNumber'] as String, [
          'parcelStatus',
          'returnedDateLocal',
          if (cleanReason.isNotEmpty) 'returnReason',
          'paymentReviewRequired',
        ]);
      });
    } on FirebaseException catch (e) {
      throw firestoreFailure(e);
    }
  }

  @override
  Future<void> completePaymentReview(
    String parcelId, {
    required ReviewResolution resolution,
    required String note,
    required String date,
  }) async {
    final cleanNote = collapseSpaces(note);
    final today = pakistanDate(clock.nowUtc());
    if (cleanNote.length < 5) {
      throw const AppFailure('Write a note (at least 5 characters).');
    }
    if (cleanNote.length > 200) {
      throw const AppFailure('Use at most 200 characters.');
    }
    if (!_isDate(date)) throw const AppFailure('Enter a valid date.');
    if (date.compareTo(today) > 0) {
      throw const AppFailure('The date cannot be in the future.');
    }

    final parcelRef = _parcels.doc(parcelId);
    try {
      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(parcelRef);
        if (!snapshot.exists) {
          throw const AppFailure('This parcel no longer exists.');
        }
        final parcel = snapshot.data()!;
        _requireNotArchived(parcel);
        if (parcel['paymentReviewRequired'] != true) {
          throw const AppFailure(
            'This parcel has no payment review to complete.',
          );
        }
        final returned = parcel['returnedDateLocal'] as String;
        if (date.compareTo(returned) < 0) {
          throw AppFailure(
            'The date cannot be before the returned date (${formatDate(returned)}).',
          );
        }

        tx.update(parcelRef, {
          'paymentReviewRequired': false,
          'paymentReviewReason': resolution.value,
          'paymentReviewNote': cleanNote,
          'paymentReviewDateLocal': date,
          'paymentReviewResolvedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _audit(
          tx,
          'resolve_review',
          parcelId,
          parcel['orderNumber'] as String,
          [
            'paymentReviewRequired',
            'paymentReviewReason',
            'paymentReviewNote',
            'paymentReviewDateLocal',
          ],
        );
      });
    } on FirebaseException catch (e) {
      throw firestoreFailure(e);
    }
  }

  @override
  Future<void> setNotes(String parcelId, String notes) async {
    final clean = notes.trim();
    if (clean.length > 500) {
      throw const AppFailure('Use at most 500 characters.');
    }
    final parcelRef = _parcels.doc(parcelId);
    try {
      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(parcelRef);
        if (!snapshot.exists) {
          throw const AppFailure('This parcel no longer exists.');
        }
        final parcel = snapshot.data()!;
        _requireNotArchived(parcel);
        if ((parcel['notes'] as String? ?? '') == clean) return;
        tx.update(parcelRef, {
          'notes': clean.isEmpty ? FieldValue.delete() : clean,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _audit(tx, 'update', parcelId, parcel['orderNumber'] as String, [
          'notes',
        ]);
      });
    } on FirebaseException catch (e) {
      throw firestoreFailure(e);
    }
  }

  @override
  Future<void> setPayLaterDate(String parcelId, String? date) async {
    if (date != null && !_isDate(date)) {
      throw const AppFailure('Enter a valid date.');
    }
    if (date != null && date.compareTo(pakistanDate(clock.nowUtc())) < 0) {
      throw const AppFailure('Choose today or a later date.');
    }
    final parcelRef = _parcels.doc(parcelId);
    try {
      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(parcelRef);
        if (!snapshot.exists) {
          throw const AppFailure('This parcel no longer exists.');
        }
        final parcel = snapshot.data()!;
        _requireNotArchived(parcel);
        if (parcel['collectionMethod'] != CollectionMethod.payLater.value) {
          throw const AppFailure('Only a Pay Later parcel has a payment date.');
        }
        if (parcel['parcelStatus'] == ParcelStatus.returned.value) {
          throw const AppFailure("A returned parcel's date can't be changed.");
        }
        if ((parcel['outstandingPaisa'] as int) == 0) {
          throw const AppFailure('Nothing is outstanding on this parcel.');
        }
        if (parcel['estimatedPaymentDateLocal'] == date) return;
        tx.update(parcelRef, {
          'estimatedPaymentDateLocal': date ?? FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _audit(tx, 'update', parcelId, parcel['orderNumber'] as String, [
          'estimatedPaymentDateLocal',
        ]);
      });
    } on FirebaseException catch (e) {
      throw firestoreFailure(e);
    }
  }

  @override
  Future<void> correctPayment(
    String parcelId,
    String paymentId, {
    required int correctedAmountPaisa,
    required String reason,
    String? receivedOn,
  }) async {
    final cleanReason = collapseSpaces(reason);
    if (cleanReason.length < 5) {
      throw const AppFailure('Give a reason (at least 5 characters).');
    }
    if (cleanReason.length > 200) {
      throw const AppFailure('Use at most 200 characters.');
    }
    if (correctedAmountPaisa < 0) {
      throw const AppFailure('Enter a valid amount.');
    }
    final today = pakistanDate(clock.nowUtc());
    if (receivedOn != null && !_isDate(receivedOn)) {
      throw const AppFailure('Enter a valid date.');
    }
    if (receivedOn != null && receivedOn.compareTo(today) > 0) {
      throw const AppFailure('The received date cannot be in the future.');
    }

    final parcelRef = _parcels.doc(parcelId);
    final originalRef = parcelRef.collection('payments').doc(paymentId);
    final reversalRef = parcelRef.collection('payments').doc('rev_$paymentId');
    final replacementRef = parcelRef
        .collection('payments')
        .doc('cor_$paymentId');
    try {
      await _retryWhenDenied(
        () => _firestore.runTransaction((tx) async {
          final snapshot = await tx.get(parcelRef);
          if (!snapshot.exists) {
            throw const AppFailure('This parcel no longer exists.');
          }
          final parcel = snapshot.data()!;
          _requireNotArchived(parcel);
          if (parcel['parcelStatus'] == ParcelStatus.returned.value) {
            throw const AppFailure(
              "A returned parcel's payments can't be corrected.",
            );
          }

          final original = await tx.get(originalRef);
          if (!original.exists) {
            throw const AppFailure('This payment no longer exists.');
          }
          final originalAmount = original['amountPaisa'] as int;
          if (originalAmount <= 0) {
            throw const AppFailure("A correction can't be corrected.");
          }
          if ((await tx.get(reversalRef)).exists) {
            throw const AppFailure('This payment was already corrected.');
          }
          final originalAt = original['receivedAt'] as Timestamp;
          final originalDate = pakistanDate(originalAt.toDate());
          final newDate = receivedOn ?? originalDate;
          if (correctedAmountPaisa == originalAmount &&
              newDate == originalDate) {
            throw const AppFailure(
              'Change the amount or the date: the correction is the same as the payment.',
            );
          }
          if (correctedAmountPaisa > 0 &&
              newDate.compareTo(parcel['sendingDateLocal'] as String) < 0) {
            throw AppFailure(
              'The received date cannot be before the sending date (${formatDate(parcel['sendingDateLocal'] as String)}).',
            );
          }

          final expected = parcel['productAmountExpectedPaisa'] as int;
          final received =
              (parcel['receivedPaisa'] as int) -
              originalAmount +
              correctedAmountPaisa;
          if (received > expected) {
            throw AppFailure(
              'The total received cannot exceed ${formatRupees(expected)}.',
            );
          }

          final isFree =
              parcel['collectionMethod'] == CollectionMethod.giftFree.value;
          final outstanding = outstandingFor(
            expectedPaisa: expected,
            receivedPaisa: received,
          );
          final status = paymentStatusFor(
            isFree: isFree,
            expectedPaisa: expected,
            receivedPaisa: received,
          ).value;
          tx.update(parcelRef, {
            'receivedPaisa': received,
            'outstandingPaisa': outstanding,
            'paymentStatus': status,
            'lastPaymentId': reversalRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          final type = original['paymentType'] as String;
          tx.set(reversalRef, {
            'amountPaisa': -originalAmount,
            'paymentType': type,
            'reversalOfPaymentId': paymentId,
            'correctionReason': cleanReason,
            'replacementPaisa': correctedAmountPaisa,
            'correctedBy': _auth.currentUser!.uid,
            'receivedAt': FieldValue.serverTimestamp(),
            'recordedAt': FieldValue.serverTimestamp(),
          });
          if (correctedAmountPaisa > 0) {
            tx.set(replacementRef, {
              'amountPaisa': correctedAmountPaisa,
              'paymentType': type,
              'correctionOfPaymentId': paymentId,
              // the original day is kept unless a new one was chosen; today uses the server's clock
              'receivedAt': receivedOn == null
                  ? originalAt
                  : (receivedOn == today
                        ? FieldValue.serverTimestamp()
                        : _noonPakistan(receivedOn)),
              'recordedAt': FieldValue.serverTimestamp(),
            });
          }
          // only the fields that really changed (a date-only correction moves no money)
          _audit(
            tx,
            'correct_payment',
            parcelId,
            parcel['orderNumber'] as String,
            [
              'lastPaymentId',
              if (received != parcel['receivedPaisa']) 'receivedPaisa',
              if (outstanding != parcel['outstandingPaisa']) 'outstandingPaisa',
              if (status != parcel['paymentStatus']) 'paymentStatus',
            ],
          );
        }),
      );
    } on FirebaseException catch (e) {
      throw firestoreFailure(e);
    }
  }

  /// The fields an edit may change. A null value means "remove this optional field".
  Map<String, Object?> _editableFields(
    ParcelInput input,
    String normalizedReference,
    int expected,
    int received,
    bool isFree,
  ) => {
    'customerId': input.customer.id,
    'customerSnapshot': {
      'name': input.customer.name,
      'phone': input.customer.phone,
      'address': input.customer.address,
    },
    'items': [for (final item in input.items) item.toMap()],
    'collectionMethod': input.method.value,
    'postalServiceType': input.service.value,
    'otherPostalServiceName': input.service == PostalService.other
        ? collapseSpaces(input.otherServiceName ?? '')
        : null,
    'postalReference': input.postalReference.trim(),
    'postalReferenceNormalized': normalizedReference,
    'deliveryChargePaisa': input.deliveryChargePaisa,
    'actualPackedWeightGrams': input.packedWeightGrams,
    'estimatedPaymentDateLocal': input.estimatedPaymentDate,
    'productAmountExpectedPaisa': expected,
    'outstandingPaisa': outstandingFor(
      expectedPaisa: expected,
      receivedPaisa: received,
    ),
    'paymentStatus': paymentStatusFor(
      isFree: isFree,
      expectedPaisa: expected,
      receivedPaisa: received,
    ).value,
    'parcelStatus': input.status.value,
  };

  Map<String, Object> _newParcelFields(
    ParcelInput input,
    String orderNumber,
    int sequence,
    String normalizedReference,
    String? guardId,
  ) {
    final isFree = input.method == CollectionMethod.giftFree;
    final expected = input.expectedPaisa;
    return {
      'orderNumber': orderNumber,
      'orderSequence': sequence,
      'customerId': input.customer.id,
      'customerSnapshot': {
        'name': input.customer.name,
        'phone': input.customer.phone,
        'address': input.customer.address,
      },
      'items': [for (final item in input.items) item.toMap()],
      'collectionMethod': input.method.value,
      'postalServiceType': input.service.value,
      'otherPostalServiceName': ?(input.service == PostalService.other
          ? collapseSpaces(input.otherServiceName ?? '')
          : null),
      'postalReference': input.postalReference.trim(),
      'postalReferenceNormalized': normalizedReference,
      'postalGuardId': ?guardId,
      'deliveryChargePaisa': ?input.deliveryChargePaisa,
      'actualPackedWeightGrams': ?input.packedWeightGrams,
      'estimatedPaymentDateLocal': ?input.estimatedPaymentDate,
      'productAmountExpectedPaisa': expected,
      'receivedPaisa': 0,
      'outstandingPaisa': expected,
      'paymentStatus':
          (isFree ? PaymentStatus.notRequired : PaymentStatus.pending).value,
      'parcelStatus': input.status.value,
      'sendingDateLocal': pakistanDate(clock.nowUtc()),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
