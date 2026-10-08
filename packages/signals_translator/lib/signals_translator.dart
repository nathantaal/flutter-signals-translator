import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:signals/signals.dart';
import 'package:signals_translator_core/signals_translator_core.dart';

/// Translator backed by `signals`. Read translations inside a `SignalBuilder`
/// (from `package:signals/signals_flutter.dart`) so widgets rebuild when the
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

  SignalTranslator._internal() : super(_signalCell);

  void _retire() => detachObserver();
}

ReactiveCell<T> _signalCell<T>(T initial) => _SignalCell<T>(Signal<T>(initial));

class _SignalCell<T> implements ReactiveCell<T> {
  _SignalCell(this._signal);

  final Signal<T> _signal;

  @override
  T get value => _signal.value;

  @override
  set value(T v) => _signal.value = v;
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
