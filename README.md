**Until this package reaches 1.0.0, every version update *could* contain breaking changes. I'll try to deprecate things a few versions ahead**

# Signal translator
For my own project, I needed a lightweight translation solution that could be used in Flutter.
I previously used the `easy_localization` package, but I didn't like how it made my app re-render.
This is not because of the package itself, but because I'm a Signals enthusiast.
This package currently fits all my needs, but it might not fit yours.

## License
Licensed under a modified MIT License (with a no-reselling clause).

## (Non) features
* Supports singular only, does not support pluralization
* Only supports JSON translation files
* Does not support dates

* Translates using signals
* Display app in system language by default
* Support setting a different language
* Supports setting system language as default

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
  signals_translator: ^0.0.1
  
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

5. To set the language, you can use the `setLanguage` method of the `SignalTranslator` class. This method takes a `String` parameter that represents the language code (e.g. `en`, `fr`, etc.).
```dart
SignalTranslator().setLanguage('en');
```

5. To view the currently set language:
```dart
SignalTranslator().setLanguage('en');
```
This is done automatically when the app starts, but if you want to build in a language selector, you can use this method to highlight the currently selected language.

### Full example
See the 'example' folder for a complete example.


## Additional features
More features could be implemented. As my time is limited, feel free to open an issue and I will look into when I have time.
- Planned for Q3: a dropdown menu to select the language

## Credits
All this is possible because of the best state management package out there: [Signals](https://pub.dev/packages/signals). Credits should go there :)
