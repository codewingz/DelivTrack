import '../../../utils/text.dart';

/// How a unit is counted: whole numbers, or a decimal amount (up to 3 places).
enum UnitKind { count, measure }

/// How a product is sold. Count units are saved as a whole `quantity`; measured units (kg, litre)
/// are saved in `weightGrams` as thousandths of the unit (1.25 kg or 1.25 L -> 1250).
/// The order here is the order of the dropdown.
enum SaleUnit {
  perPiece('per_piece', 'Per Piece', UnitKind.count, 'piece', 'pieces'),
  perKg('per_kg', 'Per Kg', UnitKind.measure, 'kg', 'kg'),
  perLitre('per_litre', 'Per Litre', UnitKind.measure, 'litre', 'litres'),
  perDozen('per_dozen', 'Per Dozen', UnitKind.count, 'dozen', 'dozen'),
  perPack('per_pack', 'Per Pack', UnitKind.count, 'pack', 'packs'),
  perBox('per_box', 'Per Box', UnitKind.count, 'box', 'boxes'),
  perCarton('per_carton', 'Per Carton', UnitKind.count, 'carton', 'cartons'),
  perBag('per_bag', 'Per Bag', UnitKind.count, 'bag', 'bags'),
  perBottle('per_bottle', 'Per Bottle', UnitKind.count, 'bottle', 'bottles'),
  perJar('per_jar', 'Per Jar', UnitKind.count, 'jar', 'jars'),
  perTin('per_tin', 'Per Tin', UnitKind.count, 'tin', 'tins');

  const SaleUnit(this.value, this.label, this.kind, this.singular, this.plural);

  /// Value stored in Firestore.
  final String value;
  final String label;
  final UnitKind kind;

  /// "box" / "boxes"; for measured units the unit itself: "kg" / "kg", "litre" / "litres".
  final String singular;
  final String plural;

  bool get isMeasured => kind == UnitKind.measure;

  static SaleUnit fromValue(String value) => SaleUnit.values.firstWhere(
    (unit) => unit.value == value,
    orElse: () => throw StateError('Unknown sale unit "$value"'),
  );
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.saleUnit,
    required this.isActive,
  });

  final String id;
  final String name;
  final SaleUnit saleUnit;
  final bool isActive;
}

/// Trims and collapses inner whitespace. Names are saved in this form.
String normalizeProductName(String raw) => collapseSpaces(raw);

/// Firestore document id of the uniqueness guard for [name] (case-insensitive).
String productNameKey(String name) =>
    'n_${Uri.encodeComponent(normalizeProductName(name).toLowerCase())}';
