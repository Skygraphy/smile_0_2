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
  /// **'Code eingeben oder QR-Code scannen'**
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
