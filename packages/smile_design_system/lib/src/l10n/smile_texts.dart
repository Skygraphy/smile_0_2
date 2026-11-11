import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'smile_texts_de.dart';
import 'smile_texts_en.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

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

  /// No description provided for @introAlbumsTitle.
  ///
  /// In de, this message translates to:
  /// **'Alben'**
  String get introAlbumsTitle;

  /// No description provided for @introAlbumsText.
  ///
  /// In de, this message translates to:
  /// **'Teilt Fotos und Videos wie bei WhatsApp – nur ohne Chat. Jeder im Album sieht sie sofort.'**
  String get introAlbumsText;

  /// No description provided for @introSpacesTitle.
  ///
  /// In de, this message translates to:
  /// **'Spaces'**
  String get introSpacesTitle;

  /// No description provided for @introSpacesText.
  ///
  /// In de, this message translates to:
  /// **'Ein Space ist eure Familie oder euer Haushalt – mit euren Alben und Frames.'**
  String get introSpacesText;

  /// No description provided for @introFramesTitle.
  ///
  /// In de, this message translates to:
  /// **'Frames'**
  String get introFramesTitle;

  /// No description provided for @introFramesText.
  ///
  /// In de, this message translates to:
  /// **'Ein Tablet wird zum Bilderrahmen – zum Beispiel für Oma. Sie muss nichts bedienen.'**
  String get introFramesText;

  /// No description provided for @introSkip.
  ///
  /// In de, this message translates to:
  /// **'Überspringen'**
  String get introSkip;

  /// No description provided for @introNext.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get introNext;

  /// No description provided for @introStart.
  ///
  /// In de, this message translates to:
  /// **'Los geht\'s'**
  String get introStart;

  /// No description provided for @introAgain.
  ///
  /// In de, this message translates to:
  /// **'Einführung ansehen'**
  String get introAgain;

  /// No description provided for @introAgainHint.
  ///
  /// In de, this message translates to:
  /// **'Die drei Seiten vom ersten Start noch einmal.'**
  String get introAgainHint;

  /// No description provided for @videoTooLongTitle.
  ///
  /// In de, this message translates to:
  /// **'Video zu lang'**
  String get videoTooLongTitle;

  /// No description provided for @videoTooLongText.
  ///
  /// In de, this message translates to:
  /// **'Videos dürfen hier höchstens {minutes} Minuten lang sein. Kürze es in der Galerie und schick es dann noch einmal.'**
  String videoTooLongText(int minutes);

  /// No description provided for @storageUsed.
  ///
  /// In de, this message translates to:
  /// **'Belegt'**
  String get storageUsed;

  /// No description provided for @storageOf.
  ///
  /// In de, this message translates to:
  /// **'{used} von {limit}'**
  String storageOf(String used, String limit);

  /// No description provided for @storageCounts.
  ///
  /// In de, this message translates to:
  /// **'{photos} Fotos · {videos} Videos'**
  String storageCounts(String photos, String videos);

  /// No description provided for @shareOutMenu.
  ///
  /// In de, this message translates to:
  /// **'Teilen …'**
  String get shareOutMenu;

  /// No description provided for @shareOutShort.
  ///
  /// In de, this message translates to:
  /// **'Teilen'**
  String get shareOutShort;

  /// No description provided for @saveToPhone.
  ///
  /// In de, this message translates to:
  /// **'Aufs Handy speichern'**
  String get saveToPhone;

  /// No description provided for @saveToPhoneShort.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get saveToPhoneShort;

  /// No description provided for @savedOne.
  ///
  /// In de, this message translates to:
  /// **'Gespeichert – in deiner Galerie im Album „Smile“.'**
  String get savedOne;

  /// No description provided for @savedMany.
  ///
  /// In de, this message translates to:
  /// **'{count} gespeichert – in deiner Galerie im Album „Smile“.'**
  String savedMany(int count);

  /// No description provided for @saveFailed.
  ///
  /// In de, this message translates to:
  /// **'Das Speichern hat leider nicht geklappt.'**
  String get saveFailed;

  /// No description provided for @saveAlbum.
  ///
  /// In de, this message translates to:
  /// **'Ganzes Album speichern'**
  String get saveAlbum;

  /// No description provided for @saveAlbumTitle.
  ///
  /// In de, this message translates to:
  /// **'{count} Fotos und Videos aufs Handy speichern?'**
  String saveAlbumTitle(int count);

  /// No description provided for @saveAlbumMessage.
  ///
  /// In de, this message translates to:
  /// **'Sie kommen in deine Galerie ins Album „Smile“. Videos, die noch nicht auf dem Handy sind, werden heruntergeladen – am besten im WLAN.'**
  String get saveAlbumMessage;

  /// No description provided for @saveProgress.
  ///
  /// In de, this message translates to:
  /// **'{done} von {count} gespeichert …'**
  String saveProgress(int done, int count);

  /// No description provided for @shareFailed.
  ///
  /// In de, this message translates to:
  /// **'Das Teilen hat leider nicht geklappt.'**
  String get shareFailed;

  /// No description provided for @preparing.
  ///
  /// In de, this message translates to:
  /// **'Wird vorbereitet …'**
  String get preparing;

  /// No description provided for @pauseZoomTitle.
  ///
  /// In de, this message translates to:
  /// **'Beim Anhalten weiter zoomen'**
  String get pauseZoomTitle;

  /// No description provided for @onThisDayTitle.
  ///
  /// In de, this message translates to:
  /// **'Heute vor einem Jahr'**
  String get onThisDayTitle;

  /// No description provided for @onThisDayHint.
  ///
  /// In de, this message translates to:
  /// **'Fotos, die an diesem Tag in früheren Jahren aufgenommen wurden, laufen heute zuerst.'**
  String get onThisDayHint;

  /// No description provided for @onThisDayYears.
  ///
  /// In de, this message translates to:
  /// **'{years, plural, =1{Heute vor einem Jahr} other{Heute vor {years} Jahren}}'**
  String onThisDayYears(int years);

  /// No description provided for @fullHdTitle.
  ///
  /// In de, this message translates to:
  /// **'Full HD'**
  String get fullHdTitle;

  /// No description provided for @fullHdHint.
  ///
  /// In de, this message translates to:
  /// **'1080p, am Tablet am schärfsten. Rund 45 MB pro Minute Video, braucht länger zum Senden. Aus: es gilt die Stufe darunter.'**
  String get fullHdHint;

  /// No description provided for @pauseZoomHint.
  ///
  /// In de, this message translates to:
  /// **'Ein angehaltenes Foto zoomt im selben Tempo weiter. Aus: Es bleibt stehen, wie es gerade ist.'**
  String get pauseZoomHint;

  /// No description provided for @tipDidYouKnow.
  ///
  /// In de, this message translates to:
  /// **'WUSSTEST DU?'**
  String get tipDidYouKnow;

  /// No description provided for @easyStopTitle.
  ///
  /// In de, this message translates to:
  /// **'Easy Stopping'**
  String get easyStopTitle;

  /// No description provided for @easyStopHint.
  ///
  /// In de, this message translates to:
  /// **'Antippen hält das Bild an, nochmal tippen lässt es weiterlaufen. Auf jeder Stufe, auch bei „Nur zuschauen“.'**
  String get easyStopHint;

  /// No description provided for @easyStoppedTitle.
  ///
  /// In de, this message translates to:
  /// **'Angehalten'**
  String get easyStoppedTitle;

  /// No description provided for @easyStoppedHint.
  ///
  /// In de, this message translates to:
  /// **'Nochmal tippen, dann geht es weiter'**
  String get easyStoppedHint;

  /// No description provided for @easyResumedTitle.
  ///
  /// In de, this message translates to:
  /// **'Läuft weiter'**
  String get easyResumedTitle;

  /// No description provided for @easyLongPressHint.
  ///
  /// In de, this message translates to:
  /// **'Lange drücken zeigt die Knöpfe'**
  String get easyLongPressHint;

  /// No description provided for @newSoundTitle.
  ///
  /// In de, this message translates to:
  /// **'Ton bei neuen Fotos'**
  String get newSoundTitle;

  /// No description provided for @newSoundHint.
  ///
  /// In de, this message translates to:
  /// **'Einmal, wenn etwas Neues ankommt. Still in der Nachtruhe.'**
  String get newSoundHint;

  /// No description provided for @newReminderTitle.
  ///
  /// In de, this message translates to:
  /// **'Erinnern, bis jemand schaut'**
  String get newReminderTitle;

  /// No description provided for @newReminderHint.
  ///
  /// In de, this message translates to:
  /// **'Der Ton kommt jede Stunde wieder, höchstens dreimal.'**
  String get newReminderHint;

  /// No description provided for @newHintTitle.
  ///
  /// In de, this message translates to:
  /// **'Hinweis auf Neues'**
  String get newHintTitle;

  /// No description provided for @newHintHint.
  ///
  /// In de, this message translates to:
  /// **'Bleibt am Frame stehen, bis jemand tippt. Ein Tippen zeigt die neuen Fotos.'**
  String get newHintHint;

  /// No description provided for @newOnePhoto.
  ///
  /// In de, this message translates to:
  /// **'Ein neues Foto'**
  String get newOnePhoto;

  /// No description provided for @newOneVideo.
  ///
  /// In de, this message translates to:
  /// **'Ein neues Video'**
  String get newOneVideo;

  /// No description provided for @newManyPhotos.
  ///
  /// In de, this message translates to:
  /// **'{count} neue Fotos'**
  String newManyPhotos(int count);

  /// No description provided for @newManyVideos.
  ///
  /// In de, this message translates to:
  /// **'{count} neue Videos'**
  String newManyVideos(int count);

  /// No description provided for @newManyMixed.
  ///
  /// In de, this message translates to:
  /// **'{count} neue Fotos und Videos'**
  String newManyMixed(int count);

  /// No description provided for @newFromNames.
  ///
  /// In de, this message translates to:
  /// **'von {names}'**
  String newFromNames(String names);

  /// No description provided for @namesAnd.
  ///
  /// In de, this message translates to:
  /// **'{first} und {last}'**
  String namesAnd(String first, String last);

  /// No description provided for @newTapToSee.
  ///
  /// In de, this message translates to:
  /// **'antippen'**
  String get newTapToSee;

  /// No description provided for @roleFrameAdmin.
  ///
  /// In de, this message translates to:
  /// **'Frame-Admin'**
  String get roleFrameAdmin;

  /// No description provided for @frameAdminHint.
  ///
  /// In de, this message translates to:
  /// **'Bestimmt bei diesem Frame alles: was am Frame bedient werden darf und welche Alben laufen.'**
  String get frameAdminHint;

  /// No description provided for @inviteFrameAdmin.
  ///
  /// In de, this message translates to:
  /// **'Frame-Admin einladen'**
  String get inviteFrameAdmin;

  /// No description provided for @inviteMoreFrameAdmin.
  ///
  /// In de, this message translates to:
  /// **'Weitere Person einladen'**
  String get inviteMoreFrameAdmin;

  /// No description provided for @frameAdminFor.
  ///
  /// In de, this message translates to:
  /// **'Frame-Admin von {frame}'**
  String frameAdminFor(String frame);

  /// No description provided for @qrScanHintFrameAdmin.
  ///
  /// In de, this message translates to:
  /// **'Mit der Handykamera scannen oder in Smile: ⋮ → Code scannen. Frame-Admin wird man nur per QR-Code vor Ort.'**
  String get qrScanHintFrameAdmin;

  /// No description provided for @inviteFrameAdminFrom.
  ///
  /// In de, this message translates to:
  /// **'{name} möchte dich zum Frame-Admin machen. Du bestimmst dann, was am Frame bedient werden darf und welche Alben dort laufen.'**
  String inviteFrameAdminFrom(String name);

  /// No description provided for @acceptedFrameAdmin.
  ///
  /// In de, this message translates to:
  /// **'Du bist jetzt Frame-Admin von {frame}.'**
  String acceptedFrameAdmin(String frame);

  /// No description provided for @redeemJoinedFrameAdmin.
  ///
  /// In de, this message translates to:
  /// **'Du bist jetzt Frame-Admin von {frame}.'**
  String redeemJoinedFrameAdmin(String frame);

  /// No description provided for @frameAdminInvited.
  ///
  /// In de, this message translates to:
  /// **'Eingeladen, noch nicht angenommen'**
  String get frameAdminInvited;

  /// No description provided for @withdrawInvite.
  ///
  /// In de, this message translates to:
  /// **'Einladung zurückziehen'**
  String get withdrawInvite;

  /// No description provided for @endFrameAdmin.
  ///
  /// In de, this message translates to:
  /// **'Frame-Admin beenden'**
  String get endFrameAdmin;

  /// No description provided for @endFrameAdminTitle.
  ///
  /// In de, this message translates to:
  /// **'{name} als Frame-Admin beenden?'**
  String endFrameAdminTitle(String name);

  /// No description provided for @endFrameAdminMessage.
  ///
  /// In de, this message translates to:
  /// **'{name} bestimmt dann nicht mehr über {frame}. Der Frame läuft weiter wie eingestellt.'**
  String endFrameAdminMessage(String name, String frame);

  /// No description provided for @giveUpFrameAdmin.
  ///
  /// In de, this message translates to:
  /// **'Frame-Admin abgeben'**
  String get giveUpFrameAdmin;

  /// No description provided for @giveUpFrameAdminMessage.
  ///
  /// In de, this message translates to:
  /// **'Du bestimmst dann nicht mehr über {frame}. Der Frame läuft weiter wie eingestellt.'**
  String giveUpFrameAdminMessage(String frame);

  /// No description provided for @frameAdminPersonHint.
  ///
  /// In de, this message translates to:
  /// **'Frame-Admin von {frame}. Bestimmt die Bedienung und welche Alben laufen. Fotos, Alben und Personen im Space verwaltet sie oder er nicht.'**
  String frameAdminPersonHint(String frame);

  /// No description provided for @alreadyFrameAdmin.
  ///
  /// In de, this message translates to:
  /// **'Schon Frame-Admin oder Admin'**
  String get alreadyFrameAdmin;

  /// No description provided for @youAreFrameAdmin.
  ///
  /// In de, this message translates to:
  /// **'du bist Frame-Admin'**
  String get youAreFrameAdmin;

  /// No description provided for @unlockSection.
  ///
  /// In de, this message translates to:
  /// **'Am Frame entsperren'**
  String get unlockSection;

  /// No description provided for @unlockHint.
  ///
  /// In de, this message translates to:
  /// **'Lange auf die Uhr drücken und den Code eingeben: Der Frame zeigt dann alle Knöpfe, bis er sich nach 2 Minuten ohne Berührung wieder sperrt.'**
  String get unlockHint;

  /// No description provided for @unlockSetCode.
  ///
  /// In de, this message translates to:
  /// **'Code festlegen'**
  String get unlockSetCode;

  /// No description provided for @unlockChangeCode.
  ///
  /// In de, this message translates to:
  /// **'Code ändern'**
  String get unlockChangeCode;

  /// No description provided for @unlockCodeIsSet.
  ///
  /// In de, this message translates to:
  /// **'Ein Code ist festgelegt.'**
  String get unlockCodeIsSet;

  /// No description provided for @unlockNoCode.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Code: Am Frame lässt sich dann nichts entsperren.'**
  String get unlockNoCode;

  /// No description provided for @unlockCodeTitle.
  ///
  /// In de, this message translates to:
  /// **'Code für {frame}'**
  String unlockCodeTitle(String frame);

  /// No description provided for @unlockCodeDialogHint.
  ///
  /// In de, this message translates to:
  /// **'4 Ziffern. Wer Frame-Admin oder Admin ist, kann ihn jederzeit neu festlegen.'**
  String get unlockCodeDialogHint;

  /// No description provided for @unlockCodeRepeat.
  ///
  /// In de, this message translates to:
  /// **'Zur Bestätigung noch einmal'**
  String get unlockCodeRepeat;

  /// No description provided for @unlockCodeMismatch.
  ///
  /// In de, this message translates to:
  /// **'Die beiden Codes sind verschieden. Bitte noch einmal.'**
  String get unlockCodeMismatch;

  /// No description provided for @unlockCodeSaved.
  ///
  /// In de, this message translates to:
  /// **'Code gespeichert'**
  String get unlockCodeSaved;

  /// No description provided for @unlockRemoveCode.
  ///
  /// In de, this message translates to:
  /// **'Code entfernen'**
  String get unlockRemoveCode;

  /// No description provided for @unlockRemoveMessage.
  ///
  /// In de, this message translates to:
  /// **'Am Frame lässt sich dann nichts mehr entsperren – wie vor dem ersten Code.'**
  String get unlockRemoveMessage;

  /// No description provided for @unlockCodeRemoved.
  ///
  /// In de, this message translates to:
  /// **'Code entfernt'**
  String get unlockCodeRemoved;

  /// No description provided for @unlockEnterCode.
  ///
  /// In de, this message translates to:
  /// **'Code eingeben'**
  String get unlockEnterCode;

  /// No description provided for @unlockWrongCode.
  ///
  /// In de, this message translates to:
  /// **'Falscher Code'**
  String get unlockWrongCode;

  /// No description provided for @unlockWaitMinute.
  ///
  /// In de, this message translates to:
  /// **'Bitte 1 Minute warten'**
  String get unlockWaitMinute;

  /// No description provided for @unlockedBadge.
  ///
  /// In de, this message translates to:
  /// **'Entsperrt'**
  String get unlockedBadge;

  /// No description provided for @lockNow.
  ///
  /// In de, this message translates to:
  /// **'Sperren'**
  String get lockNow;

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

  /// No description provided for @sharedPhotos.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Foto} other{{count} Fotos}}'**
  String sharedPhotos(int count);

  /// No description provided for @sharedVideos.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Video} other{{count} Videos}}'**
  String sharedVideos(int count);

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
  /// **'Freigabe für {space} beenden?'**
  String endShareTitle(String space);

  /// No description provided for @endShareMessage.
  ///
  /// In de, this message translates to:
  /// **'{space} sieht {album} danach nicht mehr, auch nicht auf seinen Frames.'**
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

  /// No description provided for @sharedAlbumOwnedBy.
  ///
  /// In de, this message translates to:
  /// **'Dieses Album gehört {owner} aus dem Space {home} und ist mit deinem Space {space} geteilt.'**
  String sharedAlbumOwnedBy(String owner, String home, String space);

  /// No description provided for @removeFromSpace.
  ///
  /// In de, this message translates to:
  /// **'Aus {space} entfernen'**
  String removeFromSpace(String space);

  /// No description provided for @removeFromSpaceHint.
  ///
  /// In de, this message translates to:
  /// **'Das Album gehört {owner} und bleibt erhalten.'**
  String removeFromSpaceHint(String owner);

  /// No description provided for @removeFromSpaceTitle.
  ///
  /// In de, this message translates to:
  /// **'{album} aus {space} entfernen?'**
  String removeFromSpaceTitle(String album, String space);

  /// No description provided for @removeFromSpaceMessage.
  ///
  /// In de, this message translates to:
  /// **'Danach siehst du das Album nicht mehr: nicht in deiner Albumliste und nicht auf deinen Frames, und du kannst dort nichts mehr posten.\n\nEs gehört {owner} und bleibt mit allen Fotos erhalten. {owner} kann es wieder mit {space} teilen.'**
  String removeFromSpaceMessage(String owner, String space);

  /// No description provided for @deleteAlbum.
  ///
  /// In de, this message translates to:
  /// **'Album löschen'**
  String get deleteAlbum;

  /// No description provided for @deleteAlbumTitle.
  ///
  /// In de, this message translates to:
  /// **'Album {album} löschen?'**
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
  /// **'z. B. Familie Müller'**
  String get createSpaceHint;

  /// No description provided for @nameMissing.
  ///
  /// In de, this message translates to:
  /// **'Bitte gib einen Namen ein.'**
  String get nameMissing;

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
  /// **'z. B. Enkelkinder'**
  String get createAlbumHint;

  /// No description provided for @noAlbumYet.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Album'**
  String get noAlbumYet;

  /// No description provided for @sharedIntoSpace.
  ///
  /// In de, this message translates to:
  /// **'Mit dem Space {space} geteilt'**
  String sharedIntoSpace(String space);

  /// No description provided for @sharedFromSpace.
  ///
  /// In de, this message translates to:
  /// **'aus dem Space {space} · nur ansehen'**
  String sharedFromSpace(String space);

  /// No description provided for @viewOnly.
  ///
  /// In de, this message translates to:
  /// **'nur ansehen'**
  String get viewOnly;

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
  /// **'{album} nicht mehr anzeigen?'**
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

  /// No description provided for @actionStepDown.
  ///
  /// In de, this message translates to:
  /// **'Abgeben'**
  String get actionStepDown;

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
  /// **'Space {space} löschen?'**
  String deleteSpaceTitle(String space);

  /// No description provided for @deleteSpaceMessage.
  ///
  /// In de, this message translates to:
  /// **'Der Space verschwindet mit allen Alben, Fotos und Frames sofort für alle; alle Beteiligten werden benachrichtigt. 30 Tage lang kannst du ihn im Papierkorb wiederherstellen.'**
  String get deleteSpaceMessage;

  /// No description provided for @inTrash.
  ///
  /// In de, this message translates to:
  /// **'{name} ist im Papierkorb.'**
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
  /// **'zeigt gerade {album}'**
  String frameShowsAlbum(String album);

  /// No description provided for @frameSwitched.
  ///
  /// In de, this message translates to:
  /// **'{frame} zeigt jetzt {album}.'**
  String frameSwitched(String frame, String album);

  /// No description provided for @removeFromFrameTitle.
  ///
  /// In de, this message translates to:
  /// **'{album} vom Frame entfernen?'**
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
  /// **'Du verwaltest jetzt {space} mit.'**
  String acceptedCoAdmin(String space);

  /// No description provided for @acceptedAlbum.
  ///
  /// In de, this message translates to:
  /// **'{album} ist jetzt in deinen Alben.'**
  String acceptedAlbum(String album);

  /// No description provided for @acceptedShare.
  ///
  /// In de, this message translates to:
  /// **'{album} ist jetzt mit deinem Space geteilt.'**
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
  /// **'{name} ist wiederhergestellt.'**
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

  /// No description provided for @aboutSmile.
  ///
  /// In de, this message translates to:
  /// **'Über Smile'**
  String get aboutSmile;

  /// No description provided for @aboutSmileHint.
  ///
  /// In de, this message translates to:
  /// **'Version {version} · Impressum · Datenschutz'**
  String aboutSmileHint(String version);

  /// No description provided for @versionValue.
  ///
  /// In de, this message translates to:
  /// **'Version {version}'**
  String versionValue(String version);

  /// No description provided for @impressum.
  ///
  /// In de, this message translates to:
  /// **'Impressum'**
  String get impressum;

  /// No description provided for @privacyPolicy.
  ///
  /// In de, this message translates to:
  /// **'Datenschutz'**
  String get privacyPolicy;

  /// No description provided for @deleteAccountWebHint.
  ///
  /// In de, this message translates to:
  /// **'So geht es, auch ohne App'**
  String get deleteAccountWebHint;

  /// No description provided for @openSourceLicenses.
  ///
  /// In de, this message translates to:
  /// **'Open-Source-Lizenzen'**
  String get openSourceLicenses;

  /// No description provided for @openSourceThanks.
  ///
  /// In de, this message translates to:
  /// **'Smile verwendet diese freie Software. Danke an alle, die sie entwickeln.'**
  String get openSourceThanks;

  /// No description provided for @searchHint.
  ///
  /// In de, this message translates to:
  /// **'Suchen …'**
  String get searchHint;

  /// No description provided for @licenseCount.
  ///
  /// In de, this message translates to:
  /// **'{count} Lizenzen'**
  String licenseCount(int count);

  /// No description provided for @loginPrivacyBefore.
  ///
  /// In de, this message translates to:
  /// **'Mit der Anmeldung gilt unsere '**
  String get loginPrivacyBefore;

  /// No description provided for @loginPrivacyLink.
  ///
  /// In de, this message translates to:
  /// **'Datenschutzerklärung'**
  String get loginPrivacyLink;

  /// No description provided for @loginPrivacyAfter.
  ///
  /// In de, this message translates to:
  /// **'.'**
  String get loginPrivacyAfter;

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
  /// **'Frame {name} löschen?'**
  String deleteFrameTitle(String name);

  /// No description provided for @deleteFrameMessage.
  ///
  /// In de, this message translates to:
  /// **'Der Frame wird endgültig entfernt. Das Tablet löscht seine Fotos und zeigt wieder den Bildschirm zum Verbinden. Zum Weiterverwenden einfach neu verbinden.'**
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
  /// **'Bild für {name}'**
  String pictureFor(String name);

  /// No description provided for @coverFor.
  ///
  /// In de, this message translates to:
  /// **'Titelbild für {name}'**
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
  /// **'{name} hat ein neues Titelbild.'**
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

  /// No description provided for @loginEmailMissing.
  ///
  /// In de, this message translates to:
  /// **'Bitte gib deine E-Mail-Adresse ein.'**
  String get loginEmailMissing;

  /// No description provided for @loginEmailInvalid.
  ///
  /// In de, this message translates to:
  /// **'Das ist keine gültige E-Mail-Adresse. Bitte prüfe sie.'**
  String get loginEmailInvalid;

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
  /// **'Nur bei dir weg, über ⋮ → Ausgeblendete anzeigen zurückholbar'**
  String get deleteForMeHint;

  /// No description provided for @deleteOnlyOwn.
  ///
  /// In de, this message translates to:
  /// **'Für alle löschen kannst du nur deine eigenen Fotos.'**
  String get deleteOnlyOwn;

  /// No description provided for @inviteToNamed.
  ///
  /// In de, this message translates to:
  /// **'In {name} einladen'**
  String inviteToNamed(String name);

  /// No description provided for @coAdminFor.
  ///
  /// In de, this message translates to:
  /// **'Co-Admin für {name}'**
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
  /// **'Mit der Handykamera scannen oder in Smile: ⋮ → Code scannen. Oder den Code eintippen.'**
  String get qrScanHint;

  /// No description provided for @qrScanHintCoAdmin.
  ///
  /// In de, this message translates to:
  /// **'Mit der Handykamera scannen oder in Smile: ⋮ → Code scannen. Co-Admin wird man nur per QR-Code vor Ort.'**
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
  /// **'Komm in mein Smile-Album {album}! Einfach auf den Link tippen: {link}'**
  String inviteMessageMember(String album, String link);

  /// No description provided for @inviteMessageShare.
  ///
  /// In de, this message translates to:
  /// **'Ich möchte mein Smile-Album {album} mit deinem Space teilen. Einfach auf den Link tippen: {link}'**
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
  /// **'Du bist jetzt im Album {name}.'**
  String redeemJoinedAlbum(String name);

  /// No description provided for @redeemJoinedShare.
  ///
  /// In de, this message translates to:
  /// **'{album} ist jetzt in deinem Space {space} zu sehen.'**
  String redeemJoinedShare(String album, String space);

  /// No description provided for @redeemJoinedCoAdmin.
  ///
  /// In de, this message translates to:
  /// **'Du bist jetzt Co-Admin von {space}.'**
  String redeemJoinedCoAdmin(String space);

  /// No description provided for @redeemRequestedTitle.
  ///
  /// In de, this message translates to:
  /// **'Anfrage gesendet'**
  String get redeemRequestedTitle;

  /// No description provided for @redeemRequested.
  ///
  /// In de, this message translates to:
  /// **'Die Admins von {name} entscheiden. Du bekommst Bescheid.'**
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
  /// **'Verbunden · meldet sich gleich'**
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
  /// **'{name} verbinden'**
  String connectNamedFrame(String name);

  /// No description provided for @connectFrameHint.
  ///
  /// In de, this message translates to:
  /// **'Auf dem Tablet: Smile öffnen → Dieses Gerät als Frame verwenden → QR-Code scannen. Gilt 15 Minuten.'**
  String get connectFrameHint;

  /// No description provided for @waitingForFrame.
  ///
  /// In de, this message translates to:
  /// **'Warte auf den Frame …'**
  String get waitingForFrame;

  /// No description provided for @frameNameQuestion.
  ///
  /// In de, this message translates to:
  /// **'Wie soll der neue Frame heißen, z. B. Küche?'**
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
  /// **'Auf dem neuen Gerät: Smile öffnen → Dieses Gerät als Frame verwenden → QR-Code scannen. Es übernimmt Alben und Einstellungen; das bisherige Gerät ist danach kein Frame mehr.'**
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
  /// **'In {album} sind noch keine Fotos.'**
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
  /// **'Oben im Bild steht, von wem es kommt.'**
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
  /// **'Nur Antippen: hält das Bild an und lässt es weiterlaufen. Alles andere kommt aus der App.'**
  String get level1Hint;

  /// No description provided for @level2.
  ///
  /// In de, this message translates to:
  /// **'Blättern'**
  String get level2;

  /// No description provided for @level2Hint.
  ///
  /// In de, this message translates to:
  /// **'Pause und ein großer Weiter-Knopf.'**
  String get level2Hint;

  /// No description provided for @level3.
  ///
  /// In de, this message translates to:
  /// **'Einfach'**
  String get level3;

  /// No description provided for @level3Hint.
  ///
  /// In de, this message translates to:
  /// **'Zurück, Pause, Weiter und Neueste Fotos.'**
  String get level3Hint;

  /// No description provided for @level4.
  ///
  /// In de, this message translates to:
  /// **'Komfort'**
  String get level4;

  /// No description provided for @level4Hint.
  ///
  /// In de, this message translates to:
  /// **'Dazu Übersicht, Album wechseln, Anzeigedauer und Titel ein- oder ausblenden.'**
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
  /// **'{album} gehört zum Space {space}. Ein Frame zeigt nur Alben aus seinem eigenen Space oder solche, die mit seinem Space geteilt sind. Ein Admin von {space} kann das Album über Album-Info → Mit einem Space teilen mit deinem Space teilen – danach geht es hier mit einem Tipp.'**
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

  /// No description provided for @showOnFrameSent.
  ///
  /// In de, this message translates to:
  /// **'Wird jetzt auf {frame} gezeigt'**
  String showOnFrameSent(String frame);

  /// No description provided for @showOnFrameOffline.
  ///
  /// In de, this message translates to:
  /// **'{frame} ist gerade nicht erreichbar. Das Foto erscheint dort nicht.'**
  String showOnFrameOffline(String frame);

  /// No description provided for @favoriteAddedTo.
  ///
  /// In de, this message translates to:
  /// **'Lieblingsbild von {frame}'**
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
  /// **'Alle Lieblingsbilder von {frame} entfernen?'**
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
  /// **'{n, plural, =1{1 Lieblingsbild} other{{n} Lieblingsbilder}} von {frame} entfernen?'**
  String favoritesRemoveSelectedQuestion(int n, String frame);

  /// No description provided for @favoriteRemovedFrom.
  ///
  /// In de, this message translates to:
  /// **'Kein Lieblingsbild mehr von {frame}'**
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

  /// No description provided for @slideshowSettingsMore.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen …'**
  String get slideshowSettingsMore;

  /// No description provided for @slideshowPause.
  ///
  /// In de, this message translates to:
  /// **'Anhalten'**
  String get slideshowPause;

  /// No description provided for @slideshowResume.
  ///
  /// In de, this message translates to:
  /// **'Weiter abspielen'**
  String get slideshowResume;

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

  /// No description provided for @smileName.
  ///
  /// In de, this message translates to:
  /// **'Smile-Name'**
  String get smileName;

  /// No description provided for @smileNameChoose.
  ///
  /// In de, this message translates to:
  /// **'Smile-Namen wählen'**
  String get smileNameChoose;

  /// No description provided for @smileNameHint.
  ///
  /// In de, this message translates to:
  /// **'Wer deinen Smile-Namen genau kennt, findet dich in Smile und kann dich einladen. Gefunden wird nur der ganze Name, niemand kann stöbern.'**
  String get smileNameHint;

  /// No description provided for @smileNameRules.
  ///
  /// In de, this message translates to:
  /// **'3 bis 24 Zeichen: Kleinbuchstaben, Ziffern, Punkt und Unterstrich.'**
  String get smileNameRules;

  /// No description provided for @smileNameFree.
  ///
  /// In de, this message translates to:
  /// **'Frei'**
  String get smileNameFree;

  /// No description provided for @smileNameIsFree.
  ///
  /// In de, this message translates to:
  /// **'@{name} ist frei. Mit Speichern gehört er dir.'**
  String smileNameIsFree(String name);

  /// No description provided for @smileNameIsTaken.
  ///
  /// In de, this message translates to:
  /// **'@{name} ist schon vergeben. Bitte wähle einen anderen.'**
  String smileNameIsTaken(String name);

  /// No description provided for @smileNameTooShort.
  ///
  /// In de, this message translates to:
  /// **'Noch zu kurz. Mindestens 3 Zeichen.'**
  String get smileNameTooShort;

  /// No description provided for @smileNameTooLong.
  ///
  /// In de, this message translates to:
  /// **'Zu lang. Höchstens 24 Zeichen.'**
  String get smileNameTooLong;

  /// No description provided for @smileNameBadChar.
  ///
  /// In de, this message translates to:
  /// **'Das Zeichen {char} geht nicht. Erlaubt sind a–z, 0–9, Punkt und Unterstrich.'**
  String smileNameBadChar(String char);

  /// No description provided for @smileNameSpace.
  ///
  /// In de, this message translates to:
  /// **'Leerzeichen gehen nicht. Nimm einen Punkt oder Unterstrich.'**
  String get smileNameSpace;

  /// No description provided for @smileNameUmlaut.
  ///
  /// In de, this message translates to:
  /// **'Umlaute gehen nicht. Schreib ae, oe, ue oder ss.'**
  String get smileNameUmlaut;

  /// No description provided for @smileNameBadStart.
  ///
  /// In de, this message translates to:
  /// **'Am Anfang muss ein Buchstabe oder eine Ziffer stehen.'**
  String get smileNameBadStart;

  /// No description provided for @smileNameDotAtEnd.
  ///
  /// In de, this message translates to:
  /// **'Kein Punkt am Ende.'**
  String get smileNameDotAtEnd;

  /// No description provided for @smileNameDoubleDot.
  ///
  /// In de, this message translates to:
  /// **'Keine zwei Punkte hintereinander.'**
  String get smileNameDoubleDot;

  /// No description provided for @smileNameReserved.
  ///
  /// In de, this message translates to:
  /// **'Diesen Namen kann man nicht wählen. Bitte wähle einen anderen.'**
  String get smileNameReserved;

  /// No description provided for @smileNameSuggestions.
  ///
  /// In de, this message translates to:
  /// **'Diese sind frei:'**
  String get smileNameSuggestions;

  /// No description provided for @myCardHandlePlaceholder.
  ///
  /// In de, this message translates to:
  /// **'@ dein Smile-Name'**
  String get myCardHandlePlaceholder;

  /// No description provided for @myCardQrPlaceholder.
  ///
  /// In de, this message translates to:
  /// **'Hier erscheint dein QR-Code'**
  String get myCardQrPlaceholder;

  /// No description provided for @myCardPreviewHint.
  ///
  /// In de, this message translates to:
  /// **'Mit einem Smile-Namen bekommst du diese Karte. Wer sie scannt, kann dich einladen.'**
  String get myCardPreviewHint;

  /// No description provided for @myCardTakeSuggestion.
  ///
  /// In de, this message translates to:
  /// **'@{name} übernehmen'**
  String myCardTakeSuggestion(String name);

  /// No description provided for @myCardOtherName.
  ///
  /// In de, this message translates to:
  /// **'Anderen Namen wählen'**
  String get myCardOtherName;

  /// No description provided for @smileNameTaken.
  ///
  /// In de, this message translates to:
  /// **'Schon vergeben'**
  String get smileNameTaken;

  /// No description provided for @smileNameInvalid.
  ///
  /// In de, this message translates to:
  /// **'Nur a–z, 0–9, Punkt und Unterstrich, 3 bis 24 Zeichen'**
  String get smileNameInvalid;

  /// No description provided for @smileNameRemove.
  ///
  /// In de, this message translates to:
  /// **'Smile-Namen entfernen'**
  String get smileNameRemove;

  /// No description provided for @smileNameSaveError.
  ///
  /// In de, this message translates to:
  /// **'Der Smile-Name konnte nicht gespeichert werden. Bitte versuche es noch einmal.'**
  String get smileNameSaveError;

  /// No description provided for @myCard.
  ///
  /// In de, this message translates to:
  /// **'Meine Karte'**
  String get myCard;

  /// No description provided for @myCardHint.
  ///
  /// In de, this message translates to:
  /// **'Zeig diese Karte her oder teile sie, damit dich jemand in ein Album einladen kann.'**
  String get myCardHint;

  /// No description provided for @shareMyCard.
  ///
  /// In de, this message translates to:
  /// **'Meine Karte teilen'**
  String get shareMyCard;

  /// No description provided for @myCardMessage.
  ///
  /// In de, this message translates to:
  /// **'Lade mich in Smile ein: {link}'**
  String myCardMessage(String link);

  /// No description provided for @myCardNeedsName.
  ///
  /// In de, this message translates to:
  /// **'Wähle zuerst einen Smile-Namen. Dann bekommst du deine Karte mit QR-Code.'**
  String get myCardNeedsName;

  /// No description provided for @searchNameOrHandle.
  ///
  /// In de, this message translates to:
  /// **'Name oder @Smile-Name'**
  String get searchNameOrHandle;

  /// No description provided for @personNotFound.
  ///
  /// In de, this message translates to:
  /// **'Diesen Smile-Namen gibt es nicht.'**
  String get personNotFound;

  /// No description provided for @personIsYou.
  ///
  /// In de, this message translates to:
  /// **'Das ist deine eigene Karte.'**
  String get personIsYou;

  /// No description provided for @inviteIntoAlbum.
  ///
  /// In de, this message translates to:
  /// **'In ein Album einladen'**
  String get inviteIntoAlbum;

  /// No description provided for @pickAlbumToInvite.
  ///
  /// In de, this message translates to:
  /// **'In welches Album?'**
  String get pickAlbumToInvite;

  /// No description provided for @noAlbumsToInvite.
  ///
  /// In de, this message translates to:
  /// **'Du verwaltest noch kein Album, in das du einladen kannst.'**
  String get noAlbumsToInvite;

  /// No description provided for @alreadyInAlbum.
  ///
  /// In de, this message translates to:
  /// **'Schon im Album'**
  String get alreadyInAlbum;

  /// No description provided for @alreadyAdmin.
  ///
  /// In de, this message translates to:
  /// **'Schon Admin oder Co-Admin'**
  String get alreadyAdmin;

  /// No description provided for @managesNoSpace.
  ///
  /// In de, this message translates to:
  /// **'Verwaltet keinen Space'**
  String get managesNoSpace;

  /// No description provided for @noPersonFound.
  ///
  /// In de, this message translates to:
  /// **'Niemand gefunden. Fremde nur mit ganzem @Smile-Namen.'**
  String get noPersonFound;

  /// No description provided for @fromContacts.
  ///
  /// In de, this message translates to:
  /// **'Aus Kontakten'**
  String get fromContacts;

  /// No description provided for @contactsPermTitle.
  ///
  /// In de, this message translates to:
  /// **'Kontakte in Smile finden'**
  String get contactsPermTitle;

  /// No description provided for @contactsPermText.
  ///
  /// In de, this message translates to:
  /// **'Smile prüft, wer aus deinem Telefonbuch schon Smile hat. Alle anderen kannst du per SMS einladen.'**
  String get contactsPermText;

  /// No description provided for @contactsPermPoint1.
  ///
  /// In de, this message translates to:
  /// **'Dein Telefonbuch bleibt auf dem Handy. Zum Prüfen gehen nur unlesbare Prüfwerte an Smile.'**
  String get contactsPermPoint1;

  /// No description provided for @contactsPermPoint2.
  ///
  /// In de, this message translates to:
  /// **'Smile speichert keine Kontakte und schreibt niemanden von sich aus an.'**
  String get contactsPermPoint2;

  /// No description provided for @contactsPermPoint3.
  ///
  /// In de, this message translates to:
  /// **'Du kannst es in den Android-Einstellungen jederzeit wieder ausschalten.'**
  String get contactsPermPoint3;

  /// No description provided for @contactsContinue.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get contactsContinue;

  /// No description provided for @notNow.
  ///
  /// In de, this message translates to:
  /// **'Nicht jetzt'**
  String get notNow;

  /// No description provided for @contactsDenied.
  ///
  /// In de, this message translates to:
  /// **'Smile darf deine Kontakte noch nicht sehen. Du kannst es in den Einstellungen erlauben.'**
  String get contactsDenied;

  /// No description provided for @openSettings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen öffnen'**
  String get openSettings;

  /// No description provided for @searchContact.
  ///
  /// In de, this message translates to:
  /// **'Kontakt suchen'**
  String get searchContact;

  /// No description provided for @inSmile.
  ///
  /// In de, this message translates to:
  /// **'In Smile'**
  String get inSmile;

  /// No description provided for @notInSmile.
  ///
  /// In de, this message translates to:
  /// **'Noch nicht in Smile'**
  String get notInSmile;

  /// No description provided for @inSmileAs.
  ///
  /// In de, this message translates to:
  /// **'in Smile: {name}'**
  String inSmileAs(String name);

  /// No description provided for @contactInvite.
  ///
  /// In de, this message translates to:
  /// **'Einladen'**
  String get contactInvite;

  /// No description provided for @noContacts.
  ///
  /// In de, this message translates to:
  /// **'Keine Kontakte gefunden.'**
  String get noContacts;

  /// No description provided for @contactsOnlySmileHint.
  ///
  /// In de, this message translates to:
  /// **'Co-Admin kann nur werden, wer schon Smile hat.'**
  String get contactsOnlySmileHint;

  /// No description provided for @contactInviteTitle.
  ///
  /// In de, this message translates to:
  /// **'Einladung zu Smile senden'**
  String get contactInviteTitle;

  /// No description provided for @contactInviteText.
  ///
  /// In de, this message translates to:
  /// **'{name} hat noch kein Smile. Möchtest du eine Einladung schicken?'**
  String contactInviteText(String name);

  /// No description provided for @contactMessageLabel.
  ///
  /// In de, this message translates to:
  /// **'Nachricht'**
  String get contactMessageLabel;

  /// No description provided for @sendSms.
  ///
  /// In de, this message translates to:
  /// **'Per SMS senden'**
  String get sendSms;

  /// No description provided for @sendWhatsApp.
  ///
  /// In de, this message translates to:
  /// **'Per WhatsApp senden'**
  String get sendWhatsApp;

  /// No description provided for @sendEmail.
  ///
  /// In de, this message translates to:
  /// **'Per E-Mail senden'**
  String get sendEmail;

  /// No description provided for @sendOther.
  ///
  /// In de, this message translates to:
  /// **'Mit anderer App senden'**
  String get sendOther;

  /// No description provided for @contactSmsMember.
  ///
  /// In de, this message translates to:
  /// **'Ich lade dich in mein Smile-Album {album} ein. Dort teilen wir Fotos und Videos: {link}'**
  String contactSmsMember(String album, String link);

  /// No description provided for @phoneMobile.
  ///
  /// In de, this message translates to:
  /// **'Mobil'**
  String get phoneMobile;

  /// No description provided for @phoneHome.
  ///
  /// In de, this message translates to:
  /// **'Privat'**
  String get phoneHome;

  /// No description provided for @phoneWork.
  ///
  /// In de, this message translates to:
  /// **'Arbeit'**
  String get phoneWork;

  /// No description provided for @captionHint.
  ///
  /// In de, this message translates to:
  /// **'Titel hinzufügen …'**
  String get captionHint;

  /// No description provided for @tipLabel.
  ///
  /// In de, this message translates to:
  /// **'TIPP'**
  String get tipLabel;

  /// No description provided for @tipUnderstood.
  ///
  /// In de, this message translates to:
  /// **'Verstanden'**
  String get tipUnderstood;

  /// No description provided for @tipNoMore.
  ///
  /// In de, this message translates to:
  /// **'Keine Tipps mehr'**
  String get tipNoMore;

  /// No description provided for @tipsSection.
  ///
  /// In de, this message translates to:
  /// **'Tipps'**
  String get tipsSection;

  /// No description provided for @tipsShow.
  ///
  /// In de, this message translates to:
  /// **'Tipps anzeigen'**
  String get tipsShow;

  /// No description provided for @tipsShowHint.
  ///
  /// In de, this message translates to:
  /// **'Ab und zu ein kurzer Hinweis, was Smile noch kann.'**
  String get tipsShowHint;

  /// No description provided for @tipsReset.
  ///
  /// In de, this message translates to:
  /// **'Tipps von vorne zeigen'**
  String get tipsReset;

  /// No description provided for @tipsResetHint.
  ///
  /// In de, this message translates to:
  /// **'Auch die schon gesehenen kommen wieder.'**
  String get tipsResetHint;

  /// No description provided for @tipsResetDone.
  ///
  /// In de, this message translates to:
  /// **'Die Tipps kommen wieder von vorne.'**
  String get tipsResetDone;

  /// No description provided for @soundsSection.
  ///
  /// In de, this message translates to:
  /// **'Töne'**
  String get soundsSection;

  /// No description provided for @albumSounds.
  ///
  /// In de, this message translates to:
  /// **'Töne im Album'**
  String get albumSounds;

  /// No description provided for @albumSoundsHint.
  ///
  /// In de, this message translates to:
  /// **'Ein Plopp beim Senden und bei neuen Fotos im offenen Album. Ist das Handy lautlos, bleibt Smile still.'**
  String get albumSoundsHint;

  /// No description provided for @tipFrameButton.
  ///
  /// In de, this message translates to:
  /// **'Ein Tipp auf das Frame-Symbol zeigt dieses Album sofort am Frame. Lang drücken öffnet die Fernbedienung.'**
  String get tipFrameButton;

  /// No description provided for @tipSlideshow.
  ///
  /// In de, this message translates to:
  /// **'Mit dem Diashow-Symbol läuft das Album als Diashow auf diesem Handy, mit eigenen Einstellungen.'**
  String get tipSlideshow;

  /// No description provided for @tipCaptionWhenSending.
  ///
  /// In de, this message translates to:
  /// **'Jedes Foto kann einen eigenen Titel bekommen. Unten antippen oder wischen, um zum nächsten zu wechseln.'**
  String get tipCaptionWhenSending;

  /// No description provided for @tipCaptionLater.
  ///
  /// In de, this message translates to:
  /// **'Hier kannst du nachträglich einen Titel setzen oder ändern.'**
  String get tipCaptionLater;

  /// No description provided for @tipFavoriteHeart.
  ///
  /// In de, this message translates to:
  /// **'Mit dem Herz merkst du ein Foto als Lieblingsbild für den Frame.'**
  String get tipFavoriteHeart;

  /// No description provided for @tipSelectPhotos.
  ///
  /// In de, this message translates to:
  /// **'Lang auf ein Foto drücken: mehrere auswählen, ausblenden oder löschen.'**
  String get tipSelectPhotos;

  /// No description provided for @tipQuickCapture.
  ///
  /// In de, this message translates to:
  /// **'Das Kamera-Symbol oben: Foto machen und gleich in ein Album schicken.'**
  String get tipQuickCapture;

  /// No description provided for @tipInviteWays.
  ///
  /// In de, this message translates to:
  /// **'Einladen geht auch ohne E-Mail: per QR-Code, Link oder aus den Kontakten.'**
  String get tipInviteWays;

  /// No description provided for @tipSmileName.
  ///
  /// In de, this message translates to:
  /// **'Mit deinem Smile-Namen und deiner Karte findet dich jeder, der dich einladen möchte.'**
  String get tipSmileName;

  /// No description provided for @tipControlLevel.
  ///
  /// In de, this message translates to:
  /// **'Mit der Bedienstufe legst du fest, was am Frame selbst bedient werden kann, von Nur zuschauen bis Alles selbst.'**
  String get tipControlLevel;

  /// No description provided for @tipPlayback.
  ///
  /// In de, this message translates to:
  /// **'Unter Wiedergabe: Uhr, Nachtruhe, Titel, langsamer Zoom und Keine Videos.'**
  String get tipPlayback;

  /// No description provided for @tipFavoritesRound.
  ///
  /// In de, this message translates to:
  /// **'Lieblingsbilder laufen am Frame als eigene Runde, auch über alle Alben.'**
  String get tipFavoritesRound;

  /// No description provided for @tipNewAlbum.
  ///
  /// In de, this message translates to:
  /// **'Neue Alben legst du über ⋮ → Neues Album an.'**
  String get tipNewAlbum;

  /// No description provided for @tipVideoQuality.
  ///
  /// In de, this message translates to:
  /// **'Unter Videos senden wählst du, wie stark Videos verkleinert werden. Das spart Datenvolumen.'**
  String get tipVideoQuality;

  /// No description provided for @tipNewsIcon.
  ///
  /// In de, this message translates to:
  /// **'Wird das Symbol oben Coral, wartet eine Einladung oder Anfrage auf dich.'**
  String get tipNewsIcon;

  /// No description provided for @captionDelete.
  ///
  /// In de, this message translates to:
  /// **'Titel löschen'**
  String get captionDelete;

  /// No description provided for @videoNone.
  ///
  /// In de, this message translates to:
  /// **'Keine Videos'**
  String get videoNone;

  /// No description provided for @undo.
  ///
  /// In de, this message translates to:
  /// **'Rückgängig'**
  String get undo;

  /// No description provided for @showOnMyFrame.
  ///
  /// In de, this message translates to:
  /// **'Auf dem Frame zeigen'**
  String get showOnMyFrame;

  /// No description provided for @pickFrameToShow.
  ///
  /// In de, this message translates to:
  /// **'Auf welchem Frame zeigen?'**
  String get pickFrameToShow;

  /// No description provided for @rememberFrame.
  ///
  /// In de, this message translates to:
  /// **'Diesen Frame künftig immer nehmen'**
  String get rememberFrame;

  /// No description provided for @showOnFrameButton.
  ///
  /// In de, this message translates to:
  /// **'Zeigen'**
  String get showOnFrameButton;

  /// No description provided for @preferredFrame.
  ///
  /// In de, this message translates to:
  /// **'Bevorzugter Frame'**
  String get preferredFrame;

  /// No description provided for @preferredFrameAsk.
  ///
  /// In de, this message translates to:
  /// **'Jedes Mal fragen'**
  String get preferredFrameAsk;

  /// No description provided for @preferredFrameHint.
  ///
  /// In de, this message translates to:
  /// **'Ein Tipp auf das Frame-Symbol im Album zeigt es dort sofort.'**
  String get preferredFrameHint;

  /// No description provided for @captionEdit.
  ///
  /// In de, this message translates to:
  /// **'Titel bearbeiten'**
  String get captionEdit;

  /// No description provided for @captionShort.
  ///
  /// In de, this message translates to:
  /// **'Titel'**
  String get captionShort;

  /// No description provided for @showCaptions.
  ///
  /// In de, this message translates to:
  /// **'Titel anzeigen'**
  String get showCaptions;

  /// No description provided for @showCaptionsHint.
  ///
  /// In de, this message translates to:
  /// **'Unten im Bild, wenn der Absender einen geschrieben hat.'**
  String get showCaptionsHint;

  /// No description provided for @allowCaptions.
  ///
  /// In de, this message translates to:
  /// **'Titel ein- oder ausblenden'**
  String get allowCaptions;

  /// No description provided for @rotateWithDevice.
  ///
  /// In de, this message translates to:
  /// **'Bild dreht sich mit dem Frame'**
  String get rotateWithDevice;

  /// No description provided for @recentCountLabel.
  ///
  /// In de, this message translates to:
  /// **'Wie viele aktuelle Fotos'**
  String get recentCountLabel;

  /// No description provided for @quietPreset.
  ///
  /// In de, this message translates to:
  /// **'{from} – {to} Uhr'**
  String quietPreset(String from, String to);

  /// No description provided for @alsoLabel.
  ///
  /// In de, this message translates to:
  /// **'Dazu'**
  String get alsoLabel;

  /// No description provided for @rotateShort.
  ///
  /// In de, this message translates to:
  /// **'Bild dreht sich mit'**
  String get rotateShort;

  /// No description provided for @whoWatches.
  ///
  /// In de, this message translates to:
  /// **'Wer schaut auf diesen Frame?'**
  String get whoWatches;

  /// No description provided for @watchAll.
  ///
  /// In de, this message translates to:
  /// **'Jemand, der alles selbst einstellen möchte'**
  String get watchAll;

  /// No description provided for @watchAllHint.
  ///
  /// In de, this message translates to:
  /// **'Alle Knöpfe und Einstellungen direkt am Frame.'**
  String get watchAllHint;

  /// No description provided for @watchSimple.
  ///
  /// In de, this message translates to:
  /// **'Einfach bedienen'**
  String get watchSimple;

  /// No description provided for @watchSimpleHint.
  ///
  /// In de, this message translates to:
  /// **'Zurück, Pause, Weiter, Neueste Fotos und Lieblingsbilder.'**
  String get watchSimpleHint;

  /// No description provided for @watchOnly.
  ///
  /// In de, this message translates to:
  /// **'Nur zuschauen'**
  String get watchOnly;

  /// No description provided for @watchOnlyHint.
  ///
  /// In de, this message translates to:
  /// **'Keine Knöpfe. Die Fotos laufen von selbst, alles kommt aus der App.'**
  String get watchOnlyHint;

  /// No description provided for @levelBadge.
  ///
  /// In de, this message translates to:
  /// **'Stufe {n} · {name}'**
  String levelBadge(int n, String name);

  /// No description provided for @whoWatchesLater.
  ///
  /// In de, this message translates to:
  /// **'Später jederzeit änderbar unter Frame → ⋮ → Bedienung.'**
  String get whoWatchesLater;

  /// No description provided for @rotateWithDeviceHint.
  ///
  /// In de, this message translates to:
  /// **'Hochkant oder quer gestellt, das Bild dreht mit. Auch wenn die automatische Drehung am Gerät aus ist.'**
  String get rotateWithDeviceHint;

  /// No description provided for @homeSlideshowRecent.
  ///
  /// In de, this message translates to:
  /// **'Aktuelles aus allen Alben'**
  String get homeSlideshowRecent;

  /// No description provided for @homeSlideshowRecentHint.
  ///
  /// In de, this message translates to:
  /// **'Die neuesten Fotos und Videos, egal aus welchem Album'**
  String get homeSlideshowRecentHint;

  /// No description provided for @homeSlideshowRotateHint.
  ///
  /// In de, this message translates to:
  /// **'Alles, was du sehen kannst, Album für Album'**
  String get homeSlideshowRotateHint;

  /// No description provided for @homeSlideshowOneAlbum.
  ///
  /// In de, this message translates to:
  /// **'Ein Album …'**
  String get homeSlideshowOneAlbum;

  /// No description provided for @homeSlideshowOneAlbumHint.
  ///
  /// In de, this message translates to:
  /// **'Dann wählst du das Album aus'**
  String get homeSlideshowOneAlbumHint;

  /// No description provided for @homeSlideshowSettingsHint.
  ///
  /// In de, this message translates to:
  /// **'Dauer, Reihenfolge, Videos und Ton stellst du wie bisher in der Diashow über das Zahnrad ein.'**
  String get homeSlideshowSettingsHint;

  /// No description provided for @homeSlideshowStart.
  ///
  /// In de, this message translates to:
  /// **'Diashow starten'**
  String get homeSlideshowStart;

  /// No description provided for @homeSlideshowPickAlbum.
  ///
  /// In de, this message translates to:
  /// **'Welches Album?'**
  String get homeSlideshowPickAlbum;

  /// No description provided for @homeSlideshowNothing.
  ///
  /// In de, this message translates to:
  /// **'Hier gibt es noch keine Fotos oder Videos.'**
  String get homeSlideshowNothing;

  /// No description provided for @slideshowPosition.
  ///
  /// In de, this message translates to:
  /// **'{n} von {total}'**
  String slideshowPosition(int n, int total);

  /// No description provided for @tipAlbums01.
  ///
  /// In de, this message translates to:
  /// **'Ganz oben steht immer das Album, in dem zuletzt etwas passiert ist – wie bei WhatsApp.'**
  String get tipAlbums01;

  /// No description provided for @tipAlbums02.
  ///
  /// In de, this message translates to:
  /// **'Ein Punkt neben einem Album heißt: Hier gibt es Neues, das du noch nicht gesehen hast.'**
  String get tipAlbums02;

  /// No description provided for @tipAlbums03.
  ///
  /// In de, this message translates to:
  /// **'Unter dem Albumnamen siehst du, wer zuletzt etwas geschickt hat.'**
  String get tipAlbums03;

  /// No description provided for @tipAlbums04.
  ///
  /// In de, this message translates to:
  /// **'Mit der Kamera oben rechts machst du schnell ein Foto und wählst danach das Album aus.'**
  String get tipAlbums04;

  /// No description provided for @tipAlbums05.
  ///
  /// In de, this message translates to:
  /// **'Ein neues Album legst du auf der Seite deines Spaces an.'**
  String get tipAlbums05;

  /// No description provided for @tipAlbums06.
  ///
  /// In de, this message translates to:
  /// **'Ein Album gehört immer zu einem Space – zum Beispiel deiner Familie.'**
  String get tipAlbums06;

  /// No description provided for @tipAlbums07.
  ///
  /// In de, this message translates to:
  /// **'Tippe auf das Bild eines Albums, um es direkt zu öffnen.'**
  String get tipAlbums07;

  /// No description provided for @tipAlbums08.
  ///
  /// In de, this message translates to:
  /// **'Ein Album ohne Fotos zeigt seine Anfangsbuchstaben – bis das erste Foto kommt.'**
  String get tipAlbums08;

  /// No description provided for @tipAlbums09.
  ///
  /// In de, this message translates to:
  /// **'Über ⋮ → Code scannen trittst du mit einem QR-Code einem Album bei.'**
  String get tipAlbums09;

  /// No description provided for @tipAlbums10.
  ///
  /// In de, this message translates to:
  /// **'Unten wechselst du zwischen Alben, Frames und Spaces.'**
  String get tipAlbums10;

  /// No description provided for @tipAlbums11.
  ///
  /// In de, this message translates to:
  /// **'Ziehe die Liste nach unten, um sie sofort zu aktualisieren.'**
  String get tipAlbums11;

  /// No description provided for @tipAlbums12.
  ///
  /// In de, this message translates to:
  /// **'Neue Fotos anderer erscheinen von selbst – du musst nichts tun.'**
  String get tipAlbums12;

  /// No description provided for @tipAlbums13.
  ///
  /// In de, this message translates to:
  /// **'Auch ohne Internet siehst du die Alben, die du zuletzt geöffnet hast.'**
  String get tipAlbums13;

  /// No description provided for @tipAlbums14.
  ///
  /// In de, this message translates to:
  /// **'Alben, die du verlässt, verschwinden aus deiner Liste – die anderen behalten sie.'**
  String get tipAlbums14;

  /// No description provided for @tipAlbums15.
  ///
  /// In de, this message translates to:
  /// **'Ein Album kann gleichzeitig auf mehreren Frames laufen.'**
  String get tipAlbums15;

  /// No description provided for @tipAlbums16.
  ///
  /// In de, this message translates to:
  /// **'Das Bild eines Albums kann der Admin jederzeit ändern.'**
  String get tipAlbums16;

  /// No description provided for @tipAlbums17.
  ///
  /// In de, this message translates to:
  /// **'Neue Alben stehen erst ganz oben, sobald darin etwas passiert.'**
  String get tipAlbums17;

  /// No description provided for @tipAlbums18.
  ///
  /// In de, this message translates to:
  /// **'Tipp: Lege für jede Gelegenheit ein eigenes Album an – Urlaub, Geburtstag, Kinder.'**
  String get tipAlbums18;

  /// No description provided for @tipAlbums19.
  ///
  /// In de, this message translates to:
  /// **'Ein Album hat keine Größengrenze – schick so viele Fotos, wie du willst.'**
  String get tipAlbums19;

  /// No description provided for @tipAlbum01.
  ///
  /// In de, this message translates to:
  /// **'Deine eigenen Fotos stehen rechts, die der anderen links – wie in einem Chat.'**
  String get tipAlbum01;

  /// No description provided for @tipAlbum02.
  ///
  /// In de, this message translates to:
  /// **'Halte ein Foto lange gedrückt, um mehrere auszuwählen.'**
  String get tipAlbum02;

  /// No description provided for @tipAlbum03.
  ///
  /// In de, this message translates to:
  /// **'Mit „Alle auswählen“ markierst du alle Fotos auf einmal.'**
  String get tipAlbum03;

  /// No description provided for @tipAlbum04.
  ///
  /// In de, this message translates to:
  /// **'Mit + unten rechts schickst du Fotos und Videos aus deiner Galerie.'**
  String get tipAlbum04;

  /// No description provided for @tipAlbum05.
  ///
  /// In de, this message translates to:
  /// **'Du kannst mehrere Fotos und Videos auf einmal auswählen und schicken.'**
  String get tipAlbum05;

  /// No description provided for @tipAlbum06.
  ///
  /// In de, this message translates to:
  /// **'Beim Senden kannst du jedem Foto einen Titel geben.'**
  String get tipAlbum06;

  /// No description provided for @tipAlbum07.
  ///
  /// In de, this message translates to:
  /// **'Einen Titel kannst du auch später noch ändern – im Vollbild oben.'**
  String get tipAlbum07;

  /// No description provided for @tipAlbum08.
  ///
  /// In de, this message translates to:
  /// **'Fotos werden vor dem Senden verkleinert – das spart Zeit und Datenvolumen.'**
  String get tipAlbum08;

  /// No description provided for @tipAlbum09.
  ///
  /// In de, this message translates to:
  /// **'Videos werden auf dem Handy verkleinert und sind dadurch schnell da.'**
  String get tipAlbum09;

  /// No description provided for @tipAlbum10.
  ///
  /// In de, this message translates to:
  /// **'Ohne Internet wartet dein Foto mit einer kleinen Uhr und wird später geschickt.'**
  String get tipAlbum10;

  /// No description provided for @tipAlbum11.
  ///
  /// In de, this message translates to:
  /// **'Ein Foto, das noch wartet, kannst du mit „Nicht senden“ zurückhalten.'**
  String get tipAlbum11;

  /// No description provided for @tipAlbum12.
  ///
  /// In de, this message translates to:
  /// **'Deine Fotos werden auch geschickt, wenn du Smile schon geschlossen hast.'**
  String get tipAlbum12;

  /// No description provided for @tipAlbum13.
  ///
  /// In de, this message translates to:
  /// **'Die Datumsangabe oben zeigt beim Blättern, von welchem Tag die Fotos sind.'**
  String get tipAlbum13;

  /// No description provided for @tipAlbum14.
  ///
  /// In de, this message translates to:
  /// **'Wer ein Foto geschickt hat, steht mit Bild und Namen daneben.'**
  String get tipAlbum14;

  /// No description provided for @tipAlbum15.
  ///
  /// In de, this message translates to:
  /// **'Mit „Ausblenden“ verschwindet ein Foto nur bei dir – die anderen sehen es weiter.'**
  String get tipAlbum15;

  /// No description provided for @tipAlbum16.
  ///
  /// In de, this message translates to:
  /// **'Ausgeblendete Fotos holst du über ⋮ jederzeit wieder zurück.'**
  String get tipAlbum16;

  /// No description provided for @tipAlbum17.
  ///
  /// In de, this message translates to:
  /// **'„Löschen“ entfernt ein Foto für alle – das darf nur, wer es geschickt hat, oder der Admin.'**
  String get tipAlbum17;

  /// No description provided for @tipAlbum18.
  ///
  /// In de, this message translates to:
  /// **'Gelöschte Fotos liegen 30 Tage im Papierkorb.'**
  String get tipAlbum18;

  /// No description provided for @tipAlbum19.
  ///
  /// In de, this message translates to:
  /// **'Über ⋮ startest du eine Diashow des Albums direkt am Handy.'**
  String get tipAlbum19;

  /// No description provided for @tipAlbum20.
  ///
  /// In de, this message translates to:
  /// **'Tippe oben auf den Albumnamen, um zur Info-Seite des Albums zu kommen.'**
  String get tipAlbum20;

  /// No description provided for @tipAlbum21.
  ///
  /// In de, this message translates to:
  /// **'Beim Senden und Empfangen gibt es einen kurzen Ton – abschaltbar in den Einstellungen.'**
  String get tipAlbum21;

  /// No description provided for @tipAlbum22.
  ///
  /// In de, this message translates to:
  /// **'Videos zeigen ein kleines Symbol – tippe darauf, um sie abzuspielen.'**
  String get tipAlbum22;

  /// No description provided for @tipAlbum23.
  ///
  /// In de, this message translates to:
  /// **'Schon angesehene Videos sind auch ohne Internet abspielbar.'**
  String get tipAlbum23;

  /// No description provided for @tipAlbum24.
  ///
  /// In de, this message translates to:
  /// **'Neue Fotos anderer tauchen im offenen Album sofort auf.'**
  String get tipAlbum24;

  /// No description provided for @tipViewer01.
  ///
  /// In de, this message translates to:
  /// **'Wische nach links und rechts, um durch alle Fotos und Videos zu blättern.'**
  String get tipViewer01;

  /// No description provided for @tipViewer02.
  ///
  /// In de, this message translates to:
  /// **'Mit zwei Fingern vergrößerst du ein Foto.'**
  String get tipViewer02;

  /// No description provided for @tipViewer03.
  ///
  /// In de, this message translates to:
  /// **'Doppeltippen vergrößert ein Foto – nochmal doppeltippen, und es ist wieder ganz.'**
  String get tipViewer03;

  /// No description provided for @tipViewer04.
  ///
  /// In de, this message translates to:
  /// **'Mit dem Herz oben machst du ein Foto zum Lieblingsbild eines Frames.'**
  String get tipViewer04;

  /// No description provided for @tipViewer05.
  ///
  /// In de, this message translates to:
  /// **'Mit dem Frame-Symbol oben zeigst du das Foto sofort am Frame.'**
  String get tipViewer05;

  /// No description provided for @tipViewer06.
  ///
  /// In de, this message translates to:
  /// **'Die Leiste oben bleibt beim Wischen stehen – ihre Knöpfe gelten fürs gezeigte Foto.'**
  String get tipViewer06;

  /// No description provided for @tipViewer07.
  ///
  /// In de, this message translates to:
  /// **'Im Vollbild siehst du das ganze Foto – im Album wird es manchmal angeschnitten.'**
  String get tipViewer07;

  /// No description provided for @tipViewer08.
  ///
  /// In de, this message translates to:
  /// **'Ein Titel steht unten im Bild – genau wie später am Frame.'**
  String get tipViewer08;

  /// No description provided for @tipViewer09.
  ///
  /// In de, this message translates to:
  /// **'Videos starten erst, wenn du zu ihnen wischst.'**
  String get tipViewer09;

  /// No description provided for @tipViewer10.
  ///
  /// In de, this message translates to:
  /// **'Tippe auf ein Video, um es anzuhalten oder weiterlaufen zu lassen.'**
  String get tipViewer10;

  /// No description provided for @tipViewer11.
  ///
  /// In de, this message translates to:
  /// **'Am Balken unten springst du in einem Video vor und zurück.'**
  String get tipViewer11;

  /// No description provided for @tipViewer12.
  ///
  /// In de, this message translates to:
  /// **'Mit dem Pfeil oben links kommst du zurück ins Album.'**
  String get tipViewer12;

  /// No description provided for @tipViewer13.
  ///
  /// In de, this message translates to:
  /// **'Ein vergrößertes Foto verschiebst du mit einem Finger.'**
  String get tipViewer13;

  /// No description provided for @tipViewer14.
  ///
  /// In de, this message translates to:
  /// **'Auch Fotos, die noch unterwegs sind, kannst du schon groß ansehen.'**
  String get tipViewer14;

  /// No description provided for @tipViewer15.
  ///
  /// In de, this message translates to:
  /// **'Mit dem Titel-Symbol oben gibst du einem Foto nachträglich einen Titel.'**
  String get tipViewer15;

  /// No description provided for @tipAlbumInfo01.
  ///
  /// In de, this message translates to:
  /// **'Hier siehst du, wer im Album ist und wer mitposten darf.'**
  String get tipAlbumInfo01;

  /// No description provided for @tipAlbumInfo02.
  ///
  /// In de, this message translates to:
  /// **'Mit „Einladen“ holst du weitere Personen ins Album.'**
  String get tipAlbumInfo02;

  /// No description provided for @tipAlbumInfo03.
  ///
  /// In de, this message translates to:
  /// **'Mit „Teilen“ zeigst du das Album einem anderen Space – zum Ansehen.'**
  String get tipAlbumInfo03;

  /// No description provided for @tipAlbumInfo04.
  ///
  /// In de, this message translates to:
  /// **'Geteilte Spaces sehen das Album, können aber nichts hineinschicken.'**
  String get tipAlbumInfo04;

  /// No description provided for @tipAlbumInfo05.
  ///
  /// In de, this message translates to:
  /// **'Tippe auf eine Person, um zu sehen, welche Rolle sie hat.'**
  String get tipAlbumInfo05;

  /// No description provided for @tipAlbumInfo06.
  ///
  /// In de, this message translates to:
  /// **'Der Admin kann Personen aus dem Album entfernen.'**
  String get tipAlbumInfo06;

  /// No description provided for @tipAlbumInfo07.
  ///
  /// In de, this message translates to:
  /// **'Unter „Läuft auf“ siehst du, auf welchen Frames das Album gerade läuft.'**
  String get tipAlbumInfo07;

  /// No description provided for @tipAlbumInfo08.
  ///
  /// In de, this message translates to:
  /// **'Mit „Auf Frame zeigen“ legst du das Album mit einem Tipp auf einen Frame.'**
  String get tipAlbumInfo08;

  /// No description provided for @tipAlbumInfo09.
  ///
  /// In de, this message translates to:
  /// **'Den Namen ändert der Admin mit einem Tipp auf den Namen.'**
  String get tipAlbumInfo09;

  /// No description provided for @tipAlbumInfo10.
  ///
  /// In de, this message translates to:
  /// **'Das Albumbild kann ein eigenes Foto oder ein Foto aus dem Album sein.'**
  String get tipAlbumInfo10;

  /// No description provided for @tipAlbumInfo11.
  ///
  /// In de, this message translates to:
  /// **'Ein geteiltes Album eines anderen Spaces nimmst du mit „Aus … entfernen“ wieder heraus.'**
  String get tipAlbumInfo11;

  /// No description provided for @tipAlbumInfo12.
  ///
  /// In de, this message translates to:
  /// **'Gehört dir ein Album nicht, bleibt es beim Entfernen beim Besitzer erhalten.'**
  String get tipAlbumInfo12;

  /// No description provided for @tipAlbumInfo13.
  ///
  /// In de, this message translates to:
  /// **'„Album verlassen“ beendet nur deine Mitgliedschaft – das Album bleibt bestehen.'**
  String get tipAlbumInfo13;

  /// No description provided for @tipAlbumInfo14.
  ///
  /// In de, this message translates to:
  /// **'„Album löschen“ legt das Album 30 Tage in den Papierkorb.'**
  String get tipAlbumInfo14;

  /// No description provided for @tipAlbumInfo15.
  ///
  /// In de, this message translates to:
  /// **'Beitrittsanfragen zum Album entscheidet der Admin unter Neuigkeiten.'**
  String get tipAlbumInfo15;

  /// No description provided for @tipInvite01.
  ///
  /// In de, this message translates to:
  /// **'Leute, die du schon aus Smile kennst, lädst du einfach mit ihrem Namen ein.'**
  String get tipInvite01;

  /// No description provided for @tipInvite02.
  ///
  /// In de, this message translates to:
  /// **'Mit einem QR-Code ist jemand neben dir sofort im Album – ohne Rückfrage.'**
  String get tipInvite02;

  /// No description provided for @tipInvite03.
  ///
  /// In de, this message translates to:
  /// **'Einen Einladungslink kannst du per WhatsApp oder SMS verschicken.'**
  String get tipInvite03;

  /// No description provided for @tipInvite04.
  ///
  /// In de, this message translates to:
  /// **'Ein abgetippter Code geht als Anfrage an den Admin – der entscheidet.'**
  String get tipInvite04;

  /// No description provided for @tipInvite05.
  ///
  /// In de, this message translates to:
  /// **'Über „Aus Kontakten“ findest du Leute aus deinem Telefonbuch, die schon Smile haben.'**
  String get tipInvite05;

  /// No description provided for @tipInvite06.
  ///
  /// In de, this message translates to:
  /// **'Wer Smile noch nicht hat, bekommt aus deinen Kontakten eine Einladung per SMS oder WhatsApp.'**
  String get tipInvite06;

  /// No description provided for @tipInvite07.
  ///
  /// In de, this message translates to:
  /// **'Ein Einladungscode gilt 24 Stunden.'**
  String get tipInvite07;

  /// No description provided for @tipInvite08.
  ///
  /// In de, this message translates to:
  /// **'Ein neuer Code macht den alten sofort ungültig.'**
  String get tipInvite08;

  /// No description provided for @tipInvite09.
  ///
  /// In de, this message translates to:
  /// **'Co-Admin und Frame-Admin wird man nur per Name oder QR-Code vor Ort.'**
  String get tipInvite09;

  /// No description provided for @tipInvite10.
  ///
  /// In de, this message translates to:
  /// **'Unbeantwortete Einladungen kannst du jederzeit zurückziehen.'**
  String get tipInvite10;

  /// No description provided for @tipInvite11.
  ///
  /// In de, this message translates to:
  /// **'Eingeladene sehen deine Einladung unter Neuigkeiten und entscheiden selbst.'**
  String get tipInvite11;

  /// No description provided for @tipInvite12.
  ///
  /// In de, this message translates to:
  /// **'Mit deinem Smile-Namen (@name) finden dich andere leichter.'**
  String get tipInvite12;

  /// No description provided for @tipInvite13.
  ///
  /// In de, this message translates to:
  /// **'Unter „Meine Karte“ zeigst du deinen eigenen QR-Code zum Scannen.'**
  String get tipInvite13;

  /// No description provided for @tipInvite14.
  ///
  /// In de, this message translates to:
  /// **'Offene Anfragen verfallen nach einiger Zeit von selbst.'**
  String get tipInvite14;

  /// No description provided for @tipFrames01.
  ///
  /// In de, this message translates to:
  /// **'Ein Frame ist ein Tablet, das deine Alben als Bilderrahmen zeigt.'**
  String get tipFrames01;

  /// No description provided for @tipFrames02.
  ///
  /// In de, this message translates to:
  /// **'Der grüne Punkt am Frame-Bild heißt: Der Frame ist gerade online.'**
  String get tipFrames02;

  /// No description provided for @tipFrames03.
  ///
  /// In de, this message translates to:
  /// **'Unter „Frames“ siehst du alle Frames, die du verwaltest.'**
  String get tipFrames03;

  /// No description provided for @tipFrames04.
  ///
  /// In de, this message translates to:
  /// **'Einen neuen Frame verbindest du mit einem QR-Code, den er beim ersten Start zeigt.'**
  String get tipFrames04;

  /// No description provided for @tipFrames05.
  ///
  /// In de, this message translates to:
  /// **'Ein neues Tablet kann einen alten Frame ersetzen – Alben und Einstellungen bleiben.'**
  String get tipFrames05;

  /// No description provided for @tipFrames06.
  ///
  /// In de, this message translates to:
  /// **'Unter „Einstellungen & Gerät“ siehst du Akku, Gerät und letzten Kontakt des Frames.'**
  String get tipFrames06;

  /// No description provided for @tipFrames07.
  ///
  /// In de, this message translates to:
  /// **'Ist ein Frame länger offline, bekommst du eine Nachricht.'**
  String get tipFrames07;

  /// No description provided for @tipFrames08.
  ///
  /// In de, this message translates to:
  /// **'Einen Frame kannst du vorübergehend sperren – und später wieder freigeben.'**
  String get tipFrames08;

  /// No description provided for @tipFrames09.
  ///
  /// In de, this message translates to:
  /// **'Den Namen und das Bild eines Frames änderst du unter „Einstellungen & Gerät“.'**
  String get tipFrames09;

  /// No description provided for @tipFrames10.
  ///
  /// In de, this message translates to:
  /// **'Auf einem Frame können mehrere Alben laufen.'**
  String get tipFrames10;

  /// No description provided for @tipFrames11.
  ///
  /// In de, this message translates to:
  /// **'„Alben verwalten“ legt fest, welche Alben ein Frame zeigt.'**
  String get tipFrames11;

  /// No description provided for @tipFrames12.
  ///
  /// In de, this message translates to:
  /// **'Ein Frame zeigt auch Alben, die mit seinem Space geteilt sind.'**
  String get tipFrames12;

  /// No description provided for @tipFrames13.
  ///
  /// In de, this message translates to:
  /// **'Der Frame merkt sich alle Fotos – er zeigt sie auch ohne Internet weiter.'**
  String get tipFrames13;

  /// No description provided for @tipFrames14.
  ///
  /// In de, this message translates to:
  /// **'Mit der Nachtruhe bleibt der Frame nachts dunkel.'**
  String get tipFrames14;

  /// No description provided for @tipFrames15.
  ///
  /// In de, this message translates to:
  /// **'Tipp: Hefte die Smile-App am Tablet an, dann kann niemand versehentlich hinaus.'**
  String get tipFrames15;

  /// No description provided for @tipFrames16.
  ///
  /// In de, this message translates to:
  /// **'Mit „Große Uhr“ zeigt der Frame Datum und Uhrzeit groß – praktisch für Oma.'**
  String get tipFrames16;

  /// No description provided for @tipFrames17.
  ///
  /// In de, this message translates to:
  /// **'Wer ein Foto geschickt hat, steht am Frame oben links.'**
  String get tipFrames17;

  /// No description provided for @tipFrames18.
  ///
  /// In de, this message translates to:
  /// **'Ein Frame dreht sich mit dem Tablet – wenn du es so einstellst.'**
  String get tipFrames18;

  /// No description provided for @tipFrames19.
  ///
  /// In de, this message translates to:
  /// **'Ein gelöschter Frame zeigt wieder den QR-Code zum Verbinden.'**
  String get tipFrames19;

  /// No description provided for @tipFrame01.
  ///
  /// In de, this message translates to:
  /// **'Tippe auf ein Album im Streifen oben, um es sofort am Frame zu zeigen.'**
  String get tipFrame01;

  /// No description provided for @tipFrame02.
  ///
  /// In de, this message translates to:
  /// **'„Läuft gerade“ zeigt, was der Frame in diesem Moment abspielt.'**
  String get tipFrame02;

  /// No description provided for @tipFrame03.
  ///
  /// In de, this message translates to:
  /// **'Mit der Fernbedienung hältst du den Frame an oder blätterst weiter.'**
  String get tipFrame03;

  /// No description provided for @tipFrame04.
  ///
  /// In de, this message translates to:
  /// **'„Neueste 20 Fotos abspielen“ zeigt die neuesten Fotos aller Alben.'**
  String get tipFrame04;

  /// No description provided for @tipFrame05.
  ///
  /// In de, this message translates to:
  /// **'Lieblingsbilder sind eine eigene Auswahl nur für diesen Frame.'**
  String get tipFrame05;

  /// No description provided for @tipFrame06.
  ///
  /// In de, this message translates to:
  /// **'Unter „Alle ansehen“ siehst du alle Lieblingsbilder eines Frames.'**
  String get tipFrame06;

  /// No description provided for @tipFrame07.
  ///
  /// In de, this message translates to:
  /// **'Mit „Ton bei Videos“ entscheidest du, ob Videos am Frame Ton haben.'**
  String get tipFrame07;

  /// No description provided for @tipFrame08.
  ///
  /// In de, this message translates to:
  /// **'Die Kachel „Bedienstufe“ legt fest, was man am Frame selbst tun kann.'**
  String get tipFrame08;

  /// No description provided for @tipFrame09.
  ///
  /// In de, this message translates to:
  /// **'Mit „Frame-Admin einladen“ darf jemand anderes diesen Frame bedienen – zum Beispiel die Eltern eines Kindes.'**
  String get tipFrame09;

  /// No description provided for @tipFrame10.
  ///
  /// In de, this message translates to:
  /// **'Ein Frame-Admin bestimmt Bedienung und Alben – aber nicht Name, Gerät oder Löschen.'**
  String get tipFrame10;

  /// No description provided for @tipFrame11.
  ///
  /// In de, this message translates to:
  /// **'Unter „Am Frame entsperren“ legst du einen Code für den Frame fest.'**
  String get tipFrame11;

  /// No description provided for @tipFrame12.
  ///
  /// In de, this message translates to:
  /// **'Mit dem Code zeigt der Frame nach langem Druck auf die Uhr alle Knöpfe.'**
  String get tipFrame12;

  /// No description provided for @tipFrame13.
  ///
  /// In de, this message translates to:
  /// **'Der entsperrte Frame sperrt sich nach 2 Minuten ohne Berührung von selbst.'**
  String get tipFrame13;

  /// No description provided for @tipFrame14.
  ///
  /// In de, this message translates to:
  /// **'Ohne Code lässt sich am Frame nichts entsperren.'**
  String get tipFrame14;

  /// No description provided for @tipFrame15.
  ///
  /// In de, this message translates to:
  /// **'Das Abzeichen „Frame-Admin“ zeigt Frames, die du für jemand anderen bedienst.'**
  String get tipFrame15;

  /// No description provided for @tipControls01.
  ///
  /// In de, this message translates to:
  /// **'Easy Stopping: Ein Tippen auf den Frame hält das Bild an, noch eins lässt es weiterlaufen.'**
  String get tipControls01;

  /// No description provided for @tipControls02.
  ///
  /// In de, this message translates to:
  /// **'Ein angehaltener Frame läuft nach 10 Minuten von selbst weiter.'**
  String get tipControls02;

  /// No description provided for @tipControls03.
  ///
  /// In de, this message translates to:
  /// **'Stufe 1 „Nur zuschauen“: Am Frame geht nur Antippen zum Anhalten.'**
  String get tipControls03;

  /// No description provided for @tipControls04.
  ///
  /// In de, this message translates to:
  /// **'Stufe 2: Pause und ein großer Weiter-Knopf – ideal für den Anfang.'**
  String get tipControls04;

  /// No description provided for @tipControls05.
  ///
  /// In de, this message translates to:
  /// **'Stufe 3: Dazu Zurück und die neuesten Fotos.'**
  String get tipControls05;

  /// No description provided for @tipControls06.
  ///
  /// In de, this message translates to:
  /// **'Stufe 4: Dazu Übersicht, Album wechseln, Anzeigedauer und Titel.'**
  String get tipControls06;

  /// No description provided for @tipControls07.
  ///
  /// In de, this message translates to:
  /// **'Stufe 5: Am Frame lässt sich alles selbst einstellen.'**
  String get tipControls07;

  /// No description provided for @tipControls08.
  ///
  /// In de, this message translates to:
  /// **'Einzelne Knöpfe kannst du auch einzeln erlauben – das ist dann „Eigene Auswahl“.'**
  String get tipControls08;

  /// No description provided for @tipControls09.
  ///
  /// In de, this message translates to:
  /// **'Am Frame wischt man nach links zum nächsten Foto – ab Stufe 2.'**
  String get tipControls09;

  /// No description provided for @tipControls10.
  ///
  /// In de, this message translates to:
  /// **'Nach rechts wischen geht zum vorigen Foto – ab Stufe 3.'**
  String get tipControls10;

  /// No description provided for @tipControls11.
  ///
  /// In de, this message translates to:
  /// **'Mit „Merken“ macht man direkt am Frame ein Foto zum Lieblingsbild.'**
  String get tipControls11;

  /// No description provided for @tipControls12.
  ///
  /// In de, this message translates to:
  /// **'Die „Übersicht“ am Frame zeigt alle Fotos als Kacheln zum Antippen.'**
  String get tipControls12;

  /// No description provided for @tipControls13.
  ///
  /// In de, this message translates to:
  /// **'Mit „Album“ wechselt man am Frame selbst das Album.'**
  String get tipControls13;

  /// No description provided for @tipControls14.
  ///
  /// In de, this message translates to:
  /// **'Die Knöpfe am Frame verschwinden nach ein paar Sekunden von selbst.'**
  String get tipControls14;

  /// No description provided for @tipControls15.
  ///
  /// In de, this message translates to:
  /// **'Die Bedienstufe kannst du jederzeit ändern – der Frame folgt sofort.'**
  String get tipControls15;

  /// No description provided for @tipPlayback01.
  ///
  /// In de, this message translates to:
  /// **'„Was läuft“: ein Album, alle Alben im Wechsel, die neuesten oder die Lieblingsbilder.'**
  String get tipPlayback01;

  /// No description provided for @tipPlayback02.
  ///
  /// In de, this message translates to:
  /// **'Die Reihenfolge: neueste zuerst, älteste zuerst oder gemischt.'**
  String get tipPlayback02;

  /// No description provided for @tipPlayback03.
  ///
  /// In de, this message translates to:
  /// **'Die Anzeigedauer bestimmt, wie lange jedes Foto zu sehen ist.'**
  String get tipPlayback03;

  /// No description provided for @tipPlayback04.
  ///
  /// In de, this message translates to:
  /// **'Am Ende eines Albums fängt der Frame von vorn an – oder zeigt die Übersicht.'**
  String get tipPlayback04;

  /// No description provided for @tipPlayback05.
  ///
  /// In de, this message translates to:
  /// **'Videos können ganz laufen, nur so lang wie ein Foto, oder gar nicht.'**
  String get tipPlayback05;

  /// No description provided for @tipPlayback06.
  ///
  /// In de, this message translates to:
  /// **'„Füllen“: Fotos füllen den Bildschirm – oder werden ganz gezeigt.'**
  String get tipPlayback06;

  /// No description provided for @tipPlayback07.
  ///
  /// In de, this message translates to:
  /// **'„Automatisch füllen“ füllt nur, wenn das Foto zum Bildschirm passt.'**
  String get tipPlayback07;

  /// No description provided for @tipPlayback08.
  ///
  /// In de, this message translates to:
  /// **'Das langsame Zoomen bringt Leben in die Fotos.'**
  String get tipPlayback08;

  /// No description provided for @tipPlayback09.
  ///
  /// In de, this message translates to:
  /// **'„Neues gleich zeigen“: Ein neues Foto erscheint sofort am Frame.'**
  String get tipPlayback09;

  /// No description provided for @tipPlayback10.
  ///
  /// In de, this message translates to:
  /// **'„Ton bei neuen Fotos“: Der Frame meldet sich mit einem Dreiklang.'**
  String get tipPlayback10;

  /// No description provided for @tipPlayback11.
  ///
  /// In de, this message translates to:
  /// **'„Erinnern, bis jemand schaut“: Der Ton kommt stündlich wieder, höchstens dreimal.'**
  String get tipPlayback11;

  /// No description provided for @tipPlayback12.
  ///
  /// In de, this message translates to:
  /// **'„Hinweis auf Neues“: Ein leuchtender Hinweis bleibt, bis jemand tippt.'**
  String get tipPlayback12;

  /// No description provided for @tipPlayback13.
  ///
  /// In de, this message translates to:
  /// **'Ein Tippen auf den Hinweis zeigt genau die neuen Fotos.'**
  String get tipPlayback13;

  /// No description provided for @tipPlayback14.
  ///
  /// In de, this message translates to:
  /// **'Die Nachtruhe schaltet den Frame nachts dunkel.'**
  String get tipPlayback14;

  /// No description provided for @tipPlayback15.
  ///
  /// In de, this message translates to:
  /// **'In der Nachtruhe bleibt der Frame still – auch bei neuen Fotos.'**
  String get tipPlayback15;

  /// No description provided for @tipPlayback16.
  ///
  /// In de, this message translates to:
  /// **'„Große Uhr“ zeigt Datum und Uhrzeit groß am Frame.'**
  String get tipPlayback16;

  /// No description provided for @tipPlayback17.
  ///
  /// In de, this message translates to:
  /// **'„Absender zeigen“ blendet ein, wer ein Foto geschickt hat.'**
  String get tipPlayback17;

  /// No description provided for @tipPlayback18.
  ///
  /// In de, this message translates to:
  /// **'„Titel zeigen“ blendet die Titel der Fotos ein.'**
  String get tipPlayback18;

  /// No description provided for @tipPlayback19.
  ///
  /// In de, this message translates to:
  /// **'„Mit dem Gerät drehen“ dreht den Frame auch, wenn das Tablet das sonst nicht tut.'**
  String get tipPlayback19;

  /// No description provided for @tipPlayback20.
  ///
  /// In de, this message translates to:
  /// **'Jede Änderung hier ist in unter einer Sekunde am Frame.'**
  String get tipPlayback20;

  /// No description provided for @tipFavorites01.
  ///
  /// In de, this message translates to:
  /// **'Lieblingsbilder sind pro Frame – jeder Frame hat seine eigenen.'**
  String get tipFavorites01;

  /// No description provided for @tipFavorites02.
  ///
  /// In de, this message translates to:
  /// **'Mit dem Herz im Vollbild machst du ein Foto zum Lieblingsbild.'**
  String get tipFavorites02;

  /// No description provided for @tipFavorites03.
  ///
  /// In de, this message translates to:
  /// **'Bei mehreren Frames wählst du, für welchen Frame das Herz gilt.'**
  String get tipFavorites03;

  /// No description provided for @tipFavorites04.
  ///
  /// In de, this message translates to:
  /// **'Mit „Hinzufügen“ wählst du mehrere Lieblingsbilder auf einmal aus.'**
  String get tipFavorites04;

  /// No description provided for @tipFavorites05.
  ///
  /// In de, this message translates to:
  /// **'Lieblingsbilder kann man am Frame als eigene Runde abspielen.'**
  String get tipFavorites05;

  /// No description provided for @tipFavorites06.
  ///
  /// In de, this message translates to:
  /// **'Wer ein Lieblingsbild markiert hat, siehst du in der Liste.'**
  String get tipFavorites06;

  /// No description provided for @tipFavorites07.
  ///
  /// In de, this message translates to:
  /// **'Ein Lieblingsbild, das am Frame gemerkt wurde, steht dort mit „Am Frame“.'**
  String get tipFavorites07;

  /// No description provided for @tipFavorites08.
  ///
  /// In de, this message translates to:
  /// **'Über ⋮ entfernst du alle Lieblingsbilder eines Frames auf einmal.'**
  String get tipFavorites08;

  /// No description provided for @tipFavorites09.
  ///
  /// In de, this message translates to:
  /// **'Ist „Lieblingsbilder“ eingestellt, ist der Knopf am Frame eingerahmt.'**
  String get tipFavorites09;

  /// No description provided for @tipSpaces01.
  ///
  /// In de, this message translates to:
  /// **'Ein Space ist dein Haushalt oder deine Familie – mit Alben und Frames.'**
  String get tipSpaces01;

  /// No description provided for @tipSpaces02.
  ///
  /// In de, this message translates to:
  /// **'Jeder Space hat einen Admin, der alles darf.'**
  String get tipSpaces02;

  /// No description provided for @tipSpaces03.
  ///
  /// In de, this message translates to:
  /// **'Co-Admins verwalten den Space mit – Alben, Frames und Personen.'**
  String get tipSpaces03;

  /// No description provided for @tipSpaces04.
  ///
  /// In de, this message translates to:
  /// **'Mit „Co-Admin einladen“ bekommst du Hilfe beim Verwalten.'**
  String get tipSpaces04;

  /// No description provided for @tipSpaces05.
  ///
  /// In de, this message translates to:
  /// **'Der Admin kann seine Rolle an einen Co-Admin übergeben.'**
  String get tipSpaces05;

  /// No description provided for @tipSpaces06.
  ///
  /// In de, this message translates to:
  /// **'Ein Co-Admin kann die Rolle jederzeit selbst abgeben.'**
  String get tipSpaces06;

  /// No description provided for @tipSpaces07.
  ///
  /// In de, this message translates to:
  /// **'Einen Space löschen kann nur der Admin.'**
  String get tipSpaces07;

  /// No description provided for @tipSpaces08.
  ///
  /// In de, this message translates to:
  /// **'Ein gelöschter Space liegt 30 Tage im Papierkorb.'**
  String get tipSpaces08;

  /// No description provided for @tipSpaces09.
  ///
  /// In de, this message translates to:
  /// **'Du kannst in mehreren Spaces sein – zum Beispiel bei dir und bei den Eltern.'**
  String get tipSpaces09;

  /// No description provided for @tipSpaces10.
  ///
  /// In de, this message translates to:
  /// **'Ein Space kann Alben eines anderen Spaces zum Ansehen bekommen.'**
  String get tipSpaces10;

  /// No description provided for @tipSpaces11.
  ///
  /// In de, this message translates to:
  /// **'Jeder Space kann ein eigenes Bild haben.'**
  String get tipSpaces11;

  /// No description provided for @tipSpaces12.
  ///
  /// In de, this message translates to:
  /// **'Neue Alben legst du in einem Space an.'**
  String get tipSpaces12;

  /// No description provided for @tipSpaces13.
  ///
  /// In de, this message translates to:
  /// **'Neue Frames verbindest du über einen Space.'**
  String get tipSpaces13;

  /// No description provided for @tipSpaces14.
  ///
  /// In de, this message translates to:
  /// **'Wer einen Space verwaltet, ist automatisch in allen seinen Alben.'**
  String get tipSpaces14;

  /// No description provided for @tipSpaces15.
  ///
  /// In de, this message translates to:
  /// **'Den Namen des Spaces ändert der Admin mit einem Tipp darauf.'**
  String get tipSpaces15;

  /// No description provided for @tipNews01.
  ///
  /// In de, this message translates to:
  /// **'Unter Neuigkeiten findest du Einladungen, Anfragen und alle Nachrichten der letzten 30 Tage.'**
  String get tipNews01;

  /// No description provided for @tipNews02.
  ///
  /// In de, this message translates to:
  /// **'Ein roter Punkt an Neuigkeiten heißt: Hier wartet etwas auf deine Antwort.'**
  String get tipNews02;

  /// No description provided for @tipNews03.
  ///
  /// In de, this message translates to:
  /// **'Einladungen nimmst du hier an – oder lehnst sie ab.'**
  String get tipNews03;

  /// No description provided for @tipNews04.
  ///
  /// In de, this message translates to:
  /// **'Als Admin entscheidest du hier über Beitrittsanfragen.'**
  String get tipNews04;

  /// No description provided for @tipNews05.
  ///
  /// In de, this message translates to:
  /// **'Der Papierkorb liegt bei den Neuigkeiten.'**
  String get tipNews05;

  /// No description provided for @tipNews06.
  ///
  /// In de, this message translates to:
  /// **'Aus dem Papierkorb holst du Gelöschtes 30 Tage lang zurück.'**
  String get tipNews06;

  /// No description provided for @tipNews07.
  ///
  /// In de, this message translates to:
  /// **'Nach 30 Tagen wird der Papierkorb von selbst geleert.'**
  String get tipNews07;

  /// No description provided for @tipNews08.
  ///
  /// In de, this message translates to:
  /// **'Tippe auf eine Nachricht, um direkt zum Album oder Frame zu kommen.'**
  String get tipNews08;

  /// No description provided for @tipNews09.
  ///
  /// In de, this message translates to:
  /// **'Auch Pushes, die du weggewischt hast, findest du hier wieder.'**
  String get tipNews09;

  /// No description provided for @tipNews10.
  ///
  /// In de, this message translates to:
  /// **'Viele neue Fotos derselben Person kommen als eine Nachricht.'**
  String get tipNews10;

  /// No description provided for @tipSettings01.
  ///
  /// In de, this message translates to:
  /// **'Dein Name ist Pflicht – so wissen alle, von wem ein Foto kommt.'**
  String get tipSettings01;

  /// No description provided for @tipSettings02.
  ///
  /// In de, this message translates to:
  /// **'Ohne eigenes Bild zeigt Smile deine Anfangsbuchstaben.'**
  String get tipSettings02;

  /// No description provided for @tipSettings03.
  ///
  /// In de, this message translates to:
  /// **'Tippe auf dein Bild, um es zu ändern.'**
  String get tipSettings03;

  /// No description provided for @tipSettings04.
  ///
  /// In de, this message translates to:
  /// **'Unter „Smile-Name“ wählst du einen @Namen, mit dem dich andere finden.'**
  String get tipSettings04;

  /// No description provided for @tipSettings05.
  ///
  /// In de, this message translates to:
  /// **'„Meine Karte“ zeigt deinen QR-Code – andere scannen ihn zum Einladen.'**
  String get tipSettings05;

  /// No description provided for @tipSettings06.
  ///
  /// In de, this message translates to:
  /// **'Unter „Töne im Album“ schaltest du die Plopp-Töne ein oder aus.'**
  String get tipSettings06;

  /// No description provided for @tipSettings07.
  ///
  /// In de, this message translates to:
  /// **'Bei lautlosem Handy bleibt Smile still.'**
  String get tipSettings07;

  /// No description provided for @tipSettings08.
  ///
  /// In de, this message translates to:
  /// **'Unter „Videoqualität“ wählst du, wie stark Videos verkleinert werden.'**
  String get tipSettings08;

  /// No description provided for @tipSettings09.
  ///
  /// In de, this message translates to:
  /// **'„Tipps von vorne zeigen“ bringt alle Tipps zurück.'**
  String get tipSettings09;

  /// No description provided for @tipSettings10.
  ///
  /// In de, this message translates to:
  /// **'„Keine Tipps mehr“ schaltet alle Tipps ab – hier wieder ein.'**
  String get tipSettings10;

  /// No description provided for @tipSettings11.
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigungen kommen für neue Fotos, Einladungen und Änderungen an deinen Frames.'**
  String get tipSettings11;

  /// No description provided for @tipSettings12.
  ///
  /// In de, this message translates to:
  /// **'Dein Konto kannst du in den Einstellungen löschen – mit allem, was dir gehört.'**
  String get tipSettings12;

  /// No description provided for @tipSettings13.
  ///
  /// In de, this message translates to:
  /// **'Abmelden ist jederzeit möglich – deine Alben bleiben auf dem Server.'**
  String get tipSettings13;

  /// No description provided for @tipSettings14.
  ///
  /// In de, this message translates to:
  /// **'Smile meldet sich mit einem Code per E-Mail an – ganz ohne Passwort.'**
  String get tipSettings14;

  /// No description provided for @tipSettings15.
  ///
  /// In de, this message translates to:
  /// **'Smile ist dunkel gestaltet – so leuchten die Fotos am schönsten.'**
  String get tipSettings15;

  /// No description provided for @tipGeneral01.
  ///
  /// In de, this message translates to:
  /// **'Smile ist wie WhatsApp für Fotos – nur ohne Chat und mit Bilderrahmen.'**
  String get tipGeneral01;

  /// No description provided for @tipGeneral02.
  ///
  /// In de, this message translates to:
  /// **'Alles, was du änderst, sehen die anderen sofort.'**
  String get tipGeneral02;

  /// No description provided for @tipGeneral03.
  ///
  /// In de, this message translates to:
  /// **'Smile arbeitet auch offline – Änderungen werden nachgeschickt.'**
  String get tipGeneral03;

  /// No description provided for @tipGeneral04.
  ///
  /// In de, this message translates to:
  /// **'Fotos in Smile sind privat – nur Mitglieder eines Albums sehen sie.'**
  String get tipGeneral04;

  /// No description provided for @tipGeneral05.
  ///
  /// In de, this message translates to:
  /// **'Wer ein Album verlässt, sieht dessen Fotos danach nicht mehr.'**
  String get tipGeneral05;

  /// No description provided for @tipGeneral06.
  ///
  /// In de, this message translates to:
  /// **'Lange drücken öffnet fast überall weitere Möglichkeiten.'**
  String get tipGeneral06;

  /// No description provided for @tipGeneral07.
  ///
  /// In de, this message translates to:
  /// **'Das ⋮ oben rechts hat auf jeder Seite weitere Funktionen.'**
  String get tipGeneral07;

  /// No description provided for @tipGeneral08.
  ///
  /// In de, this message translates to:
  /// **'Nach unten ziehen aktualisiert fast jede Liste.'**
  String get tipGeneral08;

  /// No description provided for @tipGeneral09.
  ///
  /// In de, this message translates to:
  /// **'Ein Tipp auf einen Namen oder ein Bild zeigt meistens mehr.'**
  String get tipGeneral09;

  /// No description provided for @tipGeneral10.
  ///
  /// In de, this message translates to:
  /// **'Smile schickt nur Fotos und Videos – keine Nachrichten.'**
  String get tipGeneral10;

  /// No description provided for @tipGeneral11.
  ///
  /// In de, this message translates to:
  /// **'Ein Album ist kein Einzelchat: Es kann immer weitere Leute aufnehmen.'**
  String get tipGeneral11;

  /// No description provided for @tipGeneral12.
  ///
  /// In de, this message translates to:
  /// **'Ein Frame braucht kein eigenes Konto – er wird mit einem Code verbunden.'**
  String get tipGeneral12;

  /// No description provided for @tipGeneral13.
  ///
  /// In de, this message translates to:
  /// **'Fotos werden verschlüsselt übertragen.'**
  String get tipGeneral13;

  /// No description provided for @membershipRequestFailed.
  ///
  /// In de, this message translates to:
  /// **'Anfrage fehlgeschlagen: {reason}'**
  String membershipRequestFailed(String reason);

  /// No description provided for @withdrawFailed.
  ///
  /// In de, this message translates to:
  /// **'Zurückziehen fehlgeschlagen: {reason}'**
  String withdrawFailed(String reason);

  /// No description provided for @deleteFailedShort.
  ///
  /// In de, this message translates to:
  /// **'Löschen fehlgeschlagen.'**
  String get deleteFailedShort;

  /// No description provided for @hideFailedShort.
  ///
  /// In de, this message translates to:
  /// **'Ausblenden fehlgeschlagen.'**
  String get hideFailedShort;

  /// No description provided for @unhideFailedShort.
  ///
  /// In de, this message translates to:
  /// **'Einblenden fehlgeschlagen.'**
  String get unhideFailedShort;

  /// No description provided for @photosNotDeleted.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Foto konnte nicht gelöscht werden (nicht dein eigenes).} other{{count} Fotos konnten nicht gelöscht werden (nicht deine eigenen).}}'**
  String photosNotDeleted(int count);

  /// No description provided for @photosNotPossible.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Bei 1 Foto nicht möglich.} other{Bei {count} Fotos nicht möglich.}}'**
  String photosNotPossible(int count);

  /// No description provided for @loginIntro.
  ///
  /// In de, this message translates to:
  /// **'Melde dich mit deiner E-Mail-Adresse an. Wir senden dir einen 6-stelligen Code.'**
  String get loginIntro;

  /// No description provided for @loginRequestCode.
  ///
  /// In de, this message translates to:
  /// **'Code anfordern'**
  String get loginRequestCode;

  /// No description provided for @loginCodeSent.
  ///
  /// In de, this message translates to:
  /// **'Wir haben einen Code an {email} gesendet. Bitte gib ihn ein.'**
  String loginCodeSent(String email);

  /// No description provided for @loginConfirm.
  ///
  /// In de, this message translates to:
  /// **'Bestätigen'**
  String get loginConfirm;

  /// No description provided for @loginOtherEmail.
  ///
  /// In de, this message translates to:
  /// **'Andere E-Mail-Adresse verwenden'**
  String get loginOtherEmail;

  /// No description provided for @avatarUploadFailed.
  ///
  /// In de, this message translates to:
  /// **'Bild konnte nicht hochgeladen werden: {reason}'**
  String avatarUploadFailed(String reason);

  /// No description provided for @enterYourName.
  ///
  /// In de, this message translates to:
  /// **'Bitte gib deinen Namen ein.'**
  String get enterYourName;

  /// No description provided for @saveFailedWith.
  ///
  /// In de, this message translates to:
  /// **'Speichern fehlgeschlagen: {reason}'**
  String saveFailedWith(String reason);

  /// No description provided for @avatarUrlInvalid.
  ///
  /// In de, this message translates to:
  /// **'Das ist keine gültige Internetadresse.'**
  String get avatarUrlInvalid;

  /// No description provided for @avatarUrlUnreachable.
  ///
  /// In de, this message translates to:
  /// **'Das Bild konnte nicht geladen werden. Bitte prüfe die Adresse.'**
  String get avatarUrlUnreachable;

  /// No description provided for @avatarUrlNotImage.
  ///
  /// In de, this message translates to:
  /// **'Die Adresse zeigt auf kein Bild.'**
  String get avatarUrlNotImage;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In de, this message translates to:
  /// **'Neue Fotos, Einladungen, Anfragen und Änderungen in deinen Alben und Spaces'**
  String get notificationChannelDescription;

  /// No description provided for @errUserNotFound.
  ///
  /// In de, this message translates to:
  /// **'Diese Person hat noch keinen Smile-Account.'**
  String get errUserNotFound;

  /// No description provided for @errNotAlbumManager.
  ///
  /// In de, this message translates to:
  /// **'Du bist nicht berechtigt, dieses Album zu verwalten.'**
  String get errNotAlbumManager;

  /// No description provided for @errRequestPending.
  ///
  /// In de, this message translates to:
  /// **'Es gibt bereits eine offene Einladung/Anfrage.'**
  String get errRequestPending;

  /// No description provided for @errNotSpaceAdmin.
  ///
  /// In de, this message translates to:
  /// **'Nur der Admin kann das tun.'**
  String get errNotSpaceAdmin;

  /// No description provided for @errAlreadyAdmin.
  ///
  /// In de, this message translates to:
  /// **'Diese Person ist bereits Admin.'**
  String get errAlreadyAdmin;

  /// No description provided for @errAlreadyCoAdmin.
  ///
  /// In de, this message translates to:
  /// **'Diese Person ist bereits Co-Admin.'**
  String get errAlreadyCoAdmin;

  /// No description provided for @errInvitePending.
  ///
  /// In de, this message translates to:
  /// **'Es gibt bereits eine offene Einladung.'**
  String get errInvitePending;

  /// No description provided for @errNotCoAdmin.
  ///
  /// In de, this message translates to:
  /// **'Diese Person ist kein Co-Admin.'**
  String get errNotCoAdmin;

  /// No description provided for @errGeneric.
  ///
  /// In de, this message translates to:
  /// **'Das hat leider nicht geklappt. Bitte versuche es noch einmal.'**
  String get errGeneric;

  /// No description provided for @noLongerAvailable.
  ///
  /// In de, this message translates to:
  /// **'Das ist nicht mehr verfügbar – gelöscht oder kein Zugriff mehr.'**
  String get noLongerAvailable;

  /// No description provided for @dateToday.
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get dateToday;

  /// No description provided for @dateYesterday.
  ///
  /// In de, this message translates to:
  /// **'Gestern'**
  String get dateYesterday;

  /// No description provided for @timeJustNow.
  ///
  /// In de, this message translates to:
  /// **'gerade eben'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In de, this message translates to:
  /// **'vor {minutes} Min.'**
  String timeMinutesAgo(int minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In de, this message translates to:
  /// **'vor {hours} Std.'**
  String timeHoursAgo(int hours);

  /// No description provided for @dateNumericPattern.
  ///
  /// In de, this message translates to:
  /// **'dd.MM.yyyy'**
  String get dateNumericPattern;

  /// No description provided for @dateNumericShortPattern.
  ///
  /// In de, this message translates to:
  /// **'dd.MM.yy'**
  String get dateNumericShortPattern;

  /// No description provided for @licenseOther.
  ///
  /// In de, this message translates to:
  /// **'Lizenz'**
  String get licenseOther;

  /// No description provided for @language.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get language;

  /// No description provided for @languageAutomatic.
  ///
  /// In de, this message translates to:
  /// **'Automatisch'**
  String get languageAutomatic;

  /// No description provided for @languageAutomaticValue.
  ///
  /// In de, this message translates to:
  /// **'Automatisch ({language})'**
  String languageAutomaticValue(String language);

  /// No description provided for @languageLikePhone.
  ///
  /// In de, this message translates to:
  /// **'Wie das Handy: {language}'**
  String languageLikePhone(String language);

  /// No description provided for @languageSheetHint.
  ///
  /// In de, this message translates to:
  /// **'Gilt für die App und die Mitteilungen, die du bekommst.'**
  String get languageSheetHint;

  /// No description provided for @frameLanguage.
  ///
  /// In de, this message translates to:
  /// **'Sprache am Frame'**
  String get frameLanguage;

  /// No description provided for @frameLanguageLikeTablet.
  ///
  /// In de, this message translates to:
  /// **'Wie das Tablet'**
  String get frameLanguageLikeTablet;

  /// No description provided for @loginCodeStillValid.
  ///
  /// In de, this message translates to:
  /// **'Wir haben dir gerade schon einen Code an {email} geschickt. Er gilt noch – bitte gib ihn ein.'**
  String loginCodeStillValid(String email);

  /// No description provided for @languageFollowsPhone.
  ///
  /// In de, this message translates to:
  /// **'Wie das Handy'**
  String get languageFollowsPhone;

  /// No description provided for @planSectionTitle.
  ///
  /// In de, this message translates to:
  /// **'Frame-Abo'**
  String get planSectionTitle;

  /// No description provided for @planTrial.
  ///
  /// In de, this message translates to:
  /// **'Probezeit'**
  String get planTrial;

  /// No description provided for @planDaysLeft.
  ///
  /// In de, this message translates to:
  /// **'{days, plural, =1{noch 1 Tag} other{noch {days} Tage}}'**
  String planDaysLeft(int days);

  /// No description provided for @planTrialUntil.
  ///
  /// In de, this message translates to:
  /// **'Alle Frames bekommen neue Fotos bis {date}'**
  String planTrialUntil(String date);

  /// No description provided for @planFrames.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Frame} other{{count} Frames}}'**
  String planFrames(int count);

  /// No description provided for @planActive.
  ///
  /// In de, this message translates to:
  /// **'aktiv'**
  String get planActive;

  /// No description provided for @planSourceVoucher.
  ///
  /// In de, this message translates to:
  /// **'Gutschein'**
  String get planSourceVoucher;

  /// No description provided for @planSourcePlay.
  ///
  /// In de, this message translates to:
  /// **'Google Play'**
  String get planSourcePlay;

  /// No description provided for @planSourceStaff.
  ///
  /// In de, this message translates to:
  /// **'Smile'**
  String get planSourceStaff;

  /// No description provided for @planUntil.
  ///
  /// In de, this message translates to:
  /// **'bis {date}'**
  String planUntil(String date);

  /// No description provided for @planNoEnd.
  ///
  /// In de, this message translates to:
  /// **'ohne Ablauf'**
  String get planNoEnd;

  /// No description provided for @planNone.
  ///
  /// In de, this message translates to:
  /// **'Kein Abo'**
  String get planNone;

  /// No description provided for @planNoneText.
  ///
  /// In de, this message translates to:
  /// **'Die Frames zeigen weiter alle Fotos, bekommen aber keine neuen.'**
  String get planNoneText;

  /// No description provided for @planFree.
  ///
  /// In de, this message translates to:
  /// **'Kostenlos'**
  String get planFree;

  /// No description provided for @planTrialStartsWithFrame.
  ///
  /// In de, this message translates to:
  /// **'Alben und Fotos sind kostenlos. Mit dem ersten Frame beginnen 2 Monate Probezeit.'**
  String get planTrialStartsWithFrame;

  /// No description provided for @planFramesUsed.
  ///
  /// In de, this message translates to:
  /// **'{used} von {count} Frames'**
  String planFramesUsed(int used, int count);

  /// No description provided for @planVideoLength.
  ///
  /// In de, this message translates to:
  /// **'Videos bis {minutes} Minuten'**
  String planVideoLength(int minutes);

  /// No description provided for @choosePlan.
  ///
  /// In de, this message translates to:
  /// **'Abo wählen'**
  String get choosePlan;

  /// No description provided for @redeemVoucher.
  ///
  /// In de, this message translates to:
  /// **'Gutschein einlösen'**
  String get redeemVoucher;

  /// No description provided for @planForSpace.
  ///
  /// In de, this message translates to:
  /// **'Für den ganzen Space „{space}“. Mitglieder zahlen nie etwas.'**
  String planForSpace(String space);

  /// No description provided for @planTierMore.
  ///
  /// In de, this message translates to:
  /// **'Mehr als 5'**
  String get planTierMore;

  /// No description provided for @planTierDetails.
  ///
  /// In de, this message translates to:
  /// **'{gb} GB · Videos {minutes} Min.'**
  String planTierDetails(int gb, int minutes);

  /// No description provided for @planTierMoreDetails.
  ///
  /// In de, this message translates to:
  /// **'je Frame +20 GB · 15 Min.'**
  String get planTierMoreDetails;

  /// No description provided for @planPerMonth.
  ///
  /// In de, this message translates to:
  /// **'pro Monat'**
  String get planPerMonth;

  /// No description provided for @planPerExtraFrame.
  ///
  /// In de, this message translates to:
  /// **'je Frame'**
  String get planPerExtraFrame;

  /// No description provided for @planYearlyHint.
  ///
  /// In de, this message translates to:
  /// **'Jährlich zahlen: 2 Monate geschenkt'**
  String get planYearlyHint;

  /// No description provided for @planYours.
  ///
  /// In de, this message translates to:
  /// **'deins'**
  String get planYours;

  /// No description provided for @planBuySoon.
  ///
  /// In de, this message translates to:
  /// **'Kaufen geht bald direkt hier. Bis dahin mit einem Gutschein.'**
  String get planBuySoon;

  /// No description provided for @voucherForSpace.
  ///
  /// In de, this message translates to:
  /// **'Für den Space'**
  String get voucherForSpace;

  /// No description provided for @voucherChangeSpace.
  ///
  /// In de, this message translates to:
  /// **'ändern'**
  String get voucherChangeSpace;

  /// No description provided for @voucherEnterCode.
  ///
  /// In de, this message translates to:
  /// **'Gib den Code von deiner Karte ein'**
  String get voucherEnterCode;

  /// No description provided for @voucherCodeHint.
  ///
  /// In de, this message translates to:
  /// **'SMILE-XXXX-XXXX'**
  String get voucherCodeHint;

  /// No description provided for @voucherRedeem.
  ///
  /// In de, this message translates to:
  /// **'Einlösen'**
  String get voucherRedeem;

  /// No description provided for @voucherScan.
  ///
  /// In de, this message translates to:
  /// **'QR-Code scannen'**
  String get voucherScan;

  /// No description provided for @voucherCodeNote.
  ///
  /// In de, this message translates to:
  /// **'Groß- und Kleinschreibung ist egal.'**
  String get voucherCodeNote;

  /// No description provided for @voucherDone.
  ///
  /// In de, this message translates to:
  /// **'Gutschein eingelöst'**
  String get voucherDone;

  /// No description provided for @voucherDoneText.
  ///
  /// In de, this message translates to:
  /// **'{space} hat jetzt {frames} bis {date}.'**
  String voucherDoneText(String space, String frames, String date);

  /// No description provided for @voucherDoneLater.
  ///
  /// In de, this message translates to:
  /// **'{space} hat {frames} vom {start} bis {date} – direkt nach dem, was schon läuft.'**
  String voucherDoneLater(
    String space,
    String frames,
    String start,
    String date,
  );

  /// No description provided for @voucherGiftFrom.
  ///
  /// In de, this message translates to:
  /// **'Ein Geschenk von {name}'**
  String voucherGiftFrom(String name);

  /// No description provided for @voucherNotFound.
  ///
  /// In de, this message translates to:
  /// **'Diesen Code gibt es nicht. Prüf ihn bitte noch einmal.'**
  String get voucherNotFound;

  /// No description provided for @voucherAlreadyUsed.
  ///
  /// In de, this message translates to:
  /// **'Dieser Code wurde schon verwendet.'**
  String get voucherAlreadyUsed;

  /// No description provided for @voucherExpired.
  ///
  /// In de, this message translates to:
  /// **'Dieser Code ist abgelaufen.'**
  String get voucherExpired;

  /// No description provided for @voucherBlocked.
  ///
  /// In de, this message translates to:
  /// **'Dieser Code gilt nicht mehr.'**
  String get voucherBlocked;

  /// No description provided for @voucherRateLimited.
  ///
  /// In de, this message translates to:
  /// **'Zu viele Versuche. Bitte versuch es in einer Stunde wieder.'**
  String get voucherRateLimited;

  /// No description provided for @voucherNotManager.
  ///
  /// In de, this message translates to:
  /// **'Nur die Admins eines Spaces können einen Gutschein einlösen.'**
  String get voucherNotManager;

  /// No description provided for @voucherNoSpace.
  ///
  /// In de, this message translates to:
  /// **'Leg zuerst einen Space an – der Gutschein gilt dann für ihn.'**
  String get voucherNoSpace;

  /// No description provided for @voucherPickSpace.
  ///
  /// In de, this message translates to:
  /// **'Für welchen Space?'**
  String get voucherPickSpace;

  /// No description provided for @frameNotCovered.
  ///
  /// In de, this message translates to:
  /// **'Bekommt keine neuen Fotos – mehr Frames als im Abo'**
  String get frameNotCovered;

  /// No description provided for @frameNoPlan.
  ///
  /// In de, this message translates to:
  /// **'Bekommt keine neuen Fotos – kein Abo'**
  String get frameNoPlan;

  /// No description provided for @sendFailedSpaceFull.
  ///
  /// In de, this message translates to:
  /// **'Der Speicher dieses Spaces ist voll – nicht gesendet. Die Admins können Platz schaffen oder ein größeres Abo wählen.'**
  String get sendFailedSpaceFull;
}

class _SmileTextsDelegate extends LocalizationsDelegate<SmileTexts> {
  const _SmileTextsDelegate();

  @override
  Future<SmileTexts> load(Locale locale) {
    return SynchronousFuture<SmileTexts>(lookupSmileTexts(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_SmileTextsDelegate old) => false;
}

SmileTexts lookupSmileTexts(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return SmileTextsDe();
    case 'en':
      return SmileTextsEn();
  }

  throw FlutterError(
    'SmileTexts.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
