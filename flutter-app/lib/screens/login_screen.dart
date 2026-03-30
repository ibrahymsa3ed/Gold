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

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      setState(() => _error = _cleanErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                      decoration: InputDecoration(labelText: AppStrings.t(context, 'email')),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(labelText: AppStrings.t(context, 'password')),
                    ),
                    const SizedBox(height: 12),
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
                            child: const Text('Sign up'),
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
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => _run(widget.authService.signInWithApple),
                      icon: const Icon(Icons.apple),
                      label: Text(AppStrings.t(context, 'apple_sign_in')),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
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
