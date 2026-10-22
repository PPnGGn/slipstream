/// How often URL subscriptions are re-fetched when the provider does not
/// send its own `profile-update-interval`. [off] disables auto-update
/// entirely, the provider's interval included.
enum AutoUpdateInterval {
  off(null),
  h1(1),
  h3(3),
  h6(6),
  h12(12),
  h24(24);

  const AutoUpdateInterval(this.hours);

  /// Null only for [off].
  final int? hours;
}
