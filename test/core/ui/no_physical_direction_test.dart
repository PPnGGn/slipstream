import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A guard for right-to-left languages: layout code must say "start" and
/// "end", not "left" and "right", or Persian would show a mirrored text with
/// an unmirrored layout. It scans the source, so a new `EdgeInsets.only(left:`
/// fails here before anybody has to look at a phone.
void main() {
  // Files where the physical side is the point, not a mistake.
  const allowed = {
    // Small mock-ups of the home layouts (an image of a screen).
    'lib/features/appearance/ui/appearance_previews.dart',
    // A circular ring: left/right offsets are symmetric.
    'lib/features/vpn/ui/widgets/connection_card.dart',
  };

  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.replaceAll(r'\', '/').contains('lib/l10n/gen/'))
      .where((f) => !allowed.contains(f.path.replaceAll(r'\', '/')))
      .toList();

  List<String> offenders(RegExp pattern) => [
    for (final file in files)
      for (final (i, line) in file.readAsLinesSync().indexed)
        if (!line.trimLeft().startsWith('//') && pattern.hasMatch(line))
          '${file.path.replaceAll(r'\', '/')}:${i + 1}: ${line.trim()}',
  ];

  test('no physical corner or side alignments', () {
    // `size.bottomRight(...)` is the geometry of a rectangle, not a layout.
    final found = offenders(
      RegExp(r'(?<!size)\.(center|top|bottom)(Left|Right)\b'),
    );
    expect(found, isEmpty, reason: found.join('\n'));
  });

  test('no EdgeInsets.only with left or right', () {
    final found = offenders(RegExp(r'\.only\([^)]*\b(left|right):'));
    expect(found, isEmpty, reason: found.join('\n'));
  });

  test('no Positioned with a left or right offset other than 0', () {
    final found = offenders(RegExp(r'^\s*(left|right):\s*-?[1-9]'));
    expect(found, isEmpty, reason: found.join('\n'));
  });

  test('fromLTRB has the same left and right', () {
    final pattern = RegExp(r'fromLTRB\(\s*([^,]+),[^,]+,\s*([^,]+),');
    final found = <String>[];
    for (final file in files) {
      for (final (i, line) in file.readAsLinesSync().indexed) {
        final match = pattern.firstMatch(line);
        if (match != null && match.group(1)!.trim() != match.group(2)!.trim()) {
          found.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(found, isEmpty, reason: found.join('\n'));
  });
}
