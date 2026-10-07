// ignore_for_file: deprecated_member_use
import 'package:signals_translator/signals_translator.dart';
import 'package:translator_conformance/translator_conformance.dart';

void main() => runTranslatorConformance(
  TranslatorHarness(
    create: SignalTranslator.new,
    reset: SignalTranslator.debugReset,
    tl: tl,
    tlv: tlv,
    tlvm: tlvm,
    tlp: tlp,
    tlpm: tlpm,
  ),
);
