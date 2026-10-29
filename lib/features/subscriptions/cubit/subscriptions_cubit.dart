import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/subscriptions/cubit/refresh_outcome.dart';
import 'package:slipstream/features/subscriptions/data/favorite_servers.dart';
import 'package:slipstream/features/subscriptions/data/selected_server_store.dart';
import 'package:slipstream/features/subscriptions/data/server_identity.dart';
import 'package:slipstream/features/subscriptions/data/subscription_factory.dart';
import 'package:slipstream/features/subscriptions/data/subscription_order.dart';
import 'package:slipstream/features/subscriptions/data/subscription_order_store.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_exceptions.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_parser_service.dart';
import 'package:slipstream/features/subscriptions/data/subscription_refresher.dart';
import 'package:slipstream/features/subscriptions/data/subscription_storage/subscription_storage.dart';

part 'subscriptions_state.dart';
part 'subscriptions_cubit.freezed.dart';

@lazySingleton
class SubscriptionsCubit extends Cubit<SubscriptionsState> {
  SubscriptionsCubit({
    required SubscriptionParserService parser,
    required SubscriptionStorage storage,
    required SelectedServerStore selectedServerStore,
    required SubscriptionOrderStore orderStore,
    required SubscriptionFactory factory,
    required SubscriptionRefresher refresher,
    required VpnServiceCubit vpnServiceCubit,
    required Talker talker,
  }) : _parser = parser,
       _storage = storage,
       _selectedServerStore = selectedServerStore,
       _orderStore = orderStore,
       _factory = factory,
       _refresher = refresher,
       _vpnServiceCubit = vpnServiceCubit,
       _talker = talker,
       super(const SubscriptionsState()) {
    _init();
  }

  final SubscriptionParserService _parser;
  final SubscriptionStorage _storage;
  final SelectedServerStore _selectedServerStore;
  final SubscriptionOrderStore _orderStore;
  final SubscriptionFactory _factory;
  final SubscriptionRefresher _refresher;
  final VpnServiceCubit _vpnServiceCubit;
  final Talker _talker;

  Future<void> _init() async {
    final subs = await _storage.loadAll();
    final selected = _selectedServerStore.load();
    emit(
      state.copyWith(
        subscriptions: orderSubscriptions(subs, _orderStore.load()),
        selectedSubscriptionId: selected?.$1,
        selectedServerId: selected?.$2,
        isLoaded: true,
      ),
    );
  }

  /// Parses a URL / vless:// / ss://
  Future<bool> addFromInput(String input, {String? name}) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;

    final isUrl = trimmed.toLowerCase().startsWith('http');
    if (isUrl && _findByUrl(trimmed) != null) {
      const duplicate = DuplicateSubscriptionException();
      emit(
        state.copyWith(
          errorMessage: duplicate.toString(),
          errorCause: duplicate,
        ),
      );
      return false;
    }

    emit(state.copyWith(isAdding: true, errorMessage: null, errorCause: null));
    final result = await _parser.parseFromInput(trimmed);

    switch (result) {
      case Success(:final data):
        final stored = _factory.create(
          data,
          input: trimmed,
          isUrl: isUrl,
          name: name,
        );
        await _storage.save(stored);
        _talker.info(
          'Subscriptions: added ${stored.servers.length} server(s) (${stored.subscription.name})',
        );
        emit(
          state.copyWith(
            subscriptions: [...state.subscriptions, stored],
            isAdding: false,
          ),
        );
        await _saveOrder();
        return true;
      case Failure(:final message, :final exception):
        _talker.warning('Subscriptions: failed to add -> $message');
        emit(
          state.copyWith(
            isAdding: false,
            errorMessage: message,
            errorCause: exception,
          ),
        );
        return false;
    }
  }

  Future<bool> addAndActivate(String input, {String? name}) async {
    final added = await addFromInput(input, name: name);
    if (!added) return false;
    final stored = state.subscriptions.last;
    if (stored.servers.isNotEmpty) {
      await selectServer(stored.subscription.id, stored.servers.first.id);
    }
    return true;
  }

  Future<void> removeSubscription(String subscriptionId) async {
    await _storage.delete(subscriptionId);
    final remaining = state.subscriptions
        .where((s) => s.subscription.id != subscriptionId)
        .toList();

    var selectedSubscriptionId = state.selectedSubscriptionId;
    var selectedServerId = state.selectedServerId;
    if (selectedSubscriptionId == subscriptionId) {
      selectedSubscriptionId = null;
      selectedServerId = null;
      await _selectedServerStore.clear();
    }

    emit(
      state.copyWith(
        subscriptions: remaining,
        selectedSubscriptionId: selectedSubscriptionId,
        selectedServerId: selectedServerId,
      ),
    );
    await _saveOrder();
  }

  /// Drag and drop: moves the card at [oldIndex] to [newIndex] (counted
  /// after it is taken out, as `ReorderableListView.onReorderItem` gives it)
  /// and remembers the order.
  Future<void> moveSubscription(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    emit(
      state.copyWith(
        subscriptions: moveItem(state.subscriptions, oldIndex, newIndex),
      ),
    );
    await _saveOrder();
  }

  /// Pins the server to the top of its subscription, or unpins it. The id is
  /// saved with the subscription, so a refresh keeps it (see
  /// `SubscriptionFactory.refresh`). Returns true when it was pinned, false
  /// when unpinned, null when there is no such subscription or server.
  Future<bool?> toggleFavorite(String subscriptionId, String serverId) async {
    final stored = _findSubscription(subscriptionId);
    if (stored == null || !stored.servers.any((s) => s.id == serverId)) {
      return null;
    }

    final subscription = stored.subscription;
    final ids = toggleFavoriteId(subscription.favoriteServerIds, serverId);
    final updated = stored.copyWith(
      subscription: subscription.copyWith(favoriteServerIds: ids),
    );
    await _storage.save(updated);
    // Looked up again after the save, as in refreshSubscription: the list
    // may have changed meanwhile.
    emit(
      state.copyWith(
        subscriptions: [
          for (final s in state.subscriptions)
            s.subscription.id == subscriptionId ? updated : s,
        ],
      ),
    );
    return ids.contains(serverId);
  }

  Future<void> _saveOrder() => _orderStore.save([
    for (final stored in state.subscriptions) stored.subscription.id,
  ]);

  Future<void> selectServer(String subscriptionId, String serverId) async {
    await _selectedServerStore.save(subscriptionId, serverId);
    emit(
      state.copyWith(
        selectedSubscriptionId: subscriptionId,
        selectedServerId: serverId,
      ),
    );

    final server = _findServer(subscriptionId, serverId);
    if (server != null) _vpnServiceCubit.switchServerIfActive(server);
  }

  VpnServer? _findServer(String subscriptionId, String serverId) {
    for (final stored in state.subscriptions) {
      if (stored.subscription.id != subscriptionId) continue;
      for (final server in stored.servers) {
        if (server.id == serverId) return server;
      }
    }
    return null;
  }

  /// Re-fetches a URL-based subscription and replaces its server list.
  ///
  /// Used by the ⋯ menu and by auto-update alike. A failure keeps the old
  /// servers and lands in the subscription's `lastError` (shown in its meta
  /// line), never in [SubscriptionsState.errorMessage], which belongs to the
  /// add sheet. A refresh already running for [subscriptionId] wins: a
  /// second call returns at once.
  ///
  /// Returns how it ended; the manual refresh tells the user, the automatic
  /// one does not look at it.
  Future<RefreshOutcome> refreshSubscription(String subscriptionId) async {
    if (state.refreshingIds.contains(subscriptionId)) {
      return const RefreshIgnored();
    }
    final stored = _findSubscription(subscriptionId);
    if (stored == null || stored.subscription.url == null) {
      return const RefreshIgnored();
    }

    emit(
      state.copyWith(refreshingIds: {...state.refreshingIds, subscriptionId}),
    );
    final refreshed = await _refresher.refreshDetailed(stored);
    final updated = refreshed.stored;

    // Looked up again by id: the list may have changed during the fetch,
    // and a subscription deleted meanwhile must not come back.
    if (_findSubscription(subscriptionId) == null) {
      _talker.debug('Subscriptions: $subscriptionId deleted mid-refresh');
      emit(
        state.copyWith(
          refreshingIds: {...state.refreshingIds}..remove(subscriptionId),
        ),
      );
      return const RefreshIgnored();
    }

    await _storage.save(updated);
    final error = updated.subscription.lastError;
    if (error == null) {
      _talker.info(
        'Subscriptions: refreshed ${updated.servers.length} server(s) (${updated.subscription.name})',
      );
    } else {
      _talker.warning('Subscriptions: failed to refresh -> $error');
    }

    // Taken before the list is replaced: it tells the automatic server from
    // the real one that shares its address.
    final selectedTitle = state.selectedServer?.title;

    // State is read again only now, after the save: refreshes running side
    // by side (refreshAll) emit in the meantime, and a copy taken before the
    // await would undo their changes.
    emit(
      state.copyWith(
        subscriptions: [
          for (final s in state.subscriptions)
            s.subscription.id == subscriptionId ? updated : s,
        ],
        refreshingIds: {...state.refreshingIds}..remove(subscriptionId),
      ),
    );
    await _followSelectedServer(selectedTitle);
    return error == null ? Refreshed(updated) : RefreshFailed(refreshed.cause);
  }

  /// [refreshSubscription] for every subscription with a URL, all at once:
  /// the list's pull down. One failure does not stop the others. Outcomes
  /// come in list order; subscriptions without a URL get none.
  Future<List<RefreshOutcome>> refreshAll() => Future.wait([
    for (final stored in state.subscriptions)
      if (stored.subscription.url != null)
        refreshSubscription(stored.subscription.id),
  ]);

  /// Re-reads every subscription from disk, for when the background job
  /// refreshed them while the UI was away. Known subscriptions keep their
  /// place in the list; new ones go to the end.
  Future<void> reloadFromStorage() async {
    final loaded = {
      for (final s in await _storage.loadAll()) s.subscription.id: s,
    };
    final subscriptions = [
      for (final s in state.subscriptions) ?loaded.remove(s.subscription.id),
      ...loaded.values,
    ];
    final selectedTitle = state.selectedServer?.title;
    emit(state.copyWith(subscriptions: subscriptions));
    await _followSelectedServer(selectedTitle);
  }

  /// Keeps the selection on the same server when a refresh shifted its id
  /// (see [remapServerId]); [oldTitle] is the selected server's title before
  /// the refresh. A server that is really gone stays selected by its old id —
  /// nothing is picked silently in its place.
  Future<void> _followSelectedServer(String? oldTitle) async {
    final subscriptionId = state.selectedSubscriptionId;
    final serverId = state.selectedServerId;
    if (subscriptionId == null || serverId == null) return;
    final stored = _findSubscription(subscriptionId);
    if (stored == null) return;

    final remapped = remapServerId(
      serverId,
      stored.servers,
      oldTitle: oldTitle,
    );
    if (remapped == null || remapped == serverId) return;
    _talker.debug('Subscriptions: selected server moved -> $remapped');
    await _selectedServerStore.save(subscriptionId, remapped);
    emit(state.copyWith(selectedServerId: remapped));
  }

  StoredSubscription? _findSubscription(String subscriptionId) {
    for (final stored in state.subscriptions) {
      if (stored.subscription.id == subscriptionId) return stored;
    }
    return null;
  }

  void clearError() =>
      emit(state.copyWith(errorMessage: null, errorCause: null));

  StoredSubscription? _findByUrl(String url) {
    for (final stored in state.subscriptions) {
      if (stored.subscription.url == url) return stored;
    }
    return null;
  }
}
