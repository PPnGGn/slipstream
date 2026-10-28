import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/toast/show_toast.dart';
import 'package:slipstream/features/ping/presentation/ping_cubit.dart';
import 'package:slipstream/features/ping/presentation/ui/ping_sorting.dart';
import 'package:slipstream/features/qr/ui/qr_share_sheet.dart';
import 'package:slipstream/features/subscriptions/cubit/subscription_auto_update_cubit.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';
import 'package:slipstream/features/subscriptions/data/search.dart';
import 'package:slipstream/features/subscriptions/data/subscription_description_store.dart';
import 'package:slipstream/features/subscriptions/data/subscription_display.dart';
import 'package:slipstream/features/subscriptions/ui/subscription_menu_toasts.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/server_list/server_tile.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/server_list/subscription_info.dart';

enum _SectionAction { refresh, share, delete, pingAll, toggleDescription }

class SubscriptionSection extends StatefulWidget {
  const SubscriptionSection({
    super.key,
    required this.index,
    required this.colors,
    required this.stored,
    required this.query,
    required this.refreshing,
    required this.selectedServerId,
    required this.onSelect,
  });

  /// Position in the list: the drag of the header needs it.
  final int index;
  final AppColors colors;
  final StoredSubscription stored;
  final String query;
  final bool refreshing;
  final String? selectedServerId;
  final ValueChanged<VpnServer> onSelect;

  @override
  State<SubscriptionSection> createState() => _SubscriptionSectionState();
}

class _SubscriptionSectionState extends State<SubscriptionSection> {
  final _controller = ExpansibleController();
  final _descriptionStore = getIt<SubscriptionDescriptionStore>();
  late bool _expanded = widget.selectedServerId != null;
  late bool _descriptionShown = _descriptionStore.isShown(
    widget.stored.subscription.id,
  );

  bool get _effectiveExpanded => _expanded || widget.query.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_effectiveExpanded) _controller.expand();
  }

  @override
  void didUpdateWidget(SubscriptionSection old) {
    super.didUpdateWidget(old);
    if (old.query.isEmpty != widget.query.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sync();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _sync();
  }

  void _sync() =>
      _effectiveExpanded ? _controller.expand() : _controller.collapse();

  // The ⋯ menu's refresh tells the user how it ended; the automatic refresh
  // runs the same cubit method and stays silent.
  Future<void> _refresh(SubscriptionsCubit cubit, String id) async {
    final toast = refreshToast(await cubit.refreshSubscription(id));
    if (toast != null) showToastSpec(toast);
  }

  // The name is taken before the delete: afterwards the section is gone.
  Future<void> _delete(SubscriptionsCubit cubit, String id, String name) async {
    await cubit.removeSubscription(id);
    showToastSpec(subscriptionDeletedToast(name));
  }

  void _runAction(_SectionAction action) {
    final cubit = getIt<SubscriptionsCubit>();
    final id = widget.stored.subscription.id;
    switch (action) {
      case _SectionAction.refresh:
        unawaited(_refresh(cubit, id));
      case _SectionAction.share:
        final url = widget.stored.subscription.url;
        if (url == null) return;
        showQrShareSheet(
          context,
          title: widget.stored.subscription.name,
          data: url,
        );
      case _SectionAction.delete:
        unawaited(_delete(cubit, id, widget.stored.subscription.name));
      case _SectionAction.pingAll:
        getIt<PingCubit>().runForServers(widget.stored.servers);
      case _SectionAction.toggleDescription:
        final shown = !_descriptionShown;
        setState(() => _descriptionShown = shown);
        _descriptionStore.setShown(id, shown);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final sub = widget.stored.subscription;
    final servers = filterServers(widget.stored.servers, widget.query);

    return Container(
      clipBehavior: .antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: .circular(20),
        border: .all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          BlocBuilder<SubscriptionAutoUpdateCubit, AutoUpdateInterval>(
            bloc: getIt<SubscriptionAutoUpdateCubit>(),
            // A long press on the header lifts the whole card; a tap still
            // folds it. The servers below have no drag listener, so a long
            // press on a server stays free for its own action.
            builder: (context, autoUpdate) =>
                ReorderableDelayedDragStartListener(
                  index: widget.index,
                  child: _Header(
                    colors: colors,
                    name: sub.name,
                    meta: subscriptionMeta(
                      sub,
                      serverCount: widget.stored.servers.length,
                      refreshing: widget.refreshing,
                      autoUpdate: autoUpdate,
                    ),
                    isUrl: sub.url != null,
                    expanded: _effectiveExpanded,
                    descriptionShown: _descriptionShown,
                    onTap: _toggle,
                    onAction: _runAction,
                  ),
                ),
          ),
          SubscriptionInfo(
            colors: colors,
            subscription: sub,
            showDescription: _descriptionShown,
          ),
          Expansible(
            controller: _controller,
            maintainState: false,
            headerBuilder: (context, animation) => const SizedBox.shrink(),
            bodyBuilder: (context, animation) =>
                BlocBuilder<PingCubit, PingViewState>(
                  bloc: getIt<PingCubit>(),
                  // Only the sort order depends on ping state here —
                  // each ServerTile's own PingBadge listens for its
                  // live value independently. Without this, every
                  // in-flight ping patch (dozens a second across a
                  // whole run) rebuilt this entire server list.
                  buildWhen: (previous, current) =>
                      previous.sortByPing != current.sortByPing ||
                      previous.isRunning != current.isRunning,
                  builder: (context, ping) {
                    var ordered = servers;
                    // Sorted only between runs: mid-run re-sorting would
                    // make rows jump under the user's finger (spec).
                    if (ping.sortByPing && !ping.isRunning) {
                      ordered = sortServersByPing(ordered, ping.entries);
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(height: 1, color: colors.border),
                        for (final server in ordered)
                          ServerTile(
                            colors: colors,
                            server: server,
                            selected: server.id == widget.selectedServerId,
                            onTap: () => widget.onSelect(server),
                          ),
                        const SizedBox(height: 5),
                      ],
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.colors,
    required this.name,
    required this.meta,
    required this.isUrl,
    required this.expanded,
    required this.descriptionShown,
    required this.onTap,
    required this.onAction,
  });

  final AppColors colors;
  final String name;
  final SubscriptionMeta meta;
  final bool isUrl;
  final bool expanded;
  final bool descriptionShown;
  final VoidCallback onTap;
  final ValueChanged<_SectionAction> onAction;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: .opaque,
      child: Padding(
        padding: const .fromLTRB(10, 13, 8, 12),
        child: Row(
          spacing: 8,
          children: [
            AnimatedRotation(
              turns: expanded ? 0.25 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: SvgPicture.asset(
                AppAssets.chevronRight,
                width: 16,
                height: 16,
                colorFilter: .mode(colors.textSecondary, .srcIn),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                spacing: 3,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: .w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  _MetaLine(colors: colors, meta: meta),
                ],
              ),
            ),
            _SectionMenu(
              colors: colors,
              isUrl: isUrl,
              descriptionShown: descriptionShown,
              onAction: onAction,
            ),
          ],
        ),
      ),
    );
  }
}

/// `↻ 12h · 29.10.26, 01:11 · 40 ▤`
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.colors, required this.meta});

  final AppColors colors;
  final SubscriptionMeta meta;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 10.5,
      fontWeight: .w500,
      color: meta.refreshing ? colors.warn : colors.textMuted,
    );
    if (meta.refreshing) return Text('UPDATING…', style: style, maxLines: 1);

    Widget icon(String path) => SvgPicture.asset(
      path,
      width: 11,
      height: 11,
      colorFilter: .mode(colors.textMuted, .srcIn),
    );
    final interval = meta.interval;

    return Row(
      spacing: 5,
      children: [
        if (interval != null) ...[
          icon(AppAssets.refresh),
          Text(interval, style: style),
          Text('·', style: style),
        ],
        Flexible(
          child: Text(
            meta.updated,
            style: style,
            maxLines: 1,
            overflow: .ellipsis,
          ),
        ),
        Text('·', style: style),
        Text('${meta.serverCount}', style: style),
        icon(AppAssets.server),
        if (meta.failed)
          Text('FAILED', style: style.copyWith(color: colors.warn)),
      ],
    );
  }
}

/// The "⋯" menu: every per-subscription action lives here.
class _SectionMenu extends StatelessWidget {
  const _SectionMenu({
    required this.colors,
    required this.isUrl,
    required this.descriptionShown,
    required this.onAction,
  });

  final AppColors colors;
  final bool isUrl;
  final bool descriptionShown;
  final ValueChanged<_SectionAction> onAction;

  Future<void> _open(BuildContext context) async {
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    PopupMenuItem<_SectionAction> item(
      _SectionAction action,
      String label,
      String icon, {
      Color? color,
    }) => PopupMenuItem(
      value: action,
      height: 40,
      child: Row(
        spacing: 9,
        children: [
          SvgPicture.asset(
            icon,
            width: 14,
            height: 14,
            colorFilter: .mode(color ?? colors.textPrimary, .srcIn),
          ),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );

    final selected = await showMenu<_SectionAction>(
      context: context,
      position: position,
      items: [
        if (isUrl)
          item(
            _SectionAction.refresh,
            'Refresh subscription',
            AppAssets.refresh,
          ),
        item(_SectionAction.pingAll, 'Ping servers', AppAssets.ping),
        if (isUrl)
          item(_SectionAction.share, 'Share subscription', AppAssets.share),
        item(
          _SectionAction.toggleDescription,
          descriptionShown ? 'Hide description' : 'Show description',
          AppAssets.info,
        ),
        const PopupMenuDivider(height: 9),
        item(
          _SectionAction.delete,
          'Delete subscription',
          AppAssets.trash,
          color: colors.danger,
        ),
      ],
    );
    if (selected != null) onAction(selected);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      behavior: .opaque,
      child: SizedBox.square(
        dimension: 32,
        child: Center(
          child: SvgPicture.asset(
            AppAssets.dotsVertical,
            width: 15,
            height: 15,
            colorFilter: .mode(colors.textSecondary, .srcIn),
          ),
        ),
      ),
    );
  }
}
