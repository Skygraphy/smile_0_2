import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'media_service.dart';
import 'media_shrink.dart';
import 'offline.dart';
import 'video_cache.dart';

/// One photo or video on its way into an album.
class QueuedUpload {
  QueuedUpload._(this.dir, this.meta, this.tileBytes);

  final Directory dir;
  final Map<String, dynamic> meta;

  /// What the album shows until the server's copy is there: the photo
  /// itself, or a still from the video.
  final Uint8List? tileBytes;

  String get id => meta['id'] as String;
  String get userId => meta['user_id'] as String;
  String get channelId => meta['channel_id'] as String;
  bool get isVideo => meta['kind'] == 'video';
  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(meta['created_at'] as int);
  double? get aspectRatio => (meta['aspect_ratio'] as num?)?.toDouble();
  bool get prepared => meta['prepared'] == true;

  /// Its id on the server once known: a photo brings its own, a video gets
  /// one from create-upload.
  String? get mediaItemId => meta['server_media_id'] as String? ?? (isVideo || meta['via_server'] == true ? null : id);

  // --- What the album shows (not stored) --------------------------------
  /// 0..1 while known (a video being converted or sent), null = spinning.
  double? progress;

  /// No connection: waits with a clock until there is one again.
  bool waiting = false;

  /// Ready on the phone with a connection: from here on it almost always
  /// goes through, so no more ring (2026-10-10).
  bool sure = false;

  /// In the album on the server; the album swaps to the server's copy.
  bool done = false;
}

/// Photos and videos are sent like WhatsApp sends messages (decided
/// 2026-10-11): everything goes into this queue on the phone first and is
/// shown in the album at once. Without a connection it waits there with a
/// clock and goes out by itself as soon as there is one -- even when Smile
/// is closed (Android WorkManager starts [runInBackground], see
/// UploadWorker.kt) and after a restart.
///
/// Each item lives in its own folder under app support `upload_queue/`
/// (meta.json plus its files); it is removed once the server has it.
/// Making it ready (shrinking) needs no connection and happens right away;
/// only sending waits. A lock file makes sure the app and the background
/// worker never send the same thing at once.
class UploadQueue extends ChangeNotifier {
  UploadQueue._();

  static final instance = UploadQueue._();

  static const _channel = MethodChannel('smile/upload_queue');

  final _mediaService = MediaService();
  final List<QueuedUpload> _items = [];
  /// Being written by [enqueue] right now -- not yet "found on disk".
  final Set<String> _adding = {};
  final _failures = StreamController<QueuedUpload>.broadcast();

  /// Registered while the phone converts a video -- one round trip less.
  final Map<String, Future<Map<String, dynamic>?>> _earlyCreate = {};

  Directory? _root;
  bool _inBackground = false;
  bool _processing = false;
  bool _again = false;
  Timer? _retryTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;

  /// Something the server refused (e.g. no longer a member of the album):
  /// it is gone from the queue; the album says so.
  Stream<QueuedUpload> get failures => _failures.stream;

  /// Newest first, as the album lists them.
  List<QueuedUpload> itemsFor(String channelId) =>
      _items.where((i) => i.channelId == channelId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// The album has swapped to the server's copy.
  void forget(QueuedUpload item) {
    if (_items.remove(item)) notifyListeners();
  }

  Future<Directory> _dir() async {
    final root = _root ??= Directory('${(await getApplicationSupportDirectory()).path}/upload_queue');
    await root.create(recursive: true);
    return root;
  }

  /// In the app: picks up what is left from before and sends whenever the
  /// connection comes back.
  Future<void> start() async {
    _connectivity ??= Connectivity().onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) unawaited(process());
    });
    // The background worker asks a running app to send (UploadWorker.kt).
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'process') unawaited(process());
    });
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) unawaited(process());
    });
    await _syncFromDisk();
    unawaited(process());
  }

  /// In the background worker: sends what it can; returns how many are left.
  Future<int> runInBackground() async {
    _inBackground = true;
    await _syncFromDisk();
    await process();
    return _items.where((i) => !i.done).length;
  }

  /// Signed out: nothing of this account is sent any more.
  Future<void> clear() async {
    _items.clear();
    _earlyCreate.clear();
    try {
      final root = await _dir();
      await root.delete(recursive: true);
    } catch (_) {}
    notifyListeners();
    unawaited(_scheduleBackground(false));
  }

  /// Puts picked photos/videos into the queue and the album. [beforeShow]
  /// runs for each before it appears (e.g. decoding its picture, so it
  /// doesn't flash black).
  Future<void> enqueue(
    String channelId,
    List<XFile> files, {
    Future<void> Function(QueuedUpload item)? beforeShow,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final root = await _dir();
    final start = DateTime.now().millisecondsSinceEpoch;
    for (final (index, file) in files.indexed) {
      final id = MediaService.newUuid();
      _adding.add(id);
      final dir = await Directory('${root.path}/$id').create(recursive: true);
      final extension = file.path.split('.').last.toLowerCase();
      final isVideo = _videoExtensions.contains(extension);
      final Uint8List? tile;
      final meta = <String, dynamic>{
        'id': id,
        'user_id': userId,
        'channel_id': channelId,
        'kind': isVideo ? 'video' : 'photo',
        // In the order they were picked, even within one millisecond.
        'created_at': start + index,
        'extension': extension,
        'mime_type': isVideo
            ? (extension == 'mov' ? 'video/quicktime' : 'video/$extension')
            : (extension == 'png' ? 'image/png' : 'image/jpeg'),
      };
      if (isVideo) {
        // The video itself stays where the picker put it until it is
        // converted (copying a long original would take a while).
        meta['source'] = file.path;
        tile = await MediaService.videoPosterBytes(File(file.path));
        if (tile != null) await File('${dir.path}/tile.jpg').writeAsBytes(tile);
      } else {
        tile = await file.readAsBytes();
        await File('${dir.path}/original').writeAsBytes(tile);
      }
      if (tile != null) meta['aspect_ratio'] = await _aspectRatio(tile);
      await _writeMeta(dir, meta);
      final item = QueuedUpload._(dir, meta, tile);
      if (beforeShow != null) await beforeShow(item);
      _items.add(item);
      _adding.remove(id);
      notifyListeners();
      // The first one starts at once -- not only after all were put in.
      unawaited(process());
    }
    unawaited(_scheduleBackground(true));
  }

  /// "Nicht senden": only while it waits.
  Future<void> cancel(QueuedUpload item) async {
    if (!_items.remove(item)) return;
    notifyListeners();
    final serverId = item.meta['server_media_id'] as String?;
    if (item.isVideo && serverId != null) unawaited(_mediaService.dropUnfinished(serverId));
    final early = _earlyCreate.remove(item.id);
    if (early != null) {
      unawaited(early.then((data) async {
        final id = data?['media_item_id'] as String?;
        if (id != null && id != serverId) await _mediaService.dropUnfinished(id);
      }));
    }
    await _deleteDir(item);
  }

  // --- Sending ----------------------------------------------------------

  Future<void> process() async {
    if (_processing) {
      _again = true;
      return;
    }
    _processing = true;
    try {
      do {
        _again = false;
        await _processOnce();
      } while (_again);
    } catch (e) {
      debugPrint('SmileQueue: $e');
    } finally {
      _processing = false;
    }
  }

  Future<void> _processOnce() async {
    final lock = _QueueLock(File('${(await _dir()).parent.path}/upload_queue.lock'));
    if (!await lock.tryAcquire()) {
      // The other side (app or background worker) is sending: look again
      // shortly -- what it sent disappears from here then.
      _retryLater(const Duration(seconds: 3));
      return;
    }
    try {
      // Signed out (or the session is gone): they wait for the account.
      while (Supabase.instance.client.auth.currentUser != null) {
        await _syncFromDisk();
        final todo = _items.where((i) => !i.done).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        if (todo.isEmpty) break;
        final head = todo.first;
        if (head.userId != Supabase.instance.client.auth.currentUser?.id) {
          // Left over from an account that is no longer signed in.
          _items.remove(head);
          await _deleteDir(head);
          continue;
        }
        // Photos of the same album go together (one request for all),
        // videos one by one.
        final run = head.isVideo
            ? [head]
            : todo.takeWhile((i) => !i.isVideo && i.channelId == head.channelId).take(10).toList();
        var online = await Offline.hasNetwork();
        // The next ones are made ready while this one goes up (2026-10-12:
        // several videos waited for each other's upload before converting).
        unawaited(_prepareAhead());
        for (final item in run.where((i) => !i.prepared).toList()) {
          await _ensurePrepared(item, online: online);
        }
        final ready = run.where((i) => _items.contains(i) && i.prepared).toList();
        if (ready.isEmpty) continue;
        online = await Offline.hasNetwork();
        if (!online) {
          // Everything else can at least be made ready meanwhile.
          for (final item in todo.where((i) => _items.contains(i) && !i.prepared).toList()) {
            await _ensurePrepared(item, online: false);
          }
          _markWaiting();
          break;
        }
        bool sent;
        try {
          sent = await _send(ready);
        } catch (e) {
          // E.g. its files are gone: drop these, go on with the rest.
          for (final item in ready.where((i) => !i.done)) {
            await _fail(item, e);
          }
          sent = true;
        }
        if (!sent) {
          _markWaiting();
          break;
        }
      }
    } finally {
      await lock.release();
    }
    final left = _items.where((i) => !i.done).isNotEmpty;
    unawaited(_scheduleBackground(left));
    // Connected to a WLAN without internet doesn't change connectivity --
    // so look again every now and then while something waits.
    if (left) _retryLater(const Duration(seconds: 20));
  }

  void _retryLater(Duration delay) {
    if (_inBackground) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(process()));
  }

  void _markWaiting() {
    for (final item in _items.where((i) => !i.done)) {
      item.waiting = true;
      item.progress = null;
    }
    notifyListeners();
  }

  /// One preparation per item, whoever asks for it (the send loop or
  /// [_prepareAhead]) -- never two conversions of the same video.
  final Map<String, Future<void>> _preparing = {};

  Future<void> _ensurePrepared(QueuedUpload item, {required bool online}) {
    if (item.prepared || !_items.contains(item)) return Future.value();
    return _preparing[item.id] ??= _prepareOrDrop(item, online: online).whenComplete(() => _preparing.remove(item.id));
  }

  /// Makes every waiting item ready, oldest first, one at a time (the
  /// phone's video encoder does one video at a time anyway).
  bool _preparingAhead = false;
  Future<void> _prepareAhead() async {
    if (_preparingAhead) return;
    _preparingAhead = true;
    try {
      while (true) {
        final me = Supabase.instance.client.auth.currentUser?.id;
        final next = (_items.where((i) => !i.done && !i.prepared && i.userId == me).toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)))
            .firstOrNull;
        if (next == null) break;
        await _ensurePrepared(next, online: await Offline.hasNetwork());
      }
    } finally {
      _preparingAhead = false;
    }
  }

  /// Progress is drawn at most ~10 times a second (2026-10-12: every
  /// percent redrew the whole album, the phone fell behind and the ticks
  /// came late).
  final Map<String, DateTime> _lastProgressAt = {};
  void _progress(QueuedUpload item, double value) {
    item.progress = value;
    final now = DateTime.now();
    final last = _lastProgressAt[item.id];
    if (last != null && now.difference(last) < const Duration(milliseconds: 100) && value < 1) return;
    _lastProgressAt[item.id] = now;
    notifyListeners();
  }

  /// A photo/video that can't be read any more is dropped (with the
  /// usual message) instead of holding up everything behind it.
  Future<void> _prepareOrDrop(QueuedUpload item, {required bool online}) async {
    try {
      await _prepare(item, online: online);
    } catch (e) {
      await _fail(item, e);
    }
  }

  Future<void> _prepare(QueuedUpload item, {required bool online}) async {
    final dir = item.dir;
    if (!item.isVideo) {
      final original = File('${dir.path}/original');
      final bytes = await original.readAsBytes();
      final prepared = await _mediaService.preparePhoto(bytes);
      if (prepared == null) {
        item.meta['via_server'] = true;
      } else {
        await File('${dir.path}/display.jpg').writeAsBytes(prepared.display);
        await File('${dir.path}/thumb.jpg').writeAsBytes(prepared.thumbnail);
        item.meta['width'] = prepared.size?.$1;
        item.meta['height'] = prepared.size?.$2;
        item.meta['preview'] = prepared.preview;
      }
      item.meta['prepared'] = true;
      await _writeMeta(dir, item.meta);
      if (prepared != null) {
        await _tryDelete(original);
        if (online) item.sure = true;
      }
      notifyListeners();
      return;
    }

    final source = File(item.meta['source'] as String);
    if (!await source.exists()) {
      await _fail(item, MediaServiceException('video_missing'));
      return;
    }
    final size = await source.length();
    final video = await _mediaService.prepareVideo(
      source,
      mimeType: item.meta['mime_type'] as String,
      onPreparing: (percent) => _progress(item, percent / 100),
      onFramed: (preview) {
        // Registered while the phone converts (2026-10-09).
        if (online && item.meta['server_media_id'] == null) {
          _earlyCreate[item.id] = _mediaService
              .createVideoUpload(channelId: item.channelId, fileSizeBytes: size, previewDataUrl: preview)
              .then<Map<String, dynamic>?>((data) async {
            item.meta['server_media_id'] = data['media_item_id'];
            await _writeMeta(item.dir, item.meta);
            return data;
          }).catchError((Object _) => null);
        }
      },
    );
    var path = video.file.path;
    if (path != source.path) {
      // The converted copy belongs to the queue now.
      path = '${dir.path}/video.mp4';
      try {
        await video.file.rename(path);
      } catch (_) {
        await video.file.copy(path);
        await _tryDelete(video.file);
      }
    }
    if (video.poster != null) await File('${dir.path}/poster.jpg').writeAsBytes(video.poster!);
    final shrunk = video.shrunk;
    item.meta
      ..['video_path'] = path
      ..['upload_mime'] = video.mimeType
      ..['converted'] = shrunk != null
      ..['width'] = shrunk?.width
      ..['height'] = shrunk?.height
      ..['duration'] = shrunk?.durationSeconds
      ..['preview'] = video.previewDataUrl
      ..['prepared'] = true;
    await _writeMeta(dir, item.meta);
    item.progress = null;
    if (online && shrunk != null) item.sure = true;
    notifyListeners();
  }

  /// False when the connection is gone (everything stays); a refusal by
  /// the server removes just that item.
  Future<bool> _send(List<QueuedUpload> run) async {
    if (!run.first.isVideo) return _sendPhotos(run);
    return _sendVideo(run.single);
  }

  Future<bool> _sendPhotos(List<QueuedUpload> run) async {
    var connected = true;
    final direct = run.where((i) => i.meta['via_server'] != true).toList();
    if (direct.isNotEmpty) {
      final photos = <({String id, PreparedPhoto photo})>[];
      for (final item in direct) {
        final width = item.meta['width'] as int?;
        final height = item.meta['height'] as int?;
        photos.add((
          id: item.id,
          photo: PreparedPhoto(
            display: await File('${item.dir.path}/display.jpg').readAsBytes(),
            thumbnail: await File('${item.dir.path}/thumb.jpg').readAsBytes(),
            size: width != null && height != null ? (width, height) : null,
            preview: item.meta['preview'] as String?,
          ),
        ));
      }
      final errors = await _mediaService.sendPreparedPhotos(channelId: run.first.channelId, photos: photos);
      for (final (i, error) in errors.indexed) {
        if (error == null) {
          await _finish(direct[i], direct[i].id);
        } else if (Offline.isConnectionError(error)) {
          connected = false;
        } else {
          await _fail(direct[i], error);
        }
      }
    }
    for (final item in run.where((i) => i.meta['via_server'] == true)) {
      if (!connected) break;
      final errors = await _mediaService.uploadPhotosViaServer(
        channelId: item.channelId,
        photos: [
          (
            bytes: await File('${item.dir.path}/original').readAsBytes(),
            fileExtension: item.meta['extension'] as String,
            mimeType: item.meta['mime_type'] as String,
          ),
        ],
        onMediaItemCreated: (_, id) => item.meta['server_media_id'] = id,
      );
      final error = errors.single;
      if (error == null) {
        await _finish(item, item.meta['server_media_id'] as String?);
      } else if (Offline.isConnectionError(error)) {
        connected = false;
      } else {
        await _fail(item, error);
      }
    }
    return connected;
  }

  Future<bool> _sendVideo(QueuedUpload item) async {
    Map<String, dynamic>? createData;
    final early = _earlyCreate.remove(item.id);
    if (early != null) createData = await early;
    final leftOver = item.meta['server_media_id'] as String?;
    if (createData == null && leftOver != null) {
      // Registered by an earlier try that never finished: start clean.
      await _mediaService.dropUnfinished(leftOver);
      item.meta.remove('server_media_id');
      await _writeMeta(item.dir, item.meta);
    }
    final converted = item.meta['converted'] == true;
    final posterFile = File('${item.dir.path}/poster.jpg');
    final poster = await posterFile.exists() ? await posterFile.readAsBytes() : null;
    final file = File(item.meta['video_path'] as String);
    if (!await file.exists()) {
      await _fail(item, MediaServiceException('video_missing'));
      return true;
    }
    try {
      final mediaId = await _mediaService.sendPreparedVideo(
        channelId: item.channelId,
        video: PreparedVideo(
          file: file,
          mimeType: item.meta['upload_mime'] as String,
          shrunk: converted && poster != null
              ? ShrunkVideo(
                  file: file,
                  width: item.meta['width'] as int?,
                  height: item.meta['height'] as int?,
                  durationSeconds: (item.meta['duration'] as num?)?.toDouble(),
                )
              : null,
          poster: poster,
          previewDataUrl: item.meta['preview'] as String?,
        ),
        createData: createData,
        onMediaItemCreated: (id) {
          item.meta['server_media_id'] = id;
          unawaited(_writeMeta(item.dir, item.meta));
        },
        onProgress: (sent, total) {
          if (item.sure || total == 0) return;
          // Bytes are flowing: the connection is really there.
          if (sent > 0) item.waiting = false;
          _progress(item, sent / total);
        },
      );
      // The converted copy is the video as it now is on the server: kept
      // on the phone, it plays at once and offline (VideoCache).
      if (converted) await VideoCache.keep(mediaId, file);
      await _finish(item, mediaId);
      return true;
    } catch (e) {
      if (Offline.isConnectionError(e)) return false;
      await _fail(item, e);
      return true;
    }
  }

  Future<void> _finish(QueuedUpload item, String? mediaId) async {
    if (mediaId != null) item.meta['server_media_id'] = mediaId;
    item
      ..done = true
      ..sure = true
      ..waiting = false
      ..progress = null;
    await _deleteDir(item);
    notifyListeners();
    // The album swaps to the server's copy and forgets it; if it isn't
    // open, this does.
    Timer(const Duration(minutes: 2), () => forget(item));
  }

  Future<void> _fail(QueuedUpload item, Object error) async {
    debugPrint('SmileQueue: ${item.id} refused: $error');
    _items.remove(item);
    await _deleteDir(item);
    notifyListeners();
    _failures.add(item);
  }

  // --- On disk ----------------------------------------------------------

  /// Takes in what is on disk but not here yet (from before a restart, or
  /// added by the other side); what vanished was sent by the other side.
  Future<void> _syncFromDisk() async {
    final root = await _dir();
    final onDisk = <String>{};
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      final metaFile = File('${entry.path}/meta.json');
      if (!await metaFile.exists()) {
        // Half-written by an enqueue that was killed.
        final age = DateTime.now().difference((await entry.stat()).modified);
        if (age > const Duration(minutes: 10)) await _tryDeleteDir(entry);
        continue;
      }
      final Map<String, dynamic> meta;
      try {
        meta = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      final id = meta['id'] as String;
      onDisk.add(id);
      if (_adding.contains(id) || _items.any((i) => i.id == id)) continue;
      Uint8List? tile;
      for (final name in ['display.jpg', 'original', 'tile.jpg']) {
        final file = File('${entry.path}/$name');
        if (await file.exists()) {
          tile = await file.readAsBytes();
          break;
        }
      }
      _items.add(QueuedUpload._(entry, meta, tile));
    }
    for (final item in _items.where((i) => !i.done && !onDisk.contains(i.id)).toList()) {
      item
        ..done = true
        ..sure = true
        ..waiting = false;
      Timer(const Duration(minutes: 2), () => forget(item));
    }
    notifyListeners();
  }

  static Future<void> _writeMeta(Directory dir, Map<String, dynamic> meta) async {
    final tmp = File('${dir.path}/meta.json.tmp');
    await tmp.writeAsString(jsonEncode(meta), flush: true);
    await tmp.rename('${dir.path}/meta.json');
  }

  static Future<void> _deleteDir(QueuedUpload item) => _tryDeleteDir(item.dir);

  static Future<void> _tryDeleteDir(Directory dir) async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }

  static Future<void> _tryDelete(File file) async {
    try {
      await file.delete();
    } catch (_) {}
  }

  /// WorkManager (UploadWorker.kt): sends what is left once there is a
  /// connection, even with Smile closed.
  Future<void> _scheduleBackground(bool needed) async {
    if (_inBackground) return;
    try {
      await _channel.invokeMethod(needed ? 'schedule' : 'cancel');
    } catch (_) {}
  }

  static Future<double?> _aspectRatio(Uint8List bytes) async {
    try {
      // A small decode is enough for the shape -- a full 12 MP one takes
      // a few hundred ms per photo.
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64);
      final frame = await codec.getNextFrame();
      final ratio = frame.image.height > 0 ? frame.image.width / frame.image.height : null;
      frame.image.dispose();
      return ratio;
    } catch (_) {
      return null;
    }
  }

  static const _videoExtensions = {'mp4', 'mov', 'm4v', '3gp', 'mkv', 'webm', 'avi'};
}

/// Only one side sends at a time: a file created exclusively, kept fresh
/// while sending; one left by a killed process counts as free after 90 s.
class _QueueLock {
  _QueueLock(this.file);

  final File file;
  Timer? _heartbeat;

  static const _stale = Duration(seconds: 90);

  Future<bool> tryAcquire() async {
    try {
      await file.create(exclusive: true);
    } on FileSystemException {
      try {
        final age = DateTime.now().difference(await file.lastModified());
        if (age < _stale) return false;
        await file.delete();
        await file.create(exclusive: true);
      } catch (_) {
        return false;
      }
    }
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      file.setLastModified(DateTime.now()).catchError((Object _) {});
    });
    return true;
  }

  Future<void> release() async {
    _heartbeat?.cancel();
    try {
      await file.delete();
    } catch (_) {}
  }
}
