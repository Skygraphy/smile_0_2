import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/perf.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../services/media_cache_service.dart';
import '../services/media_service.dart';
import '../services/membership_service.dart';
import '../services/sync_bus.dart';
import 'package:smile_design_system/smile_design_system.dart';
import '../services/channel_service.dart';
import '../services/frame_service.dart';
import '../services/foreground_notifications.dart';
import '../services/object_picture_service.dart';
import 'album_info_screen.dart';
import 'capture_preview_screen.dart';
import '../widgets/friendly_error.dart';
import '../widgets/capture_choice.dart';
import '../widgets/album_covers.dart';
import '../widgets/local_display.dart';
import '../services/offline.dart';
import '../services/upload_queue.dart';
import '../services/local_changes.dart';
import '../services/channel_picker_service.dart';
import 'photo_viewer_screen.dart';
import 'frame_remote_screen.dart';
import 'album_slideshow_screen.dart';
import 'video_player_screen.dart';

/// WhatsApp-style chat feed: sorted chronologically top(oldest) to
/// bottom(newest), other members' photos on the left with their avatar
/// and name above the image, the caller's own on the right with neither
/// (same convention WhatsApp uses for its own outgoing messages).
class ChannelFeedScreen extends StatefulWidget {
  ChannelFeedScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    MediaService? mediaService,
    MembershipService? membershipService,
  })  : mediaService = mediaService ?? MediaService(),
        membershipService = membershipService ?? MembershipService();

  final String channelId;
  final String channelName;
  final MediaService mediaService;
  final MembershipService membershipService;

  @override
  State<ChannelFeedScreen> createState() => _ChannelFeedScreenState();
}

class _ChannelFeedScreenState extends State<ChannelFeedScreen> with SyncReload {
  List<MediaItem>? _items;
  late String _channelName = widget.channelName;
  /// This phone's own photos/videos on their way (UploadQueue), newest
  /// first -- shown at once, the server's copy takes over once it's there.
  List<QueuedUpload> get _pendingUploads => UploadQueue.instance.itemsFor(widget.channelId);
  StreamSubscription<QueuedUpload>? _queueFailures;
  /// Each one ticks once, the moment it appears in the album.
  final Set<String> _ticked = {};
  String? _errorMessage;
  String? _statusMessage;
  final Set<String> _selectedIds = {};
  /// For the album's own cover next to its name in the top bar, as
  /// WhatsApp shows the group picture (2026-10-09).
  Map<String, ChannelWithActivity> _covers = const {};
  /// The Frames this album is on (only those the caller manages, RLS) --
  /// the Frame symbol in the top bar opens their remote (2026-10-11).
  List<FrameShowing> _frames = const [];
  // WhatsApp's own "floating" date header: pinned at the top of the
  // visible feed, updating to whichever day's messages are currently
  // scrolled to the top. Not a real sliver-pinned header (that needs
  // `CustomScrollView` + `SliverPersistentHeader`, whose pinning behavior
  // combined with `reverse: true` was judged too easy to get subtly
  // backwards to risk here) -- instead a plain overlay `Positioned` on
  // top of the list, whose text is recomputed by measuring each date
  // separator's actual on-screen position after every scroll frame.
  final _feedStackKey = GlobalKey();
  final Map<String, GlobalKey> _dateSeparatorKeys = {};
  final _scrollController = ScrollController();
  DateTime? _stickyDate;
  // "Ausblenden" (any member, personal, reversible, Smile-App only) is a
  // completely separate feature from "Löschen" (sender/admin only,
  // permanent, everywhere) -- this just switches which feed is being
  // browsed, it never interacts with multi-select/delete state.
  bool _showingHidden = false;
  bool get _selectionMode => _selectedIds.isNotEmpty;

  // A viewer who can see this channel only via a Space they own being
  // shared into it (channel_shares) never posted here -- null while
  // loading, so the FAB stays hidden rather than briefly flashing the
  // wrong affordance.
  MyChannelMembershipStatus? _myStatus;
  bool _isRequestingMembership = false;

  @override
  void initState() {
    super.initState();
    // Photos arriving in this album need no notification while it is open.
    ForegroundNotifications.openAlbumId = widget.channelId;
    _loadFromCacheThenRefresh();
    _loadCover();
    _loadFrames();
    unawaited(_loadMyStatus());
    _scrollController.addListener(_updateStickyDate);
    // Already there (e.g. waiting from before): no tick for those.
    _ticked.addAll(_pendingUploads.map((p) => p.id));
    UploadQueue.instance.addListener(_onQueue);
    _queueFailures = UploadQueue.instance.failures.listen((item) {
      if (mounted && item.channelId == widget.channelId) {
        setState(() => _errorMessage = SmileTexts.of(context).sendFailed);
      }
    });
  }

  void _onQueue() {
    if (!mounted) return;
    setState(() {});
    for (final item in _pendingUploads) {
      // The tick comes the moment it appears in the album (decided
      // 2026-10-12), one per photo/video -- not when its ring goes.
      if (_ticked.add(item.id)) _tickNow();
    }
    if (_pendingUploads.any((p) => p.done)) unawaited(_handOver());
  }

  // Other members' uploads/processing completions/deletes, a hide on this
  // user's other device, a membership decision, a name change -- all
  // arrive as FCM sync pushes (SyncBus). The feed is the one expensive
  // reload, so it only reacts to changes concerning this channel (or a
  // profile, which may be a sender's name/avatar shown here).
  @override
  bool isSyncRelevant(SyncEvent event) {
    // Our own "seen" marker moving (album_reads, see markAlbumSeen) changes
    // nothing on this screen -- only the album list's counter.
    if (event.tables.length == 1 && event.tables.contains('album_reads')) return false;
    return event.channelIds.contains(widget.channelId) ||
        event.tables.contains('profiles') ||
        event.tables.contains('media_item_hides');
  }

  @override
  Future<void> onSync() async {
    if (await closeIfGone(context, table: 'channels', id: widget.channelId)) return;
    await _refreshAll();
    _loadCover();
    _loadFrames();
  }

  void _loadFrames() {
    unawaited(ChannelService().listFramesShowing(widget.channelId).then((frames) async {
      if (mounted) setState(() => _frames = frames);
      final favorites = await FrameService().favoritesOf(frames.map((f) => f.frameId).toList());
      if (mounted) setState(() => _favoriteFrames = favorites);
    }).catchError((Object _) {}));
  }

  /// Which photos are Lieblingsbilder of which of this album's Frames --
  /// the heart in the photo/video viewer shows it (2026-10-14).
  Map<String, Set<String>> _favoriteFrames = const {};

  /// A photo/video still on its way: full screen straight from the phone.
  Future<void> _openQueued(QueuedUpload item) async {
    final Widget screen;
    if (item.isVideo) {
      final path = item.localVideoPath;
      if (path == null) return;
      screen = VideoPlayerScreen(mediaId: item.mediaItemId ?? item.id, url: null, localPath: path);
    } else {
      final bytes = item.tileBytes;
      if (bytes == null) return;
      screen = PhotoViewerScreen.local(localBytes: bytes);
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  /// Newest first, only what is ready (and not just removed here).
  Future<void> _playSlideshow() async {
    final items = (_items ?? const <MediaItem>[]).where((i) => i.isReady && !_isGoneHere(i.id)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (items.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AlbumSlideshowScreen(albumName: _shownName, items: items)),
    );
  }

  /// "Jetzt am Frame zeigen" (2026-10-14): the Frame shows this photo at
  /// once (on several Frames, which one first). Fire and forget, with a
  /// tick -- a Frame that is offline simply doesn't change.
  Future<void> _showOnFrame(String mediaItemId) async {
    final frame = await _pickFrame();
    if (frame == null) return;
    unawaited(HapticFeedback.selectionClick());
    try {
      await FrameService().sendCommand(frameId: frame.frameId, command: 'show', mediaItemId: mediaItemId);
    } catch (_) {}
  }

  /// "Lieblingsbild für den Frame" (2026-10-14): onto the Frame's
  /// Lieblingsbilder (on several Frames, which one first).
  /// The heart marks or takes back -- on the picked Frame. Returns whether
  /// the photo is a Lieblingsbild of any Frame afterwards (the heart's fill).
  Future<bool?> _toggleFavorite(String mediaItemId) async {
    final t = SmileTexts.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final frame = await _pickFrame();
    if (frame == null) return null;
    final on = !(_favoriteFrames[mediaItemId]?.contains(frame.frameId) ?? false);
    unawaited(HapticFeedback.selectionClick());
    final before = _favoriteFrames;
    setState(() {
      final frames = {...?_favoriteFrames[mediaItemId]};
      on ? frames.add(frame.frameId) : frames.remove(frame.frameId);
      _favoriteFrames = {..._favoriteFrames, mediaItemId: frames};
    });
    final saved = await LocalChanges.instance.run(
      overrides: const {},
      commit: () => on
          ? FrameService().addFavorite(frameId: frame.frameId, mediaItemId: mediaItemId)
          : FrameService().removeFavorites(frameId: frame.frameId, mediaItemIds: [mediaItemId]),
      affects: tablesChanged({'frame_favorites'}),
    );
    if (!saved) {
      if (mounted) setState(() => _favoriteFrames = before);
      return before[mediaItemId]?.isNotEmpty ?? false;
    }
    final name = frameNameOf(frame.frameId, frame.frameName);
    messenger.showSnackBar(SnackBar(content: Text(on ? t.favoriteAddedTo(name) : t.favoriteRemovedFrom(name))));
    return _favoriteFrames[mediaItemId]?.isNotEmpty ?? false;
  }

  Future<FrameShowing?> _pickFrame() async {
    final t = SmileTexts.of(context);
    if (_frames.length == 1) return _frames.single;
    return showDialog<FrameShowing>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(t.pickFrame),
        children: [
          for (final f in _frames)
            SimpleDialogOption(onPressed: () => Navigator.of(context).pop(f), child: Text(frameNameOf(f.frameId, f.frameName))),
        ],
      ),
    );
  }

  Future<void> _openFrame() async {
    final t = SmileTexts.of(context);
    var frame = _frames.length == 1 ? _frames.single : null;
    frame ??= await showDialog<FrameShowing>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(t.pickFrame),
        children: [
          for (final f in _frames)
            SimpleDialogOption(onPressed: () => Navigator.of(context).pop(f), child: Text(frameNameOf(f.frameId, f.frameName))),
        ],
      ),
    );
    if (frame == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => FrameRemoteScreen(frameId: frame!.frameId)));
    _loadFrames();
  }

  void _loadCover() {
    unawaited(loadAlbumCovers().then((covers) {
      if (mounted) setState(() => _covers = covers);
    }));
  }

  /// Pull-to-refresh's own handler: also re-checks membership status, not
  /// just the feed itself -- nothing else notices when the channel's SCO
  /// decides a pending request/invite on their own device (same gap
  /// album_info_screen.dart and news_screen.dart have), so
  /// without this the FAB stays stuck on "Anfrage gesendet" forever even
  /// after being approved.
  Future<void> _refreshAll() => Future.wait([_load(), _loadMyStatus()]);

  Future<void> _loadMyStatus() async {
    try {
      final status = await widget.membershipService.getMyMembershipStatus(widget.channelId);
      if (!mounted) return;
      setState(() => _myStatus = status);
    } catch (_) {
      // Best-effort -- worst case the upload FAB stays hidden for a
      // member whose status failed to load, never the reverse.
    }
  }

  Future<void> _requestMembership() async {
    setState(() => _isRequestingMembership = true);
    try {
      await widget.membershipService.requestMembership(widget.channelId);
      await _loadMyStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Anfrage fehlgeschlagen: ${errorReason(context, e)}')));
    } finally {
      if (mounted) setState(() => _isRequestingMembership = false);
    }
  }

  Future<void> _withdrawMembershipRequest() async {
    final requestId = _myStatus?.pendingRequestId;
    if (requestId == null) return;
    setState(() => _isRequestingMembership = true);
    try {
      await widget.membershipService.withdrawMembershipRequest(requestId);
      await _loadMyStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Zurückziehen fehlgeschlagen: ${errorReason(context, e)}')));
    } finally {
      if (mounted) setState(() => _isRequestingMembership = false);
    }
  }

  /// Finds whichever date separator has most recently scrolled to (or
  /// past) the top of the feed and shows its date in the floating
  /// overlay -- re-measured after every scroll frame via the real
  /// `RenderBox` positions, not anything derived from scroll offset
  /// math, so it stays correct regardless of each bubble's (now
  /// variable, aspect-ratio-dependent) height.
  ///
  /// Deliberately shows *nothing* until a separator has actually reached
  /// the top edge (`dy <= 4`): an earlier version fell back to whichever
  /// separator was merely nearest the top while still fully visible
  /// further down the screen -- which, since the floating copy is always
  /// anchored right at the top, just put two identical date pills on
  /// screen at once with a gap between them. As long as a section's own
  /// inline separator is still visibly on screen, it already tells the
  /// user the date; the floating copy only earns its place once that
  /// inline separator has scrolled away and needs a stand-in.
  ///
  /// A short day (little or no content between two date changes) can
  /// still collide the floating copy with a *different*, later separator
  /// that's already close to the top too -- e.g. a day with only one
  /// short photo scrolls its own separator past (earning the float) just
  /// as the next day's separator arrives right underneath it. Suppress
  /// the float whenever any separator sits within its own rendered
  /// footprint of the top, whether or not that's the one being replaced.
  static const _stickyOverlayFootprintPx = 40.0;

  void _updateStickyDate() {
    final stackBox = _feedStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || !stackBox.attached) return;
    final stackTop = stackBox.localToGlobal(Offset.zero).dy;

    DateTime? passedCandidate;
    double passedBestDy = double.negativeInfinity;
    var anotherSeparatorCrowdsTheTop = false;

    for (final entry in _dateSeparatorKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final dy = box.localToGlobal(Offset.zero).dy - stackTop;
      // Its pill is still visible until the whole box has passed the top
      // (2026-10-11: counting only its top edge put both on screen).
      final bottom = dy + box.size.height;
      final date = DateTime.parse(entry.key);
      // Already scrolled to/past the top -- among those, the one closest
      // to it (largest dy that's still <= the small threshold) is the
      // section currently pinned.
      if (bottom <= 4 && dy > passedBestDy) {
        passedBestDy = dy;
        passedCandidate = date;
      }
      // A separator that hasn't fully passed yet but is already within
      // the floating pill's own footprint would sit right where the
      // float renders -- showing both would visually collide.
      if (bottom > 4 && dy <= _stickyOverlayFootprintPx) anotherSeparatorCrowdsTheTop = true;
    }

    final next = anotherSeparatorCrowdsTheTop ? null : passedCandidate;
    if (next != _stickyDate) setState(() => _stickyDate = next);
  }

  @override
  void dispose() {
    // Only clear it if no other feed took over in the meantime.
    if (ForegroundNotifications.openAlbumId == widget.channelId) ForegroundNotifications.openAlbumId = null;
    _scrollController.dispose();
    UploadQueue.instance.removeListener(_onQueue);
    unawaited(_queueFailures?.cancel());
    super.dispose();
  }

  /// Paints the last-known feed instantly from local cache (if any) so the
  /// screen isn't a blank spinner on every open, then kicks off the real
  /// network fetch in the background. Signed URLs are short-lived, so the
  /// cached paint is only ever a brief placeholder until `_load()` replaces
  /// it with fresh data.
  Future<void> _loadFromCacheThenRefresh() async {
    Perf.start('feed cache');
    Perf.start('feed network');
    final cached = await MediaCacheService.load(widget.channelId);
    if (cached != null && mounted && _items == null) {
      setState(() => _items = cached);
    }
    Perf.end('feed cache', '${cached?.length ?? 0} items');
    await _load();
  }

  Future<void> _load() async {
    final List<MediaItem> items;
    try {
      items = _showingHidden
          ? await widget.mediaService.fetchHiddenMedia(widget.channelId)
          : await widget.mediaService.fetchReadyMedia(widget.channelId);
      // Opening the album (and staying in it while new posts arrive)
      // counts as seen -- clears the unread counter. Best-effort.
      if (!_showingHidden) unawaited(ChannelService().markAlbumSeen(widget.channelId).catchError((_) {}));
    } catch (e) {
      if (!mounted) return;
      // Without this, a permission/network failure here left _items stuck
      // at null forever -- an unexplained, permanent loading spinner, since
      // nothing else ever calls setState to move past it.
      // Offline: the photos last loaded stay, the hint above says why
      // nothing new comes (2026-10-09).
      // Never an error on screen (2026-10-11): what was loaded last stays.
      Offline.noteFailure(e);
      debugPrint('SmileFeed: load failed: $e');
      setState(() => _items ??= const []);
      return;
    }
    Offline.reachedServer();
    Perf.end('feed network', '${items.length} items');
    if (!mounted) return;

    if (!_showingHidden) {
      // Fully download and decode each now-ready item that's still covered
      // by a local pending tile *before* swapping -- otherwise
      // CachedNetworkImage briefly paints its placeholder (or the blurry
      // preview) for the one frame it takes to fetch the real thumbnail,
      // which is exactly the "blur then sharp" pop this is trying to
      // avoid. Once precached, the widget paints straight from Flutter's
      // image cache with no placeholder frame at all. Irrelevant in the
      // hidden view, which never has pending uploads of its own.
      //
      // Iterate a snapshot, not the live list: `_load()` can run
      // concurrently with itself (the SyncBus-triggered debounced
      // call can fire while `_pickAndUpload`'s own retry-loop call is still
      // awaiting a precacheImage below), and the *other* call's `setState`
      // mutating `_pendingUploads` mid-iteration throws
      // ConcurrentModificationError.
      for (final pending in _pendingUploads.toList()) {
        MediaItem? readyItem;
        for (final item in items) {
          if (item.id == pending.mediaItemId && item.isReady) {
            readyItem = item;
            break;
          }
        }
        final url = readyItem == null
            ? null
            : readyItem.isVideo
                ? readyItem.thumbnailUrl // a video's display URL is the MP4 itself
                : readyItem.thumbnailUrl ?? readyItem.displayUrl;
        if (url == null) continue;
        if (!mounted) return;
        await precacheImage(CachedNetworkImageProvider(url, cacheKey: '${readyItem!.id}_grid'), context);
      }
      if (!mounted) return;
    }

    setState(() => _items = items);
    if (!_showingHidden) {
      // Keep showing the full-quality local bytes (no spinner, no interim
      // blurry preview) for as long as *this device's own* upload isn't
      // actually ready yet -- only swap to the real thumbnail once it
      // truly is, so there's exactly one clean handoff instead of
      // local-preview -> blurry-server-preview -> real-thumbnail.
      for (final p in _pendingUploads) {
        if (p.done && p.mediaItemId != null && items.any((i) => i.id == p.mediaItemId && i.isReady)) {
          UploadQueue.instance.forget(p);
        }
      }
    }
    if (!_showingHidden) unawaited(MediaCacheService.save(widget.channelId, items));
    // The date separators this data produces don't have a RenderBox yet
    // until after this frame lays them out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateStickyDate();
    });
  }

  void _toggleHiddenView() {
    setState(() {
      _showingHidden = !_showingHidden;
      _items = null; // brief spinner while switching feeds, same as first open
      _selectedIds.clear();
    });
    unawaited(_load());
  }


  Future<void> _pickAndUpload() async {
    // Photos and videos, several at once, one picker (decisions 2026-10-01:
    // videos of any length; 2026-10-08: multiple selection, mixed).
    final picked = await ImagePicker().pickMultipleMedia(imageQuality: 90);
    if (picked.isEmpty || !mounted) return;
    await _uploadFiles(picked);
  }

  /// The album's own camera (decided 2026-10-08): photo or video, then a
  /// preview offers "Senden" or "Nochmal" before anything is uploaded.
  Future<void> _chooseCapture() async {
    var captured = await captureWithChoice(context);
    while (captured != null) {
      if (!mounted) return;
      final (:file, :isVideo) = captured;
      final decision = await Navigator.of(context).push<CaptureDecision>(
        MaterialPageRoute(
          builder: (_) => CapturePreviewScreen(file: File(file.path), isVideo: isVideo, albumName: _channelName),
        ),
      );
      if (!mounted) return;
      if (decision == CaptureDecision.send) {
        await _uploadFiles([file]);
        return;
      }
      if (decision != CaptureDecision.retake) return;
      final again = await capture(video: isVideo);
      captured = again == null ? null : (file: again, isVideo: isVideo);
    }
  }

  /// A short tick per photo/video, like WhatsApp (2026-10-10) -- together
  /// with what it stands for ([action]: its ring disappearing), and a
  /// little apart from the next, so several don't blur into one.
  Future<void> _ticks = Future<void>.value();
  void _tick([void Function()? action]) {
    _ticks = _ticks.then((_) async {
      if (mounted && action != null) {
        action();
        // Felt when it is SEEN: wait until the frame showing the change is
        // actually on screen (the phone may be busy preparing the next
        // photo), then vibrate.
        await WidgetsBinding.instance.endOfFrame;
      }
      await HapticFeedback.lightImpact();
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
  }

  /// The tick of a sent photo/video, in the very frame it appears in the
  /// album (2026-10-12; before: when its ring went).
  /// The first one at once, each further one at least 150 ms after the
  /// previous, so they never overlap (decided 2026-10-11).
  DateTime _nextTickAt = DateTime(0);
  void _tickNow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      final at = now.isAfter(_nextTickAt) ? now : _nextTickAt;
      _nextTickAt = at.add(const Duration(milliseconds: 150));
      final wait = at.difference(now);
      if (wait <= Duration.zero) {
        unawaited(HapticFeedback.lightImpact());
      } else {
        Future<void>.delayed(wait, HapticFeedback.lightImpact);
      }
    });
  }

  /// Photos leaving the album one by one, each with its tick, before the
  /// delete goes to the server (LocalChanges then keeps them hidden).
  final Set<String> _leaving = {};

  /// Like WhatsApp (decided 2026-10-11): into the queue and the album at
  /// once; without a connection they wait there with a clock and go out by
  /// themselves later, even with Smile closed (UploadQueue).
  Future<void> _uploadFiles(List<XFile> picked) async {
    setState(() {
      _errorMessage = null;
      _statusMessage = null;
    });
    var index = 0;
    await UploadQueue.instance.enqueue(
      widget.channelId,
      picked,
      beforeShow: (item) async {
        // Decode before it's ever shown: Image.memory doesn't paint anything
        // for the frame or two it takes to decode a several-MB original,
        // which otherwise reads as a black flash the instant you tap upload.
        // Only the newest few are on screen right away -- decoding all of a
        // big batch up front would just eat memory.
        final position = index++;
        final bytes = item.tileBytes;
        if (mounted && bytes != null && position >= picked.length - 3) {
          await precacheImage(MemoryImage(bytes), context);
        }
      },
    );
  }

  /// Sent: each swaps to the server's copy as soon as that is loaded --
  /// one clean handoff, no blurry step in between.
  bool _handingOver = false;
  Future<void> _handOver() async {
    if (_handingOver) return;
    _handingOver = true;
    try {
      for (var attempt = 0; attempt < 8; attempt++) {
        await _load();
        if (!mounted) return;
        if (!_pendingUploads.any((p) => p.done)) return;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      // A video still converting on the server (the fallback when the
      // phone couldn't) keeps its sharp frame until it's ready -- the sync
      // push brings it; photos don't wait any longer.
      for (final p in _pendingUploads.where((p) => p.done && !p.isVideo).toList()) {
        UploadQueue.instance.forget(p);
      }
    } catch (_) {
      // The sync push brings them anyway.
    } finally {
      _handingOver = false;
    }
  }

  void _toggleSelected(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
    _remeasureStickyDate();
  }

  void _clearSelection() {
    setState(_selectedIds.clear);
    _remeasureStickyDate();
  }

  /// The selection bar changes the list's height: the floating date has to
  /// be measured again, or it sits on top of the inline one.
  void _remeasureStickyDate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateStickyDate();
    });
  }

  bool get _canSetCover {
    if (_showingHidden || _selectedIds.length != 1 || !(_myStatus?.isSco ?? false)) return false;
    final id = _selectedIds.first;
    return (_items ?? const []).any((item) => item.id == id && item.isReady);
  }

  Future<void> _setSelectedAsCover() async {
    final t = SmileTexts.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final mediaId = _selectedIds.first;
    final item = _items!.firstWhere((i) => i.id == mediaId);
    _clearSelection();
    // The photo is the cover at once, here and in every list (LocalChanges).
    final saved = await LocalChanges.instance.run(
      overrides: {
        if (item.thumbnailUrl != null)
          LocalChanges.albumCover(widget.channelId): LocalPicture.url(item.thumbnailUrl!, cacheKey: albumPhotoCacheKey(mediaId)),
      },
      commit: () => ObjectPictureService().setAlbumCoverPhoto(widget.channelId, mediaId),
      affects: tablesChanged({'channels'}, channelIds: {widget.channelId}),
    );
    if (saved) messenger.showSnackBar(SnackBar(content: Text(t.coverSet(_shownName))));
  }

  /// Every photo/video of this view -- not the ones still on their way.
  List<String> get _selectableIds {
    final queued = _showingHidden ? const <String?>{} : _pendingUploads.map((p) => p.mediaItemId).toSet();
    return (_items ?? const <MediaItem>[])
        .where((i) => !_isGoneHere(i.id) && !queued.contains(i.id))
        .map((i) => i.id)
        .toList();
  }

  bool get _allSelected {
    final all = _selectableIds;
    return all.isNotEmpty && all.every(_selectedIds.contains);
  }

  /// "Alle" / "Keine" (decided 2026-10-11).
  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_selectableIds);
      }
    });
    _remeasureStickyDate();
  }

  /// Like WhatsApp (decided 2026-10-11): "Für alle löschen" -- gone for
  /// everyone and from every Frame, permanently (delete-media) -- only
  /// when the caller may for every selected one (own photos, or the
  /// album's admin; the server checks too). "Für mich löschen" is the
  /// personal, reversible hide ("Ausgeblendet").
  Future<void> _deleteSelection() async {
    final t = SmileTexts.of(context);
    final myUserId = supabase.auth.currentUser?.id;
    final isSco = _myStatus?.isSco ?? false;
    final ids = _selectedIds.toList();
    final forEveryone =
        isSco || ids.every((id) => (_items ?? const <MediaItem>[]).any((i) => i.id == id && i.senderId == myUserId));
    final forMe = !_showingHidden;
    if (!forEveryone && !forMe) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.deleteOnlyOwn)));
      return;
    }
    final scheme = Theme.of(context).colorScheme;
    Widget option(String label, String? hint, bool value) => Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(value),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(label),
                if (hint != null)
                  Text(hint, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400)),
              ],
            ),
          ),
        );
    // true = for everyone, false = for me.
    final everyone = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deletePhotosTitle(ids.length)),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (forEveryone) option(t.deleteForEveryone, t.deleteForEveryoneHint, true),
            if (forMe) option(t.deleteForMe, t.deleteForMeHint, false),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.actionCancel)),
            ),
          ],
        ),
      ),
    );
    if (everyone == null || !mounted) return;
    if (everyone) {
      await _deleteForEveryone(ids);
    } else {
      await _applyHideToggleToSelection();
    }
  }

  Future<void> _deleteForEveryone(List<String> ids) async {
    _clearSelection();
    // One after the other, each photo disappears with its own short tick,
    // like WhatsApp (2026-10-10).
    for (final id in ids) {
      _tick(() => setState(() => _leaving.add(id)));
    }
    await _ticks;
    // Gone at once; back with a message if the server says no.
    MediaActionResult? result;
    final saved = await LocalChanges.instance.run(
      overrides: {for (final id in ids) LocalChanges.mediaGone(id): _viewName},
      commit: () async => result = await widget.mediaService.deletePhotos(ids),
      affects: tablesChanged({'media_items', 'channels'}, channelIds: {widget.channelId}),
      failureText: 'Löschen fehlgeschlagen.',
    );
    // From here LocalChanges keeps them hidden -- or they come back.
    if (mounted) setState(() => _leaving.removeAll(ids));
    if (!saved || !mounted) return;
    final denied = result?.deniedIds ?? const [];
    LocalChanges.instance.drop(denied.map(LocalChanges.mediaGone));
    setState(() {
      _errorMessage = denied.isEmpty ? null : '${denied.length} Foto(s) konnten nicht gelöscht werden (nicht eigenes Foto).';
    });
    await _load();
  }

  /// The actions for the marked photos, each with its name, at the bottom
  /// (decided 2026-10-11) -- room at the top for "3 ausgewählt".
  Widget _selectionBar(SmileTexts t) {
    final scheme = Theme.of(context).colorScheme;
    Widget action(IconData icon, String label, VoidCallback onTap, {bool danger = false}) {
      final color = danger ? scheme.primary : scheme.onSurface;
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            action(SmileIcons.selectAll, _allSelected ? t.selectNone : t.selectAll, _toggleSelectAll),
            if (_showingHidden) action(SmileIcons.unhide, t.actionUnhide, _applyHideToggleToSelection),
            if (_canSetCover) action(SmileIcons.picture, t.coverShort, _setSelectedAsCover),
            action(SmileIcons.delete, t.actionDelete, _deleteSelection, danger: true),
          ],
        ),
      ),
    );
  }

  /// Which list a just-removed photo disappears from (normal or hidden).
  String get _viewName => _showingHidden ? 'hidden' : 'feed';

  bool _isGoneHere(String mediaId) =>
      _leaving.contains(mediaId) || LocalChanges.instance.text(LocalChanges.mediaGone(mediaId)) == _viewName;

  String get _shownName => albumNameOf(widget.channelId, _channelName);

  /// Non-destructive and personal: any channel member may hide/re-show any
  /// selected photo(s) for just their own Smile-App view. Same multi-select
  /// flow as delete (long-press, tap to add more), no confirmation dialog
  /// since it's fully reversible -- just an eye icon next to the trash icon.
  Future<void> _applyHideToggleToSelection() async {
    final ids = _selectedIds.toList();
    _clearSelection();
    final hiding = !_showingHidden;
    // Out of this list at once; back with a message if the server says no.
    MediaActionResult? result;
    final saved = await LocalChanges.instance.run(
      overrides: {for (final id in ids) LocalChanges.mediaGone(id): _viewName},
      commit: () async => result = hiding ? await widget.mediaService.hidePhotos(ids) : await widget.mediaService.unhidePhotos(ids),
      affects: tablesChanged({'media_items', 'media_item_hides', 'channels'}, channelIds: {widget.channelId}),
      failureText: hiding ? 'Ausblenden fehlgeschlagen.' : 'Einblenden fehlgeschlagen.',
    );
    if (!saved || !mounted) return;
    final denied = result?.deniedIds ?? const [];
    LocalChanges.instance.drop(denied.map(LocalChanges.mediaGone));
    setState(() => _errorMessage = denied.isEmpty ? null : '${denied.length} Foto(s) nicht möglich.');
    await _load();
  }

  /// Builds the chat rows newest-first (for the `reverse: true` list),
  /// interleaving a centered date separator wherever the calendar day
  /// changes, and deciding per row whether to show the sender's
  /// avatar+name -- only at the *top* of a consecutive same-sender run
  /// (i.e. when the next *older* item, index i+1 in this newest-first
  /// list, belongs to someone else or doesn't exist), same convention
  /// WhatsApp itself uses. Built eagerly, not lazily, since both of these
  /// need to look at a row's older neighbor.
  List<Widget> _buildFeedRows(int pendingCount, List<MediaItem> visibleItems) {
    final myUserId = supabase.auth.currentUser?.id;
    final total = pendingCount + visibleItems.length;
    final queued = pendingCount == 0 ? const <QueuedUpload>[] : _pendingUploads;

    String? senderIdAt(int i) => i < pendingCount ? myUserId : visibleItems[i - pendingCount].senderId;
    DateTime createdAtAt(int i) => i < pendingCount ? queued[i].createdAt : visibleItems[i - pendingCount].createdAt;
    bool sameDay(DateTime a, DateTime b) {
      final la = a.toLocal();
      final lb = b.toLocal();
      return la.year == lb.year && la.month == lb.month && la.day == lb.day;
    }

    final rows = <Widget>[];
    for (var i = 0; i < total; i++) {
      // The tail (and, for a non-mine sender, the avatar+name label) only
      // belongs on the *first* (chronologically oldest, i.e. topmost on
      // screen) bubble of a consecutive same-sender run -- true for
      // pending uploads too, via the same senderIdAt helper (which
      // reports the caller's own id for a pending row).
      final olderSenderId = i + 1 < total ? senderIdAt(i + 1) : null;
      final isFirstInRun = olderSenderId != senderIdAt(i);

      if (i < pendingCount) {
        final pending = queued[i];
        final picture = _PhotoTile(bytes: pending.tileBytes);
        final still = pending.isVideo ? _VideoBadge(playable: false, child: picture) : picture;
        // Keyed by the queue item itself (stable across rebuilds) --
        // without a key, Flutter would tear this tile down and recreate
        // it on every sync-triggered rebuild instead of recognizing
        // it as unchanged.
        rows.add(_ChatRow(
          key: ValueKey('queued_${pending.id}'),
          isMine: true,
          showTail: isFirstInRun,
          aspectRatio: pending.aspectRatio,
          time: pending.createdAt,
          // A clock until it is on the server (2026-10-12, like WhatsApp);
          // without a connection also slightly darker, with "Nicht senden".
          waiting: !pending.done,
          // Opens at once from the phone -- before it is on the server, too.
          onTap: () => _openQueued(pending),
          onCancelSend: pending.waiting ? () => unawaited(UploadQueue.instance.cancel(pending)) : null,
          photo: pending.waiting
              ? Stack(fit: StackFit.passthrough, children: [
                  still,
                  Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.2))),
                ])
              : (pending.sure || pending.done)
                  ? still
                  : _UploadProgress(progress: pending.progress, child: picture),
        ));
      } else {
        final item = visibleItems[i - pendingCount];
        final previewBytes =
            item.previewDataUrl != null ? base64Decode(item.previewDataUrl!.split(',').last) : null;

        final Widget tile;
        if (!item.isReady) {
          // Someone else's still-uploading/processing photo -- their
          // instant preview, no local full-quality bytes for this viewer.
          tile = _PhotoTile(bytes: previewBytes);
        } else {
          // A video's display URL is the MP4 itself -- only its poster
          // frame (thumbnail) is an image.
          final imageUrl = item.isVideo ? item.thumbnailUrl : item.thumbnailUrl ?? item.displayUrl;
          final Widget small = imageUrl != null
              ? CachedNetworkImage(
                  // The URL itself carries a short-lived signed token that
                  // changes on every fetch -- key the disk cache on the
                  // stable media_item_id instead so a re-signed URL for
                  // the same photo still hits the cache.
                  cacheKey: '${item.id}_grid',
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  // Blur-up from the same tiny preview instead of a flat
                  // grey flash while the real thumbnail loads.
                  placeholder: (context, url) =>
                      previewBytes != null ? Image.memory(previewBytes, fit: BoxFit.cover) : const ColoredBox(color: Colors.black12),
                  errorWidget: (context, url, error) => const ColoredBox(color: Colors.black12),
                )
              : previewBytes != null
                  ? Image.memory(previewBytes, fit: BoxFit.cover)
                  : const ColoredBox(color: Colors.black12);
          // A photo shows its full version in the bubble (2026-10-10): the
          // 400 px thumbnail looked blurry in the larger WhatsApp-like
          // bubbles. The thumbnail stands in until it's loaded (and
          // offline, if it never was); the full view then opens from cache.
          tile = !item.isVideo && item.displayUrl != null
              ? CachedNetworkImage(
                  cacheKey: '${item.id}_display',
                  imageUrl: item.displayUrl!,
                  fit: BoxFit.cover,
                  // Decoded at bubble size, not 2048 px -- memory.
                  memCacheWidth: 900,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholder: (context, url) => small,
                  errorWidget: (context, url, error) => small,
                )
              : small;
        }

        final isMine = item.senderId == myUserId;
        // Every channel, whatever its current member count, can grow --
        // an owner can invite more people at any time -- so there's no
        // stable "this is a 1:1, no label needed" case to special-case;
        // always label a received photo with who sent it.
        final showSenderInfo = !isMine && isFirstInRun;
        rows.add(_ChatRow(
          key: ValueKey(item.id),
          isMine: isMine,
          showSenderInfo: showSenderInfo,
          showTail: isFirstInRun,
          aspectRatio: item.aspectRatio,
          senderName: isMine ? null : item.senderLabel,
          senderAvatarUrl: isMine ? null : item.senderAvatarUrl,
          time: item.createdAt,
          isSelected: _selectedIds.contains(item.id),
          // Delete works the same way in both views -- a hidden photo can
          // be deleted directly here instead of having to unhide it first.
          onLongPress: () => _toggleSelected(item.id),
          onTap: _selectionMode
              ? () => _toggleSelected(item.id)
              : (item.isVideo && item.isReady && item.displayUrl != null)
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VideoPlayerScreen(
                            mediaId: item.id,
                            url: item.displayUrl,
                            onShowOnFrame: _frames.isEmpty ? null : () => _showOnFrame(item.id),
                            favorite: _favoriteFrames[item.id]?.isNotEmpty ?? false,
                            onFavorite: _frames.isEmpty ? null : () => _toggleFavorite(item.id),
                          ),
                        ),
                      )
                  // A photo: the whole of it, full screen (the bubble crops).
                  : (!item.isVideo && item.isReady)
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PhotoViewerScreen(
                                item: item,
                                onShowOnFrame: _frames.isEmpty ? null : () => _showOnFrame(item.id),
                                favorite: _favoriteFrames[item.id]?.isNotEmpty ?? false,
                            onFavorite: _frames.isEmpty ? null : () => _toggleFavorite(item.id),
                              ),
                            ),
                          )
                      : null,
          photo: item.isVideo
              ? _VideoBadge(playable: item.isReady && item.displayUrl != null, child: tile)
              : tile,
        ));
      }

      final thisDate = createdAtAt(i);
      final olderExists = i + 1 < total;
      if (!olderExists || !sameDay(thisDate, createdAtAt(i + 1))) {
        // Keyed by calendar day (not the row index) so the same
        // GlobalKey identity survives across rebuilds -- _updateStickyDate
        // relies on that to keep measuring the right RenderBox.
        final dayKey = thisDate.toLocal().toIso8601String().substring(0, 10);
        final separatorKey = _dateSeparatorKeys.putIfAbsent(dayKey, () => GlobalKey());
        rows.add(_DateSeparator(key: separatorKey, date: thisDate));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    return Scaffold(
      appBar: _selectionMode
          ? AppBar(
              leading: IconButton(icon: const Icon(SmileIcons.close), onPressed: _clearSelection),
              // In words (2026-10-11) -- the actions are in the bar below.
              title: Text(_allSelected ? t.allSelected(_selectedIds.length) : t.selectedCount(_selectedIds.length)),
            )
          : _showingHidden
              ? AppBar(
                  // Entering/leaving this view reads as real navigation (a
                  // sub-page, back arrow to leave) rather than a toggle --
                  // it no longer shares the eye icon with the per-tile
                  // hide/unhide action, which was confusing (same icon,
                  // opposite meaning in each context).
                  leading: IconButton(icon: const Icon(SmileIcons.back), onPressed: _toggleHiddenView),
                  title: Text(t.hiddenPhotos),
                )
              : AppBar(
                  leading: IconButton(icon: const Icon(SmileIcons.back), onPressed: () => Navigator.of(context).maybePop()),
                  titleSpacing: 0,
                  // WhatsApp pattern: tapping the album's icon + name opens
                  // its info page (people, shares, frames).
                  title: Tooltip(
                    message: t.albumInfo,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(SmileRadius.m),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AlbumInfoScreen(
                              channelId: widget.channelId,
                              channelName: _channelName,
                              onRenamed: (name) => setState(() => _channelName = name),
                            ),
                          ),
                        );
                        // The cover may have been changed there.
                        _loadCover();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Row(
                          children: [
                            albumCover(widget.channelId, _shownName, _covers, size: 36),
                            const SizedBox(width: SmileSpacing.m),
                            Expanded(child: Text(_shownName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    // The album as a slideshow, like on a Frame (2026-10-11).
                    if ((_items ?? const <MediaItem>[]).any((i) => i.isReady))
                      IconButton(icon: const Icon(SmileIcons.slideshow), tooltip: t.playSlideshow, onPressed: _playSlideshow),
                    if (_frames.isNotEmpty)
                      IconButton(icon: const Icon(SmileIcons.frame), tooltip: t.openRemote, onPressed: _openFrame),
                    IconButton(
                      icon: const Icon(SmileIcons.hide),
                      tooltip: t.hiddenPhotos,
                      onPressed: _toggleHiddenView,
                    ),
                  ],
                ),
      bottomNavigationBar: _selectionMode ? _selectionBar(t) : null,
      floatingActionButton: _selectionMode || _showingHidden || _myStatus == null
          ? null
          : _myStatus!.isMember
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Camera above "+" (decided 2026-10-08): a short choice
                    // between photo and video. "+" stays the main button --
                    // most photos for a Frame already exist.
                    FloatingActionButton.small(
                      heroTag: null,
                      tooltip: t.captureInAlbum,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      onPressed: _chooseCapture,
                      child: const Icon(SmileIcons.camera),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      heroTag: null,
                      tooltip: t.addMedia,
                      onPressed: _pickAndUpload,
                      child: const Icon(SmileIcons.add),
                    ),
                  ],
                )
              : FloatingActionButton.extended(
                  heroTag: null,
                  // Only a Space-shared viewer (never a plain member, that
                  // branch above already covers them) ever lands here --
                  // requesting posting rights for themselves, the other
                  // symmetric half of album_info_screen.dart's
                  // "Person einladen".
                  onPressed: _isRequestingMembership
                      ? null
                      : (_myStatus!.pendingRequestId != null ? _withdrawMembershipRequest : _requestMembership),
                  icon: _isRequestingMembership
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_myStatus!.pendingRequestId != null ? SmileIcons.pending : SmileIcons.invite),
                  label: Text(_myStatus!.pendingRequestId != null ? t.requestSent : t.requestMembership),
                ),
      body: _items == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(_statusMessage!, style: Theme.of(context).textTheme.bodySmall),
                  ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                Expanded(
                  child: Builder(builder: (context) {
                    final pendingCount = _showingHidden ? 0 : _pendingUploads.length;
                    final pendingIds = _pendingUploads.map((p) => p.mediaItemId).toSet();
                    // A row already covered by a local pending tile (this
                    // device's own not-yet-ready upload) is skipped here --
                    // otherwise it'd render twice: once at full local
                    // quality via the pending tile, once blurry via its
                    // server-side preview. Never applies in the hidden view.
                    final visibleItems = (_showingHidden
                            ? _items!
                            : _items!.where((item) => !pendingIds.contains(item.id)))
                        .where((item) => !_isGoneHere(item.id))
                        // Still not ready after an hour: a send that broke
                        // off -- it never becomes anything (2026-10-12).
                        .where((item) => item.isReady || DateTime.now().difference(item.createdAt) < const Duration(hours: 1))
                        .toList();
                    if (visibleItems.isEmpty && pendingCount == 0) {
                      return RefreshIndicator(
                        onRefresh: _refreshAll,
                        child: ListView(
                          children: [
                            const SizedBox(height: 160),
                            SmileEmptyState(
                              icon: _showingHidden ? SmileIcons.hide : SmileIcons.album,
                              title: _showingHidden ? t.hiddenPhotosEmpty : t.feedEmptyTitle,
                              message: !_showingHidden && (_myStatus?.isMember ?? false) ? t.feedEmptyMemberHint : null,
                            ),
                          ],
                        ),
                      );
                    }
                    return Stack(
                      key: _feedStackKey,
                      children: [
                        RefreshIndicator(
                          onRefresh: _refreshAll,
                          child: ListView(
                            // Index 0 is the newest thing (a pending upload
                            // if any, else the newest ready item -- same
                            // order the old grid used) and `reverse: true`
                            // paints index 0 at the *bottom* -- so without
                            // reordering anything, this reads top(oldest)
                            // to bottom(newest), scrolled to the newest
                            // message, exactly like a chat. Built eagerly
                            // (not `.builder`) since the date-separator and
                            // avatar-run grouping below need to look at
                            // neighboring items -- fine at this app's real
                            // scale (the feed already loads full history
                            // up front, see media_service.dart).
                            controller: _scrollController,
                            reverse: true,
                            // Extra bottom clearance (visual top, since
                            // reverse:true puts the newest item there) so the
                            // newest message can scroll fully clear of the
                            // FloatingActionButton instead of sitting under
                            // it -- the Scaffold doesn't reserve this space
                            // automatically, only when the FAB is actually
                            // showing (hidden during selection/hidden view).
                            padding: EdgeInsets.fromLTRB(
                              0,
                              8,
                              0,
                              // + the system navigation bar: the feed runs
                              // underneath it (edge-to-edge), the FABs don't.
                              MediaQuery.paddingOf(context).bottom +
                                  (_selectionMode || _showingHidden ? 8 : (_myStatus?.isMember ?? false) ? 144 : 88),
                            ),
                            children: _buildFeedRows(pendingCount, visibleItems),
                          ),
                        ),
                        // WhatsApp's own floating date header -- see
                        // _updateStickyDate's doc comment for why this is a
                        // plain overlay rather than a sliver-pinned header.
                        if (_stickyDate != null)
                          Positioned(
                            top: 8,
                            left: 0,
                            right: 0,
                            child: Center(child: _DateSeparator(date: _stickyDate!, floating: true)),
                          ),
                      ],
                    );
                  }),
                ),
              ],
            ),
    );
  }
}

/// A photo whose real, server-processed thumbnail isn't in hand yet: either
/// this device's own upload (the actual locally-picked bytes, full quality)
/// or another member's still-processing photo (their tiny server-generated
/// preview). Deliberately no spinner or dimming -- it's meant to read as "a
/// photo", not "a photo that's loading", so the later swap to the real
/// `CachedNetworkImage` goes unnoticed. `bytes` is null only if a remote
/// preview failed to generate.
/// A photo or video still on its way: its own progress ring on the
/// picture, like WhatsApp (2026-10-10) -- instead of a spinner on the
/// button that blocked sending more.
class _UploadProgress extends StatelessWidget {
  const _UploadProgress({required this.child, this.progress});

  final Widget child;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.25))),
        Positioned.fill(
          child: Center(
            child: Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 3,
                color: Colors.white,
                backgroundColor: progress == null ? null : Colors.white24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final data = bytes;
    final image = data != null ? Image.memory(data, fit: BoxFit.cover) : const ColoredBox(color: Colors.black12);
    // Runs once per tile identity (same key -> TweenAnimationBuilder doesn't
    // re-animate on later rebuilds, only the first time this tile mounts),
    // fading the already-decoded image in instead of it just popping into
    // place the instant it's inserted.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
      child: image,
    );
  }
}

/// One chat-style row, WhatsApp-style: the photo sits inside a rounded,
/// colored "frame" (a speech-bubble-like container, not a plain
/// borderless tile) with the time overlaid at its bottom-right corner.
/// The photo itself keeps its original aspect ratio (fit within a
/// bounding box) instead of always being cropped to a square. The
/// caller's own bubbles align right with no avatar/name column at all;
/// everyone else's align left with a fixed avatar gutter, separate from
/// the bubble itself -- the avatar+name (`showSenderInfo`) and the
/// speech-bubble tail (`showTail`) both only actually render on the
/// *first* (topmost, chronologically oldest) bubble of a consecutive
/// same-sender run (decided by the caller, `_buildFeedRows`), same
/// convention WhatsApp itself uses -- but the avatar gutter's width is
/// always reserved so continuation bubbles still line up underneath.
/// A play symbol over a video's poster frame -- videos are tiles like
/// photos, tapping one plays it full-screen (VideoPlayerScreen).
class _VideoBadge extends StatelessWidget {
  const _VideoBadge({required this.child, this.playable = true});

  final Widget child;

  /// False while the video can't be played yet (still going up, or still
  /// being prepared on the server): the play sign is only faint then
  /// (2026-10-10), so it doesn't look like a button.
  final bool playable;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Center(child: Icon(SmileIcons.play, size: 56, color: playable ? Colors.white70 : Colors.white24)),
      ],
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    super.key,
    required this.isMine,
    required this.photo,
    this.showSenderInfo = true,
    this.showTail = true,
    this.senderName,
    this.senderAvatarUrl,
    this.time,
    this.aspectRatio,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.waiting = false,
    this.onCancelSend,
  });

  final bool isMine;
  /// Waiting for a connection to be sent: a clock next to the time.
  final bool waiting;
  /// "Nicht senden" in its menu (three dots), while it waits.
  final VoidCallback? onCancelSend;
  final Widget photo;
  // Any channel, however many members it has right now, can grow (an
  // owner can invite more people at any time) -- so a received photo
  // always gets a name/avatar gutter reserved, even in what's currently
  // a two-person channel. Only the *first* bubble of a consecutive
  // same-sender run actually shows the avatar+name (see `showTail`'s
  // doc comment); continuation bubbles still reserve the gutter so they
  // stay aligned under the one that does show it.
  final bool showSenderInfo;
  // The speech-bubble pointer -- only the first bubble of a consecutive
  // same-sender run gets one (mine included), not every single bubble.
  final bool showTail;
  final String? senderName;
  final String? senderAvatarUrl;
  final DateTime? time;
  // width/height, if known -- null (not yet processed, or decode failed)
  // falls back to a square.
  final double? aspectRatio;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  static const _avatarGutterWidth = 36.0;
  static const _cornerRadius = 16.0;
  // The tail sticks out *sideways* from the bubble's top corner (right of
  // it for mine, left of it for others) by (tailWidth - tailOverlap); the
  // remaining `tailOverlap` px are painted *inside* the bubble's own fill
  // area so the two shapes' edges merge into one solid region instead of
  // needing a hairline-precise abutment (which anti-aliasing on two
  // separately-painted shapes can never quite guarantee). It stays fully
  // within the bubble's own vertical span (top: 0 to tailHeight), so --
  // unlike the earlier above-the-bubble version -- it never overflows into
  // the row above and needs no extra top clearance for that.
  static const _tailWidth = 10.0;
  static const _tailHeight = 16.0;
  static const _tailOverlap = 4.0;

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  /// Like WhatsApp (decided 2026-10-10, variant D): three fixed shapes
  /// instead of each photo's exact ratio, which made photos of the same
  /// camera come out in different widths. Landscape wide (4:3), portrait
  /// narrower (3:4), roughly square ones square -- the picture is cropped
  /// to fit (BoxFit.cover); tapping it shows the whole photo.
  Size _photoBoxSize() {
    final ratio = aspectRatio ?? 1.0;
    if (ratio > 1.1) return const Size(264, 198); // 4:3
    if (ratio < 0.9) return const Size(210, 280); // 3:4
    return const Size(236, 236);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Own bubbles get a coral-tinted frame, others a neutral one -- the
    // same "mine vs. theirs" color split WhatsApp itself uses (there with
    // green vs. grey), just built from this app's own tokens instead of
    // a hardcoded WhatsApp-green.
    final frameColor = isMine ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHigh;
    final photoSize = _photoBoxSize();

    // The tail-side *top* corner is left sharp only when a tail is
    // actually shown, so the painted triangle sits flush against it --
    // a continuation bubble (no tail) stays fully rounded on all sides.
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(showTail && !isMine ? 0 : _cornerRadius),
      topRight: Radius.circular(showTail && isMine ? 0 : _cornerRadius),
      bottomLeft: const Radius.circular(_cornerRadius),
      bottomRight: const Radius.circular(_cornerRadius),
    );

    final frame = Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: frameColor, borderRadius: borderRadius),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: photoSize.width,
              height: photoSize.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photo,
                  if (isSelected)
                    Container(
                      color: Colors.black45,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.all(4),
                      child: const Icon(SmileIcons.selected, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
          if (time != null)
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (waiting) ...[
                      const Icon(SmileIcons.waiting, color: Colors.white, size: 12),
                      const SizedBox(width: 3),
                    ],
                    Text(_formatTime(time!), style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),
            ),
          if (onCancelSend != null)
            Positioned(
              top: 2,
              right: 2,
              child: PopupMenuButton<void>(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                  child: const Icon(SmileIcons.more, color: Colors.white, size: 18),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem<void>(onTap: onCancelSend, child: Text(SmileTexts.of(context).dontSend)),
                ],
              ),
            ),
        ],
      ),
    );

    // The speech-bubble "pointer" -- a small triangle sticking out
    // *sideways* from the bubble's top corner (right for mine, left for
    // others'), same fill color as the frame, tip pointing toward that
    // side (not upward) so it reads as "this bubble belongs to that
    // side" rather than as a spike above the bubble. Positioned so
    // `_tailOverlap` px of it sit *inside* the frame's own bounds (see
    // the constants' doc comment) instead of trying to align two
    // separate shapes edge-to-edge.
    final bubble = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: showTail
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                frame,
                Positioned(
                  top: 0,
                  right: isMine ? -(_tailWidth - _tailOverlap) : null,
                  left: isMine ? null : -(_tailWidth - _tailOverlap),
                  child: CustomPaint(
                    size: const Size(_tailWidth, _tailHeight),
                    painter: _BubbleTailPainter(color: frameColor, pointRight: isMine, overlap: _tailOverlap),
                  ),
                ),
              ],
            )
          : frame,
    );

    // The tail now stays within the bubble's own vertical bounds (see
    // above), so it needs no extra top clearance -- a plain constant gap
    // between consecutive rows, same as any continuation bubble.
    const topPadding = 4.0;

    if (isMine) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, topPadding, 12, 4),
        child: Align(alignment: Alignment.centerRight, child: bubble),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, topPadding, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fixed-width gutter, populated only at the top of a run --
          // reserving the space either way keeps continuation bubbles
          // aligned under it instead of sliding left.
          SizedBox(
            width: _avatarGutterWidth,
            child: showSenderInfo ? SmileAvatar(name: senderName ?? '', avatarUrl: senderAvatarUrl, size: 32) : null,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showSenderInfo)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 2),
                  child: Text(
                    senderName ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              bubble,
            ],
          ),
        ],
      ),
    );
  }
}

/// A small flag-shaped tail attached at the bubble's sharp top corner,
/// pointing sideways. `overlap` px of it sit *inside* the bubble's own
/// fill area (see `_ChatRow._tailOverlap`'s doc comment); the corner
/// point itself (where the bubble's own straight top edge and this
/// shape meet) sits at local x = `overlap` (mine) / `width - overlap`
/// (others) -- exactly where the bubble's real corner is, not at the
/// embedded shape's own edge -- so the top segment from there to the
/// bubble's edge is perfectly flat and colinear with the bubble's own
/// top, instead of the diagonal starting early and looking chamfered/
/// not-quite-flush against the bubble. Only the two diagonals actually
/// converging on the sideways tip are genuinely visible.
class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.color, required this.pointRight, required this.overlap});

  final Color color;
  final bool pointRight;
  final double overlap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    final tipY = size.height / 2;
    if (pointRight) {
      path.moveTo(0, 0);
      // Flat along the bubble's own top edge up to its real corner...
      path.lineTo(overlap, 0);
      // ...then the diagonal actually pointing right, starting exactly
      // at that corner.
      path.lineTo(size.width, tipY);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width - overlap, 0);
      path.lineTo(0, tipY);
      path.lineTo(size.width, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pointRight != pointRight || oldDelegate.overlap != overlap;
}

/// A centered date pill between two days' worth of messages -- "Heute" /
/// "Gestern" / `dd.MM.yyyy`, same convention WhatsApp uses to break up
/// its own chat history.
class _DateSeparator extends StatelessWidget {
  const _DateSeparator({super.key, required this.date, this.floating = false});

  final DateTime date;
  // The overlay copy pinned at the top of the feed (see
  // _updateStickyDate) gets a subtle shadow so it visually lifts above
  // the scrolling content behind it -- the plain inline copies further
  // down the feed don't need that, they already sit in the normal flow.
  final bool floating;

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _label() {
    final local = date.toLocal();
    final now = DateTime.now();
    if (_isSameDay(local, now)) return 'Heute';
    if (_isSameDay(local, now.subtract(const Duration(days: 1)))) return 'Gestern';
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            boxShadow: floating
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(_label(), style: theme.textTheme.bodySmall),
        ),
      ),
    );
  }
}

