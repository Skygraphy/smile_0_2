import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../main.dart' show navigatorKey;

/// The test app (2026-10-19, built with --dart-define=SMILE_TEST=true): no
/// gallery and no camera, so no private photo can ever end up in a test or
/// the tutorial. Instead a page of made-up pictures ("Testbild 1" to 12,
/// always the same), plus test videos the test tools put into the app's
/// own folder (`Android/data/<app>/files/fixtures/*.mp4`).
const bool smileTestMode = bool.fromEnvironment('SMILE_TEST');

const _count = 12;

/// Colors and a shape per picture, fixed, so screenshots stay comparable.
const _palette = <(Color, Color)>[
  (Color(0xFFFF8A65), Color(0xFF6D2F2A)),
  (Color(0xFF4FC3F7), Color(0xFF1A3D5C)),
  (Color(0xFF81C784), Color(0xFF234A2A)),
  (Color(0xFFFFD54F), Color(0xFF6B4B12)),
  (Color(0xFFBA68C8), Color(0xFF3E1F48)),
  (Color(0xFF4DB6AC), Color(0xFF14403B)),
  (Color(0xFFF06292), Color(0xFF5A1B33)),
  (Color(0xFF9575CD), Color(0xFF2C2350)),
  (Color(0xFFAED581), Color(0xFF3A4A17)),
  (Color(0xFFFFB74D), Color(0xFF5E3410)),
  (Color(0xFF64B5F6), Color(0xFF173A63)),
  (Color(0xFFE57373), Color(0xFF4F1D1D)),
];

/// Every third picture is upright, the others lie: both shapes get tested.
bool _upright(int n) => n % 3 == 0;

Future<File> _picture(int n) async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/test_media');
  await dir.create(recursive: true);
  final file = File('${dir.path}/testbild_${n.toString().padLeft(2, '0')}.png');
  if (await file.exists()) return file;

  final w = _upright(n) ? 1200.0 : 1600.0;
  final h = _upright(n) ? 1600.0 : 1200.0;
  final (light, dark) = _palette[(n - 1) % _palette.length];
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(w, h), [light, dark]),
  );
  // A simple shape per picture: circle, square or triangle.
  final shape = Paint()..color = Colors.white.withValues(alpha: 0.28);
  final c = Offset(w / 2, h * 0.42);
  switch (n % 3) {
    case 1:
      canvas.drawCircle(c, w * 0.22, shape);
    case 2:
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w * 0.4, height: w * 0.4), const Radius.circular(40)), shape);
    default:
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - w * 0.24)
          ..lineTo(c.dx + w * 0.24, c.dy + w * 0.18)
          ..lineTo(c.dx - w * 0.24, c.dy + w * 0.18)
          ..close(),
        shape,
      );
  }
  void text(String s, double size, double y, {FontWeight weight = FontWeight.w700}) {
    final p = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: Colors.white, fontSize: size, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w);
    p.paint(canvas, Offset((w - p.width) / 2, y - p.height / 2));
  }

  text('$n', w * 0.26, h * 0.42);
  text('Testbild $n', w * 0.06, h * 0.82, weight: FontWeight.w600);
  final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  await file.writeAsBytes(png!.buffer.asUint8List());
  return file;
}

Future<List<File>> _videos() async {
  final base = await getExternalStorageDirectory();
  if (base == null) return const [];
  final dir = Directory('${base.path}/fixtures');
  if (!await dir.exists()) return const [];
  final files = await dir.list().where((e) => e is File && e.path.toLowerCase().endsWith('.mp4')).cast<File>().toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// Instead of the gallery: [multiple] lets several be chosen, [videos]
/// adds the test videos.
Future<List<XFile>> pickTestMedia({bool multiple = true, bool videos = true}) async {
  final navigator = navigatorKey.currentState;
  if (navigator == null) return const [];
  final chosen = await navigator.push<List<XFile>>(
    MaterialPageRoute(builder: (_) => _TestMediaPage(multiple: multiple, videos: videos)),
  );
  return chosen ?? const [];
}

class _TestMediaPage extends StatefulWidget {
  const _TestMediaPage({required this.multiple, required this.videos});

  final bool multiple;
  final bool videos;

  @override
  State<_TestMediaPage> createState() => _TestMediaPageState();
}

class _TestMediaPageState extends State<_TestMediaPage> {
  late final Future<List<File>> _files = () async {
    return [
      for (var n = 1; n <= _count; n++) await _picture(n),
      if (widget.videos) ...await _videos(),
    ];
  }();
  final _selected = <String>[];

  void _tap(File f) {
    if (!widget.multiple) {
      Navigator.of(context).pop([XFile(f.path)]);
      return;
    }
    setState(() => _selected.contains(f.path) ? _selected.remove(f.path) : _selected.add(f.path));
  }

  String _label(File f) {
    final name = f.path.split(Platform.pathSeparator).last;
    final m = RegExp(r'testbild_(\d+)').firstMatch(name);
    return m != null ? 'Testbild ${int.parse(m.group(1)!)}' : 'Testvideo ${name.replaceAll('.mp4', '')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Testbilder')),
      body: FutureBuilder<List<File>>(
        future: _files,
        builder: (context, snapshot) {
          final files = snapshot.data;
          if (files == null) return const Center(child: CircularProgressIndicator());
          return GridView.count(
            crossAxisCount: 3,
            padding: const EdgeInsets.all(4),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (final f in files)
                Semantics(
                  label: _label(f),
                  button: true,
                  child: GestureDetector(
                    onTap: () => _tap(f),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (f.path.endsWith('.png'))
                          Image.file(f, fit: BoxFit.cover, cacheWidth: 300)
                        else
                          Container(
                            color: const Color(0xFF263238),
                            alignment: Alignment.center,
                            child: Text(_label(f), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                          ),
                        if (_selected.contains(f.path))
                          Container(
                            color: Colors.black45,
                            alignment: Alignment.center,
                            child: CircleAvatar(
                              backgroundColor: SmileTheme.primary,
                              child: Text('${_selected.indexOf(f.path) + 1}'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
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
