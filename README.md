**Until this package reaches 1.0.0, every version update *could* contain breaking changes. I'll try to deprecate things a few versions ahead**

# Signal translator
This is a translation package for the Signals framework. It's not a pluralization package.

For my own project, I needed a lightweight translation solution that could be used in dart.
I previously used the `easy_localization` package, but I didn't like how it made my app re-render.
This is not because of the package itself, but because I'm a Signals enthusiast.
This package currently fits all my needs, but it might not fit yours. 
Please read the (non) features section to see if this package fits your needs.
And feel free to open an issue or a PR if you want to add something.

## License
Licensed under a MIT License. 

## (Non) features
* Supports singular and pluralization
* Display app in system language by default
* Support setting a different language
* Supports setting system language as default
* **Only supports JSON translation files**
* **Does not support dates**


## Getting started
### important
1. All the components that use translations must use some kind of Watch functionality as described in the Signals package.
1. Text widgets cannot be constants anymore, since their Signals. Although this completely logical, it might have some impact on performance.

### Steps
1. In root, create a folder called `assets/translations/`
2. In the `assets/translations/` folder, create a JSON file for each language you want to support. The name of the file should be the language code (e.g. `en.json`, `fr.json`, etc.). The content of the file should be a JSON object with key-value pairs for each translation:
```json
{
  "language": "English",
  "translations": {
    "example translation": "example translation",
    "example translation 2": "example translation 2"
  }
}
```

3. Add the following to your `pubspec.yaml` file:
```yamld
dependencies:
  signals_translator: ^0.0.6
  
  [...]
  
  flutter:
  assets:
    - assets/translations/
```
Then run `flutter pub get` to install the package.

4. Add a widget that needs translating
```dart
import 'package:signals/signals_flutter.dart';
import 'package:signals_translator/signals_translator.dart';

Watch(
  (context) => Text(
    tl('example translation'), 
  )
);

```

5. To set the language, you can use the `loadLocale` method of the `SignalTranslator` class. This method takes a `String` parameter that represents the language code (e.g. `en`, `fr`, etc.).
```dart
SignalTranslator().loadLocale('en');
```

5. To view the currently set language:
```dart
SignalTranslator().currentLocale;
```
This is done automatically when the app starts, but if you want to build in a language selector, you can use this method to highlight the currently selected language.

If you need a concrete locale string for APIs like `intl`'s `DateFormat` — which don't understand the `'sys'` sentinel — use `resolvedLocale` instead. It returns `currentLocale` for explicit choices and the device locale when `'sys'` is selected:
```dart
SignalTranslator().resolvedLocale;
```

## Examples
### Basic translation (tl)
```json
{
  "English": "English"
}
```
```dart
Text(tl('English'));
```

### Translation with a variable (tlv)
```json
"{0} has won the game!": "{0} has won the game!"
```
```dart
Text(tlv('{0} has won the game!', 'David'));
```

### Translation with multiple variables (tlvm)
```json
"He came in {0}, while his partner came in at the {1} place": "He came in {0}, while his partner came in at the {1} place",
```
```dart
Text(tlvm('He came in {0}, while his partner came in at the {1} place', ['first', 'second']));
```

### Pluralization (tlp)
```json
    "I have {0} apples": {
      "zero": "I have no apples",
      "one": "I have 1 apple",
      "other": "I have {0} apples"
    },
```
```dart
Text(tlp('I have {0} apples', 0)); // I have no apples
Text(tlp('I have {0} apples', 1)); // I have 1 apple
Text(tlp('I have {0} apples', 5)); // I have 5 apples
```

### Pluralization with multiple counts (tlpm)
```json
"I have {0} strawberries and {1} bananas": {
  "zero_zero": "I have no strawberries and no bananas",
  "one_one": "I have 1 strawberry and 1 banana",
  "one_other": "I have 1 strawberry and {1} bananas",
  "other_one": "I have {0} strawberries and 1 banana",
  "other_other": "I have bo strawberries and {1} bananas"
}
```

```dart
Text(tlpm('I have {0} strawberries and {1} bananas', [1, 1])); // I have 1 strawberry and 1 banana
Text(tlpm('I have {0} strawberries and {1} bananas', [0, 0])); // I have no strawberries and no bananas
Text(tlpm('I have {0} strawberries and {1} bananas', [2, 3])); // I have bo strawberries and 3 bananas
```

#### Note on pluralization:
For English, the text 'I have no strawberries and no bananas' is grammarly same as 'I have 0 strawberries and 0 bananas'. That means that you don't have to add a 'zero' entry for 'no strawberries and no bananas'. zero and other is sufficient. But for 
See the 'example' folder for a complete example.

## Regional locales

You can ship region-specific translation files alongside the generic ones.
Files use the canonical name `<lang>_<REGION>.json`:

```
assets/translations/
  en.json
  en_GB.json
  en_US.json
  nl.json
```

Then call `loadLocale` with the regional code:

```dart
SignalTranslator().loadLocale('en_GB');
```

If `en_GB.json` is missing, the package falls back to `en.json`, then to your
configured `fallbackLocale` (and then to its bare language if regional). This
means you can introduce regional files incrementally. Then you can use this otherwise in your application, for example 
when formatting dates per region, while still using the generic `en` translations for text.

Input is case- and separator-tolerant: `'en_GB'`, `'en-gb'`, and `'EN_gB'`
all resolve to the same canonical form. Non-canonical input logs a one-line
`debugPrint` warning so typos are visible in debug builds.

Wiring from `MaterialApp`'s `Locale` is a one-liner:

```dart
final code = l.countryCode == null
    ? l.languageCode
    : '${l.languageCode}_${l.countryCode}';
SignalTranslator().loadLocale(code);
```

## Development
Publish extension using dart pub publish --dry-run

## Considerations
* Plural 'like there are / is  5 / winners' is not supported yet, might consider ICU here for the future..