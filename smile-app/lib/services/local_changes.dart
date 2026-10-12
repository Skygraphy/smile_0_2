import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';
import '../widgets/friendly_error.dart';

import '../main.dart';
import 'avatar_upload.dart';
import 'offline.dart';
import 'sync_bus.dart';

/// A picture shown before the server has it (decided 2026-10-09): the
/// bytes just picked on this phone, a web address, an album photo's
/// thumbnail -- or [removed] (initials again).
class LocalPicture {
  const LocalPicture.bytes(Uint8List this.bytes)
      : url = null,
        cacheKey = null,
        removed = false;
  const LocalPicture.url(String this.url, {this.cacheKey})
      : bytes = null,
        removed = false;
  const LocalPicture.removed()
      : bytes = null,
        url = null,
        cacheKey = null,
        removed = true;

  final Uint8List? bytes;
  final String? url;
  final String? cacheKey;
  final bool removed;

  ImageProvider? get image {
    if (bytes != null) return MemoryImage(bytes!);
    if (url != null) return CachedNetworkImageProvider(url!, cacheKey: cacheKey);
    return null;
  }
}

/// Own changes show at once, everywhere (decided 2026-10-09, "sofort
/// umsetzen, dann mit dem Server abgleichen"): an action first records
/// what it changes here -- every screen draws these values over its own
/// server data -- then saves to the server. Success: all open screens
/// reload right away (no waiting for the sync push) and the values here
/// stay until that reload has surely landed. Failure: they are dropped
/// again and a message says why.
class LocalChanges extends ChangeNotifier {
  LocalChanges._();

  static final instance = LocalChanges._();

  final Map<String, Object> _values = {};
  final Map<String, Timer> _expiry = {};

  // --- Keys -------------------------------------------------------------
  static String albumName(String id) => 'album.name:$id';
  static String albumCover(String id) => 'album.cover:$id';
  static String spaceName(String id) => 'space.name:$id';
  static String spacePicture(String id) => 'space.picture:$id';
  static String frameName(String id) => 'frame.name:$id';
  static String framePicture(String id) => 'frame.picture:$id';
  static String frameAlbum(String id) => 'frame.album:$id';
  static String frameAlbumRemoved(String frameId, String channelId) => 'frame.removed:$frameId:$channelId';
  static String mediaGone(String id) => 'media.gone:$id';
  static const profileName = 'profile.name';
  static const profileAvatar = 'profile.avatar';

  T? value<T>(String key) {
    final v = _values[key];
    return v is T ? v : null;
  }

  String? text(String key) => value<String>(key);
  LocalPicture? picture(String key) => value<LocalPicture>(key);
  bool flag(String key) => value<bool>(key) ?? false;

  /// Shows [overrides] at once, then runs [commit] (the server call).
  /// [warmUp] runs after a successful commit and before the overrides go --
  /// e.g. downloading the new picture, so the switch to the server's copy
  /// has nothing to wait for. Returns whether the change was saved.
  Future<bool> run({
    required Map<String, Object> overrides,
    required Future<void> Function() commit,
    required SyncEvent affects,
    Future<void> Function()? warmUp,
    String? failureText,
  }) async {
    for (final entry in overrides.entries) {
      _expiry.remove(entry.key)?.cancel();
      _values[entry.key] = entry.value;
    }
    notifyListeners();
    try {
      await commit();
    } catch (e) {
      if (Offline.isConnectionError(e)) {
        // No connection: it stays done here and goes to the server as soon
        // as there is one again -- no message, like WhatsApp (2026-10-12:
        // "Für mich löschen" offline said "Ausblenden fehlgeschlagen").
        unawaited(_retryWhenOnline(overrides, commit, affects, failureText));
        return false;
      }
      _undo(overrides);
      _showFailure(failureText, e);
      return false;
    }
    await _settle(overrides, affects, warmUp);
    return true;
  }

  void _undo(Map<String, Object> overrides) {
    for (final key in overrides.keys) {
      if (identical(_values[key], overrides[key])) _values.remove(key);
    }
    notifyListeners();
  }

  /// Tries again whenever the network comes back (and every so often),
  /// while the app runs; a real refusal by the server takes it back.
  Future<void> _retryWhenOnline(
    Map<String, Object> overrides,
    Future<void> Function() commit,
    SyncEvent affects,
    String? failureText,
  ) async {
    for (var attempt = 0; attempt < 200; attempt++) {
      await _networkOrTimeout(Duration(seconds: attempt < 10 ? 10 : 60));
      // Something newer replaced it here meanwhile: that one counts.
      if (!overrides.entries.every((e) => identical(_values[e.key], e.value))) return;
      if (!await Offline.hasNetwork()) continue;
      try {
        await commit();
      } catch (e) {
        if (Offline.isConnectionError(e)) continue;
        _undo(overrides);
        _showFailure(failureText, e);
        return;
      }
      await _settle(overrides, affects, null);
      return;
    }
  }

  static Future<void> _networkOrTimeout(Duration max) async {
    final back = Completer<void>();
    StreamSubscription<List<ConnectivityResult>>? sub;
    try {
      sub = Connectivity().onConnectivityChanged.listen((r) {
        if (!r.contains(ConnectivityResult.none) && !back.isCompleted) back.complete();
      });
    } catch (_) {}
    await back.future.timeout(max, onTimeout: () {});
    await sub?.cancel();
  }

  Future<void> _settle(Map<String, Object> overrides, SyncEvent affects, Future<void> Function()? warmUp) async {
    if (warmUp != null) {
      try {
        await warmUp().timeout(const Duration(seconds: 15));
      } catch (_) {
        // Only a nicer handover -- the change itself is saved.
      }
    }
    SyncBus.emit(affects);
    // Long enough for every open screen's reload (debounced 400 ms, then
    // one server round-trip) to have the server's own copy.
    for (final entry in overrides.entries) {
      _expiry[entry.key] = Timer(const Duration(seconds: 8), () {
        _expiry.remove(entry.key);
        if (identical(_values[entry.key], entry.value)) {
          _values.remove(entry.key);
          notifyListeners();
        }
      });
    }
  }

  /// Takes back some overrides of a saved change at once -- the part the
  /// server refused (e.g. photos someone else sent).
  void drop(Iterable<String> keys) {
    for (final key in keys) {
      _expiry.remove(key)?.cancel();
      _values.remove(key);
    }
    notifyListeners();
  }

  /// Without anything to show beforehand (e.g. creating, inviting): every
  /// open screen reloads right after the server said yes, instead of
  /// waiting for the sync push.
  static void saved(SyncEvent affects) => SyncBus.emit(affects);

  void _showFailure(String? text, Object error) {
    final messenger = scaffoldMessengerKey.currentState;
    final context = scaffoldMessengerKey.currentContext;
    if (messenger == null) return;
    // A reason meant for people (e.g. "Die Adresse zeigt auf kein Bild.")
    // is shown as it is.
    final reason = error is AvatarUrlException
        ? error.message
        : context != null
            ? errorReasonIn(SmileTexts.of(context), error)
            : 'Bitte versuche es noch einmal.';
    final message = text ??
        (error is AvatarUrlException
            ? reason
            : context != null
                ? SmileTexts.of(context).changeNotSaved(reason)
                : 'Die Änderung wurde nicht gespeichert. $reason');
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Precaches a network picture (the server's copy of a just-changed one).
Future<void> precacheUrl(String? url, {String? cacheKey}) async {
  if (url == null) return;
  final context = navigatorKey.currentContext;
  if (context == null) return;
  await precacheImage(CachedNetworkImageProvider(url, cacheKey: cacheKey), context);
}

SyncEvent tablesChanged(Set<String> tables, {Set<String> channelIds = const {}, Set<String> spaceIds = const {}}) =>
    SyncEvent(tables: tables, channelIds: channelIds, spaceIds: spaceIds);
