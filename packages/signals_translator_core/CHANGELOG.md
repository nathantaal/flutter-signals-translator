## 0.2.0

* Initial release. Extracted from signals_translator 0.1.0.
* **BREAKING** (compared to signals_translator 0.1.0):
  * No `translatePlural`, and nested `zero`/`one`/`other` JSON objects are
    no longer read; `translate` returns the key for them. Use inline ICU
    plural blocks.
  * Only canonical asset names (`en_GB.json`) are loaded; hyphen-named
    files (`en-gb.json`) are no longer probed.
  * The persisted locale is saved in canonical form; older raw values are
    rewritten on the next start.
  * `prefs` is private. There is no `requestedAssetPath`, and adapters no
    longer expose `assetLocationString`; use `activeAssetPath`.
* With no stored locale, the system locale is now loaded at startup (it
  is not persisted). Before, nothing was loaded until `loadLocale` was
  called. This also happens when SharedPreferences fails to load.
* New `translationsPath` setting to load translation files from another
  directory, such as a shared package's assets
  (`packages/<name>/assets/translations`).
* Requires Flutter 3.41+ / Dart 3.11 (via `shared_preferences` 2.5.6).
  `intl` stays at `>=0.20.2` so apps using `flutter_localizations` on
  Flutter 3.41–3.44 still resolve.
