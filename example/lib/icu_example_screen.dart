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
          ],
        ),
      ),
    );
  }
}

class _LangSwitcher extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (label, code) in [
          ('English', 'en'),
          ('Dutch', 'nl'),
          ('Spanish', 'es'),
        ])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: () => SignalTranslator().loadLocale(code),
              child: Text(label),
            ),
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
