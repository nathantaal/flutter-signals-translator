import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_translator_example/icu_example_screen.dart';

void main() {
  test('every locale offered by the example defines all keys from en.json', () {
    Set<String> keysOf(String locale) {
      final json =
          jsonDecode(
                File('assets/translations/$locale.json').readAsStringSync(),
              )
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
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: IcuExampleScreen()));

    expect(find.text('Plural + variable — search_results'), findsOneWidget);
    expect(find.textContaining(r'\"'), findsNothing);
  });
}
