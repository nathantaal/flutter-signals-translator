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
}
