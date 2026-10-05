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
