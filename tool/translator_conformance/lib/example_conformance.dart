// This library is a test suite shared by every example, so it uses
// test-only members by design.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Binds the example suite to one example app.
class ExampleHarness {
  const ExampleHarness({
    required this.buildApp,
    required this.buildIcuScreen,
    required this.resetTranslator,
  });

  final Widget Function() buildApp;
  final Widget Function() buildIcuScreen;
  final void Function() resetTranslator;
}

// The shared example_translations package, relative to an example directory
// (packages/<adapter>/example), which is the working directory of
// `flutter test`.
const _translationsDir =
    '../../../tool/example_translations/assets/translations';
const _bundledPath = 'packages/example_translations/assets/translations';

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 8000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Lets real asset loads and SharedPreferences writes complete, then
/// settles the frame.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

void runExampleConformance(ExampleHarness h) {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    h.resetTranslator();
  });

  test('every locale offered by the example defines all keys from en.json', () {
    Set<String> keysOf(String locale) {
      final json =
          jsonDecode(File('$_translationsDir/$locale.json').readAsStringSync())
              as Map<String, dynamic>;
      return (json['translations'] as Map<String, dynamic>).keys.toSet();
    }

    final reference = keysOf('en');
    for (final locale in ['en_GB', 'nl', 'es']) {
      expect(
        reference.difference(keysOf(locale)),
        isEmpty,
        reason: '$locale.json is missing keys that en.json defines',
      );
    }
  });

  testWidgets('search_results subtitle shows the key without escape '
      'backslashes', (tester) async {
    _tallView(tester);
    await tester.pumpWidget(MaterialApp(home: h.buildIcuScreen()));
    expect(find.text('Plural + variable — search_results'), findsOneWidget);
    expect(find.textContaining(r'\"'), findsNothing);
  });

  testWidgets('ICU screen reacts to language and counter changes', (
    tester,
  ) async {
    _tallView(tester);
    await tester.pumpWidget(MaterialApp(home: h.buildIcuScreen()));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Dutch'));
    await _settle(tester);
    expect(find.text('ICU-voorbeelden'), findsOneWidget);
    expect(
      find.text('Je hebt geen berichten in je inbox.'),
      findsAtLeastNWidgets(1),
    );

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    expect(
      find.text('Je hebt 1 bericht in je inbox.'),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('home screen switches language from the dropdown', (
    tester,
  ) async {
    _tallView(tester);
    await tester.pumpWidget(h.buildApp());
    await _settle(tester);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dutch').last);
    await _settle(tester);

    expect(find.text('Nederlands'), findsOneWidget);
    expect(find.text('Current locale: nl'), findsOneWidget);
    expect(find.text('Active asset: $_bundledPath/nl.json'), findsOneWidget);
  });
}
