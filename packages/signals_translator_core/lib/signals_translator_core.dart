/// Framework-agnostic core of the signals_translator packages.
library;

export 'src/reactive_cell.dart' show ReactiveCell, CellFactory;
export 'src/translation_lookup.dart'
    show
        translate,
        translatePlural,
        tlpDeprecationMessage,
        tlpmDeprecationMessage;
export 'src/translator_core.dart' show TranslatorCore;
