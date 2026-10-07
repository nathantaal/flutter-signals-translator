import 'package:alien_signals/alien_signals.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:signals_translator_core/signals_translator_core.dart';

/// Translator backed by `alien_signals`. Read translations inside oref's
/// `SignalBuilder` (or `watch(context, ...)`) so widgets rebuild when the
/// locale changes.
class SignalTranslator extends TranslatorCore {
  factory SignalTranslator() => _current;

  static SignalTranslator _current = SignalTranslator._internal();

  /// Swaps the singleton for a fresh instance so tests start from a clean
  /// slate without needing to reset fields by hand. The previous instance's
  /// `WidgetsBindingObserver` registration is detached so observers don't
  /// accumulate across tests.
  @visibleForTesting
  static void debugReset() {
    _current._retire();
    _current = SignalTranslator._internal();
  }

  SignalTranslator._internal() : super(_alienCell) {
    assetLocationString = computed((_) => requestedAssetPath);
  }

  /// Asset path for the requested locale, before fallback.
  late final Computed<String> assetLocationString;

  void _retire() => detachObserver();
}

ReactiveCell<T> _alienCell<T>(T initial) => _AlienCell<T>(signal<T>(initial));

class _AlienCell<T> implements ReactiveCell<T> {
  _AlienCell(this._signal);

  final WritableSignal<T> _signal;

  @override
  T get value => _signal();

  @override
  set value(T v) => _signal.set(v);
}

/// Translates a key using the current locale.
String tl(String key) => translate(SignalTranslator(), key);

/// Translates a key with a single variable using the current locale.
///
/// Also resolves `{N, plural, ...}`, `{N, selectordinal, ...}` and
/// `{N, select, ...}` ICU blocks in the translation. Plural categories follow
/// the CLDR rules of the active locale; a [variable] that isn't a number
/// selects the `other` form and is shown as-is for `#`.
String tlv(String key, String variable) =>
    translate(SignalTranslator(), key, [variable]);

/// Translates a key with multiple variables using the current locale. ICU
/// blocks and `{N}` placeholders are resolved in one pass, so every
/// occurrence of a placeholder is substituted and substituted values are
/// never re-read as placeholders.
String tlvm(String key, List<String> variables) =>
    translate(SignalTranslator(), key, variables);

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
@Deprecated(tlpDeprecationMessage)
String? tlp(String key, int count) =>
    translatePlural(SignalTranslator(), key, [count]);

/// Translates a pluralized key for multiple counts using the current locale.
///
/// **Deprecated:** Use [tlvm] with ICU plural blocks in the translation
/// string instead. Replace the nested underscore-keyed JSON object with
/// inline ICU strings and call
/// `tlvm(key, counts.map((c) => c.toString()).toList())`.
@Deprecated(tlpmDeprecationMessage)
String? tlpm(String key, List<int> counts) =>
    translatePlural(SignalTranslator(), key, counts);
