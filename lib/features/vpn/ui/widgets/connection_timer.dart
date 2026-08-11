import 'dart:async';
import 'package:flutter/material.dart';
import 'package:slipstream/core/formatters.dart';

class ConnectionTimer extends StatefulWidget {
  const ConnectionTimer({super.key, required this.connectedAt, this.style});

  final DateTime connectedAt;
  final TextStyle? style;

  @override
  State<ConnectionTimer> createState() => _ConnectionTimerState();
}

class _ConnectionTimerState extends State<ConnectionTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.connectedAt);
    return Text(formatDuration(elapsed), style: widget.style);
  }
}
