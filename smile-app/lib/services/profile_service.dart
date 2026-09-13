import 'avatar_upload.dart';
import '../main.dart';

class SmileProfile {
  SmileProfile({required this.userId, required this.displayName, this.avatarUrl});

  final String userId;
  final String displayName;
  final String? avatarUrl;
}

/// One row per user, self-managed (migrations/0029_profiles_and_avatars.sql).
/// display_name is required by that migration's not-null column -- a
/// missing row (not an empty name) is what main.dart's profile gate
/// treats as "onboarding not done yet", per the user's requirement that
/// every user has at least a name and a profile picture (the picture
/// falls back to SmileAvatar's generated initials when avatar_path is
/// null, so only the name is ever actually blocking).
class ProfileService {
  Future<SmileProfile?> getMyProfile() async {
    final userId = supabase.auth.currentUser!.id;
    final row = await supabase.from('profiles').select('display_name, avatar_path').eq('user_id', userId).maybeSingle();
    if (row == null) return null;
    return SmileProfile(
      userId: userId,
      displayName: row['display_name'] as String,
      avatarUrl: avatarPathToUrl(row['avatar_path'] as String?),
    );
  }

  Future<void> setDisplayName(String name) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('profiles').upsert({
      'user_id': userId,
      'display_name': name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<String?> uploadMyAvatarFromCamera() => _setAvatar(pickAndUploadFromCamera('users/${_userId()}'));

  Future<String?> uploadMyAvatarFromGallery() => _setAvatar(pickAndUploadFromGallery('users/${_userId()}'));

  Future<String?> uploadMyAvatarFromUrl(String url) => _setAvatar(uploadAvatarFromUrl('users/${_userId()}', url));

  String _userId() => supabase.auth.currentUser!.id;

  Future<String?> _setAvatar(Future<String?> upload) async {
    final path = await upload;
    if (path == null) return null;
    await supabase.from('profiles').update({
      'avatar_path': path,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', _userId());
    return avatarPathToUrl(path);
  }
}
