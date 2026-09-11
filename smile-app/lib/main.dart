import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/channel_feed_screen.dart';
import 'screens/channel_members_screen.dart';
import 'screens/login_screen.dart';
import 'screens/spaces_screen.dart';
import 'services/push_service.dart';

final supabase = Supabase.instance.client;

/// Lets a foreground push notification (join request/approval/new photo)
/// show as a SnackBar -- FCM's own notification payload is only ever
/// auto-displayed by the OS while the app is backgrounded/killed.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Lets tap-to-navigate push outside any widget's own BuildContext (a
/// backgrounded-tap or a cold-start-via-notification handler runs before
/// any screen exists yet).
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  await Firebase.initializeApp();
  FirebaseMessaging.onMessage.listen((message) {
    final notification = message.notification;
    if (notification == null) return;
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('${notification.title}: ${notification.body}')),
    );
  });
  // Tapped while the app was backgrounded (not killed).
  FirebaseMessaging.onMessageOpenedApp.listen((message) => _openNotificationTarget(message.data));
  // Tapped while the app was fully killed -- the tap is what launched it,
  // so this has to be checked once explicitly rather than via a stream.
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) _openNotificationTarget(initialMessage.data);
  runApp(const SmileApp());
}

/// Routes a tapped notification to the channel it's about -- see the three
/// server-side triggers in claim-channel-invite, decide-channel-join-request,
/// and _shared/media-fanout.ts for the `type`/`channel_id`/`channel_name`
/// data shape. Best-effort: an unrecognized/incomplete payload just does
/// nothing rather than crashing whatever screen happens to be showing.
void _openNotificationTarget(Map<String, dynamic> data) {
  final type = data['type'] as String?;
  final channelId = data['channel_id'] as String?;
  final channelName = data['channel_name'] as String? ?? '';
  if (type == null || channelId == null) return;
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;

  switch (type) {
    case 'join_request':
      navigator.push(
        MaterialPageRoute(builder: (_) => ChannelMembersScreen(channelId: channelId, channelName: channelName)),
      );
    case 'join_request_approved':
    case 'new_photo':
      navigator.push(
        MaterialPageRoute(builder: (_) => ChannelFeedScreen(channelId: channelId, channelName: channelName)),
      );
  }
}

class SmileApp extends StatelessWidget {
  const SmileApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF6F61); // Living Coral
    final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    return MaterialApp(
      title: 'Smile',
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ),
        textTheme: textTheme,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: AuthGate(),
    );
  }
}

/// Switches between the login flow and the authenticated app based on the
/// current Supabase Auth session. Supabase's own auth-state stream (not a
/// manual navigation call) drives the switch, so a successful OTP
/// verification, a restored session on cold start, and a sign-out all route
/// through the same path.
class AuthGate extends StatelessWidget {
  AuthGate({super.key, PushService? pushService}) : pushService = pushService ?? PushService();

  final PushService pushService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? supabase.auth.currentSession;
        if (session != null) {
          // Fire-and-forget, idempotent (unique(user_id, fcm_token) just
          // refreshes updated_at if already registered) -- runs again on
          // every auth-state change, which is fine, not just once at
          // cold start, so a token obtained after this widget first built
          // (permission granted later, token rotated) still gets saved.
          unawaited(pushService.requestPermission().then((_) => pushService.registerCurrentToken()));
          return const SpacesScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
