import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show Locale, WidgetsBinding, WidgetsBindingObserver;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';

import 'src/locale_canonical.dart';
import 'src/translation_loader.dart';

export 'src/translation_lookup.dart' show tl, tlv, tlvm, tlp, tlpm;

class SignalTranslator with WidgetsBindingObserver {
  // Make the TranslationService a singleton
  factory SignalTranslator() => _current;

  static SignalTranslator _current = SignalTranslator._internal();

  /// Swaps the singleton for a fresh instance so tests start from a clean
  /// slate without needing to reset fields by hand. Each new state field added
  /// to [SignalTranslator] is reset automatically because a new instance is
  /// constructed. The previous instance's [WidgetsBindingObserver] registration
  /// is also detached so observers don't accumulate across tests.
  @visibleForTesting
  static void debugReset() {
    _current._detachObserver();
    _current = SignalTranslator._internal();
  }

  late final SharedPreferences prefs;
  final Completer<void> _sharedPreferencesCompleter = Completer<void>();

  final Signal<Map<String, dynamic>> _translations = Signal({});

  final Signal<String> _chosenLocale = Signal(composeDeviceLocale());
  final Signal<String> _deviceLocale = Signal(composeDeviceLocale());
  final Signal<String?> _activeLocale = Signal(null);

  // Monotonic counter that lets a later [_reloadTranslationsForResolvedLocale]
  // call invalidate an in-flight earlier one — so a slow stale asset load can't
  // overwrite the result of a newer reload.
  int _reloadSeq = 0;

  late final Computed<String> assetLocationString;

  /// Locale used to load translations when the requested locale's asset (and
  /// its bare-language variant, if regional) cannot be resolved. Defaults to
  /// `'en'`. Accepts the same case/separator-tolerant input as [loadLocale]
  /// and is normalized to canonical form when consulted. If the fallback is
  /// itself regional (e.g. `'fr_CA'`), its bare-language form (`'fr'`) is
  /// tried as well — so the full chain on a miss is
  /// `<requested> → <raw-input> → <bare-of-requested> → <fallback> → <bare-of-fallback>`,
  /// deduplicated. The `<raw-input>` step probes the caller's
  /// pre-normalization string (e.g. `'en-gb'`) so apps that shipped legacy
  /// hyphen-named assets keep loading; it's skipped when the raw input is
  /// the `'sys'` sentinel or equals the canonical form. Set
  /// [fallbackLocale] before the first [loadLocale] call (or bundle a
  /// matching asset) to customise it.
  String fallbackLocale = 'en';

  String get currentLocale => _chosenLocale.value;

  /// Resolves once SharedPreferences has been initialized. Note: this does
  /// NOT wait for the initial locale-to-translations load triggered by
  /// `_loadLocaleFromStorage` — translations may still be empty when this
  /// completes. Use [activeLocale] or a `Watch` to react to the first
  /// successful load.
  Future<void> get ready => _sharedPreferencesCompleter.future;

  /// Returns the current locale reported by the operating system.
  ///
  /// This value updates when the platform locale changes.
  String get systemLocale => _deviceLocale.value;

  /// Returns a concrete locale string suitable for APIs that don't understand
  /// the `'sys'` sentinel (e.g. `intl`'s `DateFormat`, number formatters).
  ///
  /// When the user has selected a specific locale this matches [currentLocale].
  /// When `'sys'` is selected this resolves to the device locale signal, which
  /// stays current via [didChangeLocales] — a `Watch` reading this getter
  /// rebuilds when the OS locale changes.
  ///
  /// Use [currentLocale] when you need the user's *intent* (e.g. to drive a
  /// language-picker selection). Use [resolvedLocale] when you need a real
  /// locale string for formatting.
  String get resolvedLocale =>
      _chosenLocale.value == 'sys' ? _deviceLocale.value : _chosenLocale.value;

  /// Locale file that was actually loaded most recently, or `null` if none
  /// could be resolved.
  String? get activeLocale => _activeLocale.value;

  /// Asset path that was actually loaded most recently.
  String? get activeAssetPath {
    final locale = _activeLocale.value;
    if (locale == null) return null;
    return 'assets/translations/$locale.json';
  }

  /// The currently loaded translation map. Exposed for the `tl*` helpers
  /// in `src/translation_lookup.dart`; don't read from external code —
  /// use [tl] / [tlv] / [tlp] etc. instead.
  Map<String, dynamic> get internalTranslations => _translations.value;

  Future<void> _initializePrefs() async {
    prefs = await SharedPreferences.getInstance();
    _sharedPreferencesCompleter.complete();
  }

  // Singleton constructor
  SignalTranslator._internal() {
    _ensureObserverAttached();
    _initializePrefs();
    _loadLocaleFromStorage();

    assetLocationString = computed(
      () =>
          _chosenLocale.value == 'sys'
              ? 'assets/translations/${_deviceLocale.value}.json'
              : 'assets/translations/${_chosenLocale.value}.json',
    );
  }

  bool _observerAttached = false;

  @visibleForTesting
  bool get debugObserverAttached => _observerAttached;

  @visibleForTesting
  void debugDetachObserverForTest() => _detachObserver();

  // Idempotent: if the binding wasn't initialised at construction time (e.g.
  // the singleton was created very early in main() before
  // WidgetsFlutterBinding.ensureInitialized()), later calls will retry so
  // didChangeLocales still wires up once a binding exists.
  void _ensureObserverAttached() {
    if (_observerAttached) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      _observerAttached = true;
    } catch (_) {
      // Binding still not initialised; will retry on the next entry point.
    }
  }

  void _detachObserver() {
    if (!_observerAttached) return;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {
      // Best-effort: binding may have been torn down already.
    }
    _observerAttached = false;
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final next = composeDeviceLocale();
    if (next == _deviceLocale.value) return;

    _deviceLocale.value = next;
    if (_chosenLocale.value == 'sys') {
      unawaited(_reloadTranslationsForResolvedLocale());
    }
  }

  Future<void> _saveLocaleToStorage(String locale) async {
    await _sharedPreferencesCompleter.future;
    if (prefs.getString('locale') == locale) return;
    await prefs.setString('locale', locale);
  }

  Future<void> _loadLocaleFromStorage() async {
    await _sharedPreferencesCompleter.future;
    final locale = prefs.getString('locale');
    if (locale != null) {
      // Skip the non-canonical warning for values already in storage — the
      // developer can't act on it on every cold start. The warning still
      // fires on direct loadLocale() calls.
      await _applyLocale(locale);
    }
  }

  Future<void> loadLocale(String locale) async {
    final canonical = normalizeLocale(locale);
    if (canonical != locale) {
      debugPrint(
        "signals_translator: locale '$locale' is not canonical; using '$canonical'",
      );
    }
    await _applyLocale(locale);
  }

  Future<void> _applyLocale(String locale) async {
    _ensureObserverAttached();
    _chosenLocale.value = normalizeLocale(locale);
    // Persist the caller's original form (e.g. 'en-gb' or 'sys'). Keeping
    // the raw string lets apps shipping legacy hyphen-separated assets
    // (`en-gb.json`) keep working across restarts, and avoids silently
    // rewriting prefs values stored by older versions.
    await _saveLocaleToStorage(locale);
    await _reloadTranslationsForResolvedLocale(rawIntent: locale);
  }

  Future<void> _reloadTranslationsForResolvedLocale({String? rawIntent}) async {
    final token = ++_reloadSeq;

    // Resolve 'sys' to the device locale via the reactive signal, which is
    // kept current by [didChangeLocales] when the OS reports a locale change.
    final resolved =
        _chosenLocale.value == 'sys'
            ? _deviceLocale.value
            : _chosenLocale.value;
    final normalizedFallback = normalizeLocale(fallbackLocale);

    final candidates = <String>[];
    void addCandidate(String c) {
      if (c.isEmpty) return;
      if (!candidates.contains(c)) candidates.add(c);
    }

    addCandidate(resolved);
    // Backwards compat: probe the caller's raw input (e.g. legacy
    // `en-gb`) before falling through to bare-language / fallback, so
    // apps that shipped hyphen-named assets keep finding them. Skip the
    // 'sys' sentinel — it isn't a real locale spelling and was never a
    // valid asset name.
    if (rawIntent != null && rawIntent != 'sys') {
      addCandidate(rawIntent);
    }
    for (final candidate in localeFallbackCandidates(resolved)) {
      addCandidate(candidate);
    }
    for (final candidate in localeFallbackCandidates(normalizedFallback)) {
      addCandidate(candidate);
    }

    for (final candidate in candidates) {
      final path = 'assets/translations/$candidate.json';
      try {
        final translations = await loadTranslationsFromAsset(path);
        if (token != _reloadSeq) return;
        _translations.value = translations;
        _activeLocale.value = candidate;
        return;
      } on FlutterError {
        if (token != _reloadSeq) return;
        debugPrint(
          'signals_translator: asset not found at $path — confirm the file is named in canonical xx_XX form',
        );
      } on FormatException catch (e) {
        if (token != _reloadSeq) return;
        debugPrint('signals_translator: malformed translations at $path ($e)');
      }
    }
    if (token != _reloadSeq) return;
    _activeLocale.value = null;
    _clearTranslations();
  }

  void _clearTranslations() {
    _translations.value = {};
  }
}
