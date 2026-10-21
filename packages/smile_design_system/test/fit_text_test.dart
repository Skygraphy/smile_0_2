import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_design_system/smile_design_system.dart';

void main() {
  Future<Text> fitted(WidgetTester tester, String text, double width) async {
    await tester.pumpWidget(MaterialApp(
      home: Center(child: SizedBox(width: width, child: SmileFitText(text, style: const TextStyle(fontSize: 20)))),
    ));
    return tester.widget<Text>(find.byType(Text));
  }

  testWidgets('a name that fits keeps its size', (tester) async {
    expect((await fitted(tester, 'Urlaub', 300)).style!.fontSize, 20);
  });

  testWidgets('a longer name gets smaller before it is cut', (tester) async {
    final size = (await fitted(tester, 'Sommerurlaub 2026 am Meer', 260)).style!.fontSize!;
    expect(size, lessThan(20));
    expect(size, greaterThanOrEqualTo(15));
  });

  testWidgets('a far too long name stops at three quarters and ends in …', (tester) async {
    final text = await fitted(tester, 'Ein sehr, sehr langer Name für ein Album, der nie passt', 120);
    expect(text.style!.fontSize, 15);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
