import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart'
    show SignalBuilder, Effect;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solidart_translator/solidart_translator.dart';
import 'package:translator_conformance/translator_conformance.dart';

Widget _wrap(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

Widget _hello() => SignalBuilder(builder: (_, _) => Text(tl('hello')));

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockTranslationAssets({
      'assets/translations/en.json': kHelloEn,
      'assets/translations/en_GB.json': kHelloEn,
      'assets/translations/nl.json': kHelloNl,
    });
    SignalTranslator.debugReset();
  });

  tearDown(clearTranslationAssets);

  test(
    'a native effect re-runs on every locale switch (nl → en → nl)',
    () async {
      final translator = SignalTranslator();
      final seen = <String>[];
      final dispose = Effect(() {
        seen.add(tl('hello'));
      });
      await translator.loadLocale('nl');
      await translator.loadLocale('en');
      await translator.loadLocale('nl');
      dispose();
      expect(seen.where((s) => s != 'hello'), ['Hallo', 'Hello', 'Hallo']);
    },
  );

  test('assetLocationString follows loadLocale', () async {
    final translator = SignalTranslator();
    await translator.loadLocale('nl');
    expect(translator.assetLocationString.value, 'assets/translations/nl.json');
  });

  test('assetLocationString follows the OS locale in sys mode', () async {
    binding.platformDispatcher.localeTestValue = const Locale('nl');
    addTearDown(binding.platformDispatcher.clearLocaleTestValue);
    SignalTranslator.debugReset();
    final translator = SignalTranslator();
    await translator.loadLocale('sys');
    expect(translator.assetLocationString.value, 'assets/translations/nl.json');

    binding.platformDispatcher.localeTestValue = const Locale('en', 'GB');
    translator.didChangeLocales(const [Locale('en', 'GB')]);
    expect(
      translator.assetLocationString.value,
      'assets/translations/en_GB.json',
    );
  });

  testWidgets(
    'flutter_solidart SignalBuilder rebuilds when the locale changes',
    (tester) async {
      await tester.pumpWidget(_wrap(_hello()));
      expect(find.text('hello'), findsOneWidget);
      await tester.runAsync(() => SignalTranslator().loadLocale('nl'));
      await tester.pump();
      expect(find.text('Hallo'), findsOneWidget);
    },
  );

  testWidgets('state survives after the last rebuild widget unmounts', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_hello()));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => SignalTranslator().loadLocale('nl'));
    await tester.pumpWidget(_wrap(_hello()));
    expect(find.text('Hallo'), findsOneWidget);
    expect(
      SignalTranslator().assetLocationString.value,
      'assets/translations/nl.json',
    );
  });
}
