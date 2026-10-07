import 'package:example_translations/example_translations.dart';
import 'package:flutter/material.dart';
import 'package:alien_signals_translator/alien_signals_translator.dart';

import 'example_app.dart';

/// Points the translator at the translation files shared by all examples.
void configureTranslator() {
  SignalTranslator().translationsPath = exampleTranslationsPath;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureTranslator();
  runApp(const ExampleApp());
}
