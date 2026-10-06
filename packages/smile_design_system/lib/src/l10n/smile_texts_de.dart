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
  String get firstStepsInvitedHint =>
      'Deine Einladung findest du unter Neuigkeiten';

  @override
  String get firstStepsSetup => 'Ich richte Smile ein';

  @override
  String get firstStepsSetupHint =>
      'Space für dein Zuhause oder deinen Betrieb anlegen';

  @override
  String get firstStepsQuestion =>
      'Hier erscheinen deine Alben. Wie möchtest du anfangen?';

  @override
  String firstStepsYourEmail(String email) {
    return 'Eingeladen wirst du über deine E-Mail-Adresse $email';
  }

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

  @override
  String spacesLoadError(String error) {
    return 'Spaces konnten nicht geladen werden: $error';
  }

  @override
  String get spacesEmptyTitle => 'Noch kein eigener Space';

  @override
  String get spacesEmptyMessage =>
      'Einen Space brauchst du nur, wenn du selbst Frames aufstellst oder Alben verwaltest, für dein Zuhause oder deinen Betrieb.';

  @override
  String get createSpace => 'Space anlegen';

  @override
  String get createSpaceHint =>
      'Name, z. B. „Familie Müller“ oder „Hotel Sacher“';

  @override
  String get create => 'Anlegen';

  @override
  String get youAreAdmin => 'Du bist Admin';

  @override
  String get youAreCoAdmin => 'Du bist Co-Admin';

  @override
  String get renameSpace => 'Space umbenennen';

  @override
  String spaceInfoLoadError(String error) {
    return 'Space-Infos konnten nicht geladen werden: $error';
  }

  @override
  String get createAlbum => 'Album anlegen';

  @override
  String get createAlbumHint => 'Name, z. B. „Enkelkinder“ oder „Lobby“';

  @override
  String get noAlbumYet => 'Noch kein Album';

  @override
  String get sharedIntoSpace => 'Mit diesem Space geteilt';

  @override
  String get sharedIntoSpaceHint =>
      'Alben anderer Spaces, die hier nur angesehen werden';

  @override
  String get stopShowing => 'Nicht mehr anzeigen';

  @override
  String stopShowingTitle(String album) {
    return '„$album“ nicht mehr anzeigen?';
  }

  @override
  String get stopShowingMessage =>
      'Dieser Space und seine Frames sehen das Album danach nicht mehr.';

  @override
  String get noFrameYet => 'Noch kein Frame';

  @override
  String get connectFrame => 'Frame verbinden';

  @override
  String get frameActive => 'Aktiv';

  @override
  String get framePending => 'Wartet auf Kopplung';

  @override
  String get frameRevoked => 'Widerrufen';

  @override
  String get inviteCoAdmin => 'Co-Admin einladen';

  @override
  String get inviteCoAdminHint =>
      'Die Person braucht bereits einen Smile-Account. Nimmt sie an, verwaltet sie diesen Space mit allen Rechten außer Löschen.';

  @override
  String get makeAdmin => 'Zum Admin machen';

  @override
  String makeAdminTitle(String name) {
    return '$name zum Admin machen?';
  }

  @override
  String get makeAdminMessage =>
      'Diese Person wird Admin dieses Space. Du bleibst Co-Admin mit allen Rechten, entscheidest aber nicht mehr allein, wer mitverwaltet.';

  @override
  String get chooseNewAdmin => 'Wer soll Admin werden?';

  @override
  String get removeCoAdmin => 'Als Co-Admin entfernen';

  @override
  String removeCoAdminTitle(String name) {
    return '$name als Co-Admin entfernen?';
  }

  @override
  String get removeCoAdminMessage =>
      'Die Person verliert die Verwaltungsrechte über diesen Space.';

  @override
  String get stepDown => 'Co-Admin-Rolle abgeben';

  @override
  String get stepDownMessage =>
      'Du verlierst deine Verwaltungsrechte über diesen Space.';

  @override
  String get trashTitle => 'Papierkorb';

  @override
  String get deleteSpace => 'Space löschen';

  @override
  String deleteSpaceTitle(String space) {
    return 'Space „$space“ löschen?';
  }

  @override
  String get deleteSpaceMessage =>
      'Der Space verschwindet mit allen Alben, Fotos und Frames sofort für alle; alle Beteiligten werden benachrichtigt. 30 Tage lang kannst du ihn im Papierkorb wiederherstellen.';

  @override
  String inTrash(String name) {
    return '„$name“ ist im Papierkorb.';
  }

  @override
  String frameInfoLoadError(String error) {
    return 'Frame-Infos konnten nicht geladen werden: $error';
  }

  @override
  String frameInSpace(String space) {
    return 'Frame in $space';
  }

  @override
  String get renameFrame => 'Frame umbenennen';

  @override
  String get status => 'Status';

  @override
  String get device => 'Gerät';

  @override
  String get lastSeen => 'Zuletzt gesehen';

  @override
  String get appVersion => 'App-Version';

  @override
  String get battery => 'Akku';

  @override
  String get charging => 'lädt';

  @override
  String get settings => 'Einstellungen';

  @override
  String get videoSound => 'Videos mit Ton';

  @override
  String get videoSoundHint => 'Aus: Videos laufen auf diesem Frame stumm.';

  @override
  String get albumSwitch => 'Album-Wechsel erlauben';

  @override
  String get albumSwitchHint =>
      'Wer vor dem Frame steht, kann selbst zwischen den Alben wechseln.';

  @override
  String get showsAlbums => 'Zeigt';

  @override
  String get noAlbumAssigned => 'Noch kein Album zugewiesen';

  @override
  String get addAlbumToFrame => 'Album hinzufügen';

  @override
  String get noMoreAlbums =>
      'Es gibt keine weiteren Alben, die dieser Space sehen kann.';

  @override
  String get close => 'Schließen';

  @override
  String get removeFromFrame => 'Vom Frame entfernen';

  @override
  String get revokeFrame => 'Frame widerrufen';

  @override
  String get revokeFrameMessage =>
      'Der Frame verliert sofort jeden Zugriff und löscht seine Fotos. Du kannst ihn jederzeit wieder aktivieren.';

  @override
  String get reactivateFrame => 'Frame wieder aktivieren';

  @override
  String get newsEmptyTitle => 'Keine Neuigkeiten';

  @override
  String get newsEmptyMessage =>
      'Hier erscheinen Einladungen, Anfragen und gelöschte Alben oder Spaces.';

  @override
  String newsLoadError(String error) {
    return 'Neuigkeiten konnten nicht geladen werden: $error';
  }

  @override
  String get invitations => 'Einladungen';

  @override
  String get requests => 'Anfragen';

  @override
  String get myRequests => 'Eigene Anfragen';

  @override
  String inviteCoAdminFrom(String name) {
    return '$name lädt dich als Co-Admin ein';
  }

  @override
  String inviteMemberFrom(String name) {
    return '$name lädt dich als Member ein';
  }

  @override
  String inviteShareFrom(String name) {
    return '$name möchte das Album mit deinem Space teilen';
  }

  @override
  String requestMemberFrom(String name) {
    return '$name möchte Member werden';
  }

  @override
  String requestShareFrom(String name) {
    return '$name möchte das Album mit dem eigenen Space sehen';
  }

  @override
  String get waitingForAnswer => 'Wartet auf Antwort';

  @override
  String acceptedCoAdmin(String space) {
    return 'Du verwaltest jetzt „$space“ mit.';
  }

  @override
  String acceptedAlbum(String album) {
    return '„$album“ ist jetzt in deinen Alben.';
  }

  @override
  String acceptedShare(String album) {
    return '„$album“ ist jetzt mit deinem Space geteilt.';
  }

  @override
  String get requestAccepted => 'Anfrage angenommen.';

  @override
  String get needOwnSpace =>
      'Du brauchst zuerst einen eigenen Space, um ein geteiltes Album anzunehmen.';

  @override
  String get chooseSpace => 'Mit welchem Space?';

  @override
  String get trashEmpty => 'Der Papierkorb ist leer.';

  @override
  String trashLoadError(String error) {
    return 'Papierkorb konnte nicht geladen werden: $error';
  }

  @override
  String trashSpaceIn(String space) {
    return 'in $space';
  }

  @override
  String trashDeletedBy(String name) {
    return 'gelöscht von $name';
  }

  @override
  String trashGoneOn(String date) {
    return 'endgültig weg am $date';
  }

  @override
  String restored(String name) {
    return '„$name“ ist wiederhergestellt.';
  }

  @override
  String profileLoadError(String error) {
    return 'Profil konnte nicht geladen werden: $error';
  }

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get changeName => 'Name ändern';

  @override
  String nameSaveError(String error) {
    return 'Name konnte nicht gespeichert werden: $error';
  }

  @override
  String avatarUploadError(String error) {
    return 'Bild konnte nicht hochgeladen werden: $error';
  }

  @override
  String get changePicture => 'Profilbild ändern';

  @override
  String get viewPicture => 'Profilbild ansehen';

  @override
  String get takePhoto => 'Foto aufnehmen';

  @override
  String get choosePicture => 'Vorhandenes Bild wählen';

  @override
  String get pictureFromWeb => 'Von einer Internetadresse laden';

  @override
  String get pictureUrl => 'Bild-URL';

  @override
  String get load => 'Laden';

  @override
  String get account => 'Konto';

  @override
  String get emailAddress => 'E-Mail-Adresse';

  @override
  String get signOut => 'Abmelden';

  @override
  String get signOutQuestion => 'Möchtest du dich wirklich abmelden?';

  @override
  String get profileSetupQuestion => 'Wie sollen wir dich nennen?';

  @override
  String get next => 'Weiter';

  @override
  String get framePairTitle => 'Frame verbinden';

  @override
  String get framePairHint =>
      'Gib den Code ein, den die Smile-App beim Verbinden dieses Frames anzeigt.';

  @override
  String get framePairButton => 'Verbinden';

  @override
  String get framePairInvalid => 'Dieser Code ist ungültig.';

  @override
  String get framePairExpired =>
      'Der Code ist abgelaufen. Lass dir in der Smile-App einen neuen anzeigen.';

  @override
  String get framePairRevoked => 'Dieser Frame wurde widerrufen.';

  @override
  String get framePairFailed => 'Verbinden fehlgeschlagen.';

  @override
  String get framePairNoConnection =>
      'Keine Verbindung zum Server. Bitte erneut versuchen.';

  @override
  String get frameOfflineTooLong =>
      'Dieser Frame war zu lange ohne Verbindung.\nDie Fotos erscheinen wieder, sobald er online ist.';

  @override
  String get frameRevokedScreen =>
      'Dieser Frame wurde widerrufen.\nEin Admin des Space kann ihn in der Smile-App wieder aktivieren.';

  @override
  String get frameNoPhotos => 'Noch keine Fotos';

  @override
  String get chooseAlbum => 'Album wählen';

  @override
  String postPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos',
      one: 'Foto',
    );
    return '$_temp0';
  }

  @override
  String postVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Videos',
      one: 'Video',
    );
    return '$_temp0';
  }

  @override
  String lastPostBy(String name, String what) {
    return '$name: $what';
  }

  @override
  String get someone => 'Jemand';

  @override
  String get noPostsYet => 'Noch keine Fotos';

  @override
  String get history => 'Verlauf';

  @override
  String get yesterday => 'Gestern';

  @override
  String get removeAll => 'Alle entfernen';

  @override
  String get removeEntry => 'Entfernen';

  @override
  String get deleteFrame => 'Frame löschen';

  @override
  String deleteFrameTitle(String name) {
    return 'Frame „$name“ löschen?';
  }

  @override
  String get deleteFrameMessage =>
      'Der Frame wird endgültig entfernt. Das Tablet löscht seine Fotos und zeigt wieder „Frame verbinden“. Zum Weiterverwenden einfach neu verbinden.';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountTitle => 'Konto endgültig löschen?';

  @override
  String get deleteAccountMessage =>
      'Dein Profil, alle deine Fotos und Videos in allen Alben und alle deine Mitgliedschaften werden sofort und endgültig gelöscht. Spaces, in denen du Admin bist, übernimmt dein längster Co-Admin; ohne Co-Admin wird der Space mit allen Alben und Frames gelöscht. Das kann nicht rückgängig gemacht werden.';

  @override
  String get deleteAccountConfirm => 'Endgültig löschen';

  @override
  String deleteAccountTitleNamed(String name) {
    return 'Konto von $name löschen?';
  }

  @override
  String deleteAccountWhich(String email) {
    return 'Gelöscht wird das Konto $email, mit dem du gerade angemeldet bist.';
  }

  @override
  String get deleteAccountTypeEmail =>
      'Zum Bestätigen diese E-Mail-Adresse eintippen:';
}
