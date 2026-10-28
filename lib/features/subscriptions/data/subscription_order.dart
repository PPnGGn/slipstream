import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';

List<StoredSubscription> orderSubscriptions(
  List<StoredSubscription> subscriptions,
  List<String> savedIds,
) {
  final byId = {for (final s in subscriptions) s.subscription.id: s};
  final known = [for (final id in savedIds) ?byId.remove(id)];
  final rest = byId.values.toList()
    ..sort((a, b) => a.subscription.id.compareTo(b.subscription.id));
  return [...known, ...rest];
}
List<T> moveItem<T>(List<T> items, int oldIndex, int newIndex) {
  final moved = [...items];
  moved.insert(newIndex, moved.removeAt(oldIndex));
  return moved;
}
