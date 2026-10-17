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
    setState(() => _failure = null);
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
    });
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
    final (String? status, Color statusColor) = switch (_check) {
      _Check.free when _handle != widget.current => (t.smileNameFree, scheme.primary),
      _Check.taken => (t.smileNameTaken, scheme.error),
      _Check.invalid => (t.smileNameInvalid, scheme.error),
      _ => (null, muted),
    };
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(SmileRadius.m), borderSide: BorderSide.none),
              suffixIcon: _check == _Check.checking
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: SmileSpacing.s),
          SizedBox(
            height: 20,
            child: status == null ? null : Text(status, style: TextStyle(color: statusColor, fontSize: 13)),
          ),
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
