import '../signals_translator.dart';

String _lookupSingle(
  Map<String, dynamic> translations,
  String key, [
  List<Object?> variables = const [],
]) {
  var translation = translations[key];
  if (translation is! String) {
    translation = key;
  }
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
String tlv(String key, String variable) =>
    _lookupSingle(SignalTranslator().internalTranslations, key, [variable]);

/// Translates a key with multiple variables using the current locale.
String tlvm(String key, List<String> variables) =>
    _lookupSingle(SignalTranslator().internalTranslations, key, variables);

/// Translates a pluralized key for a single count using the current locale.
String? tlp(String key, int count) =>
    _lookupPlural(SignalTranslator().internalTranslations, key, [count]);

/// Translates a pluralized key for multiple counts using the current locale.
String? tlpm(String key, List<int> counts) =>
    _lookupPlural(SignalTranslator().internalTranslations, key, counts);
