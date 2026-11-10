// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'smile_texts.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SmileTextsEn extends SmileTexts {
  SmileTextsEn([String locale = 'en']) : super(locale);

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
  String get albums => 'Albums';

  @override
  String albumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums',
      one: '1 album',
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
  String get persons => 'People';

  @override
  String personCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get profile => 'Profile';

  @override
  String get you => 'You';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleCoAdmin => 'Co-admin';

  @override
  String get introAlbumsTitle => 'Albums';

  @override
  String get introAlbumsText =>
      'Share photos and videos like on WhatsApp – just without the chat. Everyone in the album sees them right away.';

  @override
  String get introSpacesTitle => 'Spaces';

  @override
  String get introSpacesText =>
      'A Space is your family or household – with your albums and Frames.';

  @override
  String get introFramesTitle => 'Frames';

  @override
  String get introFramesText =>
      'A tablet becomes a picture frame – for Grandma, for example. She doesn\'t have to do a thing.';

  @override
  String get introSkip => 'Skip';

  @override
  String get introNext => 'Next';

  @override
  String get introStart => 'Let\'s go';

  @override
  String get introAgain => 'Watch the introduction';

  @override
  String get introAgainHint =>
      'The three pages from the first start, once more.';

  @override
  String get videoTooLongTitle => 'Video too long';

  @override
  String get videoTooLongText =>
      'Videos can be at most 2 minutes long. Trim it in your gallery and send it again.';

  @override
  String get storageUsed => 'Used';

  @override
  String storageOf(String used, String limit) {
    return '$used of $limit';
  }

  @override
  String storageCounts(String photos, String videos) {
    return '$photos photos · $videos videos';
  }

  @override
  String get shareOutMenu => 'Share …';

  @override
  String get shareOutShort => 'Share';

  @override
  String get saveToPhone => 'Save to phone';

  @override
  String get saveToPhoneShort => 'Save';

  @override
  String get savedOne => 'Saved – in your gallery, album “Smile”.';

  @override
  String savedMany(int count) {
    return '$count saved – in your gallery, album “Smile”.';
  }

  @override
  String get saveFailed => 'Couldn\'t save that.';

  @override
  String get saveAlbum => 'Save whole album';

  @override
  String saveAlbumTitle(int count) {
    return 'Save $count photos and videos to your phone?';
  }

  @override
  String get saveAlbumMessage =>
      'They go into your gallery, album “Smile”. Videos that aren\'t on your phone yet will be downloaded – best on Wi‑Fi.';

  @override
  String saveProgress(int done, int count) {
    return '$done of $count saved …';
  }

  @override
  String get shareFailed => 'Couldn\'t share that.';

  @override
  String get preparing => 'Preparing …';

  @override
  String get pauseZoomTitle => 'Keep zooming while stopped';

  @override
  String get onThisDayTitle => 'On this day';

  @override
  String get onThisDayHint =>
      'Photos taken on this day in earlier years play first today.';

  @override
  String onThisDayYears(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years years ago today',
      one: 'One year ago today',
    );
    return '$_temp0';
  }

  @override
  String get fullHdTitle => 'Full HD';

  @override
  String get fullHdHint =>
      '1080p, sharpest on a tablet. About 45 MB per minute of video, takes longer to send. Off: the level below applies.';

  @override
  String get pauseZoomHint =>
      'A stopped photo keeps zooming at the same pace. Off: it stays exactly as it is.';

  @override
  String get tipDidYouKnow => 'DID YOU KNOW?';

  @override
  String get easyStopTitle => 'Easy Stopping';

  @override
  String get easyStopHint =>
      'A tap stops the picture, another tap lets it continue. On every level, even “Just watch”.';

  @override
  String get easyStoppedTitle => 'Stopped';

  @override
  String get easyStoppedHint => 'Tap again to continue';

  @override
  String get easyResumedTitle => 'Playing again';

  @override
  String get easyLongPressHint => 'Press and hold to show the buttons';

  @override
  String get newSoundTitle => 'Sound for new photos';

  @override
  String get newSoundHint =>
      'Once, when something new arrives. Silent during quiet hours.';

  @override
  String get newReminderTitle => 'Remind until someone looks';

  @override
  String get newReminderHint =>
      'The sound comes back every hour, at most three times.';

  @override
  String get newHintTitle => 'Show what\'s new';

  @override
  String get newHintHint =>
      'Stays on the Frame until someone taps. A tap shows the new photos.';

  @override
  String get newOnePhoto => 'A new photo';

  @override
  String get newOneVideo => 'A new video';

  @override
  String newManyPhotos(int count) {
    return '$count new photos';
  }

  @override
  String newManyVideos(int count) {
    return '$count new videos';
  }

  @override
  String newManyMixed(int count) {
    return '$count new photos and videos';
  }

  @override
  String newFromNames(String names) {
    return 'from $names';
  }

  @override
  String namesAnd(String first, String last) {
    return '$first and $last';
  }

  @override
  String get newTapToSee => 'tap to see';

  @override
  String get roleFrameAdmin => 'Frame admin';

  @override
  String get frameAdminHint =>
      'Decides everything on this Frame: what can be used on it and which albums play.';

  @override
  String get inviteFrameAdmin => 'Invite a Frame admin';

  @override
  String get inviteMoreFrameAdmin => 'Invite another person';

  @override
  String frameAdminFor(String frame) {
    return 'Frame admin of $frame';
  }

  @override
  String get qrScanHintFrameAdmin =>
      'Scan with your phone camera or in Smile: ⋮ → Scan code. You can only become a Frame admin by QR code in person.';

  @override
  String inviteFrameAdminFrom(String name) {
    return '$name would like to make you Frame admin. You\'ll then decide what can be used on the Frame and which albums play there.';
  }

  @override
  String acceptedFrameAdmin(String frame) {
    return 'You\'re now Frame admin of $frame.';
  }

  @override
  String redeemJoinedFrameAdmin(String frame) {
    return 'You\'re now Frame admin of $frame.';
  }

  @override
  String get frameAdminInvited => 'Invited, not accepted yet';

  @override
  String get withdrawInvite => 'Withdraw invitation';

  @override
  String get endFrameAdmin => 'End Frame admin';

  @override
  String endFrameAdminTitle(String name) {
    return 'End $name as Frame admin?';
  }

  @override
  String endFrameAdminMessage(String name, String frame) {
    return '$name will no longer decide about $frame. The Frame keeps running as set.';
  }

  @override
  String get giveUpFrameAdmin => 'Give up Frame admin';

  @override
  String giveUpFrameAdminMessage(String frame) {
    return 'You\'ll no longer decide about $frame. The Frame keeps running as set.';
  }

  @override
  String frameAdminPersonHint(String frame) {
    return 'Frame admin of $frame. Decides how it\'s used and which albums play. Doesn\'t manage photos, albums or people in the Space.';
  }

  @override
  String get alreadyFrameAdmin => 'Already Frame admin or admin';

  @override
  String get youAreFrameAdmin => 'you\'re Frame admin';

  @override
  String get unlockSection => 'Unlock on the Frame';

  @override
  String get unlockHint =>
      'Press and hold the clock and enter the code: the Frame shows all buttons until it locks again after 2 minutes without a touch.';

  @override
  String get unlockSetCode => 'Set code';

  @override
  String get unlockChangeCode => 'Change code';

  @override
  String get unlockCodeIsSet => 'A code is set.';

  @override
  String get unlockNoCode =>
      'No code yet: nothing can be unlocked on the Frame.';

  @override
  String unlockCodeTitle(String frame) {
    return 'Code for $frame';
  }

  @override
  String get unlockCodeDialogHint =>
      '4 digits. Frame admins and admins can set a new one at any time.';

  @override
  String get unlockCodeRepeat => 'Once more to confirm';

  @override
  String get unlockCodeMismatch =>
      'The two codes are different. Please try again.';

  @override
  String get unlockCodeSaved => 'Code saved';

  @override
  String get unlockRemoveCode => 'Remove code';

  @override
  String get unlockRemoveMessage =>
      'Nothing can be unlocked on the Frame anymore – like before the first code.';

  @override
  String get unlockCodeRemoved => 'Code removed';

  @override
  String get unlockEnterCode => 'Enter code';

  @override
  String get unlockWrongCode => 'Wrong code';

  @override
  String get unlockWaitMinute => 'Please wait 1 minute';

  @override
  String get unlockedBadge => 'Unlocked';

  @override
  String get lockNow => 'Lock';

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
  String get news => 'Activity';

  @override
  String get newsWaiting => 'Activity – something is waiting for you';

  @override
  String get actionSendPhoto => 'Send photo';

  @override
  String get actionInvite => 'Invite';

  @override
  String get actionShare => 'Share with a Space';

  @override
  String get actionAdd => 'Create new';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionLeave => 'Leave';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionRestore => 'Restore';

  @override
  String get actionHandOver => 'Hand over admin';

  @override
  String get actionInviteCode => 'Invite code';

  @override
  String get actionConnect => 'Connect';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionConfirm => 'OK';

  @override
  String get firstStepsWelcome => 'Welcome to Smile';

  @override
  String get firstStepsInvited => 'I was invited';

  @override
  String get firstStepsInvitedHint => 'Scan a QR code or type a code';

  @override
  String get firstStepsSetup => 'I\'m setting up Smile';

  @override
  String get firstStepsSetupHint =>
      'Create a Space for your home or your business';

  @override
  String get firstStepsQuestion =>
      'Your albums will show up here. How would you like to start?';

  @override
  String albumsLoadError(String error) {
    return 'Couldn\'t load the albums right now. $error';
  }

  @override
  String get albumsEmptyTitle => 'No albums yet';

  @override
  String get albumsEmptyMessage => 'Create a Space or accept an invitation.';

  @override
  String get openSpaces => 'Open Spaces';

  @override
  String get albumInfo => 'Album info';

  @override
  String get addMedia => 'Share a photo or video';

  @override
  String get feedEmptyTitle => 'No photos yet';

  @override
  String get feedEmptyMemberHint => 'Tap + to share the first photo or video.';

  @override
  String get hiddenPhotos => 'Hidden photos';

  @override
  String get hiddenPhotosEmpty => 'No hidden photos';

  @override
  String get actionHide => 'Hide';

  @override
  String get actionUnhide => 'Unhide';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get requestMembership => 'Become a member';

  @override
  String get requestSent => 'Request sent';

  @override
  String get sendTo => 'Send to …';

  @override
  String sharedPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String sharedVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '1 video',
    );
    return '$_temp0';
  }

  @override
  String get sendToNoAlbum =>
      'You\'re not in any album yet where you can share photos.';

  @override
  String albumInSpace(String space) {
    return 'Album in $space';
  }

  @override
  String get rename => 'Rename';

  @override
  String get renameAlbum => 'Rename album';

  @override
  String get name => 'Name';

  @override
  String get save => 'Save';

  @override
  String get inviteToAlbum => 'Invite a person';

  @override
  String get inviteToAlbumHint =>
      'The person needs a Smile account already. They can accept or decline the invitation.';

  @override
  String get shareWithSpace => 'Share with a Space';

  @override
  String get shareWithSpaceHint =>
      'An admin of the other Space can accept. Its people and Frames then see the album but don\'t add anything.';

  @override
  String get emailOfAdmin => 'Email address';

  @override
  String get invitedWaiting => 'Invited · waiting for an answer';

  @override
  String get wantsToJoin => 'Wants to become a member';

  @override
  String get wantsToShare => 'Wants to see the album with their own Space';

  @override
  String get sharedViewOnly => 'Sees the album, doesn\'t add anything';

  @override
  String get notSharedYet => 'Not shared with any other Space yet';

  @override
  String get showsOn => 'Playing on';

  @override
  String get notOnAnyFrame => 'Not on any Frame yet';

  @override
  String get showOnFrame => 'Show on a Frame';

  @override
  String get removeFromAlbum => 'Remove from album';

  @override
  String removePersonTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get removePersonMessage => 'The person loses access to this album.';

  @override
  String get endShare => 'Stop sharing';

  @override
  String endShareTitle(String space) {
    return 'Stop sharing with $space?';
  }

  @override
  String endShareMessage(String space, String album) {
    return '$space won\'t see $album anymore, not on its Frames either.';
  }

  @override
  String get leaveAlbum => 'Leave album';

  @override
  String get leaveAlbumMessage =>
      'You won\'t see this album\'s photos anymore.';

  @override
  String sharedAlbumOwnedBy(String owner, String home, String space) {
    return 'This album belongs to $owner from the Space $home and is shared with your Space $space.';
  }

  @override
  String removeFromSpace(String space) {
    return 'Remove from $space';
  }

  @override
  String removeFromSpaceHint(String owner) {
    return 'The album belongs to $owner and is kept.';
  }

  @override
  String removeFromSpaceTitle(String album, String space) {
    return 'Remove $album from $space?';
  }

  @override
  String removeFromSpaceMessage(String owner, String space) {
    return 'You won\'t see the album anymore: not in your album list and not on your Frames, and you can\'t post there anymore.\n\nIt belongs to $owner and is kept with all its photos. $owner can share it with $space again.';
  }

  @override
  String get deleteAlbum => 'Delete album';

  @override
  String deleteAlbumTitle(String album) {
    return 'Delete the album $album?';
  }

  @override
  String get deleteAlbumMessage =>
      'The album and all its photos disappear right away for everyone and from all Frames. You can restore it from the trash for 30 days.';

  @override
  String albumInfoLoadError(String error) {
    return 'Couldn\'t load the album info right now. $error';
  }

  @override
  String actionFailed(String error) {
    return 'That didn\'t work. $error';
  }

  @override
  String get actionAccept => 'Accept';

  @override
  String get actionDecline => 'Decline';

  @override
  String get actionWithdraw => 'Withdraw';

  @override
  String spacesLoadError(String error) {
    return 'Couldn\'t load the Spaces right now. $error';
  }

  @override
  String get spacesEmptyTitle => 'No Space of your own yet';

  @override
  String get spacesEmptyMessage =>
      'You only need a Space if you set up Frames yourself or manage albums, for your home or your business.';

  @override
  String get createSpace => 'Create a Space';

  @override
  String get createSpaceHint => 'e.g. The Miller family';

  @override
  String get nameMissing => 'Please enter a name.';

  @override
  String get create => 'Create';

  @override
  String get youAreAdmin => 'You\'re the admin';

  @override
  String get youAreCoAdmin => 'You\'re a co-admin';

  @override
  String get renameSpace => 'Rename Space';

  @override
  String spaceInfoLoadError(String error) {
    return 'Couldn\'t load the Space info right now. $error';
  }

  @override
  String get createAlbum => 'Create album';

  @override
  String get newAlbum => 'New album';

  @override
  String get moreOptions => 'More options';

  @override
  String get newAlbumWhere => 'New album in …';

  @override
  String inSpaceLine(String space) {
    return 'in $space';
  }

  @override
  String get createAlbumHint => 'e.g. Grandchildren';

  @override
  String get noAlbumYet => 'No album yet';

  @override
  String sharedIntoSpace(String space) {
    return 'Shared with the Space $space';
  }

  @override
  String sharedFromSpace(String space) {
    return 'from the Space $space · view only';
  }

  @override
  String get viewOnly => 'view only';

  @override
  String get sharedIntoSpaceHint =>
      'Albums of other Spaces that can only be viewed here';

  @override
  String get stopShowing => 'Stop showing';

  @override
  String stopShowingTitle(String album) {
    return 'Stop showing $album?';
  }

  @override
  String get stopShowingMessage =>
      'This Space and its Frames won\'t see the album anymore.';

  @override
  String get noFrameYet => 'No Frame yet';

  @override
  String get connectFrame => 'Connect a Frame';

  @override
  String get frameActive => 'Active';

  @override
  String get framePending => 'Waiting to be paired';

  @override
  String get frameRevoked => 'Revoked';

  @override
  String get inviteCoAdmin => 'Invite a co-admin';

  @override
  String get inviteCoAdminHint =>
      'The person needs a Smile account already. If they accept, they manage this Space with all rights except deleting it.';

  @override
  String get makeAdmin => 'Make admin';

  @override
  String makeAdminTitle(String name) {
    return 'Make $name the admin?';
  }

  @override
  String get makeAdminMessage =>
      'This person becomes admin of this Space. You stay co-admin with all rights, but no longer decide alone who helps manage it.';

  @override
  String get chooseNewAdmin => 'Who should become admin?';

  @override
  String get removeCoAdmin => 'Remove as co-admin';

  @override
  String removeCoAdminTitle(String name) {
    return 'Remove $name as co-admin?';
  }

  @override
  String get removeCoAdminMessage =>
      'The person loses the right to manage this Space.';

  @override
  String get stepDown => 'Give up co-admin role';

  @override
  String get actionStepDown => 'Give up';

  @override
  String get stepDownMessage => 'You lose the right to manage this Space.';

  @override
  String get trashTitle => 'Trash';

  @override
  String get deleteSpace => 'Delete Space';

  @override
  String deleteSpaceTitle(String space) {
    return 'Delete the Space $space?';
  }

  @override
  String get deleteSpaceMessage =>
      'The Space with all albums, photos and Frames disappears right away for everyone; everyone involved is notified. You can restore it from the trash for 30 days.';

  @override
  String inTrash(String name) {
    return '$name is in the trash.';
  }

  @override
  String frameInfoLoadError(String error) {
    return 'Couldn\'t load the Frame info right now. $error';
  }

  @override
  String frameInSpace(String space) {
    return 'Frame in $space';
  }

  @override
  String get renameFrame => 'Rename Frame';

  @override
  String get status => 'Status';

  @override
  String get device => 'Device';

  @override
  String get lastSeen => 'Last seen';

  @override
  String get appVersion => 'App version';

  @override
  String get battery => 'Battery';

  @override
  String get charging => 'charging';

  @override
  String get settings => 'Settings';

  @override
  String get videoSound => 'Videos with sound';

  @override
  String get videoSoundHint => 'Off: videos play muted on this Frame.';

  @override
  String get albumSwitch => 'Allow switching albums';

  @override
  String get albumSwitchHint =>
      'Whoever stands in front of the Frame can switch between albums.';

  @override
  String get showsAlbums => 'Shows';

  @override
  String get noAlbumAssigned => 'No album assigned yet';

  @override
  String get addAlbumToFrame => 'Add album';

  @override
  String get noMoreAlbums => 'There are no other albums this Space can see.';

  @override
  String get close => 'Close';

  @override
  String get removeFromFrame => 'Remove from Frame';

  @override
  String get openAlbum => 'Open album';

  @override
  String get openFrame => 'Open Frame';

  @override
  String get offlineHint => 'Offline – last loaded state';

  @override
  String get videoNotOnPhone =>
      'This video isn\'t on your phone yet. It can\'t play without a connection.';

  @override
  String changeNotSaved(String reason) {
    return 'The change wasn\'t saved. $reason';
  }

  @override
  String get showingNow => 'Playing now';

  @override
  String get showNow => 'Show now';

  @override
  String get showHereNow => 'Show here now';

  @override
  String get frameShowsThisAlbum => 'is showing this album';

  @override
  String frameShowsAlbum(String album) {
    return 'is showing $album';
  }

  @override
  String frameSwitched(String frame, String album) {
    return '$frame is now showing $album.';
  }

  @override
  String removeFromFrameTitle(String album) {
    return 'Remove $album from the Frame?';
  }

  @override
  String get removeFromFrameMessage =>
      'The Frame won\'t show this album\'s photos anymore. The album and its photos are kept.';

  @override
  String get revokeFrame => 'Revoke Frame';

  @override
  String get revokeFrameMessage =>
      'The Frame loses all access right away and deletes its photos. You can reactivate it at any time.';

  @override
  String get reactivateFrame => 'Reactivate Frame';

  @override
  String get newsEmptyTitle => 'No activity';

  @override
  String get newsEmptyMessage =>
      'Invitations, requests and deleted albums or Spaces show up here.';

  @override
  String newsLoadError(String error) {
    return 'Couldn\'t load the activity right now. $error';
  }

  @override
  String get invitations => 'Invitations';

  @override
  String get requests => 'Requests';

  @override
  String get myRequests => 'My requests';

  @override
  String inviteCoAdminFrom(String name) {
    return '$name invites you as co-admin';
  }

  @override
  String inviteMemberFrom(String name) {
    return '$name invites you as a member';
  }

  @override
  String inviteShareFrom(String name) {
    return '$name would like to share the album with your Space';
  }

  @override
  String requestMemberFrom(String name) {
    return '$name would like to become a member';
  }

  @override
  String requestShareFrom(String name) {
    return '$name would like to see the album with their own Space';
  }

  @override
  String get waitingForAnswer => 'Waiting for an answer';

  @override
  String acceptedCoAdmin(String space) {
    return 'You now help manage $space.';
  }

  @override
  String acceptedAlbum(String album) {
    return '$album is now in your albums.';
  }

  @override
  String acceptedShare(String album) {
    return '$album is now shared with your Space.';
  }

  @override
  String get requestAccepted => 'Request accepted.';

  @override
  String get needOwnSpace =>
      'You need a Space of your own first to accept a shared album.';

  @override
  String get chooseSpace => 'With which Space?';

  @override
  String get trashEmpty => 'The trash is empty.';

  @override
  String trashLoadError(String error) {
    return 'Couldn\'t load the trash right now. $error';
  }

  @override
  String trashSpaceIn(String space) {
    return 'in $space';
  }

  @override
  String trashDeletedBy(String name) {
    return 'deleted by $name';
  }

  @override
  String trashGoneOn(String date) {
    return 'gone for good on $date';
  }

  @override
  String restored(String name) {
    return '$name is restored.';
  }

  @override
  String profileLoadError(String error) {
    return 'Couldn\'t load your profile right now. $error';
  }

  @override
  String get retry => 'Try again';

  @override
  String get changeName => 'Change name';

  @override
  String nameSaveError(String error) {
    return 'Couldn\'t save the name. $error';
  }

  @override
  String avatarUploadError(String error) {
    return 'Couldn\'t upload the picture. $error';
  }

  @override
  String get changePicture => 'Change profile picture';

  @override
  String get viewPicture => 'View profile picture';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get choosePicture => 'Choose an existing picture';

  @override
  String get pictureFromWeb => 'Load from a web address';

  @override
  String get pictureUrl => 'Picture URL';

  @override
  String get load => 'Load';

  @override
  String get account => 'Account';

  @override
  String get aboutSmile => 'About Smile';

  @override
  String aboutSmileHint(String version) {
    return 'Version $version · Legal notice · Privacy';
  }

  @override
  String versionValue(String version) {
    return 'Version $version';
  }

  @override
  String get impressum => 'Legal notice';

  @override
  String get privacyPolicy => 'Privacy';

  @override
  String get deleteAccountWebHint => 'How it works, also without the app';

  @override
  String get openSourceLicenses => 'Open source licenses';

  @override
  String get openSourceThanks =>
      'Smile uses this free software. Thanks to everyone who builds it.';

  @override
  String get searchHint => 'Search …';

  @override
  String licenseCount(int count) {
    return '$count licenses';
  }

  @override
  String get loginPrivacyBefore => 'By signing in you agree to our ';

  @override
  String get loginPrivacyLink => 'privacy policy';

  @override
  String get loginPrivacyAfter => '.';

  @override
  String get emailAddress => 'Email address';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutQuestion => 'Do you really want to sign out?';

  @override
  String get profileSetupQuestion => 'What should we call you?';

  @override
  String get next => 'Next';

  @override
  String get framePairTitle => 'Connect Frame';

  @override
  String get framePairHint =>
      'Hold the QR code from the Smile app up to the camera – or type the code shown below it.';

  @override
  String get framePairButton => 'Connect';

  @override
  String get framePairInvalid => 'This code isn\'t valid.';

  @override
  String get framePairExpired =>
      'The code has expired. Show a new one in the Smile app.';

  @override
  String get framePairRevoked => 'This Frame was revoked.';

  @override
  String get framePairFailed => 'Couldn\'t connect.';

  @override
  String get framePairNoConnection =>
      'No connection to the server. Please try again.';

  @override
  String get frameOfflineTooLong =>
      'This Frame was offline for too long.\n\nThe photos will come back as soon as it\'s online.';

  @override
  String get frameRevokedScreen =>
      'This Frame was revoked.\n\nAn admin of the Space can reactivate it in the Smile app.';

  @override
  String get frameNoPhotos => 'No photos yet';

  @override
  String get chooseAlbum => 'Choose album';

  @override
  String postPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: 'photo',
    );
    return '$_temp0';
  }

  @override
  String postVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: 'video',
    );
    return '$_temp0';
  }

  @override
  String lastPostBy(String name, String what) {
    return '$name: $what';
  }

  @override
  String get someone => 'Someone';

  @override
  String get noPostsYet => 'No photos yet';

  @override
  String get history => 'History';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get removeAll => 'Remove all';

  @override
  String get removeEntry => 'Remove';

  @override
  String get deleteFrame => 'Delete Frame';

  @override
  String deleteFrameTitle(String name) {
    return 'Delete the Frame $name?';
  }

  @override
  String get deleteFrameMessage =>
      'The Frame is removed for good. The tablet deletes its photos and shows the connect screen again. To keep using it, just connect it again.';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountTitle => 'Delete account for good?';

  @override
  String get deleteAccountMessage =>
      'Your profile, all your photos and videos in all albums and all your memberships are deleted right away and for good. Spaces where you\'re the admin go to your longest-standing co-admin; without a co-admin, the Space is deleted with all its albums and Frames. This can\'t be undone.';

  @override
  String get deleteAccountConfirm => 'Delete for good';

  @override
  String deleteAccountTitleNamed(String name) {
    return 'Delete $name\'s account?';
  }

  @override
  String deleteAccountWhich(String email) {
    return 'This deletes the account $email you\'re signed in with right now.';
  }

  @override
  String get deleteAccountTypeEmail => 'To confirm, type this email address:';

  @override
  String get newsUnseen => 'Activity – there\'s something new';

  @override
  String pictureFor(String name) {
    return 'Picture for $name';
  }

  @override
  String coverFor(String name) {
    return 'Cover for $name';
  }

  @override
  String get pickFromAlbum => 'Choose a photo from the album';

  @override
  String get automaticCover => 'Automatic: newest photo';

  @override
  String get removePicture => 'Remove picture';

  @override
  String get changeObjectPicture => 'Change picture';

  @override
  String get setAsCover => 'Set as cover';

  @override
  String coverSet(String name) {
    return '$name has a new cover.';
  }

  @override
  String get choosePhoto => 'Choose photo';

  @override
  String get noPhotosInAlbum => 'There are no photos in this album yet.';

  @override
  String get captureInAlbum => 'Capture';

  @override
  String get recordVideo => 'Record video';

  @override
  String get captureSend => 'Send';

  @override
  String get captureRetake => 'Retake';

  @override
  String get noConnectionTitle => 'No internet connection';

  @override
  String get noConnectionMessage => 'Check your connection and try again.';

  @override
  String get noConnectionReason => 'No internet connection.';

  @override
  String get tryAgainReason => 'Please try again.';

  @override
  String get videoNotPlayable => 'The video can\'t be played right now.';

  @override
  String get loginEmailMissing => 'Please enter your email address.';

  @override
  String get loginEmailInvalid =>
      'That isn\'t a valid email address. Please check it.';

  @override
  String get loginSendFailed =>
      'Couldn\'t send the email with the code right now. Please try again in a moment.';

  @override
  String get loginCodeWrong =>
      'The code is wrong or has expired. Please check it or get a new one.';

  @override
  String get sendFailed => 'Couldn\'t send that. Please try again.';

  @override
  String sendFailedSome(int failed, int total) {
    return '$failed of $total couldn\'t be sent. Please try again.';
  }

  @override
  String get ok => 'OK';

  @override
  String get dontSend => 'Don\'t send';

  @override
  String allSelected(int count) {
    return 'All $count selected';
  }

  @override
  String get selectAll => 'All';

  @override
  String get selectNone => 'None';

  @override
  String get coverShort => 'Cover';

  @override
  String deletePhotosTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count photos?',
      one: 'Delete photo?',
    );
    return '$_temp0';
  }

  @override
  String get deleteForEveryone => 'Delete for everyone';

  @override
  String get deleteForEveryoneHint =>
      'For everyone and on all Frames, for good';

  @override
  String get deleteForMe => 'Delete for me';

  @override
  String get deleteForMeHint =>
      'Gone only for you, bring it back via ⋮ → Show hidden';

  @override
  String get deleteOnlyOwn =>
      'You can only delete your own photos for everyone.';

  @override
  String inviteToNamed(String name) {
    return 'Invite to $name';
  }

  @override
  String coAdminFor(String name) {
    return 'Co-admin for $name';
  }

  @override
  String get searchName => 'Search name';

  @override
  String get noKnownPeople =>
      'No one you know in Smile yet. Invite by QR code or link.';

  @override
  String get showQrCode => 'Show QR code';

  @override
  String get shareInviteLink => 'Share invite link';

  @override
  String get inviteByEmail => 'Invite by email';

  @override
  String inviteSentTo(String name) {
    return 'Invitation sent to $name';
  }

  @override
  String get managesASpace => 'Manages a Space';

  @override
  String get qrScanHint =>
      'Scan with your phone camera or in Smile: ⋮ → Scan code. Or type the code.';

  @override
  String get qrScanHintCoAdmin =>
      'Scan with your phone camera or in Smile: ⋮ → Scan code. You can only become co-admin by QR code in person.';

  @override
  String get qrValid => 'Valid for 24 hours.';

  @override
  String get newCode => 'Create a new code';

  @override
  String inviteMessageMember(String album, String link) {
    return 'Join my Smile album $album! Just tap the link: $link';
  }

  @override
  String inviteMessageShare(String album, String link) {
    return 'I\'d like to share my Smile album $album with your Space. Just tap the link: $link';
  }

  @override
  String get scanCode => 'Scan code';

  @override
  String get scanHint => 'Hold the QR code inside the frame';

  @override
  String get typeCode => 'Type code';

  @override
  String get codeFieldHint => 'e.g. K7P-2QX';

  @override
  String redeemJoinedAlbum(String name) {
    return 'You\'re now in the album $name.';
  }

  @override
  String redeemJoinedShare(String album, String space) {
    return '$album can now be seen in your Space $space.';
  }

  @override
  String redeemJoinedCoAdmin(String space) {
    return 'You\'re now co-admin of $space.';
  }

  @override
  String get redeemRequestedTitle => 'Request sent';

  @override
  String redeemRequested(String name) {
    return 'The admins of $name will decide. You\'ll be notified.';
  }

  @override
  String get redeemAlready => 'You\'re already in.';

  @override
  String get redeemPickSpace => 'Share with which Space?';

  @override
  String get codeInvalid => 'This code isn\'t valid.';

  @override
  String get codeExpired => 'The code has expired. Ask for a new one.';

  @override
  String get codeQrOnly =>
      'You can only become co-admin by scanning the QR code in person.';

  @override
  String get codeNoSpace =>
      'You don\'t manage a Space you could share the album with.';

  @override
  String get cameraUnavailable =>
      'The camera isn\'t available. You can type the code instead.';

  @override
  String get frameOnline => 'Online';

  @override
  String frameOfflineSince(String time) {
    return 'Offline for $time';
  }

  @override
  String get frameNeverOnline => 'Connected · checking in shortly';

  @override
  String batteryShort(int level) {
    return 'Battery $level%';
  }

  @override
  String durationMinutes(int count) {
    return '$count min';
  }

  @override
  String durationHours(int count) {
    return '$count hrs';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get nowShowingLabel => 'Playing now';

  @override
  String get switchAlbum => 'Switch album';

  @override
  String get soundOn => 'Sound on';

  @override
  String get soundOff => 'Sound off';

  @override
  String get tileVideoSound => 'Video sound';

  @override
  String get tileAlbumSwitch => 'Switching on the Frame';

  @override
  String get valueOn => 'On';

  @override
  String get valueOff => 'Off';

  @override
  String get valueAllowed => 'Allowed';

  @override
  String get manageAlbums => 'Manage albums';

  @override
  String get settingsAndDevice => 'Settings & device';

  @override
  String get openRemote => 'Control Frame';

  @override
  String get pickFrame => 'Which Frame?';

  @override
  String get useAsFrame => 'Use this device as a Frame';

  @override
  String get setUpFrame => 'Set up a Frame';

  @override
  String connectNamedFrame(String name) {
    return 'Connect $name';
  }

  @override
  String get connectFrameHint =>
      'On the tablet: open Smile → Use this device as a Frame → scan the QR code. Valid for 15 minutes.';

  @override
  String get waitingForFrame => 'Waiting for the Frame …';

  @override
  String get frameNameQuestion =>
      'What should the new Frame be called, e.g. Kitchen?';

  @override
  String get anotherDevice => 'Another device';

  @override
  String get anotherDeviceHint =>
      'The tablet scans the QR code or gets the code.';

  @override
  String get thisDevice => 'This device';

  @override
  String get thisDeviceHint =>
      'This device becomes a Frame right away. You\'ll be signed out here.';

  @override
  String get thisDeviceTitle => 'Make this device a Frame?';

  @override
  String get thisDeviceMessage =>
      'Afterwards only the slideshow runs here, and you\'ll be signed out on this device. Your albums and photos are of course kept.';

  @override
  String get thisDeviceConfirm => 'Make it a Frame';

  @override
  String get frameScanHint =>
      'Hold the QR code from the Smile app inside the frame';

  @override
  String get frameScanInstead => 'Scan QR code';

  @override
  String get pickSpaceForFrame => 'For which Space?';

  @override
  String get connectOtherDevice => 'Connect another device';

  @override
  String get reconnectHint =>
      'On the new device: open Smile → Use this device as a Frame → scan the QR code. It takes over the albums and settings; the old device is no longer a Frame afterwards.';

  @override
  String get done => 'Done';

  @override
  String get playSlideshow => 'Slideshow';

  @override
  String frameAlbumEmpty(String album) {
    return 'There are no photos in $album yet.';
  }

  @override
  String get frameAlbumEmptyHint =>
      'You choose a different album in the Smile app under Frames.';

  @override
  String get sendVideos => 'Sending videos';

  @override
  String get qualityHigh => 'High';

  @override
  String get qualityMedium => 'Medium';

  @override
  String get qualityLow => 'Low';

  @override
  String get qualityHighHint =>
      '720p, very sharp – about 24 MB per minute of video.';

  @override
  String get qualityMediumHint =>
      'Just like WhatsApp (480p) – about 12 MB per minute of video.';

  @override
  String get qualityLowHint =>
      '360p, for small screens – about 6 MB per minute of video. Sent the fastest.';

  @override
  String get ctrlBack => 'Back';

  @override
  String get ctrlPause => 'Pause';

  @override
  String get ctrlPlay => 'Play';

  @override
  String get ctrlNext => 'Next';

  @override
  String get ctrlNewest => 'Newest';

  @override
  String get ctrlOverview => 'Overview';

  @override
  String get ctrlAlbum => 'Album';

  @override
  String get ctrlDuration => 'Duration';

  @override
  String frameNewFrom(String name) {
    return 'New from $name';
  }

  @override
  String get frameBackToSlideshow => 'Back to the slideshow';

  @override
  String get durationQuestion => 'How long should a photo be shown?';

  @override
  String secondsValue(int n) {
    return '$n seconds';
  }

  @override
  String get oneMinute => '1 minute';

  @override
  String get playbackTitle => 'Playback';

  @override
  String get playbackHint =>
      'What plays and how. This is always set in the app, whatever the control level.';

  @override
  String get whatPlays => 'What plays';

  @override
  String get contentAlbum => 'One album';

  @override
  String get contentRotate => 'All albums in turn';

  @override
  String get contentRecent => 'Latest';

  @override
  String get recentMeans => 'Latest means';

  @override
  String recentLast(int n) {
    return 'Last $n photos';
  }

  @override
  String get playOrder => 'Order';

  @override
  String get orderNewest => 'Newest first';

  @override
  String get orderOldest => 'In order';

  @override
  String get orderShuffle => 'Shuffle';

  @override
  String get atEnd => 'At the end';

  @override
  String get endLoop => 'Loop';

  @override
  String get endOverview => 'Show overview';

  @override
  String get displayTime => 'Display time';

  @override
  String get showNewNow => 'Show new photos right away';

  @override
  String get showNewNowHint => 'The top of the picture says who it\'s from.';

  @override
  String get bigClock => 'Big clock with date';

  @override
  String get bigClockHint => 'Weekday, date and time at the top right.';

  @override
  String get showSenderCaption => 'Show sender';

  @override
  String get showSenderCaptionHint =>
      'Album and name at the top left of the picture.';

  @override
  String get quietTime => 'Quiet hours';

  @override
  String get quietTimeHint => 'The screen is dark during this time.';

  @override
  String get quietOff => 'Off';

  @override
  String quietRange(String from, String to) {
    return '$from to $to';
  }

  @override
  String get quietFromLabel => 'Dark from';

  @override
  String get quietToLabel => 'Light from';

  @override
  String get controlsTitle => 'Controls on the Frame';

  @override
  String get controlsHint =>
      'The app always controls the Frame completely. The control level decides what the person in front of the Frame may also do themselves.';

  @override
  String get controlLevel => 'Control level';

  @override
  String get level1 => 'Just watch';

  @override
  String get level1Hint =>
      'Just tapping: stops the picture and lets it continue. Everything else comes from the app.';

  @override
  String get level2 => 'Browse';

  @override
  String get level2Hint => 'Pause and a big Next button.';

  @override
  String get level3 => 'Simple';

  @override
  String get level3Hint => 'Back, Pause, Next and Newest photos.';

  @override
  String get level4 => 'Comfort';

  @override
  String get level4Hint =>
      'Plus Overview, Switch album, Display time and showing or hiding captions.';

  @override
  String get level5 => 'Full control';

  @override
  String get level5Hint => 'Plus all playback settings on the Frame.';

  @override
  String get levelCustom => 'Custom';

  @override
  String get levelCustomHint => 'Some switches differ from the levels.';

  @override
  String get allowedOneByOne => 'Allowed one by one';

  @override
  String get allowNext => 'Next';

  @override
  String get allowBack => 'Back';

  @override
  String get allowPause => 'Pause';

  @override
  String get allowNewest => 'Newest photos';

  @override
  String get allowOverview => 'Overview';

  @override
  String get allowAlbum => 'Switch album';

  @override
  String get allowDuration => 'Display time';

  @override
  String get allowPlayback => 'Playback settings';

  @override
  String get remoteTitle => 'Remote';

  @override
  String get remoteHint => 'Works on every control level.';

  @override
  String remoteNewest(int n) {
    return 'Play the newest $n photos';
  }

  @override
  String get showOnFrameNow => 'Show on Frame now';

  @override
  String get nowRunning => 'playing now';

  @override
  String get addShort => 'Add';

  @override
  String frameOtherSpaceHint(String album, String space) {
    return '$album belongs to the Space $space. A Frame only shows albums from its own Space or ones shared with its Space. An admin of $space can share the album with your Space via Album info → Share with a Space – then it works here with one tap.';
  }

  @override
  String get favorites => 'Favorites';

  @override
  String get favoriteMarked => 'Kept';

  @override
  String get favoriteUnmarked => 'No longer kept';

  @override
  String get ctrlFavorite => 'Keep';

  @override
  String get allowFavorite => 'Keep favorites';

  @override
  String get allowFavorites => 'Play favorites';

  @override
  String get contentFavorites => 'Favorites';

  @override
  String get favoritesSeeAll => 'See all';

  @override
  String favoritesCount(int n) {
    return 'Favorites · $n';
  }

  @override
  String get favoriteOnFrame => 'On the Frame';

  @override
  String favoriteToday(String time) {
    return 'today $time';
  }

  @override
  String favoriteYesterday(String time) {
    return 'yesterday $time';
  }

  @override
  String get favoriteFor => 'Favorite for the Frame';

  @override
  String showOnFrameSent(String frame) {
    return 'Now showing on $frame';
  }

  @override
  String showOnFrameOffline(String frame) {
    return '$frame can\'t be reached right now. The photo won\'t appear there.';
  }

  @override
  String favoriteAddedTo(String frame) {
    return 'Favorite of $frame';
  }

  @override
  String get favoritesEmpty => 'No favorites yet';

  @override
  String get favoritesEmptyHint =>
      'Keep them on the Frame with the heart – or here in an album with the heart at the top right of a photo.';

  @override
  String get favoritesRemove => 'Remove';

  @override
  String get favoritesRemoveAll => 'Remove all';

  @override
  String favoritesRemoveAllQuestion(String frame) {
    return 'Remove all favorites of $frame?';
  }

  @override
  String get favoritesRemoveHint =>
      'The photos themselves stay in their albums.';

  @override
  String favoritesSelected(int n) {
    return '$n selected';
  }

  @override
  String favoritesRemoveSelectedQuestion(int n, String frame) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n favorites',
      one: '1 favorite',
    );
    return 'Remove $_temp0 from $frame?';
  }

  @override
  String favoriteRemovedFrom(String frame) {
    return 'No longer a favorite of $frame';
  }

  @override
  String favoritesAddTitle(String frame) {
    return 'Favorites · $frame';
  }

  @override
  String get favoriteForWhich => 'Favorite for …';

  @override
  String get favoriteStateOn => 'kept';

  @override
  String get favoriteStateOff => 'not kept';

  @override
  String get framePhotosLoading => 'Loading photos …';

  @override
  String get videoLengthLabel => 'Videos';

  @override
  String get videoFull => 'Full length';

  @override
  String videoAsPhoto(int seconds) {
    return 'Like a photo ($seconds s)';
  }

  @override
  String get fillLabel => 'Fill the screen';

  @override
  String get fillNever => 'Never';

  @override
  String get fillAuto => 'When it fits';

  @override
  String get fillAlways => 'Always';

  @override
  String get fillHint =>
      'When it fits: fills the screen if at most a narrow edge is cut off – otherwise the whole photo on a blurred background.';

  @override
  String get slowZoom => 'Slow zoom';

  @override
  String get slowZoomHint => 'Every photo slowly gets a little bigger.';

  @override
  String get groupBrowse => 'Browse';

  @override
  String get groupPlaying => 'What plays';

  @override
  String get orientationLabel => 'Orientation';

  @override
  String get orientAuto => 'Automatic';

  @override
  String get orientPortrait => 'Portrait';

  @override
  String get orientLandscape => 'Landscape';

  @override
  String get slideshowSettings => 'Slideshow settings';

  @override
  String get slideshowSettingsMore => 'Settings …';

  @override
  String get slideshowPause => 'Pause';

  @override
  String get slideshowResume => 'Resume';

  @override
  String get slideshowSettingsHint => 'Applies to the slideshow on this phone.';

  @override
  String get showHiddenMenu => 'Show hidden';

  @override
  String get showAllMenu => 'Show all photos';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get roleAdminHint => 'Created the Space and manages everything.';

  @override
  String get roleCoAdminHint =>
      'Helps manage the Space: albums, Frames and people.';

  @override
  String get roleMemberHint => 'Adds photos and videos to the album.';

  @override
  String get roleViewerHint => 'Sees the album through a shared Space.';

  @override
  String get sharedSpaceHint =>
      'This Space sees the album on its Frames and phones but doesn\'t add anything.';

  @override
  String get favorites2 => 'Favorites';

  @override
  String inviteMessageCodeFallback(String code) {
    return 'If the link doesn\'t work: in Smile ⋮ → Scan code → Type code: $code';
  }

  @override
  String get smileName => 'Smile name';

  @override
  String get smileNameChoose => 'Choose a Smile name';

  @override
  String get smileNameHint =>
      'Anyone who knows your exact Smile name can find you in Smile and invite you. Only the whole name is found, nobody can browse.';

  @override
  String get smileNameRules =>
      '3 to 24 characters: lowercase letters, digits, dot and underscore.';

  @override
  String get smileNameFree => 'Available';

  @override
  String smileNameIsFree(String name) {
    return '@$name is available. Save to make it yours.';
  }

  @override
  String smileNameIsTaken(String name) {
    return '@$name is already taken. Please choose another one.';
  }

  @override
  String get smileNameTooShort => 'Still too short. At least 3 characters.';

  @override
  String get smileNameTooLong => 'Too long. At most 24 characters.';

  @override
  String smileNameBadChar(String char) {
    return 'The character $char isn\'t allowed. Allowed are a–z, 0–9, dot and underscore.';
  }

  @override
  String get smileNameSpace =>
      'Spaces aren\'t allowed. Use a dot or an underscore.';

  @override
  String get smileNameUmlaut =>
      'Accented letters aren\'t allowed. Use plain letters, e.g. ae for ä.';

  @override
  String get smileNameBadStart => 'It has to start with a letter or a digit.';

  @override
  String get smileNameDotAtEnd => 'No dot at the end.';

  @override
  String get smileNameDoubleDot => 'No two dots in a row.';

  @override
  String get smileNameReserved =>
      'This name can\'t be chosen. Please choose another one.';

  @override
  String get smileNameSuggestions => 'These are available:';

  @override
  String get myCardHandlePlaceholder => '@ your Smile name';

  @override
  String get myCardQrPlaceholder => 'Your QR code appears here';

  @override
  String get myCardPreviewHint =>
      'With a Smile name you get this card. Whoever scans it can invite you.';

  @override
  String myCardTakeSuggestion(String name) {
    return 'Take @$name';
  }

  @override
  String get myCardOtherName => 'Choose another name';

  @override
  String get smileNameTaken => 'Already taken';

  @override
  String get smileNameInvalid =>
      'Only a–z, 0–9, dot and underscore, 3 to 24 characters';

  @override
  String get smileNameRemove => 'Remove Smile name';

  @override
  String get smileNameSaveError =>
      'Couldn\'t save the Smile name. Please try again.';

  @override
  String get myCard => 'My card';

  @override
  String get myCardHint =>
      'Show or share this card so someone can invite you to an album.';

  @override
  String get shareMyCard => 'Share my card';

  @override
  String myCardMessage(String link) {
    return 'Invite me in Smile: $link';
  }

  @override
  String get myCardNeedsName =>
      'Choose a Smile name first. Then you get your card with a QR code.';

  @override
  String get searchNameOrHandle => 'Name or @Smile name';

  @override
  String get personNotFound => 'This Smile name doesn\'t exist.';

  @override
  String get personIsYou => 'That\'s your own card.';

  @override
  String get inviteIntoAlbum => 'Invite to an album';

  @override
  String get pickAlbumToInvite => 'To which album?';

  @override
  String get noAlbumsToInvite =>
      'You don\'t manage an album yet that you can invite people to.';

  @override
  String get alreadyInAlbum => 'Already in the album';

  @override
  String get alreadyAdmin => 'Already admin or co-admin';

  @override
  String get managesNoSpace => 'Doesn\'t manage a Space';

  @override
  String get noPersonFound =>
      'Nobody found. Strangers only by their full @Smile name.';

  @override
  String get fromContacts => 'From contacts';

  @override
  String get contactsPermTitle => 'Find contacts in Smile';

  @override
  String get contactsPermText =>
      'Smile checks who in your phone book already has Smile. You can invite everyone else by text message.';

  @override
  String get contactsPermPoint1 =>
      'Your phone book stays on your phone. Only unreadable check values go to Smile for checking.';

  @override
  String get contactsPermPoint2 =>
      'Smile doesn\'t store contacts and never messages anyone on its own.';

  @override
  String get contactsPermPoint3 =>
      'You can turn it off again at any time in Android\'s settings.';

  @override
  String get contactsContinue => 'Continue';

  @override
  String get notNow => 'Not now';

  @override
  String get contactsDenied =>
      'Smile isn\'t allowed to see your contacts yet. You can allow it in the settings.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get searchContact => 'Search contact';

  @override
  String get inSmile => 'In Smile';

  @override
  String get notInSmile => 'Not in Smile yet';

  @override
  String inSmileAs(String name) {
    return 'in Smile: $name';
  }

  @override
  String get contactInvite => 'Invite';

  @override
  String get noContacts => 'No contacts found.';

  @override
  String get contactsOnlySmileHint =>
      'Only people who already have Smile can become co-admin.';

  @override
  String get contactInviteTitle => 'Send an invitation to Smile';

  @override
  String contactInviteText(String name) {
    return '$name doesn\'t have Smile yet. Would you like to send an invitation?';
  }

  @override
  String get contactMessageLabel => 'Message';

  @override
  String get sendSms => 'Send by text message';

  @override
  String get sendWhatsApp => 'Send by WhatsApp';

  @override
  String get sendEmail => 'Send by email';

  @override
  String get sendOther => 'Send with another app';

  @override
  String contactSmsMember(String album, String link) {
    return 'I\'m inviting you to my Smile album $album. We share photos and videos there: $link';
  }

  @override
  String get phoneMobile => 'Mobile';

  @override
  String get phoneHome => 'Home';

  @override
  String get phoneWork => 'Work';

  @override
  String get captionHint => 'Add a caption …';

  @override
  String get tipLabel => 'TIP';

  @override
  String get tipUnderstood => 'Got it';

  @override
  String get tipNoMore => 'No more tips';

  @override
  String get tipsSection => 'Tips';

  @override
  String get tipsShow => 'Show tips';

  @override
  String get tipsShowHint =>
      'Now and then a short hint about what else Smile can do.';

  @override
  String get tipsReset => 'Show tips from the start';

  @override
  String get tipsResetHint => 'The ones you\'ve already seen come back too.';

  @override
  String get tipsResetDone => 'The tips start over.';

  @override
  String get soundsSection => 'Sounds';

  @override
  String get albumSounds => 'Album sounds';

  @override
  String get albumSoundsHint =>
      'A pop when sending and for new photos in the open album. When the phone is silent, Smile stays quiet.';

  @override
  String get tipFrameButton =>
      'A tap on the Frame icon shows this album on the Frame right away. Press and hold to open the remote.';

  @override
  String get tipSlideshow =>
      'The slideshow icon plays the album as a slideshow on this phone, with its own settings.';

  @override
  String get tipCaptionWhenSending =>
      'Every photo can get its own caption. Tap below or swipe to go to the next one.';

  @override
  String get tipCaptionLater =>
      'Here you can add or change a caption afterwards.';

  @override
  String get tipFavoriteHeart =>
      'With the heart you keep a photo as a favorite for the Frame.';

  @override
  String get tipSelectPhotos =>
      'Press and hold a photo: select several, hide or delete them.';

  @override
  String get tipQuickCapture =>
      'The camera icon at the top: take a photo and send it straight to an album.';

  @override
  String get tipInviteWays =>
      'You can invite without email too: by QR code, link or from your contacts.';

  @override
  String get tipSmileName =>
      'With your Smile name and your card, anyone who wants to invite you can find you.';

  @override
  String get tipControlLevel =>
      'The control level decides what can be done on the Frame itself, from Just watch to Full control.';

  @override
  String get tipPlayback =>
      'Under Playback: clock, quiet hours, captions, slow zoom and No videos.';

  @override
  String get tipFavoritesRound =>
      'Favorites play on the Frame as a round of their own, across all albums too.';

  @override
  String get tipNewAlbum => 'You create new albums via ⋮ → New album.';

  @override
  String get tipVideoQuality =>
      'Under Sending videos you choose how much videos are shrunk. That saves data.';

  @override
  String get tipNewsIcon =>
      'When the icon at the top turns coral, an invitation or request is waiting for you.';

  @override
  String get captionDelete => 'Delete caption';

  @override
  String get videoNone => 'No videos';

  @override
  String get undo => 'Undo';

  @override
  String get showOnMyFrame => 'Show on the Frame';

  @override
  String get pickFrameToShow => 'Show on which Frame?';

  @override
  String get rememberFrame => 'Always use this Frame from now on';

  @override
  String get showOnFrameButton => 'Show';

  @override
  String get preferredFrame => 'Preferred Frame';

  @override
  String get preferredFrameAsk => 'Ask every time';

  @override
  String get preferredFrameHint =>
      'A tap on the Frame icon in an album shows it there right away.';

  @override
  String get captionEdit => 'Edit caption';

  @override
  String get captionShort => 'Caption';

  @override
  String get showCaptions => 'Show captions';

  @override
  String get showCaptionsHint =>
      'At the bottom of the picture, if the sender wrote one.';

  @override
  String get allowCaptions => 'Show or hide captions';

  @override
  String get rotateWithDevice => 'Picture turns with the Frame';

  @override
  String get recentCountLabel => 'How many latest photos';

  @override
  String quietPreset(String from, String to) {
    return '$from – $to';
  }

  @override
  String get alsoLabel => 'Also';

  @override
  String get rotateShort => 'Picture turns with it';

  @override
  String get whoWatches => 'Who watches this Frame?';

  @override
  String get watchAll => 'Someone who wants to set everything up themselves';

  @override
  String get watchAllHint => 'All buttons and settings right on the Frame.';

  @override
  String get watchSimple => 'Easy to use';

  @override
  String get watchSimpleHint =>
      'Back, Pause, Next, Newest photos and Favorites.';

  @override
  String get watchOnly => 'Just watch';

  @override
  String get watchOnlyHint =>
      'No buttons. The photos play by themselves, everything comes from the app.';

  @override
  String levelBadge(int n, String name) {
    return 'Level $n · $name';
  }

  @override
  String get whoWatchesLater =>
      'You can change this any time under Frame → ⋮ → Controls.';

  @override
  String get rotateWithDeviceHint =>
      'Upright or sideways, the picture turns with it. Even when auto-rotate is off on the device.';

  @override
  String get homeSlideshowRecent => 'Latest from all albums';

  @override
  String get homeSlideshowRecentHint =>
      'The newest photos and videos, whichever album';

  @override
  String get homeSlideshowRotateHint =>
      'Everything you can see, album by album';

  @override
  String get homeSlideshowOneAlbum => 'One album …';

  @override
  String get homeSlideshowOneAlbumHint => 'Then you choose the album';

  @override
  String get homeSlideshowSettingsHint =>
      'You set duration, order, videos and sound in the slideshow, as before.';

  @override
  String get homeSlideshowStart => 'Start slideshow';

  @override
  String get homeSlideshowPickAlbum => 'Which album?';

  @override
  String get homeSlideshowNothing => 'There are no photos or videos here yet.';

  @override
  String slideshowPosition(int n, int total) {
    return '$n of $total';
  }

  @override
  String get tipAlbums01 =>
      'The album where something happened last is always at the top – like on WhatsApp.';

  @override
  String get tipAlbums02 =>
      'A dot next to an album means there\'s something new you haven\'t seen yet.';

  @override
  String get tipAlbums03 =>
      'Below the album name you see who sent something last.';

  @override
  String get tipAlbums04 =>
      'With the camera at the top right you quickly take a photo and choose the album afterwards.';

  @override
  String get tipAlbums05 => 'You create a new album on your Space\'s page.';

  @override
  String get tipAlbums06 =>
      'An album always belongs to a Space – your family, for example.';

  @override
  String get tipAlbums07 => 'Tap an album\'s picture to open it right away.';

  @override
  String get tipAlbums08 =>
      'An album without photos shows its initials – until the first photo arrives.';

  @override
  String get tipAlbums09 =>
      'Via ⋮ → Scan code you join an album with a QR code.';

  @override
  String get tipAlbums10 =>
      'At the bottom you switch between Albums, Frames and Spaces.';

  @override
  String get tipAlbums11 => 'Pull the list down to refresh it right away.';

  @override
  String get tipAlbums12 =>
      'Other people\'s new photos appear by themselves – you don\'t have to do anything.';

  @override
  String get tipAlbums13 =>
      'Even without internet you see the albums you opened last.';

  @override
  String get tipAlbums14 =>
      'Albums you leave disappear from your list – the others keep them.';

  @override
  String get tipAlbums15 =>
      'An album can play on several Frames at the same time.';

  @override
  String get tipAlbums16 =>
      'The admin can change an album\'s picture at any time.';

  @override
  String get tipAlbums17 =>
      'New albums only move to the top once something happens in them.';

  @override
  String get tipAlbums18 =>
      'Tip: create an album for every occasion – holidays, birthdays, kids.';

  @override
  String get tipAlbums19 =>
      'An album has no size limit – send as many photos as you like.';

  @override
  String get tipAlbum01 =>
      'Your own photos are on the right, everyone else\'s on the left – like in a chat.';

  @override
  String get tipAlbum02 => 'Press and hold a photo to select several.';

  @override
  String get tipAlbum03 => '“Select all” marks all photos at once.';

  @override
  String get tipAlbum04 =>
      'With + at the bottom right you send photos and videos from your gallery.';

  @override
  String get tipAlbum05 =>
      'You can select and send several photos and videos at once.';

  @override
  String get tipAlbum06 => 'When sending, you can give each photo a caption.';

  @override
  String get tipAlbum07 =>
      'You can change a caption later too – in full screen at the top.';

  @override
  String get tipAlbum08 =>
      'Photos are shrunk before sending – that saves time and data.';

  @override
  String get tipAlbum09 =>
      'Videos are shrunk on your phone, so they arrive quickly.';

  @override
  String get tipAlbum10 =>
      'Without internet your photo waits with a small clock and is sent later.';

  @override
  String get tipAlbum11 =>
      'A photo that\'s still waiting can be held back with “Don\'t send”.';

  @override
  String get tipAlbum12 =>
      'Your photos are sent even when you\'ve already closed Smile.';

  @override
  String get tipAlbum13 =>
      'The date at the top shows, while scrolling, which day the photos are from.';

  @override
  String get tipAlbum14 =>
      'Whoever sent a photo is shown next to it with picture and name.';

  @override
  String get tipAlbum15 =>
      '“Hide” makes a photo disappear only for you – the others still see it.';

  @override
  String get tipAlbum16 =>
      'You can bring hidden photos back via ⋮ at any time.';

  @override
  String get tipAlbum17 =>
      '“Delete” removes a photo for everyone – only the sender or the admin may do that.';

  @override
  String get tipAlbum18 => 'Deleted photos stay in the trash for 30 days.';

  @override
  String get tipAlbum19 =>
      'Via ⋮ you start a slideshow of the album right on your phone.';

  @override
  String get tipAlbum20 =>
      'Tap the album name at the top to get to the album\'s info page.';

  @override
  String get tipAlbum21 =>
      'There\'s a short sound when sending and receiving – you can turn it off in the settings.';

  @override
  String get tipAlbum22 => 'Videos show a small icon – tap it to play them.';

  @override
  String get tipAlbum23 =>
      'Videos you\'ve already watched also play without internet.';

  @override
  String get tipAlbum24 =>
      'Other people\'s new photos appear in the open album right away.';

  @override
  String get tipViewer01 =>
      'Swipe left and right to browse through all photos and videos.';

  @override
  String get tipViewer02 => 'Zoom into a photo with two fingers.';

  @override
  String get tipViewer03 =>
      'Double-tap zooms into a photo – double-tap again and it\'s whole again.';

  @override
  String get tipViewer04 =>
      'With the heart at the top you make a photo a favorite of a Frame.';

  @override
  String get tipViewer05 =>
      'With the Frame icon at the top you show the photo on the Frame right away.';

  @override
  String get tipViewer06 =>
      'The bar at the top stays put while swiping – its buttons apply to the photo shown.';

  @override
  String get tipViewer07 =>
      'In full screen you see the whole photo – in the album it\'s sometimes cropped.';

  @override
  String get tipViewer08 =>
      'A caption sits at the bottom of the picture – just like later on the Frame.';

  @override
  String get tipViewer09 => 'Videos only start when you swipe to them.';

  @override
  String get tipViewer10 => 'Tap a video to pause it or let it continue.';

  @override
  String get tipViewer11 =>
      'With the bar at the bottom you jump back and forth in a video.';

  @override
  String get tipViewer12 =>
      'The arrow at the top left takes you back to the album.';

  @override
  String get tipViewer13 => 'Move a zoomed photo around with one finger.';

  @override
  String get tipViewer14 =>
      'You can view photos that are still on their way in full size already.';

  @override
  String get tipViewer15 =>
      'With the caption icon at the top you give a photo a caption afterwards.';

  @override
  String get tipAlbumInfo01 =>
      'Here you see who\'s in the album and who can post.';

  @override
  String get tipAlbumInfo02 =>
      'With “Invite” you bring more people into the album.';

  @override
  String get tipAlbumInfo03 =>
      'With “Share” you show the album to another Space – for viewing.';

  @override
  String get tipAlbumInfo04 =>
      'Shared Spaces see the album but can\'t send anything into it.';

  @override
  String get tipAlbumInfo05 => 'Tap a person to see which role they have.';

  @override
  String get tipAlbumInfo06 => 'The admin can remove people from the album.';

  @override
  String get tipAlbumInfo07 =>
      'Under “Playing on” you see on which Frames the album is playing right now.';

  @override
  String get tipAlbumInfo08 =>
      'With “Show on a Frame” you put the album on a Frame with one tap.';

  @override
  String get tipAlbumInfo09 =>
      'The admin changes the name with a tap on the name.';

  @override
  String get tipAlbumInfo10 =>
      'The album picture can be a photo of your own or one from the album.';

  @override
  String get tipAlbumInfo11 =>
      'You take a shared album of another Space out again with “Remove from …”.';

  @override
  String get tipAlbumInfo12 =>
      'If an album isn\'t yours, removing it keeps it with its owner.';

  @override
  String get tipAlbumInfo13 =>
      '“Leave album” only ends your membership – the album stays.';

  @override
  String get tipAlbumInfo14 =>
      '“Delete album” puts the album in the trash for 30 days.';

  @override
  String get tipAlbumInfo15 =>
      'The admin decides requests to join the album under Activity.';

  @override
  String get tipInvite01 =>
      'People you already know from Smile you simply invite by their name.';

  @override
  String get tipInvite02 =>
      'With a QR code, someone next to you is in the album right away – without asking.';

  @override
  String get tipInvite03 =>
      'You can send an invite link via WhatsApp or text message.';

  @override
  String get tipInvite04 =>
      'A typed code goes to the admin as a request – they decide.';

  @override
  String get tipInvite05 =>
      'With “From contacts” you find people from your phone book who already have Smile.';

  @override
  String get tipInvite06 =>
      'Contacts who don\'t have Smile yet get an invitation by text message or WhatsApp.';

  @override
  String get tipInvite07 => 'An invite code is valid for 24 hours.';

  @override
  String get tipInvite08 => 'A new code makes the old one invalid right away.';

  @override
  String get tipInvite09 =>
      'You can only become co-admin or Frame admin by name or by QR code in person.';

  @override
  String get tipInvite10 =>
      'You can withdraw unanswered invitations at any time.';

  @override
  String get tipInvite11 =>
      'Invited people see your invitation under Activity and decide themselves.';

  @override
  String get tipInvite12 =>
      'With your Smile name (@name) others find you more easily.';

  @override
  String get tipInvite13 =>
      'Under “My card” you show your own QR code for scanning.';

  @override
  String get tipInvite14 => 'Open requests expire by themselves after a while.';

  @override
  String get tipFrames01 =>
      'A Frame is a tablet that shows your albums as a picture frame.';

  @override
  String get tipFrames02 =>
      'The green dot on a Frame\'s picture means the Frame is online right now.';

  @override
  String get tipFrames03 => 'Under “Frames” you see all Frames you manage.';

  @override
  String get tipFrames04 =>
      'You connect a new Frame with a QR code it shows on its first start.';

  @override
  String get tipFrames05 =>
      'A new tablet can replace an old Frame – albums and settings stay.';

  @override
  String get tipFrames06 =>
      'Under “Settings & device” you see the Frame\'s battery, device and last contact.';

  @override
  String get tipFrames07 =>
      'If a Frame is offline for a long time, you get a notification.';

  @override
  String get tipFrames08 =>
      'You can revoke a Frame for a while – and reactivate it later.';

  @override
  String get tipFrames09 =>
      'You change a Frame\'s name and picture under “Settings & device”.';

  @override
  String get tipFrames10 => 'Several albums can play on one Frame.';

  @override
  String get tipFrames11 =>
      '“Manage albums” decides which albums a Frame shows.';

  @override
  String get tipFrames12 =>
      'A Frame also shows albums that are shared with its Space.';

  @override
  String get tipFrames13 =>
      'The Frame keeps all photos – it goes on showing them without internet.';

  @override
  String get tipFrames14 => 'With quiet hours the Frame stays dark at night.';

  @override
  String get tipFrames15 =>
      'Tip: pin the Smile app on the tablet so nobody can leave it by accident.';

  @override
  String get tipFrames16 =>
      'With “Big clock” the Frame shows date and time in large type – handy for Grandma.';

  @override
  String get tipFrames17 =>
      'Whoever sent a photo is shown at the top left of the Frame.';

  @override
  String get tipFrames18 => 'A Frame turns with the tablet – if you set it to.';

  @override
  String get tipFrames19 =>
      'A deleted Frame shows the QR code for connecting again.';

  @override
  String get tipFrame01 =>
      'Tap an album in the strip at the top to show it on the Frame right away.';

  @override
  String get tipFrame02 =>
      '“Playing now” shows what the Frame is playing at this moment.';

  @override
  String get tipFrame03 => 'With the remote you pause the Frame or skip ahead.';

  @override
  String get tipFrame04 =>
      '“Play the newest 20 photos” shows the newest photos of all albums.';

  @override
  String get tipFrame05 =>
      'Favorites are a selection of their own, just for this Frame.';

  @override
  String get tipFrame06 =>
      'Under “See all” you see all of a Frame\'s favorites.';

  @override
  String get tipFrame07 =>
      'With “Video sound” you decide whether videos play with sound on the Frame.';

  @override
  String get tipFrame08 =>
      'The “Control level” tile decides what people can do on the Frame themselves.';

  @override
  String get tipFrame09 =>
      'With “Invite a Frame admin” someone else may run this Frame – a child\'s parents, for example.';

  @override
  String get tipFrame10 =>
      'A Frame admin decides controls and albums – but not the name, device or deleting.';

  @override
  String get tipFrame11 =>
      'Under “Unlock on the Frame” you set a code for the Frame.';

  @override
  String get tipFrame12 =>
      'With the code, the Frame shows all buttons after a long press on the clock.';

  @override
  String get tipFrame13 =>
      'An unlocked Frame locks itself again after 2 minutes without a touch.';

  @override
  String get tipFrame14 =>
      'Without a code nothing can be unlocked on the Frame.';

  @override
  String get tipFrame15 =>
      'The “Frame admin” badge marks Frames you run for someone else.';

  @override
  String get tipControls01 =>
      'Easy Stopping: a tap on the Frame stops the picture, another tap lets it continue.';

  @override
  String get tipControls02 =>
      'A stopped Frame continues by itself after 10 minutes.';

  @override
  String get tipControls03 =>
      'Level 1 “Just watch”: on the Frame, only tapping to stop works.';

  @override
  String get tipControls04 =>
      'Level 2: Pause and a big Next button – ideal to start with.';

  @override
  String get tipControls05 => 'Level 3: plus Back and the newest photos.';

  @override
  String get tipControls06 =>
      'Level 4: plus Overview, Switch album, Display time and captions.';

  @override
  String get tipControls07 =>
      'Level 5: everything can be set up right on the Frame.';

  @override
  String get tipControls08 =>
      'You can also allow buttons one by one – that\'s “Custom”.';

  @override
  String get tipControls09 =>
      'On the Frame, swipe left for the next photo – from level 2.';

  @override
  String get tipControls10 =>
      'Swiping right goes to the previous photo – from level 3.';

  @override
  String get tipControls11 =>
      'With “Keep” a photo becomes a favorite right on the Frame.';

  @override
  String get tipControls12 =>
      'The “Overview” on the Frame shows all photos as tiles to tap.';

  @override
  String get tipControls13 =>
      'With “Album” you switch the album on the Frame yourself.';

  @override
  String get tipControls14 =>
      'The buttons on the Frame disappear by themselves after a few seconds.';

  @override
  String get tipControls15 =>
      'You can change the control level at any time – the Frame follows right away.';

  @override
  String get tipPlayback01 =>
      '“What plays”: one album, all albums in turn, the newest photos or the favorites.';

  @override
  String get tipPlayback02 =>
      'The order: newest first, oldest first or shuffled.';

  @override
  String get tipPlayback03 =>
      'The display time decides how long each photo is shown.';

  @override
  String get tipPlayback04 =>
      'At the end of an album the Frame starts over – or shows the overview.';

  @override
  String get tipPlayback05 =>
      'Videos can play in full, only as long as a photo, or not at all.';

  @override
  String get tipPlayback06 =>
      '“Fill”: photos fill the screen – or are shown whole.';

  @override
  String get tipPlayback07 =>
      '“When it fits” only fills when the photo suits the screen.';

  @override
  String get tipPlayback08 => 'The slow zoom brings the photos to life.';

  @override
  String get tipPlayback09 =>
      '“Show new photos right away”: a new photo appears on the Frame immediately.';

  @override
  String get tipPlayback10 =>
      '“Sound for new photos”: the Frame chimes with three notes.';

  @override
  String get tipPlayback11 =>
      '“Remind until someone looks”: the sound comes back every hour, at most three times.';

  @override
  String get tipPlayback12 =>
      '“Show what\'s new”: a glowing hint stays until someone taps.';

  @override
  String get tipPlayback13 => 'A tap on the hint shows exactly the new photos.';

  @override
  String get tipPlayback14 => 'Quiet hours make the Frame go dark at night.';

  @override
  String get tipPlayback15 =>
      'During quiet hours the Frame stays silent – even for new photos.';

  @override
  String get tipPlayback16 =>
      '“Big clock” shows date and time large on the Frame.';

  @override
  String get tipPlayback17 => '“Show sender” shows who sent a photo.';

  @override
  String get tipPlayback18 => '“Show captions” shows the photos\' captions.';

  @override
  String get tipPlayback19 =>
      '“Picture turns with the Frame” turns the picture even when the tablet otherwise wouldn\'t.';

  @override
  String get tipPlayback20 =>
      'Every change here reaches the Frame in under a second.';

  @override
  String get tipFavorites01 =>
      'Favorites are per Frame – every Frame has its own.';

  @override
  String get tipFavorites02 =>
      'With the heart in full screen you make a photo a favorite.';

  @override
  String get tipFavorites03 =>
      'With several Frames, you choose which Frame the heart is for.';

  @override
  String get tipFavorites04 =>
      'With “Add” you choose several favorites at once.';

  @override
  String get tipFavorites05 =>
      'Favorites can play on the Frame as a round of their own.';

  @override
  String get tipFavorites06 => 'You see in the list who marked a favorite.';

  @override
  String get tipFavorites07 =>
      'A favorite kept on the Frame is listed with “On the Frame”.';

  @override
  String get tipFavorites08 =>
      'Via ⋮ you remove all of a Frame\'s favorites at once.';

  @override
  String get tipFavorites09 =>
      'When “Favorites” is set, the button on the Frame has a frame around it.';

  @override
  String get tipSpaces01 =>
      'A Space is your household or family – with albums and Frames.';

  @override
  String get tipSpaces02 => 'Every Space has an admin who may do everything.';

  @override
  String get tipSpaces03 =>
      'Co-admins help manage the Space – albums, Frames and people.';

  @override
  String get tipSpaces04 => 'With “Invite a co-admin” you get help managing.';

  @override
  String get tipSpaces05 => 'The admin can hand the role over to a co-admin.';

  @override
  String get tipSpaces06 =>
      'A co-admin can give up the role themselves at any time.';

  @override
  String get tipSpaces07 => 'Only the admin can delete a Space.';

  @override
  String get tipSpaces08 => 'A deleted Space stays in the trash for 30 days.';

  @override
  String get tipSpaces09 =>
      'You can be in several Spaces – yours and your parents\', for example.';

  @override
  String get tipSpaces10 =>
      'A Space can get albums of another Space for viewing.';

  @override
  String get tipSpaces11 => 'Every Space can have its own picture.';

  @override
  String get tipSpaces12 => 'You create new albums in a Space.';

  @override
  String get tipSpaces13 => 'You connect new Frames through a Space.';

  @override
  String get tipSpaces14 =>
      'Whoever manages a Space is automatically in all its albums.';

  @override
  String get tipSpaces15 =>
      'The admin changes the Space\'s name with a tap on it.';

  @override
  String get tipNews01 =>
      'Under Activity you find invitations, requests and all notifications of the last 30 days.';

  @override
  String get tipNews02 =>
      'A red dot on Activity means something is waiting for your answer.';

  @override
  String get tipNews03 => 'You accept invitations here – or decline them.';

  @override
  String get tipNews04 => 'As admin, you decide requests to join here.';

  @override
  String get tipNews05 => 'The trash is next to Activity.';

  @override
  String get tipNews06 =>
      'From the trash you get deleted things back for 30 days.';

  @override
  String get tipNews07 => 'After 30 days the trash empties itself.';

  @override
  String get tipNews08 =>
      'Tap a notification to go straight to the album or Frame.';

  @override
  String get tipNews09 =>
      'Notifications you swiped away can be found here again too.';

  @override
  String get tipNews10 =>
      'Many new photos from the same person come as one notification.';

  @override
  String get tipSettings01 =>
      'Your name is required – so everyone knows who a photo is from.';

  @override
  String get tipSettings02 =>
      'Without a picture of your own, Smile shows your initials.';

  @override
  String get tipSettings03 => 'Tap your picture to change it.';

  @override
  String get tipSettings04 =>
      'Under “Smile name” you choose an @name others can find you by.';

  @override
  String get tipSettings05 =>
      '“My card” shows your QR code – others scan it to invite you.';

  @override
  String get tipSettings06 =>
      'Under “Album sounds” you turn the pop sounds on or off.';

  @override
  String get tipSettings07 => 'When your phone is silent, Smile stays quiet.';

  @override
  String get tipSettings08 =>
      'Under “Sending videos” you choose how much videos are shrunk.';

  @override
  String get tipSettings09 =>
      '“Show tips from the start” brings all tips back.';

  @override
  String get tipSettings10 =>
      '“No more tips” turns all tips off – turn them back on here.';

  @override
  String get tipSettings11 =>
      'Notifications come for new photos, invitations and changes to your Frames.';

  @override
  String get tipSettings12 =>
      'You can delete your account in the settings – with everything that\'s yours.';

  @override
  String get tipSettings13 =>
      'You can sign out at any time – your albums stay on the server.';

  @override
  String get tipSettings14 =>
      'Smile signs you in with a code by email – no password at all.';

  @override
  String get tipSettings15 =>
      'Smile is dark by design – that\'s how photos shine the most.';

  @override
  String get tipGeneral01 =>
      'Smile is like WhatsApp for photos – just without the chat and with a picture frame.';

  @override
  String get tipGeneral02 =>
      'Everything you change, the others see right away.';

  @override
  String get tipGeneral03 =>
      'Smile works offline too – changes are sent later.';

  @override
  String get tipGeneral04 =>
      'Photos in Smile are private – only an album\'s members see them.';

  @override
  String get tipGeneral05 =>
      'Whoever leaves an album no longer sees its photos.';

  @override
  String get tipGeneral06 =>
      'Pressing and holding opens more options almost everywhere.';

  @override
  String get tipGeneral07 =>
      'The ⋮ at the top right has more functions on every page.';

  @override
  String get tipGeneral08 => 'Pulling down refreshes almost every list.';

  @override
  String get tipGeneral09 => 'A tap on a name or a picture usually shows more.';

  @override
  String get tipGeneral10 =>
      'Smile only sends photos and videos – no messages.';

  @override
  String get tipGeneral11 =>
      'An album isn\'t a one-to-one chat: it can always take in more people.';

  @override
  String get tipGeneral12 =>
      'A Frame doesn\'t need an account of its own – it\'s connected with a code.';

  @override
  String get tipGeneral13 => 'Photos are transferred encrypted.';

  @override
  String membershipRequestFailed(String reason) {
    return 'Request failed: $reason';
  }

  @override
  String withdrawFailed(String reason) {
    return 'Couldn\'t withdraw: $reason';
  }

  @override
  String get deleteFailedShort => 'Couldn\'t delete.';

  @override
  String get hideFailedShort => 'Couldn\'t hide.';

  @override
  String get unhideFailedShort => 'Couldn\'t unhide.';

  @override
  String photosNotDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos couldn\'t be deleted (not your own).',
      one: '1 photo couldn\'t be deleted (not your own).',
    );
    return '$_temp0';
  }

  @override
  String photosNotPossible(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Not possible for $count photos.',
      one: 'Not possible for 1 photo.',
    );
    return '$_temp0';
  }

  @override
  String get loginIntro =>
      'Sign in with your email address. We\'ll send you a 6-digit code.';

  @override
  String get loginRequestCode => 'Get code';

  @override
  String loginCodeSent(String email) {
    return 'We sent a code to $email. Please enter it.';
  }

  @override
  String get loginConfirm => 'Confirm';

  @override
  String get loginOtherEmail => 'Use a different email address';

  @override
  String avatarUploadFailed(String reason) {
    return 'Couldn\'t upload the picture: $reason';
  }

  @override
  String get enterYourName => 'Please enter your name.';

  @override
  String saveFailedWith(String reason) {
    return 'Couldn\'t save: $reason';
  }

  @override
  String get avatarUrlInvalid => 'That isn\'t a valid web address.';

  @override
  String get avatarUrlUnreachable =>
      'Couldn\'t load the picture. Please check the address.';

  @override
  String get avatarUrlNotImage => 'The address doesn\'t point to a picture.';

  @override
  String get notificationChannelDescription =>
      'New photos, invitations, requests and changes in your albums and Spaces';

  @override
  String get errUserNotFound =>
      'This person doesn\'t have a Smile account yet.';

  @override
  String get errNotAlbumManager => 'You\'re not allowed to manage this album.';

  @override
  String get errRequestPending =>
      'There\'s already an open invitation or request.';

  @override
  String get errNotSpaceAdmin => 'Only the admin can do that.';

  @override
  String get errAlreadyAdmin => 'This person is already the admin.';

  @override
  String get errAlreadyCoAdmin => 'This person is already a co-admin.';

  @override
  String get errInvitePending => 'There\'s already an open invitation.';

  @override
  String get errNotCoAdmin => 'This person isn\'t a co-admin.';

  @override
  String get errGeneric => 'That didn\'t work. Please try again.';

  @override
  String get noLongerAvailable =>
      'That\'s no longer available – deleted or no access anymore.';

  @override
  String get dateToday => 'Today';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours hrs ago';
  }

  @override
  String get dateNumericPattern => 'MMM d, yyyy';

  @override
  String get dateNumericShortPattern => 'M/d/yy';

  @override
  String get licenseOther => 'License';

  @override
  String get language => 'Language';

  @override
  String get languageAutomatic => 'Automatic';

  @override
  String languageAutomaticValue(String language) {
    return 'Automatic ($language)';
  }

  @override
  String languageLikePhone(String language) {
    return 'Like the phone: $language';
  }

  @override
  String get languageSheetHint =>
      'Applies to the app and the notifications you get.';

  @override
  String get frameLanguage => 'Language on the Frame';

  @override
  String get frameLanguageLikeTablet => 'Like the tablet';
}
