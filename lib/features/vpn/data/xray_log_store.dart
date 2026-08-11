import 'dart:async';
import 'dart:collection';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';

@lazySingleton
class XrayLogStore {
  static const _maxEntries = 500;
  static const _emitInterval = Duration(milliseconds: 200);

  final ListQueue<VpnLogMessage> _entries = ListQueue<VpnLogMessage>();
  final _controller = StreamController<List<VpnLogMessage>>.broadcast();
  Timer? _emitTimer;

  List<VpnLogMessage> get history => List.unmodifiable(_entries);

  Stream<List<VpnLogMessage>> get stream => _controller.stream;

  void add(VpnLogMessage entry) {
    _entries.addLast(entry);
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }
    _emitTimer ??= Timer(_emitInterval, _flush);
  }

  void clear() {
    _entries.clear();
    _flush();
  }

  void _flush() {
    _emitTimer?.cancel();
    _emitTimer = null;
    _controller.add(history);
  }

  @disposeMethod
  void dispose() {
    _emitTimer?.cancel();
    _controller.close();
  }
}
