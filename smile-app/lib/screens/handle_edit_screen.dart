import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/profile_service.dart';

/// "Smile-Namen wählen" (2026-10-17): a unique @name, checked while typing.
/// Pops with the saved name, or '' when it was removed.
class HandleEditScreen extends StatefulWidget {
  HandleEditScreen({super.key, this.current, this.displayName = '', ProfileService? profileService})
      : profileService = profileService ?? ProfileService();

  final String? current;
  /// For the first proposal when there is no name yet.
  final String displayName;
  final ProfileService profileService;

  @override
  State<HandleEditScreen> createState() => _HandleEditScreenState();
}

enum _Check { none, checking, free, taken, invalid }

class _HandleEditScreenState extends State<HandleEditScreen> {
  late final TextEditingController _controller;
  Timer? _debounce;
  _Check _check = _Check.none;
  bool _saving = false;
  String? _failure;
  /// Free alternatives to a taken name (up to three).
  List<String> _alternatives = const [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.current ?? suggestHandle(widget.displayName));
    _onChanged(_controller.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String get _handle => normalizeHandle(_controller.text);

  void _onChanged(String _) {
    _debounce?.cancel();
    final handle = _handle;
    setState(() {
      _failure = null;
      _alternatives = const [];
    });
    if (handle.isEmpty) {
      setState(() => _check = _Check.none);
      return;
    }
    if (!isValidHandle(handle)) {
      setState(() => _check = _Check.invalid);
      return;
    }
    if (handle == widget.current) {
      setState(() => _check = _Check.free);
      return;
    }
    setState(() => _check = _Check.checking);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      bool free;
      try {
        free = await widget.profileService.isHandleAvailable(handle);
      } catch (_) {
        // Unknown (e.g. offline): saving will tell.
        if (mounted && _handle == handle) setState(() => _check = _Check.none);
        return;
      }
      if (mounted && _handle == handle) setState(() => _check = free ? _Check.free : _Check.taken);
      if (!free) unawaited(_findAlternatives(handle));
    });
  }

  Future<void> _findAlternatives(String handle) async {
    final found = <String>[];
    for (final candidate in handleAlternatives(handle)) {
      if (found.length == 3 || !mounted || _handle != handle) break;
      try {
        if (await widget.profileService.isHandleAvailable(candidate)) found.add(candidate);
      } catch (_) {
        return;
      }
    }
    if (mounted && _handle == handle) setState(() => _alternatives = found);
  }

  void _take(String alternative) {
    _controller.text = alternative;
    _controller.selection = TextSelection.collapsed(offset: alternative.length);
    _onChanged(alternative);
  }

  Future<void> _save(String? handle) async {
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await widget.profileService.setHandle(handle);
      if (mounted) Navigator.of(context).pop(handle ?? '');
    } on HandleTakenException {
      if (mounted) setState(() => _check = _Check.taken);
    } catch (_) {
      if (mounted) setState(() => _failure = SmileTexts.of(context).smileNameSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final canSave = !_saving && _check == _Check.free && _handle != widget.current;
    // Free in green, taken or against the rules in red, each saying
    // exactly what is the matter (2026-10-20, test suite find 9).
    final handle = _handle;
    final good = _check == _Check.free && handle != widget.current;
    final bad = _check == _Check.taken || _check == _Check.invalid;
    final Color? stateColor = good ? SmileTheme.success : (bad ? scheme.error : null);
    final String? status = switch (_check) {
      _Check.free when handle != widget.current => t.smileNameIsFree(handle),
      _Check.taken => t.smileNameIsTaken(handle),
      _Check.invalid => switch (handleProblem(handle)) {
          HandleProblem.tooShort => t.smileNameTooShort,
          HandleProblem.tooLong => t.smileNameTooLong,
          HandleProblem.reserved => t.smileNameReserved,
          _ => t.smileNameBadChars,
        },
      _ => null,
    };
    OutlineInputBorder border(Color? color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(SmileRadius.m),
          borderSide: color == null ? BorderSide.none : BorderSide(color: color, width: 2),
        );
    return Scaffold(
      appBar: AppBar(title: Text(t.smileName)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            SmileSpacing.l, SmileSpacing.l, SmileSpacing.l, SmileSpacing.l + MediaQuery.paddingOf(context).bottom),
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._@]')),
              LengthLimitingTextInputFormatter(25),
              TextInputFormatter.withFunction(
                  (old, value) => value.copyWith(text: value.text.toLowerCase(), composing: TextRange.empty)),
            ],
            onChanged: _onChanged,
            onSubmitted: (_) => canSave ? _save(_handle) : null,
            style: Theme.of(context).textTheme.titleMedium,
            decoration: InputDecoration(
              prefixText: '@',
              filled: true,
              border: border(stateColor),
              enabledBorder: border(stateColor),
              focusedBorder: border(stateColor),
              suffixIcon: _check == _Check.checking
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : stateColor == null
                      ? null
                      : Icon(good ? SmileIcons.check : SmileIcons.warning, color: stateColor),
            ),
          ),
          const SizedBox(height: SmileSpacing.s),
          if (status != null && stateColor != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: SmileSpacing.m, vertical: SmileSpacing.s),
              decoration: BoxDecoration(
                color: stateColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(SmileRadius.m),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(good ? SmileIcons.check : SmileIcons.warning, size: 18, color: stateColor),
                  ),
                  const SizedBox(width: SmileSpacing.s),
                  Expanded(
                    child: Text(status,
                        style: TextStyle(color: stateColor, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.35)),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 20),
          if (_check == _Check.taken && _alternatives.isNotEmpty) ...[
            const SizedBox(height: SmileSpacing.s),
            Text(t.smileNameSuggestions, style: TextStyle(color: muted, fontSize: 13)),
            const SizedBox(height: SmileSpacing.xs),
            Wrap(
              spacing: SmileSpacing.s,
              runSpacing: SmileSpacing.xs,
              children: [for (final a in _alternatives) ActionChip(label: Text(a), onPressed: () => _take(a))],
            ),
          ],
          const SizedBox(height: SmileSpacing.s),
          Text(t.smileNameRules, style: TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: SmileSpacing.m),
          Text(t.smileNameHint, style: TextStyle(color: muted, fontSize: 13, height: 1.45)),
          if (_failure != null) ...[
            const SizedBox(height: SmileSpacing.m),
            Text(_failure!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: SmileSpacing.xl),
          FilledButton(onPressed: canSave ? () => _save(_handle) : null, child: Text(t.save)),
          if (widget.current != null) ...[
            const SizedBox(height: SmileSpacing.s),
            TextButton(
              onPressed: _saving ? null : () => _save(null),
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              child: Text(t.smileNameRemove),
            ),
          ],
        ],
      ),
    );
  }
}
