import '../core/money/money.dart';
import 'phone.dart';
import 'text.dart';

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

  /// Validates a person or item name: required, 2-60 characters after trimming and
  /// collapsing inner whitespace.
  static String? name(String? value, {String fieldName = 'Name'}) {
    final normalized = collapseSpaces(value ?? '');
    if (normalized.isEmpty) return '$fieldName is required';
    if (normalized.length < 2 || normalized.length > 60) return 'Use 2–60 characters';
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

  /// Validates a money amount in rupees (up to 2 decimals). Bounds are in paisa.
  static String? amount(
    String? value, {
    bool isRequired = true,
    String fieldName = 'Amount',
    int minPaisa = 0,
    int maxPaisa = maxMoneyPaisa,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return isRequired ? '$fieldName is required' : null;
    }
    final paisa = parseRupeesToPaisa(trimmed);
    if (paisa == null) return 'Enter a valid amount';
    if (paisa < minPaisa) return minPaisa <= 1 ? 'Enter an amount above zero' : 'Minimum amount is ${formatRupees(minPaisa)}';
    if (paisa > maxPaisa) return 'Maximum amount is ${formatRupees(maxPaisa)}';
    return null;
  }

  /// Validates a weight in kilograms (up to 3 decimals, above zero, at most 9,999.999).
  static String? weight(String? value, {bool isRequired = false, String fieldName = 'Weight'}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return isRequired ? '$fieldName is required' : null;
    }
    final grams = parseKgToGrams(trimmed);
    if (grams == null || grams <= 0) return 'Enter a valid weight in kg';
    return null;
  }

  /// Validates a phone number (see [isValidPhone]).
  static String? phone(String? value, {bool isRequired = true}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return isRequired ? 'Phone number is required' : null;
    }
    return isValidPhone(trimmed) ? null : 'Enter a valid phone number';
  }

  /// Validates a full address: required, 5-200 characters after trimming.
  static String? address(String? value, {String fieldName = 'Address'}) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return '$fieldName is required';
    if (trimmed.length < 5 || trimmed.length > 200) return 'Enter the full address (5–200 characters)';
    return null;
  }
}

