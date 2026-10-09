import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smile_app/services/offline.dart';

// Offline is shown as a quiet hint, a real refusal still as an error
// (2026-10-09) -- so the two must be told apart.
void main() {
  test('missing connection is recognized', () {
    expect(Offline.isConnectionError(const SocketException('Failed host lookup: example.supabase.co')), isTrue);
    expect(Offline.isConnectionError(TimeoutException('slow')), isTrue);
    expect(Offline.isConnectionError(Exception('ClientException with SocketException: Network is unreachable')), isTrue);
  });

  test('a refusal by the server is not offline', () {
    expect(Offline.isConnectionError(Exception('PostgrestException(message: permission denied, code: 42501)')), isFalse);
  });

  test('the hint follows the last request', () {
    Offline.noteFailure(const SocketException('offline'));
    expect(Offline.isOffline.value, isTrue);
    Offline.reachedServer();
    expect(Offline.isOffline.value, isFalse);
  });
}
