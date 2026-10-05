import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/channel_feed_screen.dart';
import 'screens/channel_members_screen.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/my_invites_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/space_co_owners_screen.dart';
import 'screens/spaces_screen.dart';
import 'services/profile_service.dart';
import 'services/push_service.dart';
import 'services/sync_bus.dart';
import 'package:smile_design_system/smile_design_system.dart';

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
    // Silent cross-device sync (sync-fanout) -- never shown, just reloads
    // whatever is on screen.
    if (message.data['type'] == 'sync') {
      SyncBus.emit(SyncEvent.fromPush(message.data));
      return;
    }
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
  // Silent sync pushes only reach onMessage while in the foreground --
  // anything that changed while backgrounded is caught up here instead.
  _resumeListener = AppLifecycleListener(onResume: () => SyncBus.emit(const SyncEvent.everything()));
  // While open: the same sync signals, live (works where silent pushes are
  // throttled -- iOS). Push above stays for when the app is closed.
  LiveSyncChannel.start();
  runApp(const SmileApp());
}

// ignore: unused_element -- held only so the listener isn't garbage-collected.
AppLifecycleListener? _resumeListener;

/// Routes a tapped notification -- see invite-channel-member,
/// invite-channel-share, invite-space-co-owner, transfer-space-ownership,
/// notify-event, and _shared/media-fanout.ts for the
/// `type`/`channel_id`+`channel_name`/`space_id`+`space_name` data shapes
/// (a payload only ever carries the pair relevant to its own `type`, never
/// both). Best-effort: an unrecognized/incomplete payload just does
/// nothing rather than crashing whatever screen happens to be showing --
/// each case below re-checks its own required field(s) instead of one
/// blanket guard up front, since different types need different fields.
void _openNotificationTarget(Map<String, dynamic> data) {
  final type = data['type'] as String?;
  if (type == null) return;
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;

  final channelId = data['channel_id'] as String?;
  final channelName = data['channel_name'] as String? ?? '';
  final spaceId = data['space_id'] as String?;
  final spaceName = data['space_name'] as String? ?? '';

  switch (type) {
    case 'channel_membership_invite':
    case 'channel_share_invite':
    case 'space_co_owner_invite':
      // The recipient isn't a channel member (or hasn't linked their Space,
      // or accepted the co-owner invite) yet -- can't view the target
      // itself before accepting, so this opens their invite inbox instead.
      navigator.push(MaterialPageRoute(builder: (_) => MyInvitesScreen()));
    case 'new_photo':
    case 'media_failed':
      if (channelId == null) return;
      navigator.push(
        MaterialPageRoute(builder: (_) => ChannelFeedScreen(channelId: channelId, channelName: channelName)),
      );
    case 'membership_invite_decided':
    case 'membership_request_decided':
    case 'share_invite_decided':
    case 'share_request_decided':
    // notify-event: who sees the channel changed -- the roster is where
    // the owner can end the share if they don't want that.
    case 'share_audience_changed':
    case 'share_ended_for_owner':
      // The outcome (who's now a member, what's now shared) shows up in
      // the roster -- more useful to land on than the feed itself.
      if (channelId == null) return;
      navigator.push(
        MaterialPageRoute(builder: (_) => ChannelMembersScreen(channelId: channelId, channelName: channelName)),
      );
    case 'space_ownership_transferred':
      navigator.push(MaterialPageRoute(builder: (_) => SpacesScreen()));
    case 'space_co_owner_invite_decided':
      if (spaceId == null) return;
      navigator.push(
        MaterialPageRoute(builder: (_) => SpaceCoOwnersScreen(spaceId: spaceId, spaceName: spaceName)),
      );
  }
}

class SmileApp extends StatelessWidget {
  const SmileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smile',
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: SmileTheme.themeData,
      // German only for now; all Smile terms come from SmileTexts, and the
      // Material/Cupertino delegates make built-in widgets German too.
      locale: const Locale('de'),
      localizationsDelegates: SmileTexts.localizationsDelegates,
      supportedLocales: SmileTexts.supportedLocales,
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
          // Keyed by user id so signing out and back in as someone else
          // (common on a shared test device) re-checks that person's own
          // profile instead of reusing the previous user's cached state.
          return _ProfileGate(key: ValueKey(session.user.id));
        }
        return const LoginScreen();
      },
    );
  }
}

/// Every user needs at least a display name (migrations/0029's not-null
/// profiles.display_name) before using the rest of the app -- an avatar
/// is optional, SmileAvatar's initials fallback covers that half of the
/// requirement automatically. Shown once per account, right after the
/// auth session exists but before SpacesScreen, then never again once a
/// profiles row exists.
class _ProfileGate extends StatefulWidget {
  const _ProfileGate({super.key});

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  final _profileService = ProfileService();
  bool _isLoading = true;
  bool _hasProfile = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final profile = await _profileService.getMyProfile();
      if (!mounted) return;
      setState(() {
        _hasProfile = profile != null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Profil konnte nicht geladen werden: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _check, child: const Text('Erneut versuchen')),
              ],
            ),
          ),
        ),
      );
    }
    if (!_hasProfile) {
      return ProfileSetupScreen(
        profileService: _profileService,
        onDone: () => setState(() => _hasProfile = true),
      );
    }
    return const HomeShell();
  }
}
