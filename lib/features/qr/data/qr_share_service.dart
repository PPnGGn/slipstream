import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slipstream/features/qr/data/qr_image_renderer.dart';

// Sends a QR code through the system share sheet as a PNG image.
@lazySingleton
class QrShareService {
  QrShareService()
    : _render = renderQrPng,
      _tempDir = getTemporaryDirectory,
      _send = _sharePng;

  @visibleForTesting
  QrShareService.custom({
    required Future<Uint8List> Function(String data) render,
    required Future<Directory> Function() tempDir,
    required Future<void> Function(String path) send,
  }) : _render = render,
       _tempDir = tempDir,
       _send = send;

  final Future<Uint8List> Function(String data) _render;
  final Future<Directory> Function() _tempDir;
  final Future<void> Function(String path) _send;

  // The image is named after [name], so that is what the receiver sees.
  // The file is not deleted afterwards: on Android the receiving app reads it
  // only after the share sheet has returned. Instead the folder is emptied
  // before the next share, so at most one image stays in the cache.
  Future<void> shareQr({required String data, required String name}) async {
    final png = await _render(data);

    final dir = Directory('${(await _tempDir()).path}/qr_share');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    final file = File('${dir.path}/${safeFileName(name)}.png');
    await file.writeAsBytes(png);
    await _send(file.path);
  }
}

Future<void> _sharePng(String path) async {
  await SharePlus.instance.share(
    ShareParams(files: [XFile(path, mimeType: 'image/png')]),
  );
}

// A file name from free text: no characters file systems reject, no hidden
// or relative names, at most 50 characters, never empty.
String safeFileName(String name) {
  final cleaned = name
      .trim()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[/\\:*?"<>|\u0000-\u001F\u007F]'), '')
      .replaceAll(RegExp(r'^\.+|\.+$'), '');
  // Cut by code points, so an emoji is never split in half.
  final capped = String.fromCharCodes(cleaned.runes.take(50));
  return capped.isEmpty ? 'subscription' : capped;
}
