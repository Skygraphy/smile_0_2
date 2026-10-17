import 'package:flutter/material.dart' show Icons, IconData;

/// The one place that maps Smile concepts to icons (decided with the user
/// 2026-10-05, see the smile-ui-backlog memory). Screens only ever use
/// these semantic names, never Material `Icons` directly, so an icon can
/// change in exactly one spot.
///
/// Glyphs come from the Phosphor Icons 2.1 fonts bundled in this package
/// (code points = Phosphor's own, identical in Regular and Fill). Weight
/// is Regular throughout; the `*Filled` variants exist only for the
/// selected tab in the bottom navigation bar.
class SmileIcons {
  SmileIcons._();

  static const _pkg = 'smile_design_system';

  // --- Objects ---------------------------------------------------------
  /// Phosphor `squares-four`.
  static const IconData space = IconData(0xe464, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData spaceFilled = IconData(0xe464, fontFamily: 'PhosphorFill', fontPackage: _pkg);

  /// Phosphor `images-square`.
  static const IconData album = IconData(0xe834, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData albumFilled = IconData(0xe834, fontFamily: 'PhosphorFill', fontPackage: _pkg);

  /// Phosphor `frame-corners`.
  static const IconData frame = IconData(0xe626, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData frameFilled = IconData(0xe626, fontFamily: 'PhosphorFill', fontPackage: _pkg);

  /// Phosphor `user`: a person (others) and the own profile share it.
  static const IconData person = IconData(0xe4c2, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData personFilled = IconData(0xe4c2, fontFamily: 'PhosphorFill', fontPackage: _pkg);

  // --- Roles and relations ---------------------------------------------
  /// Phosphor `key`.
  static const IconData admin = IconData(0xe2d6, fontFamily: 'PhosphorRegular', fontPackage: _pkg);

  /// Phosphor `user-gear`.
  static const IconData coAdmin = IconData(0xe4cc, fontFamily: 'PhosphorRegular', fontPackage: _pkg);

  /// Phosphor `pencil-simple`.
  static const IconData member = IconData(0xe3b4, fontFamily: 'PhosphorRegular', fontPackage: _pkg);

  /// Phosphor `binoculars`.
  static const IconData viewer = IconData(0xea64, fontFamily: 'PhosphorRegular', fontPackage: _pkg);

  /// Phosphor `link-simple`: "Shared with `Space`", also the share action.
  static const IconData shared = IconData(0xe2e6, fontFamily: 'PhosphorRegular', fontPackage: _pkg);

  // --- Navigation ------------------------------------------------------
  /// Phosphor `notification`: "Neuigkeiten" (invitations, join requests,
  /// trash). No counter: the icon is tinted coral while something waits.
  static const IconData news = IconData(0xe6fa, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData back = IconData(0xe058, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  /// The three dots: Material's `more_vert` -- Phosphor's dots were too
  /// thin next to WhatsApp's (user, 2026-10-13).
  static const IconData more = Icons.more_vert;
  static const IconData chevron = IconData(0xe13a, fontFamily: 'PhosphorRegular', fontPackage: _pkg);

  // --- Actions (same icon for the same action everywhere) --------------
  static const IconData invite = IconData(0xe4d0, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData share = shared;
  static const IconData add = IconData(0xe3d4, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData remove = IconData(0xe4ce, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData leave = IconData(0xe42a, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData delete = IconData(0xe4a6, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData trash = delete;
  static const IconData restore = IconData(0xe038, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData handOver = IconData(0xe0a0, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData inviteCode = IconData(0xe3e6, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData camera = IconData(0xe10e, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  /// Phosphor `video-camera`: record a video in an album.
  static const IconData recordVideo = IconData(0xe4da, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  /// Phosphor `wifi-slash`: no connection (the offline hint).
  static const IconData offline = IconData(0xe4f2, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  /// Phosphor `selection-all`: mark every photo of an album.
  static const IconData selectAll = IconData(0xe746, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  /// Phosphor `speaker-high` / `speaker-slash`: a Frame's video sound.
  static const IconData soundOn = IconData(0xe44a, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData soundOff = IconData(0xe45a, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  /// Phosphor `gear-six`: a Frame's settings and device page.
  static const IconData settings = IconData(0xe272, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  /// Phosphor `scan`: scan an invite's QR code (Neuigkeiten).
  static const IconData scan = IconData(0xebb6, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  /// Phosphor `share-network`: send an invite code as a message.
  static const IconData shareOut = IconData(0xe408, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  /// Phosphor `magnifying-glass`: search by name.
  static const IconData search = IconData(0xe30c, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  /// Phosphor `clock`: a photo/video waiting for a connection to be sent.
  static const IconData waiting = IconData(0xe19a, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  /// Phosphor `paper-plane-right`: send a photo just taken.
  static const IconData send = IconData(0xe396, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  /// Pick an existing picture (avatar from the gallery) -- deliberately
  /// not the album icon, which means "a Smile album".
  static const IconData picture = IconData(0xe2ca, fontFamily: 'PhosphorRegular', fontPackage: _pkg);

  /// Load a picture from a web address -- not the link icon, which means
  /// "Shared with".
  static const IconData web = IconData(0xe288, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData email = IconData(0xe218, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData close = IconData(0xe4f6, fontFamily: 'PhosphorRegular', fontPackage: _pkg);

  /// Accept a request / invitation.
  static const IconData accept = IconData(0xe182, fontFamily: 'PhosphorRegular', fontPackage: _pkg);

  /// Personal hide/unhide of a photo (Ausblenden / Einblenden) and the
  /// "Ausgeblendete Fotos" view.
  static const IconData hide = IconData(0xe224, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData unhide = IconData(0xe220, fontFamily: 'PhosphorRegular', fontPackage: _pkg);

  /// Waiting for someone else (a sent request).
  static const IconData pending = IconData(0xe2b8, fontFamily: 'PhosphorRegular', fontPackage: _pkg);

  // --- Smile-Frame -----------------------------------------------------
  /// Switch the Frame between slideshow and the tile overview.
  static const IconData overview = IconData(0xe1fc, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  /// Phosphor `slideshow` (images with arrows) -- chosen by the user 2026-10-17
  /// instead of the play triangle.
  static const IconData slideshow = IconData(0xed32, fontFamily: 'PhosphorRegular', fontPackage: _pkg);

  /// "More to choose from here" (the album switcher on the Frame).
  static const IconData switchAlbum = IconData(0xe140, fontFamily: 'PhosphorRegular', fontPackage: _pkg);

  // --- Media overlays (filled, drawn on top of photos) -----------------
  static const IconData play = IconData(0xe3d2, fontFamily: 'PhosphorFill', fontPackage: _pkg);
  static const IconData selected = IconData(0xe184, fontFamily: 'PhosphorFill', fontPackage: _pkg);

  // --- Frame controls and remote (2026-10-14) ---------------------------
  static const IconData previous = IconData(0xe138, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData nextItem = IconData(0xe13a, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData pause = IconData(0xe39e, fontFamily: 'PhosphorFill', fontPackage: _pkg);
  static const IconData playFilled = IconData(0xe3d0, fontFamily: 'PhosphorFill', fontPackage: _pkg);
  /// "Neueste Fotos".
  static const IconData newest = IconData(0xe6a2, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  /// Display time per photo.
  static const IconData timer = IconData(0xe492, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData shuffle = IconData(0xe422, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData repeat = IconData(0xe3f6, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  /// Nachtruhe.
  static const IconData night = IconData(0xe58e, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  /// "Bedienung am Frame".
  static const IconData controls = IconData(0xe298, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  /// "Wiedergabe".
  static const IconData playback = IconData(0xe434, fontFamily: 'PhosphorRegular', fontPackage: _pkg);

  /// Lieblingsbilder (2026-10-14): outline = not marked, filled = marked.
  static const IconData heart = IconData(0xe2a8, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData heartFilled = IconData(0xe2a8, fontFamily: 'PhosphorFill', fontPackage: _pkg);

  /// Smile-Name (@name) and the personal card (2026-10-17).
  static const IconData handle = IconData(0xe0ac, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData card = IconData(0xe2c8, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
}
