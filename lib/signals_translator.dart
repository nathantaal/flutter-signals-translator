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

  final Signal<Map<String, dynamic>> _translations = Signal({});

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

  // Add missing _loadLocaleFromStorage method
  Future<void> _loadLocaleFromStorage() async {
    await _sharedPreferencesCompleter.future;
    final locale = prefs.getString('locale');
    if (locale != null) {
      await loadLocale(locale);
    }
  }

  Future<void> loadLocale(String locale) async {
    _chosenLocale.value = locale;
    Map<String, dynamic> decodedJson = json.decode(
      await rootBundle.loadString(assetLocationString.value, cache: false),
    );
    if (!decodedJson.containsKey('translations')) {
      throw Exception('Translations key not found in the JSON file');
    }
    Map<String, dynamic> translationsJson = decodedJson['translations'];
    _translations.value = translationsJson;
    await _saveLocaleToStorage(locale);
  }

  String _translate(String key, [List variables = const []]) {
    var translation = _translations.value[key];
    if (translation is! String) {
      translation = key;
    }

    for (var i = 0; i < variables.length; i++) {
      translation = translation.replaceFirst('{$i}', variables[i].toString());
    }
    return translation;
  }

  String? _translatePlural(String key, List<int> counts) {
    var value = _translations.value[key];
    if (value is String) {
      // fallback to normal translation
      return _translate(key, counts);
    }
    if (value is Map) {
      // Build the plural form key, e.g. one_other, other_one, etc.
      List<String> forms = counts.map((c) {
        if (c == 0) return 'zero';
        if (c == 1) return 'one';
        return 'other';
      }).toList();
      String formKey = forms.join('_');
      String? form = value[formKey];
      form ??= value.values.first.toString();
      // Replace {i} with counts[i] and variables[i] if present
      for (var i = 0; i < counts.length; i++) {
        form = form?.replaceFirst('{$i}', counts[i].toString());
      }
      return form;
    }
    return key;
  }
}

/// Translates a key using the current locale.
///
/// Returns the translated string for the given [key].
String tl(String key) {
  return SignalTranslator()._translate(key);
}

/// Translates a key with a single variable using the current locale.
///
/// [key] is the translation key. [variable] is the value to substitute in the translation.
/// Returns the translated string with the variable substituted.
String tlv(String key, String variable) {
  return SignalTranslator()._translate(key, [variable]);
}

/// Translates a key with multiple variables using the current locale.
///
/// [key] is the translation key. [variables] is a list of values to substitute in the translation.
/// Returns the translated string with the variables substituted.
String tlvm(String key, List<String> variables) {
  return SignalTranslator()._translate(key, variables);
}

/// Translates a pluralized key for a single count using the current locale.
///
/// [key] is the translation key. [count] is the number to determine the plural form.
/// Returns the appropriate pluralized translation string.
String? tlp(String key, int count) {
  return SignalTranslator()._translatePlural(key, [count]);
}

/// Translates a pluralized key for multiple counts using the current locale.
///
/// [key] is the translation key. [counts] is a list of numbers to determine the plural form.
/// Returns the appropriate pluralized translation string.
String? tlpm(String key, List<int> counts) {
  return SignalTranslator()._translatePlural(key, counts);
}
