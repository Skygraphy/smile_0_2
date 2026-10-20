import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../services/offline.dart';
import '../services/test_media.dart' show smileTestMode;
import '../widgets/otp_code_field.dart';
import '../frame/frame.dart' as frame;
import 'package:smile_design_system/smile_design_system.dart';

/// Passwordless Email-OTP login (concept doc sect. 4): request a 6-digit
/// code by email, then verify it. On success, AuthGate's own
/// onAuthStateChange listener navigates away -- this screen never navigates
/// itself.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginStep { enterEmail, enterCode }

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  _LoginStep _step = _LoginStep.enterEmail;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();

  /// Written like an address: something@something.domain (2026-10-20,
  /// test suite finds 7 and 8). Whether the mailbox exists only the mail
  /// itself can tell.
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  Future<void> _requestCode() async {
    final t = SmileTexts.of(context);
    if (_email.isEmpty || !_emailPattern.hasMatch(_email)) {
      setState(() => _errorMessage = _email.isEmpty ? t.loginEmailMissing : t.loginEmailInvalid);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      // The test app sends no mail: the test tools make the code with the
      // testsuite project's admin access (2026-10-19).
      if (!smileTestMode) await supabase.auth.signInWithOtp(email: _email);
      if (!mounted) return;
      setState(() => _step = _LoginStep.enterCode);
    } catch (e) {
      // Never the server's own (English) text (2026-10-11).
      debugPrint('SmileLogin: $e');
      if (mounted) {
        final t = SmileTexts.of(context);
        setState(() => _errorMessage = Offline.isConnectionError(e) ? t.noConnectionReason : t.loginSendFailed);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await supabase.auth.verifyOTP(
        type: OtpType.email,
        email: _email,
        token: code,
      );
      // AuthGate's onAuthStateChange listener handles navigation from here.
    } catch (e) {
      debugPrint('SmileLogin: $e');
      if (mounted) {
        final t = SmileTexts.of(context);
        setState(() => _errorMessage = Offline.isConnectionError(e) ? t.noConnectionReason : t.loginCodeWrong);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // A LayoutBuilder + minHeight ConstrainedBox keeps the form
        // centered when it fits, but lets it scroll instead of
        // overflowing once the on-screen keyboard shrinks the available
        // height (hit in practice once the logo/wordmark made this
        // screen taller -- a plain Center+Column can't scroll at all).
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: SmileMark(size: 56)),
                          const SizedBox(height: 12),
                          const Center(child: SmileWordmark(fontSize: 32)),
                          const SizedBox(height: 32),
                          if (_step == _LoginStep.enterEmail) ..._buildEmailStep(),
                          if (_step == _LoginStep.enterCode) ..._buildCodeStep(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The message right under the field, above the button: visible with
  /// the keyboard open (2026-10-20; at the bottom it was hidden behind it).
  List<Widget> _error() {
    final message = _errorMessage;
    if (message == null) return const [];
    final color = Theme.of(context).colorScheme.error;
    return [
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(SmileIcons.warning, size: 18, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13.5))),
        ],
      ),
    ];
  }

  /// Typing again clears the message.
  void _clearError() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_clearError);
    _codeController.addListener(_clearError);
  }

  List<Widget> _buildEmailStep() {
    return [
      Text(
        'Melde dich mit deiner E-Mail-Adresse an. Wir senden dir einen 6-stelligen Code.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(labelText: 'E-Mail-Adresse'),
        onSubmitted: (_) => _requestCode(),
      ),
      ..._error(),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: _isSubmitting ? null : _requestCode,
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Code anfordern'),
      ),
      const SizedBox(height: 32),
      // One app (2026-10-11): an old tablet becomes a Frame from here.
      OutlinedButton.icon(
        onPressed: _isSubmitting
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => frame.PairingScreen())),
        icon: const Icon(SmileIcons.frame),
        label: Text(SmileTexts.of(context).useAsFrame),
      ),
    ];
  }

  List<Widget> _buildCodeStep() {
    return [
      Text(
        'Wir haben einen Code an $_email gesendet. Bitte gib ihn ein.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      Center(
        child: OtpCodeField(
          controller: _codeController,
          autofocus: true,
          onCompleted: (_) => _verifyCode(),
          onSubmitted: (_) => _verifyCode(),
        ),
      ),
      ..._error(),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: _isSubmitting ? null : _verifyCode,
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Bestätigen'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _isSubmitting
            ? null
            : () => setState(() {
                  _step = _LoginStep.enterEmail;
                  _codeController.clear();
                  _errorMessage = null;
                }),
        child: const Text('Andere E-Mail-Adresse verwenden'),
      ),
    ];
  }
}
