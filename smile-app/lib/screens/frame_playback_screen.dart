import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/frame_service.dart';
import '../services/local_changes.dart';
import '../services/sync_bus.dart';

/// "Wiedergabe" (decided 2026-10-14): what a Frame plays and how -- always
/// set here in the app, whatever its control level.
class FramePlaybackScreen extends StatefulWidget {
  const FramePlaybackScreen({super.key, required this.frame, this.spaceId, required this.frameService});

  final SmileFrame frame;
  final String? spaceId;
  final FrameService frameService;

  @override
  State<FramePlaybackScreen> createState() => _FramePlaybackScreenState();
}

class _FramePlaybackScreenState extends State<FramePlaybackScreen> with SyncReload {
  late SmileFrame _frame = widget.frame;

  /// Saves under way: a reload meanwhile would undo what is shown.
  int _saving = 0;

  @override
  bool isSyncRelevant(SyncEvent event) => event.tables.contains('frames');

  /// A change on the Frame itself or from another phone (2026-10-14: an
  /// album picked on the Frame switched it to "Ein Album", this page kept
  /// showing "Alle Alben im Wechsel").
  @override
  Future<void> onSync() async {
    if (_saving > 0) return;
    try {
      final fresh = await widget.frameService.getFrame(_frame.id);
      if (mounted && _saving == 0) setState(() => _frame = fresh);
    } catch (_) {}
  }

  /// Shown at once; the Frame follows within seconds.
  Future<void> _save(Map<String, dynamic> changes) async {
    final before = _frame;
    setState(() => _frame = _frame.withSettings(changes));
    _saving++;
    final saved = await LocalChanges.instance.run(
      overrides: const {},
      commit: () => widget.frameService.updateSettings(frameId: _frame.id, changes: changes),
      affects: tablesChanged({'frames'}, spaceIds: {?widget.spaceId}),
    );
    _saving--;
    if (!saved && mounted) setState(() => _frame = before);
  }

  static String _hhmm(String? time) => time == null || time.length < 5 ? '' : time.substring(0, 5);

  Future<void> _pickTime({required bool from}) async {
    final current = from ? _frame.quietFrom : _frame.quietTo;
    final parts = (current ?? (from ? '22:00' : '07:00')).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final value = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await _save({from ? 'quiet_from' : 'quiet_to': value});
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    final f = _frame;
    final quietOn = f.quietFrom != null && f.quietTo != null;

    // A Material, not a coloured Container: ListTiles paint their ink on it
    // (Crashlytics 2026-10-15).
    Widget card(List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: SmileSpacing.m),
          child: Material(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(SmileRadius.l),
            clipBehavior: Clip.antiAlias,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        );
    Widget label(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(SmileSpacing.l, SmileSpacing.m, SmileSpacing.l, SmileSpacing.s),
          child: Text(text.toUpperCase(), style: TextStyle(fontSize: 11.5, letterSpacing: 0.8, color: scheme.onSurfaceVariant)),
        );
    Widget chips<T>(List<(T, String)> options, T selected, String column) => Padding(
          padding: const EdgeInsets.fromLTRB(SmileSpacing.l, 0, SmileSpacing.l, SmileSpacing.m),
          child: Wrap(
            spacing: SmileSpacing.s,
            runSpacing: SmileSpacing.s,
            children: [
              for (final (value, name) in options)
                ChoiceChip(
                  label: Text(name),
                  selected: value == selected,
                  onSelected: value == selected ? null : (_) => _save({column: value}),
                ),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(t.playbackTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(SmileSpacing.m, SmileSpacing.m, SmileSpacing.m, SmileSpacing.m + MediaQuery.paddingOf(context).bottom),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: SmileSpacing.m),
            child: Text(t.playbackHint, style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          card([
            label(t.whatPlays),
            chips(
              [('album', t.contentAlbum), ('rotate', t.contentRotate), ('recent', t.contentRecent), ('favorites', t.contentFavorites)],
              f.contentMode,
              'content_mode',
            ),
            if (f.contentMode == 'recent') ...[
              label(t.recentMeans),
              chips([for (final n in const [10, 20, 50, 100]) (n, t.recentLast(n))], f.recentCount, 'recent_count'),
            ],
          ]),
          card([
            label(t.playOrder),
            chips([('newest', t.orderNewest), ('oldest', t.orderOldest), ('shuffle', t.orderShuffle)], f.playOrder, 'play_order'),
            label(t.displayTime),
            chips(
              [for (final s in const [5, 10, 20, 60]) (s, s == 60 ? t.oneMinute : t.secondsValue(s))],
              f.intervalSeconds,
              'slideshow_interval_seconds',
            ),
            label(t.atEnd),
            chips([('loop', t.endLoop), ('overview', t.endOverview)], f.endBehavior, 'end_behavior'),
            label(t.videoLengthLabel),
            chips([('full', t.videoFull), ('photo', t.videoAsPhoto(f.intervalSeconds))], f.videoLength, 'video_length'),
          ]),
          card([
            label(t.fillLabel),
            chips([('fit', t.fillNever), ('auto', t.fillAuto), ('fill', t.fillAlways)], f.fillMode, 'fill_mode'),
            Padding(
              padding: const EdgeInsets.fromLTRB(SmileSpacing.l, 0, SmileSpacing.l, SmileSpacing.s),
              child: Text(t.fillHint, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
            ),
            SwitchListTile(
              secondary: const Icon(SmileIcons.picture),
              title: Text(t.slowZoom),
              subtitle: Text(t.slowZoomHint),
              value: f.slowZoom,
              onChanged: (v) => _save({'slow_zoom': v}),
            ),
            SwitchListTile(
              secondary: const Icon(SmileIcons.rotate),
              title: Text(t.rotateWithDevice),
              subtitle: Text(t.rotateWithDeviceHint),
              value: f.rotateWithDevice,
              onChanged: (v) => _save({'rotate_with_device': v}),
            ),
          ]),
          card([
            SwitchListTile(
              secondary: const Icon(SmileIcons.newest),
              title: Text(t.showNewNow),
              subtitle: Text(t.showNewNowHint),
              value: f.showNewImmediately,
              onChanged: (v) => _save({'show_new_immediately': v}),
            ),
            SwitchListTile(
              secondary: const Icon(SmileIcons.waiting),
              title: Text(t.bigClock),
              subtitle: Text(t.bigClockHint),
              value: f.showClock,
              onChanged: (v) => _save({'show_clock': v}),
            ),
            SwitchListTile(
              secondary: const Icon(SmileIcons.person),
              title: Text(t.showSenderCaption),
              subtitle: Text(t.showSenderCaptionHint),
              value: f.showSender,
              onChanged: (v) => _save({'show_sender': v}),
            ),
            SwitchListTile(
              secondary: Icon(f.videoSound ? SmileIcons.soundOn : SmileIcons.soundOff),
              title: Text(t.videoSound),
              subtitle: Text(t.videoSoundHint),
              value: f.videoSound,
              onChanged: (v) => _save({'video_sound': v}),
            ),
          ]),
          card([
            SwitchListTile(
              secondary: const Icon(SmileIcons.night),
              title: Text(t.quietTime),
              subtitle: Text(quietOn ? t.quietRange(_hhmm(f.quietFrom), _hhmm(f.quietTo)) : t.quietTimeHint),
              value: quietOn,
              onChanged: (on) => _save(on ? {'quiet_from': '22:00', 'quiet_to': '07:00'} : {'quiet_from': null, 'quiet_to': null}),
            ),
            if (quietOn) ...[
              ListTile(
                contentPadding: const EdgeInsets.only(left: 72, right: SmileSpacing.l),
                title: Text(t.quietFromLabel),
                trailing: Text(_hhmm(f.quietFrom), style: TextStyle(color: scheme.primary, fontSize: 16)),
                onTap: () => _pickTime(from: true),
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 72, right: SmileSpacing.l),
                title: Text(t.quietToLabel),
                trailing: Text(_hhmm(f.quietTo), style: TextStyle(color: scheme.primary, fontSize: 16)),
                onTap: () => _pickTime(from: false),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}
