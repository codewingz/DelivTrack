/// Trims and collapses runs of whitespace to a single space.
String collapseSpaces(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');
