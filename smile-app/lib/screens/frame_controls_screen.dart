import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/frame_controls.dart';
import '../services/frame_service.dart';
import '../services/local_changes.dart';
import '../services/sync_bus.dart';

/// "Bedienung am Frame" (decided 2026-10-14): which big buttons the person
/// in front of the Frame gets -- a level, or the switches one by one. The
/// app itself always controls the Frame completely.
class FrameControlsScreen extends StatefulWidget {
  const FrameControlsScreen({super.key, required this.frame, this.spaceId, required this.frameService});

  final SmileFrame frame;
  final String? spaceId;
  final FrameService frameService;

  @override
  State<FrameControlsScreen> createState() => _FrameControlsScreenState();
}

class _FrameControlsScreenState extends State<FrameControlsScreen> with SyncReload {
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
  Future<void> _save(Map<String, bool> controls) async {
    final changes = FrameControlLevels.update(controls);
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

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    final controls = _frame.controls;
    final level = _frame.controlLevel ?? FrameControlLevels.levelOf(controls);
    final levels = [
      (1, t.level1, t.level1Hint),
      (2, t.level2, t.level2Hint),
      (3, t.level3, t.level3Hint),
      (4, t.level4, t.level4Hint),
      (5, t.level5, t.level5Hint),
    ];
    final switches = [
      ('next', t.allowNext, SmileIcons.nextItem),
      ('back', t.allowBack, SmileIcons.previous),
      ('pause', t.allowPause, SmileIcons.pause),
      ('newest', t.allowNewest, SmileIcons.newest),
      ('overview', t.allowOverview, SmileIcons.overview),
      ('album', t.allowAlbum, SmileIcons.switchAlbum),
      ('duration', t.allowDuration, SmileIcons.timer),
      ('playback', t.allowPlayback, SmileIcons.playback),
    ];

    Widget card(List<Widget> children) => Container(
          margin: const EdgeInsets.only(bottom: SmileSpacing.m),
          decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(SmileRadius.l)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        );
    Widget label(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(SmileSpacing.m, SmileSpacing.m, SmileSpacing.m, SmileSpacing.xs),
          child: Text(
            text.toUpperCase(),
            style: TextStyle(fontSize: 11.5, letterSpacing: 0.8, color: scheme.onSurfaceVariant),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(t.controlsTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(SmileSpacing.m, SmileSpacing.m, SmileSpacing.m, SmileSpacing.m + MediaQuery.paddingOf(context).bottom),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: SmileSpacing.m),
            child: Text(t.controlsHint, style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          card([
            label(t.controlLevel),
            for (final (value, name, hint) in levels)
              ListTile(
                leading: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: level == value ? scheme.primary : scheme.surfaceContainerHighest,
                  ),
                  child: Text(
                    '$value',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: level == value ? scheme.onPrimary : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                title: Text(name, style: TextStyle(fontWeight: level == value ? FontWeight.w600 : FontWeight.w400)),
                subtitle: Text(hint),
                trailing: level == value ? Icon(SmileIcons.accept, color: scheme.primary) : null,
                onTap: level == value ? null : () => _save(FrameControlLevels.preset(value)),
              ),
            if (level == null)
              ListTile(
                leading: Icon(SmileIcons.controls, color: scheme.primary),
                title: Text(t.levelCustom, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(t.levelCustomHint),
                trailing: Icon(SmileIcons.accept, color: scheme.primary),
              ),
            const SizedBox(height: SmileSpacing.s),
          ]),
          card([
            label(t.allowedOneByOne),
            for (final (key, name, icon) in switches)
              SwitchListTile(
                secondary: Icon(icon),
                title: Text(name),
                value: controls[key] ?? false,
                onChanged: (on) => _save({...controls, key: on}),
              ),
            const SizedBox(height: SmileSpacing.s),
          ]),
        ],
      ),
    );
  }
}
