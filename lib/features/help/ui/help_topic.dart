import 'package:slipstream/core/theme/app_colors.dart' show TileHue;

/// The content of one help sheet: what a settings page is for, and one
/// [HelpItem] per setting on it. Plain data, so the texts can be tested
/// without a widget; the sheet only draws it.
class HelpTopic {
  const HelpTopic({
    required this.title,
    required this.intro,
    required this.items,
    this.notes = const [],
  });

  /// The page's name, the same as in its header.
  final String title;

  /// One or two sentences: what the page is for.
  final String intro;

  final List<HelpItem> items;

  /// "Good to know": when changes apply, exceptions, a legend.
  final List<HelpNote> notes;
}

/// One setting. [title], [iconPath] and [hue] repeat what its row on the
/// page shows, so the card is recognized at a glance.
class HelpItem {
  const HelpItem({
    required this.iconPath,
    required this.hue,
    required this.title,
    required this.what,
    required this.why,
    this.tip,
  });

  final String iconPath;
  final TileHue hue;
  final String title;

  /// What the setting does.
  final String what;

  /// Why anyone would want it: the situation it solves.
  final String why;

  /// A short recommendation ("Keep it on"); null draws no tip.
  final String? tip;
}

class HelpNote {
  const HelpNote({required this.title, required this.body});

  final String title;
  final String body;
}
