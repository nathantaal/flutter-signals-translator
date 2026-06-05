import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Loads and validates a translation asset.
///
/// Returns the inner `translations` map on success. Throws:
///
/// - [FlutterError] if [rootBundle] can't find the asset (caller decides
///   whether that means "fall through to the next candidate" or surface).
/// - [FormatException] if the JSON is malformed or the file's shape doesn't
///   match the contract: root must be a JSON object containing a
///   `translations` key whose value is itself a JSON object.
Future<Map<String, dynamic>> loadTranslationsFromAsset(
  String assetPath,
) async {
  final raw = await rootBundle.loadString(assetPath, cache: false);
  final decoded = json.decode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException(
      'Expected a JSON object at the root, got ${decoded.runtimeType}',
    );
  }
  if (!decoded.containsKey('translations')) {
    throw const FormatException(
      'Translations key not found in the JSON file',
    );
  }
  final translations = decoded['translations'];
  if (translations is! Map<String, dynamic>) {
    throw FormatException(
      'Expected "translations" to be a JSON object, got ${translations.runtimeType}',
    );
  }
  return translations;
}
