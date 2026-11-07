import '../../../utils/text.dart';

enum SaleUnit {
  perPiece('per_piece', 'Per Piece'),
  perKg('per_kg', 'Per Kg');

  const SaleUnit(this.value, this.label);

  /// Value stored in Firestore.
  final String value;
  final String label;

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
String productNameKey(String name) => 'n_${Uri.encodeComponent(normalizeProductName(name).toLowerCase())}';
