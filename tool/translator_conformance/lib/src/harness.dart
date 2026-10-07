import 'package:signals_translator_core/signals_translator_core.dart';

/// Binds the behaviour suite to one adapter.
class TranslatorHarness {
  const TranslatorHarness({
    required this.create,
    required this.reset,
    required this.tl,
    required this.tlv,
    required this.tlvm,
    required this.tlp,
    required this.tlpm,
  });

  /// Returns the adapter's singleton, i.e. `SignalTranslator()`.
  final TranslatorCore Function() create;

  /// The adapter's `SignalTranslator.debugReset`.
  final void Function() reset;

  final String Function(String key) tl;
  final String Function(String key, String variable) tlv;
  final String Function(String key, List<String> variables) tlvm;
  final String? Function(String key, int count) tlp;
  final String? Function(String key, List<int> counts) tlpm;
}
