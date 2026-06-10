import 'dart:ui' as ui;
import 'package:flutter/widgets.dart' show WidgetsBinding;

final RegExp _localeSeparator = RegExp(r'[_-]');
final RegExp _alphaSubtag = RegExp(r'^[A-Za-z]+$');
final RegExp _numericSubtag = RegExp(r'^\d+$');

/// Normalizes a locale input string to canonical form.
///
/// - `'sys'` is preserved as the sentinel meaning "follow the device locale".
/// - Otherwise normalizes each locale subtag and joins with `_`.
/// - Language subtags are lowercased (`en`), script subtags are title-cased
///   (`Hans`), region subtags are uppercased (`GB`), and variants are
///   lowercased.
/// - Case-variants of `'sys'` (e.g. `'SYS'`, `'Sys'`) are NOT collapsed into
///   the sentinel — they're returned as-is so they don't silently switch
///   the caller into system-locale mode.
String normalizeLocale(String input) {
  if (input == 'sys') return 'sys';

  final parts = input
      .split(_localeSeparator)
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return input;

  final normalized = <String>[parts.first.toLowerCase()];
  for (final part in parts.skip(1)) {
    normalized.add(_normalizeLocaleSubtag(part));
  }
  final result = normalized.join('_');
  if (result == 'sys') return input;
  return result;
}

String _normalizeLocaleSubtag(String part) {
  if (part.length == 4 && _alphaSubtag.hasMatch(part)) {
    final lower = part.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }
  if ((part.length == 2 && _alphaSubtag.hasMatch(part)) ||
      (part.length == 3 && _numericSubtag.hasMatch(part))) {
    return part.toUpperCase();
  }
  return part.toLowerCase();
}

/// Yields progressively shorter locale variants by stripping one trailing
/// subtag at a time. Input must be a canonical underscore-joined string.
/// `'zh_Hans_CN'` yields `'zh_Hans_CN'`, `'zh_Hans'`, `'zh'`.
Iterable<String> localeFallbackCandidates(String locale) sync* {
  final parts = locale.split('_');
  for (var length = parts.length; length > 0; length--) {
    yield parts.take(length).join('_');
  }
}

/// Returns the current device locale as a canonical underscore-joined
/// string, including `scriptCode` and `countryCode` when the OS reports
/// them (e.g. `zh_Hans_CN`).
///
/// Prefers the binding's platform dispatcher so test overrides via
/// `localeTestValue` are respected; falls back to the raw instance when the
/// binding has not yet been initialised (e.g. very early in `main()`).
String composeDeviceLocale() {
  ui.PlatformDispatcher dispatcher;
  try {
    dispatcher = WidgetsBinding.instance.platformDispatcher;
  } catch (_) {
    dispatcher = ui.PlatformDispatcher.instance;
  }
  final locale = dispatcher.locale;
  final parts = <String>[locale.languageCode];
  final script = locale.scriptCode;
  if (script != null && script.isNotEmpty) parts.add(script);
  final country = locale.countryCode;
  if (country != null && country.isNotEmpty) parts.add(country);
  return parts.join('_');
}
