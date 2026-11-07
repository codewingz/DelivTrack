/// Centralized validation logic for DelivTrack.
/// Reusable across FormFields, Controllers, and business logic.
class AppValidators {
  AppValidators._();

  /// Validates required fields with a customizable field name or message.
  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates email address format and optional emptiness check.
  static String? email(String? value, {bool isRequired = true}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return isRequired ? 'Email address is required' : null;
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
    );
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Validates password with minimum length (default 6 for Firebase Auth).
  static String? password(String? value, {bool isRequired = true, int minLength = 6}) {
    final val = value ?? '';
    if (val.isEmpty) {
      return isRequired ? 'Password is required' : null;
    }
    if (val.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    return null;
  }

  /// Validates that a confirmation field equals [original].
  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  /// Validates numeric currency / payment amounts.
  static String? amount(
    String? value, {
    bool isRequired = true,
    double? min,
    double? max,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return isRequired ? 'Amount is required' : null;
    }

    final numVal = double.tryParse(trimmed);
    if (numVal == null) {
      return 'Enter a valid amount';
    }
    if (min != null && numVal < min) {
      return 'Minimum amount is Rs. $min';
    }
    if (max != null && numVal > max) {
      return 'Maximum amount is Rs. $max';
    }
    return null;
  }

  /// Validates weight in kilograms.
  static String? weight(String? value, {bool isRequired = false}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return isRequired ? 'Weight is required' : null;
    }

    final numVal = double.tryParse(trimmed);
    if (numVal == null || numVal <= 0) {
      return 'Enter a valid weight in kg';
    }
    return null;
  }

  /// Validates Pakistan and international mobile phone numbers.
  static String? phone(String? value, {bool isRequired = true}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return isRequired ? 'Phone number is required' : null;
    }

    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 10) {
      return 'Enter a valid phone number (at least 10 digits)';
    }
    return null;
  }
}

