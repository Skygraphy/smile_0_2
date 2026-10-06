import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

/// The body an Edge Function answered with -- also when it answered with an
/// error status.
class EdgeResponse {
  const EdgeResponse(this.data);

  final dynamic data;
}

/// Calls an Edge Function like `supabase.functions.invoke`, but an error
/// answer (4xx/5xx with `{"error": "<code>"}`) comes back as data instead
/// of an exception. Every service checks `data['error']` and turns the
/// code into a readable German message ("Diese Person hat noch keinen
/// Smile-Account."); the current supabase client throws first, which put
/// raw "FunctionsHttpException(... user_not_found ...)" text on screen
/// (found in the 2026-10-06 walkthrough). Network failures still throw.
Future<EdgeResponse> invokeEdge(String name, {Object? body}) async {
  try {
    final response = await supabase.functions.invoke(name, body: body);
    return EdgeResponse(response.data);
  } on FunctionException catch (e) {
    final details = e.details;
    if (e.status > 0 && details is Map && details['error'] is String) {
      return EdgeResponse(Map<String, dynamic>.from(details));
    }
    rethrow;
  }
}
