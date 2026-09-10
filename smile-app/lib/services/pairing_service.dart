import '../main.dart';

/// Calls claim-device-pairing (see supabase/functions) to bind a Frame,
/// identified by the code shown on its screen, to a Space the current user
/// owns (concept doc sect. 14-16).
class PairingService {
  Future<void> claimDevicePairing({required String code, required String spaceId}) async {
    final response = await supabase.functions.invoke(
      'claim-device-pairing',
      body: {'code': code, 'space_id': spaceId},
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
        _ => 'Koppeln fehlgeschlagen.',
      };

  @override
  String toString() => 'PairingClaimException($code)';
}
