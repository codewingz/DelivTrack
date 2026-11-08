import 'package:flutter_test/flutter_test.dart';

/// The Home greeting depends on the time of day ("Good morning, Ali"), so tests match any of the three.
Finder greetingWith(String firstName) => find.textContaining(
  RegExp('^Good (morning|afternoon|evening), $firstName\$'),
);

Finder get greetingWithoutName =>
    find.textContaining(RegExp(r'^Good (morning|afternoon|evening)$'));
