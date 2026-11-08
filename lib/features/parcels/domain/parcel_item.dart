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

  /// A counted line: [quantity] pieces (or boxes, dozens...) at [unitPricePaisa] each.
  factory ParcelItem.pieces({
    required String productId,
    required String productName,
    required int quantity,
    required int unitPricePaisa,
    SaleUnit saleUnit = SaleUnit.perPiece,
  }) => ParcelItem._(
    productId: productId,
    productName: productName,
    saleUnit: saleUnit,
    quantity: quantity,
    weightGrams: null,
    unitPricePaisa: unitPricePaisa,
    lineTotalPaisa: pieceLineTotalPaisa(
      quantity: quantity,
      unitPricePaisa: unitPricePaisa,
    ),
  );

  /// A measured line: [weightGrams] (thousandths of a kg or litre) at [unitPricePaisa] per unit.
  factory ParcelItem.weight({
    required String productId,
    required String productName,
    required int weightGrams,
    required int unitPricePaisa,
    SaleUnit saleUnit = SaleUnit.perKg,
  }) => ParcelItem._(
    productId: productId,
    productName: productName,
    saleUnit: saleUnit,
    quantity: null,
    weightGrams: weightGrams,
    unitPricePaisa: unitPricePaisa,
    lineTotalPaisa: weightLineTotalPaisa(
      grams: weightGrams,
      pricePerKgPaisa: unitPricePaisa,
    ),
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

  /// Whole number of pieces, boxes, dozens... (counted lines only).
  final int? quantity;

  /// Thousandths of a kg or litre (measured lines only; the name is from when kg was the only one).
  final int? weightGrams;

  /// Price per piece, box, kg, litre... in paisa.
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

  /// "3 pieces", "2 boxes", "1.25 kg" or "1 litre".
  String get amountLabel => saleUnit.isMeasured
      ? formatMeasure(
          weightGrams!,
          weightGrams == 1000 ? saleUnit.singular : saleUnit.plural,
        )
      : '$quantity ${quantity == 1 ? saleUnit.singular : saleUnit.plural}';

  /// "each" for pieces, otherwise "per box", "per kg"...
  String get priceLabel =>
      saleUnit == SaleUnit.perPiece ? 'each' : 'per ${saleUnit.singular}';
}
