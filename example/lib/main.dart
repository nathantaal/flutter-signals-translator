import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:signals_translator/signals_translator.dart';
import 'icu_example_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    Watch(
      (context) {
        final translator = SignalTranslator();
        final localeOptions = <String, String>{
          'sys': 'System',
          'en': 'English',
          'en_GB': 'English (UK)',
          'nl': 'Dutch',
          'es': 'Spanish',
        };
        final selectedLocale =
            localeOptions.containsKey(translator.currentLocale)
                ? translator.currentLocale
                : 'sys';
        return MaterialApp(
          theme: ThemeData(primarySwatch: Colors.blue),
          home: Scaffold(
            appBar: AppBar(
              title: Text(tl('Signal Translator Example')),
            ),
            body: Builder(
              builder: (context) => Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 760),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedLocale,
                              decoration: InputDecoration(
                                labelText: 'Language',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                if (value == null) return;
                                translator.loadLocale(value);
                              },
                              items: localeOptions.entries
                                  .map(
                                    (entry) => DropdownMenuItem<String>(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'ICU message format (recommended)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'See plural, select, and nested-variable examples in action.',
                                ),
                                SizedBox(height: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.translate),
                                  label: const Text('Open ICU Examples'),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => IcuExampleScreen(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Locale diagnostics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                SizedBox(height: 8),
                                Text('System locale: ${translator.systemLocale}'),
                                Text('Current locale: ${translator.currentLocale}'),
                                Text('Resolved locale: ${translator.resolvedLocale}'),
                                Text('Fallback locale: ${translator.fallbackLocale}'),
                                Text('Requested asset: ${translator.assetLocationString.value}'),
                                Text('Active asset: ${translator.activeAssetPath ?? 'none loaded'}'),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Translate (tl) examples', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                SizedBox(height: 8),
                                Text(tl('Dutch')),
                                Text(tl('English')),
                                Text(tl('Spanish')),
                                Text(tl('CAN_USE_KEY')),
                                SizedBox(height: 12),
                                Text(
                                  'Regional variants - switch between "English" and "English (UK)" to compare:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(tl('My favorite color is blue.')), // colour (UK) vs color (US)
                                Text(tl('I took the elevator to the 5th floor.')), // lift (UK) vs elevator (US)
                                SizedBox(height: 12),
                                Text('Translate with variable (tlv) example:', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  tlv(
                                    '{0} has won the game', 'David',
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text('Translate with multiple variables (tlmv) example:', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  tlvm(
                                    'He came in {0}, while his partner came in at the {1} place',
                                    ['first', 'second'],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text('Pluralization (tlp) examples:', style: TextStyle(fontWeight: FontWeight.bold)),
                                // ignore: deprecated_member_use
                                Text(tlp('I have {0} apples', 0) ?? ''),
                                // ignore: deprecated_member_use
                                Text(tlp('I have {0} apples', 1) ?? ''),
                                // ignore: deprecated_member_use
                                Text(tlp('I have {0} apples', 5) ?? ''),
                                SizedBox(height: 8),
                                Text('Pluralization with multiple counts (tlpm) examples:', style: TextStyle(fontWeight: FontWeight.bold)),
                                // ignore: deprecated_member_use
                                Text(tlpm('I have {0} strawberries and {1} bananas', [1, 1]) ?? ''),
                                // ignore: deprecated_member_use
                                Text(tlpm('I have {0} strawberries and {1} bananas', [0, 0]) ?? ''),
                                // ignore: deprecated_member_use
                                Text(tlpm('I have {0} strawberries and {1} bananas', [2, 3]) ?? ''),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
