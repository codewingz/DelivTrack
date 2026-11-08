import 'package:deliv_track/common_widgets/app_choice_field.dart';
import 'package:deliv_track/common_widgets/app_date_field.dart';
import 'package:deliv_track/common_widgets/app_select_field.dart';
import 'package:deliv_track/common_widgets/app_text_field.dart';
import 'package:deliv_track/utils/app_validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

void main() {
  group('AppValidators.quantity / postalReference', () {
    test('quantity and weight messages name the unit', () {
      expect(
        AppValidators.quantity('', unit: 'boxes'),
        'Enter the number of boxes',
      );
      expect(
        AppValidators.quantity('0', unit: 'boxes'),
        'Enter a whole number of boxes (1–99,999)',
      );
      expect(AppValidators.quantity('5', unit: 'boxes'), isNull);
      expect(
        AppValidators.weight('0', unit: 'litres', fieldName: 'Volume'),
        'Enter a valid volume in litres',
      );
      expect(
        AppValidators.weight(
          '',
          isRequired: true,
          fieldName: 'Volume',
          unit: 'litres',
        ),
        'Volume is required',
      );
      expect(
        AppValidators.weight('1.5', unit: 'litres', fieldName: 'Volume'),
        isNull,
      );
      expect(AppValidators.weight('0'), 'Enter a valid weight in kg');
    });

    test('quantity: whole number 1-99,999', () {
      expect(AppValidators.quantity(null), 'Enter the number of pieces');
      expect(AppValidators.quantity('  '), 'Enter the number of pieces');
      for (final bad in ['0', '00', '1.5', '-1', 'abc', '100000', '1 2']) {
        expect(
          AppValidators.quantity(bad),
          'Enter a whole number of pieces (1–99,999)',
          reason: bad,
        );
      }
      for (final ok in ['1', '7', '99999', ' 12 ']) {
        expect(AppValidators.quantity(ok), isNull, reason: ok);
      }
    });

    test('postal reference: optional unless required; then 5-30 of letters/digits/-/ (spaces ignored)', () {
      expect(AppValidators.postalReference(''), isNull);
      expect(
        AppValidators.postalReference('', isRequired: true),
        'Postal reference is required to mark as Sent',
      );
      expect(
        AppValidators.postalReference('ABCD'),
        'Use 5–30 letters or numbers (also - and /)',
      );
      expect(AppValidators.postalReference('vpp 12345'), isNull);
      expect(
        AppValidators.postalReference('A' * 31),
        'Use 5–30 letters or numbers (also - and /)',
      );
    });
  });

  group('AppTextField.integer', () {
    testWidgets('accepts digits only and at most 5', (t) async {
      final c = TextEditingController();
      await t.pumpWidget(_wrap(AppTextField.integer(controller: c)));
      await t.enterText(find.byType(TextFormField), '12ab.3-4567');
      expect(c.text, '12345');
      expect(find.text('Quantity (pieces) *'), findsOneWidget);
    });

    testWidgets('validates 0 and empty', (t) async {
      final key = GlobalKey<FormState>();
      final c = TextEditingController();
      await t.pumpWidget(
        _wrap(
          Form(
            key: key,
            child: AppTextField.integer(controller: c),
          ),
        ),
      );
      key.currentState!.validate();
      await t.pump();
      expect(find.text('Enter the number of pieces'), findsOneWidget);
      c.text = '0';
      key.currentState!.validate();
      await t.pump();
      expect(
        find.text('Enter a whole number of pieces (1–99,999)'),
        findsOneWidget,
      );
      c.text = '3';
      expect(key.currentState!.validate(), isTrue);
    });
  });

  group('AppTextField.reference', () {
    testWidgets('upper-case keyboard, limited characters and length', (
      t,
    ) async {
      final c = TextEditingController();
      await t.pumpWidget(_wrap(AppTextField.reference(controller: c)));
      expect(
        t.widget<EditableText>(find.byType(EditableText)).textCapitalization,
        TextCapitalization.characters,
      );
      await t.enterText(
        find.byType(TextFormField),
        'vpp#12_34/x-é ${'y' * 60}',
      );
      expect(c.text.length, 40);
      expect(RegExp(r'^[A-Za-z0-9 /-]+$').hasMatch(c.text), isTrue);
    });

    testWidgets('required variant shows the Sent message', (t) async {
      final key = GlobalKey<FormState>();
      await t.pumpWidget(
        _wrap(Form(key: key, child: AppTextField.reference(isRequired: true))),
      );
      key.currentState!.validate();
      await t.pump();
      expect(
        find.text('Postal reference is required to mark as Sent'),
        findsOneWidget,
      );
    });
  });

  group('AppSelectField', () {
    testWidgets(
      'shows the choice, calls onTap, and re-renders when the choice changes',
      (t) async {
        String? chosen;
        var taps = 0;
        late StateSetter setOuter;
        await t.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (context, setState) {
                setOuter = setState;
                return AppSelectField(
                  label: 'Customer',
                  hint: 'Select a customer',
                  displayText: chosen,
                  onTap: () => taps++,
                  isRequired: true,
                );
              },
            ),
          ),
        );
        expect(find.text('Select a customer'), findsOneWidget);
        await t.tap(find.byType(TextFormField));
        expect(taps, 1);
        expect(
          t.widget<TextFormField>(find.byType(TextFormField)).enabled,
          isTrue,
        );

        setOuter(() => chosen = 'Ali Raza');
        await t.pump();
        expect(find.text('Ali Raza'), findsOneWidget);
      },
    );

    testWidgets('does not open a keyboard and validates through the caller', (
      t,
    ) async {
      final key = GlobalKey<FormState>();
      await t.pumpWidget(
        _wrap(
          Form(
            key: key,
            child: AppSelectField(
              label: 'Customer',
              hint: 'Select',
              displayText: null,
              onTap: () {},
              validator: () => 'Select a customer',
            ),
          ),
        ),
      );
      expect(
        t.widget<EditableText>(find.byType(EditableText)).readOnly,
        isTrue,
      );
      expect(key.currentState!.validate(), isFalse);
      await t.pump();
      expect(find.text('Select a customer'), findsOneWidget);
    });

    testWidgets('disabled field ignores taps', (t) async {
      var taps = 0;
      await t.pumpWidget(
        _wrap(
          AppSelectField(
            label: 'Customer',
            hint: 'Select',
            displayText: null,
            onTap: () => taps++,
            enabled: false,
          ),
        ),
      );
      await t.tap(find.byType(TextFormField), warnIfMissed: false);
      expect(taps, 0);
    });
  });

  group('AppDateField', () {
    Widget field({String? value, required ValueChanged<String?> onChanged}) =>
        AppDateField(
          label: 'Estimated payment date',
          value: value,
          onChanged: onChanged,
          firstDate: '2026-11-07',
          lastDate: '2031-11-07',
        );

    testWidgets(
      'empty: shows the hint, no clear button; tapping opens the picker and returns yyyy-MM-dd',
      (t) async {
        String? result;
        await t.pumpWidget(_wrap(field(onChanged: (v) => result = v)));
        expect(find.byTooltip('Clear date'), findsNothing);
        await t.tap(find.byType(TextFormField));
        await t.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        await t.tap(find.text('OK'));
        await t.pumpAndSettle();
        expect(
          result,
          '2026-11-07',
          reason: 'the first selectable day is preselected',
        );
      },
    );

    testWidgets('with a value: shows it formatted, can be cleared', (t) async {
      String? result = 'unchanged';
      await t.pumpWidget(
        _wrap(field(value: '2026-12-25', onChanged: (v) => result = v)),
      );
      expect(find.text('25 Dec 2026'), findsOneWidget);
      await t.tap(find.byTooltip('Clear date'));
      expect(result, isNull);
    });

    testWidgets('cancelling the picker changes nothing', (t) async {
      var calls = 0;
      await t.pumpWidget(_wrap(field(onChanged: (_) => calls++)));
      await t.tap(find.byType(TextFormField));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(calls, 0);
    });

    testWidgets(
      'a value before the first day is clamped into range for the picker',
      (t) async {
        await t.pumpWidget(
          _wrap(field(value: '2020-01-01', onChanged: (_) {})),
        );
        await t.tap(find.byType(TextFormField));
        await t.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  });

  group('AppChoiceField', () {
    testWidgets(
      'a validation error disappears as soon as an option is chosen',
      (t) async {
        final key = GlobalKey<FormState>();
        await t.pumpWidget(
          _wrap(
            Form(
              key: key,
              child: AppChoiceField<String>(
                label: 'Parcel type',
                options: const [
                  (value: 'a', label: 'Alpha'),
                  (value: 'b', label: 'Beta'),
                ],
                onChanged: (_) {},
                validator: (value) =>
                    value == null ? 'Select a parcel type' : null,
              ),
            ),
          ),
        );
        expect(key.currentState!.validate(), isFalse);
        await t.pump();
        expect(find.text('Select a parcel type'), findsOneWidget);

        await t.tap(find.widgetWithText(ChoiceChip, 'Beta'));
        await t.pump();
        expect(
          find.text('Select a parcel type'),
          findsNothing,
          reason: 'the error must not outlive the fix',
        );
        expect(
          t
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Beta'))
              .selected,
          isTrue,
        );
      },
    );

    testWidgets(
      'no error is shown before the user has interacted or validated',
      (t) async {
        await t.pumpWidget(
          _wrap(
            Form(
              child: AppChoiceField<String>(
                label: 'Parcel type',
                options: const [(value: 'a', label: 'Alpha')],
                onChanged: (_) {},
                validator: (value) =>
                    value == null ? 'Select a parcel type' : null,
              ),
            ),
          ),
        );
        expect(find.text('Select a parcel type'), findsNothing);
      },
    );
  });
}
