import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_app/services/channel_service.dart';
import 'package:smile_app/services/membership_service.dart';
import 'package:smile_app/services/object_picture_service.dart';
import 'package:smile_app/services/space_service.dart';
import 'package:smile_app/services/upload_queue.dart';

import 'backend.dart';
import 'chapter.dart';

const anna = 'anna.berger@example.com';
const paulMail = 'paul.berger@example.com';
const lenaMail = 'lena.huber@example.com';
const tomMail = 'tom.berger@example.com';

/// What a chapter starts from: the ids it needs.
class Seed {
  Seed({required this.spaceId, required this.albums});

  final String spaceId;

  /// By name: Geburtstage, Sommerurlaub 2026, Weihnachten.
  final Map<String, String> albums;
}

/// Resets the server and the phone and signs Anna in (not part of the chapter).
Future<void> freshAnna(WidgetTester tester, Chapter c) async {
  await TestBackend.reset();
  await TestBackend.person('paul.berger@example.com', 'Paul Berger', handle: 'paul.berger');
  await TestBackend.person(anna, 'Anna Berger', handle: 'anna.berger');
  final support = (await getApplicationSupportDirectory()).path;
  await TestBackend.setAvatar(anna, await File('$support/fixtures/profiles/frau_mittel.png').readAsBytes(), 'image/png');
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await prefs.setBool('tips_enabled', false); // Tipps haben ein eigenes Kapitel.
}

/// Signs [email] in on the phone (the login screen must be showing).
Future<void> signIn(Chapter c, String email, {String screen = 'Startseite'}) async {
  c.screen('Anmeldung');
  if (!await c.waitFor('Code anfordern', seconds: 20)) throw TestFailure('Anmeldung erscheint nicht');
  await c.typeInto('E-Mail-Adresse', email);
  await c.tap('Code anfordern');
  c.screen('Code-Eingabe');
  await c.waitFor('Wir haben einen Code', seconds: 10);
  await c.typeInto('', await TestBackend.otp(email), logAs: 'Code-Kästchen');
  c.screen(screen);
}

/// The end of chapter 4, built by the app's own services as Anna (signed
/// in already): Familie Berger with a picture; Sommerurlaub 2026 (cover,
/// one photo with a title); Geburtstage (three photos, two videos, the
/// Torte mit Kerzen as its cover); Weihnachten empty.
Future<Seed> endOfChapter4(WidgetTester tester) async {
  final media = '${(await getApplicationSupportDirectory()).path}/fixtures/media';
  Future<List<Map>> items(String album) async =>
      (await TestBackend.select('media_items', 'select=id,caption,processing_status&channel_id=eq.$album&order=created_at.asc'))
          .cast<Map>();
  Future<bool> eventually(FutureOr<bool> Function() test, {double seconds = 10}) async {
    final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
    while (true) {
      if (await test()) return true;
      if (DateTime.now().isAfter(end)) return false;
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  final spaceId = await SpaceService().createSpace('Familie Berger');
  final pictures = ObjectPictureService();
  final house = (bytes: await File('$media/04_haus_mit_garten.jpg').readAsBytes(), mimeType: 'image/jpeg');
  await pictures.save(ObjectKind.space, spaceId, await pictures.uploadPicked(ObjectKind.space, spaceId, house));
  final summer = await ChannelService().createChannel(spaceId: spaceId, name: 'Sommerurlaub 2026');
  final beach = (bytes: await File('$media/26_strand_am_abend.jpg').readAsBytes(), mimeType: 'image/jpeg');
  await pictures.save(ObjectKind.album, summer, await pictures.uploadPicked(ObjectKind.album, summer, beach));
  final birthdays = await ChannelService().createChannel(spaceId: spaceId, name: 'Geburtstage');
  final christmas = await ChannelService().createChannel(spaceId: spaceId, name: 'Weihnachten');
  // One after another, as Anna sent them (the Herbstwald was deleted in chapter 4).
  for (final (file, caption) in [
    ('07_geburtstagstorte.jpg', 'Omas 80. Geburtstag'),
    ('20_luftballons.mp4', null),
    ('49_torte_mit_kerzen.jpg', null),
    ('21_obstschale.jpg', 'Obst für alle'),
    ('40_hund_laeuft.mp4', null),
  ]) {
    final n = (await items(birthdays)).length + 1;
    await UploadQueue.instance.enqueue(birthdays, [XFile('$media/$file')], captions: [caption]);
    if (!await eventually(() async => (await items(birthdays)).length >= n, seconds: 120)) {
      throw TestFailure('Senden von $file dauert zu lange');
    }
  }
  await UploadQueue.instance.enqueue(summer, [XFile('$media/26_strand_am_abend.jpg')], captions: ['Erster Abend am Meer']);
  if (!await eventually(() async => (await items(summer)).length == 1, seconds: 60)) {
    throw TestFailure('Senden in den Sommerurlaub dauert zu lange');
  }
  await eventually(
      () async => (await TestBackend.select('media_items', 'select=processing_status'))
          .every((r) => (r as Map)['processing_status'] == 'ready'),
      seconds: 120);
  final kerzen = (await items(birthdays))[2]['id'] as String;
  await pictures.setAlbumCoverPhoto(birthdays, kerzen);
  return Seed(spaceId: spaceId, albums: {'Geburtstage': birthdays, 'Sommerurlaub 2026': summer, 'Weihnachten': christmas});
}

/// The end of chapter 5, on top of [endOfChapter4] (Anna signed in):
/// Geburtstage with Anna, Lena and Tom; Lena's Space Familie Huber with
/// Wanderungen (Anna and Tom in it) and Bergtouren (Anna left again);
/// Anna's invitation to Lena for Weihnachten still open. Everyone has a
/// profile picture.
Future<Seed> endOfChapter5(WidgetTester tester) async {
  final seed = await endOfChapter4(tester);
  final support = (await getApplicationSupportDirectory()).path;
  Future<void> picture(String mail, String file) async =>
      TestBackend.setAvatar(mail, await File('$support/fixtures/profiles/$file').readAsBytes(), 'image/png');
  await picture(paulMail, 'mann_mittel.png');
  await TestBackend.person(lenaMail, 'Lena Huber', handle: 'lena.huber');
  await picture(lenaMail, 'frau_jung.png');
  await TestBackend.person(tomMail, 'Tom Berger', handle: 'tom.berger');
  await picture(tomMail, 'mann_jung.png');
  final lena = await TestUser.signIn(lenaMail);
  final tom = await TestUser.signIn(tomMail);
  final annaId = await TestBackend.userId(anna);
  final members = MembershipService();

  // Anna invites, the other one accepts (as in chapter 5).
  Future<void> accept(TestUser who, String album) async {
    final open = await who.select('channel_membership_requests', 'select=id&status=eq.pending&channel_id=eq.$album&user_id=eq.${who.id}');
    await who.patch('channel_membership_requests', 'id=eq.${open.first['id']}', {'status': 'accepted'});
  }

  final birthdays = seed.albums['Geburtstage']!;
  for (final who in [lena, tom]) {
    await members.inviteMember(channelId: birthdays, userId: who.id);
    await accept(who, birthdays);
  }
  await members.inviteMember(channelId: seed.albums['Weihnachten']!, userId: lena.id);

  final huber = (await lena.insert('spaces', {'name': 'Familie Huber'})).first['id'];
  final hiking = (await lena.insert('channels', {'space_id': huber, 'name': 'Wanderungen'})).first['id'] as String;
  await lena.insert('channels', {'space_id': huber, 'name': 'Bergtouren'});
  await lena.edge('invite-channel-member', {'channel_id': hiking, 'user_id': annaId});
  final annaInvite = (await TestBackend.select(
          'channel_membership_requests', 'select=id&status=eq.pending&channel_id=eq.$hiking&user_id=eq.$annaId'))
      .first['id'] as String;
  await members.decideMembershipRequest(annaInvite, accept: true);
  await lena.edge('invite-channel-member', {'channel_id': hiking, 'user_id': tom.id});
  await accept(tom, hiking);
  return Seed(spaceId: seed.spaceId, albums: {...seed.albums, 'Wanderungen': hiking});
}
