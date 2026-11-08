import 'package:flutter/services.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

import '../../../core/errors/app_failure.dart';

/// A name and one phone number the user chose from the phone's contacts.
class PickedContact {
  const PickedContact({required this.name, required this.phone});
  final String name;
  final String phone;
}

/// Lets the user choose a contact's phone number from the phone's own contact list.
abstract class ContactPicker {
  /// The chosen contact, or null when the user backed out. Throws [AppFailure] when the contact list
  /// can't be opened (the caller then tells the user to type the number).
  Future<PickedContact?> pick();
}

/// The Android system contact picker. The app never reads the address book: the picker hands back only
/// the one contact the user taps, so no contacts permission is declared or asked for.
class SystemContactPicker implements ContactPicker {
  const SystemContactPicker();

  @override
  Future<PickedContact?> pick() async {
    try {
      final contact = await FlutterNativeContactPicker().selectPhoneNumber();
      final phone =
          contact?.selectedPhoneNumber ?? contact?.phoneNumbers?.firstOrNull;
      if (contact == null || phone == null || phone.trim().isEmpty) return null;
      return PickedContact(name: contact.fullName ?? '', phone: phone);
    } on PlatformException {
      throw const AppFailure(
        "Couldn't open your contacts. Type the number instead.",
      );
    }
  }
}

/// Offers no contacts (tests).
class NoContactPicker implements ContactPicker {
  const NoContactPicker();

  @override
  Future<PickedContact?> pick() async => null;
}
