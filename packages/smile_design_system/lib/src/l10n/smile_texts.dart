import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'smile_texts_de.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of SmileTexts
/// returned by `SmileTexts.of(context)`.
///
/// Applications need to include `SmileTexts.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/smile_texts.dart';
///
/// return MaterialApp(
///   localizationsDelegates: SmileTexts.localizationsDelegates,
///   supportedLocales: SmileTexts.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the SmileTexts.supportedLocales
/// property.
abstract class SmileTexts {
  SmileTexts(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static SmileTexts of(BuildContext context) {
    return Localizations.of<SmileTexts>(context, SmileTexts)!;
  }

  static const LocalizationsDelegate<SmileTexts> delegate =
      _SmileTextsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('de')];

  /// No description provided for @space.
  ///
  /// In de, this message translates to:
  /// **'Space'**
  String get space;

  /// No description provided for @spaces.
  ///
  /// In de, this message translates to:
  /// **'Spaces'**
  String get spaces;

  /// No description provided for @spaceCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Space} other{{count} Spaces}}'**
  String spaceCount(int count);

  /// No description provided for @album.
  ///
  /// In de, this message translates to:
  /// **'Album'**
  String get album;

  /// No description provided for @albums.
  ///
  /// In de, this message translates to:
  /// **'Alben'**
  String get albums;

  /// No description provided for @albumCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Album} other{{count} Alben}}'**
  String albumCount(int count);

  /// No description provided for @frame.
  ///
  /// In de, this message translates to:
  /// **'Frame'**
  String get frame;

  /// No description provided for @frames.
  ///
  /// In de, this message translates to:
  /// **'Frames'**
  String get frames;

  /// No description provided for @frameCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Frame} other{{count} Frames}}'**
  String frameCount(int count);

  /// No description provided for @person.
  ///
  /// In de, this message translates to:
  /// **'Person'**
  String get person;

  /// No description provided for @persons.
  ///
  /// In de, this message translates to:
  /// **'Personen'**
  String get persons;

  /// No description provided for @personCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Person} other{{count} Personen}}'**
  String personCount(int count);

  /// No description provided for @profile.
  ///
  /// In de, this message translates to:
  /// **'Profil'**
  String get profile;

  /// No description provided for @you.
  ///
  /// In de, this message translates to:
  /// **'Du'**
  String get you;

  /// No description provided for @roleAdmin.
  ///
  /// In de, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @roleCoAdmin.
  ///
  /// In de, this message translates to:
  /// **'Co-Admin'**
  String get roleCoAdmin;

  /// No description provided for @roleMember.
  ///
  /// In de, this message translates to:
  /// **'Member'**
  String get roleMember;

  /// No description provided for @roleViewer.
  ///
  /// In de, this message translates to:
  /// **'Viewer'**
  String get roleViewer;

  /// No description provided for @admins.
  ///
  /// In de, this message translates to:
  /// **'Admins'**
  String get admins;

  /// No description provided for @sharedWith.
  ///
  /// In de, this message translates to:
  /// **'Shared with'**
  String get sharedWith;

  /// No description provided for @sharedWithSpace.
  ///
  /// In de, this message translates to:
  /// **'Shared with {space}'**
  String sharedWithSpace(String space);

  /// No description provided for @news.
  ///
  /// In de, this message translates to:
  /// **'Neuigkeiten'**
  String get news;

  /// No description provided for @newsWaiting.
  ///
  /// In de, this message translates to:
  /// **'Neuigkeiten, es wartet etwas auf dich'**
  String get newsWaiting;

  /// No description provided for @actionSendPhoto.
  ///
  /// In de, this message translates to:
  /// **'Foto senden'**
  String get actionSendPhoto;

  /// No description provided for @actionInvite.
  ///
  /// In de, this message translates to:
  /// **'Einladen'**
  String get actionInvite;

  /// No description provided for @actionShare.
  ///
  /// In de, this message translates to:
  /// **'Mit Space teilen'**
  String get actionShare;

  /// No description provided for @actionAdd.
  ///
  /// In de, this message translates to:
  /// **'Neu anlegen'**
  String get actionAdd;

  /// No description provided for @actionRemove.
  ///
  /// In de, this message translates to:
  /// **'Entfernen'**
  String get actionRemove;

  /// No description provided for @actionLeave.
  ///
  /// In de, this message translates to:
  /// **'Verlassen'**
  String get actionLeave;

  /// No description provided for @actionDelete.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get actionDelete;

  /// No description provided for @actionRestore.
  ///
  /// In de, this message translates to:
  /// **'Wiederherstellen'**
  String get actionRestore;

  /// No description provided for @actionHandOver.
  ///
  /// In de, this message translates to:
  /// **'Admin übergeben'**
  String get actionHandOver;

  /// No description provided for @actionInviteCode.
  ///
  /// In de, this message translates to:
  /// **'Einladungscode'**
  String get actionInviteCode;

  /// No description provided for @actionConnect.
  ///
  /// In de, this message translates to:
  /// **'Verbinden'**
  String get actionConnect;

  /// No description provided for @actionCancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get actionCancel;

  /// No description provided for @actionConfirm.
  ///
  /// In de, this message translates to:
  /// **'OK'**
  String get actionConfirm;

  /// No description provided for @firstStepsWelcome.
  ///
  /// In de, this message translates to:
  /// **'Willkommen bei Smile'**
  String get firstStepsWelcome;

  /// No description provided for @firstStepsInvited.
  ///
  /// In de, this message translates to:
  /// **'Ich wurde eingeladen'**
  String get firstStepsInvited;

  /// No description provided for @firstStepsInvitedHint.
  ///
  /// In de, this message translates to:
  /// **'Deine Einladung findest du unter Neuigkeiten'**
  String get firstStepsInvitedHint;

  /// No description provided for @firstStepsSetup.
  ///
  /// In de, this message translates to:
  /// **'Ich richte Smile ein'**
  String get firstStepsSetup;

  /// No description provided for @firstStepsSetupHint.
  ///
  /// In de, this message translates to:
  /// **'Space für dein Zuhause oder deinen Betrieb anlegen'**
  String get firstStepsSetupHint;

  /// No description provided for @firstStepsQuestion.
  ///
  /// In de, this message translates to:
  /// **'Hier erscheinen deine Alben. Wie möchtest du anfangen?'**
  String get firstStepsQuestion;

  /// No description provided for @firstStepsYourEmail.
  ///
  /// In de, this message translates to:
  /// **'Eingeladen wirst du über deine E-Mail-Adresse {email}'**
  String firstStepsYourEmail(String email);

  /// No description provided for @albumsLoadError.
  ///
  /// In de, this message translates to:
  /// **'Alben konnten nicht geladen werden: {error}'**
  String albumsLoadError(String error);

  /// No description provided for @albumsEmptyTitle.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Alben'**
  String get albumsEmptyTitle;

  /// No description provided for @albumsEmptyMessage.
  ///
  /// In de, this message translates to:
  /// **'Lege einen Space an oder nimm eine Einladung an.'**
  String get albumsEmptyMessage;

  /// No description provided for @openSpaces.
  ///
  /// In de, this message translates to:
  /// **'Spaces öffnen'**
  String get openSpaces;

  /// No description provided for @albumInfo.
  ///
  /// In de, this message translates to:
  /// **'Infos zum Album'**
  String get albumInfo;

  /// No description provided for @addMedia.
  ///
  /// In de, this message translates to:
  /// **'Foto oder Video teilen'**
  String get addMedia;

  /// No description provided for @feedEmptyTitle.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Fotos'**
  String get feedEmptyTitle;

  /// No description provided for @feedEmptyMemberHint.
  ///
  /// In de, this message translates to:
  /// **'Tippe auf +, um das erste Foto oder Video zu teilen.'**
  String get feedEmptyMemberHint;

  /// No description provided for @hiddenPhotos.
  ///
  /// In de, this message translates to:
  /// **'Ausgeblendete Fotos'**
  String get hiddenPhotos;

  /// No description provided for @hiddenPhotosEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine ausgeblendeten Fotos'**
  String get hiddenPhotosEmpty;

  /// No description provided for @actionHide.
  ///
  /// In de, this message translates to:
  /// **'Ausblenden'**
  String get actionHide;

  /// No description provided for @actionUnhide.
  ///
  /// In de, this message translates to:
  /// **'Einblenden'**
  String get actionUnhide;

  /// No description provided for @selectedCount.
  ///
  /// In de, this message translates to:
  /// **'{count} ausgewählt'**
  String selectedCount(int count);

  /// No description provided for @requestMembership.
  ///
  /// In de, this message translates to:
  /// **'Member werden'**
  String get requestMembership;

  /// No description provided for @requestSent.
  ///
  /// In de, this message translates to:
  /// **'Anfrage gesendet'**
  String get requestSent;

  /// No description provided for @sendTo.
  ///
  /// In de, this message translates to:
  /// **'Senden an …'**
  String get sendTo;

  /// No description provided for @sendToNoAlbum.
  ///
  /// In de, this message translates to:
  /// **'Du bist noch in keinem Album, in dem du Fotos teilen kannst.'**
  String get sendToNoAlbum;

  /// No description provided for @albumInSpace.
  ///
  /// In de, this message translates to:
  /// **'Album in {space}'**
  String albumInSpace(String space);

  /// No description provided for @rename.
  ///
  /// In de, this message translates to:
  /// **'Umbenennen'**
  String get rename;

  /// No description provided for @renameAlbum.
  ///
  /// In de, this message translates to:
  /// **'Album umbenennen'**
  String get renameAlbum;

  /// No description provided for @name.
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @save.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get save;

  /// No description provided for @inviteToAlbum.
  ///
  /// In de, this message translates to:
  /// **'Person einladen'**
  String get inviteToAlbum;

  /// No description provided for @inviteToAlbumHint.
  ///
  /// In de, this message translates to:
  /// **'Die Person braucht bereits einen Smile-Account. Sie kann die Einladung annehmen oder ablehnen.'**
  String get inviteToAlbumHint;

  /// No description provided for @shareWithSpace.
  ///
  /// In de, this message translates to:
  /// **'Mit einem Space teilen'**
  String get shareWithSpace;

  /// No description provided for @shareWithSpaceHint.
  ///
  /// In de, this message translates to:
  /// **'Ein Admin des anderen Space kann annehmen. Dessen Personen und Frames sehen das Album dann, tragen aber nichts bei.'**
  String get shareWithSpaceHint;

  /// No description provided for @emailOfAdmin.
  ///
  /// In de, this message translates to:
  /// **'E-Mail-Adresse'**
  String get emailOfAdmin;

  /// No description provided for @invitedWaiting.
  ///
  /// In de, this message translates to:
  /// **'Eingeladen · Annahme ausstehend'**
  String get invitedWaiting;

  /// No description provided for @wantsToJoin.
  ///
  /// In de, this message translates to:
  /// **'Möchte Member werden'**
  String get wantsToJoin;

  /// No description provided for @wantsToShare.
  ///
  /// In de, this message translates to:
  /// **'Möchte das Album mit dem eigenen Space sehen'**
  String get wantsToShare;

  /// No description provided for @sharedViewOnly.
  ///
  /// In de, this message translates to:
  /// **'Sieht das Album, trägt nichts bei'**
  String get sharedViewOnly;

  /// No description provided for @notSharedYet.
  ///
  /// In de, this message translates to:
  /// **'Noch mit keinem anderen Space geteilt'**
  String get notSharedYet;

  /// No description provided for @showsOn.
  ///
  /// In de, this message translates to:
  /// **'Läuft auf'**
  String get showsOn;

  /// No description provided for @notOnAnyFrame.
  ///
  /// In de, this message translates to:
  /// **'Noch auf keinem Frame'**
  String get notOnAnyFrame;

  /// No description provided for @removeFromAlbum.
  ///
  /// In de, this message translates to:
  /// **'Aus dem Album entfernen'**
  String get removeFromAlbum;

  /// No description provided for @removePersonTitle.
  ///
  /// In de, this message translates to:
  /// **'{name} entfernen?'**
  String removePersonTitle(String name);

  /// No description provided for @removePersonMessage.
  ///
  /// In de, this message translates to:
  /// **'Die Person verliert den Zugriff auf dieses Album.'**
  String get removePersonMessage;

  /// No description provided for @endShare.
  ///
  /// In de, this message translates to:
  /// **'Freigabe beenden'**
  String get endShare;

  /// No description provided for @endShareTitle.
  ///
  /// In de, this message translates to:
  /// **'Freigabe für „{space}“ beenden?'**
  String endShareTitle(String space);

  /// No description provided for @endShareMessage.
  ///
  /// In de, this message translates to:
  /// **'„{space}“ sieht „{album}“ danach nicht mehr, auch nicht auf seinen Frames.'**
  String endShareMessage(String space, String album);

  /// No description provided for @leaveAlbum.
  ///
  /// In de, this message translates to:
  /// **'Album verlassen'**
  String get leaveAlbum;

  /// No description provided for @leaveAlbumMessage.
  ///
  /// In de, this message translates to:
  /// **'Du siehst die Fotos dieses Albums danach nicht mehr.'**
  String get leaveAlbumMessage;

  /// No description provided for @deleteAlbum.
  ///
  /// In de, this message translates to:
  /// **'Album löschen'**
  String get deleteAlbum;

  /// No description provided for @deleteAlbumTitle.
  ///
  /// In de, this message translates to:
  /// **'Album „{album}“ löschen?'**
  String deleteAlbumTitle(String album);

  /// No description provided for @deleteAlbumMessage.
  ///
  /// In de, this message translates to:
  /// **'Das Album verschwindet mit allen Fotos sofort für alle Personen und von allen Frames. 30 Tage lang kannst du es im Papierkorb wiederherstellen.'**
  String get deleteAlbumMessage;

  /// No description provided for @albumInfoLoadError.
  ///
  /// In de, this message translates to:
  /// **'Album-Infos konnten nicht geladen werden: {error}'**
  String albumInfoLoadError(String error);

  /// No description provided for @actionFailed.
  ///
  /// In de, this message translates to:
  /// **'Aktion fehlgeschlagen: {error}'**
  String actionFailed(String error);

  /// No description provided for @actionAccept.
  ///
  /// In de, this message translates to:
  /// **'Annehmen'**
  String get actionAccept;

  /// No description provided for @actionDecline.
  ///
  /// In de, this message translates to:
  /// **'Ablehnen'**
  String get actionDecline;

  /// No description provided for @actionWithdraw.
  ///
  /// In de, this message translates to:
  /// **'Zurückziehen'**
  String get actionWithdraw;

  /// No description provided for @spacesLoadError.
  ///
  /// In de, this message translates to:
  /// **'Spaces konnten nicht geladen werden: {error}'**
  String spacesLoadError(String error);

  /// No description provided for @spacesEmptyTitle.
  ///
  /// In de, this message translates to:
  /// **'Noch kein eigener Space'**
  String get spacesEmptyTitle;

  /// No description provided for @spacesEmptyMessage.
  ///
  /// In de, this message translates to:
  /// **'Einen Space brauchst du nur, wenn du selbst Frames aufstellst oder Alben verwaltest, für dein Zuhause oder deinen Betrieb.'**
  String get spacesEmptyMessage;

  /// No description provided for @createSpace.
  ///
  /// In de, this message translates to:
  /// **'Space anlegen'**
  String get createSpace;

  /// No description provided for @createSpaceHint.
  ///
  /// In de, this message translates to:
  /// **'Name, z. B. „Familie Müller“ oder „Hotel Sacher“'**
  String get createSpaceHint;

  /// No description provided for @create.
  ///
  /// In de, this message translates to:
  /// **'Anlegen'**
  String get create;

  /// No description provided for @youAreAdmin.
  ///
  /// In de, this message translates to:
  /// **'Du bist Admin'**
  String get youAreAdmin;

  /// No description provided for @youAreCoAdmin.
  ///
  /// In de, this message translates to:
  /// **'Du bist Co-Admin'**
  String get youAreCoAdmin;

  /// No description provided for @renameSpace.
  ///
  /// In de, this message translates to:
  /// **'Space umbenennen'**
  String get renameSpace;

  /// No description provided for @spaceInfoLoadError.
  ///
  /// In de, this message translates to:
  /// **'Space-Infos konnten nicht geladen werden: {error}'**
  String spaceInfoLoadError(String error);

  /// No description provided for @createAlbum.
  ///
  /// In de, this message translates to:
  /// **'Album anlegen'**
  String get createAlbum;

  /// No description provided for @createAlbumHint.
  ///
  /// In de, this message translates to:
  /// **'Name, z. B. „Enkelkinder“ oder „Lobby“'**
  String get createAlbumHint;

  /// No description provided for @noAlbumYet.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Album'**
  String get noAlbumYet;

  /// No description provided for @sharedIntoSpace.
  ///
  /// In de, this message translates to:
  /// **'Mit diesem Space geteilt'**
  String get sharedIntoSpace;

  /// No description provided for @sharedIntoSpaceHint.
  ///
  /// In de, this message translates to:
  /// **'Alben anderer Spaces, die hier nur angesehen werden'**
  String get sharedIntoSpaceHint;

  /// No description provided for @stopShowing.
  ///
  /// In de, this message translates to:
  /// **'Nicht mehr anzeigen'**
  String get stopShowing;

  /// No description provided for @stopShowingTitle.
  ///
  /// In de, this message translates to:
  /// **'„{album}“ nicht mehr anzeigen?'**
  String stopShowingTitle(String album);

  /// No description provided for @stopShowingMessage.
  ///
  /// In de, this message translates to:
  /// **'Dieser Space und seine Frames sehen das Album danach nicht mehr.'**
  String get stopShowingMessage;

  /// No description provided for @noFrameYet.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Frame'**
  String get noFrameYet;

  /// No description provided for @connectFrame.
  ///
  /// In de, this message translates to:
  /// **'Frame verbinden'**
  String get connectFrame;

  /// No description provided for @frameActive.
  ///
  /// In de, this message translates to:
  /// **'Aktiv'**
  String get frameActive;

  /// No description provided for @framePending.
  ///
  /// In de, this message translates to:
  /// **'Wartet auf Kopplung'**
  String get framePending;

  /// No description provided for @frameRevoked.
  ///
  /// In de, this message translates to:
  /// **'Widerrufen'**
  String get frameRevoked;

  /// No description provided for @inviteCoAdmin.
  ///
  /// In de, this message translates to:
  /// **'Co-Admin einladen'**
  String get inviteCoAdmin;

  /// No description provided for @inviteCoAdminHint.
  ///
  /// In de, this message translates to:
  /// **'Die Person braucht bereits einen Smile-Account. Nimmt sie an, verwaltet sie diesen Space mit allen Rechten außer Löschen.'**
  String get inviteCoAdminHint;

  /// No description provided for @makeAdmin.
  ///
  /// In de, this message translates to:
  /// **'Zum Admin machen'**
  String get makeAdmin;

  /// No description provided for @makeAdminTitle.
  ///
  /// In de, this message translates to:
  /// **'{name} zum Admin machen?'**
  String makeAdminTitle(String name);

  /// No description provided for @makeAdminMessage.
  ///
  /// In de, this message translates to:
  /// **'Diese Person wird Admin dieses Space. Du bleibst Co-Admin mit allen Rechten, entscheidest aber nicht mehr allein, wer mitverwaltet.'**
  String get makeAdminMessage;

  /// No description provided for @chooseNewAdmin.
  ///
  /// In de, this message translates to:
  /// **'Wer soll Admin werden?'**
  String get chooseNewAdmin;

  /// No description provided for @removeCoAdmin.
  ///
  /// In de, this message translates to:
  /// **'Als Co-Admin entfernen'**
  String get removeCoAdmin;

  /// No description provided for @removeCoAdminTitle.
  ///
  /// In de, this message translates to:
  /// **'{name} als Co-Admin entfernen?'**
  String removeCoAdminTitle(String name);

  /// No description provided for @removeCoAdminMessage.
  ///
  /// In de, this message translates to:
  /// **'Die Person verliert die Verwaltungsrechte über diesen Space.'**
  String get removeCoAdminMessage;

  /// No description provided for @stepDown.
  ///
  /// In de, this message translates to:
  /// **'Co-Admin-Rolle abgeben'**
  String get stepDown;

  /// No description provided for @stepDownMessage.
  ///
  /// In de, this message translates to:
  /// **'Du verlierst deine Verwaltungsrechte über diesen Space.'**
  String get stepDownMessage;

  /// No description provided for @trashTitle.
  ///
  /// In de, this message translates to:
  /// **'Papierkorb'**
  String get trashTitle;

  /// No description provided for @deleteSpace.
  ///
  /// In de, this message translates to:
  /// **'Space löschen'**
  String get deleteSpace;

  /// No description provided for @deleteSpaceTitle.
  ///
  /// In de, this message translates to:
  /// **'Space „{space}“ löschen?'**
  String deleteSpaceTitle(String space);

  /// No description provided for @deleteSpaceMessage.
  ///
  /// In de, this message translates to:
  /// **'Der Space verschwindet mit allen Alben, Fotos und Frames sofort für alle; alle Beteiligten werden benachrichtigt. 30 Tage lang kannst du ihn im Papierkorb wiederherstellen.'**
  String get deleteSpaceMessage;

  /// No description provided for @inTrash.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ ist im Papierkorb.'**
  String inTrash(String name);

  /// No description provided for @frameInfoLoadError.
  ///
  /// In de, this message translates to:
  /// **'Frame-Infos konnten nicht geladen werden: {error}'**
  String frameInfoLoadError(String error);

  /// No description provided for @frameInSpace.
  ///
  /// In de, this message translates to:
  /// **'Frame in {space}'**
  String frameInSpace(String space);

  /// No description provided for @renameFrame.
  ///
  /// In de, this message translates to:
  /// **'Frame umbenennen'**
  String get renameFrame;

  /// No description provided for @status.
  ///
  /// In de, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @device.
  ///
  /// In de, this message translates to:
  /// **'Gerät'**
  String get device;

  /// No description provided for @lastSeen.
  ///
  /// In de, this message translates to:
  /// **'Zuletzt gesehen'**
  String get lastSeen;

  /// No description provided for @appVersion.
  ///
  /// In de, this message translates to:
  /// **'App-Version'**
  String get appVersion;

  /// No description provided for @battery.
  ///
  /// In de, this message translates to:
  /// **'Akku'**
  String get battery;

  /// No description provided for @charging.
  ///
  /// In de, this message translates to:
  /// **'lädt'**
  String get charging;

  /// No description provided for @settings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settings;

  /// No description provided for @videoSound.
  ///
  /// In de, this message translates to:
  /// **'Videos mit Ton'**
  String get videoSound;

  /// No description provided for @videoSoundHint.
  ///
  /// In de, this message translates to:
  /// **'Aus: Videos laufen auf diesem Frame stumm.'**
  String get videoSoundHint;

  /// No description provided for @albumSwitch.
  ///
  /// In de, this message translates to:
  /// **'Album-Wechsel erlauben'**
  String get albumSwitch;

  /// No description provided for @albumSwitchHint.
  ///
  /// In de, this message translates to:
  /// **'Wer vor dem Frame steht, kann selbst zwischen den Alben wechseln.'**
  String get albumSwitchHint;

  /// No description provided for @showsAlbums.
  ///
  /// In de, this message translates to:
  /// **'Zeigt'**
  String get showsAlbums;

  /// No description provided for @noAlbumAssigned.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Album zugewiesen'**
  String get noAlbumAssigned;

  /// No description provided for @addAlbumToFrame.
  ///
  /// In de, this message translates to:
  /// **'Album hinzufügen'**
  String get addAlbumToFrame;

  /// No description provided for @noMoreAlbums.
  ///
  /// In de, this message translates to:
  /// **'Es gibt keine weiteren Alben, die dieser Space sehen kann.'**
  String get noMoreAlbums;

  /// No description provided for @close.
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get close;

  /// No description provided for @removeFromFrame.
  ///
  /// In de, this message translates to:
  /// **'Vom Frame entfernen'**
  String get removeFromFrame;

  /// No description provided for @revokeFrame.
  ///
  /// In de, this message translates to:
  /// **'Frame widerrufen'**
  String get revokeFrame;

  /// No description provided for @revokeFrameMessage.
  ///
  /// In de, this message translates to:
  /// **'Der Frame verliert sofort jeden Zugriff und löscht seine Fotos. Du kannst ihn jederzeit wieder aktivieren.'**
  String get revokeFrameMessage;

  /// No description provided for @reactivateFrame.
  ///
  /// In de, this message translates to:
  /// **'Frame wieder aktivieren'**
  String get reactivateFrame;

  /// No description provided for @newsEmptyTitle.
  ///
  /// In de, this message translates to:
  /// **'Keine Neuigkeiten'**
  String get newsEmptyTitle;

  /// No description provided for @newsEmptyMessage.
  ///
  /// In de, this message translates to:
  /// **'Hier erscheinen Einladungen, Anfragen und gelöschte Alben oder Spaces.'**
  String get newsEmptyMessage;

  /// No description provided for @newsLoadError.
  ///
  /// In de, this message translates to:
  /// **'Neuigkeiten konnten nicht geladen werden: {error}'**
  String newsLoadError(String error);

  /// No description provided for @invitations.
  ///
  /// In de, this message translates to:
  /// **'Einladungen'**
  String get invitations;

  /// No description provided for @requests.
  ///
  /// In de, this message translates to:
  /// **'Anfragen'**
  String get requests;

  /// No description provided for @myRequests.
  ///
  /// In de, this message translates to:
  /// **'Eigene Anfragen'**
  String get myRequests;

  /// No description provided for @inviteCoAdminFrom.
  ///
  /// In de, this message translates to:
  /// **'{name} lädt dich als Co-Admin ein'**
  String inviteCoAdminFrom(String name);

  /// No description provided for @inviteMemberFrom.
  ///
  /// In de, this message translates to:
  /// **'{name} lädt dich als Member ein'**
  String inviteMemberFrom(String name);

  /// No description provided for @inviteShareFrom.
  ///
  /// In de, this message translates to:
  /// **'{name} möchte das Album mit deinem Space teilen'**
  String inviteShareFrom(String name);

  /// No description provided for @requestMemberFrom.
  ///
  /// In de, this message translates to:
  /// **'{name} möchte Member werden'**
  String requestMemberFrom(String name);

  /// No description provided for @requestShareFrom.
  ///
  /// In de, this message translates to:
  /// **'{name} möchte das Album mit dem eigenen Space sehen'**
  String requestShareFrom(String name);

  /// No description provided for @waitingForAnswer.
  ///
  /// In de, this message translates to:
  /// **'Wartet auf Antwort'**
  String get waitingForAnswer;

  /// No description provided for @acceptedCoAdmin.
  ///
  /// In de, this message translates to:
  /// **'Du verwaltest jetzt „{space}“ mit.'**
  String acceptedCoAdmin(String space);

  /// No description provided for @acceptedAlbum.
  ///
  /// In de, this message translates to:
  /// **'„{album}“ ist jetzt in deinen Alben.'**
  String acceptedAlbum(String album);

  /// No description provided for @acceptedShare.
  ///
  /// In de, this message translates to:
  /// **'„{album}“ ist jetzt mit deinem Space geteilt.'**
  String acceptedShare(String album);

  /// No description provided for @requestAccepted.
  ///
  /// In de, this message translates to:
  /// **'Anfrage angenommen.'**
  String get requestAccepted;

  /// No description provided for @needOwnSpace.
  ///
  /// In de, this message translates to:
  /// **'Du brauchst zuerst einen eigenen Space, um ein geteiltes Album anzunehmen.'**
  String get needOwnSpace;

  /// No description provided for @chooseSpace.
  ///
  /// In de, this message translates to:
  /// **'Mit welchem Space?'**
  String get chooseSpace;

  /// No description provided for @trashEmpty.
  ///
  /// In de, this message translates to:
  /// **'Der Papierkorb ist leer.'**
  String get trashEmpty;

  /// No description provided for @trashLoadError.
  ///
  /// In de, this message translates to:
  /// **'Papierkorb konnte nicht geladen werden: {error}'**
  String trashLoadError(String error);

  /// No description provided for @trashSpaceIn.
  ///
  /// In de, this message translates to:
  /// **'in {space}'**
  String trashSpaceIn(String space);

  /// No description provided for @trashDeletedBy.
  ///
  /// In de, this message translates to:
  /// **'gelöscht von {name}'**
  String trashDeletedBy(String name);

  /// No description provided for @trashGoneOn.
  ///
  /// In de, this message translates to:
  /// **'endgültig weg am {date}'**
  String trashGoneOn(String date);

  /// No description provided for @restored.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ ist wiederhergestellt.'**
  String restored(String name);

  /// No description provided for @profileLoadError.
  ///
  /// In de, this message translates to:
  /// **'Profil konnte nicht geladen werden: {error}'**
  String profileLoadError(String error);

  /// No description provided for @retry.
  ///
  /// In de, this message translates to:
  /// **'Erneut versuchen'**
  String get retry;

  /// No description provided for @changeName.
  ///
  /// In de, this message translates to:
  /// **'Name ändern'**
  String get changeName;

  /// No description provided for @nameSaveError.
  ///
  /// In de, this message translates to:
  /// **'Name konnte nicht gespeichert werden: {error}'**
  String nameSaveError(String error);

  /// No description provided for @avatarUploadError.
  ///
  /// In de, this message translates to:
  /// **'Bild konnte nicht hochgeladen werden: {error}'**
  String avatarUploadError(String error);

  /// No description provided for @changePicture.
  ///
  /// In de, this message translates to:
  /// **'Profilbild ändern'**
  String get changePicture;

  /// No description provided for @viewPicture.
  ///
  /// In de, this message translates to:
  /// **'Profilbild ansehen'**
  String get viewPicture;

  /// No description provided for @takePhoto.
  ///
  /// In de, this message translates to:
  /// **'Foto aufnehmen'**
  String get takePhoto;

  /// No description provided for @choosePicture.
  ///
  /// In de, this message translates to:
  /// **'Vorhandenes Bild wählen'**
  String get choosePicture;

  /// No description provided for @pictureFromWeb.
  ///
  /// In de, this message translates to:
  /// **'Von einer Internetadresse laden'**
  String get pictureFromWeb;

  /// No description provided for @pictureUrl.
  ///
  /// In de, this message translates to:
  /// **'Bild-URL'**
  String get pictureUrl;

  /// No description provided for @load.
  ///
  /// In de, this message translates to:
  /// **'Laden'**
  String get load;

  /// No description provided for @account.
  ///
  /// In de, this message translates to:
  /// **'Konto'**
  String get account;

  /// No description provided for @emailAddress.
  ///
  /// In de, this message translates to:
  /// **'E-Mail-Adresse'**
  String get emailAddress;

  /// No description provided for @signOut.
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get signOut;

  /// No description provided for @signOutQuestion.
  ///
  /// In de, this message translates to:
  /// **'Möchtest du dich wirklich abmelden?'**
  String get signOutQuestion;

  /// No description provided for @profileSetupQuestion.
  ///
  /// In de, this message translates to:
  /// **'Wie sollen wir dich nennen?'**
  String get profileSetupQuestion;

  /// No description provided for @next.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get next;

  /// No description provided for @framePairTitle.
  ///
  /// In de, this message translates to:
  /// **'Frame verbinden'**
  String get framePairTitle;

  /// No description provided for @framePairHint.
  ///
  /// In de, this message translates to:
  /// **'Gib den Code ein, den die Smile-App beim Verbinden dieses Frames anzeigt.'**
  String get framePairHint;

  /// No description provided for @framePairButton.
  ///
  /// In de, this message translates to:
  /// **'Verbinden'**
  String get framePairButton;

  /// No description provided for @framePairInvalid.
  ///
  /// In de, this message translates to:
  /// **'Dieser Code ist ungültig.'**
  String get framePairInvalid;

  /// No description provided for @framePairExpired.
  ///
  /// In de, this message translates to:
  /// **'Der Code ist abgelaufen. Lass dir in der Smile-App einen neuen anzeigen.'**
  String get framePairExpired;

  /// No description provided for @framePairRevoked.
  ///
  /// In de, this message translates to:
  /// **'Dieser Frame wurde widerrufen.'**
  String get framePairRevoked;

  /// No description provided for @framePairFailed.
  ///
  /// In de, this message translates to:
  /// **'Verbinden fehlgeschlagen.'**
  String get framePairFailed;

  /// No description provided for @framePairNoConnection.
  ///
  /// In de, this message translates to:
  /// **'Keine Verbindung zum Server. Bitte erneut versuchen.'**
  String get framePairNoConnection;

  /// No description provided for @frameOfflineTooLong.
  ///
  /// In de, this message translates to:
  /// **'Dieser Frame war zu lange ohne Verbindung.\nDie Fotos erscheinen wieder, sobald er online ist.'**
  String get frameOfflineTooLong;

  /// No description provided for @frameRevokedScreen.
  ///
  /// In de, this message translates to:
  /// **'Dieser Frame wurde widerrufen.\nEin Admin des Space kann ihn in der Smile-App wieder aktivieren.'**
  String get frameRevokedScreen;

  /// No description provided for @frameNoPhotos.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Fotos'**
  String get frameNoPhotos;

  /// No description provided for @chooseAlbum.
  ///
  /// In de, this message translates to:
  /// **'Album wählen'**
  String get chooseAlbum;

  /// No description provided for @postPhotos.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Foto} other{{count} Fotos}}'**
  String postPhotos(int count);

  /// No description provided for @postVideos.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Video} other{{count} Videos}}'**
  String postVideos(int count);

  /// No description provided for @lastPostBy.
  ///
  /// In de, this message translates to:
  /// **'{name}: {what}'**
  String lastPostBy(String name, String what);

  /// No description provided for @someone.
  ///
  /// In de, this message translates to:
  /// **'Jemand'**
  String get someone;

  /// No description provided for @noPostsYet.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Fotos'**
  String get noPostsYet;

  /// No description provided for @history.
  ///
  /// In de, this message translates to:
  /// **'Verlauf'**
  String get history;

  /// No description provided for @yesterday.
  ///
  /// In de, this message translates to:
  /// **'Gestern'**
  String get yesterday;
}

class _SmileTextsDelegate extends LocalizationsDelegate<SmileTexts> {
  const _SmileTextsDelegate();

  @override
  Future<SmileTexts> load(Locale locale) {
    return SynchronousFuture<SmileTexts>(lookupSmileTexts(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de'].contains(locale.languageCode);

  @override
  bool shouldReload(_SmileTextsDelegate old) => false;
}

SmileTexts lookupSmileTexts(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return SmileTextsDe();
  }

  throw FlutterError(
    'SmileTexts.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
