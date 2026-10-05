import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_app/services/news_service.dart';
import 'package:smile_app/widgets/top_bar_actions.dart';
import 'package:smile_design_system/smile_design_system.dart';

class _FakeNewsService implements NewsService {
  _FakeNewsService(this.pending);

  final bool pending;

  @override
  Future<bool> hasPendingForMe() async => pending;
}

Widget _host(Widget child) => MaterialApp(
      theme: SmileTheme.themeData,
      locale: const Locale('de'),
      localizationsDelegates: SmileTexts.localizationsDelegates,
      supportedLocales: SmileTexts.supportedLocales,
      home: Scaffold(appBar: AppBar(actions: [child])),
    );

Color? _newsIconColor(WidgetTester tester) =>
    tester.widget<Icon>(find.byIcon(SmileIcons.news)).color;

void main() {
  testWidgets('Neuigkeiten icon turns coral only while something waits', (tester) async {
    await tester.pumpWidget(_host(NewsButton(newsService: _FakeNewsService(true))));
    await tester.pump();
    expect(_newsIconColor(tester), SmileTheme.primary);
    expect(find.byTooltip('Neuigkeiten, es wartet etwas auf dich'), findsOneWidget);

    await tester.pumpWidget(_host(NewsButton(key: UniqueKey(), newsService: _FakeNewsService(false))));
    await tester.pump();
    expect(_newsIconColor(tester), isNull);
    expect(find.byTooltip('Neuigkeiten'), findsOneWidget);
  });
}
