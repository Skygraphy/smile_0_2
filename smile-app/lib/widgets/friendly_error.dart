import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/offline.dart';

/// No technical error texts for people (2026-10-11): without a connection
/// a short, friendly note like WhatsApp's; the raw error only in the log.

/// Whether the phone has any network at all (Wi-Fi or mobile data).
Future<bool> hasNetwork() => Offline.hasNetwork();

/// "Keine Internetverbindung – prüfe deine Verbindung …" with an OK button.
Future<void> showNoConnection(BuildContext context) {
  final t = SmileTexts.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t.noConnectionTitle),
      content: Text(t.noConnectionMessage),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.ok))],
    ),
  );
}

/// The reason to put into a message like "Aktion fehlgeschlagen: …":
/// "keine Internetverbindung" instead of a ClientException.
String errorReason(BuildContext context, Object error) => errorReasonIn(SmileTexts.of(context), error);

/// [errorReason] with the texts taken before an await.
String errorReasonIn(SmileTexts t, Object error) {
  if (Offline.isConnectionError(error)) {
    debugPrint('SmileError (offline): $error');
    return t.noConnectionReason;
  }
  return '$error';
}
