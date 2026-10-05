import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_app/screens/channels_home_screen.dart';
import 'package:smile_app/services/channel_picker_service.dart';
import 'package:smile_design_system/smile_design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _NoAlbums implements ChannelPickerService {
  @override
  Future<List<ChannelWithActivity>> listMyChannelsWithActivity() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: 'https://example.supabase.co', publishableKey: 'sb_publishable_test');
  });

  testWidgets('an empty album list offers the two ways in (decision 6)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: SmileTheme.themeData,
      locale: const Locale('de'),
      localizationsDelegates: SmileTexts.localizationsDelegates,
      supportedLocales: SmileTexts.supportedLocales,
      home: ChannelsHomeScreen(channelPickerService: _NoAlbums()),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Willkommen bei Smile'), findsOneWidget);
    expect(find.text('Ich wurde eingeladen'), findsOneWidget);
    expect(find.text('Deine Einladung findest du unter Neuigkeiten'), findsOneWidget);
    expect(find.text('Ich richte Smile ein'), findsOneWidget);
  });
}
