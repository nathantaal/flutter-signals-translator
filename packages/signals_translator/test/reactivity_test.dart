import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals_flutter.dart';
import 'package:signals_translator/signals_translator.dart';
import 'package:translator_conformance/translator_conformance.dart';

Widget _wrap(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

Widget _hello() => SignalBuilder(builder: (_) => Text(tl('hello')));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockTranslationAssets({
      'assets/translations/en.json': kHelloEn,
      'assets/translations/en_GB.json': kHelloEn,
      'assets/translations/nl.json': kHelloNl,
      'shared/en.json': kHelloEn,
    });
    SignalTranslator.debugReset();
  });

  tearDown(clearTranslationAssets);

  test(
    'a native effect re-runs on every locale switch (nl → en → nl)',
    () async {
      final translator = SignalTranslator();
      final seen = <String>[];
      final dispose = effect(() {
        seen.add(tl('hello'));
      });
      await translator.loadLocale('nl');
      await translator.loadLocale('en');
      await translator.loadLocale('nl');
      dispose();
      expect(seen.where((s) => s != 'hello'), ['Hallo', 'Hello', 'Hallo']);
    },
  );

  test('a native effect tracks activeAssetPath', () async {
    final translator = SignalTranslator();
    final seen = <String?>[];
    final dispose = effect(() {
      seen.add(translator.activeAssetPath);
    });
    await translator.loadLocale('nl');
    await translator.loadLocale('en');
    translator.translationsPath = 'shared';
    await translator.loadLocale('en');
    dispose();
    expect(seen.whereType<String>(), [
      'assets/translations/nl.json',
      'assets/translations/en.json',
      'shared/en.json',
    ]);
  });

  testWidgets('SignalBuilder rebuilds when the locale changes', (tester) async {
    await tester.pumpWidget(_wrap(_hello()));
    expect(find.text('hello'), findsOneWidget);
    await tester.runAsync(() => SignalTranslator().loadLocale('nl'));
    await tester.pump();
    expect(find.text('Hallo'), findsOneWidget);
  });

  testWidgets('state survives after the last rebuild widget unmounts', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_hello()));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => SignalTranslator().loadLocale('nl'));
    await tester.pumpWidget(_wrap(_hello()));
    expect(find.text('Hallo'), findsOneWidget);
    expect(SignalTranslator().activeAssetPath, 'assets/translations/nl.json');
  });
}
