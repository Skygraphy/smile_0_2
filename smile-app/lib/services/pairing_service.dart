import '../main.dart';

/// Calls claim-device-pairing (see supabase/functions) to bind a Frame,
/// identified by the code shown on its screen, to a Space the current user
/// owns (concept doc sect. 14-16).
class PairingService {
  /// [replaceDeviceId], when set, carries the old Frame's channel
  /// assignments, policy, and photo backlog over to this newly paired one
  /// (see migrations/0023_replace_device_on_pairing.sql) -- without it, a
  /// re-paired Frame starts from a completely blank slate.
  Future<void> claimDevicePairing({
    required String code,
    required String spaceId,
    String? replaceDeviceId,
  }) async {
    final response = await supabase.functions.invoke(
      'claim-device-pairing',
      body: {'code': code, 'space_id': spaceId, 'replace_device_id': ?replaceDeviceId},
    );
    final data = response.data as Map<String, dynamic>?;
    if (data == null || data['status'] != 'claimed') {
      throw PairingClaimException(data?['error'] as String? ?? 'unknown_error');
    }
  }
}

class PairingClaimException implements Exception {
  PairingClaimException(this.code);

  final String code;

  String get message => switch (code) {
        'invalid_code' => 'Ungültiger Code.',
        'code_expired' => 'Der Code ist abgelaufen.',
        'code_already_used' || 'code_already_claimed' => 'Dieser Code wurde bereits verwendet.',
        'not_space_owner' => 'Du bist nicht berechtigt, diesem Space ein Frame hinzuzufügen.',
        'replace_device_id_not_in_space' => 'Das zu ersetzende Gerät gehört nicht zu diesem Space.',
        _ => 'Koppeln fehlgeschlagen.',
      };

  @override
  String toString() => 'PairingClaimException($code)';
}
