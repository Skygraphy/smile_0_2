import 'package:flutter/material.dart';

import '../l10n/smile_texts.dart';

/// The one confirmation dialog. [destructive] colors the confirm button
/// coral-on-error style for Delete/Leave/Remove. Returns true only when
/// the user confirmed; dismissing counts as cancel.
Future<bool> showSmileConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final t = SmileTexts.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final msg = message;
      return AlertDialog(
        title: Text(title),
        content: msg == null ? null : Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.actionCancel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
