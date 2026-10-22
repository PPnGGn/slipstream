import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/widgets/page_header.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';
import 'package:slipstream/features/vpn/data/xray_log_store.dart';

class XrayLogsPage extends StatefulWidget {
  const XrayLogsPage({super.key});

  @override
  State<XrayLogsPage> createState() => _XrayLogsPageState();
}

class _XrayLogsPageState extends State<XrayLogsPage> {
  static const _bottomThreshold = 48.0;
  static const _maxSettleAttempts = 20;

  final _scrollController = ScrollController();
  bool _atBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atBottom =
        position.pixels >= position.maxScrollExtent - _bottomThreshold;
    if (atBottom != _atBottom) {
      setState(() => _atBottom = atBottom);
    }
  }

  Future<void> _scrollToBottom() async {
    for (var i = 0; i < _maxSettleAttempts; i++) {
      if (!_scrollController.hasClients) return;
      final before = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(before);
      await WidgetsBinding.instance.endOfFrame;
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent <= before) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = getIt<XrayLogStore>();
    final colors = AppColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Логи ядра',
              actions: [
                BoxIconButton(
                  iconPath: AppAssets.doc,
                  onTap: () => context.push('/logs/flutter'),
                ),
                BoxIconButton(iconPath: AppAssets.trash, onTap: store.clear),
              ],
            ),
            Expanded(
              child: Container(
                margin: const .fromLTRB(20, 6, 20, 24),
                clipBehavior: .antiAlias,
                decoration: BoxDecoration(
                  color: colors.inputFill,
                  borderRadius: .circular(16),
                  border: .all(color: colors.border),
                ),
                child: StreamBuilder<List<VpnLogMessage>>(
                  stream: store.stream,
                  initialData: store.history,
                  builder: (context, snapshot) {
                    final logs = snapshot.data ?? const <VpnLogMessage>[];
                    if (logs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const .all(32),
                          child: Text(
                            'Логи ядра появятся во время подключения.',
                            textAlign: .center,
                            style: TextStyle(color: colors.textMuted),
                          ),
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        SelectionArea(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const .symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              final entry = logs[index];
                              return _LogTile(
                                key: ObjectKey(entry),
                                entry: entry,
                                colors: colors,
                              );
                            },
                          ),
                        ),
                        if (!_atBottom)
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: BoxIconButton(
                              iconPath: AppAssets.arrowDown,
                              onTap: () => _scrollToBottom(),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({super.key, required this.entry, required this.colors});

  final VpnLogMessage entry;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: 10,
      height: 1.6,
      fontWeight: .w500,
      color: colors.textSecondary,
    );

    return Padding(
      padding: const .symmetric(vertical: 3),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${_formatTime(entry.timestampMs)}  ',
              style: TextStyle(color: colors.textMuted),
            ),
            TextSpan(
              text: '${_levelLabel(entry.level)}  ',
              style: TextStyle(
                color: _levelColor(entry.level),
                fontWeight: .w700,
              ),
            ),
            TextSpan(text: entry.message),
            TextSpan(
              text: '  · ${entry.source}',
              style: TextStyle(color: colors.textMuted),
            ),
          ],
        ),
        style: mono,
      ),
    );
  }

  Color _levelColor(String level) => switch (level.toLowerCase()) {
    'error' => colors.danger,
    'warning' || 'warn' => colors.warn,
    'debug' => colors.textMuted,
    _ => colors.ok,
  };

  static String _levelLabel(String level) => switch (level.toLowerCase()) {
    'warning' => 'WARN',
    final other => other.toUpperCase(),
  };

  static String _formatTime(int timestampMs) {
    final t = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${three(t.millisecond)}';
  }
}
