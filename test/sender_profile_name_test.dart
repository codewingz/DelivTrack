import 'package:deliv_track/features/settings/domain/sender_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = SenderProfile(
    name: 'Ali Raza',
    businessName: 'Ali Collection',
    phone: '0300 1234567',
    address: 'Shop 12, Lahore',
  );

  test('customers see the business name by default', () {
    expect(base.customerFacingName, 'Ali Collection');
    expect(base.toMap().containsKey('preferSenderName'), isFalse);
  });

  test('the owner can choose the sender name instead', () {
    final chosen = base.copyWith(preferSenderName: true);
    expect(chosen.customerFacingName, 'Ali Raza');
    expect(chosen.toMap()['preferSenderName'], true);
    expect(SenderProfile.fromMap(chosen.toMap()), chosen);
  });

  test('without a business name the sender name is used either way', () {
    const noBusiness = SenderProfile(
      name: 'Ali Raza',
      phone: '0300 1234567',
      address: 'Shop 12, Lahore',
    );
    expect(noBusiness.customerFacingName, 'Ali Raza');
    expect(const SenderProfile.empty().customerFacingName, '');
  });

  test('messages, invoices and labels are chosen separately', () {
    final mixed = base.copyWith(labelUsesSenderName: true);
    expect(mixed.customerFacingName, 'Ali Collection');
    expect(mixed.invoiceName, 'Ali Collection');
    expect(mixed.labelName, 'Ali Raza');
    expect(mixed.toMap()['labelUsesSenderName'], true);
    expect(mixed.toMap().containsKey('invoiceUsesSenderName'), isFalse);
    expect(SenderProfile.fromMap(mixed.toMap()), mixed);
  });
}
