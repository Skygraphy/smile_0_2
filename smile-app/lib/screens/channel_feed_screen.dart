import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/media_cache_service.dart';
import '../services/media_service.dart';
import 'channel_members_screen.dart';

/// A picked photo shown in the grid immediately, before the network upload
/// (let alone server-side processing) has even started -- WhatsApp-style
/// optimistic UI. `mediaItemId` fills in once create-upload responds, so the
/// upload loop can tell when the real, fully-processed item has taken its
/// place in `_items` and this placeholder can be dropped.
class _PendingUpload {
  _PendingUpload(this.bytes);
  final Uint8List bytes;
  String? mediaItemId;
}

/// Phase 3 minimal feed: pick a photo, upload it, show what's ready. Full
/// chat-style feed UI, captions, and video are later phases.
class ChannelFeedScreen extends StatefulWidget {
  ChannelFeedScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    MediaService? mediaService,
  }) : mediaService = mediaService ?? MediaService();

  final String channelId;
  final String channelName;
  final MediaService mediaService;

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
  // "Ausblenden" (any member, personal, reversible, Smile-App only) is a
  // completely separate feature from "Löschen" (sender/admin only,
  // permanent, everywhere) -- this just switches which feed is being
  // browsed, it never interacts with multi-select/delete state.
  bool _showingHidden = false;

  bool get _selectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadFromCacheThenRefresh();
    // Other members' (or this device's own, on a second screen) uploads and
    // processing completions land here without polling -- media_items_select
    // RLS already lets any channel member see any row in their channel, so a
    // plain INSERT/UPDATE subscription is enough to know something changed.
    // Hides/unhides never touch media_items, so this never fires for them --
    // fine, since the hidden view is only ever refreshed by the viewer's own
    // actions or a manual pull-to-refresh.
    _realtimeChannel = widget.mediaService.subscribeToChannelMedia(widget.channelId, _onRealtimeChange);
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
    // Show the picked photo in the grid *before* any network call -- the
    // slow part (upload + server-side resize/thumbnail/dispatch) happens
    // behind this placeholder instead of blocking what the user sees.
    final pending = _PendingUpload(bytes);
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
      floatingActionButton: _selectionMode || _showingHidden
          ? null
          : FloatingActionButton(
              onPressed: _isUploading ? null : _pickAndUpload,
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_a_photo),
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
                    return RefreshIndicator(
                      onRefresh: _load,
                      child: visibleItems.isEmpty && pendingCount == 0
                          ? ListView(
                              children: [
                                const SizedBox(height: 200),
                                Center(
                                  child: Text(_showingHidden ? 'Keine ausgeblendeten Fotos' : 'Noch keine Fotos'),
                                ),
                              ],
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(8),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                              ),
                              itemCount: pendingCount + visibleItems.length,
                              itemBuilder: (context, index) {
                                if (index < pendingCount) {
                                  final pending = _pendingUploads[index];
                                  // Keyed by the upload attempt itself (stable across
                                  // rebuilds) -- without a key, Flutter would tear this
                                  // tile down and recreate it on every realtime-triggered
                                  // rebuild instead of recognizing it as unchanged.
                                  return _PhotoTile(key: ValueKey(pending), bytes: pending.bytes);
                                }
                                final item = visibleItems[index - pendingCount];
                                final previewBytes = item.previewDataUrl != null
                                    ? base64Decode(item.previewDataUrl!.split(',').last)
                                    : null;

                                final Widget tile;
                                if (!item.isReady) {
                                  // Someone else's still-uploading/processing photo --
                                  // their instant preview, no local full-quality bytes
                                  // available for this viewer.
                                  tile = _PhotoTile(bytes: previewBytes);
                                } else {
                                  final gridImageUrl = item.thumbnailUrl ?? item.displayUrl;
                                  tile = gridImageUrl != null
                                      ? CachedNetworkImage(
                                          // The URL itself carries a short-lived signed token
                                          // that changes on every fetch -- key the disk cache
                                          // on the stable media_item_id instead so a re-signed
                                          // URL for the same photo still hits the cache.
                                          cacheKey: '${item.id}_grid',
                                          imageUrl: gridImageUrl,
                                          fit: BoxFit.cover,
                                          fadeInDuration: Duration.zero,
                                          fadeOutDuration: Duration.zero,
                                          // Blur-up from the same tiny preview instead of a
                                          // flat grey flash while the real thumbnail loads.
                                          placeholder: (context, url) => previewBytes != null
                                              ? Image.memory(previewBytes, fit: BoxFit.cover)
                                              : const ColoredBox(color: Colors.black12),
                                          errorWidget: (context, url, error) =>
                                              const ColoredBox(color: Colors.black12),
                                        )
                                      : const ColoredBox(color: Colors.black12);
                                }

                                final isSelected = _selectedIds.contains(item.id);
                                return GestureDetector(
                                  key: ValueKey(item.id),
                                  // Delete works the same way in both views -- a hidden
                                  // photo can be deleted directly here instead of having
                                  // to unhide it first.
                                  onLongPress: () => _toggleSelected(item.id),
                                  onTap: _selectionMode ? () => _toggleSelected(item.id) : null,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      tile,
                                      if (isSelected)
                                        Container(
                                          color: Colors.black45,
                                          alignment: Alignment.topRight,
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(Icons.check_circle, color: Colors.white),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
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
  const _PhotoTile({super.key, required this.bytes});

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

