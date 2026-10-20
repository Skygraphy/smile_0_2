import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../main.dart' show navigatorKey;
import 'media_service.dart';

/// The test app (2026-10-19, built with --dart-define=SMILE_TEST=true): no
/// gallery and no camera, so no private photo can ever end up in a test or
/// the tutorial. Instead the test tools put free test pictures and videos
/// into the app's own folder (`Android/data/<app>/files/fixtures/`):
/// `media/` (photos and videos, with `labels.json`) and `profiles/`
/// (portraits for profile pictures). See tools/testsuite/README.md.
const bool smileTestMode = bool.fromEnvironment('SMILE_TEST');

class _TestFile {
  const _TestFile(this.file, this.label);
  final File file;
  final String label;
  bool get isVideo => file.path.toLowerCase().endsWith('.mp4');
}

Future<List<_TestFile>> _files(String folder, {required bool videos}) async {
  final base = await getExternalStorageDirectory();
  if (base == null) return const [];
  final dir = Directory('${base.path}/fixtures/$folder');
  if (!await dir.exists()) return const [];
  var labels = <String, dynamic>{};
  final labelFile = File('${dir.path}/labels.json');
  if (await labelFile.exists()) {
    try {
      labels = jsonDecode(await labelFile.readAsString()) as Map<String, dynamic>;
    } catch (_) {}
  }
  final files = await dir
      .list()
      .where((e) => e is File && RegExp(r'\.(jpe?g|png|mp4)$', caseSensitive: false).hasMatch(e.path))
      .cast<File>()
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final f in files)
      if (videos || !f.path.toLowerCase().endsWith('.mp4'))
        _TestFile(f, labels[f.uri.pathSegments.last] as String? ?? f.uri.pathSegments.last.split('.').first),
  ];
}

/// Instead of the gallery: [multiple] lets several be chosen, [videos]
/// adds the test videos, [profiles] shows the portraits instead.
Future<List<XFile>> pickTestMedia({bool multiple = true, bool videos = true, bool profiles = false}) async {
  final navigator = navigatorKey.currentState;
  if (navigator == null) return const [];
  final chosen = await navigator.push<List<XFile>>(
    MaterialPageRoute(builder: (_) => _TestMediaPage(multiple: multiple, videos: videos, profiles: profiles)),
  );
  return chosen ?? const [];
}

class _TestMediaPage extends StatefulWidget {
  const _TestMediaPage({required this.multiple, required this.videos, required this.profiles});

  final bool multiple;
  final bool videos;
  final bool profiles;

  @override
  State<_TestMediaPage> createState() => _TestMediaPageState();
}

class _TestMediaPageState extends State<_TestMediaPage> {
  late final Future<List<_TestFile>> _list = () async {
    if (widget.profiles) {
      final portraits = await _files('profiles', videos: false);
      if (portraits.isNotEmpty) return portraits;
    }
    return _files('media', videos: widget.videos);
  }();
  final _selected = <String>[];
  final _posters = <String, Future<Uint8List?>>{};

  void _tap(_TestFile f) {
    if (!widget.multiple) {
      Navigator.of(context).pop([XFile(f.file.path)]);
      return;
    }
    setState(() => _selected.contains(f.file.path) ? _selected.remove(f.file.path) : _selected.add(f.file.path));
  }

  Widget _tile(_TestFile f) {
    final Widget picture = f.isVideo
        ? FutureBuilder<Uint8List?>(
            future: _posters.putIfAbsent(f.file.path, () => MediaService.videoPosterBytes(f.file)),
            builder: (context, snap) => snap.data == null
                ? Container(color: const Color(0xFF263238))
                : Image.memory(snap.data!, fit: BoxFit.cover, gaplessPlayback: true),
          )
        : Image.file(f.file, fit: BoxFit.cover, cacheWidth: 300);
    return Semantics(
      label: f.label,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _tap(f),
        child: Stack(
          fit: StackFit.expand,
          children: [
            picture,
            if (f.isVideo) const Center(child: Icon(SmileIcons.playFilled, color: Colors.white, size: 34)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(f.label,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
              ),
            ),
            if (_selected.contains(f.file.path))
              Container(
                color: Colors.black45,
                alignment: Alignment.center,
                child: CircleAvatar(
                  backgroundColor: SmileTheme.primary,
                  child: Text('${_selected.indexOf(f.file.path) + 1}'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.profiles ? 'Testporträts' : 'Testbilder')),
      body: FutureBuilder<List<_TestFile>>(
        future: _list,
        builder: (context, snapshot) {
          final files = snapshot.data;
          if (files == null) return const Center(child: CircularProgressIndicator());
          if (files.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Keine Testbilder auf diesem Gerät. Die Test-Werkzeuge legen sie an.', textAlign: TextAlign.center),
              ),
            );
          }
          return GridView.count(
            crossAxisCount: 3,
            padding: const EdgeInsets.all(4),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [for (final f in files) _tile(f)],
          );
        },
      ),
      bottomNavigationBar: widget.multiple
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop([for (final p in _selected) XFile(p)]),
                  child: Text('Auswählen (${_selected.length})'),
                ),
              ),
            )
          : null,
    );
  }
}
