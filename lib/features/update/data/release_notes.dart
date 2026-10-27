// The release description on GitHub is the body of the release commit (see
// the release workflow). Its bullet lines are the "What's new" list; anything
// else in it (headings, paragraphs, links) is not shown in the app.

final _bullet = RegExp(r'^\s*[-*•]\s+(.*)$');

// What GitHub writes itself for a merged pull request: noise, not a note.
final _generatedPullRequestLine = RegExp(r'\sby @\S+ in https?://\S+');

/// The "What's new" items from a release [body], in order. Empty when the
/// release has none, and then the app shows no such block.
List<String> parseReleaseNotes(String? body) {
  if (body == null) return const [];

  final notes = <String>[];
  for (final line in body.split(RegExp(r'\r?\n'))) {
    final match = _bullet.firstMatch(line);
    if (match == null) continue;
    final text = match
        .group(1)!
        .replaceAll('`', '')
        .replaceAll('**', '')
        .trim();
    if (text.isEmpty || _generatedPullRequestLine.hasMatch(text)) continue;
    notes.add(text);
  }
  return notes;
}
