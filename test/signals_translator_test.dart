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
    expect(signalTranslator!.translate('Dutch'), 'Dutch');
    expect(signalTranslator!.translate('English'), 'English');
    expect(signalTranslator!.translate('Spanish'), 'Spanish');
  });

  test('Test other translations', () async {
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
    expect(signalTranslator!.translate('Dutch'), 'Nederlands');
    expect(signalTranslator!.translate('English'), 'English');
    expect(signalTranslator!.translate('Spanish'), 'Español');

    // For the ES variant, there is chosen to stay native to the user so they can find there language easily
    await signalTranslator!.loadLocale('es');
    expect(signalTranslator!.translate('Dutch'), 'Holandés');
    expect(signalTranslator!.translate('English'), 'Inglés');
    expect(signalTranslator!.translate('Spanish'), 'Español');
  });

  test('it should fall back to key', () => {
    //TODO
  });

  //Here you can explicitly reverse order of the variables
  //Normally, this is done for language that differ in grammar (for example, Germanic vs Romance languages)
  test('it should translate with variables', () async {
    await signalTranslator!.loadLocale('en');
    var result = signalTranslator!.translateWithVariables(
      "He came in {0}, while his partner came in at the {1} place",
      ["first", "fifth"],
    );
    expect(
      result,
      "He came in first, while his partner came in at the fifth place",
    );

    await signalTranslator!.loadLocale('nl');
    result = signalTranslator!.translateWithVariables(
      "He came in {0}, while his partner came in at the {1} place",
      ["eerste", "vijfde"],
    );
    expect(
      result,
      "Zijn parter eindigde op de vijfde plaats, terwijl hij op de eerste plaats eindigde",
    );
  });

  test(
    'it should translate using short tl function',
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
        //TODO
    },
  );
}
