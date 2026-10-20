import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import 'test_media.dart';

/// Used by [ProfileService] for user avatars: three ways to get an avatar
/// image -- camera, an existing photo, or a URL -- all uploading to the
/// `avatars` bucket at a fixed path, overwriting whatever was there before
/// (there's only ever one current avatar per user, never a history of old
/// ones). Each returns the object path (not yet a URL) on success, or null
/// if the user cancelled a picker.

Future<String?> pickAndUploadFromCamera(String objectPath) => _pickAndUpload(objectPath, ImageSource.camera);

Future<String?> pickAndUploadFromGallery(String objectPath) => _pickAndUpload(objectPath, ImageSource.gallery);

Future<String?> _pickAndUpload(String objectPath, ImageSource source) async {
  final picked = await pickPictureBytes(source);
  if (picked == null) return null;
  await uploadPictureBytes(objectPath, picked);
  return objectPath;
}

/// A picture picked on this phone, not uploaded yet -- shown at once while
/// it uploads (LocalChanges, 2026-10-09).
typedef PickedPicture = ({Uint8List bytes, String mimeType});

Future<PickedPicture?> pickPictureBytes(ImageSource source) async {
  if (smileTestMode) {
    final test = (await pickTestMedia(multiple: false, videos: false, profiles: true)).firstOrNull;
    if (test == null) return null;
    return (bytes: await test.readAsBytes(), mimeType: test.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
  }
  final picked = await ImagePicker().pickImage(
    source: source,
    imageQuality: 85,
    maxWidth: 512,
    maxHeight: 512,
  );
  if (picked == null) return null;
  final extension = picked.path.split('.').last.toLowerCase();
  return (bytes: await picked.readAsBytes(), mimeType: extension == 'png' ? 'image/png' : 'image/jpeg');
}

Future<void> uploadPictureBytes(String objectPath, PickedPicture picture) =>
    _upload(objectPath, picture.bytes, picture.mimeType);

/// Downloads what the URL points to and checks it is a picture -- throws
/// [AvatarUrlException] with a user-facing reason if the address isn't a
/// web address, isn't reachable or isn't a picture. Uploaded like a picked
/// picture afterwards.
Future<PickedPicture> fetchPictureFromUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.isAbsolute || !(uri.isScheme('http') || uri.isScheme('https'))) {
    throw AvatarUrlException('Das ist keine gültige Internetadresse.');
  }
  final http.Response response;
  try {
    response = await http.get(uri).timeout(const Duration(seconds: 20));
  } catch (e) {
    debugPrint('SmileAvatar: $e');
    throw AvatarUrlException('Das Bild konnte nicht geladen werden. Bitte prüfe die Adresse.');
  }
  if (response.statusCode != 200) {
    throw AvatarUrlException('Das Bild konnte nicht geladen werden. Bitte prüfe die Adresse.');
  }
  final contentType = response.headers['content-type'] ?? '';
  if (!contentType.startsWith('image/')) {
    throw AvatarUrlException('Die Adresse zeigt auf kein Bild.');
  }
  return (bytes: response.bodyBytes, mimeType: contentType.split(';').first.trim());
}

Future<void> _upload(String objectPath, Uint8List bytes, String mimeType) async {
  await supabase.storage.from('avatars').uploadBinary(
        objectPath,
        bytes,
        fileOptions: FileOptions(contentType: mimeType, upsert: true),
      );
}

String? avatarPathToUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  return supabase.storage.from('avatars').getPublicUrl(path);
}

class AvatarUrlException implements Exception {
  AvatarUrlException(this.message);

  final String message;

  @override
  String toString() => 'AvatarUrlException($message)';
}
