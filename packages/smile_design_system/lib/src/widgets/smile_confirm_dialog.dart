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

/// The one "enter a name" dialog (create or rename a Space, Album or
/// Frame). Returns the trimmed name, or null when cancelled, left empty
/// or unchanged from [initialValue].
Future<String?> showSmileNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialValue = '',
  String? hint,
  String? subtitle,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (context) =>
        _NameDialog(title: title, confirmLabel: confirmLabel, initialValue: initialValue, hint: hint, subtitle: subtitle),
  );
  final trimmed = result?.trim() ?? '';
  if (trimmed.isEmpty || trimmed == initialValue.trim()) return null;
  return trimmed;
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.confirmLabel, required this.initialValue, this.hint, this.subtitle});

  final String title;
  final String confirmLabel;
  final String initialValue;
  final String? hint;

  /// A quiet line under the title, e.g. which Space a new album goes to.
  final String? subtitle;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    return AlertDialog(
      title: widget.subtitle == null
          ? Text(widget.title)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.title),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: t.name, hintText: widget.hint),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.actionCancel)),
        TextButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: Text(widget.confirmLabel)),
      ],
    );
  }
}
