import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_translator/signals_translator.dart';

class MockAssetBundle extends CachingAssetBundle {
  final Map<String, String> _mockAssets;

  MockAssetBundle(this._mockAssets);

  @override
  Future<ByteData> load(String key) async {
    if (_mockAssets.containsKey(key)) {
      return ByteData.view(
        Uint8List.fromList(utf8.encode(_mockAssets[key]!)).buffer,
      );
    }
    throw FlutterError('Unable to load asset: $key');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (_mockAssets.containsKey(key)) {
      return _mockAssets[key]!;
    }
    throw FlutterError('Unable to load asset: $key');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mockEnJson = '''
  {
    "language": "English",
    "translations": {
      "Dutch": "Dutch",
      "English": "English",
      "Spanish": "Spanish",
      "He came in {0}, while his partner came in at the {1} place": "He came in {0}, while his partner came in at the {1} place",
      "CAN_USE_KEY": "You can also use key-value pairs to translate"
    }
  }
  ''';

  const mockNLJson = '''
  {
    "language": "Dutch",
    "translations": {
      "Dutch": "Nederlands",
      "English": "English",
      "Spanish": "Español",
      "He came in {0}, while his partner came in at the {1} place": "Zijn parter eindigde op de {1} plaats, terwijl hij op de {0} plaats eindigde",
      "CAN_USE_KEY": "Je kunt ook sleutel-waardeparen gebruiken om te vertalen"
    }
  }
  ''';

  const mockEsJson = '''
  {
    "language": "Spanish",
    "translations": {
      "Dutch": "Holandés",
      "English": "Inglés",
      "Spanish": "Español",
      "He came in {0}, while his partner came in at the {1} place": "Él llegó en {0}, mientras que su pareja llegó en el {1} lugar",
      "CAN_USE_KEY": "También puedes usar pares clave-valor para traducir"
    }
  }
  ''';

  MockAssetBundle? mockBundle;
  SignalTranslator? signalTranslator;

  void installAssetHandler() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          final asset = mockBundle?._mockAssets[key];
          if (asset == null) {
            return null;
          }

          return ByteData.view(Uint8List.fromList(utf8.encode(asset)).buffer);
        });
  }

  void useAssets(Map<String, String> assets) {
    mockBundle = MockAssetBundle(assets);
    installAssetHandler();
  }

  Future<void> useFailingAssetHandler() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async => null);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    useAssets({
      'assets/translations/en.json': mockEnJson,
      'assets/translations/nl.json': mockNLJson,
      'assets/translations/es.json': mockEsJson,
    });

    SignalTranslator.debugReset();
    signalTranslator = SignalTranslator();
  });

  tearDown(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    mockBundle = null;
    signalTranslator = null;
  });

  group('basic translation lookups', () {
    // Test will fail if the system language is not English, which is as expected.
    test(
      'uses the default translations before a locale is explicitly loaded',
      () {
        // For the EN variant, there is chosen to stay native to the user so they
        // can find there language easily.
        expect(tl('Dutch'), 'Dutch');
        expect(tl('English'), 'English');
        expect(tl('Spanish'), 'Spanish');
      },
    );

    test(
      "defaults currentLocale to the 'sys' sentinel until something is chosen",
      () {
        // 0.0.6 defaulted to composeDeviceLocale() (e.g. 'en_US'), which
        // silently broke any caller binding a dropdown to currentLocale
        // against bare-language items. Default to 'sys' so regional asset
        // auto-pickup still resolves via _deviceLocale without forcing
        // consumers to strip region suffixes for their UI.
        expect(signalTranslator!.currentLocale, 'sys');
      },
    );

    test('changes language and serves the selected translation set', () async {
      // For the NL variant, the developer choose to not translate the
      // languages, so the user can find their language easily.
      await signalTranslator!.loadLocale('nl');
      expect(tl('Dutch'), 'Nederlands');
      expect(tl('English'), 'English');
      expect(tl('Spanish'), 'Español');

      // For the ES variant, there is chosen to stay native to the user so they
      // can find a different language, in their own language, easily.
      await signalTranslator!.loadLocale('es');
      expect(tl('Dutch'), 'Holandés');
      expect(tl('English'), 'Inglés');
      expect(tl('Spanish'), 'Español');
    });

    test('falls back to the key when a translation is missing', () async {
      await signalTranslator!.loadLocale('en');
      expect(tl('nonexistent_key'), 'nonexistent_key');
    });

    test('translates direct key-value entries', () async {
      await signalTranslator!.loadLocale('en');
      expect(
        tl('CAN_USE_KEY'),
        'You can also use key-value pairs to translate',
      );
    });
  });

  group('variable interpolation and persistence', () {
    // Here you can explicitly reverse order of the variables.
    // Normally, this is done for language that differ in grammar
    // (for example, Germanic vs Romance languages).
    test('translates values with positional variables', () async {
      await signalTranslator!.loadLocale('en');
      var result = tlvm(
        'He came in {0}, while his partner came in at the {1} place',
        ['first', 'fifth'],
      );
      expect(
        result,
        'He came in first, while his partner came in at the fifth place',
      );

      await signalTranslator!.loadLocale('nl');
      result = tlvm(
        'He came in {0}, while his partner came in at the {1} place',
        ['eerste', 'vijfde'],
      );
      expect(
        result,
        'Zijn parter eindigde op de vijfde plaats, terwijl hij op de eerste plaats eindigde',
      );
    });

    test('retrieves a saved locale from storage after restart', () async {
      await signalTranslator!.loadLocale('es');
      expect(tl('English'), 'Inglés');

      // Simulate an app restart: swap in a fresh instance that has to
      // rehydrate from prefs, just like cold-start in a real app.
      SignalTranslator.debugReset();
      signalTranslator = SignalTranslator();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(signalTranslator!.currentLocale, 'es');
      expect(tl('English'), 'Inglés');
    });
  });

  group('fallback behavior and test isolation', () {
    test('starts each test with the default fallback locale', () {
      expect(signalTranslator!.fallbackLocale, 'en');
    });

    test(
      'falls back to the fallback locale when the chosen asset is missing',
      () async {
        await signalTranslator!.loadLocale('hu');

        expect(signalTranslator!.currentLocale, 'hu');
        expect(tl('Dutch'), 'Dutch');
        expect(tl('English'), 'English');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('locale'), 'hu');
      },
    );

    test(
      'clears stale translations when chosen and fallback assets both fail',
      () async {
        await signalTranslator!.loadLocale('en');
        expect(
          tl('CAN_USE_KEY'),
          'You can also use key-value pairs to translate',
        );

        await useFailingAssetHandler();
        await signalTranslator!.loadLocale('hu');

        expect(signalTranslator!.currentLocale, 'hu');
        expect(tl('CAN_USE_KEY'), 'CAN_USE_KEY');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('locale'), 'hu');
      },
    );

    test(
      'honours a customised fallbackLocale without leaking to later tests',
      () async {
        signalTranslator!.fallbackLocale = 'nl';

        await signalTranslator!.loadLocale('hu');

        expect(signalTranslator!.currentLocale, 'hu');
        expect(tl('Dutch'), 'Nederlands');
        expect(tl('Spanish'), 'Español');
      },
    );

    test('falls back when the asset JSON root is not an object', () async {
      useAssets({
        'assets/translations/hu.json': '[1, 2, 3]',
        'assets/translations/en.json': mockEnJson,
      });

      await signalTranslator!.loadLocale('hu');

      expect(signalTranslator!.currentLocale, 'hu');
      expect(signalTranslator!.activeLocale, 'en');
      expect(tl('Dutch'), 'Dutch');
    });

    test(
      'falls back when the translations key is not a JSON object',
      () async {
        useAssets({
          'assets/translations/hu.json':
              '{"language": "Hungarian", "translations": "not a map"}',
          'assets/translations/en.json': mockEnJson,
        });

        await signalTranslator!.loadLocale('hu');

        expect(signalTranslator!.currentLocale, 'hu');
        expect(signalTranslator!.activeLocale, 'en');
        expect(tl('Dutch'), 'Dutch');
      },
    );
  });

  group('pluralization', () {
    test('pluralizes a single count', () async {
      const pluralJson = '''
      {
        "language": "English",
        "translations": {
          "I have {0} apples": {
            "zero": "I have no apples",
            "one": "I have 1 apple",
            "other": "I have {0} apples"
          }
        }
      }
      ''';

      useAssets({'assets/translations/en.json': pluralJson});

      await signalTranslator!.loadLocale('en');
      expect(tlp('I have {0} apples', 0), 'I have no apples');
      expect(tlp('I have {0} apples', 1), 'I have 1 apple');
      expect(tlp('I have {0} apples', 2), 'I have 2 apples');
      expect(tlp('I have {0} apples', 42), 'I have 42 apples');
    });

    test(
      'pluralizes multiple counts and falls back to the key when missing',
      () async {
        const pluralMultiJson = '''
      {
        "language": "English",
        "translations": {
          "I have {0} strawberries and {1} bananas": {
            "zero_zero": "I have no strawberries and no bananas",
            "one_one": "I have 1 strawberry and 1 banana",
            "one_other": "I have 1 strawberry and {1} bananas",
            "other_one": "I have {0} strawberries and 1 banana",
            "other_other": "I have {0} strawberries and {1} bananas"
          }
        }
      }
      ''';

        useAssets({'assets/translations/en.json': pluralMultiJson});

        await signalTranslator!.loadLocale('en');
        expect(
          tlpm('I have {0} strawberries and {1} bananas', [0, 0]),
          'I have no strawberries and no bananas',
        );
        expect(
          tlpm('I have {0} strawberries and {1} bananas', [1, 1]),
          'I have 1 strawberry and 1 banana',
        );
        expect(
          tlpm('I have {0} strawberries and {1} bananas', [1, 3]),
          'I have 1 strawberry and 3 bananas',
        );
        expect(
          tlpm('I have {0} strawberries and {1} bananas', [2, 1]),
          'I have 2 strawberries and 1 banana',
        );
        expect(
          tlpm('I have {0} strawberries and {1} bananas', [2, 5]),
          'I have 2 strawberries and 5 bananas',
        );
        expect(tlpm('nonexistent_key', [1, 2]), 'nonexistent_key');
      },
    );
  });

  group('regional fallback chain', () {
    const mockEnGbJson = '''
  {
    "language": "English (UK)",
    "translations": {
      "Dutch": "Dutch",
      "English": "English",
      "Spanish": "Spanish",
      "colour": "colour",
      "CAN_USE_KEY": "You can also use key-value pairs to translate (UK)"
    }
  }
  ''';

    test('uses the regional file when it is shipped', () async {
      useAssets({
        'assets/translations/en.json': mockEnJson,
        'assets/translations/en_GB.json': mockEnGbJson,
      });

      await signalTranslator!.loadLocale('en_GB');
      expect(signalTranslator!.currentLocale, 'en_GB');
      expect(
        tl('CAN_USE_KEY'),
        'You can also use key-value pairs to translate (UK)',
      );
    });

    test(
      'falls through to bare language when the regional file is missing',
      () async {
        useAssets({'assets/translations/en.json': mockEnJson});

        await signalTranslator!.loadLocale('en_GB');
        expect(signalTranslator!.currentLocale, 'en_GB');
        expect(
          tl('CAN_USE_KEY'),
          'You can also use key-value pairs to translate',
        );
      },
    );

    test(
      'falls through to fallbackLocale when both regional and bare are missing',
      () async {
        useAssets({'assets/translations/nl.json': mockNLJson});
        signalTranslator!.fallbackLocale = 'nl';

        await signalTranslator!.loadLocale('en_GB');
        expect(signalTranslator!.currentLocale, 'en_GB');
        expect(tl('Dutch'), 'Nederlands');
      },
    );

    test('lands in key-as-value mode when every candidate fails', () async {
      await useFailingAssetHandler();

      await signalTranslator!.loadLocale('en_GB');
      expect(signalTranslator!.currentLocale, 'en_GB');
      expect(tl('whatever_key'), 'whatever_key');
    });

    test(
      'falls through to bare-of-fallback when fallback is regional',
      () async {
        useAssets({
          'assets/translations/fr.json': '''
    {
      "language": "French",
      "translations": {
        "Dutch": "Néerlandais",
        "English": "Anglais"
      }
    }
    ''',
        });
        signalTranslator!.fallbackLocale = 'fr_CA';

        await signalTranslator!.loadLocale('en_GB');
        expect(signalTranslator!.currentLocale, 'en_GB');
        expect(tl('Dutch'), 'Néerlandais');
      },
    );

    test('candidate list dedupes when requested equals fallback', () async {
      // Wire a counting asset handler so we can assert en.json is only fetched
      // once even though it appears as both the bare-language step and the
      // fallback step for input 'en' with fallbackLocale 'en'.
      final hitCounts = <String, int>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (message) async {
            final key = utf8.decode(message!.buffer.asUint8List());
            hitCounts[key] = (hitCounts[key] ?? 0) + 1;
            if (key == 'assets/translations/en.json') {
              return ByteData.view(
                Uint8List.fromList(utf8.encode(mockEnJson)).buffer,
              );
            }
            return null;
          });

      await signalTranslator!.loadLocale('en');
      expect(hitCounts['assets/translations/en.json'], 1);
    });
  });

  group('device locale auto-detection', () {
    test('includes the region when countryCode is non-null', () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.localeTestValue = const Locale('en', 'GB');

      useAssets({
        'assets/translations/en.json': mockEnJson,
        'assets/translations/en_GB.json': '''
          {
            "language": "English (UK)",
            "translations": {"colour": "colour (UK)"}
          }
        ''',
      });

      SignalTranslator.debugReset();
      final fresh = SignalTranslator();
      await fresh.loadLocale('sys');
      expect(tl('colour'), 'colour (UK)');

      binding.platformDispatcher.clearLocaleTestValue();
    });

    test('uses bare language when countryCode is null', () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.localeTestValue = const Locale('en');

      useAssets({'assets/translations/en.json': mockEnJson});

      SignalTranslator.debugReset();
      final fresh = SignalTranslator();
      await fresh.loadLocale('sys');
      expect(tl('Dutch'), 'Dutch');

      binding.platformDispatcher.clearLocaleTestValue();
    });

    test(
      'regional sys mode falls through bare language when regional missing',
      () async {
        final binding = TestWidgetsFlutterBinding.ensureInitialized();
        binding.platformDispatcher.localeTestValue = const Locale('en', 'GB');

        useAssets({'assets/translations/en.json': mockEnJson});

        SignalTranslator.debugReset();
        final fresh = SignalTranslator();
        await fresh.loadLocale('sys');
        expect(tl('Dutch'), 'Dutch');

        binding.platformDispatcher.clearLocaleTestValue();
      },
    );

    test('didChangeLocales updates the device locale signal', () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.localeTestValue = const Locale('en');

      useAssets({
        'assets/translations/en.json': mockEnJson,
        'assets/translations/en_GB.json': '''
          {
            "language": "English (UK)",
            "translations": {"colour": "colour (UK)"}
          }
        ''',
      });

      SignalTranslator.debugReset();
      final fresh = SignalTranslator();

      // First load uses bare English (countryCode null).
      await fresh.loadLocale('sys');
      expect(tl('Dutch'), 'Dutch');

      // OS reports a locale change to en-GB. Set the test value and invoke
      // the observer hook the same way the framework would.
      binding.platformDispatcher.localeTestValue = const Locale('en', 'GB');
      fresh.didChangeLocales(const [Locale('en', 'GB')]);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(fresh.currentLocale, 'sys');
      expect(fresh.systemLocale, 'en_GB');
      expect(tl('colour'), 'colour (UK)');

      binding.platformDispatcher.clearLocaleTestValue();
    });
  });

  group('locale normalization', () {
    test('preserves canonical bare-language input', () async {
      await signalTranslator!.loadLocale('en');
      expect(signalTranslator!.currentLocale, 'en');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'en');
    });

    test('normalizes uppercase language to lowercase', () async {
      await signalTranslator!.loadLocale('EN');
      expect(signalTranslator!.currentLocale, 'en');

      // Prefs keep the raw input so legacy callers round-trip unchanged.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'EN');
    });

    test(
      'normalizes hyphen separator to underscore and uppercases region',
      () async {
        await signalTranslator!.loadLocale('en-gb');
        expect(signalTranslator!.currentLocale, 'en_GB');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('locale'), 'en-gb');
      },
    );

    test('normalizes mixed-case region input', () async {
      await signalTranslator!.loadLocale('EN_gB');
      expect(signalTranslator!.currentLocale, 'en_GB');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'EN_gB');
    });

    test('preserves canonical regional input unchanged', () async {
      await signalTranslator!.loadLocale('en_GB');
      expect(signalTranslator!.currentLocale, 'en_GB');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'en_GB');
    });

    test(
      'canonicalizes script subtags without uppercasing the whole suffix',
      () async {
        useAssets({
          'assets/translations/zh_Hans.json': '''
          {
            "language": "Chinese (Simplified)",
            "translations": {"SCRIPT_KEY": "script asset loaded"}
          }
        ''',
        });

        await signalTranslator!.loadLocale('zh-hans');
        expect(signalTranslator!.currentLocale, 'zh_Hans');
        expect(tl('SCRIPT_KEY'), 'script asset loaded');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('locale'), 'zh-hans');
      },
    );

    test("preserves the 'sys' sentinel exactly", () async {
      await signalTranslator!.loadLocale('sys');
      expect(signalTranslator!.currentLocale, 'sys');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'sys');
    });

    test('emits a debugPrint warning when input is non-canonical', () async {
      final captured = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) captured.add(message);
      };
      try {
        await signalTranslator!.loadLocale('en-gb');
      } finally {
        debugPrint = original;
      }

      expect(
        captured.any((m) => m.contains("'en-gb'") && m.contains('en_GB')),
        isTrue,
        reason:
            "expected a debugPrint mentioning the raw and canonical forms, got: $captured",
      );
    });

    test('does not warn when input is already canonical', () async {
      final captured = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) captured.add(message);
      };
      try {
        await signalTranslator!.loadLocale('en_GB');
      } finally {
        debugPrint = original;
      }

      expect(
        captured.any((m) => m.contains('not canonical')),
        isFalse,
        reason:
            'unexpected normalization warning for canonical input: $captured',
      );
    });
  });

  group('resolvedLocale', () {
    test('matches currentLocale when a concrete locale is chosen', () async {
      await signalTranslator!.loadLocale('nl');
      expect(signalTranslator!.resolvedLocale, 'nl');
      expect(signalTranslator!.resolvedLocale, signalTranslator!.currentLocale);
    });

    test('resolves to the device locale when sys is chosen', () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.localeTestValue = const Locale('nl', 'NL');

      useAssets({'assets/translations/nl.json': mockNLJson});

      SignalTranslator.debugReset();
      final fresh = SignalTranslator();
      await fresh.loadLocale('sys');

      expect(fresh.currentLocale, 'sys');
      expect(fresh.resolvedLocale, 'nl_NL');

      binding.platformDispatcher.clearLocaleTestValue();
    });

    test('includes scriptCode from the device locale in sys mode', () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.localeTestValue = const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
        countryCode: 'CN',
      );

      useAssets({
        'assets/translations/zh.json': '''
          {"language": "Chinese", "translations": {"hello": "ni hao"}}
        ''',
      });

      SignalTranslator.debugReset();
      final fresh = SignalTranslator();
      await fresh.loadLocale('sys');

      expect(fresh.resolvedLocale, 'zh_Hans_CN');
      // Falls back through zh_Hans_CN → zh_Hans → zh.
      expect(fresh.activeLocale, 'zh');
      expect(tl('hello'), 'ni hao');

      binding.platformDispatcher.clearLocaleTestValue();
    });

    test('tracks device locale changes while sys is selected', () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.localeTestValue = const Locale('en');

      useAssets({'assets/translations/en.json': mockEnJson});

      SignalTranslator.debugReset();
      final fresh = SignalTranslator();
      await fresh.loadLocale('sys');
      expect(fresh.resolvedLocale, 'en');

      binding.platformDispatcher.localeTestValue = const Locale('en', 'GB');
      fresh.didChangeLocales(const [Locale('en', 'GB')]);

      expect(fresh.resolvedLocale, 'en_GB');

      binding.platformDispatcher.clearLocaleTestValue();
    });

    test('switches back to the chosen locale when sys is replaced', () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.localeTestValue = const Locale('nl', 'NL');

      useAssets({
        'assets/translations/nl.json': mockNLJson,
        'assets/translations/es.json': mockEsJson,
      });

      SignalTranslator.debugReset();
      final fresh = SignalTranslator();
      await fresh.loadLocale('sys');
      expect(fresh.resolvedLocale, 'nl_NL');

      await fresh.loadLocale('es');
      expect(fresh.resolvedLocale, 'es');

      binding.platformDispatcher.clearLocaleTestValue();
    });
  });

  group('sys sentinel reservation', () {
    test('loadLocale("sys") never probes assets/translations/sys.json',
        () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.localeTestValue = const Locale('nl');

      // Ship a sys.json with distinctive content alongside the real
      // device-locale file. If the implementation ever probes 'sys' as a
      // candidate, it would load this asset and the assertions below
      // would fail.
      useAssets({
        'assets/translations/sys.json': '''
          {"language": "SYS", "translations": {"marker": "from sys.json"}}
        ''',
        'assets/translations/nl.json': mockNLJson,
      });

      SignalTranslator.debugReset();
      final fresh = SignalTranslator();
      await fresh.loadLocale('sys');

      expect(fresh.activeLocale, 'nl');
      expect(tl('marker'), 'marker');

      binding.platformDispatcher.clearLocaleTestValue();
    });

    test('loadLocale("SYS") is treated as a locale tag, not the sentinel',
        () async {
      useAssets({
        'assets/translations/SYS.json': '''
          {"language": "custom", "translations": {"hello": "from SYS"}}
        ''',
        'assets/translations/en.json': mockEnJson,
      });

      await signalTranslator!.loadLocale('SYS');

      // Case-variants of 'sys' must NOT activate system-locale mode.
      expect(signalTranslator!.currentLocale, isNot('sys'));
      expect(signalTranslator!.activeLocale, 'SYS');
      expect(tl('hello'), 'from SYS');
    });
  });

  group('backwards-compat for legacy file names', () {
    test('loads a legacy hyphen-named asset when only that file ships',
        () async {
      useAssets({
        'assets/translations/en-gb.json': '''
          {
            "language": "English (UK, legacy)",
            "translations": {"colour": "colour (legacy UK)"}
          }
        ''',
      });

      await signalTranslator!.loadLocale('en-gb');

      expect(signalTranslator!.currentLocale, 'en_GB');
      expect(signalTranslator!.activeLocale, 'en-gb');
      expect(tl('colour'), 'colour (legacy UK)');
    });

    test('prefers the canonical file when both shapes ship', () async {
      useAssets({
        'assets/translations/en-gb.json': '''
          {"language": "Legacy", "translations": {"colour": "from legacy"}}
        ''',
        'assets/translations/en_GB.json': '''
          {"language": "Canonical", "translations": {"colour": "from canonical"}}
        ''',
      });

      await signalTranslator!.loadLocale('en-gb');

      expect(signalTranslator!.activeLocale, 'en_GB');
      expect(tl('colour'), 'from canonical');
    });

    test(
      'a legacy hyphen-form value persisted by an older version still loads '
      'across restarts',
      () async {
        // Simulate an install upgraded from <0.0.6 that has 'en-gb' stored
        // and ships only en-gb.json.
        SharedPreferences.setMockInitialValues({'locale': 'en-gb'});
        useAssets({
          'assets/translations/en-gb.json': '''
            {"language": "Legacy UK", "translations": {"colour": "colour (legacy)"}}
          ''',
        });

        SignalTranslator.debugReset();
        final fresh = SignalTranslator();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(fresh.currentLocale, 'en_GB');
        expect(fresh.activeLocale, 'en-gb');
        expect(tl('colour'), 'colour (legacy)');

        // Prefs are not silently rewritten to the canonical form, so the
        // next cold start still finds en-gb.json.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('locale'), 'en-gb');
      },
    );
  });

  group('observer attachment', () {
    test('attaches at construction when the binding is available', () {
      expect(signalTranslator!.debugObserverAttached, isTrue);
    });

    test('loadLocale re-attaches when the observer is missing', () async {
      signalTranslator!.debugDetachObserverForTest();
      expect(signalTranslator!.debugObserverAttached, isFalse);

      await signalTranslator!.loadLocale('en');
      expect(signalTranslator!.debugObserverAttached, isTrue);
    });

    test('loadLocale is idempotent — does not double-attach', () async {
      expect(signalTranslator!.debugObserverAttached, isTrue);
      await signalTranslator!.loadLocale('en');
      await signalTranslator!.loadLocale('nl');
      expect(signalTranslator!.debugObserverAttached, isTrue);
    });
  });

  group('concurrent reload race', () {
    test(
      'a stale reload completing after a newer reload does not overwrite it',
      () async {
        final slowAsset = Completer<String>();

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', (message) async {
              final key = utf8.decode(message!.buffer.asUint8List());
              if (key == 'assets/translations/en.json') {
                final raw = await slowAsset.future;
                return ByteData.view(
                  Uint8List.fromList(utf8.encode(raw)).buffer,
                );
              }
              if (key == 'assets/translations/nl.json') {
                return ByteData.view(
                  Uint8List.fromList(utf8.encode(mockNLJson)).buffer,
                );
              }
              return null;
            });

        // Start the 'en' reload — it parks on `slowAsset.future`.
        final stale = signalTranslator!.loadLocale('en');
        // Yield so the first reload reaches its asset-load await.
        await Future<void>.delayed(Duration.zero);

        // A newer reload comes in and completes immediately.
        await signalTranslator!.loadLocale('nl');
        expect(tl('Dutch'), 'Nederlands');
        expect(signalTranslator!.activeLocale, 'nl');

        // Release the stale reload. Without the guard, it would overwrite
        // _translations with the 'en' payload it loaded too late.
        slowAsset.complete(mockEnJson);
        await stale;

        expect(tl('Dutch'), 'Nederlands');
        expect(signalTranslator!.activeLocale, 'nl');
      },
    );
  });

  group('ICU message format', () {
    const icuJson = '''
    {
      "language": "English",
      "translations": {
        "inbox":      "You have {0, plural, =0 {no messages} one {# message} other {# messages}} in your inbox.",
        "winners":    "There {0, plural, one {is # winner} other {are # winners}}!",
        "zero_only":  "{0, plural, =0 {nothing here} other {# things}}",
        "cart":       "Cart: {0, plural, =0 {no items} one {# item} other {# items}} and {1, plural, =0 {no coupons} one {# coupon} other {# coupons}}.",
        "reaction":   "{0, select, female {She} male {He} other {They}} liked your post.",
        "search":     "Found {0, plural, =0 {no results} one {# result} other {# results}} for \\"{1}\\".",
        "nested_var": "{0, plural, one {# item costing {1}} other {# items costing {1} each}}",
        "plain":      "No ICU blocks here, just {0}.",
        "verb_agree": "{0, plural, one {# file was} other {# files were}} changed."
      }
    }
    ''';

    setUp(() {
      useAssets({'assets/translations/en.json': icuJson});
    });

    test('plural: selects "one" form', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlv('inbox', '1'), 'You have 1 message in your inbox.');
    });

    test('plural: selects "other" form', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlv('inbox', '5'), 'You have 5 messages in your inbox.');
    });

    test('plural: =0 exact match resolves when "zero" key absent', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlv('zero_only', '0'), 'nothing here');
    });

    test('plural: exact match =0 takes priority over category', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlv('inbox', '0'), 'You have no messages in your inbox.');
    });

    test(
      'plural: falls back to "other" when no exact or category match',
      () async {
        await signalTranslator!.loadLocale('en');
        expect(tlv('winners', '0'), 'There are 0 winners!');
      },
    );

    test('plural: # token is replaced with the count', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlv('winners', '3'), 'There are 3 winners!');
      expect(tlv('winners', '1'), 'There is 1 winner!');
    });

    test('plural: verb agreement (is/are)', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlv('verb_agree', '1'), '1 file was changed.');
      expect(tlv('verb_agree', '2'), '2 files were changed.');
    });

    test('multiple ICU blocks in one string', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlvm('cart', ['0', '0']), 'Cart: no items and no coupons.');
      expect(tlvm('cart', ['1', '0']), 'Cart: 1 item and no coupons.');
      expect(tlvm('cart', ['3', '1']), 'Cart: 3 items and 1 coupon.');
      expect(tlvm('cart', ['2', '4']), 'Cart: 2 items and 4 coupons.');
    });

    test('select: matches the given form', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlv('reaction', 'female'), 'She liked your post.');
      expect(tlv('reaction', 'male'), 'He liked your post.');
    });

    test('select: falls back to "other" for unknown values', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlv('reaction', 'nonbinary'), 'They liked your post.');
      expect(tlv('reaction', 'other'), 'They liked your post.');
    });

    test('ICU plural combined with a regular {N} variable', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlvm('search', ['0', 'dart']), 'Found no results for "dart".');
      expect(
        tlvm('search', ['1', 'flutter']),
        'Found 1 result for "flutter".',
      );
      expect(
        tlvm('search', ['42', 'signals']),
        'Found 42 results for "signals".',
      );
    });

    test('{N} variable inside ICU form body is substituted', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlvm('nested_var', ['1', '\$9.99']), '1 item costing \$9.99');
      expect(
        tlvm('nested_var', ['3', '\$4.50']),
        '3 items costing \$4.50 each',
      );
    });

    test('non-ICU strings pass through the resolver unchanged', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlv('plain', 'world'), 'No ICU blocks here, just world.');
    });

    test(
      'missing variable index produces empty string for that block',
      () async {
        await signalTranslator!.loadLocale('en');
        expect(tl('inbox'), 'You have  in your inbox.');
      },
    );

    test('nonexistent ICU key falls back to the key string', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlv('nonexistent_icu_key', '5'), 'nonexistent_icu_key');
    });
  });
}
