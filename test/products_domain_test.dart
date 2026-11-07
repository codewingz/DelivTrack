import 'package:deliv_track/features/products/domain/product.dart';
import 'package:deliv_track/utils/app_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeProductName / productNameKey', () {
    test('trims and collapses whitespace', () {
      expect(normalizeProductName('  Raw   Mango \n Box '), 'Raw Mango Box');
    });

    test('key is case-insensitive and whitespace-insensitive', () {
      expect(productNameKey('Mango Box'), productNameKey('  mango   BOX '));
      expect(productNameKey('Mango Box'), isNot(productNameKey('Mango Boxes')));
    });

    test('key is a legal Firestore id even for slashes and dots', () {
      for (final name in ['a/b', '..', 'A.B', 'آم کا ڈبہ', 'x' * 60]) {
        final key = productNameKey(name);
        expect(key.contains('/'), isFalse, reason: name);
        expect(key.startsWith('n_'), isTrue);
        expect(key.length, lessThan(1500));
      }
    });
  });

  group('SaleUnit', () {
    test('round-trips stored values and rejects unknown ones', () {
      expect(SaleUnit.fromValue('per_piece'), SaleUnit.perPiece);
      expect(SaleUnit.fromValue('per_kg'), SaleUnit.perKg);
      expect(() => SaleUnit.fromValue('per_box'), throwsStateError);
    });
  });

  group('AppValidators.name', () {
    test('required, length 2-60 after normalizing', () {
      expect(AppValidators.name(null, fieldName: 'Product name'), 'Product name is required');
      expect(AppValidators.name('   ', fieldName: 'Product name'), 'Product name is required');
      expect(AppValidators.name('A'), 'Use 2–60 characters');
      expect(AppValidators.name('  A  '), 'Use 2–60 characters');
      expect(AppValidators.name('Ab'), isNull);
      expect(AppValidators.name('x' * 60), isNull);
      expect(AppValidators.name('x' * 61), 'Use 2–60 characters');
    });

    test('inner whitespace runs count once', () {
      expect(AppValidators.name('A${' ' * 100}B'), isNull);
    });
  });
}
