import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_parser_service.dart';

@lazySingleton
class SubscriptionFactory {
  static const _uuid = Uuid();

  StoredSubscription create(
    ParsedSubscription parsed, {
    required String input,
    required bool isUrl,
    String? name,
  }) {
    final id = _uuid.v4();
    final servers = _reassign(parsed.servers, id);
    return StoredSubscription(
      subscription: Subscription(
        id: id,
        url: isUrl ? input : null,
        name: _deriveName(
          name,
          input,
          isUrl: isUrl,
          servers: servers,
          suggestedName: parsed.suggestedName,
        ),
        lastUpdatedAt: DateTime.now(),
      ),
      servers: servers,
    );
  }

  StoredSubscription refresh(
    StoredSubscription existing,
    ParsedSubscription parsed,
  ) {
    final id = existing.subscription.id;
    return StoredSubscription(
      subscription: existing.subscription.copyWith(
        lastUpdatedAt: DateTime.now(),
      ),
      servers: _reassign(parsed.servers, id),
    );
  }

  List<VpnServer> _reassign(List<VpnServer> servers, String subscriptionId) =>
      servers.map((s) => s.copyWith(subscriptionId: subscriptionId)).toList();

  String _deriveName(
    String? name,
    String input, {
    required bool isUrl,
    required List<VpnServer> servers,
    String? suggestedName,
  }) {
    if (name != null && name.trim().isNotEmpty) return name.trim();
    if (suggestedName != null && suggestedName.trim().isNotEmpty) {
      return suggestedName.trim();
    }
    if (isUrl) {
      final host = Uri.tryParse(input)?.host;
      if (host != null && host.isNotEmpty) return host;
    }
    return servers.length == 1
        ? servers.first.title
        : 'Импортированные серверы';
  }
}
