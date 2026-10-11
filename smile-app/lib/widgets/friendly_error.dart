import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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

/// The reason to put into a message like "Das hat leider nicht geklappt. …"
/// -- NEVER the error itself (decided 2026-10-11: no error messages for
/// people, ever). Only "Keine Internetverbindung." or "Bitte versuche es
/// noch einmal."; the real error goes to the log and Crashlytics.
String errorReason(BuildContext context, Object error) => errorReasonIn(SmileTexts.of(context), error);

/// [errorReason] with the texts taken before an await.
String errorReasonIn(SmileTexts t, Object error) {
  if (Offline.isConnectionError(error)) {
    debugPrint('SmileError (offline): $error');
    return t.noConnectionReason;
  }
  debugPrint('SmileError: $error');
  try {
    unawaited(FirebaseCrashlytics.instance.recordError(error, StackTrace.current, reason: 'shown as "try again"'));
  } catch (_) {}
  return t.tryAgainReason;
}
