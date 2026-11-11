import '../main.dart';
import 'edge_functions.dart';

/// A Space's Frame plan right now (2026-11-11, migrations/0102), as the
/// server decides it: free, trial, or a plan from a voucher / Google Play.
class SpacePlan {
  SpacePlan(Map<String, dynamic> d)
      : status = d['status'] as String? ?? 'none',
        source = d['source'] as String?,
        frames = (d['frames'] as num?)?.toInt() ?? 0,
        framesUsed = (d['frames_used'] as num?)?.toInt() ?? 0,
        endsAt = DateTime.tryParse(d['ends_at'] as String? ?? '')?.toLocal(),
        endedAt = DateTime.tryParse(d['ended_at'] as String? ?? '')?.toLocal(),
        trialUsed = d['trial_used'] as bool? ?? true,
        storageBytes = (d['storage_bytes'] as num?)?.toInt() ?? 0,
        usedBytes = (d['used_bytes'] as num?)?.toInt() ?? 0,
        videoSeconds = (d['video_seconds'] as num?)?.toInt() ?? 120,
        photos = (d['photos'] as num?)?.toInt() ?? 0,
        videos = (d['videos'] as num?)?.toInt() ?? 0,
        coveredFrames = {for (final id in (d['covered_frames'] as List? ?? const [])) id as String};

  /// 'none', 'trial' or 'active'.
  final String status;

  /// 'trial', 'voucher', 'play', 'staff'.
  final String? source;
  final int frames;
  final int framesUsed;
  final DateTime? endsAt;
  final DateTime? endedAt;

  /// false: never had a Frame yet -- the trial starts with the first one.
  final bool trialUsed;
  final int storageBytes;
  final int usedBytes;
  final int videoSeconds;
  final int photos;
  final int videos;

  /// The Frames that get new photos (the first paired ones).
  final Set<String> coveredFrames;

  bool get isTrial => status == 'trial';
  bool get isActive => status == 'active';
  bool get isNone => status == 'none';
}

/// What redeeming a voucher gave.
class VoucherResult {
  VoucherResult(Map<String, dynamic> d)
      : frames = (d['frames'] as num).toInt(),
        startsAt = DateTime.parse(d['starts_at'] as String).toLocal(),
        endsAt = DateTime.parse(d['ends_at'] as String).toLocal(),
        from = d['from'] as String?;

  final int frames;
  final DateTime startsAt;
  final DateTime endsAt;

  /// The giver's name printed on the card ("Ein Geschenk von …"), if any.
  final String? from;

  /// Starts later -- after what the Space already has.
  bool get startsLater => startsAt.isAfter(DateTime.now().add(const Duration(minutes: 5)));
}

class VoucherException implements Exception {
  VoucherException(this.code);

  /// not_found, already_used, expired, blocked, rate_limited,
  /// not_space_manager, or something unexpected.
  final String code;

  @override
  String toString() => 'VoucherException($code)';
}

class PlanService {
  /// Only for the Space's Admin and Co-Admins; null for anyone else.
  Future<SpacePlan?> load(String spaceId) async {
    final data = await supabase.rpc('space_plan', params: {'p_space': spaceId});
    if (data is! Map) return null;
    return SpacePlan(data.cast<String, dynamic>());
  }

  Future<VoucherResult> redeem(String code, String spaceId) async {
    final response = await invokeEdge('redeem-voucher', body: {'code': code, 'space_id': spaceId});
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw VoucherException(data['error'] as String);
    return VoucherResult(data);
  }

  /// The Spaces this person manages (Admin or Co-Admin): id -> name.
  Future<Map<String, String>> managedSpaces() async {
    final me = supabase.auth.currentUser?.id;
    if (me == null) return const {};
    final results = await Future.wait([
      supabase.from('spaces').select('id, name').eq('owner_id', me).isFilter('deleted_at', null),
      supabase.from('space_co_owners').select('spaces(id, name, deleted_at)').eq('user_id', me),
    ]);
    final out = <String, String>{};
    for (final r in results[0] as List) {
      out[r['id'] as String] = r['name'] as String;
    }
    for (final r in results[1] as List) {
      final s = r['spaces'] as Map<String, dynamic>?;
      if (s != null && s['deleted_at'] == null) out[s['id'] as String] = s['name'] as String;
    }
    return out;
  }
}
