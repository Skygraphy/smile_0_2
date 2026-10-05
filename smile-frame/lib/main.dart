import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import 'screens/pairing_screen.dart';
import 'screens/slideshow_screen.dart';
import 'services/frame_credentials_store.dart';
import 'services/media_cache_store.dart';
import 'services/pairing_service.dart';
import 'services/push_service.dart';
import 'services/sync_service.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No explicit FirebaseOptions: on Android this reads the native
  // google-services.json (Android-only for now, matches the plan's
  // platform scope) via the Google Services Gradle plugin.
  await Firebase.initializeApp();
  await PushService().initialize();
  runApp(const SmileFrameApp());
}

class SmileFrameApp extends StatelessWidget {
  const SmileFrameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smile-Frame',
      debugShowCheckedModeBanner: false,
      theme: SmileTheme.themeData,
      locale: const Locale('de'),
      localizationsDelegates: SmileTexts.localizationsDelegates,
      supportedLocales: SmileTexts.supportedLocales,
      home: StartupGate(),
    );
  }
}

/// Reads the on-device credential store on cold start and routes straight
/// to the pairing screen (UNPAIRED) or the paired display (concept doc
/// sect. 24, zero-touch boot): no user interaction needed to decide which
/// screen to show.
class StartupGate extends StatefulWidget {
  StartupGate({
    super.key,
    FrameCredentialsStore? credentialsStore,
    PairingService? pairingService,
    SyncService? syncService,
    MediaCacheStore? cacheStore,
  })  : credentialsStore = credentialsStore ?? FrameCredentialsStore(),
        pairingService = pairingService ?? PairingService(),
        syncService = syncService ?? SyncService(),
        cacheStore = cacheStore ?? MediaCacheStore();

  final FrameCredentialsStore credentialsStore;
  final PairingService pairingService;
  final SyncService syncService;
  final MediaCacheStore cacheStore;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  FrameCredentialsStore get _credentialsStore => widget.credentialsStore;
  bool? _isProvisioned;
  String? _frameId;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final provisioned = await _credentialsStore.isProvisioned();
    final frameId = provisioned ? await _credentialsStore.frameId : null;
    if (!mounted) return;
    setState(() {
      _isProvisioned = provisioned;
      _frameId = frameId;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isProvisioned == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isProvisioned == true && _frameId != null) {
      return SlideshowScreen(syncService: widget.syncService, cacheStore: widget.cacheStore, onUnpaired: _check);
    }
    return PairingScreen(
      pairingService: widget.pairingService,
      credentialsStore: widget.credentialsStore,
    );
  }
}
