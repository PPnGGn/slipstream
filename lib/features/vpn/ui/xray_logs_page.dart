import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/clipboard.dart';
import 'package:slipstream/core/ui/toast/show_toast.dart';
import 'package:slipstream/core/ui/widgets/page_header.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';
import 'package:slipstream/features/vpn/data/xray_log_store.dart';
import 'package:slipstream/features/vpn/presentation/xray_logs_view.dart';

/// The live log of the Xray core. What it shows and says is decided in
/// `xray_logs_view.dart`; this page keeps the filter, the scroll position and
/// the layout.
class XrayLogsPage extends StatefulWidget {
  const XrayLogsPage({super.key});

  @override
  State<XrayLogsPage> createState() => _XrayLogsPageState();
}

class _XrayLogsPageState extends State<XrayLogsPage> {
  static const _bottomThreshold = 48.0;
  static const _maxSettleAttempts = 20;

  final _scroll = ScrollController();
  var _filter = LogLevelFilter.all;

  /// True while the view sticks to the newest line. Scrolling up turns it off,
  /// getting back to the bottom turns it on again.
  var _following = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final atBottom = position.pixels >= position.maxScrollExtent - _bottomThreshold;
    if (atBottom != _following) setState(() => _following = atBottom);
  }

  // The list builds its rows lazily, so its length is only an estimate until
  // the end is on screen: jump again until it stops growing.
  Future<void> _scrollToBottom() async {
    for (var i = 0; i < _maxSettleAttempts; i++) {
      if (!_scroll.hasClients) return;
      final before = _scroll.position.maxScrollExtent;
      _scroll.jumpTo(before);
      await WidgetsBinding.instance.endOfFrame;
      if (!_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent <= before) return;
    }
  }

  void _pick(LogLevelFilter filter) {
    setState(() {
      _filter = filter;
      _following = true;
    });
  }

  void _copy(List<VpnLogMessage> visible) {
    final toast = logsCopyToast(visible.length);
    if (visible.isEmpty) {
      showToastSpec(toast);
      return;
    }
    copyToClipboard(
      logsAsText(visible),
      title: toast.title,
      subtitle: toast.subtitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = getIt<XrayLogStore>();
    final colors = AppColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<VpnLogMessage>>(
          stream: store.stream,
          initialData: store.history,
          builder: (context, snapshot) {
            final all = snapshot.data ?? const <VpnLogMessage>[];
            final visible = filterLogs(all, _filter);
            if (_following && visible.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _scrollToBottom(),
              );
            }

            return Column(
              children: [
                PageHeader(
                  title: 'Xray core logs',
                  actions: [
                    BoxIconButton(
                      iconPath: AppAssets.doc,
                      onTap: () => context.push('/logs/flutter'),
                    ),
                    _CopyButton(colors: colors, onTap: () => _copy(visible)),
                  ],
                ),
                Padding(
                  padding: const .fromLTRB(20, 6, 20, 10),
                  child: Row(
                    spacing: 6,
                    children: [
                      for (final filter in LogLevelFilter.values)
                        _FilterChip(
                          key: ValueKey('log-filter-${filter.name}'),
                          colors: colors,
                          label: filter.label,
                          selected: filter == _filter,
                          onTap: () => _pick(filter),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const .fromLTRB(20, 0, 20, 24),
                    clipBehavior: .antiAlias,
                    decoration: BoxDecoration(
                      color: colors.inputFill,
                      borderRadius: .circular(16),
                      border: .all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: visible.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const .all(32),
                                    child: Text(
                                      logsEmptyText(
                                        total: all.length,
                                        filter: _filter,
                                      ),
                                      textAlign: .center,
                                      style: TextStyle(color: colors.textMuted),
                                    ),
                                  ),
                                )
                              : SelectionArea(
                                  child: ListView.builder(
                                    controller: _scroll,
                                    padding: const .symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    itemCount: visible.length,
                                    itemBuilder: (context, index) => _LogRow(
                                      key: ObjectKey(visible[index]),
                                      entry: visible[index],
                                      colors: colors,
                                    ),
                                  ),
                                ),
                        ),
                        _StatusBar(
                          colors: colors,
                          lines: visible.length,
                          following: _following,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 32 px "Copy" button in the header.
class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.colors, required this.onTap});

  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: .opaque,
      child: Container(
        height: 32,
        padding: const .symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: .circular(10),
          border: .all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: .min,
          spacing: 6,
          children: [
            SvgPicture.asset(
              AppAssets.copy,
              width: 12,
              height: 12,
              colorFilter: .mode(colors.textSecondary, .srcIn),
            ),
            Text(
              'Copy',
              style: TextStyle(
                fontSize: 11,
                fontWeight: .w600,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.colors,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppColors colors;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: .opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 28,
        padding: const .symmetric(horizontal: 13),
        alignment: .center,
        decoration: BoxDecoration(
          color: selected ? colors.segment : Colors.transparent,
          borderRadius: .circular(9),
          border: selected ? null : .all(color: colors.border),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color.fromRGBO(20, 20, 32, 0.2),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: .w600,
            letterSpacing: 0.44,
            color: selected ? colors.textPrimary : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// One line of the log: time, level (colored, bold) and the message.
class _LogRow extends StatelessWidget {
  const _LogRow({super.key, required this.entry, required this.colors});

  final VpnLogMessage entry;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: 9.5,
      height: 1.7,
      fontWeight: .w500,
    );
    final levelColor = switch (logSeverityOf(entry.level)) {
      LogSeverity.error => colors.danger,
      LogSeverity.warn => colors.warn,
      LogSeverity.debug => colors.textMuted,
      LogSeverity.info => colors.ok,
    };

    // Two columns: the level over the time on the left (as wide as the time
    // alone, so the message gets the room), the message on the right.
    return Row(
      crossAxisAlignment: .start,
      spacing: 8,
      children: [
        Column(
          crossAxisAlignment: .start,
          children: [
            Text(
              logLevelLabel(entry.level),
              key: const Key('log-level'),
              style: mono.copyWith(color: levelColor, fontWeight: .w700),
            ),
            Text(
              logTimeOf(entry.timestampMs),
              style: mono.copyWith(color: colors.textMuted),
            ),
          ],
        ),
        Expanded(
          child: Text(
            entry.message,
            style: mono.copyWith(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// "● FOLLOWING · 14 LINES · TUNNEL UP" under the log.
class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.colors,
    required this.lines,
    required this.following,
  });

  final AppColors colors;
  final int lines;
  final bool following;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VpnServiceCubit, VpnState>(
      bloc: getIt<VpnServiceCubit>(),
      builder: (context, state) {
        final tunnelUp = isTunnelUp(state);
        return Container(
          padding: const .symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: Row(
            spacing: 8,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: .circle,
                  color: tunnelUp ? colors.ok : colors.textMuted,
                ),
                child: const SizedBox.square(dimension: 6),
              ),
              Expanded(
                child: Text(
                  logsStatusLine(
                    lines: lines,
                    tunnelUp: tunnelUp,
                    following: following,
                  ),
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    fontWeight: .w600,
                    letterSpacing: 0.9,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
