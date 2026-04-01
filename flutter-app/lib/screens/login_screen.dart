import 'package:flutter/material.dart';

import '../l10n.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authService, this.onDevBypass});
  final AuthService authService;
  final VoidCallback? onDevBypass;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _showResetOption = false;
  String? _successMessage;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
      _showResetOption = false;
    });
    try {
      await action();
    } on Exception catch (e) {
      final msg = _cleanErrorMessage(e);
      setState(() {
        _error = msg;
        _showResetOption = _isEmailAlreadyInUse(e);
      });
    } catch (e) {
      setState(() => _error = _cleanErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isEmailAlreadyInUse(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('email-already-in-use') ||
        msg.contains('already registered') ||
        msg.contains('مسجل مسبقاً');
  }

  String _cleanErrorMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.toLowerCase() == 'error') {
      return 'Firebase Auth is not set up. Go to Firebase Console > Authentication > Get started to enable sign-in providers.';
    }
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length).trim();
    }
    return raw;
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email first.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });
    try {
      await widget.authService.sendPasswordReset(email);
      setState(() {
        _successMessage = AppStrings.t(context, 'reset_password_sent');
        _showResetOption = false;
      });
    } catch (e) {
      setState(() => _error = _cleanErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.t(context, 'login'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: AppStrings.t(context, 'email')),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(labelText: AppStrings.t(context, 'password')),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: _isLoading ? null : _sendPasswordReset,
                        child: Text(
                          AppStrings.t(context, 'forgot_password'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () => _run(() => widget.authService.signInEmailPassword(
                                      _emailController.text.trim(),
                                      _passwordController.text.trim(),
                                    )),
                            child: Text(AppStrings.t(context, 'login')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading
                                ? null
                                : () => _run(() => widget.authService.signUpEmailPassword(
                                      _emailController.text.trim(),
                                      _passwordController.text.trim(),
                                    )),
                            child: Text(AppStrings.t(context, 'signup')),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => _run(widget.authService.signInWithGoogle),
                      icon: const Icon(Icons.login),
                      label: Text(AppStrings.t(context, 'google_sign_in')),
                    ),
                    if (_successMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_successMessage!, style: const TextStyle(color: Colors.green, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                            if (_showResetOption) ...[
                              const SizedBox(height: 6),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton.icon(
                                  onPressed: _isLoading ? null : _sendPasswordReset,
                                  icon: const Icon(Icons.email, size: 16),
                                  label: Text(AppStrings.t(context, 'reset_password')),
                                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (widget.onDevBypass != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 4),
                      Text(
                        'Dev Mode (backend BYPASS_AUTH=true)',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 4),
                      FilledButton.tonal(
                        onPressed: _isLoading ? null : widget.onDevBypass,
                        child: const Text('Enter as Dev User'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
