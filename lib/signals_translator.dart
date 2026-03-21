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

  late final Computed<String> _assetLocationString;

  String get currentLocale => _chosenLocale.value;

  Future<void> get ready => _sharedPreferencesCompleter.future;

  Future<void> _initializePrefs() async {
    prefs = await SharedPreferences.getInstance();
    _sharedPreferencesCompleter.complete();
  }

  // Singleton constructor
  SignalTranslator._internal() {
    _initializePrefs();
    _loadLocaleFromStorage();

    _assetLocationString = computed(
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

  Future<void> _loadLocaleFromStorage() async {
    await _sharedPreferencesCompleter.future;
    final locale = prefs.getString('locale');
    if (locale != null) {
      try {
        await loadLocale(locale);
      } catch (_) {
        // Stored locale file not available; fall back to device locale
        _chosenLocale.value = _deviceLocale.value;
      }
    }
  }

  Future<void> loadLocale(String locale) async {
    _chosenLocale.value = locale;
    Map<String, dynamic> decodedJson = json.decode(
      await rootBundle.loadString(_assetLocationString.value, cache: false),
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

    translation = _resolveICUBlocks(translation, variables);

    for (var i = 0; i < variables.length; i++) {
      translation = translation.replaceAll('{$i}', variables[i].toString());
    }
    return translation;
  }

  /// Parses an ICU forms string like ` one {# item} other {# items}` into a map.
  Map<String, String> _parseForms(String formsStr) {
    final forms = <String, String>{};
    int i = 0;
    while (i < formsStr.length) {
      while (i < formsStr.length && formsStr[i].trim().isEmpty) i++;
      if (i >= formsStr.length) break;

      final keyStart = i;
      while (i < formsStr.length &&
          formsStr[i] != '{' &&
          formsStr[i].trim().isNotEmpty) i++;
      final key = formsStr.substring(keyStart, i).trim();
      if (key.isEmpty) break;

      while (i < formsStr.length && formsStr[i].trim().isEmpty) i++;
      if (i >= formsStr.length || formsStr[i] != '{') break;

      i++; // skip opening {
      int depth = 1;
      final contentStart = i;
      while (i < formsStr.length && depth > 0) {
        if (formsStr[i] == '{') depth++;
        else if (formsStr[i] == '}') depth--;
        if (depth > 0) i++;
      }
      forms[key] = formsStr.substring(contentStart, i);
      i++; // skip closing }
    }
    return forms;
  }

  String _pluralCategory(int count) {
    if (count == 0) return 'zero';
    if (count == 1) return 'one';
    return 'other';
  }

  /// Resolves ICU-style inline blocks within [template].
  ///
  /// Supports `{N, plural, ...}` and `{N, select, ...}` where N is the
  /// zero-based index into [variables].
  ///
  /// Plural forms: named categories (`zero`, `one`, `other`) and exact-match
  /// selectors (`=0`, `=1`, etc.). The `#` token inside a form body is
  /// replaced with the count value. Exact matches take priority over
  /// categories; categories fall back to `other`.
  ///
  /// Select forms: the form whose key equals the variable value is chosen,
  /// falling back to `other`.
  ///
  /// Resolution is repeated until the output stabilises, so nested ICU blocks
  /// within a resolved form are also expanded.
  ///
  /// After ICU resolution the remaining `{N}` placeholders in the output are
  /// handled by the normal variable substitution pass in [_translate].
  String _resolveICUBlocks(String template, List variables) {
    String current = template;
    while (true) {
      final next = _resolveICUBlocksOnce(current, variables);
      if (next == current) break;
      current = next;
    }
    return current;
  }

  String _resolveICUBlocksOnce(String template, List variables) {
    final re = RegExp(r'\{(\d+),\s*(plural|select),');
    final buffer = StringBuffer();
    int cursor = 0;

    while (cursor < template.length) {
      final match = re.firstMatch(template.substring(cursor));
      if (match == null) {
        buffer.write(template.substring(cursor));
        break;
      }

      final matchStart = cursor + match.start;
      buffer.write(template.substring(cursor, matchStart));

      final varIndex = int.parse(match.group(1)!);
      final type = match.group(2)!;

      // Walk forward from the opening '{' counting depth to find its pair.
      int depth = 1;
      int i = matchStart + 1;
      while (i < template.length && depth > 0) {
        if (template[i] == '{') depth++;
        else if (template[i] == '}') depth--;
        i++;
      }

      final innerStart = matchStart + match.group(0)!.length;
      final formsStr = template.substring(innerStart, i - 1);
      final forms = _parseForms(formsStr);
      final value = varIndex < variables.length ? variables[varIndex] : null;

      String resolved;
      if (type == 'plural' && value != null) {
        final count =
            value is int ? value : int.tryParse(value.toString()) ?? 0;
        final form = forms['=$count'] ??
            forms[_pluralCategory(count)] ??
            forms['other'] ??
            '';
        resolved = form.replaceAll('#', count.toString());
      } else if (type == 'select' && value != null) {
        resolved = forms[value.toString()] ?? forms['other'] ?? '';
      } else {
        resolved = '';
      }

      buffer.write(resolved);
      cursor = i;
    }

    return buffer.toString();
  }

  String _translatePlural(String key, List<int> counts) {
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
      String form = value[formKey] ?? value.values.first.toString();
      // Replace {i} with counts[i] and variables[i] if present
      for (var i = 0; i < counts.length; i++) {
        form = form.replaceAll('{$i}', counts[i].toString());
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
///
/// **Deprecated:** Use [tlv] with an ICU plural block in the translation string instead.
///
/// Migration example — replace the nested JSON object:
/// ```json
/// "apples": { "zero": "No apples", "one": "One apple", "other": "{0} apples" }
/// ```
/// with a flat ICU string:
/// ```json
/// "apples": "{0, plural, =0 {No apples} one {# apple} other {# apples}}"
/// ```
/// and call `tlv('apples', count.toString())`.
@Deprecated(
  'Use tlv with an ICU plural block instead: '
  'tlv(key, count.toString()). '
  'Replace the nested zero/one/other JSON object with an inline ICU string, '
  'e.g. "{0, plural, =0 {none} one {# item} other {# items}}".',
)
String tlp(String key, int count) {
  return SignalTranslator()._translatePlural(key, [count]);
}

/// Translates a pluralized key for multiple counts using the current locale.
///
/// [key] is the translation key. [counts] is a list of numbers to determine the plural form.
/// Returns the appropriate pluralized translation string.
///
/// **Deprecated:** Use [tlvm] with ICU plural blocks in the translation string instead.
///
/// Migration example — replace the nested JSON object:
/// ```json
/// "items_coupons": { "one_one": "...", "other_other": "{0} items and {1} coupons" }
/// ```
/// with a flat ICU string:
/// ```json
/// "items_coupons": "{0, plural, one {# item} other {# items}} and {1, plural, one {# coupon} other {# coupons}}"
/// ```
/// and call `tlvm('items_coupons', counts.map((c) => c.toString()).toList())`.
@Deprecated(
  'Use tlvm with ICU plural blocks instead: '
  'tlvm(key, counts.map((c) => c.toString()).toList()). '
  'Replace the nested underscore-keyed JSON object with inline ICU strings, '
  'e.g. "{0, plural, one {# item} other {# items}} and {1, plural, one {# coupon} other {# coupons}}".',
)
String tlpm(String key, List<int> counts) {
  return SignalTranslator()._translatePlural(key, counts);
}
