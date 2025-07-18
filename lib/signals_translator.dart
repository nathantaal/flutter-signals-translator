import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';

class SignalTranslator {
  // Make the TranslationService a singleton
  factory SignalTranslator() {
    return _instance;
  }

  static final SignalTranslator _instance = SignalTranslator._internal();

  late final SharedPreferences prefs;
  final Completer<void> _sharedPreferencesCompleter = Completer<void>();

  final Signal<Map<String, String>> _translations = Signal({});

  final Signal<String> _chosenLocale = Signal(
    ui.PlatformDispatcher.instance.locale.languageCode.toString(),
  );
  final Signal<String> _deviceLocale = Signal(
    ui.PlatformDispatcher.instance.locale.languageCode.toString(),
  );

  late final Computed<String> assetLocationString;
  late final Computed<String> decodedJson;

  String get currentLocale => _chosenLocale.value;

  Future<void> _initializePrefs() async {
    prefs = await SharedPreferences.getInstance();
    _sharedPreferencesCompleter.complete();
  }

  // Singleton constructor
  SignalTranslator._internal() {
    _initializePrefs();
    _loadLocaleFromStorage();

    assetLocationString = computed(
      () =>
          _chosenLocale.value == 'sys'
              ? 'assets/translations/${_deviceLocale.value}.json'
              : 'assets/translations/${_chosenLocale.value}.json',
    );
  }

  Future<void> _saveLocaleToStorage(String locale) async {
    await _sharedPreferencesCompleter.future;
    await prefs.setString('locale', locale);
  }

  Future<void> loadLocale(String locale) async {
    _chosenLocale.value = locale;

    // Decode the JSON file
    Map<String, dynamic> decodedJson = json.decode(
      await rootBundle.loadString(assetLocationString.value),
    );

    // Access the "translations" key and map its contents
    if (!decodedJson.containsKey('translations')) {
      throw Exception('Translations key not found in the JSON file');
    }

    Map<String, dynamic> translationsJson = decodedJson['translations'];
    _translations.value = translationsJson.map(
          (key, value) => MapEntry(key, value.toString()),
    );
    await _saveLocaleToStorage(locale);
  }

  Future<void> _loadLocaleFromStorage() async {
    await _sharedPreferencesCompleter.future;
    String? locale = prefs.getString('locale');

    locale != null ? await loadLocale(locale) : loadLocale(_deviceLocale.value);
  }

  String translate(String key) {
    return _translations.value[key] ?? key;
  }

  //TODO add type specificity to List (String, Number)
  String translateWithVariables(String key, List variables) {
    var translation = translate(key);
    for (var i = 0; i < variables.length; i++) {
      translation = translation.replaceFirst('{$i}', variables[i]);
    }
    return translation;
  }
}

String tl(String key) {
  return SignalTranslator().translate(key);
}

String tlv(String key, List variables) {
  return SignalTranslator().translateWithVariables(key, variables);
}
