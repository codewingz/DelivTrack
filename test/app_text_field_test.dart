import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliv_track/common_widgets/app_text_field.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: child,
        ),
      ),
    );
  }

  group('AppTextField tests', () {
    testWidgets('Email field validates invalid email and passes valid email', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();

      await tester.pumpWidget(
        buildTestableWidget(
          Form(
            key: formKey,
            child: AppTextField.email(
              controller: controller,
            ),
          ),
        ),
      );

      // Verify label and required asterisk
      expect(find.text('Email Address *'), findsOneWidget);

      // Empty submission
      formKey.currentState!.validate();
      await tester.pumpAndSettle();
      expect(find.text('Email address is required'), findsOneWidget);

      // Invalid email
      controller.text = 'invalid-email';
      formKey.currentState!.validate();
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address'), findsOneWidget);

      // Valid email
      controller.text = 'admin@codewingz.com';
      formKey.currentState!.validate();
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address'), findsNothing);
    });

    testWidgets('Password field obscures text, toggles visibility, and validates length', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();

      await tester.pumpWidget(
        buildTestableWidget(
          Form(
            key: formKey,
            child: AppTextField.password(
              controller: controller,
            ),
          ),
        ),
      );

      // Check eye icon toggle
      final toggleButton = find.byType(IconButton);
      expect(toggleButton, findsOneWidget);

      // Short password validation
      controller.text = '123';
      formKey.currentState!.validate();
      await tester.pumpAndSettle();
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);

      // Valid password
      controller.text = 'secret123';
      formKey.currentState!.validate();
      await tester.pumpAndSettle();
      expect(find.text('Password must be at least 6 characters'), findsNothing);

      // Tap toggle to unmask password
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('Amount field enforces number format and Rs. prefix', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();

      await tester.pumpWidget(
        buildTestableWidget(
          Form(
            key: formKey,
            child: AppTextField.amount(
              controller: controller,
              minPaisa: 10000,
            ),
          ),
        ),
      );

      expect(find.text('Rs. '), findsOneWidget);

      controller.text = '50';
      formKey.currentState!.validate();
      await tester.pumpAndSettle();
      expect(find.text('Minimum amount is Rs. 100'), findsOneWidget);

      controller.text = '250.50';
      formKey.currentState!.validate();
      await tester.pumpAndSettle();
      expect(find.text('Minimum amount is Rs. 100'), findsNothing);
    });

    testWidgets('Weight field displays kg suffix and validates positive weight', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();

      await tester.pumpWidget(
        buildTestableWidget(
          Form(
            key: formKey,
            child: AppTextField.weight(
              controller: controller,
              isRequired: true,
            ),
          ),
        ),
      );

      expect(find.text('kg'), findsOneWidget);

      controller.text = '0';
      formKey.currentState!.validate();
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid weight in kg'), findsOneWidget);

      controller.text = '2.5';
      formKey.currentState!.validate();
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid weight in kg'), findsNothing);
    });
  });
}

