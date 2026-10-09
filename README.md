# signals_translator monorepo

JSON-based i18n with ICU message format for Flutter, for three reactive
frameworks. All packages share one engine and one version.

| Package | For |
|---|---|
| [signals_translator](packages/signals_translator) | `signals` |
| [alien_signals_translator](packages/alien_signals_translator) | `alien_signals` (+ oref) |
| [solidart_translator](packages/solidart_translator) | `solidart` (+ flutter_solidart) |
| [signals_translator_core](packages/signals_translator_core) | shared engine |

## Development

    dart tool/each.dart flutter pub get
    dart tool/each.dart flutter test
    dart tool/each.dart flutter analyze

All three examples load their translation files from one place: the
unpublished `tool/example_translations` package, via
`SignalTranslator().translationsPath`.
