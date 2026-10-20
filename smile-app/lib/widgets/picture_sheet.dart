import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/avatar_upload.dart';
import '../services/media_service.dart';
import '../services/local_changes.dart';
import '../services/object_picture_service.dart';
import 'album_covers.dart';
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

  // The new picture shows at once, everywhere, while it uploads; if saving
  // fails it goes away again with a message (LocalChanges, 2026-10-09).
  final local = LocalChanges.instance;
  final key = switch (kind) {
    ObjectKind.space => LocalChanges.spacePicture(id),
    ObjectKind.frame => LocalChanges.framePicture(id),
    ObjectKind.album => LocalChanges.albumCover(id),
  };
  final affects = switch (kind) {
    ObjectKind.space => tablesChanged({'spaces'}, spaceIds: {id}),
    ObjectKind.frame => tablesChanged({'frames'}),
    ObjectKind.album => tablesChanged({'channels'}, channelIds: {id}),
  };
  String? savedPath;
  Future<void> warmUp() => precacheUrl(avatarPathToUrl(savedPath));

  switch (choice) {
    case _PictureChoice.albumPhoto:
      final item = await Navigator.of(context).push<MediaItem>(
        MaterialPageRoute(builder: (_) => _AlbumPhotoPicker(channelId: id, albumName: name)),
      );
      if (item == null || item.thumbnailUrl == null) return false;
      return local.run(
        overrides: {key: LocalPicture.url(item.thumbnailUrl!, cacheKey: albumPhotoCacheKey(item.id))},
        commit: () => pictures.setAlbumCoverPhoto(id, item.id),
        affects: affects,
      );
    case _PictureChoice.camera:
    case _PictureChoice.gallery:
      final picked = await pickPictureBytes(choice == _PictureChoice.camera ? ImageSource.camera : ImageSource.gallery);
      if (picked == null) return false;
      return local.run(
        overrides: {key: LocalPicture.bytes(picked.bytes)},
        commit: () async {
          savedPath = await pictures.uploadPicked(kind, id, picked);
          await pictures.save(kind, id, savedPath);
        },
        warmUp: warmUp,
        affects: affects,
      );
    case _PictureChoice.url:
      if (!context.mounted) return false;
      final picture = await showAvatarUrlDialog(context);
      if (picture == null) return false;
      return local.run(
        overrides: {key: LocalPicture.bytes(picture.bytes)},
        commit: () async {
          savedPath = await pictures.uploadPicked(kind, id, picture);
          await pictures.save(kind, id, savedPath);
        },
        warmUp: warmUp,
        affects: affects,
      );
    case _PictureChoice.remove:
      // Back to automatic (album): which photo that is, only the server
      // knows -- shown as soon as it answered.
      return local.run(
        overrides: isAlbum ? const {} : {key: const LocalPicture.removed()},
        commit: () => isAlbum ? pictures.resetAlbumCover(id) : pictures.save(kind, id, null),
        affects: affects,
      );
  }
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
                        onTap: () => Navigator.of(context).pop(item),
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
