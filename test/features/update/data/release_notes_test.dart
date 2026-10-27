import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/update/data/release_notes.dart';

void main() {
  test('no description means no notes', () {
    expect(parseReleaseNotes(null), isEmpty);
    expect(parseReleaseNotes(''), isEmpty);
    expect(parseReleaseNotes('   \n  '), isEmpty);
  });

  test('every bullet line becomes one item, without its marker', () {
    expect(
      parseReleaseNotes(
        '- Search in split tunneling\n'
        '* Fixed reconnect loop\n'
        '• New update dialog',
      ),
      [
        'Search in split tunneling',
        'Fixed reconnect loop',
        'New update dialog',
      ],
    );
  });

  test('only bullets count: headings, text and links are left out', () {
    expect(
      parseReleaseNotes(
        '## What\'s Changed\n'
        'Some words about the release.\n'
        '- The one real change\n'
        '\n'
        '**Full Changelog**: https://github.com/PPnGGn/slipstream/compare/v1...v2',
      ),
      ['The one real change'],
    );
  });

  test('Windows line endings and indentation do not matter', () {
    expect(parseReleaseNotes('  - First\r\n\t- Second\r\n'), [
      'First',
      'Second',
    ]);
  });

  test('an empty bullet is skipped', () {
    expect(parseReleaseNotes('- \n-\n- Real'), ['Real']);
  });

  test('a dash inside a word is not a bullet', () {
    expect(parseReleaseNotes('-not a bullet\nx - y'), isEmpty);
  });

  test('code quotes and bold marks are dropped from the text', () {
    expect(
      parseReleaseNotes('- Fixed `reconnect` loop after **device sleep**'),
      ['Fixed reconnect loop after device sleep'],
    );
  });

  test('lines GitHub generates for merged pull requests are not notes', () {
    expect(
      parseReleaseNotes(
        '* feat: add toasts by @someone in https://github.com/PPnGGn/slipstream/pull/12\n'
        '- A line written by hand',
      ),
      ['A line written by hand'],
    );
  });
}
