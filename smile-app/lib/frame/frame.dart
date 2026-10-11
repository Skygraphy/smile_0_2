/// The one door between the app and the Frame side (decided 2026-10-11:
/// "Trenne aber immer alles zwischen Frame und App"). App code imports only
/// this file; everything under lib/frame stays the Frame's own and never
/// imports app code. Frame data (credentials, encrypted cache, the
/// frame_mode marker) is kept apart from the app's.
library;

import 'frame_mode.dart';
import 'services/frame_credentials_store.dart';
import 'services/pairing_service.dart';

export 'frame_app.dart' show FrameModeApp;
export 'frame_mode.dart' show FrameMode;
export 'screens/pairing_screen.dart' show PairingScreen;
export 'services/push_service.dart' show firebaseMessagingBackgroundHandler;
export 'services/push_sync_signal.dart' show PushSyncSignal;

/// Makes THIS device the Frame with [pairingCode] ("Dieses Gerät"): claims
/// it like any Frame device would, then [beforeSwitch] lets the app clean
/// up its own side (sign-out etc.), then the Frame's credentials are kept
/// and the whole app turns into the Frame. Throws if the claim fails --
/// nothing has changed then.
Future<void> becomeFrame(String pairingCode, {Future<void> Function()? beforeSwitch}) async {
  final credentials = await PairingService().claimPairing(pairingCode);
  await beforeSwitch?.call();
  await FrameCredentialsStore().saveCredentials(
    frameId: credentials.frameId,
    spaceId: credentials.spaceId,
    accessToken: credentials.accessToken,
    accessTokenExpiresAt: credentials.accessTokenExpiresAt,
    refreshSecret: credentials.refreshSecret,
  );
  await FrameMode.enter();
}
