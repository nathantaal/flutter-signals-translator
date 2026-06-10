import '../signals_translator.dart';

/// Parses an ICU forms string like ` one {# item} other {# items}` into a map
/// of selector → form body.
Map<String, String> _parseForms(String formsStr) {
  final forms = <String, String>{};
  int i = 0;
  while (i < formsStr.length) {
    while (i < formsStr.length && formsStr[i].trim().isEmpty) {
      i++;
    }
    if (i >= formsStr.length) break;

    final keyStart = i;
    while (i < formsStr.length &&
        formsStr[i] != '{' &&
        formsStr[i].trim().isNotEmpty) {
      i++;
    }
    final key = formsStr.substring(keyStart, i).trim();
    if (key.isEmpty) break;

    while (i < formsStr.length && formsStr[i].trim().isEmpty) {
      i++;
    }
    if (i >= formsStr.length || formsStr[i] != '{') break;

    i++; // skip opening {
    int depth = 1;
    final contentStart = i;
    while (i < formsStr.length && depth > 0) {
      if (formsStr[i] == '{') {
        depth++;
      } else if (formsStr[i] == '}') {
        depth--;
      }
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

/// Resolves `{N, plural, ...}` and `{N, select, ...}` blocks inside [template]
/// using values from [variables]. Repeats until output stabilises so nested
/// blocks expand. Remaining `{N}` placeholders are handled by the caller's
/// normal substitution pass.
String _resolveICUBlocks(String template, List<Object?> variables) {
  String current = template;
  while (true) {
    final next = _resolveICUBlocksOnce(current, variables);
    if (next == current) break;
    current = next;
  }
  return current;
}

String _resolveICUBlocksOnce(String template, List<Object?> variables) {
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

    int depth = 1;
    int i = matchStart + 1;
    while (i < template.length && depth > 0) {
      if (template[i] == '{') {
        depth++;
      } else if (template[i] == '}') {
        depth--;
      }
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

String _lookupSingle(
  Map<String, dynamic> translations,
  String key, [
  List<Object?> variables = const [],
]) {
  var translation = translations[key];
  if (translation is! String) {
    translation = key;
  }
  translation = _resolveICUBlocks(translation, variables);
  for (var i = 0; i < variables.length; i++) {
    translation = translation.replaceFirst('{$i}', variables[i].toString());
  }
  return translation;
}

String? _lookupPlural(
  Map<String, dynamic> translations,
  String key,
  List<int> counts,
) {
  final value = translations[key];
  if (value is String) {
    return _lookupSingle(translations, key, counts);
  }
  if (value is Map) {
    final forms = counts.map((c) {
      if (c == 0) return 'zero';
      if (c == 1) return 'one';
      return 'other';
    }).toList();
    final formKey = forms.join('_');
    String? form = value[formKey];
    form ??= value.values.first.toString();
    for (var i = 0; i < counts.length; i++) {
      form = form?.replaceFirst('{$i}', counts[i].toString());
    }
    return form;
  }
  return key;
}

/// Translates a key using the current locale.
String tl(String key) =>
    _lookupSingle(SignalTranslator().internalTranslations, key);

/// Translates a key with a single variable using the current locale.
///
/// Also resolves `{N, plural, ...}` / `{N, select, ...}` ICU blocks in the
/// translation. For plural blocks, [variable] should be a stringified integer
/// (`count.toString()`); non-numeric values fall through to the `other` form.
String tlv(String key, String variable) =>
    _lookupSingle(SignalTranslator().internalTranslations, key, [variable]);

/// Translates a key with multiple variables using the current locale. ICU
/// blocks referenced by index are resolved before plain `{N}` substitution.
String tlvm(String key, List<String> variables) =>
    _lookupSingle(SignalTranslator().internalTranslations, key, variables);

/// Translates a pluralized key for a single count using the current locale.
///
/// **Deprecated:** Use [tlv] with an ICU plural block in the translation
/// string instead. Replace the nested JSON object:
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
String? tlp(String key, int count) =>
    _lookupPlural(SignalTranslator().internalTranslations, key, [count]);

/// Translates a pluralized key for multiple counts using the current locale.
///
/// **Deprecated:** Use [tlvm] with ICU plural blocks in the translation
/// string instead. Replace the nested underscore-keyed JSON object with
/// inline ICU strings and call
/// `tlvm(key, counts.map((c) => c.toString()).toList())`.
@Deprecated(
  'Use tlvm with ICU plural blocks instead: '
  'tlvm(key, counts.map((c) => c.toString()).toList()). '
  'Replace the nested underscore-keyed JSON object with inline ICU strings, '
  'e.g. "{0, plural, one {# item} other {# items}} and {1, plural, one {# coupon} other {# coupons}}".',
)
String? tlpm(String key, List<int> counts) =>
    _lookupPlural(SignalTranslator().internalTranslations, key, counts);
