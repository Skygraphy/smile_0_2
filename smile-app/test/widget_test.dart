import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_design_system/smile_design_system.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smile_app/screens/login_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_test',
    );
  });

  testWidgets('LoginScreen shows the email step by default', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('de'),
      localizationsDelegates: SmileTexts.localizationsDelegates,
      supportedLocales: SmileTexts.supportedLocales,
      home: LoginScreen(),
    ));

    expect(find.text('E-Mail-Adresse'), findsOneWidget);
    expect(find.text('Code anfordern'), findsOneWidget);
  });
}
