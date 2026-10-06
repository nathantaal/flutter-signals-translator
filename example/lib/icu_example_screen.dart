import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:signals_translator/signals_translator.dart';

class IcuExampleScreen extends StatefulWidget {
  const IcuExampleScreen({super.key});

  @override
  State<IcuExampleScreen> createState() => _IcuExampleScreenState();
}

class _IcuExampleScreenState extends State<IcuExampleScreen> {
  final _inboxCount = signal(0);
  final _winnerCount = signal(1);
  final _cartItems = signal(0);
  final _cartCoupons = signal(1);
  final _gender = signal('female');
  final _searchCount = signal(1);
  final _searchQuery = signal('flutter');

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _searchQuery.value);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Watch(
      (context) => Scaffold(
        appBar: AppBar(title: Text(tl('ICU Examples'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _LangSwitcher(),
            const SizedBox(height: 16),

            // --- plural: exact match + verb agreement ---
            _SectionCard(
              title: 'Plural — inbox_count',
              subtitle:
                  'Uses =0 exact match and # token.\n'
                  'Key: "You have {0, plural, =0 {no messages} one {# message} other {# messages}} in your inbox."',
              result: tlv('inbox_count', _inboxCount.value.toString()),
              controls: _CounterRow(
                label: 'messages',
                value: _inboxCount.value,
                onDecrement: () {
                  if (_inboxCount.value > 0) _inboxCount.value--;
                },
                onIncrement: () => _inboxCount.value++,
              ),
            ),
            const SizedBox(height: 12),

            // --- plural: verb agreement (is/are) ---
            _SectionCard(
              title: 'Plural — winner_announcement',
              subtitle:
                  'Verb agrees with count ("is" vs "are").\n'
                  'Key: "There {0, plural, one {is # winner} other {are # winners}}!"',
              result: tlv('winner_announcement', _winnerCount.value.toString()),
              controls: _CounterRow(
                label: 'winners',
                value: _winnerCount.value,
                onDecrement: () {
                  if (_winnerCount.value > 0) _winnerCount.value--;
                },
                onIncrement: () => _winnerCount.value++,
              ),
            ),
            const SizedBox(height: 12),

            // --- multiple ICU blocks in one string ---
            _SectionCard(
              title: 'Multiple plurals — cart_summary',
              subtitle:
                  'Two independent {N, plural, ...} blocks in one string.\n'
                  'Key: "Your cart has {0, plural, ...} and {1, plural, ...} applied."',
              result: tlvm('cart_summary', [
                _cartItems.value.toString(),
                _cartCoupons.value.toString(),
              ]),
              controls: Column(
                children: [
                  _CounterRow(
                    label: 'items',
                    value: _cartItems.value,
                    onDecrement: () {
                      if (_cartItems.value > 0) _cartItems.value--;
                    },
                    onIncrement: () => _cartItems.value++,
                  ),
                  _CounterRow(
                    label: 'coupons',
                    value: _cartCoupons.value,
                    onDecrement: () {
                      if (_cartCoupons.value > 0) _cartCoupons.value--;
                    },
                    onIncrement: () => _cartCoupons.value++,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- select: gender ---
            _SectionCard(
              title: 'Select — reaction',
              subtitle:
                  'Chooses a form based on a non-numeric value.\n'
                  'Key: "{0, select, female {She} male {He} other {They}} liked your post."',
              result: tlv('reaction', _gender.value),
              controls: Row(
                children: [
                  for (final g in ['female', 'male', 'other'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(g),
                        selected: _gender.value == g,
                        onSelected: (_) => _gender.value = g,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- plural + regular {N} variable ---
            _SectionCard(
              title: 'Plural + variable — search_results',
              subtitle:
                  'ICU block and a regular {N} variable in the same string.\n'
                  'Key: "Found {0, plural, ...} for \\"{1}\\"."',
              result: tlvm('search_results', [
                _searchCount.value.toString(),
                _searchQuery.value,
              ]),
              controls: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CounterRow(
                    label: 'results',
                    value: _searchCount.value,
                    onDecrement: () {
                      if (_searchCount.value > 0) _searchCount.value--;
                    },
                    onIncrement: () => _searchCount.value++,
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'search query',
                      isDense: true,
                    ),
                    onChanged: (v) => _searchQuery.value = v,
                    controller: _searchController,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Known issues',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Each card compares the expected output with what the resolver '
              'returns today. Switch to English (UK) to see the ICU keys '
              'missing from en_GB.json. Locale-specific plural rules '
              '(fr/pl/ru/ar) and the ready future are covered by unit tests '
              'only.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final issue in _knownIssues()) ...[
              _KnownIssueCard(issue: issue),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  List<_KnownIssue> _knownIssues() => [
    _icuIssue(
      'Nested plural: # uses the outer count',
      '{0, plural, one {One basket with {1, plural, one {# apple} other {# apples}}} '
          'other {# baskets with {1, plural, one {# apple} other {# apples}}}}',
      ['1', '3'],
      'One basket with 3 apples',
    ),
    _icuIssue(
      'Non-integer count picks the =0 form',
      'You have {0, plural, =0 {no messages} one {# message} other {# messages}} in your inbox.',
      ['1.5'],
      'You have 1.5 messages in your inbox.',
    ),
    _icuIssue(
      'English has no "zero" plural category',
      '{0, plural, zero {zero form} one {# item} other {# items}}',
      ['0'],
      '0 items',
    ),
    _icuIssue(
      'Truncated block throws',
      'abc {0, plural,',
      ['1'],
      'abc {0, plural,',
    ),
    _icuIssue(
      'Unclosed block swallows the rest of the string',
      'x {0, plural, one {a} other {b}',
      ['1'],
      'x {0, plural, one {a} other {b}',
    ),
    _icuIssue(
      "Quoted '#' is not kept literal",
      "{0, plural, one {# issue, see ticket '#'{1}} other {# issues, see ticket '#'{1}}}",
      ['1', '42'],
      '1 issue, see ticket #42',
    ),
    _icuIssue(
      'Repeated placeholder is substituted only once',
      '{0} likes {1, select, female {her} other {their}} cat, says {0}.',
      ['Ann', 'female'],
      'Ann likes her cat, says Ann.',
    ),
    _icuIssue(
      'Substituted value is re-scanned for placeholders',
      '{0} and {1}',
      ['{1}', 'b'],
      '{1} and b',
    ),
    _icuIssue(
      'Whitespace after "{" is not recognised',
      '{ 0, plural, one {# item} other {# items}}',
      ['2'],
      '2 items',
    ),
    _icuIssue(
      'selectordinal is not supported',
      '{0, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}',
      ['22'],
      '22nd',
    ),
    _icuIssue(
      'plural offset renders an empty string',
      '{0, plural, offset:1 =0 {nobody} =1 {only {1}} one {{1} and # other} other {{1} and # others}}',
      ['2', 'Ann'],
      'Ann and 1 other',
    ),
    _KnownIssue(
      title: 'tlv on a key still in the nested-map (tlp) format',
      template: 'I have {0} apples',
      values: const ['0'],
      // ignore: deprecated_member_use
      expected: tlp('I have {0} apples', 0) ?? '',
      actual: _attempt(() => tlv('I have {0} apples', '0')),
    ),
  ];

  _KnownIssue _icuIssue(
    String title,
    String template,
    List<String> values,
    String expected,
  ) => _KnownIssue(
    title: title,
    template: template,
    values: values,
    expected: expected,
    actual: _attempt(() => tlvm(template, values)),
  );
}

String _attempt(String Function() translate) {
  try {
    return translate();
  } catch (e) {
    return 'throws ${e.runtimeType}';
  }
}

class _KnownIssue {
  const _KnownIssue({
    required this.title,
    required this.template,
    required this.values,
    required this.expected,
    required this.actual,
  });

  final String title;
  final String template;
  final List<String> values;
  final String expected;
  final String actual;
}

class _KnownIssueCard extends StatelessWidget {
  const _KnownIssueCard({required this.issue});

  final _KnownIssue issue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passes = issue.actual == issue.expected;
    final statusColor = passes ? Colors.green : theme.colorScheme.error;
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 12);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  passes ? Icons.check_circle : Icons.cancel,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(issue.title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Template: ${issue.template}', style: mono),
            Text(
              'Values: ${issue.values.map((v) => "'$v'").join(', ')}',
              style: mono,
            ),
            const Divider(height: 20),
            Text('Expected: ${issue.expected}'),
            Text(
              'Actual: ${issue.actual}',
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangSwitcher extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, code) in [
          ('English', 'en'),
          ('English (UK)', 'en_GB'),
          ('Dutch', 'nl'),
          ('Spanish', 'es'),
        ])
          ElevatedButton(
            onPressed: () => SignalTranslator().loadLocale(code),
            child: Text(label),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.result,
    required this.controls,
  });

  final String title;
  final String subtitle;
  final String result;
  final Widget controls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            controls,
            const Divider(height: 20),
            Text(
              result,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: onDecrement,
          visualDensity: VisualDensity.compact,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: onIncrement,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
