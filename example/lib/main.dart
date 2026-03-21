import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:signals_translator/signals_translator.dart';
import 'icu_example_screen.dart';

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
          body: Builder(
            builder: (context) => Center(
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
                Text('Translate (tl) examples:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(tl('Dutch')),
                Text(tl('English')),
                Text(tl('Spanish')),
                Text(tl('CAN_USE_KEY')),
                Text('Tranlate with variable (tlv) example:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  tlv(
                    '{0} has won the game', 'David',
                  ),
                ),
                Text('Translate with multiple variables (tlmv) example:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  tlvm(
                    'He came in {0}, while his partner came in at the {1} place',
                    ['first', 'second'],
                  ),
                ),
                Text('Pluralization (tlp) examples:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(tlp('I have {0} apples', 0)), // I have no apples
                Text(tlp('I have {0} apples', 1)), // I have 1 apple
                Text(tlp('I have {0} apples', 5)), // I have 5 apples
                Text('Pluralization with multiple counts (tlpm) examples:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(tlpm('I have {0} strawberries and {1} bananas', [1, 1])), // I have 1 strawberry and 1 banana
                Text(tlpm('I have {0} strawberries and {1} bananas', [0, 0])), // I have no strawberries and no bananas
                Text(tlpm('I have {0} strawberries and {1} bananas', [2, 3])), // I have 2 strawberries and 3 bananas
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.translate),
                  label: const Text('Open ICU Examples'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => IcuExampleScreen()),
                  ),
                ),
              ],
            ),
          )),
        ),
      ),
    ),
  );
}
