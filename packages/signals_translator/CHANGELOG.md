## 0.2.0

### BREAKING

* **Removed `tlp` and `tlpm`** (deprecated since 0.1.0). Use `tlv`/`tlvm`
  with inline ICU plural blocks instead.
* **Removed support for the nested `zero`/`one`/`other` JSON format.** A
  translation value that is an object is no longer read: `tl`, `tlv` and
  `tlvm` return the key. Convert each nested object to an ICU string, e.g.
  `{"zero": "No apples", "one": "1 apple", "other": "{0} apples"}` becomes
  `"{0, plural, =0 {No apples} one {# apple} other {# apples}}"`. See
  "Migrating from tlp/tlpm" in the README.
* **Hyphen-named asset files are no longer loaded.** `en-gb.json` must be
  renamed to the canonical `en_GB.json` (and `zh-hans.json` to
  `zh_Hans.json`). Before, `loadLocale('en-gb')` also probed the raw
  `en-gb.json`; now only canonical names are tried, and a missing file falls
  back to the bare language and then `fallbackLocale`.
* **The persisted locale is now saved in canonical form** (`en_GB`, not the
  raw `en-gb` or `EN_gB` passed to `loadLocale`). A raw value stored by an
  older version is still honoured and is rewritten to the canonical form on
  the next start, so users keep their chosen language.
* **Removed `assetLocationString`.** It showed the requested asset path
  before fallback, which could name a file that doesn't exist. Use
  `activeAssetPath` (the file that was actually loaded); it is reactive inside
  `SignalBuilder` and effects.
* **`prefs` is no longer public.** It threw `LateInitializationError` before
  `ready` or when SharedPreferences failed, and writing the `'locale'` key
  directly bypassed the translator. Use `loadLocale` to change the locale and
  `ready` to wait for the stored one.
* **Requires signals ^7.1.0** (signals 6.x is no longer supported). README
  and example use `SignalBuilder` instead of the deprecated `Watch`.

### Other changes

* Internals moved to the new `signals_translator_core` package.
* New sibling packages with the same API: `alien_signals_translator` and
  `solidart_translator`.
* New `translationsPath` setting to load translation files from another
  directory, such as a shared package's assets
  (`packages/<name>/assets/translations`).
* Requires Flutter 3.41+ / Dart 3.11 (via `shared_preferences` 2.5.6).
  `intl` stays at `>=0.20.2` so apps using `flutter_localizations` on
  Flutter 3.41–3.44 still resolve.

## 0.1.0

ICU message format support. `tl`, `tlv` and `tlvm` now resolve
ICU `plural`, `selectordinal` and `select` arguments inline in any
translation string.

* `{N, plural, ...}` with `=N` exact matches, CLDR plural categories
  for the active locale (`zero`/`one`/`two`/`few`/`many`/`other`, via
  `package:intl`), `offset:`, and `#` for the count (`'#'` for a
  literal `#`).
* `{N, selectordinal, ...}` with English ordinal rules; other
  languages select `other`.
* `{N, select, ...}` for gender and category choices.
* Placeholders are substituted at every occurrence, and substituted
  values are never re-read as placeholders.
* Malformed ICU renders verbatim instead of throwing; malformed blocks
  and missing ICU variables print a debug-mode warning.
* `tlp` and `tlpm` are deprecated in favour of ICU strings with
  `tlv`/`tlvm`. `tlv`/`tlvm` also read the nested zero/one/other
  format, so call sites can migrate before every locale file does.
* New `SignalTranslator().ready`: completes once SharedPreferences has
  loaded and the stored locale is applied. It completes with an error
  (instead of hanging) when SharedPreferences fails; translation keeps
  working without persistence.
* New dependency: `intl` (`>=0.19.0 <0.21.0`).

## 0.0.7

Hotfix for 0.0.6: `currentLocale` now defaults to the `'sys'` sentinel
instead of the device's regional locale string. The 0.0.6 default
(`composeDeviceLocale()`, e.g. `'en_US'`) silently broke any caller
binding a dropdown's `value:` to `currentLocale` against bare-language
items — `'en_US'` doesn't match `'en'`, so the dropdown asserted and
the page failed to render.

* `_chosenLocale` initialises to `'sys'` until a concrete locale is
  chosen via `loadLocale` or rehydrated from storage. Regional asset
  auto-pickup still works through the `'sys'` path (`resolvedLocale`
  returns the regional code from `_deviceLocale`).
* Stored locale preferences from earlier versions continue to load
  unchanged.
* Apps that want the previous "pick the device's regional locale at
  startup" behaviour can call `await loadLocale('sys')` (or any
  explicit locale) during initialisation.

## 0.0.1
## 0.0.1+1
## 0.0.1+2

* edited and clarified the documentation

## 0.0.2
* remove the reset function

## 0.0.3
* add support for (basic) pluralization

## 0.0.5
* `loadLocale` no longer throws when the resolved translation asset is missing or malformed. It now falls back to `fallbackLocale` (defaults to `'en'`, configurable via `SignalTranslator().fallbackLocale`).
* The user's chosen locale (including `'sys'`) is persisted even when its asset cannot be loaded, so the preference survives across restarts.
* Missing/malformed asset errors are now logged via `debugPrint` instead of silently swallowed.
* Added `SignalTranslator.debugReset()` static method for test isolation (replaces the old `resetForTesting()` instance method).
* Removed unused `decodedJson` computed field.
* Wire up automated publishing from GitHub Actions: explicitly request a pub.dev OIDC token and configure pub credentials so the workflow no longer falls back to interactive OAuth.

  Note: 0.0.4 was tagged but never successfully published to pub.dev (the GA workflow's auth handshake failed), so 0.0.5 is the first release with these changes.

## 0.0.6

Region- and script-aware locales — without losing the simple flow. Ship
`en_GB`, `en_US`, or `zh_Hans_CN` translation files and they're picked
up automatically. Skip them and the existing single-language usage keeps
working exactly as before; no migration, no API churn.

* Translation files at `assets/translations/<lang>[_<Script>][_<REGION>].json`
  are now discovered. Common shapes: `en.json`, `en_GB.json`,
  `zh_Hans_CN.json`.
* `loadLocale` accepts any case or separator — `en_GB`, `en-gb`, `EN_gB`,
  `zh-hans-cn` all normalize to canonical form. Non-canonical input logs
  a one-line `debugPrint` warning so misnamed files surface quickly.
* `'sys'` mode now reads `scriptCode` and `countryCode` from the device
  locale, resolving to the most specific file the app ships. OS locale
  changes are tracked reactively via
  `WidgetsBindingObserver.didChangeLocales` — any `Watch` reading
  translations rebuilds automatically.
* Fallback chain: a missing regional asset falls through to its bare
  language before reaching `fallbackLocale`
  (e.g. `en_GB → en → fallback`), deduplicated.
* New `resolvedLocale` getter returns a concrete locale string suitable
  for `intl`/`DateFormat` and other APIs that don't understand the
  `'sys'` sentinel.
* Missing-asset `debugPrint` now mentions the canonical filename form to
  help diagnose misnamed regional files.
* Concurrent reloads are serialized via a monotonic token, so an OS
  locale change racing with an explicit `loadLocale` can't let a slow
  stale asset overwrite a newer one.
* `WidgetsBindingObserver` registration is retried lazily on each
  `loadLocale` call — a `SignalTranslator` constructed before
  `WidgetsFlutterBinding.ensureInitialized()` self-heals on the next
  call.
* Malformed translation assets (root not a JSON object, `translations`
  not a map) degrade to the next fallback candidate instead of throwing.
* Fully backwards compatible: bare-language usage (`en`, `nl`, `es`)
  works unchanged, and apps that shipped legacy hyphen-separated assets
  (e.g. `en-gb.json`) keep loading them — the raw input is probed as a
  fallback candidate before the bare-language fallback, and stored prefs
  preserve the caller's original form so cross-restart lookups don't
  drift.