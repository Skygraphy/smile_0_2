import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_design_system/smile_design_system.dart';

import 'tip_cards.dart';

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
/// still unused, at most three a day at least 30 minutes apart (Ernst
/// 2026-10-29; before: one a day), in a quiet moment (a few seconds on a
/// page, no keyboard), each only once. Besides these bubbles: about 200
/// "Wusstest du?" cards, at random, fitting the page (tip_cards.dart). "Verstanden" retires it, "Keine
/// Tipps mehr" switches all off (Einstellungen can switch them on again).
/// Kept on this phone.
class Tips {
  Tips._();

  static const _enabledKey = 'tips_enabled';
  static const _seenKey = 'tips_seen';
  static const _usedKey = 'tips_used';
  static const _dayKey = 'tips_last_day';
  static const _shownAtKey = 'tips_shown_at';
  static const _cardsSeenKey = 'tip_cards_seen';
  static const _perDay = 3;
  static const _apart = Duration(minutes: 30);
  static const _quiet = Duration(seconds: 5);

  /// For the switch in Einstellungen.
  static final enabled = ValueNotifier<bool>(true);

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
    await prefs?.remove(_shownAtKey);
    await prefs?.remove(_cardsSeenKey);
    await setEnabled(true);
  }

  /// The feature was used: its tip never needs to show.
  static Future<void> markUsed(TipId id) async {
    final prefs = await _prefs();
    if (prefs == null) return;
    final used = prefs.getStringList(_usedKey) ?? const [];
    if (!used.contains(id.name)) await prefs.setStringList(_usedKey, [...used, id.name]);
  }

  /// At most [_perDay] a day, [_apart] between two -- bubbles and cards
  /// together.
  static bool _mayShowNow(SharedPreferences prefs) {
    final now = DateTime.now();
    final shown = (prefs.getStringList(_shownAtKey) ?? const [])
        .map((s) => DateTime.fromMillisecondsSinceEpoch(int.tryParse(s) ?? 0))
        .toList();
    final today = shown.where((d) => d.year == now.year && d.month == now.month && d.day == now.day).length;
    final last = shown.isEmpty ? null : shown.reduce((a, b) => a.isAfter(b) ? a : b);
    return today < _perDay && (last == null || now.difference(last) >= _apart);
  }

  static Future<void> _noteShown(SharedPreferences prefs) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch;
    final kept = (prefs.getStringList(_shownAtKey) ?? const []).where((s) => (int.tryParse(s) ?? 0) > cutoff);
    await prefs.setStringList(_shownAtKey, [...kept, '${DateTime.now().millisecondsSinceEpoch}']);
  }

  /// A "Wusstest du?" card for this page (or a general one), at random,
  /// each only once -- same rules and same waiting as the bubbles.
  static void offerCard(BuildContext context, TipPage page) {
    // Not in widget tests: no timer left waiting there.
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    Future<void> check() async {
      if (!context.mounted) return;
      if (!enabled.value) {
        Timer(_quiet, check);
        return;
      }
      final prefs = await _prefs();
      if (prefs == null || !context.mounted) return;
      final seen = (prefs.getStringList(_cardsSeenKey) ?? const []).toSet();
      final due = [
        for (final p in {page, TipPage.general})
          for (final (i, _) in (tipCards[p] ?? const <String>[]).indexed)
            if (!seen.contains('${p.name}/$i')) (p, i),
      ];
      if (due.isEmpty) return;
      final quiet = (ModalRoute.of(context)?.isCurrent ?? false) && MediaQuery.viewInsetsOf(context).bottom == 0;
      if (!quiet || _shown != null || !_mayShowNow(prefs)) {
        Timer(_quiet, check);
        return;
      }
      final (p, i) = due[Random().nextInt(due.length)];
      await _noteShown(prefs);
      if (!context.mounted) return;
      _showText(context, (_) => tipCards[p]![i], label: (t) => t.tipDidYouKnow, onUnderstood: () async {
        final prefs = await _prefs();
        final seen = prefs?.getStringList(_cardsSeenKey) ?? const [];
        await prefs?.setStringList(_cardsSeenKey, [...seen, '${p.name}/$i']);
      });
      Timer(_quiet, check);
    }

    Timer(_quiet, check);
  }

  /// Offers a tip for the page [context] is on; [anchor] points the bubble
  /// at a button, without it a card shows at the bottom. Shows only after a
  /// quiet moment, and only if every rule allows it.
  static void offer(BuildContext context, TipId id, {GlobalKey? anchor}) =>
      offerFirst(context, [(id, anchor)]);

  /// Like [offer] for several tips of one page: the first one still due
  /// shows (each with its own anchor, null: a card at the bottom).
  /// Each page waits on its own: while it is behind another page (or the
  /// keyboard is open) the tip keeps waiting until it is in front and quiet
  /// again, as long as the page exists.
  static void offerFirst(BuildContext context, List<(TipId, GlobalKey?)> candidates) {
    if (candidates.isEmpty) return;
    Future<void> check() async {
      if (!context.mounted) return;
      // Switched off: keep waiting, they may be switched on again while the
      // page is open (Fund 45, 2026-10-27).
      if (!enabled.value) {
        Timer(_quiet, check);
        return;
      }
      final prefs = await _prefs();
      if (prefs == null || !context.mounted) return;
      final seen = prefs.getStringList(_seenKey) ?? const [];
      final used = prefs.getStringList(_usedKey) ?? const [];
      final due = candidates.where((c) => !seen.contains(c.$1.name) && !used.contains(c.$1.name)).firstOrNull;
      if (due == null) return;
      // Not now (another page in front, keyboard, a tip already open, or
      // today's tip already given): look again in a moment.
      final quiet = (ModalRoute.of(context)?.isCurrent ?? false) && MediaQuery.viewInsetsOf(context).bottom == 0;
      if (!quiet || _shown != null || !_mayShowNow(prefs)) {
        Timer(_quiet, check);
        return;
      }
      final (id, anchor) = due;
      await _noteShown(prefs);
      if (!context.mounted) return;
      _show(context, id, anchor);
      // The page's next tip on another day, even if the page stays open
      // that long (the start page does; Fund 45).
      Timer(_quiet, check);
    }

    Timer(_quiet, check);
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

  static void _show(BuildContext context, TipId id, GlobalKey? anchor) =>
      _showText(context, (t) => text(t, id), anchor: anchor, onUnderstood: () => _retire(id));

  static void _showText(
    BuildContext context,
    String Function(SmileTexts t) text, {
    GlobalKey? anchor,
    String Function(SmileTexts t)? label,
    required Future<void> Function() onUnderstood,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    Rect? target;
    final box = anchor?.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize && box.attached) target = box.localToGlobal(Offset.zero) & box.size;
    final entry = OverlayEntry(
      builder: (_) => _TipLayer(
        text: text,
        label: label,
        target: target,
        onLater: _hide,
        onUnderstood: () {
          _hide();
          unawaited(onUnderstood());
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
    required this.text,
    this.label,
    required this.target,
    required this.onLater,
    required this.onUnderstood,
    required this.onNoMore,
  });

  final String Function(SmileTexts t) text;
  final String Function(SmileTexts t)? label;
  final Rect? target;
  final VoidCallback onLater;
  final VoidCallback onUnderstood;
  final VoidCallback onNoMore;

  // Neutral grey, not the old brownish tint (Ernst 2026-10-27: no brown).
  static const _bubble = Color(0xFF262626);
  static const _border = Color(0xFF3A3A3A);

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
                Text(label?.call(t) ?? t.tipLabel,
                    style: TextStyle(color: scheme.primary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
              ],
            ),
            const SizedBox(height: 8),
            Text(text(t), style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.45)),
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
        // The button it points at is left out: a tap there reaches the
        // button itself and closes the tip too (Fund 46, 2026-10-27).
        Positioned.fill(
          child: _Hole(
            hole: target?.inflate(4),
            child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: onLater),
          ),
        ),
        if (target != null)
          Positioned.fromRect(
            rect: target.inflate(4),
            child: Listener(behavior: HitTestBehavior.translucent, onPointerUp: (_) => onLater()),
          ),
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

/// Lets taps inside [hole] through to what lies below.
class _Hole extends SingleChildRenderObjectWidget {
  const _Hole({required this.hole, super.child});

  final Rect? hole;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHole(hole);

  @override
  void updateRenderObject(BuildContext context, _RenderHole renderObject) => renderObject.hole = hole;
}

class _RenderHole extends RenderProxyBox {
  _RenderHole(this.hole);

  Rect? hole;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final h = hole;
    if (h != null && h.contains(localToGlobal(position))) return false;
    return super.hitTest(result, position: position);
  }
}
