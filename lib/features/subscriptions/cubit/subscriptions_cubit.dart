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
import 'package:slipstream/features/subscriptions/data/subscription_factory.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_parser_service.dart';
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
    required VpnServiceCubit vpnServiceCubit,
    required Talker talker,
  }) : _parser = parser,
       _storage = storage,
       _selectedServerStore = selectedServerStore,
       _factory = factory,
       _vpnServiceCubit = vpnServiceCubit,
       _talker = talker,
       super(const SubscriptionsState()) {
    _init();
  }

  final SubscriptionParserService _parser;
  final SubscriptionStorage _storage;
  final SelectedServerStore _selectedServerStore;
  final SubscriptionFactory _factory;
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
      ),
    );
  }

  /// Parses a URL / vless:// / ss://
  Future<bool> addFromInput(String input, {String? name}) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;

    final isUrl = trimmed.toLowerCase().startsWith('http');
    if (isUrl && _findByUrl(trimmed) != null) {
      emit(
        state.copyWith(
          errorMessage: 'This subscription has already been added',
        ),
      );
      return false;
    }

    emit(state.copyWith(isAdding: true, errorMessage: null));
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
      case Failure(:final message):
        _talker.warning('Subscriptions: failed to add -> $message');
        emit(state.copyWith(isAdding: false, errorMessage: message));
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
  Future<void> refreshSubscription(String subscriptionId) async {
    final index = state.subscriptions.indexWhere(
      (s) => s.subscription.id == subscriptionId,
    );
    if (index == -1) return;
    final stored = state.subscriptions[index];
    final url = stored.subscription.url;
    if (url == null) return;

    emit(
      state.copyWith(refreshingIds: {...state.refreshingIds, subscriptionId}),
    );
    final result = await _parser.parseFromInput(url);

    switch (result) {
      case Success(:final data):
        final updated = _factory.refresh(stored, data);
        await _storage.save(updated);
        _talker.info(
          'Subscriptions: refreshed ${updated.servers.length} server(s) (${updated.subscription.name})',
        );
        final subscriptions = [...state.subscriptions];
        subscriptions[index] = updated;
        emit(
          state.copyWith(
            subscriptions: subscriptions,
            refreshingIds: {...state.refreshingIds}..remove(subscriptionId),
          ),
        );
      case Failure(:final message):
        _talker.warning('Subscriptions: failed to refresh -> $message');
        emit(
          state.copyWith(
            refreshingIds: {...state.refreshingIds}..remove(subscriptionId),
            errorMessage: message,
          ),
        );
    }
  }

  void clearError() => emit(state.copyWith(errorMessage: null));

  StoredSubscription? _findByUrl(String url) {
    for (final stored in state.subscriptions) {
      if (stored.subscription.url == url) return stored;
    }
    return null;
  }
}
