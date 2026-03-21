**Until this package reaches 1.0.0, every version update *could* contain breaking changes. I'll try to deprecate things a few versions ahead**

# Signal translator
This is a translation package for the Signals framework. It's not a pluralization package.

For my own project, I needed a lightweight translation solution that could be used in dart.
I previously used the `easy_localization` package, but I didn't like how it made my app re-render.
This is not because of the package itself, but because I'm a Signals enthusiast.
This package currently fits all my needs, but it might not fit yours.
Please read the (non) features section to see if this package fits your needs.
And feel free to open an issue or a PR if you want to add something.

## License
Licensed under a MIT License.

## (Non) features
* Supports singular and pluralization (via inline ICU format; nested JSON keys are deprecated)
* ICU-style `plural` and `select` blocks embedded directly in translation strings
* Display app in system language by default
* Support setting a different language
* Supports setting system language as default
* **Only supports JSON translation files**
* **Does not support dates**


## Getting started
### important
1. All the components that use translations must use some kind of Watch functionality as described in the Signals package.
1. Text widgets cannot be constants anymore, since their Signals. Although this completely logical, it might have some impact on performance.

### Steps
1. In root, create a folder called `assets/translations/`
2. In the `assets/translations/` folder, create a JSON file for each language you want to support. The name of the file should be the language code (e.g. `en.json`, `fr.json`, etc.). The content of the file should be a JSON object with key-value pairs for each translation:
```json
{
  "language": "English",
  "translations": {
    "example translation": "example translation",
    "example translation 2": "example translation 2"
  }
}
```

3. Add the following to your `pubspec.yaml` file:
```yaml
dependencies:
  signals_translator: ^0.0.3

  [...]

  flutter:
  assets:
    - assets/translations/
```
Then run `flutter pub get` to install the package.

4. Add a widget that needs translating
```dart
import 'package:signals/signals_flutter.dart';
import 'package:signals_translator/signals_translator.dart';

Watch(
  (context) => Text(
    tl('example translation'),
  )
);

```

5. To set the language, you can use the `loadLocale` method of the `SignalTranslator` class. This method takes a `String` parameter that represents the language code (e.g. `en`, `fr`, etc.).
```dart
SignalTranslator().loadLocale('en');
```

5. To view the currently set language:
```dart
SignalTranslator().currentLocale;
```
This is done automatically when the app starts, but if you want to build in a language selector, you can use this method to highlight the currently selected language.

## Examples

### Basic translation (tl)
```json
{
  "English": "English"
}
```
```dart
Text(tl('English'));
```

### Translation with a variable (tlv)
```json
"{0} has won the game!": "{0} has won the game!"
```
```dart
Text(tlv('{0} has won the game!', 'David'));
```

### Translation with multiple variables (tlvm)
```json
"He came in {0}, while his partner came in at the {1} place": "He came in {0}, while his partner came in at the {1} place",
```
```dart
Text(tlvm('He came in {0}, while his partner came in at the {1} place', ['first', 'second']));
```

### Pluralization (tlp) — deprecated

> **Deprecated.** Use `tlv` with an ICU plural block instead (see [ICU message format](#icu-message-format) below).

```dart
// Before
Text(tlp('I have {0} apples', 5));

// After — flat ICU string + tlv
// "apples": "{0, plural, =0 {I have no apples} one {I have # apple} other {I have # apples}}"
Text(tlv('apples', '5'));
```

### Pluralization with multiple counts (tlpm) — deprecated

> **Deprecated.** Use `tlvm` with ICU plural blocks instead (see [ICU message format](#icu-message-format) below).

```dart
// Before
Text(tlpm('I have {0} strawberries and {1} bananas', [2, 3]));

// After — flat ICU string + tlvm
// "fruit": "{0, plural, =0 {no strawberries} one {# strawberry} other {# strawberries}} and {1, plural, =0 {no bananas} one {# banana} other {# bananas}}"
Text(tlvm('fruit', ['2', '3']));
```

---

## ICU message format

ICU-style `{N, plural, ...}` and `{N, select, ...}` blocks can be embedded directly inside any translation string value. They are resolved automatically by `tl`, `tlv`, and `tlvm` — no separate function needed.
ICU is a recognized international standard.
This solves problems the nested-JSON plural approach cannot, such as **verb agreement** ("There *is* 1 winner" vs "There *are* 5 winners") where the entire sentence structure changes, not just a noun.

### Syntax

```
{variableIndex, plural,  form1 {text} form2 {text} ...}
{variableIndex, select,  value1 {text} value2 {text} other {text}}
```

- `variableIndex` — zero-based index matching the variable passed to `tlv`/`tlvm`.
- Inside a form body, `#` is replaced with the count value.
- Remaining `{N}` placeholders in the output are substituted normally after ICU resolution.
- Multiple ICU blocks can appear in the same string.

### Plural forms

| Key | When used |
|-----|-----------|
| `=N` | Exact match — takes priority over named categories. |
| `zero` | Count is 0 (when no `=0` is present). |
| `one` | Count is 1 (when no `=1` is present). |
| `other` | All other counts, and the fallback when no exact/category match is found. |

### Example: verb agreement (is / are)

The nested-JSON approach cannot express verb changes because the *whole* sentence structure differs. ICU handles it naturally.

**en.json**
```json
"winner_announcement": "There {0, plural, one {is # winner} other {are # winners}}!"
```

**nl.json**
```json
"winner_announcement": "Er {0, plural, one {is # winnaar} other {zijn # winnaars}}!"
```

**Dart**
```dart
Text(tlv('winner_announcement', '1'));  // There is 1 winner!
Text(tlv('winner_announcement', '5'));  // There are 5 winners!
```

### Example: exact match with =0

Use `=0` (or any `=N`) for an exact-count override that takes priority over the named category.

**en.json**
```json
"inbox_count": "You have {0, plural, =0 {no messages} one {# message} other {# messages}} in your inbox."
```

**Dart**
```dart
Text(tlv('inbox_count', '0'));   // You have no messages in your inbox.
Text(tlv('inbox_count', '1'));   // You have 1 message in your inbox.
Text(tlv('inbox_count', '12'));  // You have 12 messages in your inbox.
```

### Example: multiple ICU blocks in one string

Each `{N, plural, ...}` block is resolved independently. Use `tlvm` to supply all values.

**en.json**
```json
"cart_summary": "Your cart has {0, plural, =0 {no items} one {# item} other {# items}} and {1, plural, =0 {no coupons} one {# coupon} other {# coupons}} applied."
```

**Dart**
```dart
Text(tlvm('cart_summary', ['0', '0']));  // Your cart has no items and no coupons applied.
Text(tlvm('cart_summary', ['1', '0']));  // Your cart has 1 item and no coupons applied.
Text(tlvm('cart_summary', ['3', '1']));  // Your cart has 3 items and 1 coupon applied.
Text(tlvm('cart_summary', ['2', '4']));  // Your cart has 2 items and 4 coupons applied.
```

### Example: select (gender / category)

`select` chooses a form based on a string value rather than a number. Falls back to `other` for unknown values.

**en.json**
```json
"reaction": "{0, select, female {She} male {He} other {They}} liked your post."
```

**nl.json**
```json
"reaction": "{0, select, female {Ze} male {Hij} other {Ze}} vond je bericht leuk."
```

**Dart**
```dart
Text(tlv('reaction', 'female'));    // She liked your post.
Text(tlv('reaction', 'male'));      // He liked your post.
Text(tlv('reaction', 'nonbinary')); // They liked your post.  (falls back to "other")
```

### Example: ICU plural combined with a regular {N} variable

ICU blocks and normal `{N}` placeholders can coexist. The ICU block is resolved first, then remaining `{N}` tokens are substituted.

**en.json**
```json
"search_results": "Found {0, plural, =0 {no results} one {# result} other {# results}} for \"{1}\"."
```

**Dart**
```dart
Text(tlvm('search_results', ['0', 'dart']));     // Found no results for "dart".
Text(tlvm('search_results', ['1', 'flutter']));  // Found 1 result for "flutter".
Text(tlvm('search_results', ['42', 'signals'])); // Found 42 results for "signals".
```

### Example: {N} variable inside an ICU form body

`{N}` placeholders inside form bodies are substituted normally after ICU resolution.

**en.json**
```json
"order_line": "{0, plural, one {# item costing {1}} other {# items costing {1} each}}"
```

**Dart**
```dart
Text(tlvm('order_line', ['1', '\$9.99'])); // 1 item costing $9.99
Text(tlvm('order_line', ['3', '\$4.50'])); // 3 items costing $4.50 each
```

### ICU vs nested-JSON pluralization

> **The nested-JSON approach (`tlp`/`tlpm`) is deprecated.** Prefer ICU inline for all new translation keys. Both formats still work and can coexist in the same file during migration.

| | Nested JSON (`tlp`/`tlpm`) ⚠️ deprecated | ICU inline (`tl`/`tlv`/`tlvm`) |
|---|---|---|
| Verb agreement | No | Yes |
| Exact match (`=0`, `=1` …) | No | Yes |
| `select` (gender, category) | No | Yes |
| Multiple counts in one string | Underscore-joined keys | Natural |
| Format lives in | JSON structure | Translation string |

---

## Development
Publish extension using `dart pub publish --dry-run`
