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