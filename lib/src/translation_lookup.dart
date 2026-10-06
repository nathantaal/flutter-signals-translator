import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart' show Intl;

import '../signals_translator.dart';
import 'locale_canonical.dart';

void _warn(String message) {
  if (kDebugMode) debugPrint('signals_translator: $message');
}

class _Malformed implements Exception {
  const _Malformed(this.reason);

  final String reason;
}

/// Single-pass evaluator for `{N}` placeholders and
/// `{N, plural|selectordinal|select, ...}` arguments. Values are inserted
/// as-is and never re-scanned.
class _MessageFormat {
  _MessageFormat(this._src, this._values, this._key);

  final String _src;
  final List<Object?> _values;
  final String _key;
  int _pos = 0;

  late final String _locale = _pluralLocale();

  String format() {
    final out = StringBuffer();
    _message(out, null, nested: false);
    return out.toString();
  }

  /// Appends text from [_pos] to [out]. [hash] is what `#` renders as inside
  /// the nearest enclosing plural, or null outside one. When [nested], stops
  /// at the `}` closing the enclosing form and returns true; returns false if
  /// the input ends first.
  bool _message(StringBuffer out, String? hash, {required bool nested}) {
    while (_pos < _src.length) {
      final char = _src[_pos];
      if (char == '}' && nested) return true;
      if (char == '{') {
        final start = _pos;
        try {
          final argument = _argument(hash);
          if (argument != null) {
            out.write(argument);
            continue;
          }
        } on _Malformed catch (e) {
          _warn("malformed ICU argument in '$_key' at offset $start: ${e.reason}");
        }
        // Not an argument: keep a balanced group as literal text so its `}`
        // can't close an enclosing form; an unbalanced `{` is kept alone.
        final end = _matchingBrace(start);
        _pos = end == -1 ? start + 1 : end + 1;
        out.write(_src.substring(start, _pos));
      } else if (hash != null && char == '#') {
        out.write(hash);
        _pos++;
      } else if (hash != null && char == "'" && _peek(1) == '#') {
        final close = _src.indexOf("'", _pos + 1);
        if (close == -1) {
          out.write(char);
          _pos++;
        } else {
          out.write(_src.substring(_pos + 1, close));
          _pos = close + 1;
        }
      } else {
        out.write(char);
        _pos++;
      }
    }
    return !nested;
  }

  /// Parses the argument whose `{` is at [_pos]. Returns null when the text
  /// isn't an argument (e.g. `{name}`); throws [_Malformed] when it starts
  /// like an ICU block but doesn't parse.
  String? _argument(String? hash) {
    final start = _pos;
    _pos++;
    _skipWhitespace();
    final index = _digits();
    if (index.isEmpty) return null;
    final value = _valueAt(int.tryParse(index));
    _skipWhitespace();
    if (_eat('}')) return value?.toString() ?? _src.substring(start, _pos);
    if (!_eat(',')) return null;

    _skipWhitespace();
    final type = _token();
    if (type != 'plural' && type != 'selectordinal' && type != 'select') {
      throw _Malformed('unsupported argument type "$type"');
    }
    _skipWhitespace();
    if (!_eat(',')) throw _Malformed('expected "," after "$type"');

    return type == 'select'
        ? _select(value, index, hash)
        : _plural(value, index, ordinal: type == 'selectordinal');
  }

  String _plural(Object? value, String index, {required bool ordinal}) {
    _skipWhitespace();
    var offset = 0;
    if (_src.startsWith('offset:', _pos)) {
      _pos += 'offset:'.length;
      _skipWhitespace();
      offset =
          int.tryParse(_digits()) ??
          (throw const _Malformed('expected a number after "offset:"'));
    }

    final parsed = value is num ? value : num.tryParse('$value');
    final number = parsed != null && parsed.isFinite ? parsed : null;
    final adjusted = number == null ? null : number - offset;
    final hash = switch (value) {
      null => '',
      _ when adjusted == null || offset == 0 => '$value',
      _ => _formatNumber(adjusted),
    };

    final forms = _forms(hash);
    if (value == null) {
      _warn("missing value for {$index} in '$_key'");
      return '';
    }
    if (number != null) {
      for (final MapEntry(:key, value: form) in forms.entries) {
        if (key.startsWith('=') && num.tryParse(key.substring(1)) == number) {
          return form;
        }
      }
    }
    final category = switch (adjusted) {
      null => 'other',
      final num n when ordinal => _ordinalCategory(n),
      final num n => _cardinalCategory(n, _fractionDigits('$value')),
    };
    return forms[category] ?? forms['other'] ?? '';
  }

  String _select(Object? value, String index, String? hash) {
    final forms = _forms(hash);
    if (value == null) {
      _warn("missing value for {$index} in '$_key'");
      return '';
    }
    return forms['$value'] ?? forms['other'] ?? '';
  }

  /// Parses `selector {form} ...}` up to and including the closing `}`.
  Map<String, String> _forms(String? hash) {
    final forms = <String, String>{};
    while (true) {
      _skipWhitespace();
      if (_pos >= _src.length) throw const _Malformed('unclosed argument');
      if (_eat('}')) return forms;
      final selector = _token();
      if (selector.isEmpty) throw const _Malformed('expected a selector');
      _skipWhitespace();
      if (!_eat('{')) throw _Malformed('expected "{" after "$selector"');
      final body = StringBuffer();
      if (!_message(body, hash, nested: true)) {
        throw _Malformed('unclosed form "$selector"');
      }
      _pos++;
      forms.putIfAbsent(selector, () => body.toString());
    }
  }

  String _cardinalCategory(num count, int precision) => Intl.pluralLogic(
    count,
    zero: 'zero',
    one: 'one',
    two: 'two',
    few: 'few',
    many: 'many',
    other: 'other',
    locale: _locale,
    precision: precision,
    useExplicitNumberCases: false,
  );

  // intl ships cardinal rules only. English is the only built-in ordinal
  // table; every other language uses `other`.
  String _ordinalCategory(num count) {
    if (_locale.split('_').first != 'en' || count != count.truncate()) {
      return 'other';
    }
    final n = count.abs().toInt();
    if (n % 10 == 1 && n % 100 != 11) return 'one';
    if (n % 10 == 2 && n % 100 != 12) return 'two';
    if (n % 10 == 3 && n % 100 != 13) return 'few';
    return 'other';
  }

  int _matchingBrace(int open) {
    var depth = 0;
    for (var i = open; i < _src.length; i++) {
      final char = _src[i];
      if (char == '{') {
        depth++;
      } else if (char == '}' && --depth == 0) {
        return i;
      }
    }
    return -1;
  }

  Object? _valueAt(int? index) =>
      index != null && index < _values.length ? _values[index] : null;

  String? _peek(int offset) {
    final i = _pos + offset;
    return i < _src.length ? _src[i] : null;
  }

  bool _eat(String char) {
    if (_pos < _src.length && _src[_pos] == char) {
      _pos++;
      return true;
    }
    return false;
  }

  void _skipWhitespace() {
    while (_pos < _src.length && _src[_pos].trim().isEmpty) {
      _pos++;
    }
  }

  String _digits() {
    final start = _pos;
    while (_pos < _src.length) {
      final unit = _src.codeUnitAt(_pos);
      if (unit < 0x30 || unit > 0x39) break;
      _pos++;
    }
    return _src.substring(start, _pos);
  }

  String _token() {
    final start = _pos;
    while (_pos < _src.length) {
      final char = _src[_pos];
      if (char == '{' || char == '}' || char == ',' || char.trim().isEmpty) {
        break;
      }
      _pos++;
    }
    return _src.substring(start, _pos);
  }
}

String _pluralLocale() {
  final translator = SignalTranslator();
  return normalizeLocale(translator.activeLocale ?? translator.resolvedLocale);
}

String _formatNumber(num n) =>
    n == n.truncate() ? n.truncate().toString() : n.toString();

int _fractionDigits(String number) {
  final dot = number.indexOf('.');
  return dot == -1 ? 0 : number.length - dot - 1;
}

String _format(String template, List<Object?> values, String key) {
  if (!template.contains('{')) return template;
  return _MessageFormat(template, values, key).format();
}

/// Picks a form from a legacy nested-map plural using explicit numbers
/// (0 → `zero`, 1 → `one`, else `other`), joined with `_` per count.
String? _legacyPluralForm(Map<dynamic, dynamic> forms, List<int?> counts) {
  final formKey = counts
      .map((c) => switch (c) {
            0 => 'zero',
            1 => 'one',
            _ => 'other',
          })
      .join('_');
  final form = forms[formKey] ?? (forms.isEmpty ? null : forms.values.first);
  return form?.toString();
}

String _lookupSingle(String key, [List<Object?> values = const []]) {
  final translation = SignalTranslator().internalTranslations[key];
  if (translation is Map && values.isNotEmpty) {
    final counts = [
      for (final v in values) v is int ? v : int.tryParse('$v'),
    ];
    return _format(_legacyPluralForm(translation, counts) ?? key, values, key);
  }
  return _format(translation is String ? translation : key, values, key);
}

String? _lookupPlural(String key, List<int> counts) {
  final translation = SignalTranslator().internalTranslations[key];
  if (translation is! String && translation is! Map) return key;
  return _lookupSingle(key, counts);
}

/// Translates a key using the current locale.
String tl(String key) => _lookupSingle(key);

/// Translates a key with a single variable using the current locale.
///
/// Also resolves `{N, plural, ...}`, `{N, selectordinal, ...}` and
/// `{N, select, ...}` ICU blocks in the translation. Plural categories follow
/// the CLDR rules of the active locale; a [variable] that isn't a number
/// selects the `other` form and is shown as-is for `#`.
String tlv(String key, String variable) => _lookupSingle(key, [variable]);

/// Translates a key with multiple variables using the current locale. ICU
/// blocks and `{N}` placeholders are resolved in one pass, so every
/// occurrence of a placeholder is substituted and substituted values are
/// never re-read as placeholders.
String tlvm(String key, List<String> variables) =>
    _lookupSingle(key, variables);

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
String? tlp(String key, int count) => _lookupPlural(key, [count]);

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
String? tlpm(String key, List<int> counts) => _lookupPlural(key, counts);
