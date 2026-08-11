import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slipstream/app/di/injector.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Логи ядра'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Логи Flutter',
            onPressed: () => context.push('/logs/flutter'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Очистить',
            onPressed: store.clear,
          ),
        ],
      ),
      body: StreamBuilder<List<VpnLogMessage>>(
        stream: store.stream,
        initialData: store.history,
        builder: (context, snapshot) {
          final logs = snapshot.data ?? const <VpnLogMessage>[];
          if (logs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Логи ядра появятся во время подключения.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Stack(
            children: [
              SelectionArea(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final entry = logs[index];
                    return _LogTile(key: ObjectKey(entry), entry: entry);
                  },
                ),
              ),
              if (!_atBottom)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    tooltip: 'К последним логам',
                    onPressed: () => _scrollToBottom(),
                    child: const Icon(Icons.arrow_downward),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({super.key, required this.entry});

  final VpnLogMessage entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _LevelBadge(level: entry.level),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.message,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatTime(entry.timestampMs)} · ${entry.source}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(int timestampMs) {
    final t = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${three(t.millisecond)}';
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level.toLowerCase()) {
      'error' => Colors.redAccent,
      'warning' || 'warn' => Colors.orange,
      'debug' => Colors.blueGrey,
      _ => Colors.green,
    };
    return Icon(Icons.circle, size: 10, color: color);
  }
}
