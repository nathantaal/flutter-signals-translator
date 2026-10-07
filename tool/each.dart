// Runs a command in every package and example directory, in dependency
// order. Directories that don't exist yet are skipped.
//
// Usage: dart tool/each.dart flutter pub get
import 'dart:io';

const directories = [
  'packages/signals_translator_core',
  'tool/translator_conformance',
  'packages/signals_translator',
  'packages/signals_translator/example',
  'packages/alien_signals_translator',
  'packages/alien_signals_translator/example',
  'packages/solidart_translator',
  'packages/solidart_translator/example',
];

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: dart tool/each.dart <command> [args...]');
    exit(64);
  }
  final root = File.fromUri(Platform.script).parent.parent.path;
  final failed = <String>[];
  for (final dir in directories) {
    final path = '$root/$dir';
    if (!Directory(path).existsSync()) continue;
    // Library-only packages (the conformance suites) have nothing to test.
    if (args.contains('test') && !Directory('$path/test').existsSync()) {
      continue;
    }
    stdout.writeln('\n=== $dir: ${args.join(' ')}');
    final process = await Process.start(
      args.first,
      args.skip(1).toList(),
      workingDirectory: path,
      runInShell: true,
      mode: ProcessStartMode.inheritStdio,
    );
    if (await process.exitCode != 0) failed.add(dir);
  }
  if (failed.isNotEmpty) {
    stderr.writeln('\nFailed in: ${failed.join(', ')}');
    exit(1);
  }
}
