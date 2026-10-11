import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import 'frame_mode.dart';
import 'screens/slideshow_screen.dart';

/// The app while this device is a Frame (FrameMode): only the slideshow,
/// as the former Smile-Frame app showed it. Unpaired, it becomes the
/// normal Smile app again.
class FrameModeApp extends StatelessWidget {
  const FrameModeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smile',
      debugShowCheckedModeBanner: false,
      theme: SmileTheme.themeData,
      locale: const Locale('de'),
      localizationsDelegates: SmileTexts.localizationsDelegates,
      supportedLocales: SmileTexts.supportedLocales,
      home: SlideshowScreen(onUnpaired: FrameMode.leave),
    );
  }
}
