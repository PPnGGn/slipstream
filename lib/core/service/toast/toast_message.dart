enum ToastKind { success, error, info }

/// What a toast says, before it is shown (no id yet). Pure functions that
/// decide the wording return this, so tests can compare it directly.
class ToastSpec {
  const ToastSpec(
    this.title, {
    this.subtitle,
    this.kind = ToastKind.success,
  });

  final String title;
  final String? subtitle;
  final ToastKind kind;

  @override
  bool operator ==(Object other) =>
      other is ToastSpec &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(title, subtitle, kind);

  @override
  String toString() => 'ToastSpec($title, $subtitle, $kind)';
}

class ToastMessage {
  const ToastMessage({
    required this.id,
    required this.title,
    required this.kind,
    this.subtitle,
  });

  final int id;
  final String title;
  final String? subtitle;
  final ToastKind kind;

  /// How long it stays: a bit longer when there is a second line to read.
  Duration get duration =>
      Duration(milliseconds: subtitle == null ? 2200 : 3200);
}
