import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_translator/signals_translator.dart';
import 'package:mockito/mockito.dart';

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

class MockSignalTranslator extends Mock implements SignalTranslator {}


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MockAssetBundle? mockBundle;
  SignalTranslator? signalTranslator;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

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

    // Override the rootBundle temporarily for the test
    mockBundle = MockAssetBundle({
      'assets/translations/en.json': mockEnJson,
      'assets/translations/nl.json': mockNLJson,
      'assets/translations/es.json': mockEsJson,
    });

    signalTranslator = SignalTranslator();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    mockBundle = null;
    signalTranslator = null;
  });

  //Test will fail if the system language is not English, which is as expected
  test('Test default translations', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (mockBundle!._mockAssets.containsKey(key)) {
            return ByteData.view(
              Uint8List.fromList(
                utf8.encode(mockBundle!._mockAssets[key]!),
              ).buffer,
            );
          }
          return null;
        });

    // For the EN variant, there is chosen to stay native to the user so they can find there language easily
    expect(tl('Dutch'), 'Dutch');
    expect(tl('English'), 'English');
    expect(tl('Spanish'), 'Spanish');
  });

  test('Test changing language', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (mockBundle!._mockAssets.containsKey(key)) {
            return ByteData.view(
              Uint8List.fromList(
                utf8.encode(mockBundle!._mockAssets[key]!),
              ).buffer,
            );
          }
          return null;
        });

    // For the NL variant, the developer choose to not translate the languages, so the user can find their language easily
    await signalTranslator!.loadLocale('nl');
    expect(tl('Dutch'), 'Nederlands');
    expect(tl('English'), 'English');
    expect(tl('Spanish'), 'Español');

    // For the ES variant, there is chosen to stay native to the user so they can find a different language, in their own language, easily
    await signalTranslator!.loadLocale('es');
    expect(tl('Dutch'), 'Holandés');
    expect(tl('English'), 'Inglés');
    expect(tl('Spanish'), 'Español');
  });

  test('it should fall back to key', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (mockBundle!._mockAssets.containsKey(key)) {
        return ByteData.view(
          Uint8List.fromList(
            utf8.encode(mockBundle!._mockAssets[key]!),
          ).buffer,
        );
      }
      return null;
    });

    await signalTranslator!.loadLocale('en');
    expect(tl('nonexistent_key'), 'nonexistent_key');
  });

  //Here you can explicitly reverse order of the variables
  //Normally, this is done for language that differ in grammar (for example, Germanic vs Romance languages)
  test('it should translate with variables', () async {
    await signalTranslator!.loadLocale('en');
    var result = tlvm(
      "He came in {0}, while his partner came in at the {1} place",
      ["first", "fifth"],
    );
    expect(
      result,
      "He came in first, while his partner came in at the fifth place",
    );

    await signalTranslator!.loadLocale('nl');
    result = tlvm(
      "He came in {0}, while his partner came in at the {1} place",
      ["eerste", "vijfde"],
    );
    expect(
      result,
      "Zijn parter eindigde op de vijfde plaats, terwijl hij op de eerste plaats eindigde",
    );
  });

  test(
    'Translating keys',
        () async {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMessageHandler('flutter/assets', (message) async {
            final key = utf8.decode(message!.buffer.asUint8List());
            if (mockBundle!._mockAssets.containsKey(key)) {
              return ByteData.view(
                Uint8List.fromList(
                  utf8.encode(mockBundle!._mockAssets[key]!),
                ).buffer,
              );
            }
            return null;
          });

      await signalTranslator!.loadLocale('en');
      expect(
        tl('CAN_USE_KEY'),
        'You can also use key-value pairs to translate',
      );
    },
  );

  test(
    'it should retrieve saved locale from storage and translate using that',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (mockBundle!._mockAssets.containsKey(key)) {
          return ByteData.view(
            Uint8List.fromList(
              utf8.encode(mockBundle!._mockAssets[key]!),
            ).buffer,
          );
        }
        return null;
      });

      // Save locale to storage
      await signalTranslator!.loadLocale('es');
      expect(tl('English'), 'Inglés');

      // Simulate app restart by creating a new instance
      signalTranslator = SignalTranslator();
      await Future.delayed(const Duration(milliseconds: 100));

      // Should retrieve 'es' from storage and use it
      expect(signalTranslator!.currentLocale, 'es');
      expect(tl('English'), 'Inglés');
    },
  );

  test('Test pluralization for "I have {0} apples"', () async {
    // Update mock asset to include plural key
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
    mockBundle = MockAssetBundle({
      'assets/translations/en.json': pluralJson,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (mockBundle!._mockAssets.containsKey(key)) {
            return ByteData.view(
              Uint8List.fromList(
                utf8.encode(mockBundle!._mockAssets[key]!),
              ).buffer,
            );
          }
          return null;
        });
    await signalTranslator!.loadLocale('en');
    expect(tlp('I have {0} apples', 0), 'I have no apples');
    expect(tlp('I have {0} apples', 1), 'I have 1 apple');
    expect(tlp('I have {0} apples', 2), 'I have 2 apples');
    expect(tlp('I have {0} apples', 42), 'I have 42 apples');
  });

  test('Test pluralization for multiple counts (strawberries and bananas)', () async {
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
    mockBundle = MockAssetBundle({
      'assets/translations/en.json': pluralMultiJson,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (mockBundle!._mockAssets.containsKey(key)) {
            return ByteData.view(
              Uint8List.fromList(
                utf8.encode(mockBundle!._mockAssets[key]!),
              ).buffer,
            );
          }
          return null;
        });
    await signalTranslator!.loadLocale('en');
    expect(tlpm('I have {0} strawberries and {1} bananas', [0, 0]), 'I have no strawberries and no bananas');
    expect(tlpm('I have {0} strawberries and {1} bananas', [1, 1]), 'I have 1 strawberry and 1 banana');
    expect(tlpm('I have {0} strawberries and {1} bananas', [1, 3]), 'I have 1 strawberry and 3 bananas');
    expect(tlpm('I have {0} strawberries and {1} bananas', [2, 1]), 'I have 2 strawberries and 1 banana');
    expect(tlpm('I have {0} strawberries and {1} bananas', [2, 5]), 'I have 2 strawberries and 5 bananas');
    // Fallback to key if not found
    expect(tlpm('nonexistent_key', [1, 2]), 'nonexistent_key');
  });
}
