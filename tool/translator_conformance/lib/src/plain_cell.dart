import 'package:signals_translator_core/signals_translator_core.dart';

/// Non-reactive [ReactiveCell], for running the suite against core alone.
class PlainCell<T> implements ReactiveCell<T> {
  PlainCell(this.value);

  @override
  T value;
}

ReactiveCell<T> plainCell<T>(T initial) => PlainCell<T>(initial);
