import 'package:url_launcher/url_launcher.dart';

/// Opens the phone's dialer with a number filled in (the user still presses call).
abstract class PhoneDialer {
  /// True when a dialer was opened.
  Future<bool> dial(String phone);
}

class UrlLauncherDialer implements PhoneDialer {
  const UrlLauncherDialer();

  @override
  Future<bool> dial(String phone) async {
    // Only the digits and a leading + go into the link; anything else typed in the number is dropped.
    final number = phone.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    if (number.isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: number);
    try {
      return await launchUrl(uri);
    } on Object {
      return false;
    }
  }
}

/// Does nothing (tests).
class NoPhoneDialer implements PhoneDialer {
  const NoPhoneDialer();

  @override
  Future<bool> dial(String phone) async => false;
}
