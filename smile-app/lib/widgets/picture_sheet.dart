import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/avatar_upload.dart';
import '../services/media_service.dart';
import '../services/object_picture_service.dart';
import 'avatar_picker.dart';

enum _PictureChoice { albumPhoto, camera, gallery, url, remove }

/// The camera badge's sheet for a Space, album or Frame (preview "Eigene
/// Bilder", 2026-10-08). Returns true when the picture changed. Errors are
/// shown as a SnackBar.
Future<bool> changeObjectPicture(
  BuildContext context, {
  required ObjectKind kind,
  required String id,
  required String name,
  required bool hasCustomPicture,
  ObjectPictureService? service,
}) async {
  final t = SmileTexts.of(context);
  final pictures = service ?? ObjectPictureService();
  final messenger = ScaffoldMessenger.of(context);
  final isAlbum = kind == ObjectKind.album;

  final choice = await showModalBottomSheet<_PictureChoice>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              isAlbum ? t.coverFor(name) : t.pictureFor(name),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          if (isAlbum)
            ListTile(
              leading: const Icon(SmileIcons.album),
              title: Text(t.pickFromAlbum),
              onTap: () => Navigator.of(context).pop(_PictureChoice.albumPhoto),
            ),
          ListTile(
            leading: const Icon(SmileIcons.camera),
            title: Text(t.takePhoto),
            onTap: () => Navigator.of(context).pop(_PictureChoice.camera),
          ),
          ListTile(
            leading: const Icon(SmileIcons.picture),
            title: Text(t.choosePicture),
            onTap: () => Navigator.of(context).pop(_PictureChoice.gallery),
          ),
          ListTile(
            leading: const Icon(SmileIcons.web),
            title: Text(t.pictureFromWeb),
            onTap: () => Navigator.of(context).pop(_PictureChoice.url),
          ),
          if (hasCustomPicture)
            ListTile(
              leading: Icon(isAlbum ? SmileIcons.restore : SmileIcons.delete, color: Theme.of(context).colorScheme.primary),
              title: Text(
                isAlbum ? t.automaticCover : t.removePicture,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              onTap: () => Navigator.of(context).pop(_PictureChoice.remove),
            ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return false;

  try {
    switch (choice) {
      case _PictureChoice.albumPhoto:
        final mediaId = await Navigator.of(context).push<String>(
          MaterialPageRoute(builder: (_) => _AlbumPhotoPicker(channelId: id, albumName: name)),
        );
        if (mediaId == null) return false;
        await pictures.setAlbumCoverPhoto(id, mediaId);
      case _PictureChoice.camera:
        final path = await pictures.fromCamera(kind, id);
        if (path == null) return false;
        await pictures.save(kind, id, path);
      case _PictureChoice.gallery:
        final path = await pictures.fromGallery(kind, id);
        if (path == null) return false;
        await pictures.save(kind, id, path);
      case _PictureChoice.url:
        final url = await showAvatarUrlDialog(context);
        if (url == null || url.trim().isEmpty) return false;
        await pictures.save(kind, id, await pictures.fromUrl(kind, id, url.trim()));
      case _PictureChoice.remove:
        if (isAlbum) {
          await pictures.resetAlbumCover(id);
        } else {
          await pictures.save(kind, id, null);
        }
    }
    return true;
  } on AvatarUrlException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(t.actionFailed('$e'))));
  }
  return false;
}

/// Grid of the album's photos to pick a cover from.
class _AlbumPhotoPicker extends StatefulWidget {
  const _AlbumPhotoPicker({required this.channelId, required this.albumName});

  final String channelId;
  final String albumName;

  @override
  State<_AlbumPhotoPicker> createState() => _AlbumPhotoPickerState();
}

class _AlbumPhotoPickerState extends State<_AlbumPhotoPicker> {
  List<MediaItem>? _items;

  @override
  void initState() {
    super.initState();
    MediaService().fetchReadyMedia(widget.channelId).then((items) {
      if (mounted) setState(() => _items = items.where((i) => i.processingStatus == 'ready' && i.thumbnailUrl != null).toList());
    }).catchError((_) {
      if (mounted) setState(() => _items = const []);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(SmileIcons.close), onPressed: () => Navigator.of(context).pop()),
        title: Text(t.choosePhoto),
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? SmileEmptyState(icon: SmileIcons.album, title: t.noPhotosInAlbum)
              : GridView.count(
                  crossAxisCount: 3,
                  padding: const EdgeInsets.all(6),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  children: [
                    for (final item in items)
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(item.id),
                        child: SmileAlbumCover(
                          name: widget.albumName,
                          imageUrl: item.thumbnailUrl,
                          cacheKey: '${item.id}_grid',
                          size: 200,
                        ),
                      ),
                  ],
                ),
    );
  }
}
