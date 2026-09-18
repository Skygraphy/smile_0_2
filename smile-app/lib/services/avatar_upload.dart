import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

/// Used by [ProfileService] for user avatars: three ways to get an avatar
/// image -- camera, an existing photo, or a URL -- all uploading to the
/// `avatars` bucket at a fixed path, overwriting whatever was there before
/// (there's only ever one current avatar per user, never a history of old
/// ones). Each returns the object path (not yet a URL) on success, or null
/// if the user cancelled a picker.

Future<String?> pickAndUploadFromCamera(String objectPath) => _pickAndUpload(objectPath, ImageSource.camera);

Future<String?> pickAndUploadFromGallery(String objectPath) => _pickAndUpload(objectPath, ImageSource.gallery);

Future<String?> _pickAndUpload(String objectPath, ImageSource source) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    imageQuality: 85,
    maxWidth: 512,
    maxHeight: 512,
  );
  if (picked == null) return null;
  final bytes = await picked.readAsBytes();
  final extension = picked.path.split('.').last.toLowerCase();
  final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
  await _upload(objectPath, bytes, mimeType);
  return objectPath;
}

/// Downloads whatever the URL points to and uploads it as-is -- throws
/// [AvatarUrlException] with a user-facing reason instead of a raw
/// exception if the URL isn't reachable or isn't actually an image, so
/// the caller can show it directly.
Future<String> uploadAvatarFromUrl(String objectPath, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.isAbsolute || !(uri.isScheme('http') || uri.isScheme('https'))) {
    throw AvatarUrlException('Das ist keine gültige Internetadresse.');
  }
  final http.Response response;
  try {
    response = await http.get(uri).timeout(const Duration(seconds: 20));
  } catch (e) {
    throw AvatarUrlException('Bild konnte nicht geladen werden: $e');
  }
  if (response.statusCode != 200) {
    throw AvatarUrlException('Bild konnte nicht geladen werden (Status ${response.statusCode}).');
  }
  final contentType = response.headers['content-type'] ?? '';
  if (!contentType.startsWith('image/')) {
    throw AvatarUrlException('Die Adresse zeigt auf kein Bild.');
  }
  await _upload(objectPath, response.bodyBytes, contentType);
  return objectPath;
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
