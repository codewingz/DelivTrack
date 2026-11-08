/// Tracking number as compared for uniqueness: no spaces, upper case.
String normalizePostalReference(String raw) =>
    raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();

/// Letters, digits, "-" and "/" only, 5-30 characters after normalizing.
bool isValidPostalReference(String raw) =>
    RegExp(r'^[A-Z0-9/-]{5,30}$').hasMatch(normalizePostalReference(raw));
