import 'package:flutter/material.dart';

/// A plain "enter someone's email" prompt -- shared by every flow that
/// looks a person up by email server-side (album_info_screen.dart's
/// "Person einladen"/"Space einladen", space_co_owners_screen.dart's
/// "Co-Owner hinzufügen"). Returns the entered email, or null if cancelled.
class EmailDialog extends StatefulWidget {
  const EmailDialog({super.key, required this.title, required this.explanation, required this.confirmLabel});

  final String title;
  final String explanation;
  final String confirmLabel;

  @override
  State<EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<EmailDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.explanation, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-Mail-Adresse'),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        TextButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: Text(widget.confirmLabel)),
      ],
    );
  }
}
