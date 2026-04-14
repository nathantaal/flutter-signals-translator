import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';

class SignalTranslator {
  // Make the TranslationService a singleton
  factory SignalTranslator() => _current;

  static SignalTranslator _current = SignalTranslator._internal();

  /// Swaps the singleton for a fresh instance so tests start from a clean
  /// slate without needing to reset fields by hand. Each new state field added
  /// to [SignalTranslator] is reset automatically because a new instance is
  /// constructed.
  @visibleForTesting
  static void debugReset() {
    _current = SignalTranslator._internal();
  }

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

  /// Locale used to load translations when the resolved locale's asset is
  /// missing or unparsable. Defaults to `'en'`. Set this before the first
  /// [loadLocale] call (or bundle a matching asset) to customise it.
  String fallbackLocale = 'en';

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
    if (prefs.getString('locale') == locale) return;
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
    // Persist the user's intent (e.g. 'sys') before attempting to load assets,
    // so the preference survives even when the resolved asset is missing.
    _chosenLocale.value = locale;
    await _saveLocaleToStorage(locale);

    final primary = assetLocationString.value;
    final fallback = 'assets/translations/$fallbackLocale.json';
    final candidates =
        primary == fallback ? <String>[primary] : <String>[primary, fallback];

    for (final path in candidates) {
      try {
        await _loadTranslationsFromAsset(path);
        return;
      } on FlutterError catch (e) {
        debugPrint('signals_translator: asset not found at $path ($e)');
      } on FormatException catch (e) {
        debugPrint('signals_translator: malformed translations at $path ($e)');
      }
    }
    // Every candidate failed — degrade to key-as-value mode.
    _clearTranslations();
  }

  Future<void> _loadTranslationsFromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath, cache: false);
    final Map<String, dynamic> decodedJson = json.decode(raw);
    if (!decodedJson.containsKey('translations')) {
      throw const FormatException('Translations key not found in the JSON file');
    }
    _translations.value = decodedJson['translations'] as Map<String, dynamic>;
  }

  void _clearTranslations() {
    _translations.value = {};
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
      List<String> forms =
          counts.map((c) {
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
