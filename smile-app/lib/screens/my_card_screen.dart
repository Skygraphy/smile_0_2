import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/invite_links.dart';
import '../services/profile_service.dart';
import 'handle_edit_screen.dart';

/// "Meine Karte" (2026-10-17): the own Smile name as a QR code and a link
/// (smileapp.app/@name) -- shown in person or shared, so someone can invite
/// you into an album without knowing your email.
class MyCardScreen extends StatefulWidget {
  const MyCardScreen({super.key, required this.profile});

  final SmileProfile profile;

  @override
  State<MyCardScreen> createState() => _MyCardScreenState();
}

class _MyCardScreenState extends State<MyCardScreen> {
  late String? _handle = widget.profile.handle;

  Future<void> _chooseName() async {
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => HandleEditScreen(current: _handle, displayName: widget.profile.displayName),
      ),
    );
    if (saved != null && mounted) setState(() => _handle = saved.isEmpty ? null : saved);
  }

  Future<void> _share(String handle) async {
    final t = SmileTexts.of(context);
    await SharePlus.instance.share(ShareParams(text: t.myCardMessage(InviteLinks.forHandle(handle))));
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final handle = _handle;
    return Scaffold(
      appBar: AppBar(title: Text(t.myCard)),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              SmileSpacing.l, SmileSpacing.l, SmileSpacing.l, SmileSpacing.l + MediaQuery.paddingOf(context).bottom),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(SmileSpacing.l),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(SmileRadius.l),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.alphaBlend(scheme.primary.withValues(alpha: 0.18), scheme.surfaceContainerHigh), scheme.surfaceContainerHigh],
                    ),
                  ),
                  child: Column(
                    children: [
                      SmileAvatar(name: widget.profile.displayName, avatarUrl: widget.profile.avatarUrl, size: 72),
                      const SizedBox(height: SmileSpacing.s),
                      Text(widget.profile.displayName,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                      if (handle != null) ...[
                        const SizedBox(height: 2),
                        Text('@$handle',
                            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: SmileSpacing.l),
                        Container(
                          padding: const EdgeInsets.all(SmileSpacing.m),
                          decoration:
                              BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(SmileRadius.l)),
                          child: QrImageView(data: InviteLinks.forHandle(handle), size: 200, backgroundColor: Colors.white),
                        ),
                        const SizedBox(height: SmileSpacing.s),
                        Text('smileapp.app/@$handle', style: TextStyle(color: muted, fontSize: 12.5)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: SmileSpacing.l),
                Text(handle != null ? t.myCardHint : t.myCardNeedsName,
                    textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.45)),
                const SizedBox(height: SmileSpacing.l),
                if (handle != null)
                  FilledButton.icon(
                    onPressed: () => _share(handle),
                    icon: const Icon(SmileIcons.shareOut),
                    label: Text(t.shareMyCard),
                  )
                else
                  FilledButton.icon(
                    onPressed: _chooseName,
                    icon: const Icon(SmileIcons.handle),
                    label: Text(t.smileNameChoose),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
