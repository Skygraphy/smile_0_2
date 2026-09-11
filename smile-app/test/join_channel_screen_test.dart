import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smile_app/screens/join_channel_screen.dart';
import 'package:smile_app/services/membership_service.dart';

class MockMembershipService extends Mock implements MembershipService {}

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });

  Future<void> pumpAndSubmit(WidgetTester tester, MockMembershipService service, String code) async {
    await tester.pumpWidget(MaterialApp(home: JoinChannelScreen(membershipService: service)));
    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.text('Beitreten'));
    await tester.pumpAndSettle();
  }

  testWidgets('joined shows the immediate-membership message', (tester) async {
    final service = MockMembershipService();
    when(() => service.joinChannelWithCode(any())).thenAnswer(
      (_) async => ChannelJoinResult(status: ChannelJoinStatus.joined, channelId: 'c1', channelName: 'Enkelkinder'),
    );

    await pumpAndSubmit(tester, service, 'ABCD1234');

    expect(find.text('Du bist jetzt Mitglied von "Enkelkinder".'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('already_member shows the already-a-member message', (tester) async {
    final service = MockMembershipService();
    when(() => service.joinChannelWithCode(any())).thenAnswer(
      (_) async =>
          ChannelJoinResult(status: ChannelJoinStatus.alreadyMember, channelId: 'c1', channelName: 'Enkelkinder'),
    );

    await pumpAndSubmit(tester, service, 'ABCD1234');

    expect(find.text('Du bist bereits Mitglied von "Enkelkinder".'), findsOneWidget);
  });

  testWidgets('pending_approval shows the awaiting-admin message with an hourglass', (tester) async {
    final service = MockMembershipService();
    when(() => service.joinChannelWithCode(any())).thenAnswer(
      (_) async =>
          ChannelJoinResult(status: ChannelJoinStatus.pendingApproval, channelId: 'c1', channelName: 'Enkelkinder'),
    );

    await pumpAndSubmit(tester, service, 'ABCD1234');

    expect(
      find.text('Deine Anfrage für "Enkelkinder" wurde gesendet -- ein Admin muss sie noch bestätigen.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
  });

  testWidgets('shows a translated error message on failure', (tester) async {
    final service = MockMembershipService();
    when(() => service.joinChannelWithCode(any())).thenThrow(ChannelInviteException('code_expired'));

    await pumpAndSubmit(tester, service, 'EXPIRED1');

    expect(find.text('Der Code ist abgelaufen.'), findsOneWidget);
  });
}
