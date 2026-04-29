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