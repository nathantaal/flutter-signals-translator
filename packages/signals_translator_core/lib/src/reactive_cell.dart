/// A single piece of reactive state owned by [TranslatorCore].
///
/// Adapters back this with their framework's writable signal so that reads
/// inside a tracking scope (a `SignalBuilder`, effect or computed)
/// subscribe to it.
abstract interface class ReactiveCell<T> {
  T get value;
  set value(T v);
}

/// Creates a [ReactiveCell] holding [initial].
typedef CellFactory = ReactiveCell<T> Function<T>(T initial);
