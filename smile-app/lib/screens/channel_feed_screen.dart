import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../services/media_cache_service.dart';
import '../services/media_service.dart';
import '../services/membership_service.dart';
import '../widgets/smile_avatar.dart';
import 'channel_members_screen.dart';

/// A picked photo shown in the grid immediately, before the network upload
/// (let alone server-side processing) has even started -- WhatsApp-style
/// optimistic UI. `mediaItemId` fills in once create-upload responds, so the
/// upload loop can tell when the real, fully-processed item has taken its
/// place in `_items` and this placeholder can be dropped.
class _PendingUpload {
  _PendingUpload(this.bytes, {this.aspectRatio});
  final Uint8List bytes;
  String? mediaItemId;
  // Decoded once up front (see _pickAndUpload) so the placeholder shows
  // at the photo's real aspect ratio from the very first frame instead
  // of a square that reflows once the real item arrives.
  final double? aspectRatio;
}

/// Best-effort -- a decode failure just falls back to a square
/// placeholder for the transient pre-upload moment, not a real problem.
Future<double?> _decodeAspectRatio(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final width = frame.image.width;
    final height = frame.image.height;
    frame.image.dispose();
    return height > 0 ? width / height : null;
  } catch (_) {
    return null;
  }
}

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

class _ChannelFeedScreenState extends State<ChannelFeedScreen> {
  List<MediaItem>? _items;
  final List<_PendingUpload> _pendingUploads = [];
  bool _isUploading = false;
  String? _errorMessage;
  String? _statusMessage;
  RealtimeChannel? _realtimeChannel;
  Timer? _realtimeDebounce;
  final Set<String> _selectedIds = {};
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
    _loadFromCacheThenRefresh();
    unawaited(_loadMyStatus());
    // Other members' (or this device's own, on a second screen) uploads and
    // processing completions land here without polling -- media_items_select
    // RLS already lets any channel member see any row in their channel, so a
    // plain INSERT/UPDATE subscription is enough to know something changed.
    // Hides/unhides never touch media_items, so this never fires for them --
    // fine, since the hidden view is only ever refreshed by the viewer's own
    // actions or a manual pull-to-refresh.
    _realtimeChannel = widget.mediaService.subscribeToChannelMedia(widget.channelId, _onRealtimeChange);
    _scrollController.addListener(_updateStickyDate);
  }

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Anfrage fehlgeschlagen: $e')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Zurückziehen fehlgeschlagen: $e')));
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
      final date = DateTime.parse(entry.key);
      // Already scrolled to/past the top -- among those, the one closest
      // to it (largest dy that's still <= the small threshold) is the
      // section currently pinned.
      if (dy <= 4 && dy > passedBestDy) {
        passedBestDy = dy;
        passedCandidate = date;
      }
      // A separator that hasn't fully passed yet but is already within
      // the floating pill's own footprint would sit right where the
      // float renders -- showing both would visually collide.
      if (dy > 4 && dy <= _stickyOverlayFootprintPx) anotherSeparatorCrowdsTheTop = true;
    }

    final next = anotherSeparatorCrowdsTheTop ? null : passedCandidate;
    if (next != _stickyDate) setState(() => _stickyDate = next);
  }

  void _onRealtimeChange() {
    // Several rows can change in a burst (e.g. a batch upload finishing
    // processing one after another) -- debounce so that doesn't turn into a
    // `_load()` per row.
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 400), () => unawaited(_load()));
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    final channel = _realtimeChannel;
    if (channel != null) unawaited(widget.mediaService.unsubscribe(channel));
    _scrollController.dispose();
    super.dispose();
  }

  /// Paints the last-known feed instantly from local cache (if any) so the
  /// screen isn't a blank spinner on every open, then kicks off the real
  /// network fetch in the background. Signed URLs are short-lived, so the
  /// cached paint is only ever a brief placeholder until `_load()` replaces
  /// it with fresh data.
  Future<void> _loadFromCacheThenRefresh() async {
    final cached = await MediaCacheService.load(widget.channelId);
    if (cached != null && mounted && _items == null) {
      setState(() => _items = cached);
    }
    await _load();
  }

  Future<void> _load() async {
    final List<MediaItem> items;
    try {
      items = _showingHidden
          ? await widget.mediaService.fetchHiddenMedia(widget.channelId)
          : await widget.mediaService.fetchReadyMedia(widget.channelId);
    } catch (e) {
      if (!mounted) return;
      // Without this, a permission/network failure here left _items stuck
      // at null forever -- an unexplained, permanent loading spinner, since
      // nothing else ever calls setState to move past it.
      setState(() {
        _items ??= const [];
        _errorMessage = 'Fotos konnten nicht geladen werden: $e';
      });
      return;
    }
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
      // concurrently with itself (the realtime subscription's debounced
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
        final url = readyItem?.thumbnailUrl ?? readyItem?.displayUrl;
        if (url == null) continue;
        if (!mounted) return;
        await precacheImage(CachedNetworkImageProvider(url, cacheKey: '${readyItem!.id}_grid'), context);
      }
      if (!mounted) return;
    }

    setState(() {
      _items = items;
      if (!_showingHidden) {
        // Keep showing the full-quality local bytes (no spinner, no interim
        // blurry preview) for as long as *this device's own* upload isn't
        // actually ready yet -- only swap to the real thumbnail once it
        // truly is, so there's exactly one clean handoff instead of
        // local-preview -> blurry-server-preview -> real-thumbnail.
        _pendingUploads.removeWhere(
          (p) => p.mediaItemId != null && items.any((i) => i.id == p.mediaItemId && i.isReady),
        );
      }
    });
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
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    // Decode before it's ever shown: Image.memory doesn't paint anything
    // for the frame or two it takes to decode a several-MB original, which
    // otherwise reads as a black flash the instant you tap upload.
    if (mounted) await precacheImage(MemoryImage(bytes), context);
    final aspectRatio = await _decodeAspectRatio(bytes);
    // Show the picked photo in the grid *before* any network call -- the
    // slow part (upload + server-side resize/thumbnail/dispatch) happens
    // behind this placeholder instead of blocking what the user sees.
    final pending = _PendingUpload(bytes, aspectRatio: aspectRatio);
    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _statusMessage = null;
      _pendingUploads.insert(0, pending);
    });
    try {
      final extension = picked.path.split('.').last.toLowerCase();
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
      await widget.mediaService.uploadPhoto(
        channelId: widget.channelId,
        bytes: bytes,
        fileExtension: extension,
        mimeType: mimeType,
        onMediaItemCreated: (id) => pending.mediaItemId = id,
        // A dropped connection (e.g. switching WiFi networks mid-upload) is
        // retried automatically -- this just keeps the user informed while
        // it's happening instead of the tile silently sitting there.
        onRetrying: (attempt, maxAttempts) {
          if (!mounted) return;
          setState(() => _statusMessage = 'Verbindung unterbrochen, versuche erneut ($attempt/$maxAttempts)…');
        },
      );
      if (mounted) setState(() => _statusMessage = null);
      // Processing (resize/thumbnail) happens asynchronously in the
      // media-processing-service, so the real item may not be 'ready' yet
      // right after upload -- give it a few short retries before giving up.
      // The placeholder above is already covering this wait for the user.
      for (var attempt = 0; attempt < 5; attempt++) {
        await _load();
        if (_items!.any((item) => item.id == pending.mediaItemId && item.isReady)) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = null;
        _errorMessage = 'Upload fehlgeschlagen (auch nach mehreren Versuchen): $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _pendingUploads.remove(pending);
        });
      }
    }
  }

  void _toggleSelected(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  /// Destructive and permanent: gone from the DB, every storage bucket,
  /// every other member's feed, and every Smile-Frame the moment it's
  /// confirmed (see supabase/functions/delete-media). No undo, no
  /// placeholder -- just a plain yes/no confirmation. A denied id (someone
  /// else's photo without admin/staff rights) doesn't block the rest of
  /// the batch.
  Future<void> _confirmAndDeleteSelection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_selectedIds.length} Foto(s) endgültig löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;

    final ids = _selectedIds.toList();
    _clearSelection();
    try {
      final result = await widget.mediaService.deletePhotos(ids);
      if (!mounted) return;
      setState(() {
        _errorMessage = result.deniedIds.isEmpty
            ? null
            : '${result.deniedIds.length} Foto(s) konnten nicht gelöscht werden (nicht eigenes Foto).';
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Löschen fehlgeschlagen: $e');
    }
  }

  /// Non-destructive and personal: any channel member may hide/re-show any
  /// selected photo(s) for just their own Smile-App view. Same multi-select
  /// flow as delete (long-press, tap to add more), no confirmation dialog
  /// since it's fully reversible -- just an eye icon next to the trash icon.
  Future<void> _applyHideToggleToSelection() async {
    final ids = _selectedIds.toList();
    _clearSelection();
    final hiding = !_showingHidden;
    try {
      final result = hiding
          ? await widget.mediaService.hidePhotos(ids)
          : await widget.mediaService.unhidePhotos(ids);
      if (!mounted) return;
      setState(() {
        _errorMessage = result.deniedIds.isEmpty
            ? null
            : '${result.deniedIds.length} Foto(s) nicht möglich.';
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '${hiding ? "Ausblenden" : "Einblenden"} fehlgeschlagen: $e');
    }
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

    String? senderIdAt(int i) => i < pendingCount ? myUserId : visibleItems[i - pendingCount].senderId;
    DateTime createdAtAt(int i) => i < pendingCount ? DateTime.now() : visibleItems[i - pendingCount].createdAt;
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
        final pending = _pendingUploads[i];
        // Keyed by the upload attempt itself (stable across rebuilds) --
        // without a key, Flutter would tear this tile down and recreate
        // it on every realtime-triggered rebuild instead of recognizing
        // it as unchanged.
        rows.add(_ChatRow(
          key: ValueKey(pending),
          isMine: true,
          showTail: isFirstInRun,
          aspectRatio: pending.aspectRatio,
          photo: _PhotoTile(bytes: pending.bytes),
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
          final imageUrl = item.thumbnailUrl ?? item.displayUrl;
          tile = imageUrl != null
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
              : const ColoredBox(color: Colors.black12);
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
          onTap: _selectionMode ? () => _toggleSelected(item.id) : null,
          photo: tile,
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
    return Scaffold(
      appBar: _selectionMode
          ? AppBar(
              leading: IconButton(icon: const Icon(Icons.close), onPressed: _clearSelection),
              title: Text('${_selectedIds.length} ausgewählt'),
              actions: [
                IconButton(
                  icon: Icon(_showingHidden ? Icons.visibility : Icons.visibility_off),
                  tooltip: _showingHidden ? 'Einblenden' : 'Ausblenden',
                  onPressed: _applyHideToggleToSelection,
                ),
                IconButton(icon: const Icon(Icons.delete_outline), onPressed: _confirmAndDeleteSelection),
              ],
            )
          : _showingHidden
              ? AppBar(
                  // Entering/leaving this view reads as real navigation (a
                  // sub-page, back arrow to leave) rather than a toggle --
                  // it no longer shares the eye icon with the per-tile
                  // hide/unhide action, which was confusing (same icon,
                  // opposite meaning in each context).
                  leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _toggleHiddenView),
                  title: const Text('Ausgeblendete Fotos'),
                )
              : AppBar(
                  title: Text(widget.channelName),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.group),
                      tooltip: 'Mitglieder',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChannelMembersScreen(
                            channelId: widget.channelId,
                            channelName: widget.channelName,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.hide_image_outlined),
                      tooltip: 'Ausgeblendete Fotos',
                      onPressed: _toggleHiddenView,
                    ),
                  ],
                ),
      floatingActionButton: _selectionMode || _showingHidden || _myStatus == null
          ? null
          : _myStatus!.isMember
              ? FloatingActionButton(
                  onPressed: _isUploading ? null : _pickAndUpload,
                  child: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_a_photo),
                )
              : FloatingActionButton.extended(
                  // Only a Space-shared viewer (never a plain member, that
                  // branch above already covers them) ever lands here --
                  // requesting posting rights for themselves, the other
                  // symmetric half of channel_members_screen.dart's
                  // "Person einladen".
                  onPressed: _isRequestingMembership
                      ? null
                      : (_myStatus!.pendingRequestId != null ? _withdrawMembershipRequest : _requestMembership),
                  icon: _isRequestingMembership
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_myStatus!.pendingRequestId != null ? Icons.hourglass_top : Icons.person_add),
                  label: Text(_myStatus!.pendingRequestId != null ? 'Anfrage gesendet' : 'Beitritt anfragen'),
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
                    final visibleItems = _showingHidden
                        ? _items!
                        : _items!.where((item) => item.isReady || !pendingIds.contains(item.id)).toList();
                    if (visibleItems.isEmpty && pendingCount == 0) {
                      return RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          children: [
                            const SizedBox(height: 200),
                            Center(
                              child: Text(_showingHidden ? 'Keine ausgeblendeten Fotos' : 'Noch keine Fotos'),
                            ),
                          ],
                        ),
                      );
                    }
                    return Stack(
                      key: _feedStackKey,
                      children: [
                        RefreshIndicator(
                          onRefresh: _load,
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
                              _selectionMode || _showingHidden ? 8 : 88,
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
  });

  final bool isMine;
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
  static const _maxPhotoWidth = 220.0;
  static const _maxPhotoHeight = 280.0;
  static const _minPhotoSize = 130.0;
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

  /// Fits `aspectRatio` inside a `_maxPhotoWidth` x `_maxPhotoHeight` box
  /// (like `BoxFit.contain` would), then guards against a sliver for an
  /// extreme aspect ratio with a floor on the shorter side.
  Size _photoBoxSize() {
    final ratio = aspectRatio ?? 1.0;
    var w = _maxPhotoWidth;
    var h = w / ratio;
    if (h > _maxPhotoHeight) {
      h = _maxPhotoHeight;
      w = h * ratio;
    }
    if (w < _minPhotoSize) {
      w = _minPhotoSize;
      h = w / ratio;
    } else if (h < _minPhotoSize) {
      h = _minPhotoSize;
      w = h * ratio;
    }
    return Size(w, h);
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
                      child: const Icon(Icons.check_circle, color: Colors.white),
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
                child: Text(_formatTime(time!), style: const TextStyle(color: Colors.white, fontSize: 11)),
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

