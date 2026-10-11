import '../main.dart';
import 'avatar_upload.dart';
import 'edge_functions.dart';
import 'local_changes.dart';
import 'sync_bus.dart';

/// Someone the caller already shares an album or a Space with -- the "per
/// Name" list when inviting (migrations/0073 known_people()).
class KnownPerson {
  const KnownPerson({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.context,
    this.managesASpace = false,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  /// Where one knows them from: an album or a Space name.
  final String? context;
  final bool managesASpace;
}

/// What an invite code is for (create-invite-code).
enum InviteKind {
  albumMember('album_member'),
  albumShare('album_share'),
  spaceCoOwner('space_co_owner');

  const InviteKind(this.wire);
  final String wire;
}

class InviteCode {
  const InviteCode({required this.code, required this.expiresAt, required this.targetName});

  final String code;
  final DateTime expiresAt;
  final String targetName;

  /// As shown and typed: K7P-2QX.
  String get pretty => '${code.substring(0, 3)}-${code.substring(3)}';

  /// What the QR code holds -- only Smile's own scanner understands it.
  String get qrData => 'smile:invite:$code';
}

/// The outcome of redeeming a code (redeem-invite-code).
class RedeemResult {
  const RedeemResult({
    required this.status,
    this.kind,
    this.channelId,
    this.channelName,
    this.spaceId,
    this.spaceName,
    this.spaces = const [],
  });

  /// joined / requested / needs_space / already_member / already_shared /
  /// already_co_owner.
  final String status;
  final String? kind;
  final String? channelId;
  final String? channelName;
  final String? spaceId;
  final String? spaceName;
  /// needs_space: the caller's Spaces to choose from.
  final List<({String id, String name})> spaces;
}

/// A refused code: invalid_code / expired_code / qr_only / no_space / ...
class InviteException implements Exception {
  const InviteException(this.code);
  final String code;

  @override
  String toString() => 'InviteException($code)';
}

/// Inviting by name and by QR code (decided 2026-10-11).
class InviteService {
  Future<List<KnownPerson>> knownPeople() async {
    final rows = await supabase.rpc('known_people') as List;
    return rows
        .cast<Map<String, dynamic>>()
        .map((r) => KnownPerson(
              userId: r['user_id'] as String,
              name: r['display_name'] as String,
              avatarUrl: avatarPathToUrl(r['avatar_path'] as String?),
              context: r['context'] as String?,
              managesASpace: r['manages_a_space'] == true,
            ))
        .toList();
  }

  /// The active code for this target (the same again until [renew]).
  Future<InviteCode> createCode(InviteKind kind, String targetId, {bool renew = false}) async {
    final response = await invokeEdge('create-invite-code', body: {
      'kind': kind.wire,
      'target_id': targetId,
      if (renew) 'renew': true,
    });
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw InviteException(data['error'] as String);
    return InviteCode(
      code: data['code'] as String,
      expiresAt: DateTime.parse(data['expires_at'] as String),
      targetName: data['target_name'] as String? ?? '',
    );
  }

  /// [viaQr]: scanned in person (in at once); typed: the admins decide.
  Future<RedeemResult> redeem(String code, {required bool viaQr, String? spaceId}) async {
    final response = await invokeEdge('redeem-invite-code', body: {
      'code': code,
      'via': viaQr ? 'qr' : 'typed',
      'space_id': ?spaceId,
    });
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw InviteException(data['error'] as String);
    final result = RedeemResult(
      status: data['status'] as String,
      kind: data['kind'] as String?,
      channelId: data['channel_id'] as String?,
      channelName: data['channel_name'] as String?,
      spaceId: data['space_id'] as String?,
      spaceName: data['space_name'] as String?,
      spaces: [
        for (final s in (data['spaces'] as List? ?? const []).cast<Map<String, dynamic>>())
          (id: s['id'] as String, name: s['name'] as String),
      ],
    );
    // Albums, Spaces, Neuigkeiten -- whatever it changed shows at once.
    LocalChanges.saved(const SyncEvent.everything());
    return result;
  }
}
