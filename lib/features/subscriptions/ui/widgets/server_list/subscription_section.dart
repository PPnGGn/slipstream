import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/app_theme.dart';
import 'package:slipstream/core/ui/clipboard.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';
import 'package:slipstream/features/subscriptions/data/ping/ping_quality.dart';
import 'package:slipstream/features/subscriptions/data/search.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/server_list/server_tile.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/server_list/subscription_info.dart';

enum _SectionAction { refresh, copyUrl, delete }

class SubscriptionSection extends StatefulWidget {
  const SubscriptionSection({
    super.key,
    required this.colors,
    required this.stored,
    required this.query,
    required this.refreshing,
    required this.selectedServerId,
    required this.onSelect,
  });

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
  late bool _expanded = widget.selectedServerId != null;

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

  void _runAction(_SectionAction action) {
    final cubit = getIt<SubscriptionsCubit>();
    final id = widget.stored.subscription.id;
    switch (action) {
      case _SectionAction.refresh:
        cubit.refreshSubscription(id);
      case _SectionAction.copyUrl:
        final url = widget.stored.subscription.url;
        if (url == null) return;
        copyToClipboard(context, url, 'URL copied');
      case _SectionAction.delete:
        cubit.removeSubscription(id);
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
        borderRadius: .circular(AppDims.radiusCard),
        border: .all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          _Header(
            colors: colors,
            name: sub.name,
            updateIntervalHours: sub.updateIntervalHours,
            isUrl: sub.url != null,
            refreshing: widget.refreshing,
            expanded: _effectiveExpanded,
            onTap: _toggle,
            onAction: _runAction,
          ),
          SubscriptionInfo(
            colors: colors,
            subscription: sub,
            serverCount: widget.stored.servers.length,
          ),
          Expansible(
            controller: _controller,
            maintainState: false,
            headerBuilder: (context, animation) => const SizedBox.shrink(),
            bodyBuilder: (context, animation) => Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                Divider(height: 1, color: colors.border),
                for (final (index, server) in servers.indexed)
                  ServerTile(
                    colors: colors,
                    server: server,
                    selected: server.id == widget.selectedServerId,
                    pingDelay: pingStagger(index),
                    onTap: () => widget.onSelect(server),
                  ),
                const SizedBox(height: 4),
              ],
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
    required this.updateIntervalHours,
    required this.isUrl,
    required this.refreshing,
    required this.expanded,
    required this.onTap,
    required this.onAction,
  });

  final AppColors colors;
  final String name;
  final int? updateIntervalHours;
  final bool isUrl;
  final bool refreshing;
  final bool expanded;
  final VoidCallback onTap;
  final ValueChanged<_SectionAction> onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      behavior: .opaque,
      child: Padding(
        padding: const .fromLTRB(12, 12, 10, 8),
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
              child: Text(
                name,
                style: textTheme.titleSmall,
                maxLines: 1,
                overflow: .ellipsis,
              ),
            ),
            if (updateIntervalHours != null)
              _Badge(colors: colors, label: '${updateIntervalHours}h')
            else if (!isUrl)
              _Badge(colors: colors, label: 'MANUAL'),
            if (isUrl)
              _CircleButton(
                colors: colors,
                icon: AppAssets.refresh,
                spinning: refreshing,
                onTap: () => onAction(_SectionAction.refresh),
              ),
            _SectionMenu(colors: colors, isUrl: isUrl, onAction: onAction),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.colors, required this.label});

  final AppColors colors;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: colors.chip, borderRadius: .circular(6)),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 9,
          fontWeight: .w700,
          letterSpacing: 0.5,
          color: colors.textMuted,
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.colors,
    required this.icon,
    required this.onTap,
    this.spinning = false,
  });

  final AppColors colors;
  final String icon;
  final VoidCallback onTap;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: .opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(shape: .circle, color: colors.chip),
        child: Center(
          child: spinning
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor: AlwaysStoppedAnimation(colors.textSecondary),
                  ),
                )
              : SvgPicture.asset(
                  icon,
                  width: 15,
                  height: 15,
                  colorFilter: .mode(colors.textSecondary, .srcIn),
                ),
        ),
      ),
    );
  }
}

class _SectionMenu extends StatelessWidget {
  const _SectionMenu({
    required this.colors,
    required this.isUrl,
    required this.onAction,
  });

  final AppColors colors;
  final bool isUrl;
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

    Widget item(String label, String icon, {Color? color}) => Row(
      spacing: 9,
      children: [
        SvgPicture.asset(
          icon,
          width: 15,
          height: 15,
          colorFilter: .mode(color ?? colors.textPrimary, .srcIn),
        ),
        Text(label, style: TextStyle(color: color)),
      ],
    );

    final selected = await showMenu<_SectionAction>(
      context: context,
      position: position,
      items: [
        if (isUrl)
          PopupMenuItem(
            value: _SectionAction.copyUrl,
            child: item('Copy URL', AppAssets.copy),
          ),
        PopupMenuItem(
          value: _SectionAction.delete,
          child: item(
            'Delete subscription',
            AppAssets.trash,
            color: colors.danger,
          ),
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
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(shape: .circle, color: colors.chip),
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
