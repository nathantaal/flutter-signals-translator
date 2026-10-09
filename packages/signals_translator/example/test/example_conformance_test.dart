import 'package:signals_translator/signals_translator.dart';
import 'package:signals_translator_example/example_app.dart';
import 'package:signals_translator_example/icu_example_screen.dart';
import 'package:signals_translator_example/main.dart';
import 'package:translator_conformance/example_conformance.dart';

void main() => runExampleConformance(
  ExampleHarness(
    buildApp: () => const ExampleApp(),
    buildIcuScreen: () => const IcuExampleScreen(),
    resetTranslator: () {
      SignalTranslator.debugReset();
      configureTranslator();
    },
  ),
);
