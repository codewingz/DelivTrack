import '../../../core/money/money.dart';
import '../../products/domain/product.dart';

/// One product line of a parcel: an immutable snapshot of the product and the agreed price.
class ParcelItem {
  const ParcelItem._({
    required this.productId,
    required this.productName,
    required this.saleUnit,
    required this.quantity,
    required this.weightGrams,
    required this.unitPricePaisa,
    required this.lineTotalPaisa,
  });

  /// A per-piece line: [quantity] pieces at [unitPricePaisa] each.
  factory ParcelItem.pieces({
    required String productId,
    required String productName,
    required int quantity,
    required int unitPricePaisa,
  }) =>
      ParcelItem._(
        productId: productId,
        productName: productName,
        saleUnit: SaleUnit.perPiece,
        quantity: quantity,
        weightGrams: null,
        unitPricePaisa: unitPricePaisa,
        lineTotalPaisa: pieceLineTotalPaisa(quantity: quantity, unitPricePaisa: unitPricePaisa),
      );

  /// A per-kg line: [weightGrams] at [unitPricePaisa] per kg.
  factory ParcelItem.weight({
    required String productId,
    required String productName,
    required int weightGrams,
    required int unitPricePaisa,
  }) =>
      ParcelItem._(
        productId: productId,
        productName: productName,
        saleUnit: SaleUnit.perKg,
        quantity: null,
        weightGrams: weightGrams,
        unitPricePaisa: unitPricePaisa,
        lineTotalPaisa: weightLineTotalPaisa(grams: weightGrams, pricePerKgPaisa: unitPricePaisa),
      );

  factory ParcelItem.fromMap(Map<String, dynamic> map) {
    final unit = SaleUnit.fromValue(map['saleUnit'] as String);
    return ParcelItem._(
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      saleUnit: unit,
      quantity: map['quantity'] as int?,
      weightGrams: map['weightGrams'] as int?,
      unitPricePaisa: map['unitPricePaisa'] as int,
      lineTotalPaisa: map['lineTotalPaisa'] as int,
    );
  }

  final String productId;
  final String productName;
  final SaleUnit saleUnit;

  /// Pieces (per-piece lines only).
  final int? quantity;

  /// Grams (per-kg lines only).
  final int? weightGrams;

  /// Price per piece, or per kg, in paisa.
  final int unitPricePaisa;
  final int lineTotalPaisa;

  Map<String, Object> toMap() => {
        'productId': productId,
        'productName': productName,
        'saleUnit': saleUnit.value,
        'quantity': ?quantity,
        'weightGrams': ?weightGrams,
        'unitPricePaisa': unitPricePaisa,
        'lineTotalPaisa': lineTotalPaisa,
      };

  /// "3 pieces" or "1.25 kg".
  String get amountLabel => saleUnit == SaleUnit.perPiece ? '$quantity ${quantity == 1 ? 'piece' : 'pieces'}' : formatKg(weightGrams!);
}
