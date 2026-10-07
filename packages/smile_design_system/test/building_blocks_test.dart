import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_design_system/smile_design_system.dart';

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: SmileTexts.localizationsDelegates,
      supportedLocales: SmileTexts.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('role badges show the decided icon and German label', (tester) async {
    await tester.pumpWidget(_host(const Column(children: [
      SmileRoleBadge(role: SmileRole.admin),
      SmileRoleBadge(role: SmileRole.coAdmin),
      SmileRoleBadge(role: SmileRole.member),
      SmileRoleBadge(role: SmileRole.viewer),
    ])));
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Co-Admin'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
    expect(find.text('Viewer'), findsOneWidget);
    expect(find.byIcon(SmileIcons.admin), findsOneWidget);
    expect(find.byIcon(SmileIcons.coAdmin), findsOneWidget);
    expect(find.byIcon(SmileIcons.member), findsOneWidget);
    expect(find.byIcon(SmileIcons.viewer), findsOneWidget);
  });

  testWidgets('icon-only badge keeps the label for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(const SmileRoleBadge(role: SmileRole.viewer, showLabel: false)));
    expect(find.text('Viewer'), findsNothing);
    expect(find.bySemanticsLabel('Viewer'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('object tile shows title, subtitle with icon, trailing and taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(SmileObjectTile(
      leading: const SmileObjectIcon(icon: SmileIcons.album),
      title: 'Enkelkinder',
      subtitle: 'Roman: Foto',
      subtitleIcon: SmileIcons.member,
      trailing: const Text('12:04'),
      onTap: () => taps++,
    )));
    expect(find.text('Enkelkinder'), findsOneWidget);
    expect(find.text('Roman: Foto'), findsOneWidget);
    expect(find.byIcon(SmileIcons.album), findsOneWidget);
    expect(find.byIcon(SmileIcons.member), findsOneWidget);
    await tester.tap(find.text('Enkelkinder'));
    expect(taps, 1);
  });

  testWidgets('empty state shows its single action only with a callback', (tester) async {
    var pressed = false;
    await tester.pumpWidget(_host(SmileEmptyState(
      icon: SmileIcons.frame,
      title: 'Noch kein Frame',
      actionLabel: 'Verbinden',
      actionIcon: SmileIcons.add,
      onAction: () => pressed = true,
    )));
    await tester.tap(find.text('Verbinden'));
    expect(pressed, isTrue);

    await tester.pumpWidget(_host(const SmileEmptyState(
      icon: SmileIcons.frame,
      title: 'Noch kein Frame',
      actionLabel: 'Verbinden',
    )));
    expect(find.text('Verbinden'), findsNothing);
  });

  testWidgets('confirm dialog returns true on confirm and false on cancel', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(_host(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    var result = showSmileConfirmDialog(ctx, title: 'Album löschen?', confirmLabel: 'Löschen', destructive: true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);

    result = showSmileConfirmDialog(ctx, title: 'Album löschen?', confirmLabel: 'Löschen');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('terms use the decided words and German plurals', (tester) async {
    late SmileTexts t;
    await tester.pumpWidget(_host(Builder(builder: (c) {
      t = SmileTexts.of(c);
      return const SizedBox();
    })));
    expect(t.album, 'Album');
    expect(t.albums, 'Alben');
    expect(t.albumCount(1), '1 Album');
    expect(t.albumCount(3), '3 Alben');
    expect(t.personCount(4), '4 Personen');
    expect(t.sharedWithSpace('Davidopa'), 'Shared with Davidopa');
    expect(t.news, 'Neuigkeiten');
  });

  test("initials take the first two letters of the name", () {
    expect(smileInitialsOf("Enkelkinder"), "EN");
    expect(smileInitialsOf("Urlaub 2026"), "UR");
    expect(smileInitialsOf("Live-Test"), "LI");
    expect(smileInitialsOf("Küche"), "KÜ");
  });

  testWidgets("an album without a photo shows its initials", (tester) async {
    await tester.pumpWidget(_host(const SmileAlbumCover(name: "Live-Test")));
    expect(find.text("LI"), findsOneWidget);
  });
}
