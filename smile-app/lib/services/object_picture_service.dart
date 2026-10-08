import '../main.dart';
import 'avatar_upload.dart';

/// Own pictures for Spaces, albums and Frames (migrations/0066) -- the same
/// three sources as a profile picture (camera, gallery, web address), set by
/// the object's managers. Each upload gets a new file name (so no device
/// keeps a cached old picture); the database removes the previous file.
enum ObjectKind { space, album, frame }

class ObjectPictureService {
  String _folder(ObjectKind kind) => switch (kind) {
        ObjectKind.space => 'spaces',
        ObjectKind.album => 'channels',
        ObjectKind.frame => 'frames',
      };

  String _newPath(ObjectKind kind, String id) => '${_folder(kind)}/$id/${DateTime.now().millisecondsSinceEpoch}';

  Future<String?> fromCamera(ObjectKind kind, String id) => pickAndUploadFromCamera(_newPath(kind, id));

  Future<String?> fromGallery(ObjectKind kind, String id) => pickAndUploadFromGallery(_newPath(kind, id));

  Future<String> fromUrl(ObjectKind kind, String id, String url) => uploadAvatarFromUrl(_newPath(kind, id), url);

  /// Stores [path] as the object's picture (null = remove it).
  Future<void> save(ObjectKind kind, String id, String? path) async {
    switch (kind) {
      case ObjectKind.space:
        await supabase.from('spaces').update({'avatar_path': path}).eq('id', id);
      case ObjectKind.frame:
        await supabase.from('frames').update({'avatar_path': path}).eq('id', id);
      case ObjectKind.album:
        await supabase.from('channels').update({'cover_path': path, 'cover_media_id': null}).eq('id', id);
    }
  }

  /// "Als Titelbild": one of the album's own photos becomes its cover.
  Future<void> setAlbumCoverPhoto(String channelId, String mediaId) async {
    await supabase.from('channels').update({'cover_media_id': mediaId, 'cover_path': null}).eq('id', channelId);
  }

  /// Back to the automatic cover (newest photo).
  Future<void> resetAlbumCover(String channelId) async {
    await supabase.from('channels').update({'cover_media_id': null, 'cover_path': null}).eq('id', channelId);
  }

  String? publicUrl(String? path) => avatarPathToUrl(path);
}
