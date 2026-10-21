import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:slipstream/features/qr/data/qr_scan.dart';

sealed class QrImportResult {
  const QrImportResult();
}

// The user closed the picker without choosing an image.
final class QrImportCancelled extends QrImportResult {
  const QrImportCancelled();
}

final class QrImportFound extends QrImportResult {
  const QrImportFound(this.text);

  final String text;
}

// The image has no readable QR code (or could not be read at all).
final class QrImportNotFound extends QrImportResult {
  const QrImportNotFound();
}

// Reads a QR code from an image the user picks, e.g. a screenshot.
@lazySingleton
class QrImageImporter {
  QrImageImporter() : pickImagePath = _pickFromGallery, readQrValues = _read;

  @visibleForTesting
  QrImageImporter.custom({
    required this.pickImagePath,
    required this.readQrValues,
  });

  // The path of the chosen image, or null if the picker was closed.
  final Future<String?> Function() pickImagePath;

  // The raw text of every QR code found in the image at the path.
  final Future<List<String?>> Function(String path) readQrValues;

  Future<QrImportResult> import() async {
    final path = await pickImagePath();
    if (path == null) return const QrImportCancelled();

    try {
      final text = QrScanSession().accept(await readQrValues(path));
      return text == null ? const QrImportNotFound() : QrImportFound(text);
    } on Exception {
      return const QrImportNotFound();
    }
  }
}

// requestFullMetadata: false keeps iOS from asking for photo library access.
Future<String?> _pickFromGallery() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    requestFullMetadata: false,
  );
  return picked?.path;
}

Future<List<String?>> _read(String path) async {
  final controller = MobileScannerController();
  try {
    final capture = await controller.analyzeImage(
      path,
      formats: const [BarcodeFormat.qrCode],
    );
    return [for (final b in capture?.barcodes ?? <Barcode>[]) b.rawValue];
  } finally {
    await controller.dispose();
  }
}
