import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Copy and show snackbar
void copyToClipboard(BuildContext context, String text, String toast) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(toast)));
}
