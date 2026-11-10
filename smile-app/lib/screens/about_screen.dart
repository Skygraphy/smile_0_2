import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:smile_design_system/smile_design_system.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Über Smile" (2026-11-10): version, Impressum, Datenschutz, how to delete
/// the account, and the open-source licences. Impressum and Datenschutz are
/// the pages on smileapp.app -- Google Play wants the privacy policy reachable
/// from inside the app, the ECG the Impressum "leicht zugänglich".
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  static const site = 'https://smileapp.app';
  static const impressum = '$site/impressum.html';
  static const privacy = '$site/datenschutz.html';
  static const deleteAccount = '$site/konto-loeschen.html';

  /// Opens one of the pages in the browser; quietly nothing if it can't.
  static Future<void> open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    }, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget icon(IconData data) => Icon(data, color: scheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: SmileFitText(t.aboutSmile)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: SmileTheme.primary, borderRadius: BorderRadius.circular(18)),
                  alignment: Alignment.center,
                  child: const Text('S', style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 10),
                const SmileWordmark(),
                if (_version != null) ...[
                  const SizedBox(height: 2),
                  Text(t.versionValue(_version!), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          SmileObjectTile(
            leading: icon(SmileIcons.card),
            title: t.impressum,
            trailing: Icon(SmileIcons.web, size: 18, color: scheme.onSurfaceVariant),
            onTap: () => AboutScreen.open(AboutScreen.impressum),
          ),
          SmileObjectTile(
            leading: icon(SmileIcons.lock),
            title: t.privacyPolicy,
            trailing: Icon(SmileIcons.web, size: 18, color: scheme.onSurfaceVariant),
            onTap: () => AboutScreen.open(AboutScreen.privacy),
          ),
          SmileObjectTile(
            leading: icon(SmileIcons.delete),
            title: t.deleteAccount,
            subtitle: t.deleteAccountWebHint,
            trailing: Icon(SmileIcons.web, size: 18, color: scheme.onSurfaceVariant),
            onTap: () => AboutScreen.open(AboutScreen.deleteAccount),
          ),
          SmileObjectTile(
            leading: icon(SmileIcons.caption),
            title: t.licenses,
            subtitle: t.licensesHint,
            trailing: Icon(SmileIcons.chevron, size: 16, color: scheme.onSurfaceVariant),
            onTap: () => showLicensePage(context: context, applicationName: 'Smile', applicationVersion: _version),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
            child: Text(
              '© 2026 Skygraphy Copter Technologies e.U.\nadmin@skygraphy.com',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.5, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
