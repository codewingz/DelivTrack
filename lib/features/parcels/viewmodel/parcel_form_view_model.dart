import 'package:flutter/foundation.dart';

import '../../customers/domain/customer.dart';
import '../../products/domain/product.dart';
import '../domain/parcel.dart';
import '../domain/parcel_enums.dart';
import '../domain/parcel_input.dart';
import '../domain/parcel_item.dart';

/// One product line while the form is being filled in.
class ItemDraft {
  ItemDraft(this.key);

  /// Stable identity so a row keeps its text when other rows are added or removed.
  final int key;
  Product? product;
  int? quantity;
  int? weightGrams;
  int? pricePaisa;

  /// Kg or litre: a decimal amount instead of a whole number of pieces, boxes...
  bool get isMeasured => product?.saleUnit.isMeasured ?? false;
}

/// State of the Add Parcel form and the rules that connect its fields.
class ParcelFormViewModel extends ChangeNotifier {
  ParcelFormViewModel() : parcel = null, items = [ItemDraft(0)] {
    _initialSignature = _signature();
  }

  /// Prefills the form from a saved parcel (edit mode).
  ParcelFormViewModel.fromParcel(Parcel saved)
    : parcel = saved,
      customer = Customer(
        id: saved.customerId,
        name: saved.customerName,
        phone: saved.customerPhone,
        address: saved.customerAddress,
      ),
      method = saved.method,
      reference = saved.postalReference,
      chargePaisa = saved.deliveryChargePaisa,
      packedGrams = saved.packedWeightGrams,
      payDate = saved.estimatedPaymentDate,
      items = [
        for (var i = 0; i < saved.items.length; i++)
          ItemDraft(i)
            ..product = Product(
              id: saved.items[i].productId,
              name: saved.items[i].productName,
              saleUnit: saved.items[i].saleUnit,
              isActive: true,
            )
            ..quantity = saved.items[i].quantity
            ..weightGrams = saved.items[i].weightGrams
            ..pricePaisa =
                saved.items[i].unitPricePaisa == 0 &&
                    saved.method == CollectionMethod.giftFree
                ? null
                : saved.items[i].unitPricePaisa,
      ] {
    _nextKey = saved.items.length;
    _initialSignature = _signature();
  }

  /// The parcel being edited, or null when adding.
  final Parcel? parcel;
  bool get isEditing => parcel != null;

  Customer? customer;
  CollectionMethod? method;
  String reference = '';
  int? chargePaisa;
  int? packedGrams;
  String? payDate;
  final List<ItemDraft> items;

  int _nextKey = 1;
  late final String _initialSignature;

  bool get isFree => method == CollectionMethod.giftFree;
  bool get canAddItem => items.length < maxParcelItems;

  /// A new parcel is always a Draft; handing it over to the post office (a separate step) makes it Sent.
  /// Editing keeps the status the parcel already has.
  ParcelStatus get status => parcel?.status ?? ParcelStatus.draft;

  /// Total of the lines that are complete so far (0 for gift parcels).
  int get totalPaisa {
    if (isFree) return 0;
    var sum = 0;
    for (final item in items) {
      final line = _lineOrNull(item);
      if (line != null) sum += line.lineTotalPaisa;
    }
    return sum;
  }

  /// "Line total" shown under a row once product, amount and price are filled in.
  int? lineTotalPaisa(ItemDraft item) =>
      isFree ? null : _lineOrNull(item)?.lineTotalPaisa;

  /// True once anything differs from how the form started (empty, or the saved parcel).
  bool get isDirty => _signature() != _initialSignature;

  String _signature() => [
    customer?.id,
    method,
    payDate,
    [
      for (final i in items)
        [i.product?.id, i.quantity, i.weightGrams, i.pricePaisa],
    ],
  ].toString();

  /// True when an earlier row already has the same product (only the repeat is flagged).
  bool isDuplicate(ItemDraft item) {
    final product = item.product;
    if (product == null) return false;
    return items
        .takeWhile((other) => other != item)
        .any((other) => other.product?.id == product.id);
  }

  void setCustomer(Customer value) {
    customer = value;
    notifyListeners();
  }

  void setMethod(CollectionMethod value) {
    method = value;
    if (value != CollectionMethod.payLater) payDate = null;
    notifyListeners();
  }

  void setPayDate(String? value) {
    payDate = value;
    notifyListeners();
  }

  void addItem() {
    if (!canAddItem) return;
    items.add(ItemDraft(_nextKey++));
    notifyListeners();
  }

  void removeItem(ItemDraft item) {
    if (items.length == 1) return;
    items.remove(item);
    notifyListeners();
  }

  /// Choosing a product with another unit discards the amount typed for the previous one.
  void setProduct(ItemDraft item, Product product) {
    if (item.product?.saleUnit != product.saleUnit) {
      item.quantity = null;
      item.weightGrams = null;
    }
    item.product = product;
    notifyListeners();
  }

  void setQuantity(ItemDraft item, int? value) {
    item.quantity = value;
    notifyListeners();
  }

  void setWeight(ItemDraft item, int? grams) {
    item.weightGrams = grams;
    notifyListeners();
  }

  void setPrice(ItemDraft item, int? paisa) {
    item.pricePaisa = paisa;
    notifyListeners();
  }

  ParcelItem? _lineOrNull(ItemDraft item) {
    final product = item.product;
    final price = item.pricePaisa;
    if (product == null || price == null) return null;
    if (item.isMeasured) {
      final grams = item.weightGrams;
      if (grams == null || grams <= 0) return null;
      return ParcelItem.weight(
        productId: product.id,
        productName: product.name,
        weightGrams: grams,
        unitPricePaisa: price,
        saleUnit: product.saleUnit,
      );
    }
    final pieces = item.quantity;
    if (pieces == null || pieces <= 0) return null;
    return ParcelItem.pieces(
      productId: product.id,
      productName: product.name,
      quantity: pieces,
      unitPricePaisa: price,
      saleUnit: product.saleUnit,
    );
  }

  /// The validated-so-far input. Call only after the form's field validators passed.
  ParcelInput buildInput() {
    final lines = <ParcelItem>[];
    for (final item in items) {
      final product = item.product!;
      final price = isFree ? 0 : item.pricePaisa!;
      lines.add(
        item.isMeasured
            ? ParcelItem.weight(
                productId: product.id,
                productName: product.name,
                weightGrams: item.weightGrams!,
                unitPricePaisa: price,
                saleUnit: product.saleUnit,
              )
            : ParcelItem.pieces(
                productId: product.id,
                productName: product.name,
                quantity: item.quantity!,
                unitPricePaisa: price,
                saleUnit: product.saleUnit,
              ),
      );
    }
    return ParcelInput(
      customer: customer!,
      items: lines,
      method: method!,
      postalReference: reference,
      deliveryChargePaisa: chargePaisa,
      packedWeightGrams: packedGrams,
      estimatedPaymentDate: method == CollectionMethod.payLater
          ? payDate
          : null,
      status: status,
    );
  }
}
