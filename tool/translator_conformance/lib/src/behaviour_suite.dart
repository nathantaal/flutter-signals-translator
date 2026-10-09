// This library is a test suite shared by every package, so it uses
// test-only members by design.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:signals_translator_core/signals_translator_core.dart';
import 'harness.dart';

class _FailingPreferencesStore extends InMemorySharedPreferencesStore {
  _FailingPreferencesStore() : super.empty();

  @override
  Future<Map<String, Object>> getAll() =>
      Future.error(PlatformException(code: 'prefs-unavailable'));
}

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

void runTranslatorConformance(TranslatorHarness h) {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Shadow the adapter's top-level functions so the tests below read the
  // same as an app using any adapter.
  String tl(String key) => h.tl(key);
  String tlv(String key, String variable) => h.tlv(key, variable);
  String tlvm(String key, List<String> variables) => h.tlvm(key, variables);

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
  TranslatorCore? signalTranslator;

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

    h.reset();
    signalTranslator = h.create();
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
      h.reset();
      signalTranslator = h.create();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(signalTranslator!.currentLocale, 'es');
      expect(tl('English'), 'Inglés');
    });
  });

  group('translationsPath', () {
    const sharedPath = 'packages/shared_translations/assets/translations';

    test('defaults to assets/translations', () {
      expect(signalTranslator!.translationsPath, 'assets/translations');
    });

    test('loads translations from a custom directory', () async {
      useAssets({'$sharedPath/nl.json': mockNLJson});
      signalTranslator!.translationsPath = sharedPath;

      await signalTranslator!.loadLocale('nl');

      expect(tl('Dutch'), 'Nederlands');
      expect(signalTranslator!.activeAssetPath, '$sharedPath/nl.json');
    });

    test('falls back within the custom directory', () async {
      useAssets({'$sharedPath/en.json': mockEnJson});
      signalTranslator!.translationsPath = sharedPath;

      await signalTranslator!.loadLocale('hu');

      expect(signalTranslator!.activeAssetPath, '$sharedPath/en.json');
    });

    test('activeAssetPath keeps the loaded file when the path changes '
        'afterwards', () async {
      useAssets({'assets/translations/nl.json': mockNLJson});
      await signalTranslator!.loadLocale('nl');

      signalTranslator!.translationsPath = sharedPath;

      expect(signalTranslator!.activeAssetPath, 'assets/translations/nl.json');
    });

    test('ignores a trailing slash', () async {
      useAssets({'$sharedPath/nl.json': mockNLJson});
      signalTranslator!.translationsPath = '$sharedPath/';

      await signalTranslator!.loadLocale('nl');

      expect(signalTranslator!.activeAssetPath, '$sharedPath/nl.json');
    });

    test('applies to the stored locale loaded at startup when set right '
        'after first access', () async {
      SharedPreferences.setMockInitialValues({'locale': 'nl'});
      useAssets({'$sharedPath/nl.json': mockNLJson});
      h.reset();
      final translator = h.create()..translationsPath = sharedPath;

      await translator.ready;

      expect(tl('Dutch'), 'Nederlands');
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

    test('falls back when the translations key is not a JSON object', () async {
      useAssets({
        'assets/translations/hu.json':
            '{"language": "Hungarian", "translations": "not a map"}',
        'assets/translations/en.json': mockEnJson,
      });

      await signalTranslator!.loadLocale('hu');

      expect(signalTranslator!.currentLocale, 'hu');
      expect(signalTranslator!.activeLocale, 'en');
      expect(tl('Dutch'), 'Dutch');
    });
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
      // fallback step for input 'en' with fallbackLocale 'en'. Wait for the
      // startup load first so it isn't counted.
      await signalTranslator!.ready;
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

      h.reset();
      final fresh = h.create();
      await fresh.loadLocale('sys');
      expect(tl('colour'), 'colour (UK)');

      binding.platformDispatcher.clearLocaleTestValue();
    });

    test('uses bare language when countryCode is null', () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.localeTestValue = const Locale('en');

      useAssets({'assets/translations/en.json': mockEnJson});

      h.reset();
      final fresh = h.create();
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

        h.reset();
        final fresh = h.create();
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

      h.reset();
      final fresh = h.create();

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

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'en');
    });

    test(
      'normalizes hyphen separator to underscore and uppercases region',
      () async {
        await signalTranslator!.loadLocale('en-gb');
        expect(signalTranslator!.currentLocale, 'en_GB');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('locale'), 'en_GB');
      },
    );

    test('normalizes mixed-case region input', () async {
      await signalTranslator!.loadLocale('EN_gB');
      expect(signalTranslator!.currentLocale, 'en_GB');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'en_GB');
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
        expect(prefs.getString('locale'), 'zh_Hans');
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

      h.reset();
      final fresh = h.create();
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

      h.reset();
      final fresh = h.create();
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

      h.reset();
      final fresh = h.create();
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

      h.reset();
      final fresh = h.create();
      await fresh.loadLocale('sys');
      expect(fresh.resolvedLocale, 'nl_NL');

      await fresh.loadLocale('es');
      expect(fresh.resolvedLocale, 'es');

      binding.platformDispatcher.clearLocaleTestValue();
    });
  });

  group('sys sentinel reservation', () {
    test(
      'loadLocale("sys") never probes assets/translations/sys.json',
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

        h.reset();
        final fresh = h.create();
        await fresh.loadLocale('sys');

        expect(fresh.activeLocale, 'nl');
        expect(tl('marker'), 'marker');

        binding.platformDispatcher.clearLocaleTestValue();
      },
    );

    test(
      'loadLocale("SYS") is treated as a locale tag, not the sentinel',
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
      },
    );
  });

  group('legacy hyphen-named locales', () {
    test('a hyphen-named asset is not loaded', () async {
      useAssets({
        'assets/translations/en-gb.json': '''
          {"language": "Legacy", "translations": {"legacy_only": "from legacy"}}
        ''',
        'assets/translations/en.json': mockEnJson,
      });

      await signalTranslator!.loadLocale('en-gb');

      expect(signalTranslator!.currentLocale, 'en_GB');
      expect(signalTranslator!.activeLocale, 'en');
      expect(tl('legacy_only'), 'legacy_only');
    });

    test('a hyphen-form value persisted by an older version is kept and '
        'rewritten to the canonical form', () async {
      SharedPreferences.setMockInitialValues({'locale': 'en-gb'});
      useAssets({
        'assets/translations/en_GB.json': '''
            {"language": "English (UK)", "translations": {"colour": "colour (UK)"}}
          ''',
      });

      h.reset();
      final fresh = h.create();
      await fresh.ready;

      expect(fresh.currentLocale, 'en_GB');
      expect(fresh.activeLocale, 'en_GB');
      expect(tl('colour'), 'colour (UK)');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'en_GB');
    });
  });

  group('observer attachment', () {
    test('debugReset detaches the retired instance', () {
      final retired = h.create();
      expect(retired.debugObserverAttached, isTrue);
      h.reset();
      expect(retired.debugObserverAttached, isFalse);
      expect(h.create().debugObserverAttached, isTrue);
      expect(identical(retired, h.create()), isFalse);
    });

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
      expect(tlvm('search', ['1', 'flutter']), 'Found 1 result for "flutter".');
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

  group('ICU edge cases', () {
    const edgeJson = r'''
    {
      "language": "English",
      "translations": {
        "inbox":              "You have {0, plural, =0 {no messages} one {# message} other {# messages}} in your inbox.",
        "nested_plural":      "{0, plural, one {One basket with {1, plural, one {# apple} other {# apples}}} other {# baskets with {1, plural, one {# apple} other {# apples}}}}",
        "truncated":          "abc {0, plural,",
        "huge_index":         "{99999999999999999999, plural, one {a} other {b}}",
        "unclosed":           "x {0, plural, one {a} other {b}",
        "literal_hash":       "{0, plural, one {# issue, see ticket '#'{1}} other {# issues, see ticket '#'{1}}}",
        "repeated_var":       "{0} likes {1, select, female {her} other {their}} cat, says {0}.",
        "pair":               "{0} and {1}",
        "space_after_brace":  "{ 0, plural, one {# item} other {# items}}",
        "space_before_comma": "{0 , plural, one {# item} other {# items}}",
        "ordinal":            "{0, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}",
        "offset":             "{0, plural, offset:1 =0 {nobody} =1 {only {1}} one {{1} and # other} other {{1} and # others}}",
        "braces_in_form":     "{0, plural, one {Hi {name}!} other {Hey {name}!}} tail",
        "number_in_form":     "{0, plural, one {# item at {1, number}} other {# items at {1, number}}}"
      }
    }
    ''';

    setUp(() {
      useAssets({'assets/translations/en.json': edgeJson});
    });

    test('nested plural: # binds to the innermost plural count', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlvm('nested_plural', ['1', '3']), 'One basket with 3 apples');
      expect(tlvm('nested_plural', ['2', '1']), '2 baskets with 1 apple');
    });

    test('plural: a non-integer value selects the "other" form', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlv('inbox', '1.5'), 'You have 1.5 messages in your inbox.');
      expect(tlv('inbox', '1,000'), 'You have 1,000 messages in your inbox.');
    });

    test('plural: a non-finite value selects the "other" form', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlv('inbox', 'NaN'), 'You have NaN messages in your inbox.');
      expect(
        tlv('inbox', 'Infinity'),
        'You have Infinity messages in your inbox.',
      );
      expect(tlv('ordinal', '1e400'), '1e400th');
    });

    test('literal braces inside a form are kept verbatim', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlv('braces_in_form', '1'), 'Hi {name}! tail');
    });

    test(
      'an unsupported argument type inside a form is kept verbatim',
      () async {
        await signalTranslator!.loadLocale('en');
        expect(tlvm('number_in_form', ['2', '3.5']), '2 items at {1, number}');
      },
    );

    test('malformed: a truncated block does not throw', () async {
      await signalTranslator!.loadLocale('en');
      expect(() => tlv('truncated', '1'), returnsNormally);
    });

    test('malformed: an oversized variable index does not throw', () async {
      await signalTranslator!.loadLocale('en');
      expect(() => tlv('huge_index', '1'), returnsNormally);
    });

    test('malformed: an unclosed block is rendered verbatim instead of '
        'swallowing the rest of the string', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlv('unclosed', '1'), 'x {0, plural, one {a} other {b}');
    });

    test("plural: a quoted '#' stays a literal #", () async {
      await signalTranslator!.loadLocale('en');
      expect(tlvm('literal_hash', ['1', '42']), '1 issue, see ticket #42');
    });

    test(
      'a placeholder used twice is substituted at every occurrence',
      () async {
        await signalTranslator!.loadLocale('en');
        expect(
          tlvm('repeated_var', ['Ann', 'female']),
          'Ann likes her cat, says Ann.',
        );
      },
    );

    test('substituted values are not re-scanned for placeholders', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlvm('pair', ['{1}', 'b']), '{1} and b');
    });

    test('whitespace around the variable index is accepted', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlv('space_after_brace', '2'), '2 items');
      expect(tlv('space_before_comma', '2'), '2 items');
    });

    test('selectordinal picks English ordinal suffixes', () async {
      await signalTranslator!.loadLocale('en');
      const want = {
        '1': '1st',
        '2': '2nd',
        '3': '3rd',
        '4': '4th',
        '11': '11th',
        '12': '12th',
        '13': '13th',
        '21': '21st',
        '22': '22nd',
        '23': '23rd',
        '101': '101st',
        '111': '111th',
      };
      for (final MapEntry(:key, :value) in want.entries) {
        expect(tlv('ordinal', key), value, reason: 'count $key');
      }
    });

    test('plural offset: exact matches use the raw value; # and the category '
        'use the value minus the offset', () async {
      await signalTranslator!.loadLocale('en');
      expect(tlvm('offset', ['0', 'Ann']), 'nobody');
      expect(tlvm('offset', ['1', 'Ann']), 'only Ann');
      expect(tlvm('offset', ['2', 'Ann']), 'Ann and 1 other');
      expect(tlvm('offset', ['3', 'Ann']), 'Ann and 2 others');
    });

    test('a missing variable logs a debug warning naming the key', () async {
      await signalTranslator!.loadLocale('en');
      final captured = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) captured.add(message);
      };
      try {
        tl('inbox');
      } finally {
        debugPrint = original;
      }

      expect(
        captured.any((m) => m.contains('inbox')),
        isTrue,
        reason: 'expected a debugPrint naming the key, got: $captured',
      );
    });
  });

  group('ICU plural categories follow CLDR rules for the active locale', () {
    // Each form echoes its category name, so the assertion shows which
    // category the resolver picked.
    const probe =
        '{0, plural, zero {zero:#} one {one:#} two {two:#} few {few:#} '
        'many {many:#} other {other:#}}';

    Future<void> loadProbe(String locale) async {
      useAssets({
        'assets/translations/$locale.json': jsonEncode({
          'language': locale,
          'translations': {'probe': probe},
        }),
      });
      await signalTranslator!.loadLocale(locale);
    }

    test(
      'English: 0 selects "other" (English has no "zero" category)',
      () async {
        await loadProbe('en');
        expect(tlv('probe', '0'), 'other:0');
        expect(tlv('probe', '1'), 'one:1');
      },
    );

    test('French: 0 selects "one"', () async {
      await loadProbe('fr');
      expect(tlv('probe', '0'), 'one:0');
      expect(tlv('probe', '2'), 'other:2');
    });

    test('Polish: selects "few" and "many"', () async {
      await loadProbe('pl');
      expect(tlv('probe', '1'), 'one:1');
      expect(tlv('probe', '3'), 'few:3');
      expect(tlv('probe', '5'), 'many:5');
      expect(tlv('probe', '12'), 'many:12');
      expect(tlv('probe', '22'), 'few:22');
    });

    test('Russian: 21 selects "one" and 11 selects "many"', () async {
      await loadProbe('ru');
      expect(tlv('probe', '21'), 'one:21');
      expect(tlv('probe', '11'), 'many:11');
      expect(tlv('probe', '3'), 'few:3');
    });

    test('Arabic: selects "two", "few" and "many"', () async {
      await loadProbe('ar');
      expect(tlv('probe', '0'), 'zero:0');
      expect(tlv('probe', '2'), 'two:2');
      expect(tlv('probe', '3'), 'few:3');
      expect(tlv('probe', '11'), 'many:11');
      expect(tlv('probe', '100'), 'other:100');
    });
  });

  group('nested-map translations', () {
    test('are no longer supported and fall back to the key', () async {
      useAssets({
        'assets/translations/en.json': '''
            {
              "language": "English",
              "translations": {
                "apples": {"zero": "No apples", "one": "One apple", "other": "{0} apples"}
              }
            }
          ''',
      });
      await signalTranslator!.loadLocale('en');

      expect(tl('apples'), 'apples');
      expect(tlv('apples', '1'), 'apples');
      expect(tlvm('apples', ['1', '2']), 'apples');
    });
  });

  group('ready', () {
    test(
      'completes with an error when SharedPreferences fails to load',
      () async {
        SharedPreferencesStorePlatform.instance = _FailingPreferencesStore();
        SharedPreferences.resetStatic();
        addTearDown(() => SharedPreferences.setMockInitialValues({}));

        h.reset();

        await expectLater(
          h.create().ready.timeout(const Duration(seconds: 1)),
          throwsA(isNot(isA<TimeoutException>())),
        );
      },
    );

    test('completes only after the stored locale has been loaded', () async {
      SharedPreferences.setMockInitialValues({'locale': 'nl'});
      h.reset();

      await h.create().ready;

      expect(tl('Dutch'), 'Nederlands');
    });

    test('loads the system locale when no locale is stored', () async {
      h.reset();
      final translator = h.create();

      await translator.ready;

      expect(translator.currentLocale, 'sys');
      expect(translator.activeLocale, 'en');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), isNull);
    });

    test(
      'still loads the system locale when SharedPreferences fails to load',
      () async {
        SharedPreferencesStorePlatform.instance = _FailingPreferencesStore();
        SharedPreferences.resetStatic();
        addTearDown(() => SharedPreferences.setMockInitialValues({}));
        h.reset();
        final translator = h.create();

        await expectLater(translator.ready, throwsA(anything));

        expect(translator.activeLocale, 'en');
      },
    );
  });
}
