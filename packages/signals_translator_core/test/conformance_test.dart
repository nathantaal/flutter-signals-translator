import 'package:signals_translator_core/signals_translator_core.dart';
import 'package:translator_conformance/translator_conformance.dart';

class _PlainTranslator extends TranslatorCore {
  factory _PlainTranslator() => _current;

  static _PlainTranslator _current = _PlainTranslator._();

  _PlainTranslator._() : super(plainCell);

  static void reset() {
    _current._retire();
    _current = _PlainTranslator._();
  }

  void _retire() => detachObserver();
}

void main() => runTranslatorConformance(
  TranslatorHarness(
    create: _PlainTranslator.new,
    reset: _PlainTranslator.reset,
    tl: (k) => translate(_PlainTranslator(), k),
    tlv: (k, v) => translate(_PlainTranslator(), k, [v]),
    tlvm: (k, vs) => translate(_PlainTranslator(), k, vs),
    tlp: (k, c) => translatePlural(_PlainTranslator(), k, [c]),
    tlpm: (k, cs) => translatePlural(_PlainTranslator(), k, cs),
  ),
);
