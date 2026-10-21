import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:qr_flutter/qr_flutter.dart';

// Draws [data] as a PNG about [size] pixels wide: black on white, even in the
// dark theme, because many scanners cannot read an inverted code. The code is
// surrounded by 4 empty modules (the quiet zone the QR spec asks for).
// Every module is a whole number of pixels so the edges stay sharp; the side is
// therefore at most [size], never more.
Future<Uint8List> renderQrPng(String data, {int size = 1024}) async {
  final qr = QrCode.fromData(
    data: data,
    errorCorrectLevel: QrErrorCorrectLevel.L,
  );
  final QrPainter painter;
  try {
    // QrValidator would say "valid" here: the data is only encoded, and found
    // too long, when the painter is created.
    painter = QrPainter.withQr(qr: qr, gapless: true);
  } on InputTooLongException {
    throw ArgumentError.value(data, 'data', 'Does not fit into a QR code');
  }

  final modules = qr.moduleCount;
  final module = size ~/ (modules + 8);
  final side = module * (modules + 8);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  canvas.translate(module * 4.0, module * 4.0);
  painter.paint(canvas, Size.square((module * modules).toDouble()));

  final image = await recorder.endRecording().toImage(side, side);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}
