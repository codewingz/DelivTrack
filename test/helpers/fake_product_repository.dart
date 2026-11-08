import 'dart:async';

import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/products/data/product_repository.dart';
import 'package:deliv_track/features/products/domain/product.dart';

/// In-memory repository that mirrors the real one's rules (unique names, archive instead of delete).
class FakeProductRepository implements ProductRepository {
  FakeProductRepository({List<Product> initial = const [], this.failure})
    : _items = [...initial];

  AppFailure? failure;
  Completer<void>? gate;
  final List<Product> _items;
  final _controller = StreamController<List<Product>>.broadcast();
  int _nextId = 1;
  int listeners = 0;
  int adds = 0;

  List<Product> get items => List.unmodifiable(_items);

  void emitError(Object error) => _controller.addError(error);

  void _emit() => _controller.add(_sorted());

  List<Product> _sorted() =>
      [..._items]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Stream<List<Product>> watchAll() async* {
    listeners++;
    yield _sorted();
    yield* _controller.stream;
  }

  Future<void> _guardCall() async {
    await gate?.future;
    if (failure != null) throw failure!;
  }

  bool _taken(String name, {String? exceptId}) => _items.any(
    (p) =>
        p.id != exceptId &&
        p.name.toLowerCase() == normalizeProductName(name).toLowerCase(),
  );

  @override
  Future<void> add({required String name, required SaleUnit saleUnit}) async {
    adds++;
    await _guardCall();
    if (_taken(name)) throw const AppFailure(duplicateProductMessage);
    _items.add(
      Product(
        id: 'p${_nextId++}',
        name: normalizeProductName(name),
        saleUnit: saleUnit,
        isActive: true,
      ),
    );
    _emit();
  }

  @override
  Future<void> update(
    String id, {
    required String name,
    required SaleUnit saleUnit,
  }) async {
    await _guardCall();
    if (_taken(name, exceptId: id)) {
      throw const AppFailure(duplicateProductMessage);
    }
    final i = _items.indexWhere((p) => p.id == id);
    _items[i] = Product(
      id: id,
      name: normalizeProductName(name),
      saleUnit: saleUnit,
      isActive: _items[i].isActive,
    );
    _emit();
  }

  @override
  Future<void> setActive(String id, bool isActive) async {
    await _guardCall();
    final i = _items.indexWhere((p) => p.id == id);
    final p = _items[i];
    _items[i] = Product(
      id: p.id,
      name: p.name,
      saleUnit: p.saleUnit,
      isActive: isActive,
    );
    _emit();
  }
}
