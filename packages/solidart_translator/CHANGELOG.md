## 1.0.0

* Initial release, at parity with signals_translator 1.0.0.
* Plurals are ICU-only: there is no `tlp`/`tlpm` and no nested
  `zero`/`one`/`other` JSON format. Asset files must use canonical names
  (`en_GB.json`, not `en-gb.json`). There is no `assetLocationString`
  (use `activeAssetPath`) and no public `prefs`. All of these were removed
  from signals_translator in 1.0.0 as **BREAKING** changes.
* New `translationsPath` setting to load translation files from another
  directory, such as a shared package's assets
  (`packages/<name>/assets/translations`).
* Requires Flutter 3.41+ / Dart 3.11 (via `shared_preferences` 2.5.6).
  `intl` stays at `>=0.20.2` so apps using `flutter_localizations` on
  Flutter 3.41–3.44 still resolve.
