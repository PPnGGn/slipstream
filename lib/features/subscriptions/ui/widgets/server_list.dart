import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/formatters.dart';
import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/app_theme.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';
import 'package:slipstream/features/subscriptions/data/ping_service.dart';

class ServerList extends StatelessWidget {
  const ServerList({super.key, this.query = '', this.onAddSubscription});

  final String query;
  final VoidCallback? onAddSubscription;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppThemeCubit, AppThemeMode>(
      bloc: getIt<AppThemeCubit>(),
      builder: (context, _) {
        final colors = getIt<AppColors>();

        return BlocBuilder<SubscriptionsCubit, SubscriptionsState>(
          bloc: getIt<SubscriptionsCubit>(),
          builder: (context, state) {
            if (state.subscriptions.isEmpty) {
              return _EmptyState(onAdd: onAddSubscription);
            }

            final normalizedQuery = query.trim().toLowerCase();

            return SingleChildScrollView(
              padding: const .only(bottom: 28),
              child: Column(
                spacing: AppDims.gapM,
                children: [
                  for (final stored in state.subscriptions)
                    _SubscriptionSection(
                      key: ValueKey(stored.subscription.id),
                      colors: colors,
                      stored: stored,
                      query: normalizedQuery,
                      refreshing: state.refreshingIds.contains(
                        stored.subscription.id,
                      ),
                      selectedServerId:
                          state.selectedSubscriptionId == stored.subscription.id
                          ? state.selectedServerId
                          : null,
                      onSelect: (server) => getIt<SubscriptionsCubit>()
                          .selectServer(stored.subscription.id, server.id),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

enum _SectionAction { refresh, copyUrl, delete }

class _SubscriptionSection extends StatefulWidget {
  const _SubscriptionSection({
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
  State<_SubscriptionSection> createState() => _SubscriptionSectionState();
}

class _SubscriptionSectionState extends State<_SubscriptionSection> {
  final _controller = ExpansibleController();
  late bool _expanded = widget.selectedServerId != null;

  bool get _effectiveExpanded => _expanded || widget.query.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_effectiveExpanded) _controller.expand();
  }

  @override
  void didUpdateWidget(_SubscriptionSection old) {
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

  List<VpnServer> get _visibleServers {
    final servers = widget.stored.servers;
    if (widget.query.isEmpty) return servers;
    return servers
        .where(
          (s) =>
              s.title.toLowerCase().contains(widget.query) ||
              s.countryCode.toLowerCase().contains(widget.query),
        )
        .toList();
  }

  void _runAction(_SectionAction action) {
    final cubit = getIt<SubscriptionsCubit>();
    final id = widget.stored.subscription.id;
    switch (action) {
      case _SectionAction.refresh:
        cubit.refreshSubscription(id);
      case _SectionAction.copyUrl:
        final url = widget.stored.subscription.url;
        if (url == null) return;
        Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('URL copied')));
      case _SectionAction.delete:
        cubit.removeSubscription(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final sub = widget.stored.subscription;
    final servers = _visibleServers;

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
          _SubscriptionInfo(
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
                  _ServerTile(
                    colors: colors,
                    server: server,
                    selected: server.id == widget.selectedServerId,
                    pingDelayMs: (index % 12) * 45,
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

/// Always-visible block under the section header: days left, traffic, announce,
/// update timestamp. Does not collapse with the servers.
class _SubscriptionInfo extends StatelessWidget {
  const _SubscriptionInfo({
    required this.colors,
    required this.subscription,
    required this.serverCount,
  });

  final AppColors colors;
  final Subscription subscription;
  final int serverCount;

  @override
  Widget build(BuildContext context) {
    final used = subscription.usedBytes;
    final expiresAt = subscription.expiresAt;
    final announce = subscription.announce?.trim();
    final hasAnnounce = announce != null && announce.isNotEmpty;

    final metaStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 10,
      fontWeight: .w600,
      letterSpacing: 0.3,
      color: colors.textMuted,
    );

    final daysLeft = expiresAt?.difference(DateTime.now()).inDays;

    return Padding(
      padding: const .fromLTRB(14, 0, 14, 12),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          if (used != null || daysLeft != null) ...[
            Row(
              spacing: 10,
              children: [
                if (daysLeft != null)
                  Text(
                    daysLeft > 0 ? '${daysLeft}d left' : 'expired',
                    style: metaStyle.copyWith(
                      color: daysLeft <= 3 ? colors.warn : colors.textMuted,
                    ),
                  ),
                if (used != null)
                  Expanded(
                    child: _TrafficBar(
                      colors: colors,
                      used: used,
                      limit: subscription.dataLimitBytes,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (hasAnnounce)
            Text(
              announce,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: colors.textSecondary,
              ),
            ),
          const SizedBox(height: 10),
          Align(
            alignment: .centerRight,
            child: Text(
              '${formatUpdatedAt(subscription.lastUpdatedAt)}  ·  $serverCount',
              style: metaStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrafficBar extends StatelessWidget {
  const _TrafficBar({
    required this.colors,
    required this.used,
    required this.limit,
  });

  final AppColors colors;
  final int used;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final unlimited = limit == null || limit! <= 0;
    final ratio = unlimited ? 0.0 : (used / limit!).clamp(0.0, 1.0);
    final label = unlimited
        ? '${formatBytes(used)} / ∞'
        : '${formatBytes(used)} / ${formatBytes(limit!)}';

    return Container(
      height: 22,
      clipBehavior: .antiAlias,
      decoration: BoxDecoration(
        color: colors.inputFill,
        borderRadius: .circular(7),
        border: .all(color: colors.border),
      ),
      child: Stack(
        children: [
          if (!unlimited)
            FractionallySizedBox(
              widthFactor: ratio,
              heightFactor: 1,
              child: ColoredBox(color: colors.primary.withValues(alpha: 0.25)),
            ),
          Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: .w600,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    required this.colors,
    required this.server,
    required this.selected,
    required this.pingDelayMs,
    required this.onTap,
  });

  final AppColors colors;
  final VpnServer server;
  final bool selected;
  final int pingDelayMs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final hasInlineFlag = startsWithFlagEmoji(server.title);
    final flag = hasInlineFlag
        ? String.fromCharCodes(server.title.runes.take(2))
        : (server.countryCode == 'XX'
              ? '🏳️'
              : countryFlag(server.countryCode));
    final title = hasInlineFlag
        ? String.fromCharCodes(server.title.runes.skip(2)).trimLeft()
        : server.title;

    final meta = _serverMeta(server.configJson);
    final endpoint = _endpoint(server.configJson);

    return GestureDetector(
      onTap: onTap,
      behavior: .opaque,
      child: Padding(
        padding: const .symmetric(horizontal: 8, vertical: 2),
        child: Container(
          decoration: selected
              ? BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.06),
                  borderRadius: .circular(12),
                  border: .all(color: colors.primary.withValues(alpha: 0.7)),
                )
              : null,
          padding: const .fromLTRB(6, 8, 4, 8),
          child: Row(
            spacing: 10,
            children: [
              _FlagBox(colors: colors, flag: flag),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  mainAxisSize: .min,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: .w600,
                        color: selected
                            ? colors.textPrimary
                            : colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _ProtoChips(colors: colors, meta: meta),
                  ],
                ),
              ),
              if (endpoint != null)
                _PingPill(
                  colors: colors,
                  host: endpoint.host,
                  port: endpoint.port,
                  delayMs: pingDelayMs,
                ),
              GestureDetector(
                onTap: () => _showServerInfo(context, server, colors),
                behavior: .opaque,
                child: Padding(
                  padding: const .all(6),
                  child: SvgPicture.asset(
                    AppAssets.info,
                    width: 16,
                    height: 16,
                    colorFilter: .mode(colors.textMuted, .srcIn),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlagBox extends StatelessWidget {
  const _FlagBox({required this.colors, required this.flag});

  final AppColors colors;
  final String flag;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: .center,
      decoration: BoxDecoration(color: colors.chip, borderRadius: .circular(9)),
      child: Text(flag, style: const TextStyle(fontSize: 17, height: 1)),
    );
  }
}

class _ProtoChips extends StatelessWidget {
  const _ProtoChips({required this.colors, required this.meta});

  final AppColors colors;
  final ({String protocol, String? network, String? security}) meta;

  @override
  Widget build(BuildContext context) {
    final tail = [meta.network, meta.security].whereType<String>().join(' · ');

    return Row(
      children: [
        Container(
          padding: const .symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: colors.chip,
            borderRadius: .circular(4),
          ),
          child: Text(
            meta.protocol,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 8.5,
              fontWeight: .w700,
              letterSpacing: 0.5,
              color: colors.textSecondary,
            ),
          ),
        ),
        if (tail.isNotEmpty)
          Expanded(
            child: Padding(
              padding: const .only(left: 6),
              child: Text(
                '· $tail',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 8.5,
                  fontWeight: .w600,
                  letterSpacing: 0.4,
                  color: colors.textMuted,
                ),
                maxLines: 1,
                overflow: .ellipsis,
              ),
            ),
          ),
      ],
    );
  }
}

class _PingPill extends StatefulWidget {
  const _PingPill({
    required this.colors,
    required this.host,
    required this.port,
    required this.delayMs,
  });

  final AppColors colors;
  final String host;
  final int port;
  final int delayMs;

  @override
  State<_PingPill> createState() => _PingPillState();
}

class _PingPillState extends State<_PingPill> {
  Duration? _rtt;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    if (widget.delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: widget.delayMs));
    }
    if (!mounted) return;
    final rtt = await PingService().ping(widget.host, widget.port);
    if (!mounted) return;
    setState(() {
      _rtt = rtt;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    if (!_done) {
      return SizedBox(
        width: 46,
        height: 18,
        child: Center(
          child: SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              valueColor: AlwaysStoppedAnimation(colors.textMuted),
            ),
          ),
        ),
      );
    }

    final ms = _rtt?.inMilliseconds;
    final color = ms == null
        ? colors.danger
        : ms < 100
        ? colors.ok
        : ms < 250
        ? colors.warn
        : colors.danger;
    final label = ms == null ? 'timeout' : '$ms ms';

    return Container(
      padding: const .symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: .circular(100),
      ),
      child: Row(
        mainAxisSize: .min,
        spacing: 5,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: .circle, color: color),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: .w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(
        onPressed: onAdd,
        child: const Text('Add subscription'),
      ),
    );
  }
}

({String protocol, String? network, String? security}) _serverMeta(
  String configJson,
) {
  String? group(RegExp re) =>
      re.firstMatch(configJson)?.group(1)?.toUpperCase();
  return (
    protocol:
        group(
          RegExp(
            r'"protocol"\s*:\s*"(vless|vmess|shadowsocks|trojan|wireguard)"',
          ),
        ) ??
        'PROXY',
    network: group(RegExp(r'"network"\s*:\s*"(\w+)"')),
    security: group(RegExp(r'"security"\s*:\s*"(\w+)"')),
  );
}

({String host, int port})? _endpoint(String configJson) {
  try {
    final json = jsonDecode(configJson) as Map<String, dynamic>;
    final outbounds = (json['outbounds'] as List).cast<Map<String, dynamic>>();
    final proxy = outbounds.firstWhere((o) => (o['tag'] as String?) == 'proxy');
    final settings = proxy['settings'] as Map<String, dynamic>;

    final Map<String, dynamic> node;
    final vnext = settings['vnext'];
    final ssServers = settings['servers'];
    if (vnext is List && vnext.isNotEmpty) {
      node = vnext.first as Map<String, dynamic>;
    } else if (ssServers is List && ssServers.isNotEmpty) {
      node = ssServers.first as Map<String, dynamic>;
    } else {
      return null;
    }

    final host = node['address'] as String?;
    final rawPort = node['port'];
    final port = rawPort is int ? rawPort : int.tryParse('$rawPort');
    if (host == null || host.isEmpty || port == null) return null;
    return (host: host, port: port);
  } catch (_) {
    return null;
  }
}

Future<void> _showServerInfo(
  BuildContext context,
  VpnServer server,
  AppColors colors,
) {
  final textTheme = Theme.of(context).textTheme;

  String pretty;
  try {
    pretty = const JsonEncoder.withIndent(
      '  ',
    ).convert(jsonDecode(server.configJson));
  } catch (_) {
    pretty = server.configJson;
  }

  final media = MediaQuery.of(context);
  final maxHeight =
      media.size.height - media.viewPadding.top - kToolbarHeight - 8;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: maxHeight),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const .fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: .stretch,
          mainAxisSize: .min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(server.title, style: textTheme.titleMedium),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pretty));
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(content: Text('Config copied')),
                      );
                  },
                  icon: SvgPicture.asset(
                    AppAssets.copy,
                    width: 18,
                    height: 18,
                    colorFilter: .mode(colors.textSecondary, .srcIn),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const .all(14),
                  decoration: BoxDecoration(
                    color: colors.inputFill,
                    borderRadius: .circular(AppDims.radiusControl),
                  ),
                  child: SelectableText(
                    pretty,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
