# signals_translator_core

Shared engine behind the signals_translator family. You almost certainly
want one of the adapters instead:

- [signals_translator](https://pub.dev/packages/signals_translator) — for `signals`
- [alien_signals_translator](https://pub.dev/packages/alien_signals_translator) — for `alien_signals`
- [solidart_translator](https://pub.dev/packages/solidart_translator) — for `solidart`

This package owns locale resolution, JSON loading, persistence and ICU
lookup. Adapters plug in reactive state by implementing `ReactiveCell`.
