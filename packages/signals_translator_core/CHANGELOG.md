## 0.2.0

* Initial release. Extracted from signals_translator 0.1.0; existing
  behaviour unchanged.
* New `translationsPath` setting to load translation files from another
  directory, such as a shared package's assets
  (`packages/<name>/assets/translations`).
* Requires Flutter 3.41+ / Dart 3.11 (via `shared_preferences` 2.5.6).
  `intl` stays at `>=0.20.2` so apps using `flutter_localizations` on
  Flutter 3.41–3.44 still resolve.
