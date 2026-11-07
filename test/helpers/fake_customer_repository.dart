import 'dart:async';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/customers/data/customer_repository.dart';
import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/utils/phone.dart';
import 'package:deliv_track/utils/text.dart';

/// In-memory repository mirroring the real one (sorted by name, phone lookup by normalized digits).
class FakeCustomerRepository implements CustomerRepository {
  FakeCustomerRepository({List<Customer> initial = const [], this.failure}) : _items = [...initial];

  AppFailure? failure;
  Completer<void>? gate;
  final List<Customer> _items;
  final _controller = StreamController<List<Customer>>.broadcast();
  int _nextId = 1;
  int adds = 0;
  int updates = 0;

  /// How many times a list screen subscribed to the live list.
  int subscriptions = 0;

  List<Customer> get items => List.unmodifiable(_items);

  void removeAll() => _items.clear();

  void resetSubscriptions() => subscriptions = 0;

  void emitError(Object error) => _controller.addError(error);

  List<Customer> _sorted() => [..._items]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Stream<List<Customer>> watchAll() async* {
    subscriptions++;
    yield _sorted();
    yield* _controller.stream;
  }

  Future<void> _guardCall() async {
    await gate?.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<Customer?> findByPhone(String phone, {String? excludeId}) async {
    await _guardCall();
    final wanted = normalizePhone(phone);
    for (final c in _items) {
      if (c.id != excludeId && c.phoneNormalized == wanted) return c;
    }
    return null;
  }

  @override
  Future<String> add({required String name, required String phone, required String address}) async {
    adds++;
    await _guardCall();
    final id = 'new-c${_nextId++}';
    _items.add(Customer(id: id, name: collapseSpaces(name), phone: phone.trim(), address: address.trim()));
    _controller.add(_sorted());
    return id;
  }

  @override
  Future<void> update(String id, {required String name, required String phone, required String address}) async {
    updates++;
    await _guardCall();
    final i = _items.indexWhere((c) => c.id == id);
    _items[i] = Customer(id: id, name: collapseSpaces(name), phone: phone.trim(), address: address.trim());
    _controller.add(_sorted());
  }
}
