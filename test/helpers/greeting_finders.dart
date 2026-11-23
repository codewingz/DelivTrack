import 'package:flutter_test/flutter_test.dart';

/// The Home greeting depends on the time of day ("Good morning, Ali Khan": the full name; on a phone the name is on its own line), so tests match any of the three.
Finder greetingWith(String name) => find.textContaining(
  RegExp('^Good (morning|afternoon|evening),[ \n]$name\$'),
);

Finder get greetingWithoutName =>
    find.textContaining(RegExp(r'^Good (morning|afternoon|evening)$'));
