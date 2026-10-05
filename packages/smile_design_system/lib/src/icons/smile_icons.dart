import 'package:flutter/widgets.dart';

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
  static const IconData more = IconData(0xe208, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
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
  static const IconData close = IconData(0xe4f6, fontFamily: 'PhosphorRegular', fontPackage: _pkg);

  /// Accept a request / invitation.
  static const IconData accept = IconData(0xe182, fontFamily: 'PhosphorRegular', fontPackage: _pkg);

  /// Personal hide/unhide of a photo (Ausblenden / Einblenden) and the
  /// "Ausgeblendete Fotos" view.
  static const IconData hide = IconData(0xe224, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const IconData unhide = IconData(0xe220, fontFamily: 'PhosphorRegular', fontPackage: _pkg);

  /// Waiting for someone else (a sent request).
  static const IconData pending = IconData(0xe2b8, fontFamily: 'PhosphorRegular', fontPackage: _pkg);

  // --- Media overlays (filled, drawn on top of photos) -----------------
  static const IconData play = IconData(0xe3d2, fontFamily: 'PhosphorFill', fontPackage: _pkg);
  static const IconData selected = IconData(0xe184, fontFamily: 'PhosphorFill', fontPackage: _pkg);
}
