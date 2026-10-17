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
  /// **'Geteilt mit'**
  String get sharedWith;

  /// No description provided for @sharedWithSpace.
  ///
  /// In de, this message translates to:
  /// **'Geteilt mit {space}'**
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
  /// **'QR-Code scannen oder Code eintippen'**
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
  /// **'Die Alben konnten gerade nicht geladen werden. {error}'**
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

  /// No description provided for @showOnFrame.
  ///
  /// In de, this message translates to:
  /// **'Auf Frame zeigen'**
  String get showOnFrame;

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
  /// **'Die Album-Infos konnten gerade nicht geladen werden. {error}'**
  String albumInfoLoadError(String error);

  /// No description provided for @actionFailed.
  ///
  /// In de, this message translates to:
  /// **'Das hat leider nicht geklappt. {error}'**
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
  /// **'Die Spaces konnten gerade nicht geladen werden. {error}'**
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
  /// **'Die Space-Infos konnten gerade nicht geladen werden. {error}'**
  String spaceInfoLoadError(String error);

  /// No description provided for @createAlbum.
  ///
  /// In de, this message translates to:
  /// **'Album anlegen'**
  String get createAlbum;

  /// No description provided for @newAlbum.
  ///
  /// In de, this message translates to:
  /// **'Neues Album'**
  String get newAlbum;

  /// No description provided for @moreOptions.
  ///
  /// In de, this message translates to:
  /// **'Weitere Optionen'**
  String get moreOptions;

  /// No description provided for @newAlbumWhere.
  ///
  /// In de, this message translates to:
  /// **'Neues Album in …'**
  String get newAlbumWhere;

  /// No description provided for @inSpaceLine.
  ///
  /// In de, this message translates to:
  /// **'in {space}'**
  String inSpaceLine(String space);

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
  /// **'Die Frame-Infos konnten gerade nicht geladen werden. {error}'**
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

  /// No description provided for @openAlbum.
  ///
  /// In de, this message translates to:
  /// **'Album öffnen'**
  String get openAlbum;

  /// No description provided for @openFrame.
  ///
  /// In de, this message translates to:
  /// **'Frame öffnen'**
  String get openFrame;

  /// No description provided for @offlineHint.
  ///
  /// In de, this message translates to:
  /// **'Offline – zuletzt geladener Stand'**
  String get offlineHint;

  /// No description provided for @videoNotOnPhone.
  ///
  /// In de, this message translates to:
  /// **'Dieses Video ist noch nicht auf dem Handy. Ohne Verbindung kann es nicht abgespielt werden.'**
  String get videoNotOnPhone;

  /// No description provided for @changeNotSaved.
  ///
  /// In de, this message translates to:
  /// **'Die Änderung wurde nicht gespeichert. {reason}'**
  String changeNotSaved(String reason);

  /// No description provided for @showingNow.
  ///
  /// In de, this message translates to:
  /// **'Läuft gerade'**
  String get showingNow;

  /// No description provided for @showNow.
  ///
  /// In de, this message translates to:
  /// **'Jetzt zeigen'**
  String get showNow;

  /// No description provided for @showHereNow.
  ///
  /// In de, this message translates to:
  /// **'Hier jetzt zeigen'**
  String get showHereNow;

  /// No description provided for @frameShowsThisAlbum.
  ///
  /// In de, this message translates to:
  /// **'zeigt gerade dieses Album'**
  String get frameShowsThisAlbum;

  /// No description provided for @frameShowsAlbum.
  ///
  /// In de, this message translates to:
  /// **'zeigt gerade „{album}“'**
  String frameShowsAlbum(String album);

  /// No description provided for @frameSwitched.
  ///
  /// In de, this message translates to:
  /// **'„{frame}“ zeigt jetzt „{album}“.'**
  String frameSwitched(String frame, String album);

  /// No description provided for @removeFromFrameTitle.
  ///
  /// In de, this message translates to:
  /// **'„{album}“ vom Frame entfernen?'**
  String removeFromFrameTitle(String album);

  /// No description provided for @removeFromFrameMessage.
  ///
  /// In de, this message translates to:
  /// **'Der Frame zeigt die Fotos dieses Albums dann nicht mehr. Das Album und seine Fotos bleiben erhalten.'**
  String get removeFromFrameMessage;

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
  /// **'Die Neuigkeiten konnten gerade nicht geladen werden. {error}'**
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
  /// **'Der Papierkorb konnte gerade nicht geladen werden. {error}'**
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
  /// **'Dein Profil konnte gerade nicht geladen werden. {error}'**
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
  /// **'Der Name konnte nicht gespeichert werden. {error}'**
  String nameSaveError(String error);

  /// No description provided for @avatarUploadError.
  ///
  /// In de, this message translates to:
  /// **'Das Bild konnte nicht hochgeladen werden. {error}'**
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
  /// **'Halte den QR-Code aus der Smile-App vor die Kamera – oder tippe den Code ein, der darunter steht.'**
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

  /// No description provided for @removeAll.
  ///
  /// In de, this message translates to:
  /// **'Alle entfernen'**
  String get removeAll;

  /// No description provided for @removeEntry.
  ///
  /// In de, this message translates to:
  /// **'Entfernen'**
  String get removeEntry;

  /// No description provided for @deleteFrame.
  ///
  /// In de, this message translates to:
  /// **'Frame löschen'**
  String get deleteFrame;

  /// No description provided for @deleteFrameTitle.
  ///
  /// In de, this message translates to:
  /// **'Frame „{name}“ löschen?'**
  String deleteFrameTitle(String name);

  /// No description provided for @deleteFrameMessage.
  ///
  /// In de, this message translates to:
  /// **'Der Frame wird endgültig entfernt. Das Tablet löscht seine Fotos und zeigt wieder „Frame verbinden“. Zum Weiterverwenden einfach neu verbinden.'**
  String get deleteFrameMessage;

  /// No description provided for @deleteAccount.
  ///
  /// In de, this message translates to:
  /// **'Konto löschen'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In de, this message translates to:
  /// **'Konto endgültig löschen?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountMessage.
  ///
  /// In de, this message translates to:
  /// **'Dein Profil, alle deine Fotos und Videos in allen Alben und alle deine Mitgliedschaften werden sofort und endgültig gelöscht. Spaces, in denen du Admin bist, übernimmt dein längster Co-Admin; ohne Co-Admin wird der Space mit allen Alben und Frames gelöscht. Das kann nicht rückgängig gemacht werden.'**
  String get deleteAccountMessage;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In de, this message translates to:
  /// **'Endgültig löschen'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountTitleNamed.
  ///
  /// In de, this message translates to:
  /// **'Konto von {name} löschen?'**
  String deleteAccountTitleNamed(String name);

  /// No description provided for @deleteAccountWhich.
  ///
  /// In de, this message translates to:
  /// **'Gelöscht wird das Konto {email}, mit dem du gerade angemeldet bist.'**
  String deleteAccountWhich(String email);

  /// No description provided for @deleteAccountTypeEmail.
  ///
  /// In de, this message translates to:
  /// **'Zum Bestätigen diese E-Mail-Adresse eintippen:'**
  String get deleteAccountTypeEmail;

  /// No description provided for @newsUnseen.
  ///
  /// In de, this message translates to:
  /// **'Neuigkeiten, es gibt Neues'**
  String get newsUnseen;

  /// No description provided for @pictureFor.
  ///
  /// In de, this message translates to:
  /// **'Bild für „{name}“'**
  String pictureFor(String name);

  /// No description provided for @coverFor.
  ///
  /// In de, this message translates to:
  /// **'Titelbild für „{name}“'**
  String coverFor(String name);

  /// No description provided for @pickFromAlbum.
  ///
  /// In de, this message translates to:
  /// **'Foto aus dem Album wählen'**
  String get pickFromAlbum;

  /// No description provided for @automaticCover.
  ///
  /// In de, this message translates to:
  /// **'Automatisch: neuestes Foto'**
  String get automaticCover;

  /// No description provided for @removePicture.
  ///
  /// In de, this message translates to:
  /// **'Bild entfernen'**
  String get removePicture;

  /// No description provided for @changeObjectPicture.
  ///
  /// In de, this message translates to:
  /// **'Bild ändern'**
  String get changeObjectPicture;

  /// No description provided for @setAsCover.
  ///
  /// In de, this message translates to:
  /// **'Als Titelbild'**
  String get setAsCover;

  /// No description provided for @coverSet.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ hat ein neues Titelbild.'**
  String coverSet(String name);

  /// No description provided for @choosePhoto.
  ///
  /// In de, this message translates to:
  /// **'Foto wählen'**
  String get choosePhoto;

  /// No description provided for @noPhotosInAlbum.
  ///
  /// In de, this message translates to:
  /// **'In diesem Album gibt es noch keine Fotos.'**
  String get noPhotosInAlbum;

  /// No description provided for @captureInAlbum.
  ///
  /// In de, this message translates to:
  /// **'Aufnehmen'**
  String get captureInAlbum;

  /// No description provided for @recordVideo.
  ///
  /// In de, this message translates to:
  /// **'Video aufnehmen'**
  String get recordVideo;

  /// No description provided for @captureSend.
  ///
  /// In de, this message translates to:
  /// **'Senden'**
  String get captureSend;

  /// No description provided for @captureRetake.
  ///
  /// In de, this message translates to:
  /// **'Nochmal'**
  String get captureRetake;

  /// No description provided for @noConnectionTitle.
  ///
  /// In de, this message translates to:
  /// **'Keine Internetverbindung'**
  String get noConnectionTitle;

  /// No description provided for @noConnectionMessage.
  ///
  /// In de, this message translates to:
  /// **'Prüfe deine Verbindung und versuche es noch einmal.'**
  String get noConnectionMessage;

  /// No description provided for @noConnectionReason.
  ///
  /// In de, this message translates to:
  /// **'Keine Internetverbindung.'**
  String get noConnectionReason;

  /// No description provided for @tryAgainReason.
  ///
  /// In de, this message translates to:
  /// **'Bitte versuche es noch einmal.'**
  String get tryAgainReason;

  /// No description provided for @videoNotPlayable.
  ///
  /// In de, this message translates to:
  /// **'Das Video kann gerade nicht abgespielt werden.'**
  String get videoNotPlayable;

  /// No description provided for @loginSendFailed.
  ///
  /// In de, this message translates to:
  /// **'Die E-Mail mit dem Code konnte gerade nicht gesendet werden. Bitte versuche es gleich noch einmal.'**
  String get loginSendFailed;

  /// No description provided for @loginCodeWrong.
  ///
  /// In de, this message translates to:
  /// **'Der Code stimmt nicht oder ist abgelaufen. Bitte prüfe ihn oder lass dir einen neuen schicken.'**
  String get loginCodeWrong;

  /// No description provided for @sendFailed.
  ///
  /// In de, this message translates to:
  /// **'Das Senden hat leider nicht geklappt. Bitte versuche es noch einmal.'**
  String get sendFailed;

  /// No description provided for @sendFailedSome.
  ///
  /// In de, this message translates to:
  /// **'{failed} von {total} konnten nicht gesendet werden. Bitte versuche es noch einmal.'**
  String sendFailedSome(int failed, int total);

  /// No description provided for @ok.
  ///
  /// In de, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @dontSend.
  ///
  /// In de, this message translates to:
  /// **'Nicht senden'**
  String get dontSend;

  /// No description provided for @allSelected.
  ///
  /// In de, this message translates to:
  /// **'Alle {count} ausgewählt'**
  String allSelected(int count);

  /// No description provided for @selectAll.
  ///
  /// In de, this message translates to:
  /// **'Alle'**
  String get selectAll;

  /// No description provided for @selectNone.
  ///
  /// In de, this message translates to:
  /// **'Keine'**
  String get selectNone;

  /// No description provided for @coverShort.
  ///
  /// In de, this message translates to:
  /// **'Titelbild'**
  String get coverShort;

  /// No description provided for @deletePhotosTitle.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Foto löschen?} other{{count} Fotos löschen?}}'**
  String deletePhotosTitle(int count);

  /// No description provided for @deleteForEveryone.
  ///
  /// In de, this message translates to:
  /// **'Für alle löschen'**
  String get deleteForEveryone;

  /// No description provided for @deleteForEveryoneHint.
  ///
  /// In de, this message translates to:
  /// **'Bei allen und auf allen Frames, endgültig'**
  String get deleteForEveryoneHint;

  /// No description provided for @deleteForMe.
  ///
  /// In de, this message translates to:
  /// **'Für mich löschen'**
  String get deleteForMe;

  /// No description provided for @deleteForMeHint.
  ///
  /// In de, this message translates to:
  /// **'Nur bei dir weg, unter „Ausgeblendet“ zurückholbar'**
  String get deleteForMeHint;

  /// No description provided for @deleteOnlyOwn.
  ///
  /// In de, this message translates to:
  /// **'Für alle löschen kannst du nur deine eigenen Fotos.'**
  String get deleteOnlyOwn;

  /// No description provided for @inviteToNamed.
  ///
  /// In de, this message translates to:
  /// **'In „{name}“ einladen'**
  String inviteToNamed(String name);

  /// No description provided for @coAdminFor.
  ///
  /// In de, this message translates to:
  /// **'Co-Admin für „{name}“'**
  String coAdminFor(String name);

  /// No description provided for @searchName.
  ///
  /// In de, this message translates to:
  /// **'Name suchen'**
  String get searchName;

  /// No description provided for @noKnownPeople.
  ///
  /// In de, this message translates to:
  /// **'Noch niemand, den du in Smile kennst. Lade per QR-Code oder Link ein.'**
  String get noKnownPeople;

  /// No description provided for @showQrCode.
  ///
  /// In de, this message translates to:
  /// **'QR-Code zeigen'**
  String get showQrCode;

  /// No description provided for @shareInviteLink.
  ///
  /// In de, this message translates to:
  /// **'Einladungslink teilen'**
  String get shareInviteLink;

  /// No description provided for @inviteByEmail.
  ///
  /// In de, this message translates to:
  /// **'Per E-Mail einladen'**
  String get inviteByEmail;

  /// No description provided for @inviteSentTo.
  ///
  /// In de, this message translates to:
  /// **'Einladung an {name} gesendet'**
  String inviteSentTo(String name);

  /// No description provided for @managesASpace.
  ///
  /// In de, this message translates to:
  /// **'Verwaltet einen Space'**
  String get managesASpace;

  /// No description provided for @qrScanHint.
  ///
  /// In de, this message translates to:
  /// **'Mit der Smile-App scannen: Neuigkeiten → Code scannen. Oder den Code eintippen.'**
  String get qrScanHint;

  /// No description provided for @qrScanHintCoAdmin.
  ///
  /// In de, this message translates to:
  /// **'Mit der Smile-App scannen: Neuigkeiten → Code scannen. Co-Admin wird man nur per QR-Code vor Ort.'**
  String get qrScanHintCoAdmin;

  /// No description provided for @qrValid.
  ///
  /// In de, this message translates to:
  /// **'Gilt 24 Stunden.'**
  String get qrValid;

  /// No description provided for @newCode.
  ///
  /// In de, this message translates to:
  /// **'Neuen Code erstellen'**
  String get newCode;

  /// No description provided for @inviteMessageMember.
  ///
  /// In de, this message translates to:
  /// **'Komm in mein Smile-Album „{album}“! Einfach auf den Link tippen: {link}'**
  String inviteMessageMember(String album, String link);

  /// No description provided for @inviteMessageShare.
  ///
  /// In de, this message translates to:
  /// **'Ich möchte mein Smile-Album „{album}“ mit deinem Space teilen. Einfach auf den Link tippen: {link}'**
  String inviteMessageShare(String album, String link);

  /// No description provided for @scanCode.
  ///
  /// In de, this message translates to:
  /// **'Code scannen'**
  String get scanCode;

  /// No description provided for @scanHint.
  ///
  /// In de, this message translates to:
  /// **'QR-Code in den Rahmen halten'**
  String get scanHint;

  /// No description provided for @typeCode.
  ///
  /// In de, this message translates to:
  /// **'Code eintippen'**
  String get typeCode;

  /// No description provided for @codeFieldHint.
  ///
  /// In de, this message translates to:
  /// **'z. B. K7P-2QX'**
  String get codeFieldHint;

  /// No description provided for @redeemJoinedAlbum.
  ///
  /// In de, this message translates to:
  /// **'Du bist jetzt im Album „{name}“.'**
  String redeemJoinedAlbum(String name);

  /// No description provided for @redeemJoinedShare.
  ///
  /// In de, this message translates to:
  /// **'„{album}“ ist jetzt in deinem Space „{space}“ zu sehen.'**
  String redeemJoinedShare(String album, String space);

  /// No description provided for @redeemJoinedCoAdmin.
  ///
  /// In de, this message translates to:
  /// **'Du bist jetzt Co-Admin von „{space}“.'**
  String redeemJoinedCoAdmin(String space);

  /// No description provided for @redeemRequestedTitle.
  ///
  /// In de, this message translates to:
  /// **'Anfrage gesendet'**
  String get redeemRequestedTitle;

  /// No description provided for @redeemRequested.
  ///
  /// In de, this message translates to:
  /// **'Die Admins von „{name}“ entscheiden. Du bekommst Bescheid.'**
  String redeemRequested(String name);

  /// No description provided for @redeemAlready.
  ///
  /// In de, this message translates to:
  /// **'Du bist schon dabei.'**
  String get redeemAlready;

  /// No description provided for @redeemPickSpace.
  ///
  /// In de, this message translates to:
  /// **'Mit welchem Space teilen?'**
  String get redeemPickSpace;

  /// No description provided for @codeInvalid.
  ///
  /// In de, this message translates to:
  /// **'Dieser Code ist ungültig.'**
  String get codeInvalid;

  /// No description provided for @codeExpired.
  ///
  /// In de, this message translates to:
  /// **'Der Code ist abgelaufen. Lass dir einen neuen zeigen.'**
  String get codeExpired;

  /// No description provided for @codeQrOnly.
  ///
  /// In de, this message translates to:
  /// **'Co-Admin wirst du nur, indem du den QR-Code vor Ort scannst.'**
  String get codeQrOnly;

  /// No description provided for @codeNoSpace.
  ///
  /// In de, this message translates to:
  /// **'Du verwaltest keinen Space, mit dem du das Album teilen kannst.'**
  String get codeNoSpace;

  /// No description provided for @cameraUnavailable.
  ///
  /// In de, this message translates to:
  /// **'Die Kamera ist nicht verfügbar. Du kannst den Code eintippen.'**
  String get cameraUnavailable;

  /// No description provided for @frameOnline.
  ///
  /// In de, this message translates to:
  /// **'Online'**
  String get frameOnline;

  /// No description provided for @frameOfflineSince.
  ///
  /// In de, this message translates to:
  /// **'Offline seit {time}'**
  String frameOfflineSince(String time);

  /// No description provided for @frameNeverOnline.
  ///
  /// In de, this message translates to:
  /// **'Noch nicht verbunden'**
  String get frameNeverOnline;

  /// No description provided for @batteryShort.
  ///
  /// In de, this message translates to:
  /// **'Akku {level} %'**
  String batteryShort(int level);

  /// No description provided for @durationMinutes.
  ///
  /// In de, this message translates to:
  /// **'{count} Min.'**
  String durationMinutes(int count);

  /// No description provided for @durationHours.
  ///
  /// In de, this message translates to:
  /// **'{count} Std.'**
  String durationHours(int count);

  /// No description provided for @durationDays.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Tag} other{{count} Tagen}}'**
  String durationDays(int count);

  /// No description provided for @nowShowingLabel.
  ///
  /// In de, this message translates to:
  /// **'Läuft gerade'**
  String get nowShowingLabel;

  /// No description provided for @switchAlbum.
  ///
  /// In de, this message translates to:
  /// **'Album wechseln'**
  String get switchAlbum;

  /// No description provided for @soundOn.
  ///
  /// In de, this message translates to:
  /// **'Ton an'**
  String get soundOn;

  /// No description provided for @soundOff.
  ///
  /// In de, this message translates to:
  /// **'Ton aus'**
  String get soundOff;

  /// No description provided for @tileVideoSound.
  ///
  /// In de, this message translates to:
  /// **'Ton bei Videos'**
  String get tileVideoSound;

  /// No description provided for @tileAlbumSwitch.
  ///
  /// In de, this message translates to:
  /// **'Wechsel am Frame'**
  String get tileAlbumSwitch;

  /// No description provided for @valueOn.
  ///
  /// In de, this message translates to:
  /// **'An'**
  String get valueOn;

  /// No description provided for @valueOff.
  ///
  /// In de, this message translates to:
  /// **'Aus'**
  String get valueOff;

  /// No description provided for @valueAllowed.
  ///
  /// In de, this message translates to:
  /// **'Erlaubt'**
  String get valueAllowed;

  /// No description provided for @manageAlbums.
  ///
  /// In de, this message translates to:
  /// **'Alben verwalten'**
  String get manageAlbums;

  /// No description provided for @settingsAndDevice.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen & Gerät'**
  String get settingsAndDevice;

  /// No description provided for @openRemote.
  ///
  /// In de, this message translates to:
  /// **'Frame steuern'**
  String get openRemote;

  /// No description provided for @pickFrame.
  ///
  /// In de, this message translates to:
  /// **'Welcher Frame?'**
  String get pickFrame;

  /// No description provided for @useAsFrame.
  ///
  /// In de, this message translates to:
  /// **'Dieses Gerät als Frame verwenden'**
  String get useAsFrame;

  /// No description provided for @setUpFrame.
  ///
  /// In de, this message translates to:
  /// **'Frame einrichten'**
  String get setUpFrame;

  /// No description provided for @connectNamedFrame.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ verbinden'**
  String connectNamedFrame(String name);

  /// No description provided for @connectFrameHint.
  ///
  /// In de, this message translates to:
  /// **'Auf dem Tablet: Smile öffnen → „Dieses Gerät als Frame verwenden“ → QR-Code scannen. Gilt 15 Minuten.'**
  String get connectFrameHint;

  /// No description provided for @waitingForFrame.
  ///
  /// In de, this message translates to:
  /// **'Warte auf den Frame …'**
  String get waitingForFrame;

  /// No description provided for @frameNameQuestion.
  ///
  /// In de, this message translates to:
  /// **'Wie soll der neue Frame heißen, z. B. „Küche“?'**
  String get frameNameQuestion;

  /// No description provided for @anotherDevice.
  ///
  /// In de, this message translates to:
  /// **'Ein anderes Gerät'**
  String get anotherDevice;

  /// No description provided for @anotherDeviceHint.
  ///
  /// In de, this message translates to:
  /// **'Das Tablet scannt den QR-Code oder bekommt den Code.'**
  String get anotherDeviceHint;

  /// No description provided for @thisDevice.
  ///
  /// In de, this message translates to:
  /// **'Dieses Gerät'**
  String get thisDevice;

  /// No description provided for @thisDeviceHint.
  ///
  /// In de, this message translates to:
  /// **'Dieses Gerät wird sofort zum Frame. Deine Anmeldung hier endet.'**
  String get thisDeviceHint;

  /// No description provided for @thisDeviceTitle.
  ///
  /// In de, this message translates to:
  /// **'Dieses Gerät zum Frame machen?'**
  String get thisDeviceTitle;

  /// No description provided for @thisDeviceMessage.
  ///
  /// In de, this message translates to:
  /// **'Danach läuft hier nur noch die Diashow, und du wirst auf diesem Gerät abgemeldet. Deine Alben und Fotos bleiben natürlich erhalten.'**
  String get thisDeviceMessage;

  /// No description provided for @thisDeviceConfirm.
  ///
  /// In de, this message translates to:
  /// **'Zum Frame machen'**
  String get thisDeviceConfirm;

  /// No description provided for @frameScanHint.
  ///
  /// In de, this message translates to:
  /// **'QR-Code aus der Smile-App in den Rahmen halten'**
  String get frameScanHint;

  /// No description provided for @frameScanInstead.
  ///
  /// In de, this message translates to:
  /// **'QR-Code scannen'**
  String get frameScanInstead;

  /// No description provided for @pickSpaceForFrame.
  ///
  /// In de, this message translates to:
  /// **'Für welchen Space?'**
  String get pickSpaceForFrame;

  /// No description provided for @connectOtherDevice.
  ///
  /// In de, this message translates to:
  /// **'Anderes Gerät verbinden'**
  String get connectOtherDevice;

  /// No description provided for @reconnectHint.
  ///
  /// In de, this message translates to:
  /// **'Auf dem neuen Gerät: Smile öffnen → „Dieses Gerät als Frame verwenden“ → QR-Code scannen. Es übernimmt Alben und Einstellungen; das bisherige Gerät ist danach kein Frame mehr.'**
  String get reconnectHint;

  /// No description provided for @done.
  ///
  /// In de, this message translates to:
  /// **'Fertig'**
  String get done;

  /// No description provided for @playSlideshow.
  ///
  /// In de, this message translates to:
  /// **'Diashow'**
  String get playSlideshow;

  /// No description provided for @frameAlbumEmpty.
  ///
  /// In de, this message translates to:
  /// **'In „{album}“ sind noch keine Fotos.'**
  String frameAlbumEmpty(String album);

  /// No description provided for @frameAlbumEmptyHint.
  ///
  /// In de, this message translates to:
  /// **'Ein anderes Album wählst du in der Smile-App unter Frames.'**
  String get frameAlbumEmptyHint;

  /// No description provided for @sendVideos.
  ///
  /// In de, this message translates to:
  /// **'Videos senden'**
  String get sendVideos;

  /// No description provided for @qualityHigh.
  ///
  /// In de, this message translates to:
  /// **'Hoch'**
  String get qualityHigh;

  /// No description provided for @qualityMedium.
  ///
  /// In de, this message translates to:
  /// **'Mittel'**
  String get qualityMedium;

  /// No description provided for @qualityLow.
  ///
  /// In de, this message translates to:
  /// **'Niedrig'**
  String get qualityLow;

  /// No description provided for @qualityHighHint.
  ///
  /// In de, this message translates to:
  /// **'720p, sehr scharf – rund 24 MB pro Minute Video.'**
  String get qualityHighHint;

  /// No description provided for @qualityMediumHint.
  ///
  /// In de, this message translates to:
  /// **'Genau wie WhatsApp (480p) – rund 12 MB pro Minute Video.'**
  String get qualityMediumHint;

  /// No description provided for @qualityLowHint.
  ///
  /// In de, this message translates to:
  /// **'360p, für kleine Bildschirme – rund 6 MB pro Minute Video. Am schnellsten gesendet.'**
  String get qualityLowHint;

  /// No description provided for @ctrlBack.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get ctrlBack;

  /// No description provided for @ctrlPause.
  ///
  /// In de, this message translates to:
  /// **'Pause'**
  String get ctrlPause;

  /// No description provided for @ctrlPlay.
  ///
  /// In de, this message translates to:
  /// **'Abspielen'**
  String get ctrlPlay;

  /// No description provided for @ctrlNext.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get ctrlNext;

  /// No description provided for @ctrlNewest.
  ///
  /// In de, this message translates to:
  /// **'Neueste'**
  String get ctrlNewest;

  /// No description provided for @ctrlOverview.
  ///
  /// In de, this message translates to:
  /// **'Übersicht'**
  String get ctrlOverview;

  /// No description provided for @ctrlAlbum.
  ///
  /// In de, this message translates to:
  /// **'Album'**
  String get ctrlAlbum;

  /// No description provided for @ctrlDuration.
  ///
  /// In de, this message translates to:
  /// **'Dauer'**
  String get ctrlDuration;

  /// No description provided for @frameNewFrom.
  ///
  /// In de, this message translates to:
  /// **'Neu von {name}'**
  String frameNewFrom(String name);

  /// No description provided for @frameBackToSlideshow.
  ///
  /// In de, this message translates to:
  /// **'Zurück zur Diashow'**
  String get frameBackToSlideshow;

  /// No description provided for @durationQuestion.
  ///
  /// In de, this message translates to:
  /// **'Wie lange soll ein Foto zu sehen sein?'**
  String get durationQuestion;

  /// No description provided for @secondsValue.
  ///
  /// In de, this message translates to:
  /// **'{n} Sekunden'**
  String secondsValue(int n);

  /// No description provided for @oneMinute.
  ///
  /// In de, this message translates to:
  /// **'1 Minute'**
  String get oneMinute;

  /// No description provided for @playbackTitle.
  ///
  /// In de, this message translates to:
  /// **'Wiedergabe'**
  String get playbackTitle;

  /// No description provided for @playbackHint.
  ///
  /// In de, this message translates to:
  /// **'Was läuft und wie. Das stellt immer die App ein, egal welche Bedienstufe.'**
  String get playbackHint;

  /// No description provided for @whatPlays.
  ///
  /// In de, this message translates to:
  /// **'Was läuft'**
  String get whatPlays;

  /// No description provided for @contentAlbum.
  ///
  /// In de, this message translates to:
  /// **'Ein Album'**
  String get contentAlbum;

  /// No description provided for @contentRotate.
  ///
  /// In de, this message translates to:
  /// **'Alle Alben im Wechsel'**
  String get contentRotate;

  /// No description provided for @contentRecent.
  ///
  /// In de, this message translates to:
  /// **'Aktuelles'**
  String get contentRecent;

  /// No description provided for @recentMeans.
  ///
  /// In de, this message translates to:
  /// **'Aktuelles bedeutet'**
  String get recentMeans;

  /// No description provided for @recentLast.
  ///
  /// In de, this message translates to:
  /// **'Letzte {n} Fotos'**
  String recentLast(int n);

  /// No description provided for @playOrder.
  ///
  /// In de, this message translates to:
  /// **'Reihenfolge'**
  String get playOrder;

  /// No description provided for @orderNewest.
  ///
  /// In de, this message translates to:
  /// **'Neueste zuerst'**
  String get orderNewest;

  /// No description provided for @orderOldest.
  ///
  /// In de, this message translates to:
  /// **'Der Reihe nach'**
  String get orderOldest;

  /// No description provided for @orderShuffle.
  ///
  /// In de, this message translates to:
  /// **'Zufällig'**
  String get orderShuffle;

  /// No description provided for @atEnd.
  ///
  /// In de, this message translates to:
  /// **'Am Ende'**
  String get atEnd;

  /// No description provided for @endLoop.
  ///
  /// In de, this message translates to:
  /// **'Endlosschleife'**
  String get endLoop;

  /// No description provided for @endOverview.
  ///
  /// In de, this message translates to:
  /// **'Übersicht zeigen'**
  String get endOverview;

  /// No description provided for @displayTime.
  ///
  /// In de, this message translates to:
  /// **'Anzeigedauer'**
  String get displayTime;

  /// No description provided for @showNewNow.
  ///
  /// In de, this message translates to:
  /// **'Neue Fotos sofort zeigen'**
  String get showNewNow;

  /// No description provided for @showNewNowHint.
  ///
  /// In de, this message translates to:
  /// **'Mit „Neu von …“ oben im Bild.'**
  String get showNewNowHint;

  /// No description provided for @bigClock.
  ///
  /// In de, this message translates to:
  /// **'Große Uhr mit Datum'**
  String get bigClock;

  /// No description provided for @bigClockHint.
  ///
  /// In de, this message translates to:
  /// **'Wochentag, Datum und Uhrzeit oben rechts.'**
  String get bigClockHint;

  /// No description provided for @showSenderCaption.
  ///
  /// In de, this message translates to:
  /// **'Absender einblenden'**
  String get showSenderCaption;

  /// No description provided for @showSenderCaptionHint.
  ///
  /// In de, this message translates to:
  /// **'Album und Name oben links im Bild.'**
  String get showSenderCaptionHint;

  /// No description provided for @quietTime.
  ///
  /// In de, this message translates to:
  /// **'Nachtruhe'**
  String get quietTime;

  /// No description provided for @quietTimeHint.
  ///
  /// In de, this message translates to:
  /// **'Der Bildschirm ist in dieser Zeit dunkel.'**
  String get quietTimeHint;

  /// No description provided for @quietOff.
  ///
  /// In de, this message translates to:
  /// **'Aus'**
  String get quietOff;

  /// No description provided for @quietRange.
  ///
  /// In de, this message translates to:
  /// **'{from} bis {to}'**
  String quietRange(String from, String to);

  /// No description provided for @quietFromLabel.
  ///
  /// In de, this message translates to:
  /// **'Dunkel ab'**
  String get quietFromLabel;

  /// No description provided for @quietToLabel.
  ///
  /// In de, this message translates to:
  /// **'Hell ab'**
  String get quietToLabel;

  /// No description provided for @controlsTitle.
  ///
  /// In de, this message translates to:
  /// **'Bedienung am Frame'**
  String get controlsTitle;

  /// No description provided for @controlsHint.
  ///
  /// In de, this message translates to:
  /// **'Die App steuert den Frame immer vollständig. Die Bedienstufe legt fest, was die Person vor dem Frame zusätzlich selbst tun darf.'**
  String get controlsHint;

  /// No description provided for @controlLevel.
  ///
  /// In de, this message translates to:
  /// **'Bedienstufe'**
  String get controlLevel;

  /// No description provided for @level1.
  ///
  /// In de, this message translates to:
  /// **'Nur zuschauen'**
  String get level1;

  /// No description provided for @level1Hint.
  ///
  /// In de, this message translates to:
  /// **'Berührungen werden ignoriert. Alles kommt aus der App.'**
  String get level1Hint;

  /// No description provided for @level2.
  ///
  /// In de, this message translates to:
  /// **'Blättern'**
  String get level2;

  /// No description provided for @level2Hint.
  ///
  /// In de, this message translates to:
  /// **'Pause und ein großer Knopf „Weiter“.'**
  String get level2Hint;

  /// No description provided for @level3.
  ///
  /// In de, this message translates to:
  /// **'Einfach'**
  String get level3;

  /// No description provided for @level3Hint.
  ///
  /// In de, this message translates to:
  /// **'Zurück, Pause, Weiter und „Neueste Fotos“.'**
  String get level3Hint;

  /// No description provided for @level4.
  ///
  /// In de, this message translates to:
  /// **'Komfort'**
  String get level4;

  /// No description provided for @level4Hint.
  ///
  /// In de, this message translates to:
  /// **'Dazu Übersicht, Album wechseln und Anzeigedauer.'**
  String get level4Hint;

  /// No description provided for @level5.
  ///
  /// In de, this message translates to:
  /// **'Alles selbst'**
  String get level5;

  /// No description provided for @level5Hint.
  ///
  /// In de, this message translates to:
  /// **'Dazu alle Wiedergabe-Einstellungen am Frame.'**
  String get level5Hint;

  /// No description provided for @levelCustom.
  ///
  /// In de, this message translates to:
  /// **'Eigene Auswahl'**
  String get levelCustom;

  /// No description provided for @levelCustomHint.
  ///
  /// In de, this message translates to:
  /// **'Einzelne Schalter weichen von den Stufen ab.'**
  String get levelCustomHint;

  /// No description provided for @allowedOneByOne.
  ///
  /// In de, this message translates to:
  /// **'Einzeln erlaubt'**
  String get allowedOneByOne;

  /// No description provided for @allowNext.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get allowNext;

  /// No description provided for @allowBack.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get allowBack;

  /// No description provided for @allowPause.
  ///
  /// In de, this message translates to:
  /// **'Pause'**
  String get allowPause;

  /// No description provided for @allowNewest.
  ///
  /// In de, this message translates to:
  /// **'Neueste Fotos'**
  String get allowNewest;

  /// No description provided for @allowOverview.
  ///
  /// In de, this message translates to:
  /// **'Übersicht'**
  String get allowOverview;

  /// No description provided for @allowAlbum.
  ///
  /// In de, this message translates to:
  /// **'Album wechseln'**
  String get allowAlbum;

  /// No description provided for @allowDuration.
  ///
  /// In de, this message translates to:
  /// **'Anzeigedauer'**
  String get allowDuration;

  /// No description provided for @allowPlayback.
  ///
  /// In de, this message translates to:
  /// **'Wiedergabe-Einstellungen'**
  String get allowPlayback;

  /// No description provided for @remoteTitle.
  ///
  /// In de, this message translates to:
  /// **'Fernbedienung'**
  String get remoteTitle;

  /// No description provided for @remoteHint.
  ///
  /// In de, this message translates to:
  /// **'Funktioniert auf jeder Bedienstufe.'**
  String get remoteHint;

  /// No description provided for @remoteNewest.
  ///
  /// In de, this message translates to:
  /// **'Neueste {n} Fotos abspielen'**
  String remoteNewest(int n);

  /// No description provided for @showOnFrameNow.
  ///
  /// In de, this message translates to:
  /// **'Jetzt am Frame zeigen'**
  String get showOnFrameNow;

  /// No description provided for @nowRunning.
  ///
  /// In de, this message translates to:
  /// **'läuft gerade'**
  String get nowRunning;

  /// No description provided for @addShort.
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get addShort;

  /// No description provided for @frameOtherSpaceHint.
  ///
  /// In de, this message translates to:
  /// **'„{album}“ gehört zum Space {space}. Ein Frame zeigt nur Alben aus seinem eigenen Space oder solche, die mit seinem Space geteilt sind. Ein Admin von {space} kann das Album über „Mit einem Space teilen“ mit deinem Space teilen – danach geht es hier mit einem Tipp.'**
  String frameOtherSpaceHint(String album, String space);

  /// No description provided for @favorites.
  ///
  /// In de, this message translates to:
  /// **'Lieblingsbilder'**
  String get favorites;

  /// No description provided for @favoriteMarked.
  ///
  /// In de, this message translates to:
  /// **'Gemerkt'**
  String get favoriteMarked;

  /// No description provided for @favoriteUnmarked.
  ///
  /// In de, this message translates to:
  /// **'Nicht mehr gemerkt'**
  String get favoriteUnmarked;

  /// No description provided for @ctrlFavorite.
  ///
  /// In de, this message translates to:
  /// **'Merken'**
  String get ctrlFavorite;

  /// No description provided for @allowFavorite.
  ///
  /// In de, this message translates to:
  /// **'Lieblingsbilder merken'**
  String get allowFavorite;

  /// No description provided for @allowFavorites.
  ///
  /// In de, this message translates to:
  /// **'Lieblingsbilder abspielen'**
  String get allowFavorites;

  /// No description provided for @contentFavorites.
  ///
  /// In de, this message translates to:
  /// **'Lieblingsbilder'**
  String get contentFavorites;

  /// No description provided for @favoritesSeeAll.
  ///
  /// In de, this message translates to:
  /// **'Alle ansehen'**
  String get favoritesSeeAll;

  /// No description provided for @favoritesCount.
  ///
  /// In de, this message translates to:
  /// **'Lieblingsbilder · {n}'**
  String favoritesCount(int n);

  /// No description provided for @favoriteOnFrame.
  ///
  /// In de, this message translates to:
  /// **'Am Frame'**
  String get favoriteOnFrame;

  /// No description provided for @favoriteToday.
  ///
  /// In de, this message translates to:
  /// **'heute {time}'**
  String favoriteToday(String time);

  /// No description provided for @favoriteYesterday.
  ///
  /// In de, this message translates to:
  /// **'gestern {time}'**
  String favoriteYesterday(String time);

  /// No description provided for @favoriteFor.
  ///
  /// In de, this message translates to:
  /// **'Lieblingsbild für den Frame'**
  String get favoriteFor;

  /// No description provided for @favoriteAddedTo.
  ///
  /// In de, this message translates to:
  /// **'Lieblingsbild von „{frame}“'**
  String favoriteAddedTo(String frame);

  /// No description provided for @favoritesEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Lieblingsbilder'**
  String get favoritesEmpty;

  /// No description provided for @favoritesEmptyHint.
  ///
  /// In de, this message translates to:
  /// **'Am Frame mit dem Herz merken – oder hier in einem Album beim Foto über das Herz oben rechts.'**
  String get favoritesEmptyHint;

  /// No description provided for @favoritesRemove.
  ///
  /// In de, this message translates to:
  /// **'Entfernen'**
  String get favoritesRemove;

  /// No description provided for @favoritesRemoveAll.
  ///
  /// In de, this message translates to:
  /// **'Alle entfernen'**
  String get favoritesRemoveAll;

  /// No description provided for @favoritesRemoveAllQuestion.
  ///
  /// In de, this message translates to:
  /// **'Alle Lieblingsbilder von „{frame}“ entfernen?'**
  String favoritesRemoveAllQuestion(String frame);

  /// No description provided for @favoritesRemoveHint.
  ///
  /// In de, this message translates to:
  /// **'Die Fotos selbst bleiben in ihren Alben.'**
  String get favoritesRemoveHint;

  /// No description provided for @favoritesSelected.
  ///
  /// In de, this message translates to:
  /// **'{n} ausgewählt'**
  String favoritesSelected(int n);

  /// No description provided for @favoritesRemoveSelectedQuestion.
  ///
  /// In de, this message translates to:
  /// **'{n, plural, =1{1 Lieblingsbild} other{{n} Lieblingsbilder}} von „{frame}“ entfernen?'**
  String favoritesRemoveSelectedQuestion(int n, String frame);

  /// No description provided for @favoriteRemovedFrom.
  ///
  /// In de, this message translates to:
  /// **'Kein Lieblingsbild mehr von „{frame}“'**
  String favoriteRemovedFrom(String frame);

  /// No description provided for @favoritesAddTitle.
  ///
  /// In de, this message translates to:
  /// **'Lieblingsbilder · {frame}'**
  String favoritesAddTitle(String frame);

  /// No description provided for @favoriteForWhich.
  ///
  /// In de, this message translates to:
  /// **'Lieblingsbild für …'**
  String get favoriteForWhich;

  /// No description provided for @favoriteStateOn.
  ///
  /// In de, this message translates to:
  /// **'gemerkt'**
  String get favoriteStateOn;

  /// No description provided for @favoriteStateOff.
  ///
  /// In de, this message translates to:
  /// **'nicht gemerkt'**
  String get favoriteStateOff;

  /// No description provided for @framePhotosLoading.
  ///
  /// In de, this message translates to:
  /// **'Fotos werden geladen …'**
  String get framePhotosLoading;

  /// No description provided for @videoLengthLabel.
  ///
  /// In de, this message translates to:
  /// **'Videos'**
  String get videoLengthLabel;

  /// No description provided for @videoFull.
  ///
  /// In de, this message translates to:
  /// **'Ganze Länge'**
  String get videoFull;

  /// No description provided for @videoAsPhoto.
  ///
  /// In de, this message translates to:
  /// **'Wie ein Foto ({seconds} s)'**
  String videoAsPhoto(int seconds);

  /// No description provided for @fillLabel.
  ///
  /// In de, this message translates to:
  /// **'Bildschirm füllen'**
  String get fillLabel;

  /// No description provided for @fillNever.
  ///
  /// In de, this message translates to:
  /// **'Nie'**
  String get fillNever;

  /// No description provided for @fillAuto.
  ///
  /// In de, this message translates to:
  /// **'Wenn passend'**
  String get fillAuto;

  /// No description provided for @fillAlways.
  ///
  /// In de, this message translates to:
  /// **'Immer'**
  String get fillAlways;

  /// No description provided for @fillHint.
  ///
  /// In de, this message translates to:
  /// **'Wenn passend: füllt den Bildschirm, wenn höchstens ein schmaler Rand wegfällt – sonst das ganze Foto auf unscharfem Hintergrund.'**
  String get fillHint;

  /// No description provided for @slowZoom.
  ///
  /// In de, this message translates to:
  /// **'Langsamer Zoom'**
  String get slowZoom;

  /// No description provided for @slowZoomHint.
  ///
  /// In de, this message translates to:
  /// **'Jedes Foto wird ganz langsam etwas größer.'**
  String get slowZoomHint;

  /// No description provided for @groupBrowse.
  ///
  /// In de, this message translates to:
  /// **'Blättern'**
  String get groupBrowse;

  /// No description provided for @groupPlaying.
  ///
  /// In de, this message translates to:
  /// **'Was läuft'**
  String get groupPlaying;

  /// No description provided for @orientationLabel.
  ///
  /// In de, this message translates to:
  /// **'Ausrichtung'**
  String get orientationLabel;

  /// No description provided for @orientAuto.
  ///
  /// In de, this message translates to:
  /// **'Automatisch'**
  String get orientAuto;

  /// No description provided for @orientPortrait.
  ///
  /// In de, this message translates to:
  /// **'Hochformat'**
  String get orientPortrait;

  /// No description provided for @orientLandscape.
  ///
  /// In de, this message translates to:
  /// **'Querformat'**
  String get orientLandscape;

  /// No description provided for @slideshowSettings.
  ///
  /// In de, this message translates to:
  /// **'Diashow-Einstellungen'**
  String get slideshowSettings;

  /// No description provided for @slideshowSettingsHint.
  ///
  /// In de, this message translates to:
  /// **'Gilt für die Diashow auf diesem Handy.'**
  String get slideshowSettingsHint;

  /// No description provided for @showHiddenMenu.
  ///
  /// In de, this message translates to:
  /// **'Ausgeblendete anzeigen'**
  String get showHiddenMenu;

  /// No description provided for @showAllMenu.
  ///
  /// In de, this message translates to:
  /// **'Alle Fotos anzeigen'**
  String get showAllMenu;

  /// No description provided for @editProfile.
  ///
  /// In de, this message translates to:
  /// **'Profil bearbeiten'**
  String get editProfile;

  /// No description provided for @roleAdminHint.
  ///
  /// In de, this message translates to:
  /// **'Hat den Space angelegt und verwaltet alles.'**
  String get roleAdminHint;

  /// No description provided for @roleCoAdminHint.
  ///
  /// In de, this message translates to:
  /// **'Verwaltet den Space mit: Alben, Frames und Personen.'**
  String get roleCoAdminHint;

  /// No description provided for @roleMemberHint.
  ///
  /// In de, this message translates to:
  /// **'Stellt Fotos und Videos ins Album.'**
  String get roleMemberHint;

  /// No description provided for @roleViewerHint.
  ///
  /// In de, this message translates to:
  /// **'Sieht das Album über einen geteilten Space.'**
  String get roleViewerHint;

  /// No description provided for @sharedSpaceHint.
  ///
  /// In de, this message translates to:
  /// **'Dieser Space sieht das Album auf seinen Frames und Handys, trägt aber nichts bei.'**
  String get sharedSpaceHint;

  /// No description provided for @favorites2.
  ///
  /// In de, this message translates to:
  /// **'Lieblingsbilder'**
  String get favorites2;

  /// No description provided for @inviteMessageCodeFallback.
  ///
  /// In de, this message translates to:
  /// **'Falls der Link nicht geht: In Smile ⋮ → Code scannen → Code eintippen: {code}'**
  String inviteMessageCodeFallback(String code);
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
