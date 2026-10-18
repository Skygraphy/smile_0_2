import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_design_system/smile_design_system.dart';

/// The tips (decided 2026-10-18): short hints about what is easy to miss.
enum TipId {
  frameButton,
  slideshow,
  captionWhenSending,
  captionLater,
  favoriteHeart,
  selectPhotos,
  quickCapture,
  inviteWays,
  smileName,
  controlLevel,
  playback,
  favoritesRound,
  newAlbum,
  videoQuality,
  newsIcon,
}

/// When and how a tip shows: passend zur Seite, only while the feature is
/// still unused, at most one per day, in a quiet moment (a few seconds on a
/// page, no keyboard), each only once. "Verstanden" retires it, "Keine
/// Tipps mehr" switches all off (Einstellungen can switch them on again).
/// Kept on this phone.
class Tips {
  Tips._();

  static const _enabledKey = 'tips_enabled';
  static const _seenKey = 'tips_seen';
  static const _usedKey = 'tips_used';
  static const _dayKey = 'tips_last_day';
  static const _quiet = Duration(seconds: 5);

  /// For the switch in Einstellungen.
  static final enabled = ValueNotifier<bool>(true);

  static Timer? _pending;
  static OverlayEntry? _shown;

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static Future<void> load() async {
    final prefs = await _prefs();
    enabled.value = prefs?.getBool(_enabledKey) ?? true;
  }

  static Future<void> setEnabled(bool on) async {
    enabled.value = on;
    await (await _prefs())?.setBool(_enabledKey, on);
    if (!on) _hide();
  }

  /// "Tipps von vorne zeigen": the seen ones come again.
  static Future<void> reset() async {
    final prefs = await _prefs();
    await prefs?.remove(_seenKey);
    await prefs?.remove(_dayKey);
    await setEnabled(true);
  }

  /// The feature was used: its tip never needs to show.
  static Future<void> markUsed(TipId id) async {
    final prefs = await _prefs();
    if (prefs == null) return;
    final used = prefs.getStringList(_usedKey) ?? const [];
    if (!used.contains(id.name)) await prefs.setStringList(_usedKey, [...used, id.name]);
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// Offers a tip for the page [context] is on; [anchor] points the bubble
  /// at a button, without it a card shows at the bottom. Shows only after a
  /// quiet moment, and only if every rule allows it.
  static void offer(BuildContext context, TipId id, {GlobalKey? anchor}) =>
      offerFirst(context, [(id, anchor)]);

  /// Like [offer] for several tips of one page: the first one still due
  /// shows (each with its own anchor, null: a card at the bottom).
  static void offerFirst(BuildContext context, List<(TipId, GlobalKey?)> candidates) {
    if (candidates.isEmpty) return;
    _pending?.cancel();
    _pending = Timer(_quiet, () async {
      if (!context.mounted || !enabled.value || _shown != null) return;
      final prefs = await _prefs();
      if (prefs == null || !context.mounted) return;
      if (prefs.getString(_dayKey) == _today()) return;
      final seen = prefs.getStringList(_seenKey) ?? const [];
      final used = prefs.getStringList(_usedKey) ?? const [];
      final due = candidates.where((c) => !seen.contains(c.$1.name) && !used.contains(c.$1.name)).firstOrNull;
      if (due == null) return;
      final (id, anchor) = due;
      // A quiet moment on this very page: it is in front, no keyboard.
      if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
      if (MediaQuery.viewInsetsOf(context).bottom > 0) return;
      await prefs.setString(_dayKey, _today());
      if (!context.mounted) return;
      _show(context, id, anchor);
    });
  }

  static void _hide() {
    _shown?.remove();
    _shown = null;
  }

  static Future<void> _retire(TipId id) async {
    final prefs = await _prefs();
    if (prefs == null) return;
    final seen = prefs.getStringList(_seenKey) ?? const [];
    if (!seen.contains(id.name)) await prefs.setStringList(_seenKey, [...seen, id.name]);
  }

  static String text(SmileTexts t, TipId id) => switch (id) {
        TipId.frameButton => t.tipFrameButton,
        TipId.slideshow => t.tipSlideshow,
        TipId.captionWhenSending => t.tipCaptionWhenSending,
        TipId.captionLater => t.tipCaptionLater,
        TipId.favoriteHeart => t.tipFavoriteHeart,
        TipId.selectPhotos => t.tipSelectPhotos,
        TipId.quickCapture => t.tipQuickCapture,
        TipId.inviteWays => t.tipInviteWays,
        TipId.smileName => t.tipSmileName,
        TipId.controlLevel => t.tipControlLevel,
        TipId.playback => t.tipPlayback,
        TipId.favoritesRound => t.tipFavoritesRound,
        TipId.newAlbum => t.tipNewAlbum,
        TipId.videoQuality => t.tipVideoQuality,
        TipId.newsIcon => t.tipNewsIcon,
      };

  static void _show(BuildContext context, TipId id, GlobalKey? anchor) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    Rect? target;
    final box = anchor?.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize && box.attached) target = box.localToGlobal(Offset.zero) & box.size;
    final entry = OverlayEntry(
      builder: (_) => _TipLayer(
        id: id,
        target: target,
        onLater: _hide,
        onUnderstood: () {
          _hide();
          unawaited(_retire(id));
        },
        onNoMore: () {
          _hide();
          unawaited(setEnabled(false));
        },
      ),
    );
    _shown = entry;
    overlay.insert(entry);
  }
}

/// The tip on top of the page: a bubble pointing at [target], or a card at
/// the bottom. A tap beside it closes it for today.
class _TipLayer extends StatelessWidget {
  const _TipLayer({
    required this.id,
    required this.target,
    required this.onLater,
    required this.onUnderstood,
    required this.onNoMore,
  });

  final TipId id;
  final Rect? target;
  final VoidCallback onLater;
  final VoidCallback onUnderstood;
  final VoidCallback onNoMore;

  static const _bubble = Color(0xFF2B2322);
  static const _border = Color(0xFF4A3532);

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final scheme = Theme.of(context).colorScheme;
    final card = Material(
      color: _bubble,
      elevation: 10,
      shadowColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(SmileIcons.lightbulb, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Text(t.tipLabel,
                    style: TextStyle(color: scheme.primary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
              ],
            ),
            const SizedBox(height: 8),
            Text(Tips.text(t, id), style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.45)),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton(
                  onPressed: onNoMore,
                  style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant, padding: EdgeInsets.zero),
                  child: Text(t.tipNoMore),
                ),
                const Spacer(),
                FilledButton(onPressed: onUnderstood, child: Text(t.tipUnderstood)),
              ],
            ),
          ],
        ),
      ),
    );

    final target = this.target;
    const width = 300.0;
    Widget placed;
    if (target == null) {
      placed = Positioned(left: 12, right: 12, bottom: padding.bottom + 84, child: card);
    } else {
      // Below the button, kept on screen; the arrow points at its middle.
      final left = (target.center.dx - width + 40).clamp(12.0, size.width - width - 12);
      final arrowX = (target.center.dx - left - 8).clamp(16.0, width - 32);
      final below = target.bottom + 10 < size.height * 0.6;
      final arrow = Padding(
        padding: EdgeInsets.only(left: arrowX),
        child: Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: _bubble, border: Border.all(color: _border)),
          ),
        ),
      );
      placed = Positioned(
        left: left,
        width: width,
        top: below ? target.bottom + 6 : null,
        bottom: below ? null : size.height - target.top + 6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (below) Transform.translate(offset: const Offset(0, 8), child: arrow),
            card,
            if (!below) Transform.translate(offset: const Offset(0, -8), child: arrow),
          ],
        ),
      );
    }
    return Stack(
      children: [
        // A tap beside the tip closes it for today; the page stays visible.
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: onLater)),
        if (target != null)
          Positioned.fromRect(
            rect: target.inflate(4),
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.45), blurRadius: 14, spreadRadius: 2)],
                ),
              ),
            ),
          ),
        placed,
      ],
    );
  }
}
