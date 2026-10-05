// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'smile_texts.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class SmileTextsDe extends SmileTexts {
  SmileTextsDe([String locale = 'de']) : super(locale);

  @override
  String get space => 'Space';

  @override
  String get spaces => 'Spaces';

  @override
  String spaceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Spaces',
      one: '1 Space',
    );
    return '$_temp0';
  }

  @override
  String get album => 'Album';

  @override
  String get albums => 'Alben';

  @override
  String albumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Alben',
      one: '1 Album',
    );
    return '$_temp0';
  }

  @override
  String get frame => 'Frame';

  @override
  String get frames => 'Frames';

  @override
  String frameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Frames',
      one: '1 Frame',
    );
    return '$_temp0';
  }

  @override
  String get person => 'Person';

  @override
  String get persons => 'Personen';

  @override
  String personCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen',
      one: '1 Person',
    );
    return '$_temp0';
  }

  @override
  String get profile => 'Profil';

  @override
  String get you => 'Du';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleCoAdmin => 'Co-Admin';

  @override
  String get roleMember => 'Member';

  @override
  String get roleViewer => 'Viewer';

  @override
  String get admins => 'Admins';

  @override
  String get sharedWith => 'Shared with';

  @override
  String sharedWithSpace(String space) {
    return 'Shared with $space';
  }

  @override
  String get news => 'Neuigkeiten';

  @override
  String get newsWaiting => 'Neuigkeiten, es wartet etwas auf dich';

  @override
  String get actionSendPhoto => 'Foto senden';

  @override
  String get actionInvite => 'Einladen';

  @override
  String get actionShare => 'Mit Space teilen';

  @override
  String get actionAdd => 'Neu anlegen';

  @override
  String get actionRemove => 'Entfernen';

  @override
  String get actionLeave => 'Verlassen';

  @override
  String get actionDelete => 'Löschen';

  @override
  String get actionRestore => 'Wiederherstellen';

  @override
  String get actionHandOver => 'Admin übergeben';

  @override
  String get actionInviteCode => 'Einladungscode';

  @override
  String get actionConnect => 'Verbinden';

  @override
  String get actionCancel => 'Abbrechen';

  @override
  String get actionConfirm => 'OK';

  @override
  String get firstStepsWelcome => 'Willkommen bei Smile';

  @override
  String get firstStepsInvited => 'Ich wurde eingeladen';

  @override
  String get firstStepsInvitedHint => 'Code eingeben oder QR-Code scannen';

  @override
  String get firstStepsSetup => 'Ich richte Smile ein';

  @override
  String get firstStepsSetupHint =>
      'Space für dein Zuhause oder deinen Betrieb anlegen';

  @override
  String albumsLoadError(String error) {
    return 'Alben konnten nicht geladen werden: $error';
  }

  @override
  String get albumsEmptyTitle => 'Noch keine Alben';

  @override
  String get albumsEmptyMessage =>
      'Lege einen Space an oder nimm eine Einladung an.';

  @override
  String get openSpaces => 'Spaces öffnen';

  @override
  String get albumInfo => 'Infos zum Album';

  @override
  String get addMedia => 'Foto oder Video teilen';

  @override
  String get feedEmptyTitle => 'Noch keine Fotos';

  @override
  String get feedEmptyMemberHint =>
      'Tippe auf +, um das erste Foto oder Video zu teilen.';

  @override
  String get hiddenPhotos => 'Ausgeblendete Fotos';

  @override
  String get hiddenPhotosEmpty => 'Keine ausgeblendeten Fotos';

  @override
  String get actionHide => 'Ausblenden';

  @override
  String get actionUnhide => 'Einblenden';

  @override
  String selectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String get requestMembership => 'Member werden';

  @override
  String get requestSent => 'Anfrage gesendet';

  @override
  String get sendTo => 'Senden an …';

  @override
  String get sendToNoAlbum =>
      'Du bist noch in keinem Album, in dem du Fotos teilen kannst.';

  @override
  String albumInSpace(String space) {
    return 'Album in $space';
  }

  @override
  String get rename => 'Umbenennen';

  @override
  String get renameAlbum => 'Album umbenennen';

  @override
  String get name => 'Name';

  @override
  String get save => 'Speichern';

  @override
  String get inviteToAlbum => 'Person einladen';

  @override
  String get inviteToAlbumHint =>
      'Die Person braucht bereits einen Smile-Account. Sie kann die Einladung annehmen oder ablehnen.';

  @override
  String get shareWithSpace => 'Mit einem Space teilen';

  @override
  String get shareWithSpaceHint =>
      'Ein Admin des anderen Space kann annehmen. Dessen Personen und Frames sehen das Album dann, tragen aber nichts bei.';

  @override
  String get emailOfAdmin => 'E-Mail-Adresse';

  @override
  String get invitedWaiting => 'Eingeladen · Annahme ausstehend';

  @override
  String get wantsToJoin => 'Möchte Member werden';

  @override
  String get wantsToShare => 'Möchte das Album mit dem eigenen Space sehen';

  @override
  String get sharedViewOnly => 'Sieht das Album, trägt nichts bei';

  @override
  String get notSharedYet => 'Noch mit keinem anderen Space geteilt';

  @override
  String get showsOn => 'Läuft auf';

  @override
  String get notOnAnyFrame => 'Noch auf keinem Frame';

  @override
  String get removeFromAlbum => 'Aus dem Album entfernen';

  @override
  String removePersonTitle(String name) {
    return '$name entfernen?';
  }

  @override
  String get removePersonMessage =>
      'Die Person verliert den Zugriff auf dieses Album.';

  @override
  String get endShare => 'Freigabe beenden';

  @override
  String endShareTitle(String space) {
    return 'Freigabe für „$space“ beenden?';
  }

  @override
  String endShareMessage(String space, String album) {
    return '„$space“ sieht „$album“ danach nicht mehr, auch nicht auf seinen Frames.';
  }

  @override
  String get leaveAlbum => 'Album verlassen';

  @override
  String get leaveAlbumMessage =>
      'Du siehst die Fotos dieses Albums danach nicht mehr.';

  @override
  String get deleteAlbum => 'Album löschen';

  @override
  String deleteAlbumTitle(String album) {
    return 'Album „$album“ löschen?';
  }

  @override
  String get deleteAlbumMessage =>
      'Das Album verschwindet mit allen Fotos sofort für alle Personen und von allen Frames. 30 Tage lang kannst du es im Papierkorb wiederherstellen.';

  @override
  String albumInfoLoadError(String error) {
    return 'Album-Infos konnten nicht geladen werden: $error';
  }

  @override
  String actionFailed(String error) {
    return 'Aktion fehlgeschlagen: $error';
  }

  @override
  String get actionAccept => 'Annehmen';

  @override
  String get actionDecline => 'Ablehnen';

  @override
  String get actionWithdraw => 'Zurückziehen';
}
