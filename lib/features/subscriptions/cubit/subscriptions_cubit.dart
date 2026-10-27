import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/subscriptions/data/selected_server_store.dart';
import 'package:slipstream/features/subscriptions/data/server_identity.dart';
import 'package:slipstream/features/subscriptions/data/subscription_factory.dart';
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
    required SubscriptionFactory factory,
    required SubscriptionRefresher refresher,
    required VpnServiceCubit vpnServiceCubit,
    required Talker talker,
  }) : _parser = parser,
       _storage = storage,
       _selectedServerStore = selectedServerStore,
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
  final SubscriptionFactory _factory;
  final SubscriptionRefresher _refresher;
  final VpnServiceCubit _vpnServiceCubit;
  final Talker _talker;

  Future<void> _init() async {
    final subs = await _storage.loadAll();
    final selected = _selectedServerStore.load();
    emit(
      state.copyWith(
        subscriptions: subs,
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
  }

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
  Future<void> refreshSubscription(String subscriptionId) async {
    if (state.refreshingIds.contains(subscriptionId)) return;
    final stored = _findSubscription(subscriptionId);
    if (stored == null || stored.subscription.url == null) return;

    emit(
      state.copyWith(refreshingIds: {...state.refreshingIds, subscriptionId}),
    );
    final updated = await _refresher.refresh(stored);
    final refreshing = {...state.refreshingIds}..remove(subscriptionId);

    // Looked up again by id: the list may have changed during the fetch,
    // and a subscription deleted meanwhile must not come back.
    final index = state.subscriptions.indexWhere(
      (s) => s.subscription.id == subscriptionId,
    );
    if (index == -1) {
      _talker.debug('Subscriptions: $subscriptionId deleted mid-refresh');
      emit(state.copyWith(refreshingIds: refreshing));
      return;
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

    final subscriptions = [...state.subscriptions];
    subscriptions[index] = updated;
    emit(
      state.copyWith(subscriptions: subscriptions, refreshingIds: refreshing),
    );
    await _followSelectedServer();
  }

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
    emit(state.copyWith(subscriptions: subscriptions));
    await _followSelectedServer();
  }

  /// Keeps the selection on the same server when a refresh shifted its id
  /// (see [remapServerId]). A server that is really gone stays selected by
  /// its old id — nothing is picked silently in its place.
  Future<void> _followSelectedServer() async {
    final subscriptionId = state.selectedSubscriptionId;
    final serverId = state.selectedServerId;
    if (subscriptionId == null || serverId == null) return;
    final stored = _findSubscription(subscriptionId);
    if (stored == null) return;

    final remapped = remapServerId(serverId, stored.servers);
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
