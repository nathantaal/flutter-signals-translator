import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:signals_translator/signals_translator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    Watch(
      (context) => MaterialApp(
        theme: ThemeData(primarySwatch: Colors.blue),
        home: Scaffold(
          appBar: AppBar(
            title: Text(tl('Signal Translator Example')),
          ),
          body: Center(
            child: Column(
              children: [
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        SignalTranslator().loadLocale('en');
                      },
                      child: Text('English'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        SignalTranslator().loadLocale('nl');
                      },
                      child: Text('Dutch'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        SignalTranslator().loadLocale('es');
                      },
                      child: Text('Spanish'),
                    ),
                  ],
                ),
                Text(tl('Dutch')),
                Text(tl('English')),
                Text(tl('Spanish')),
                Text(
                  tlv(
                    'He came in {0}, while his partner came in at the {1} place',
                    ['first', 'second'],
                  ),
                ),
                Text(tl('CAN_USE_KEY')),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
