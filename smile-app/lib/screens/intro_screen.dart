import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

/// The short introduction after the very first sign-in (Ernst 2026-11-05):
/// three pages -- Alben, Spaces, Frames -- to swipe, "Überspringen" any
/// time. Again from Einstellungen ("Einführung ansehen").
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pages = [
      (const _AlbumsArt(), t.introAlbumsTitle, t.introAlbumsText),
      (const Icon(_house, size: 76, color: SmileTheme.primary), t.introSpacesTitle, t.introSpacesText),
      (const _FrameArt(), t.introFramesTitle, t.introFramesText),
    ];
    final last = _index == pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(SmileSpacing.l, SmileSpacing.s, SmileSpacing.l, SmileSpacing.l),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Opacity(
                  opacity: last ? 0 : 1,
                  child: TextButton(
                    onPressed: last ? null : widget.onDone,
                    style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
                    child: Text(t.introSkip),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    for (final (art, title, text) in pages)
                      Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: Container(
                                width: 190,
                                height: 190,
                                decoration: const BoxDecoration(color: SmileTheme.primaryContainer, shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: art,
                              ),
                            ),
                          ),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: SmileSpacing.m),
                          SizedBox(
                            height: 96,
                            child: Text(
                              text,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, height: 1.5, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? scheme.primary : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: SmileSpacing.l),
              SizedBox(
                width: double.infinity,
                child: last
                    ? FilledButton(onPressed: widget.onDone, child: Text(t.introStart))
                    : FilledButton.tonal(
                        onPressed: () => _pages.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut),
                        child: Text(t.introNext),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phosphor `house`.
const _house = IconData(0xe2c2, fontFamily: 'PhosphorRegular', fontPackage: 'smile_design_system');

/// Two photo bubbles, like in an album.
class _AlbumsArt extends StatelessWidget {
  const _AlbumsArt();

  @override
  Widget build(BuildContext context) {
    Widget bubble(Color frame, List<Color> photo) => Container(
          width: 78,
          height: 58,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: frame, borderRadius: BorderRadius.circular(12)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: LinearGradient(colors: photo, begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
        );
    return SizedBox(
      width: 150,
      height: 120,
      child: Stack(
        children: [
          Positioned(left: 0, top: 4, child: bubble(const Color(0xFF262626), const [Color(0xFF8FC3E0), Color(0xFF3D6D8F)])),
          Positioned(right: 0, bottom: 4, child: bubble(const Color(0xFFC9574C), const [Color(0xFFF2C58A), Color(0xFFB7643F)])),
        ],
      ),
    );
  }
}

/// A tablet showing a photo.
class _FrameArt extends StatelessWidget {
  const _FrameArt();

  @override
  Widget build(BuildContext context) => Container(
        width: 128,
        height: 86,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF111111), width: 7),
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFFE9B98D), Color(0xFFB0623F), Color(0xFF4F6D4A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
}
