import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/pairing_screen.dart';
import 'screens/slideshow_screen.dart';
import 'services/device_credentials_store.dart';
import 'services/media_cache_store.dart';
import 'services/pairing_service.dart';
import 'services/push_service.dart';
import 'services/sync_service.dart';

/// Same accent/typography as the Smile app (Living Coral, Inter) --
/// Smile-Frame is a display for the same product, not a separate look.
const smileAccentColor = Color(0xFFFF6F61);

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
    final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    return MaterialApp(
      title: 'Smile-Frame',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: smileAccentColor,
          brightness: Brightness.dark,
        ),
        textTheme: textTheme,
        useMaterial3: true,
      ),
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
    DeviceCredentialsStore? credentialsStore,
    PairingService? pairingService,
    SyncService? syncService,
    MediaCacheStore? cacheStore,
  })  : credentialsStore = credentialsStore ?? DeviceCredentialsStore(),
        pairingService = pairingService ?? PairingService(),
        syncService = syncService ?? SyncService(),
        cacheStore = cacheStore ?? MediaCacheStore();

  final DeviceCredentialsStore credentialsStore;
  final PairingService pairingService;
  final SyncService syncService;
  final MediaCacheStore cacheStore;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  DeviceCredentialsStore get _credentialsStore => widget.credentialsStore;
  bool? _isProvisioned;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final provisioned = await _credentialsStore.isProvisioned();
    final deviceId = provisioned ? await _credentialsStore.deviceId : null;
    if (!mounted) return;
    setState(() {
      _isProvisioned = provisioned;
      _deviceId = deviceId;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isProvisioned == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isProvisioned == true && _deviceId != null) {
      return SlideshowScreen(syncService: widget.syncService, cacheStore: widget.cacheStore);
    }
    return PairingScreen(
      pairingService: widget.pairingService,
      credentialsStore: widget.credentialsStore,
    );
  }
}
