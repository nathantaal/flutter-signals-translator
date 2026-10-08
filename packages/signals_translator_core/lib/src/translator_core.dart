import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show Locale, WidgetsBinding, WidgetsBindingObserver;
import 'package:shared_preferences/shared_preferences.dart';

import 'locale_canonical.dart';
import 'reactive_cell.dart';
import 'translation_loader.dart';

/// Framework-agnostic translator state and locale logic.
///
/// Adapter packages subclass this, pass a [CellFactory] backed by their
/// reactive framework, and expose the subclass as a singleton.
abstract class TranslatorCore with WidgetsBindingObserver {
  TranslatorCore(CellFactory cell)
    : _translations = cell<Map<String, dynamic>>({}),
      _chosenLocale = cell<String>('sys'),
      _deviceLocale = cell<String>(composeDeviceLocale()),
      _activeLocale = cell<String?>(null) {
    _ensureObserverAttached();
    // The error stays observable through [ready]; ignore() only stops it from
    // being reported as unhandled when nobody awaits it.
    _ready = _initialize()..ignore();
  }

  late final SharedPreferences _prefs;
  // Resolves to null when SharedPreferences failed to load.
  final Completer<SharedPreferences?> _prefsCompleter = Completer();
  late final Future<void> _ready;

  final ReactiveCell<Map<String, dynamic>> _translations;

  // Until the consumer (or stored prefs) picks a concrete locale, follow the
  // system. In 0.0.6 this defaulted to `composeDeviceLocale()`, which broke
  // any caller binding a dropdown to `currentLocale` against bare-language
  // items — `'en_US'` doesn't match `'en'`. Defaulting to the `'sys'`
  // sentinel keeps the regional auto-pickup (it still resolves through
  // `_deviceLocale`) without forcing every consumer to strip regions before
  // displaying the choice.
  final ReactiveCell<String> _chosenLocale;
  final ReactiveCell<String> _deviceLocale;
  final ReactiveCell<String?> _activeLocale;

  // Monotonic counter that lets a later [_reloadTranslationsForResolvedLocale]
  // call invalidate an in-flight earlier one — so a slow stale asset load can't
  // overwrite the result of a newer reload.
  int _reloadSeq = 0;

  /// Locale used to load translations when the requested locale's asset (and
  /// its bare-language variant, if regional) cannot be resolved. Defaults to
  /// `'en'`. Accepts the same case/separator-tolerant input as [loadLocale]
  /// and is normalized to canonical form when consulted. If the fallback is
  /// itself regional (e.g. `'fr_CA'`), its bare-language form (`'fr'`) is
  /// tried as well — so the full chain on a miss is
  /// `<requested> → <bare-of-requested> → <fallback> → <bare-of-fallback>`,
  /// deduplicated. Only canonical asset names (`en_GB.json`) are probed. Set
  /// [fallbackLocale] before the first [loadLocale] call (or bundle a
  /// matching asset) to customise it.
  String fallbackLocale = 'en';

  /// Asset directory that `<locale>.json` files are loaded from. Defaults to
  /// `'assets/translations'`. To load translations bundled by another
  /// package, use Flutter's package asset prefix, e.g.
  /// `'packages/my_translations/assets/translations'`. Trailing slashes are
  /// ignored. Like [fallbackLocale], set it right after first accessing the
  /// translator (before awaiting anything) so the stored locale loaded at
  /// startup uses it too.
  String get translationsPath => _translationsPath;
  set translationsPath(String path) =>
      _translationsPath = path.replaceFirst(RegExp(r'/+$'), '');
  String _translationsPath = 'assets/translations';

  String _assetPath(String locale) => '$_translationsPath/$locale.json';

  String get currentLocale => _chosenLocale.value;

  /// Completes once SharedPreferences has loaded and the stored locale, if
  /// any, has been applied — so its translations are available.
  ///
  /// Completes with an error when SharedPreferences can't be loaded.
  /// Translation keeps working in that case; locale choices just aren't
  /// persisted. With no stored locale nothing is loaded at startup; call
  /// [loadLocale] (e.g. with `'sys'`) to load one.
  Future<void> get ready => _ready;

  /// Returns the current locale reported by the operating system.
  ///
  /// This value updates when the platform locale changes.
  String get systemLocale => _deviceLocale.value;

  /// Returns a concrete locale string suitable for APIs that don't understand
  /// the `'sys'` sentinel (e.g. `intl`'s `DateFormat`, number formatters).
  ///
  /// When the user has selected a specific locale this matches [currentLocale].
  /// When `'sys'` is selected this resolves to the device locale signal, which
  /// stays current via [didChangeLocales] — a rebuild widget reading this getter
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
    return _assetPath(locale);
  }

  /// Detaches this instance from [WidgetsBinding]. Adapters call this when
  /// retiring a singleton in `debugReset()`.
  @protected
  void detachObserver() => _detachObserver();

  /// The currently loaded translation map. Exposed for [translate]; don't
  /// read from external code — use the adapter's `tl` / `tlv` / `tlvm`
  /// instead.
  Map<String, dynamic> get internalTranslations => _translations.value;

  Future<void> _initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      _prefsCompleter.complete(null);
      debugPrint(
        'signals_translator: SharedPreferences unavailable; locale choices will not persist ($e)',
      );
      rethrow;
    }
    _prefsCompleter.complete(_prefs);
    await _loadLocaleFromStorage();
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
    final storage = await _prefsCompleter.future;
    if (storage == null || storage.getString('locale') == locale) return;
    await storage.setString('locale', locale);
  }

  Future<void> _loadLocaleFromStorage() async {
    final locale = _prefs.getString('locale');
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
    // Persist the canonical form; a raw value stored by an older version
    // (e.g. 'en-gb') is rewritten the first time it's loaded.
    await _saveLocaleToStorage(_chosenLocale.value);
    await _reloadTranslationsForResolvedLocale();
  }

  Future<void> _reloadTranslationsForResolvedLocale() async {
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
    for (final candidate in localeFallbackCandidates(resolved)) {
      addCandidate(candidate);
    }
    for (final candidate in localeFallbackCandidates(normalizedFallback)) {
      addCandidate(candidate);
    }

    for (final candidate in candidates) {
      final path = _assetPath(candidate);
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
