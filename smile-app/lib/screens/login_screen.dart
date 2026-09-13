import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../widgets/otp_code_field.dart';
import '../widgets/smile_mark.dart';
import '../widgets/smile_wordmark.dart';

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

  Future<void> _requestCode() async {
    if (_email.isEmpty) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await supabase.auth.signInWithOtp(email: _email);
      if (!mounted) return;
      setState(() => _step = _LoginStep.enterCode);
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
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
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
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
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                              textAlign: TextAlign.center,
                            ),
                          ],
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
