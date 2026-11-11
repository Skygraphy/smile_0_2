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
  String get introAlbumsTitle => 'Alben';

  @override
  String get introAlbumsText =>
      'Teilt Fotos und Videos wie bei WhatsApp – nur ohne Chat. Jeder im Album sieht sie sofort.';

  @override
  String get introSpacesTitle => 'Spaces';

  @override
  String get introSpacesText =>
      'Ein Space ist eure Familie oder euer Haushalt – mit euren Alben und Frames.';

  @override
  String get introFramesTitle => 'Frames';

  @override
  String get introFramesText =>
      'Ein Tablet wird zum Bilderrahmen – zum Beispiel für Oma. Sie muss nichts bedienen.';

  @override
  String get introSkip => 'Überspringen';

  @override
  String get introNext => 'Weiter';

  @override
  String get introStart => 'Los geht\'s';

  @override
  String get introAgain => 'Einführung ansehen';

  @override
  String get introAgainHint => 'Die drei Seiten vom ersten Start noch einmal.';

  @override
  String get videoTooLongTitle => 'Video zu lang';

  @override
  String videoTooLongText(int minutes) {
    return 'Videos dürfen hier höchstens $minutes Minuten lang sein. Kürze es in der Galerie und schick es dann noch einmal.';
  }

  @override
  String get storageUsed => 'Belegt';

  @override
  String storageOf(String used, String limit) {
    return '$used von $limit';
  }

  @override
  String storageCounts(String photos, String videos) {
    return '$photos Fotos · $videos Videos';
  }

  @override
  String get shareOutMenu => 'Teilen …';

  @override
  String get shareOutShort => 'Teilen';

  @override
  String get saveToPhone => 'Aufs Handy speichern';

  @override
  String get saveToPhoneShort => 'Speichern';

  @override
  String get savedOne => 'Gespeichert – in deiner Galerie im Album „Smile“.';

  @override
  String savedMany(int count) {
    return '$count gespeichert – in deiner Galerie im Album „Smile“.';
  }

  @override
  String get saveFailed => 'Das Speichern hat leider nicht geklappt.';

  @override
  String get saveAlbum => 'Ganzes Album speichern';

  @override
  String saveAlbumTitle(int count) {
    return '$count Fotos und Videos aufs Handy speichern?';
  }

  @override
  String get saveAlbumMessage =>
      'Sie kommen in deine Galerie ins Album „Smile“. Videos, die noch nicht auf dem Handy sind, werden heruntergeladen – am besten im WLAN.';

  @override
  String saveProgress(int done, int count) {
    return '$done von $count gespeichert …';
  }

  @override
  String get shareFailed => 'Das Teilen hat leider nicht geklappt.';

  @override
  String get preparing => 'Wird vorbereitet …';

  @override
  String get pauseZoomTitle => 'Beim Anhalten weiter zoomen';

  @override
  String get onThisDayTitle => 'Heute vor einem Jahr';

  @override
  String get onThisDayHint =>
      'Fotos, die an diesem Tag in früheren Jahren aufgenommen wurden, laufen heute zuerst.';

  @override
  String onThisDayYears(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: 'Heute vor $years Jahren',
      one: 'Heute vor einem Jahr',
    );
    return '$_temp0';
  }

  @override
  String get fullHdTitle => 'Full HD';

  @override
  String get fullHdHint =>
      '1080p, am Tablet am schärfsten. Rund 45 MB pro Minute Video, braucht länger zum Senden. Aus: es gilt die Stufe darunter.';

  @override
  String get pauseZoomHint =>
      'Ein angehaltenes Foto zoomt im selben Tempo weiter. Aus: Es bleibt stehen, wie es gerade ist.';

  @override
  String get tipDidYouKnow => 'WUSSTEST DU?';

  @override
  String get easyStopTitle => 'Easy Stopping';

  @override
  String get easyStopHint =>
      'Antippen hält das Bild an, nochmal tippen lässt es weiterlaufen. Auf jeder Stufe, auch bei „Nur zuschauen“.';

  @override
  String get easyStoppedTitle => 'Angehalten';

  @override
  String get easyStoppedHint => 'Nochmal tippen, dann geht es weiter';

  @override
  String get easyResumedTitle => 'Läuft weiter';

  @override
  String get easyLongPressHint => 'Lange drücken zeigt die Knöpfe';

  @override
  String get newSoundTitle => 'Ton bei neuen Fotos';

  @override
  String get newSoundHint =>
      'Einmal, wenn etwas Neues ankommt. Still in der Nachtruhe.';

  @override
  String get newReminderTitle => 'Erinnern, bis jemand schaut';

  @override
  String get newReminderHint =>
      'Der Ton kommt jede Stunde wieder, höchstens dreimal.';

  @override
  String get newHintTitle => 'Hinweis auf Neues';

  @override
  String get newHintHint =>
      'Bleibt am Frame stehen, bis jemand tippt. Ein Tippen zeigt die neuen Fotos.';

  @override
  String get newOnePhoto => 'Ein neues Foto';

  @override
  String get newOneVideo => 'Ein neues Video';

  @override
  String newManyPhotos(int count) {
    return '$count neue Fotos';
  }

  @override
  String newManyVideos(int count) {
    return '$count neue Videos';
  }

  @override
  String newManyMixed(int count) {
    return '$count neue Fotos und Videos';
  }

  @override
  String newFromNames(String names) {
    return 'von $names';
  }

  @override
  String namesAnd(String first, String last) {
    return '$first und $last';
  }

  @override
  String get newTapToSee => 'antippen';

  @override
  String get roleFrameAdmin => 'Frame-Admin';

  @override
  String get frameAdminHint =>
      'Bestimmt bei diesem Frame alles: was am Frame bedient werden darf und welche Alben laufen.';

  @override
  String get inviteFrameAdmin => 'Frame-Admin einladen';

  @override
  String get inviteMoreFrameAdmin => 'Weitere Person einladen';

  @override
  String frameAdminFor(String frame) {
    return 'Frame-Admin von $frame';
  }

  @override
  String get qrScanHintFrameAdmin =>
      'Mit der Handykamera scannen oder in Smile: ⋮ → Code scannen. Frame-Admin wird man nur per QR-Code vor Ort.';

  @override
  String inviteFrameAdminFrom(String name) {
    return '$name möchte dich zum Frame-Admin machen. Du bestimmst dann, was am Frame bedient werden darf und welche Alben dort laufen.';
  }

  @override
  String acceptedFrameAdmin(String frame) {
    return 'Du bist jetzt Frame-Admin von $frame.';
  }

  @override
  String redeemJoinedFrameAdmin(String frame) {
    return 'Du bist jetzt Frame-Admin von $frame.';
  }

  @override
  String get frameAdminInvited => 'Eingeladen, noch nicht angenommen';

  @override
  String get withdrawInvite => 'Einladung zurückziehen';

  @override
  String get endFrameAdmin => 'Frame-Admin beenden';

  @override
  String endFrameAdminTitle(String name) {
    return '$name als Frame-Admin beenden?';
  }

  @override
  String endFrameAdminMessage(String name, String frame) {
    return '$name bestimmt dann nicht mehr über $frame. Der Frame läuft weiter wie eingestellt.';
  }

  @override
  String get giveUpFrameAdmin => 'Frame-Admin abgeben';

  @override
  String giveUpFrameAdminMessage(String frame) {
    return 'Du bestimmst dann nicht mehr über $frame. Der Frame läuft weiter wie eingestellt.';
  }

  @override
  String frameAdminPersonHint(String frame) {
    return 'Frame-Admin von $frame. Bestimmt die Bedienung und welche Alben laufen. Fotos, Alben und Personen im Space verwaltet sie oder er nicht.';
  }

  @override
  String get alreadyFrameAdmin => 'Schon Frame-Admin oder Admin';

  @override
  String get youAreFrameAdmin => 'du bist Frame-Admin';

  @override
  String get unlockSection => 'Am Frame entsperren';

  @override
  String get unlockHint =>
      'Lange auf die Uhr drücken und den Code eingeben: Der Frame zeigt dann alle Knöpfe, bis er sich nach 2 Minuten ohne Berührung wieder sperrt.';

  @override
  String get unlockSetCode => 'Code festlegen';

  @override
  String get unlockChangeCode => 'Code ändern';

  @override
  String get unlockCodeIsSet => 'Ein Code ist festgelegt.';

  @override
  String get unlockNoCode =>
      'Noch kein Code: Am Frame lässt sich dann nichts entsperren.';

  @override
  String unlockCodeTitle(String frame) {
    return 'Code für $frame';
  }

  @override
  String get unlockCodeDialogHint =>
      '4 Ziffern. Wer Frame-Admin oder Admin ist, kann ihn jederzeit neu festlegen.';

  @override
  String get unlockCodeRepeat => 'Zur Bestätigung noch einmal';

  @override
  String get unlockCodeMismatch =>
      'Die beiden Codes sind verschieden. Bitte noch einmal.';

  @override
  String get unlockCodeSaved => 'Code gespeichert';

  @override
  String get unlockRemoveCode => 'Code entfernen';

  @override
  String get unlockRemoveMessage =>
      'Am Frame lässt sich dann nichts mehr entsperren – wie vor dem ersten Code.';

  @override
  String get unlockCodeRemoved => 'Code entfernt';

  @override
  String get unlockEnterCode => 'Code eingeben';

  @override
  String get unlockWrongCode => 'Falscher Code';

  @override
  String get unlockWaitMinute => 'Bitte 1 Minute warten';

  @override
  String get unlockedBadge => 'Entsperrt';

  @override
  String get lockNow => 'Sperren';

  @override
  String get roleMember => 'Member';

  @override
  String get roleViewer => 'Viewer';

  @override
  String get admins => 'Admins';

  @override
  String get sharedWith => 'Geteilt mit';

  @override
  String sharedWithSpace(String space) {
    return 'Geteilt mit $space';
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
  String get firstStepsInvitedHint => 'QR-Code scannen oder Code eintippen';

  @override
  String get firstStepsSetup => 'Ich richte Smile ein';

  @override
  String get firstStepsSetupHint =>
      'Space für dein Zuhause oder deinen Betrieb anlegen';

  @override
  String get firstStepsQuestion =>
      'Hier erscheinen deine Alben. Wie möchtest du anfangen?';

  @override
  String albumsLoadError(String error) {
    return 'Die Alben konnten gerade nicht geladen werden. $error';
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
  String sharedPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos',
      one: '1 Foto',
    );
    return '$_temp0';
  }

  @override
  String sharedVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Videos',
      one: '1 Video',
    );
    return '$_temp0';
  }

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
  String get showOnFrame => 'Auf Frame zeigen';

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
    return 'Freigabe für $space beenden?';
  }

  @override
  String endShareMessage(String space, String album) {
    return '$space sieht $album danach nicht mehr, auch nicht auf seinen Frames.';
  }

  @override
  String get leaveAlbum => 'Album verlassen';

  @override
  String get leaveAlbumMessage =>
      'Du siehst die Fotos dieses Albums danach nicht mehr.';

  @override
  String sharedAlbumOwnedBy(String owner, String home, String space) {
    return 'Dieses Album gehört $owner aus dem Space $home und ist mit deinem Space $space geteilt.';
  }

  @override
  String removeFromSpace(String space) {
    return 'Aus $space entfernen';
  }

  @override
  String removeFromSpaceHint(String owner) {
    return 'Das Album gehört $owner und bleibt erhalten.';
  }

  @override
  String removeFromSpaceTitle(String album, String space) {
    return '$album aus $space entfernen?';
  }

  @override
  String removeFromSpaceMessage(String owner, String space) {
    return 'Danach siehst du das Album nicht mehr: nicht in deiner Albumliste und nicht auf deinen Frames, und du kannst dort nichts mehr posten.\n\nEs gehört $owner und bleibt mit allen Fotos erhalten. $owner kann es wieder mit $space teilen.';
  }

  @override
  String get deleteAlbum => 'Album löschen';

  @override
  String deleteAlbumTitle(String album) {
    return 'Album $album löschen?';
  }

  @override
  String get deleteAlbumMessage =>
      'Das Album verschwindet mit allen Fotos sofort für alle Personen und von allen Frames. 30 Tage lang kannst du es im Papierkorb wiederherstellen.';

  @override
  String albumInfoLoadError(String error) {
    return 'Die Album-Infos konnten gerade nicht geladen werden. $error';
  }

  @override
  String actionFailed(String error) {
    return 'Das hat leider nicht geklappt. $error';
  }

  @override
  String get actionAccept => 'Annehmen';

  @override
  String get actionDecline => 'Ablehnen';

  @override
  String get actionWithdraw => 'Zurückziehen';

  @override
  String spacesLoadError(String error) {
    return 'Die Spaces konnten gerade nicht geladen werden. $error';
  }

  @override
  String get spacesEmptyTitle => 'Noch kein eigener Space';

  @override
  String get spacesEmptyMessage =>
      'Einen Space brauchst du nur, wenn du selbst Frames aufstellst oder Alben verwaltest, für dein Zuhause oder deinen Betrieb.';

  @override
  String get createSpace => 'Space anlegen';

  @override
  String get createSpaceHint => 'z. B. Familie Müller';

  @override
  String get nameMissing => 'Bitte gib einen Namen ein.';

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
    return 'Die Space-Infos konnten gerade nicht geladen werden. $error';
  }

  @override
  String get createAlbum => 'Album anlegen';

  @override
  String get newAlbum => 'Neues Album';

  @override
  String get moreOptions => 'Weitere Optionen';

  @override
  String get newAlbumWhere => 'Neues Album in …';

  @override
  String inSpaceLine(String space) {
    return 'in $space';
  }

  @override
  String get createAlbumHint => 'z. B. Enkelkinder';

  @override
  String get noAlbumYet => 'Noch kein Album';

  @override
  String sharedIntoSpace(String space) {
    return 'Mit dem Space $space geteilt';
  }

  @override
  String sharedFromSpace(String space) {
    return 'aus dem Space $space · nur ansehen';
  }

  @override
  String get viewOnly => 'nur ansehen';

  @override
  String get sharedIntoSpaceHint =>
      'Alben anderer Spaces, die hier nur angesehen werden';

  @override
  String get stopShowing => 'Nicht mehr anzeigen';

  @override
  String stopShowingTitle(String album) {
    return '$album nicht mehr anzeigen?';
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
  String get actionStepDown => 'Abgeben';

  @override
  String get stepDownMessage =>
      'Du verlierst deine Verwaltungsrechte über diesen Space.';

  @override
  String get trashTitle => 'Papierkorb';

  @override
  String get deleteSpace => 'Space löschen';

  @override
  String deleteSpaceTitle(String space) {
    return 'Space $space löschen?';
  }

  @override
  String get deleteSpaceMessage =>
      'Der Space verschwindet mit allen Alben, Fotos und Frames sofort für alle; alle Beteiligten werden benachrichtigt. 30 Tage lang kannst du ihn im Papierkorb wiederherstellen.';

  @override
  String inTrash(String name) {
    return '$name ist im Papierkorb.';
  }

  @override
  String frameInfoLoadError(String error) {
    return 'Die Frame-Infos konnten gerade nicht geladen werden. $error';
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
  String get openAlbum => 'Album öffnen';

  @override
  String get openFrame => 'Frame öffnen';

  @override
  String get offlineHint => 'Offline – zuletzt geladener Stand';

  @override
  String get videoNotOnPhone =>
      'Dieses Video ist noch nicht auf dem Handy. Ohne Verbindung kann es nicht abgespielt werden.';

  @override
  String changeNotSaved(String reason) {
    return 'Die Änderung wurde nicht gespeichert. $reason';
  }

  @override
  String get showingNow => 'Läuft gerade';

  @override
  String get showNow => 'Jetzt zeigen';

  @override
  String get showHereNow => 'Hier jetzt zeigen';

  @override
  String get frameShowsThisAlbum => 'zeigt gerade dieses Album';

  @override
  String frameShowsAlbum(String album) {
    return 'zeigt gerade $album';
  }

  @override
  String frameSwitched(String frame, String album) {
    return '$frame zeigt jetzt $album.';
  }

  @override
  String removeFromFrameTitle(String album) {
    return '$album vom Frame entfernen?';
  }

  @override
  String get removeFromFrameMessage =>
      'Der Frame zeigt die Fotos dieses Albums dann nicht mehr. Das Album und seine Fotos bleiben erhalten.';

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
    return 'Die Neuigkeiten konnten gerade nicht geladen werden. $error';
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
    return 'Du verwaltest jetzt $space mit.';
  }

  @override
  String acceptedAlbum(String album) {
    return '$album ist jetzt in deinen Alben.';
  }

  @override
  String acceptedShare(String album) {
    return '$album ist jetzt mit deinem Space geteilt.';
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
    return 'Der Papierkorb konnte gerade nicht geladen werden. $error';
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
    return '$name ist wiederhergestellt.';
  }

  @override
  String profileLoadError(String error) {
    return 'Dein Profil konnte gerade nicht geladen werden. $error';
  }

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get changeName => 'Name ändern';

  @override
  String nameSaveError(String error) {
    return 'Der Name konnte nicht gespeichert werden. $error';
  }

  @override
  String avatarUploadError(String error) {
    return 'Das Bild konnte nicht hochgeladen werden. $error';
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
  String get aboutSmile => 'Über Smile';

  @override
  String aboutSmileHint(String version) {
    return 'Version $version · Impressum · Datenschutz';
  }

  @override
  String versionValue(String version) {
    return 'Version $version';
  }

  @override
  String get impressum => 'Impressum';

  @override
  String get privacyPolicy => 'Datenschutz';

  @override
  String get deleteAccountWebHint => 'So geht es, auch ohne App';

  @override
  String get openSourceLicenses => 'Open-Source-Lizenzen';

  @override
  String get openSourceThanks =>
      'Smile verwendet diese freie Software. Danke an alle, die sie entwickeln.';

  @override
  String get searchHint => 'Suchen …';

  @override
  String licenseCount(int count) {
    return '$count Lizenzen';
  }

  @override
  String get loginPrivacyBefore => 'Mit der Anmeldung gilt unsere ';

  @override
  String get loginPrivacyLink => 'Datenschutzerklärung';

  @override
  String get loginPrivacyAfter => '.';

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
      'Halte den QR-Code aus der Smile-App vor die Kamera – oder tippe den Code ein, der darunter steht.';

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
    return 'Frame $name löschen?';
  }

  @override
  String get deleteFrameMessage =>
      'Der Frame wird endgültig entfernt. Das Tablet löscht seine Fotos und zeigt wieder den Bildschirm zum Verbinden. Zum Weiterverwenden einfach neu verbinden.';

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

  @override
  String get newsUnseen => 'Neuigkeiten, es gibt Neues';

  @override
  String pictureFor(String name) {
    return 'Bild für $name';
  }

  @override
  String coverFor(String name) {
    return 'Titelbild für $name';
  }

  @override
  String get pickFromAlbum => 'Foto aus dem Album wählen';

  @override
  String get automaticCover => 'Automatisch: neuestes Foto';

  @override
  String get removePicture => 'Bild entfernen';

  @override
  String get changeObjectPicture => 'Bild ändern';

  @override
  String get setAsCover => 'Als Titelbild';

  @override
  String coverSet(String name) {
    return '$name hat ein neues Titelbild.';
  }

  @override
  String get choosePhoto => 'Foto wählen';

  @override
  String get noPhotosInAlbum => 'In diesem Album gibt es noch keine Fotos.';

  @override
  String get captureInAlbum => 'Aufnehmen';

  @override
  String get recordVideo => 'Video aufnehmen';

  @override
  String get captureSend => 'Senden';

  @override
  String get captureRetake => 'Nochmal';

  @override
  String get noConnectionTitle => 'Keine Internetverbindung';

  @override
  String get noConnectionMessage =>
      'Prüfe deine Verbindung und versuche es noch einmal.';

  @override
  String get noConnectionReason => 'Keine Internetverbindung.';

  @override
  String get tryAgainReason => 'Bitte versuche es noch einmal.';

  @override
  String get videoNotPlayable =>
      'Das Video kann gerade nicht abgespielt werden.';

  @override
  String get loginEmailMissing => 'Bitte gib deine E-Mail-Adresse ein.';

  @override
  String get loginEmailInvalid =>
      'Das ist keine gültige E-Mail-Adresse. Bitte prüfe sie.';

  @override
  String get loginSendFailed =>
      'Die E-Mail mit dem Code konnte gerade nicht gesendet werden. Bitte versuche es gleich noch einmal.';

  @override
  String get loginCodeWrong =>
      'Der Code stimmt nicht oder ist abgelaufen. Bitte prüfe ihn oder lass dir einen neuen schicken.';

  @override
  String get sendFailed =>
      'Das Senden hat leider nicht geklappt. Bitte versuche es noch einmal.';

  @override
  String sendFailedSome(int failed, int total) {
    return '$failed von $total konnten nicht gesendet werden. Bitte versuche es noch einmal.';
  }

  @override
  String get ok => 'OK';

  @override
  String get dontSend => 'Nicht senden';

  @override
  String allSelected(int count) {
    return 'Alle $count ausgewählt';
  }

  @override
  String get selectAll => 'Alle';

  @override
  String get selectNone => 'Keine';

  @override
  String get coverShort => 'Titelbild';

  @override
  String deletePhotosTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos löschen?',
      one: 'Foto löschen?',
    );
    return '$_temp0';
  }

  @override
  String get deleteForEveryone => 'Für alle löschen';

  @override
  String get deleteForEveryoneHint =>
      'Bei allen und auf allen Frames, endgültig';

  @override
  String get deleteForMe => 'Für mich löschen';

  @override
  String get deleteForMeHint =>
      'Nur bei dir weg, über ⋮ → Ausgeblendete anzeigen zurückholbar';

  @override
  String get deleteOnlyOwn =>
      'Für alle löschen kannst du nur deine eigenen Fotos.';

  @override
  String inviteToNamed(String name) {
    return 'In $name einladen';
  }

  @override
  String coAdminFor(String name) {
    return 'Co-Admin für $name';
  }

  @override
  String get searchName => 'Name suchen';

  @override
  String get noKnownPeople =>
      'Noch niemand, den du in Smile kennst. Lade per QR-Code oder Link ein.';

  @override
  String get showQrCode => 'QR-Code zeigen';

  @override
  String get shareInviteLink => 'Einladungslink teilen';

  @override
  String get inviteByEmail => 'Per E-Mail einladen';

  @override
  String inviteSentTo(String name) {
    return 'Einladung an $name gesendet';
  }

  @override
  String get managesASpace => 'Verwaltet einen Space';

  @override
  String get qrScanHint =>
      'Mit der Handykamera scannen oder in Smile: ⋮ → Code scannen. Oder den Code eintippen.';

  @override
  String get qrScanHintCoAdmin =>
      'Mit der Handykamera scannen oder in Smile: ⋮ → Code scannen. Co-Admin wird man nur per QR-Code vor Ort.';

  @override
  String get qrValid => 'Gilt 24 Stunden.';

  @override
  String get newCode => 'Neuen Code erstellen';

  @override
  String inviteMessageMember(String album, String link) {
    return 'Komm in mein Smile-Album $album! Einfach auf den Link tippen: $link';
  }

  @override
  String inviteMessageShare(String album, String link) {
    return 'Ich möchte mein Smile-Album $album mit deinem Space teilen. Einfach auf den Link tippen: $link';
  }

  @override
  String get scanCode => 'Code scannen';

  @override
  String get scanHint => 'QR-Code in den Rahmen halten';

  @override
  String get typeCode => 'Code eintippen';

  @override
  String get codeFieldHint => 'z. B. K7P-2QX';

  @override
  String redeemJoinedAlbum(String name) {
    return 'Du bist jetzt im Album $name.';
  }

  @override
  String redeemJoinedShare(String album, String space) {
    return '$album ist jetzt in deinem Space $space zu sehen.';
  }

  @override
  String redeemJoinedCoAdmin(String space) {
    return 'Du bist jetzt Co-Admin von $space.';
  }

  @override
  String get redeemRequestedTitle => 'Anfrage gesendet';

  @override
  String redeemRequested(String name) {
    return 'Die Admins von $name entscheiden. Du bekommst Bescheid.';
  }

  @override
  String get redeemAlready => 'Du bist schon dabei.';

  @override
  String get redeemPickSpace => 'Mit welchem Space teilen?';

  @override
  String get codeInvalid => 'Dieser Code ist ungültig.';

  @override
  String get codeExpired =>
      'Der Code ist abgelaufen. Lass dir einen neuen zeigen.';

  @override
  String get codeQrOnly =>
      'Co-Admin wirst du nur, indem du den QR-Code vor Ort scannst.';

  @override
  String get codeNoSpace =>
      'Du verwaltest keinen Space, mit dem du das Album teilen kannst.';

  @override
  String get cameraUnavailable =>
      'Die Kamera ist nicht verfügbar. Du kannst den Code eintippen.';

  @override
  String get frameOnline => 'Online';

  @override
  String frameOfflineSince(String time) {
    return 'Offline seit $time';
  }

  @override
  String get frameNeverOnline => 'Verbunden · meldet sich gleich';

  @override
  String batteryShort(int level) {
    return 'Akku $level %';
  }

  @override
  String durationMinutes(int count) {
    return '$count Min.';
  }

  @override
  String durationHours(int count) {
    return '$count Std.';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tagen',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get nowShowingLabel => 'Läuft gerade';

  @override
  String get switchAlbum => 'Album wechseln';

  @override
  String get soundOn => 'Ton an';

  @override
  String get soundOff => 'Ton aus';

  @override
  String get tileVideoSound => 'Ton bei Videos';

  @override
  String get tileAlbumSwitch => 'Wechsel am Frame';

  @override
  String get valueOn => 'An';

  @override
  String get valueOff => 'Aus';

  @override
  String get valueAllowed => 'Erlaubt';

  @override
  String get manageAlbums => 'Alben verwalten';

  @override
  String get settingsAndDevice => 'Einstellungen & Gerät';

  @override
  String get openRemote => 'Frame steuern';

  @override
  String get pickFrame => 'Welcher Frame?';

  @override
  String get useAsFrame => 'Dieses Gerät als Frame verwenden';

  @override
  String get setUpFrame => 'Frame einrichten';

  @override
  String connectNamedFrame(String name) {
    return '$name verbinden';
  }

  @override
  String get connectFrameHint =>
      'Auf dem Tablet: Smile öffnen → Dieses Gerät als Frame verwenden → QR-Code scannen. Gilt 15 Minuten.';

  @override
  String get waitingForFrame => 'Warte auf den Frame …';

  @override
  String get frameNameQuestion =>
      'Wie soll der neue Frame heißen, z. B. Küche?';

  @override
  String get anotherDevice => 'Ein anderes Gerät';

  @override
  String get anotherDeviceHint =>
      'Das Tablet scannt den QR-Code oder bekommt den Code.';

  @override
  String get thisDevice => 'Dieses Gerät';

  @override
  String get thisDeviceHint =>
      'Dieses Gerät wird sofort zum Frame. Deine Anmeldung hier endet.';

  @override
  String get thisDeviceTitle => 'Dieses Gerät zum Frame machen?';

  @override
  String get thisDeviceMessage =>
      'Danach läuft hier nur noch die Diashow, und du wirst auf diesem Gerät abgemeldet. Deine Alben und Fotos bleiben natürlich erhalten.';

  @override
  String get thisDeviceConfirm => 'Zum Frame machen';

  @override
  String get frameScanHint => 'QR-Code aus der Smile-App in den Rahmen halten';

  @override
  String get frameScanInstead => 'QR-Code scannen';

  @override
  String get pickSpaceForFrame => 'Für welchen Space?';

  @override
  String get connectOtherDevice => 'Anderes Gerät verbinden';

  @override
  String get reconnectHint =>
      'Auf dem neuen Gerät: Smile öffnen → Dieses Gerät als Frame verwenden → QR-Code scannen. Es übernimmt Alben und Einstellungen; das bisherige Gerät ist danach kein Frame mehr.';

  @override
  String get done => 'Fertig';

  @override
  String get playSlideshow => 'Diashow';

  @override
  String frameAlbumEmpty(String album) {
    return 'In $album sind noch keine Fotos.';
  }

  @override
  String get frameAlbumEmptyHint =>
      'Ein anderes Album wählst du in der Smile-App unter Frames.';

  @override
  String get sendVideos => 'Videos senden';

  @override
  String get qualityHigh => 'Hoch';

  @override
  String get qualityMedium => 'Mittel';

  @override
  String get qualityLow => 'Niedrig';

  @override
  String get qualityHighHint =>
      '720p, sehr scharf – rund 24 MB pro Minute Video.';

  @override
  String get qualityMediumHint =>
      'Genau wie WhatsApp (480p) – rund 12 MB pro Minute Video.';

  @override
  String get qualityLowHint =>
      '360p, für kleine Bildschirme – rund 6 MB pro Minute Video. Am schnellsten gesendet.';

  @override
  String get ctrlBack => 'Zurück';

  @override
  String get ctrlPause => 'Pause';

  @override
  String get ctrlPlay => 'Abspielen';

  @override
  String get ctrlNext => 'Weiter';

  @override
  String get ctrlNewest => 'Neueste';

  @override
  String get ctrlOverview => 'Übersicht';

  @override
  String get ctrlAlbum => 'Album';

  @override
  String get ctrlDuration => 'Dauer';

  @override
  String frameNewFrom(String name) {
    return 'Neu von $name';
  }

  @override
  String get frameBackToSlideshow => 'Zurück zur Diashow';

  @override
  String get durationQuestion => 'Wie lange soll ein Foto zu sehen sein?';

  @override
  String secondsValue(int n) {
    return '$n Sekunden';
  }

  @override
  String get oneMinute => '1 Minute';

  @override
  String get playbackTitle => 'Wiedergabe';

  @override
  String get playbackHint =>
      'Was läuft und wie. Das stellt immer die App ein, egal welche Bedienstufe.';

  @override
  String get whatPlays => 'Was läuft';

  @override
  String get contentAlbum => 'Ein Album';

  @override
  String get contentRotate => 'Alle Alben im Wechsel';

  @override
  String get contentRecent => 'Aktuelles';

  @override
  String get recentMeans => 'Aktuelles bedeutet';

  @override
  String recentLast(int n) {
    return 'Letzte $n Fotos';
  }

  @override
  String get playOrder => 'Reihenfolge';

  @override
  String get orderNewest => 'Neueste zuerst';

  @override
  String get orderOldest => 'Der Reihe nach';

  @override
  String get orderShuffle => 'Zufällig';

  @override
  String get atEnd => 'Am Ende';

  @override
  String get endLoop => 'Endlosschleife';

  @override
  String get endOverview => 'Übersicht zeigen';

  @override
  String get displayTime => 'Anzeigedauer';

  @override
  String get showNewNow => 'Neue Fotos sofort zeigen';

  @override
  String get showNewNowHint => 'Oben im Bild steht, von wem es kommt.';

  @override
  String get bigClock => 'Große Uhr mit Datum';

  @override
  String get bigClockHint => 'Wochentag, Datum und Uhrzeit oben rechts.';

  @override
  String get showSenderCaption => 'Absender einblenden';

  @override
  String get showSenderCaptionHint => 'Album und Name oben links im Bild.';

  @override
  String get quietTime => 'Nachtruhe';

  @override
  String get quietTimeHint => 'Der Bildschirm ist in dieser Zeit dunkel.';

  @override
  String get quietOff => 'Aus';

  @override
  String quietRange(String from, String to) {
    return '$from bis $to';
  }

  @override
  String get quietFromLabel => 'Dunkel ab';

  @override
  String get quietToLabel => 'Hell ab';

  @override
  String get controlsTitle => 'Bedienung am Frame';

  @override
  String get controlsHint =>
      'Die App steuert den Frame immer vollständig. Die Bedienstufe legt fest, was die Person vor dem Frame zusätzlich selbst tun darf.';

  @override
  String get controlLevel => 'Bedienstufe';

  @override
  String get level1 => 'Nur zuschauen';

  @override
  String get level1Hint =>
      'Nur Antippen: hält das Bild an und lässt es weiterlaufen. Alles andere kommt aus der App.';

  @override
  String get level2 => 'Blättern';

  @override
  String get level2Hint => 'Pause und ein großer Weiter-Knopf.';

  @override
  String get level3 => 'Einfach';

  @override
  String get level3Hint => 'Zurück, Pause, Weiter und Neueste Fotos.';

  @override
  String get level4 => 'Komfort';

  @override
  String get level4Hint =>
      'Dazu Übersicht, Album wechseln, Anzeigedauer und Titel ein- oder ausblenden.';

  @override
  String get level5 => 'Alles selbst';

  @override
  String get level5Hint => 'Dazu alle Wiedergabe-Einstellungen am Frame.';

  @override
  String get levelCustom => 'Eigene Auswahl';

  @override
  String get levelCustomHint => 'Einzelne Schalter weichen von den Stufen ab.';

  @override
  String get allowedOneByOne => 'Einzeln erlaubt';

  @override
  String get allowNext => 'Weiter';

  @override
  String get allowBack => 'Zurück';

  @override
  String get allowPause => 'Pause';

  @override
  String get allowNewest => 'Neueste Fotos';

  @override
  String get allowOverview => 'Übersicht';

  @override
  String get allowAlbum => 'Album wechseln';

  @override
  String get allowDuration => 'Anzeigedauer';

  @override
  String get allowPlayback => 'Wiedergabe-Einstellungen';

  @override
  String get remoteTitle => 'Fernbedienung';

  @override
  String get remoteHint => 'Funktioniert auf jeder Bedienstufe.';

  @override
  String remoteNewest(int n) {
    return 'Neueste $n Fotos abspielen';
  }

  @override
  String get showOnFrameNow => 'Jetzt am Frame zeigen';

  @override
  String get nowRunning => 'läuft gerade';

  @override
  String get addShort => 'Hinzufügen';

  @override
  String frameOtherSpaceHint(String album, String space) {
    return '$album gehört zum Space $space. Ein Frame zeigt nur Alben aus seinem eigenen Space oder solche, die mit seinem Space geteilt sind. Ein Admin von $space kann das Album über Album-Info → Mit einem Space teilen mit deinem Space teilen – danach geht es hier mit einem Tipp.';
  }

  @override
  String get favorites => 'Lieblingsbilder';

  @override
  String get favoriteMarked => 'Gemerkt';

  @override
  String get favoriteUnmarked => 'Nicht mehr gemerkt';

  @override
  String get ctrlFavorite => 'Merken';

  @override
  String get allowFavorite => 'Lieblingsbilder merken';

  @override
  String get allowFavorites => 'Lieblingsbilder abspielen';

  @override
  String get contentFavorites => 'Lieblingsbilder';

  @override
  String get favoritesSeeAll => 'Alle ansehen';

  @override
  String favoritesCount(int n) {
    return 'Lieblingsbilder · $n';
  }

  @override
  String get favoriteOnFrame => 'Am Frame';

  @override
  String favoriteToday(String time) {
    return 'heute $time';
  }

  @override
  String favoriteYesterday(String time) {
    return 'gestern $time';
  }

  @override
  String get favoriteFor => 'Lieblingsbild für den Frame';

  @override
  String showOnFrameSent(String frame) {
    return 'Wird jetzt auf $frame gezeigt';
  }

  @override
  String showOnFrameOffline(String frame) {
    return '$frame ist gerade nicht erreichbar. Das Foto erscheint dort nicht.';
  }

  @override
  String favoriteAddedTo(String frame) {
    return 'Lieblingsbild von $frame';
  }

  @override
  String get favoritesEmpty => 'Noch keine Lieblingsbilder';

  @override
  String get favoritesEmptyHint =>
      'Am Frame mit dem Herz merken – oder hier in einem Album beim Foto über das Herz oben rechts.';

  @override
  String get favoritesRemove => 'Entfernen';

  @override
  String get favoritesRemoveAll => 'Alle entfernen';

  @override
  String favoritesRemoveAllQuestion(String frame) {
    return 'Alle Lieblingsbilder von $frame entfernen?';
  }

  @override
  String get favoritesRemoveHint => 'Die Fotos selbst bleiben in ihren Alben.';

  @override
  String favoritesSelected(int n) {
    return '$n ausgewählt';
  }

  @override
  String favoritesRemoveSelectedQuestion(int n, String frame) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Lieblingsbilder',
      one: '1 Lieblingsbild',
    );
    return '$_temp0 von $frame entfernen?';
  }

  @override
  String favoriteRemovedFrom(String frame) {
    return 'Kein Lieblingsbild mehr von $frame';
  }

  @override
  String favoritesAddTitle(String frame) {
    return 'Lieblingsbilder · $frame';
  }

  @override
  String get favoriteForWhich => 'Lieblingsbild für …';

  @override
  String get favoriteStateOn => 'gemerkt';

  @override
  String get favoriteStateOff => 'nicht gemerkt';

  @override
  String get framePhotosLoading => 'Fotos werden geladen …';

  @override
  String get videoLengthLabel => 'Videos';

  @override
  String get videoFull => 'Ganze Länge';

  @override
  String videoAsPhoto(int seconds) {
    return 'Wie ein Foto ($seconds s)';
  }

  @override
  String get fillLabel => 'Bildschirm füllen';

  @override
  String get fillNever => 'Nie';

  @override
  String get fillAuto => 'Wenn passend';

  @override
  String get fillAlways => 'Immer';

  @override
  String get fillHint =>
      'Wenn passend: füllt den Bildschirm, wenn höchstens ein schmaler Rand wegfällt – sonst das ganze Foto auf unscharfem Hintergrund.';

  @override
  String get slowZoom => 'Langsamer Zoom';

  @override
  String get slowZoomHint => 'Jedes Foto wird ganz langsam etwas größer.';

  @override
  String get groupBrowse => 'Blättern';

  @override
  String get groupPlaying => 'Was läuft';

  @override
  String get orientationLabel => 'Ausrichtung';

  @override
  String get orientAuto => 'Automatisch';

  @override
  String get orientPortrait => 'Hochformat';

  @override
  String get orientLandscape => 'Querformat';

  @override
  String get slideshowSettings => 'Diashow-Einstellungen';

  @override
  String get slideshowSettingsMore => 'Einstellungen …';

  @override
  String get slideshowPause => 'Anhalten';

  @override
  String get slideshowResume => 'Weiter abspielen';

  @override
  String get slideshowSettingsHint => 'Gilt für die Diashow auf diesem Handy.';

  @override
  String get showHiddenMenu => 'Ausgeblendete anzeigen';

  @override
  String get showAllMenu => 'Alle Fotos anzeigen';

  @override
  String get editProfile => 'Profil bearbeiten';

  @override
  String get roleAdminHint => 'Hat den Space angelegt und verwaltet alles.';

  @override
  String get roleCoAdminHint =>
      'Verwaltet den Space mit: Alben, Frames und Personen.';

  @override
  String get roleMemberHint => 'Stellt Fotos und Videos ins Album.';

  @override
  String get roleViewerHint => 'Sieht das Album über einen geteilten Space.';

  @override
  String get sharedSpaceHint =>
      'Dieser Space sieht das Album auf seinen Frames und Handys, trägt aber nichts bei.';

  @override
  String get favorites2 => 'Lieblingsbilder';

  @override
  String inviteMessageCodeFallback(String code) {
    return 'Falls der Link nicht geht: In Smile ⋮ → Code scannen → Code eintippen: $code';
  }

  @override
  String get smileName => 'Smile-Name';

  @override
  String get smileNameChoose => 'Smile-Namen wählen';

  @override
  String get smileNameHint =>
      'Wer deinen Smile-Namen genau kennt, findet dich in Smile und kann dich einladen. Gefunden wird nur der ganze Name, niemand kann stöbern.';

  @override
  String get smileNameRules =>
      '3 bis 24 Zeichen: Kleinbuchstaben, Ziffern, Punkt und Unterstrich.';

  @override
  String get smileNameFree => 'Frei';

  @override
  String smileNameIsFree(String name) {
    return '@$name ist frei. Mit Speichern gehört er dir.';
  }

  @override
  String smileNameIsTaken(String name) {
    return '@$name ist schon vergeben. Bitte wähle einen anderen.';
  }

  @override
  String get smileNameTooShort => 'Noch zu kurz. Mindestens 3 Zeichen.';

  @override
  String get smileNameTooLong => 'Zu lang. Höchstens 24 Zeichen.';

  @override
  String smileNameBadChar(String char) {
    return 'Das Zeichen $char geht nicht. Erlaubt sind a–z, 0–9, Punkt und Unterstrich.';
  }

  @override
  String get smileNameSpace =>
      'Leerzeichen gehen nicht. Nimm einen Punkt oder Unterstrich.';

  @override
  String get smileNameUmlaut =>
      'Umlaute gehen nicht. Schreib ae, oe, ue oder ss.';

  @override
  String get smileNameBadStart =>
      'Am Anfang muss ein Buchstabe oder eine Ziffer stehen.';

  @override
  String get smileNameDotAtEnd => 'Kein Punkt am Ende.';

  @override
  String get smileNameDoubleDot => 'Keine zwei Punkte hintereinander.';

  @override
  String get smileNameReserved =>
      'Diesen Namen kann man nicht wählen. Bitte wähle einen anderen.';

  @override
  String get smileNameSuggestions => 'Diese sind frei:';

  @override
  String get myCardHandlePlaceholder => '@ dein Smile-Name';

  @override
  String get myCardQrPlaceholder => 'Hier erscheint dein QR-Code';

  @override
  String get myCardPreviewHint =>
      'Mit einem Smile-Namen bekommst du diese Karte. Wer sie scannt, kann dich einladen.';

  @override
  String myCardTakeSuggestion(String name) {
    return '@$name übernehmen';
  }

  @override
  String get myCardOtherName => 'Anderen Namen wählen';

  @override
  String get smileNameTaken => 'Schon vergeben';

  @override
  String get smileNameInvalid =>
      'Nur a–z, 0–9, Punkt und Unterstrich, 3 bis 24 Zeichen';

  @override
  String get smileNameRemove => 'Smile-Namen entfernen';

  @override
  String get smileNameSaveError =>
      'Der Smile-Name konnte nicht gespeichert werden. Bitte versuche es noch einmal.';

  @override
  String get myCard => 'Meine Karte';

  @override
  String get myCardHint =>
      'Zeig diese Karte her oder teile sie, damit dich jemand in ein Album einladen kann.';

  @override
  String get shareMyCard => 'Meine Karte teilen';

  @override
  String myCardMessage(String link) {
    return 'Lade mich in Smile ein: $link';
  }

  @override
  String get myCardNeedsName =>
      'Wähle zuerst einen Smile-Namen. Dann bekommst du deine Karte mit QR-Code.';

  @override
  String get searchNameOrHandle => 'Name oder @Smile-Name';

  @override
  String get personNotFound => 'Diesen Smile-Namen gibt es nicht.';

  @override
  String get personIsYou => 'Das ist deine eigene Karte.';

  @override
  String get inviteIntoAlbum => 'In ein Album einladen';

  @override
  String get pickAlbumToInvite => 'In welches Album?';

  @override
  String get noAlbumsToInvite =>
      'Du verwaltest noch kein Album, in das du einladen kannst.';

  @override
  String get alreadyInAlbum => 'Schon im Album';

  @override
  String get alreadyAdmin => 'Schon Admin oder Co-Admin';

  @override
  String get managesNoSpace => 'Verwaltet keinen Space';

  @override
  String get noPersonFound =>
      'Niemand gefunden. Fremde nur mit ganzem @Smile-Namen.';

  @override
  String get fromContacts => 'Aus Kontakten';

  @override
  String get contactsPermTitle => 'Kontakte in Smile finden';

  @override
  String get contactsPermText =>
      'Smile prüft, wer aus deinem Telefonbuch schon Smile hat. Alle anderen kannst du per SMS einladen.';

  @override
  String get contactsPermPoint1 =>
      'Dein Telefonbuch bleibt auf dem Handy. Zum Prüfen gehen nur unlesbare Prüfwerte an Smile.';

  @override
  String get contactsPermPoint2 =>
      'Smile speichert keine Kontakte und schreibt niemanden von sich aus an.';

  @override
  String get contactsPermPoint3 =>
      'Du kannst es in den Android-Einstellungen jederzeit wieder ausschalten.';

  @override
  String get contactsContinue => 'Weiter';

  @override
  String get notNow => 'Nicht jetzt';

  @override
  String get contactsDenied =>
      'Smile darf deine Kontakte noch nicht sehen. Du kannst es in den Einstellungen erlauben.';

  @override
  String get openSettings => 'Einstellungen öffnen';

  @override
  String get searchContact => 'Kontakt suchen';

  @override
  String get inSmile => 'In Smile';

  @override
  String get notInSmile => 'Noch nicht in Smile';

  @override
  String inSmileAs(String name) {
    return 'in Smile: $name';
  }

  @override
  String get contactInvite => 'Einladen';

  @override
  String get noContacts => 'Keine Kontakte gefunden.';

  @override
  String get contactsOnlySmileHint =>
      'Co-Admin kann nur werden, wer schon Smile hat.';

  @override
  String get contactInviteTitle => 'Einladung zu Smile senden';

  @override
  String contactInviteText(String name) {
    return '$name hat noch kein Smile. Möchtest du eine Einladung schicken?';
  }

  @override
  String get contactMessageLabel => 'Nachricht';

  @override
  String get sendSms => 'Per SMS senden';

  @override
  String get sendWhatsApp => 'Per WhatsApp senden';

  @override
  String get sendEmail => 'Per E-Mail senden';

  @override
  String get sendOther => 'Mit anderer App senden';

  @override
  String contactSmsMember(String album, String link) {
    return 'Ich lade dich in mein Smile-Album $album ein. Dort teilen wir Fotos und Videos: $link';
  }

  @override
  String get phoneMobile => 'Mobil';

  @override
  String get phoneHome => 'Privat';

  @override
  String get phoneWork => 'Arbeit';

  @override
  String get captionHint => 'Titel hinzufügen …';

  @override
  String get tipLabel => 'TIPP';

  @override
  String get tipUnderstood => 'Verstanden';

  @override
  String get tipNoMore => 'Keine Tipps mehr';

  @override
  String get tipsSection => 'Tipps';

  @override
  String get tipsShow => 'Tipps anzeigen';

  @override
  String get tipsShowHint =>
      'Ab und zu ein kurzer Hinweis, was Smile noch kann.';

  @override
  String get tipsReset => 'Tipps von vorne zeigen';

  @override
  String get tipsResetHint => 'Auch die schon gesehenen kommen wieder.';

  @override
  String get tipsResetDone => 'Die Tipps kommen wieder von vorne.';

  @override
  String get soundsSection => 'Töne';

  @override
  String get albumSounds => 'Töne im Album';

  @override
  String get albumSoundsHint =>
      'Ein Plopp beim Senden und bei neuen Fotos im offenen Album. Ist das Handy lautlos, bleibt Smile still.';

  @override
  String get tipFrameButton =>
      'Ein Tipp auf das Frame-Symbol zeigt dieses Album sofort am Frame. Lang drücken öffnet die Fernbedienung.';

  @override
  String get tipSlideshow =>
      'Mit dem Diashow-Symbol läuft das Album als Diashow auf diesem Handy, mit eigenen Einstellungen.';

  @override
  String get tipCaptionWhenSending =>
      'Jedes Foto kann einen eigenen Titel bekommen. Unten antippen oder wischen, um zum nächsten zu wechseln.';

  @override
  String get tipCaptionLater =>
      'Hier kannst du nachträglich einen Titel setzen oder ändern.';

  @override
  String get tipFavoriteHeart =>
      'Mit dem Herz merkst du ein Foto als Lieblingsbild für den Frame.';

  @override
  String get tipSelectPhotos =>
      'Lang auf ein Foto drücken: mehrere auswählen, ausblenden oder löschen.';

  @override
  String get tipQuickCapture =>
      'Das Kamera-Symbol oben: Foto machen und gleich in ein Album schicken.';

  @override
  String get tipInviteWays =>
      'Einladen geht auch ohne E-Mail: per QR-Code, Link oder aus den Kontakten.';

  @override
  String get tipSmileName =>
      'Mit deinem Smile-Namen und deiner Karte findet dich jeder, der dich einladen möchte.';

  @override
  String get tipControlLevel =>
      'Mit der Bedienstufe legst du fest, was am Frame selbst bedient werden kann, von Nur zuschauen bis Alles selbst.';

  @override
  String get tipPlayback =>
      'Unter Wiedergabe: Uhr, Nachtruhe, Titel, langsamer Zoom und Keine Videos.';

  @override
  String get tipFavoritesRound =>
      'Lieblingsbilder laufen am Frame als eigene Runde, auch über alle Alben.';

  @override
  String get tipNewAlbum => 'Neue Alben legst du über ⋮ → Neues Album an.';

  @override
  String get tipVideoQuality =>
      'Unter Videos senden wählst du, wie stark Videos verkleinert werden. Das spart Datenvolumen.';

  @override
  String get tipNewsIcon =>
      'Wird das Symbol oben Coral, wartet eine Einladung oder Anfrage auf dich.';

  @override
  String get captionDelete => 'Titel löschen';

  @override
  String get videoNone => 'Keine Videos';

  @override
  String get undo => 'Rückgängig';

  @override
  String get showOnMyFrame => 'Auf dem Frame zeigen';

  @override
  String get pickFrameToShow => 'Auf welchem Frame zeigen?';

  @override
  String get rememberFrame => 'Diesen Frame künftig immer nehmen';

  @override
  String get showOnFrameButton => 'Zeigen';

  @override
  String get preferredFrame => 'Bevorzugter Frame';

  @override
  String get preferredFrameAsk => 'Jedes Mal fragen';

  @override
  String get preferredFrameHint =>
      'Ein Tipp auf das Frame-Symbol im Album zeigt es dort sofort.';

  @override
  String get captionEdit => 'Titel bearbeiten';

  @override
  String get captionShort => 'Titel';

  @override
  String get showCaptions => 'Titel anzeigen';

  @override
  String get showCaptionsHint =>
      'Unten im Bild, wenn der Absender einen geschrieben hat.';

  @override
  String get allowCaptions => 'Titel ein- oder ausblenden';

  @override
  String get rotateWithDevice => 'Bild dreht sich mit dem Frame';

  @override
  String get recentCountLabel => 'Wie viele aktuelle Fotos';

  @override
  String quietPreset(String from, String to) {
    return '$from – $to Uhr';
  }

  @override
  String get alsoLabel => 'Dazu';

  @override
  String get rotateShort => 'Bild dreht sich mit';

  @override
  String get whoWatches => 'Wer schaut auf diesen Frame?';

  @override
  String get watchAll => 'Jemand, der alles selbst einstellen möchte';

  @override
  String get watchAllHint => 'Alle Knöpfe und Einstellungen direkt am Frame.';

  @override
  String get watchSimple => 'Einfach bedienen';

  @override
  String get watchSimpleHint =>
      'Zurück, Pause, Weiter, Neueste Fotos und Lieblingsbilder.';

  @override
  String get watchOnly => 'Nur zuschauen';

  @override
  String get watchOnlyHint =>
      'Keine Knöpfe. Die Fotos laufen von selbst, alles kommt aus der App.';

  @override
  String levelBadge(int n, String name) {
    return 'Stufe $n · $name';
  }

  @override
  String get whoWatchesLater =>
      'Später jederzeit änderbar unter Frame → ⋮ → Bedienung.';

  @override
  String get rotateWithDeviceHint =>
      'Hochkant oder quer gestellt, das Bild dreht mit. Auch wenn die automatische Drehung am Gerät aus ist.';

  @override
  String get homeSlideshowRecent => 'Aktuelles aus allen Alben';

  @override
  String get homeSlideshowRecentHint =>
      'Die neuesten Fotos und Videos, egal aus welchem Album';

  @override
  String get homeSlideshowRotateHint =>
      'Alles, was du sehen kannst, Album für Album';

  @override
  String get homeSlideshowOneAlbum => 'Ein Album …';

  @override
  String get homeSlideshowOneAlbumHint => 'Dann wählst du das Album aus';

  @override
  String get homeSlideshowSettingsHint =>
      'Dauer, Reihenfolge, Videos und Ton stellst du wie bisher in der Diashow über das Zahnrad ein.';

  @override
  String get homeSlideshowStart => 'Diashow starten';

  @override
  String get homeSlideshowPickAlbum => 'Welches Album?';

  @override
  String get homeSlideshowNothing =>
      'Hier gibt es noch keine Fotos oder Videos.';

  @override
  String slideshowPosition(int n, int total) {
    return '$n von $total';
  }

  @override
  String get tipAlbums01 =>
      'Ganz oben steht immer das Album, in dem zuletzt etwas passiert ist – wie bei WhatsApp.';

  @override
  String get tipAlbums02 =>
      'Ein Punkt neben einem Album heißt: Hier gibt es Neues, das du noch nicht gesehen hast.';

  @override
  String get tipAlbums03 =>
      'Unter dem Albumnamen siehst du, wer zuletzt etwas geschickt hat.';

  @override
  String get tipAlbums04 =>
      'Mit der Kamera oben rechts machst du schnell ein Foto und wählst danach das Album aus.';

  @override
  String get tipAlbums05 =>
      'Ein neues Album legst du auf der Seite deines Spaces an.';

  @override
  String get tipAlbums06 =>
      'Ein Album gehört immer zu einem Space – zum Beispiel deiner Familie.';

  @override
  String get tipAlbums07 =>
      'Tippe auf das Bild eines Albums, um es direkt zu öffnen.';

  @override
  String get tipAlbums08 =>
      'Ein Album ohne Fotos zeigt seine Anfangsbuchstaben – bis das erste Foto kommt.';

  @override
  String get tipAlbums09 =>
      'Über ⋮ → Code scannen trittst du mit einem QR-Code einem Album bei.';

  @override
  String get tipAlbums10 =>
      'Unten wechselst du zwischen Alben, Frames und Spaces.';

  @override
  String get tipAlbums11 =>
      'Ziehe die Liste nach unten, um sie sofort zu aktualisieren.';

  @override
  String get tipAlbums12 =>
      'Neue Fotos anderer erscheinen von selbst – du musst nichts tun.';

  @override
  String get tipAlbums13 =>
      'Auch ohne Internet siehst du die Alben, die du zuletzt geöffnet hast.';

  @override
  String get tipAlbums14 =>
      'Alben, die du verlässt, verschwinden aus deiner Liste – die anderen behalten sie.';

  @override
  String get tipAlbums15 =>
      'Ein Album kann gleichzeitig auf mehreren Frames laufen.';

  @override
  String get tipAlbums16 =>
      'Das Bild eines Albums kann der Admin jederzeit ändern.';

  @override
  String get tipAlbums17 =>
      'Neue Alben stehen erst ganz oben, sobald darin etwas passiert.';

  @override
  String get tipAlbums18 =>
      'Tipp: Lege für jede Gelegenheit ein eigenes Album an – Urlaub, Geburtstag, Kinder.';

  @override
  String get tipAlbums19 =>
      'Ein Album hat keine Größengrenze – schick so viele Fotos, wie du willst.';

  @override
  String get tipAlbum01 =>
      'Deine eigenen Fotos stehen rechts, die der anderen links – wie in einem Chat.';

  @override
  String get tipAlbum02 =>
      'Halte ein Foto lange gedrückt, um mehrere auszuwählen.';

  @override
  String get tipAlbum03 =>
      'Mit „Alle auswählen“ markierst du alle Fotos auf einmal.';

  @override
  String get tipAlbum04 =>
      'Mit + unten rechts schickst du Fotos und Videos aus deiner Galerie.';

  @override
  String get tipAlbum05 =>
      'Du kannst mehrere Fotos und Videos auf einmal auswählen und schicken.';

  @override
  String get tipAlbum06 =>
      'Beim Senden kannst du jedem Foto einen Titel geben.';

  @override
  String get tipAlbum07 =>
      'Einen Titel kannst du auch später noch ändern – im Vollbild oben.';

  @override
  String get tipAlbum08 =>
      'Fotos werden vor dem Senden verkleinert – das spart Zeit und Datenvolumen.';

  @override
  String get tipAlbum09 =>
      'Videos werden auf dem Handy verkleinert und sind dadurch schnell da.';

  @override
  String get tipAlbum10 =>
      'Ohne Internet wartet dein Foto mit einer kleinen Uhr und wird später geschickt.';

  @override
  String get tipAlbum11 =>
      'Ein Foto, das noch wartet, kannst du mit „Nicht senden“ zurückhalten.';

  @override
  String get tipAlbum12 =>
      'Deine Fotos werden auch geschickt, wenn du Smile schon geschlossen hast.';

  @override
  String get tipAlbum13 =>
      'Die Datumsangabe oben zeigt beim Blättern, von welchem Tag die Fotos sind.';

  @override
  String get tipAlbum14 =>
      'Wer ein Foto geschickt hat, steht mit Bild und Namen daneben.';

  @override
  String get tipAlbum15 =>
      'Mit „Ausblenden“ verschwindet ein Foto nur bei dir – die anderen sehen es weiter.';

  @override
  String get tipAlbum16 =>
      'Ausgeblendete Fotos holst du über ⋮ jederzeit wieder zurück.';

  @override
  String get tipAlbum17 =>
      '„Löschen“ entfernt ein Foto für alle – das darf nur, wer es geschickt hat, oder der Admin.';

  @override
  String get tipAlbum18 => 'Gelöschte Fotos liegen 30 Tage im Papierkorb.';

  @override
  String get tipAlbum19 =>
      'Über ⋮ startest du eine Diashow des Albums direkt am Handy.';

  @override
  String get tipAlbum20 =>
      'Tippe oben auf den Albumnamen, um zur Info-Seite des Albums zu kommen.';

  @override
  String get tipAlbum21 =>
      'Beim Senden und Empfangen gibt es einen kurzen Ton – abschaltbar in den Einstellungen.';

  @override
  String get tipAlbum22 =>
      'Videos zeigen ein kleines Symbol – tippe darauf, um sie abzuspielen.';

  @override
  String get tipAlbum23 =>
      'Schon angesehene Videos sind auch ohne Internet abspielbar.';

  @override
  String get tipAlbum24 =>
      'Neue Fotos anderer tauchen im offenen Album sofort auf.';

  @override
  String get tipViewer01 =>
      'Wische nach links und rechts, um durch alle Fotos und Videos zu blättern.';

  @override
  String get tipViewer02 => 'Mit zwei Fingern vergrößerst du ein Foto.';

  @override
  String get tipViewer03 =>
      'Doppeltippen vergrößert ein Foto – nochmal doppeltippen, und es ist wieder ganz.';

  @override
  String get tipViewer04 =>
      'Mit dem Herz oben machst du ein Foto zum Lieblingsbild eines Frames.';

  @override
  String get tipViewer05 =>
      'Mit dem Frame-Symbol oben zeigst du das Foto sofort am Frame.';

  @override
  String get tipViewer06 =>
      'Die Leiste oben bleibt beim Wischen stehen – ihre Knöpfe gelten fürs gezeigte Foto.';

  @override
  String get tipViewer07 =>
      'Im Vollbild siehst du das ganze Foto – im Album wird es manchmal angeschnitten.';

  @override
  String get tipViewer08 =>
      'Ein Titel steht unten im Bild – genau wie später am Frame.';

  @override
  String get tipViewer09 => 'Videos starten erst, wenn du zu ihnen wischst.';

  @override
  String get tipViewer10 =>
      'Tippe auf ein Video, um es anzuhalten oder weiterlaufen zu lassen.';

  @override
  String get tipViewer11 =>
      'Am Balken unten springst du in einem Video vor und zurück.';

  @override
  String get tipViewer12 =>
      'Mit dem Pfeil oben links kommst du zurück ins Album.';

  @override
  String get tipViewer13 =>
      'Ein vergrößertes Foto verschiebst du mit einem Finger.';

  @override
  String get tipViewer14 =>
      'Auch Fotos, die noch unterwegs sind, kannst du schon groß ansehen.';

  @override
  String get tipViewer15 =>
      'Mit dem Titel-Symbol oben gibst du einem Foto nachträglich einen Titel.';

  @override
  String get tipAlbumInfo01 =>
      'Hier siehst du, wer im Album ist und wer mitposten darf.';

  @override
  String get tipAlbumInfo02 =>
      'Mit „Einladen“ holst du weitere Personen ins Album.';

  @override
  String get tipAlbumInfo03 =>
      'Mit „Teilen“ zeigst du das Album einem anderen Space – zum Ansehen.';

  @override
  String get tipAlbumInfo04 =>
      'Geteilte Spaces sehen das Album, können aber nichts hineinschicken.';

  @override
  String get tipAlbumInfo05 =>
      'Tippe auf eine Person, um zu sehen, welche Rolle sie hat.';

  @override
  String get tipAlbumInfo06 =>
      'Der Admin kann Personen aus dem Album entfernen.';

  @override
  String get tipAlbumInfo07 =>
      'Unter „Läuft auf“ siehst du, auf welchen Frames das Album gerade läuft.';

  @override
  String get tipAlbumInfo08 =>
      'Mit „Auf Frame zeigen“ legst du das Album mit einem Tipp auf einen Frame.';

  @override
  String get tipAlbumInfo09 =>
      'Den Namen ändert der Admin mit einem Tipp auf den Namen.';

  @override
  String get tipAlbumInfo10 =>
      'Das Albumbild kann ein eigenes Foto oder ein Foto aus dem Album sein.';

  @override
  String get tipAlbumInfo11 =>
      'Ein geteiltes Album eines anderen Spaces nimmst du mit „Aus … entfernen“ wieder heraus.';

  @override
  String get tipAlbumInfo12 =>
      'Gehört dir ein Album nicht, bleibt es beim Entfernen beim Besitzer erhalten.';

  @override
  String get tipAlbumInfo13 =>
      '„Album verlassen“ beendet nur deine Mitgliedschaft – das Album bleibt bestehen.';

  @override
  String get tipAlbumInfo14 =>
      '„Album löschen“ legt das Album 30 Tage in den Papierkorb.';

  @override
  String get tipAlbumInfo15 =>
      'Beitrittsanfragen zum Album entscheidet der Admin unter Neuigkeiten.';

  @override
  String get tipInvite01 =>
      'Leute, die du schon aus Smile kennst, lädst du einfach mit ihrem Namen ein.';

  @override
  String get tipInvite02 =>
      'Mit einem QR-Code ist jemand neben dir sofort im Album – ohne Rückfrage.';

  @override
  String get tipInvite03 =>
      'Einen Einladungslink kannst du per WhatsApp oder SMS verschicken.';

  @override
  String get tipInvite04 =>
      'Ein abgetippter Code geht als Anfrage an den Admin – der entscheidet.';

  @override
  String get tipInvite05 =>
      'Über „Aus Kontakten“ findest du Leute aus deinem Telefonbuch, die schon Smile haben.';

  @override
  String get tipInvite06 =>
      'Wer Smile noch nicht hat, bekommt aus deinen Kontakten eine Einladung per SMS oder WhatsApp.';

  @override
  String get tipInvite07 => 'Ein Einladungscode gilt 24 Stunden.';

  @override
  String get tipInvite08 => 'Ein neuer Code macht den alten sofort ungültig.';

  @override
  String get tipInvite09 =>
      'Co-Admin und Frame-Admin wird man nur per Name oder QR-Code vor Ort.';

  @override
  String get tipInvite10 =>
      'Unbeantwortete Einladungen kannst du jederzeit zurückziehen.';

  @override
  String get tipInvite11 =>
      'Eingeladene sehen deine Einladung unter Neuigkeiten und entscheiden selbst.';

  @override
  String get tipInvite12 =>
      'Mit deinem Smile-Namen (@name) finden dich andere leichter.';

  @override
  String get tipInvite13 =>
      'Unter „Meine Karte“ zeigst du deinen eigenen QR-Code zum Scannen.';

  @override
  String get tipInvite14 =>
      'Offene Anfragen verfallen nach einiger Zeit von selbst.';

  @override
  String get tipFrames01 =>
      'Ein Frame ist ein Tablet, das deine Alben als Bilderrahmen zeigt.';

  @override
  String get tipFrames02 =>
      'Der grüne Punkt am Frame-Bild heißt: Der Frame ist gerade online.';

  @override
  String get tipFrames03 =>
      'Unter „Frames“ siehst du alle Frames, die du verwaltest.';

  @override
  String get tipFrames04 =>
      'Einen neuen Frame verbindest du mit einem QR-Code, den er beim ersten Start zeigt.';

  @override
  String get tipFrames05 =>
      'Ein neues Tablet kann einen alten Frame ersetzen – Alben und Einstellungen bleiben.';

  @override
  String get tipFrames06 =>
      'Unter „Einstellungen & Gerät“ siehst du Akku, Gerät und letzten Kontakt des Frames.';

  @override
  String get tipFrames07 =>
      'Ist ein Frame länger offline, bekommst du eine Nachricht.';

  @override
  String get tipFrames08 =>
      'Einen Frame kannst du vorübergehend sperren – und später wieder freigeben.';

  @override
  String get tipFrames09 =>
      'Den Namen und das Bild eines Frames änderst du unter „Einstellungen & Gerät“.';

  @override
  String get tipFrames10 => 'Auf einem Frame können mehrere Alben laufen.';

  @override
  String get tipFrames11 =>
      '„Alben verwalten“ legt fest, welche Alben ein Frame zeigt.';

  @override
  String get tipFrames12 =>
      'Ein Frame zeigt auch Alben, die mit seinem Space geteilt sind.';

  @override
  String get tipFrames13 =>
      'Der Frame merkt sich alle Fotos – er zeigt sie auch ohne Internet weiter.';

  @override
  String get tipFrames14 => 'Mit der Nachtruhe bleibt der Frame nachts dunkel.';

  @override
  String get tipFrames15 =>
      'Tipp: Hefte die Smile-App am Tablet an, dann kann niemand versehentlich hinaus.';

  @override
  String get tipFrames16 =>
      'Mit „Große Uhr“ zeigt der Frame Datum und Uhrzeit groß – praktisch für Oma.';

  @override
  String get tipFrames17 =>
      'Wer ein Foto geschickt hat, steht am Frame oben links.';

  @override
  String get tipFrames18 =>
      'Ein Frame dreht sich mit dem Tablet – wenn du es so einstellst.';

  @override
  String get tipFrames19 =>
      'Ein gelöschter Frame zeigt wieder den QR-Code zum Verbinden.';

  @override
  String get tipFrame01 =>
      'Tippe auf ein Album im Streifen oben, um es sofort am Frame zu zeigen.';

  @override
  String get tipFrame02 =>
      '„Läuft gerade“ zeigt, was der Frame in diesem Moment abspielt.';

  @override
  String get tipFrame03 =>
      'Mit der Fernbedienung hältst du den Frame an oder blätterst weiter.';

  @override
  String get tipFrame04 =>
      '„Neueste 20 Fotos abspielen“ zeigt die neuesten Fotos aller Alben.';

  @override
  String get tipFrame05 =>
      'Lieblingsbilder sind eine eigene Auswahl nur für diesen Frame.';

  @override
  String get tipFrame06 =>
      'Unter „Alle ansehen“ siehst du alle Lieblingsbilder eines Frames.';

  @override
  String get tipFrame07 =>
      'Mit „Ton bei Videos“ entscheidest du, ob Videos am Frame Ton haben.';

  @override
  String get tipFrame08 =>
      'Die Kachel „Bedienstufe“ legt fest, was man am Frame selbst tun kann.';

  @override
  String get tipFrame09 =>
      'Mit „Frame-Admin einladen“ darf jemand anderes diesen Frame bedienen – zum Beispiel die Eltern eines Kindes.';

  @override
  String get tipFrame10 =>
      'Ein Frame-Admin bestimmt Bedienung und Alben – aber nicht Name, Gerät oder Löschen.';

  @override
  String get tipFrame11 =>
      'Unter „Am Frame entsperren“ legst du einen Code für den Frame fest.';

  @override
  String get tipFrame12 =>
      'Mit dem Code zeigt der Frame nach langem Druck auf die Uhr alle Knöpfe.';

  @override
  String get tipFrame13 =>
      'Der entsperrte Frame sperrt sich nach 2 Minuten ohne Berührung von selbst.';

  @override
  String get tipFrame14 => 'Ohne Code lässt sich am Frame nichts entsperren.';

  @override
  String get tipFrame15 =>
      'Das Abzeichen „Frame-Admin“ zeigt Frames, die du für jemand anderen bedienst.';

  @override
  String get tipControls01 =>
      'Easy Stopping: Ein Tippen auf den Frame hält das Bild an, noch eins lässt es weiterlaufen.';

  @override
  String get tipControls02 =>
      'Ein angehaltener Frame läuft nach 10 Minuten von selbst weiter.';

  @override
  String get tipControls03 =>
      'Stufe 1 „Nur zuschauen“: Am Frame geht nur Antippen zum Anhalten.';

  @override
  String get tipControls04 =>
      'Stufe 2: Pause und ein großer Weiter-Knopf – ideal für den Anfang.';

  @override
  String get tipControls05 => 'Stufe 3: Dazu Zurück und die neuesten Fotos.';

  @override
  String get tipControls06 =>
      'Stufe 4: Dazu Übersicht, Album wechseln, Anzeigedauer und Titel.';

  @override
  String get tipControls07 =>
      'Stufe 5: Am Frame lässt sich alles selbst einstellen.';

  @override
  String get tipControls08 =>
      'Einzelne Knöpfe kannst du auch einzeln erlauben – das ist dann „Eigene Auswahl“.';

  @override
  String get tipControls09 =>
      'Am Frame wischt man nach links zum nächsten Foto – ab Stufe 2.';

  @override
  String get tipControls10 =>
      'Nach rechts wischen geht zum vorigen Foto – ab Stufe 3.';

  @override
  String get tipControls11 =>
      'Mit „Merken“ macht man direkt am Frame ein Foto zum Lieblingsbild.';

  @override
  String get tipControls12 =>
      'Die „Übersicht“ am Frame zeigt alle Fotos als Kacheln zum Antippen.';

  @override
  String get tipControls13 =>
      'Mit „Album“ wechselt man am Frame selbst das Album.';

  @override
  String get tipControls14 =>
      'Die Knöpfe am Frame verschwinden nach ein paar Sekunden von selbst.';

  @override
  String get tipControls15 =>
      'Die Bedienstufe kannst du jederzeit ändern – der Frame folgt sofort.';

  @override
  String get tipPlayback01 =>
      '„Was läuft“: ein Album, alle Alben im Wechsel, die neuesten oder die Lieblingsbilder.';

  @override
  String get tipPlayback02 =>
      'Die Reihenfolge: neueste zuerst, älteste zuerst oder gemischt.';

  @override
  String get tipPlayback03 =>
      'Die Anzeigedauer bestimmt, wie lange jedes Foto zu sehen ist.';

  @override
  String get tipPlayback04 =>
      'Am Ende eines Albums fängt der Frame von vorn an – oder zeigt die Übersicht.';

  @override
  String get tipPlayback05 =>
      'Videos können ganz laufen, nur so lang wie ein Foto, oder gar nicht.';

  @override
  String get tipPlayback06 =>
      '„Füllen“: Fotos füllen den Bildschirm – oder werden ganz gezeigt.';

  @override
  String get tipPlayback07 =>
      '„Automatisch füllen“ füllt nur, wenn das Foto zum Bildschirm passt.';

  @override
  String get tipPlayback08 => 'Das langsame Zoomen bringt Leben in die Fotos.';

  @override
  String get tipPlayback09 =>
      '„Neues gleich zeigen“: Ein neues Foto erscheint sofort am Frame.';

  @override
  String get tipPlayback10 =>
      '„Ton bei neuen Fotos“: Der Frame meldet sich mit einem Dreiklang.';

  @override
  String get tipPlayback11 =>
      '„Erinnern, bis jemand schaut“: Der Ton kommt stündlich wieder, höchstens dreimal.';

  @override
  String get tipPlayback12 =>
      '„Hinweis auf Neues“: Ein leuchtender Hinweis bleibt, bis jemand tippt.';

  @override
  String get tipPlayback13 =>
      'Ein Tippen auf den Hinweis zeigt genau die neuen Fotos.';

  @override
  String get tipPlayback14 => 'Die Nachtruhe schaltet den Frame nachts dunkel.';

  @override
  String get tipPlayback15 =>
      'In der Nachtruhe bleibt der Frame still – auch bei neuen Fotos.';

  @override
  String get tipPlayback16 =>
      '„Große Uhr“ zeigt Datum und Uhrzeit groß am Frame.';

  @override
  String get tipPlayback17 =>
      '„Absender zeigen“ blendet ein, wer ein Foto geschickt hat.';

  @override
  String get tipPlayback18 => '„Titel zeigen“ blendet die Titel der Fotos ein.';

  @override
  String get tipPlayback19 =>
      '„Mit dem Gerät drehen“ dreht den Frame auch, wenn das Tablet das sonst nicht tut.';

  @override
  String get tipPlayback20 =>
      'Jede Änderung hier ist in unter einer Sekunde am Frame.';

  @override
  String get tipFavorites01 =>
      'Lieblingsbilder sind pro Frame – jeder Frame hat seine eigenen.';

  @override
  String get tipFavorites02 =>
      'Mit dem Herz im Vollbild machst du ein Foto zum Lieblingsbild.';

  @override
  String get tipFavorites03 =>
      'Bei mehreren Frames wählst du, für welchen Frame das Herz gilt.';

  @override
  String get tipFavorites04 =>
      'Mit „Hinzufügen“ wählst du mehrere Lieblingsbilder auf einmal aus.';

  @override
  String get tipFavorites05 =>
      'Lieblingsbilder kann man am Frame als eigene Runde abspielen.';

  @override
  String get tipFavorites06 =>
      'Wer ein Lieblingsbild markiert hat, siehst du in der Liste.';

  @override
  String get tipFavorites07 =>
      'Ein Lieblingsbild, das am Frame gemerkt wurde, steht dort mit „Am Frame“.';

  @override
  String get tipFavorites08 =>
      'Über ⋮ entfernst du alle Lieblingsbilder eines Frames auf einmal.';

  @override
  String get tipFavorites09 =>
      'Ist „Lieblingsbilder“ eingestellt, ist der Knopf am Frame eingerahmt.';

  @override
  String get tipSpaces01 =>
      'Ein Space ist dein Haushalt oder deine Familie – mit Alben und Frames.';

  @override
  String get tipSpaces02 => 'Jeder Space hat einen Admin, der alles darf.';

  @override
  String get tipSpaces03 =>
      'Co-Admins verwalten den Space mit – Alben, Frames und Personen.';

  @override
  String get tipSpaces04 =>
      'Mit „Co-Admin einladen“ bekommst du Hilfe beim Verwalten.';

  @override
  String get tipSpaces05 =>
      'Der Admin kann seine Rolle an einen Co-Admin übergeben.';

  @override
  String get tipSpaces06 =>
      'Ein Co-Admin kann die Rolle jederzeit selbst abgeben.';

  @override
  String get tipSpaces07 => 'Einen Space löschen kann nur der Admin.';

  @override
  String get tipSpaces08 => 'Ein gelöschter Space liegt 30 Tage im Papierkorb.';

  @override
  String get tipSpaces09 =>
      'Du kannst in mehreren Spaces sein – zum Beispiel bei dir und bei den Eltern.';

  @override
  String get tipSpaces10 =>
      'Ein Space kann Alben eines anderen Spaces zum Ansehen bekommen.';

  @override
  String get tipSpaces11 => 'Jeder Space kann ein eigenes Bild haben.';

  @override
  String get tipSpaces12 => 'Neue Alben legst du in einem Space an.';

  @override
  String get tipSpaces13 => 'Neue Frames verbindest du über einen Space.';

  @override
  String get tipSpaces14 =>
      'Wer einen Space verwaltet, ist automatisch in allen seinen Alben.';

  @override
  String get tipSpaces15 =>
      'Den Namen des Spaces ändert der Admin mit einem Tipp darauf.';

  @override
  String get tipNews01 =>
      'Unter Neuigkeiten findest du Einladungen, Anfragen und alle Nachrichten der letzten 30 Tage.';

  @override
  String get tipNews02 =>
      'Ein roter Punkt an Neuigkeiten heißt: Hier wartet etwas auf deine Antwort.';

  @override
  String get tipNews03 => 'Einladungen nimmst du hier an – oder lehnst sie ab.';

  @override
  String get tipNews04 =>
      'Als Admin entscheidest du hier über Beitrittsanfragen.';

  @override
  String get tipNews05 => 'Der Papierkorb liegt bei den Neuigkeiten.';

  @override
  String get tipNews06 =>
      'Aus dem Papierkorb holst du Gelöschtes 30 Tage lang zurück.';

  @override
  String get tipNews07 =>
      'Nach 30 Tagen wird der Papierkorb von selbst geleert.';

  @override
  String get tipNews08 =>
      'Tippe auf eine Nachricht, um direkt zum Album oder Frame zu kommen.';

  @override
  String get tipNews09 =>
      'Auch Pushes, die du weggewischt hast, findest du hier wieder.';

  @override
  String get tipNews10 =>
      'Viele neue Fotos derselben Person kommen als eine Nachricht.';

  @override
  String get tipSettings01 =>
      'Dein Name ist Pflicht – so wissen alle, von wem ein Foto kommt.';

  @override
  String get tipSettings02 =>
      'Ohne eigenes Bild zeigt Smile deine Anfangsbuchstaben.';

  @override
  String get tipSettings03 => 'Tippe auf dein Bild, um es zu ändern.';

  @override
  String get tipSettings04 =>
      'Unter „Smile-Name“ wählst du einen @Namen, mit dem dich andere finden.';

  @override
  String get tipSettings05 =>
      '„Meine Karte“ zeigt deinen QR-Code – andere scannen ihn zum Einladen.';

  @override
  String get tipSettings06 =>
      'Unter „Töne im Album“ schaltest du die Plopp-Töne ein oder aus.';

  @override
  String get tipSettings07 => 'Bei lautlosem Handy bleibt Smile still.';

  @override
  String get tipSettings08 =>
      'Unter „Videoqualität“ wählst du, wie stark Videos verkleinert werden.';

  @override
  String get tipSettings09 =>
      '„Tipps von vorne zeigen“ bringt alle Tipps zurück.';

  @override
  String get tipSettings10 =>
      '„Keine Tipps mehr“ schaltet alle Tipps ab – hier wieder ein.';

  @override
  String get tipSettings11 =>
      'Benachrichtigungen kommen für neue Fotos, Einladungen und Änderungen an deinen Frames.';

  @override
  String get tipSettings12 =>
      'Dein Konto kannst du in den Einstellungen löschen – mit allem, was dir gehört.';

  @override
  String get tipSettings13 =>
      'Abmelden ist jederzeit möglich – deine Alben bleiben auf dem Server.';

  @override
  String get tipSettings14 =>
      'Smile meldet sich mit einem Code per E-Mail an – ganz ohne Passwort.';

  @override
  String get tipSettings15 =>
      'Smile ist dunkel gestaltet – so leuchten die Fotos am schönsten.';

  @override
  String get tipGeneral01 =>
      'Smile ist wie WhatsApp für Fotos – nur ohne Chat und mit Bilderrahmen.';

  @override
  String get tipGeneral02 => 'Alles, was du änderst, sehen die anderen sofort.';

  @override
  String get tipGeneral03 =>
      'Smile arbeitet auch offline – Änderungen werden nachgeschickt.';

  @override
  String get tipGeneral04 =>
      'Fotos in Smile sind privat – nur Mitglieder eines Albums sehen sie.';

  @override
  String get tipGeneral05 =>
      'Wer ein Album verlässt, sieht dessen Fotos danach nicht mehr.';

  @override
  String get tipGeneral06 =>
      'Lange drücken öffnet fast überall weitere Möglichkeiten.';

  @override
  String get tipGeneral07 =>
      'Das ⋮ oben rechts hat auf jeder Seite weitere Funktionen.';

  @override
  String get tipGeneral08 => 'Nach unten ziehen aktualisiert fast jede Liste.';

  @override
  String get tipGeneral09 =>
      'Ein Tipp auf einen Namen oder ein Bild zeigt meistens mehr.';

  @override
  String get tipGeneral10 =>
      'Smile schickt nur Fotos und Videos – keine Nachrichten.';

  @override
  String get tipGeneral11 =>
      'Ein Album ist kein Einzelchat: Es kann immer weitere Leute aufnehmen.';

  @override
  String get tipGeneral12 =>
      'Ein Frame braucht kein eigenes Konto – er wird mit einem Code verbunden.';

  @override
  String get tipGeneral13 => 'Fotos werden verschlüsselt übertragen.';

  @override
  String membershipRequestFailed(String reason) {
    return 'Anfrage fehlgeschlagen: $reason';
  }

  @override
  String withdrawFailed(String reason) {
    return 'Zurückziehen fehlgeschlagen: $reason';
  }

  @override
  String get deleteFailedShort => 'Löschen fehlgeschlagen.';

  @override
  String get hideFailedShort => 'Ausblenden fehlgeschlagen.';

  @override
  String get unhideFailedShort => 'Einblenden fehlgeschlagen.';

  @override
  String photosNotDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Fotos konnten nicht gelöscht werden (nicht deine eigenen).',
      one: '1 Foto konnte nicht gelöscht werden (nicht dein eigenes).',
    );
    return '$_temp0';
  }

  @override
  String photosNotPossible(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bei $count Fotos nicht möglich.',
      one: 'Bei 1 Foto nicht möglich.',
    );
    return '$_temp0';
  }

  @override
  String get loginIntro =>
      'Melde dich mit deiner E-Mail-Adresse an. Wir senden dir einen 6-stelligen Code.';

  @override
  String get loginRequestCode => 'Code anfordern';

  @override
  String loginCodeSent(String email) {
    return 'Wir haben einen Code an $email gesendet. Bitte gib ihn ein.';
  }

  @override
  String get loginConfirm => 'Bestätigen';

  @override
  String get loginOtherEmail => 'Andere E-Mail-Adresse verwenden';

  @override
  String avatarUploadFailed(String reason) {
    return 'Bild konnte nicht hochgeladen werden: $reason';
  }

  @override
  String get enterYourName => 'Bitte gib deinen Namen ein.';

  @override
  String saveFailedWith(String reason) {
    return 'Speichern fehlgeschlagen: $reason';
  }

  @override
  String get avatarUrlInvalid => 'Das ist keine gültige Internetadresse.';

  @override
  String get avatarUrlUnreachable =>
      'Das Bild konnte nicht geladen werden. Bitte prüfe die Adresse.';

  @override
  String get avatarUrlNotImage => 'Die Adresse zeigt auf kein Bild.';

  @override
  String get notificationChannelDescription =>
      'Neue Fotos, Einladungen, Anfragen und Änderungen in deinen Alben und Spaces';

  @override
  String get errUserNotFound => 'Diese Person hat noch keinen Smile-Account.';

  @override
  String get errNotAlbumManager =>
      'Du bist nicht berechtigt, dieses Album zu verwalten.';

  @override
  String get errRequestPending =>
      'Es gibt bereits eine offene Einladung/Anfrage.';

  @override
  String get errNotSpaceAdmin => 'Nur der Admin kann das tun.';

  @override
  String get errAlreadyAdmin => 'Diese Person ist bereits Admin.';

  @override
  String get errAlreadyCoAdmin => 'Diese Person ist bereits Co-Admin.';

  @override
  String get errInvitePending => 'Es gibt bereits eine offene Einladung.';

  @override
  String get errNotCoAdmin => 'Diese Person ist kein Co-Admin.';

  @override
  String get errGeneric =>
      'Das hat leider nicht geklappt. Bitte versuche es noch einmal.';

  @override
  String get noLongerAvailable =>
      'Das ist nicht mehr verfügbar – gelöscht oder kein Zugriff mehr.';

  @override
  String get dateToday => 'Heute';

  @override
  String get dateYesterday => 'Gestern';

  @override
  String get timeJustNow => 'gerade eben';

  @override
  String timeMinutesAgo(int minutes) {
    return 'vor $minutes Min.';
  }

  @override
  String timeHoursAgo(int hours) {
    return 'vor $hours Std.';
  }

  @override
  String get dateNumericPattern => 'dd.MM.yyyy';

  @override
  String get dateNumericShortPattern => 'dd.MM.yy';

  @override
  String get licenseOther => 'Lizenz';

  @override
  String get language => 'Sprache';

  @override
  String get languageAutomatic => 'Automatisch';

  @override
  String languageAutomaticValue(String language) {
    return 'Automatisch ($language)';
  }

  @override
  String languageLikePhone(String language) {
    return 'Wie das Handy: $language';
  }

  @override
  String get languageSheetHint =>
      'Gilt für die App und die Mitteilungen, die du bekommst.';

  @override
  String get frameLanguage => 'Sprache am Frame';

  @override
  String get frameLanguageLikeTablet => 'Wie das Tablet';

  @override
  String loginCodeStillValid(String email) {
    return 'Wir haben dir gerade schon einen Code an $email geschickt. Er gilt noch – bitte gib ihn ein.';
  }

  @override
  String get languageFollowsPhone => 'Wie das Handy';

  @override
  String get planSectionTitle => 'Frame-Abo';

  @override
  String get planTrial => 'Probezeit';

  @override
  String planDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'noch $days Tage',
      one: 'noch 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String planTrialUntil(String date) {
    return 'Alle Frames bekommen neue Fotos bis $date';
  }

  @override
  String planFrames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Frames',
      one: '1 Frame',
    );
    return '$_temp0';
  }

  @override
  String get planActive => 'aktiv';

  @override
  String get planSourceVoucher => 'Gutschein';

  @override
  String get planSourcePlay => 'Google Play';

  @override
  String get planSourceStaff => 'Smile';

  @override
  String planUntil(String date) {
    return 'bis $date';
  }

  @override
  String get planNoEnd => 'ohne Ablauf';

  @override
  String get planNone => 'Kein Abo';

  @override
  String get planNoneText =>
      'Die Frames zeigen weiter alle Fotos, bekommen aber keine neuen.';

  @override
  String get planFree => 'Kostenlos';

  @override
  String get planTrialStartsWithFrame =>
      'Alben und Fotos sind kostenlos. Mit dem ersten Frame beginnen 2 Monate Probezeit.';

  @override
  String planFramesUsed(int used, int count) {
    return '$used von $count Frames';
  }

  @override
  String planVideoLength(int minutes) {
    return 'Videos bis $minutes Minuten';
  }

  @override
  String get choosePlan => 'Abo wählen';

  @override
  String get redeemVoucher => 'Gutschein einlösen';

  @override
  String planForSpace(String space) {
    return 'Für den ganzen Space „$space“. Mitglieder zahlen nie etwas.';
  }

  @override
  String get planTierMore => 'Mehr als 5';

  @override
  String planTierDetails(int gb, int minutes) {
    return '$gb GB · Videos $minutes Min.';
  }

  @override
  String get planTierMoreDetails => 'je Frame +20 GB · 15 Min.';

  @override
  String get planPerMonth => 'pro Monat';

  @override
  String get planPerExtraFrame => 'je Frame';

  @override
  String get planYearlyHint => 'Jährlich zahlen: 2 Monate geschenkt';

  @override
  String get planYours => 'deins';

  @override
  String get planBuySoon =>
      'Kaufen geht bald direkt hier. Bis dahin mit einem Gutschein.';

  @override
  String get voucherForSpace => 'Für den Space';

  @override
  String get voucherChangeSpace => 'ändern';

  @override
  String get voucherEnterCode => 'Gib den Code von deiner Karte ein';

  @override
  String get voucherCodeHint => 'SMILE-XXXX-XXXX';

  @override
  String get voucherRedeem => 'Einlösen';

  @override
  String get voucherScan => 'QR-Code scannen';

  @override
  String get voucherCodeNote => 'Groß- und Kleinschreibung ist egal.';

  @override
  String get voucherDone => 'Gutschein eingelöst';

  @override
  String voucherDoneText(String space, String frames, String date) {
    return '$space hat jetzt $frames bis $date.';
  }

  @override
  String voucherDoneLater(
    String space,
    String frames,
    String start,
    String date,
  ) {
    return '$space hat $frames vom $start bis $date – direkt nach dem, was schon läuft.';
  }

  @override
  String voucherGiftFrom(String name) {
    return 'Ein Geschenk von $name';
  }

  @override
  String get voucherNotFound =>
      'Diesen Code gibt es nicht. Prüf ihn bitte noch einmal.';

  @override
  String get voucherAlreadyUsed => 'Dieser Code wurde schon verwendet.';

  @override
  String get voucherExpired => 'Dieser Code ist abgelaufen.';

  @override
  String get voucherBlocked => 'Dieser Code gilt nicht mehr.';

  @override
  String get voucherRateLimited =>
      'Zu viele Versuche. Bitte versuch es in einer Stunde wieder.';

  @override
  String get voucherNotManager =>
      'Nur die Admins eines Spaces können einen Gutschein einlösen.';

  @override
  String get voucherNoSpace =>
      'Leg zuerst einen Space an – der Gutschein gilt dann für ihn.';

  @override
  String get voucherPickSpace => 'Für welchen Space?';

  @override
  String get frameNotCovered =>
      'Bekommt keine neuen Fotos – mehr Frames als im Abo';

  @override
  String get frameNoPlan => 'Bekommt keine neuen Fotos – kein Abo';

  @override
  String get sendFailedSpaceFull =>
      'Der Speicher dieses Spaces ist voll – nicht gesendet. Die Admins können Platz schaffen oder ein größeres Abo wählen.';
}
