import 'package:flutter/foundation.dart';
import '../../../utils/postal_reference.dart';
import '../../customers/domain/customer.dart';
import '../../products/domain/product.dart';
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

  bool get isPerKg => product?.saleUnit == SaleUnit.perKg;
}

/// State of the Add Parcel form and the rules that connect its fields.
class ParcelFormViewModel extends ChangeNotifier {
  ParcelFormViewModel() : items = [ItemDraft(0)];

  Customer? customer;
  CollectionMethod? method;
  PostalService? service;
  String otherServiceName = '';
  String reference = '';
  int? chargePaisa;
  int? packedGrams;
  String? payDate;
  final List<ItemDraft> items;

  int _nextKey = 1;
  bool _serviceChosenByUser = false;

  bool get isFree => method == CollectionMethod.giftFree;
  bool get canAddItem => items.length < maxParcelItems;

  /// Sent once the slip details are in (a valid reference and a delivery charge); otherwise a draft.
  ParcelStatus get status =>
      reference.trim().isNotEmpty && isValidPostalReference(reference) && chargePaisa != null ? ParcelStatus.sent : ParcelStatus.draft;

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
  int? lineTotalPaisa(ItemDraft item) => isFree ? null : _lineOrNull(item)?.lineTotalPaisa;

  bool get isDirty =>
      customer != null ||
      method != null ||
      reference.isNotEmpty ||
      chargePaisa != null ||
      packedGrams != null ||
      payDate != null ||
      items.any((i) => i.product != null || i.quantity != null || i.weightGrams != null || i.pricePaisa != null) ||
      items.length > 1;

  /// True when an earlier row already has the same product (only the repeat is flagged).
  bool isDuplicate(ItemDraft item) {
    final product = item.product;
    if (product == null) return false;
    return items.takeWhile((other) => other != item).any((other) => other.product?.id == product.id);
  }

  void setCustomer(Customer value) {
    customer = value;
    notifyListeners();
  }

  void setMethod(CollectionMethod value) {
    method = value;
    if (!_serviceChosenByUser) service = PostalService.defaultFor(value);
    if (value != CollectionMethod.payLater) payDate = null;
    notifyListeners();
  }

  void setService(PostalService value) {
    service = value;
    _serviceChosenByUser = true;
    if (value != PostalService.other) otherServiceName = '';
    notifyListeners();
  }

  void setOtherServiceName(String value) => otherServiceName = value;
  void setReference(String value) {
    reference = value;
    notifyListeners();
  }

  void setCharge(int? paisa) {
    chargePaisa = paisa;
    notifyListeners();
  }

  void setPackedWeight(int? grams) => packedGrams = grams;

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
    if (item.isPerKg) {
      final grams = item.weightGrams;
      if (grams == null || grams <= 0) return null;
      return ParcelItem.weight(productId: product.id, productName: product.name, weightGrams: grams, unitPricePaisa: price);
    }
    final pieces = item.quantity;
    if (pieces == null || pieces <= 0) return null;
    return ParcelItem.pieces(productId: product.id, productName: product.name, quantity: pieces, unitPricePaisa: price);
  }

  /// The validated-so-far input. Call only after the form's field validators passed.
  ParcelInput buildInput() {
    final lines = <ParcelItem>[];
    for (final item in items) {
      final product = item.product!;
      final price = isFree ? 0 : item.pricePaisa!;
      lines.add(
        item.isPerKg
            ? ParcelItem.weight(productId: product.id, productName: product.name, weightGrams: item.weightGrams!, unitPricePaisa: price)
            : ParcelItem.pieces(productId: product.id, productName: product.name, quantity: item.quantity!, unitPricePaisa: price),
      );
    }
    return ParcelInput(
      customer: customer!,
      items: lines,
      method: method!,
      service: service!,
      otherServiceName: service == PostalService.other ? otherServiceName : null,
      postalReference: reference,
      deliveryChargePaisa: chargePaisa,
      packedWeightGrams: packedGrams,
      estimatedPaymentDate: method == CollectionMethod.payLater ? payDate : null,
      status: status,
    );
  }
}
