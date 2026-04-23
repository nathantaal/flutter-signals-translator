## 0.0.1
## 0.0.1+1
## 0.0.1+2

* edited and clarified the documentation

## 0.0.2
* remove the reset function

## 0.0.3
* add support for (basic) pluralization

## 0.0.4
* `loadLocale` no longer throws when the resolved translation asset is missing or malformed. It now falls back to `fallbackLocale` (defaults to `'en'`, configurable via `SignalTranslator().fallbackLocale`).
* The user's chosen locale (including `'sys'`) is persisted even when its asset cannot be loaded, so the preference survives across restarts.
* Missing/malformed asset errors are now logged via `debugPrint` instead of silently swallowed.
* Added `SignalTranslator.debugReset()` static method for test isolation (replaces the old `resetForTesting()` instance method).
* Removed unused `decodedJson` computed field.
* Try publishing versions from GA