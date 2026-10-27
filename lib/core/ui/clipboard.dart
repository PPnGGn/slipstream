import 'package:flutter/services.dart';
import 'package:slipstream/core/ui/toast/show_toast.dart';

/// Puts [text] on the clipboard and confirms it with a toast.
Future<void> copyToClipboard(
  String text, {
  required String title,
  String? subtitle,
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  showToast(title, subtitle: subtitle);
}
