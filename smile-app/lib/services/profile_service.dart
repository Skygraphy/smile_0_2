import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'avatar_upload.dart';
import '../main.dart';
import 'edge_functions.dart';

class SmileProfile {
  SmileProfile({required this.userId, required this.displayName, this.avatarUrl, this.handle});

  final String userId;
  final String displayName;
  final String? avatarUrl;

  /// The Smile name without "@" (migrations/0080); null until chosen.
  final String? handle;
}

/// A Smile name that is taken (or not allowed) -- only the free check
/// while typing can race with someone else.
class HandleTakenException implements Exception {
  const HandleTakenException();
}

/// The shape a Smile name must have (the same check as migrations/0080).
bool isValidHandle(String handle) {
  const reserved = {
    'smile', 'smileapp', 'admin', 'administrator', 'support', 'help', 'hilfe',
    'team', 'official', 'offiziell', 'info', 'frame', 'smileframe', 'noreply', 'root',
  };
  return RegExp(r'^[a-z0-9][a-z0-9._]{1,22}[a-z0-9_]$').hasMatch(handle) &&
      !handle.contains('..') &&
      !reserved.contains(handle);
}

enum HandleProblem { tooShort, tooLong, badChars, reserved }

/// Why [handle] is not a valid Smile name, so the message can say it
/// exactly (2026-10-20, test suite find 9); null when it is valid.
HandleProblem? handleProblem(String handle) {
  if (isValidHandle(handle)) return null;
  if (handle.length < 3) return HandleProblem.tooShort;
  if (handle.length > 24) return HandleProblem.tooLong;
  if (RegExp(r'^[a-z0-9][a-z0-9._]{1,22}[a-z0-9_]$').hasMatch(handle) && !handle.contains('..')) {
    return HandleProblem.reserved;
  }
  return HandleProblem.badChars;
}

/// Variants of a taken name to offer instead (checked for being free by
/// the caller).
List<String> handleAlternatives(String handle) => [
      '${handle}1',
      handle.contains('.') ? handle.replaceAll('.', '_') : '${handle}_',
      '${handle}2',
      '$handle.smile',
      '${handle}3',
    ].where(isValidHandle).toSet().toList();

/// '@Ernst.Schiener ' -> 'ernst.schiener'.
String normalizeHandle(String raw) => raw.trim().replaceFirst(RegExp('^@'), '').toLowerCase();

/// A first proposal from the display name: "Ernst Schiener" -> ernst.schiener.
String suggestHandle(String displayName) {
  var s = displayName.toLowerCase();
  const umlauts = {'ä': 'ae', 'ö': 'oe', 'ü': 'ue', 'ß': 'ss', 'é': 'e', 'è': 'e', 'á': 'a', 'à': 'a'};
  umlauts.forEach((from, to) => s = s.replaceAll(from, to));
  s = s.replaceAll(RegExp(r'\s+'), '.').replaceAll(RegExp(r'[^a-z0-9._]'), '');
  s = s.replaceAll(RegExp(r'\.{2,}'), '.').replaceAll(RegExp(r'^[._]+|\.+$'), '');
  return s.length > 24 ? s.substring(0, 24).replaceAll(RegExp(r'\.+$'), '') : s;
}

/// One row per user, self-managed (migrations/0029_profiles_and_avatars.sql).
/// display_name is required by that migration's not-null column -- a
/// missing row (not an empty name) is what main.dart's profile gate
/// treats as "onboarding not done yet", per the user's requirement that
/// every user has at least a name and a profile picture (the picture
/// falls back to SmileAvatar's generated initials when avatar_path is
/// null, so only the name is ever actually blocking).
class ProfileService {
  /// Deletes the caller's account and everything of it (delete-account,
  /// decision 2026-10-06). Throws if the server refused.
  Future<void> deleteMyAccount() async {
    final response = await invokeEdge('delete-account', body: const {});
    final data = response.data as Map<String, dynamic>?;
    if (data?['status'] != 'deleted') throw Exception(data?['error'] ?? 'delete_failed');
  }

  Future<SmileProfile?> getMyProfile() async {
    final userId = supabase.auth.currentUser!.id;
    final row =
        await supabase.from('profiles').select('display_name, avatar_path, handle').eq('user_id', userId).maybeSingle();
    if (row == null) return null;
    return SmileProfile(
      userId: userId,
      displayName: row['display_name'] as String,
      avatarUrl: avatarPathToUrl(row['avatar_path'] as String?),
      handle: row['handle'] as String?,
    );
  }

  /// Free for the caller (their own current name counts as free)?
  Future<bool> isHandleAvailable(String handle) async =>
      await supabase.rpc('handle_available', params: {'raw': handle}) == true;

  /// [handle] null removes the Smile name. Throws [HandleTakenException]
  /// when someone else got it first.
  Future<void> setHandle(String? handle) async {
    try {
      await supabase.from('profiles').update({
        'handle': handle,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', _userId());
    } on PostgrestException catch (e) {
      // 23505 unique, 23514 format check.
      if (e.code == '23505' || e.code == '23514') throw const HandleTakenException();
      rethrow;
    }
  }

  /// [withAvatar]: the picture chosen before the profile existed (first
  /// start) is saved along -- its own update had no row to change then
  /// (found by the test suite, 2026-10-20).
  Future<void> setDisplayName(String name, {bool withAvatar = false}) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('profiles').upsert({
      'user_id': userId,
      'display_name': name,
      if (withAvatar && _pendingAvatarPath != null) 'avatar_path': _pendingAvatarPath,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    if (withAvatar) _pendingAvatarPath = null;
  }

  Future<String?> uploadMyAvatarFromCamera() => _setAvatar(pickAndUploadFromCamera(_newAvatarPath()));

  Future<String?> uploadMyAvatarFromGallery() => _setAvatar(pickAndUploadFromGallery(_newAvatarPath()));

  /// A picture already picked (and shown at once, LocalChanges).
  Future<String?> uploadMyAvatarPicked(PickedPicture picture) => _setAvatar(() async {
        final path = _newAvatarPath();
        await uploadPictureBytes(path, picture);
        return path;
      }());

  String _userId() => supabase.auth.currentUser!.id;

  /// Each picture gets its own file (2026-10-20, migrations/0086): under one
  /// fixed address, phones kept showing the old picture they had cached.
  /// The database removes the previous file.
  String _newAvatarPath() => 'users/${_userId()}/${DateTime.now().millisecondsSinceEpoch}';

  /// A picture chosen before the profile exists (first start): saved with
  /// the name. A picture replaced before that is removed at once.
  String? _pendingAvatarPath;

  Future<String?> _setAvatar(Future<String?> upload) async {
    final path = await upload;
    if (path == null) return null;
    final rows = await supabase
        .from('profiles')
        .update({
          'avatar_path': path,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', _userId())
        .select('user_id');
    if (rows.isEmpty) {
      final replaced = _pendingAvatarPath;
      _pendingAvatarPath = path;
      if (replaced != null) {
        try {
          await supabase.storage.from('avatars').remove([replaced]);
        } catch (_) {}
      }
    }
    return avatarPathToUrl(path);
  }
}
