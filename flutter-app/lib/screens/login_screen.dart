import 'package:flutter/material.dart';

import '../l10n.dart';
import '../services/auth_service.dart';
import '../widgets/ig_logo.dart';
import '../widgets/premium_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authService, this.onDevBypass});
  final AuthService authService;
  final VoidCallback? onDevBypass;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;
  bool _showResetOption = false;
  String? _successMessage;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final goldAccent =
        isDark ? const Color(0xFFD4B254) : const Color(0xFFB5973F);

    return PremiumBackground(
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF7F2E8), Color(0xFFF0E9D8)],
                  ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SelectionContainer.disabled(
                            child: IgLogo(size: 144),
                          ),
                          const SizedBox(height: 24),
                          const SelectionContainer.disabled(
                            child: InstaGoldWordmark(fontSize: 36),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            Localizations.localeOf(context).languageCode == 'ar'
                                ? 'تتبع أسعار الذهب وإدارة أصول العائلة'
                                : 'Track gold prices & manage family assets',
                            style: TextStyle(
                              fontSize: 15,
                              color: cs.onSurfaceVariant,
                              letterSpacing: 0.1,
                            ),
                          ),

                          const SizedBox(height: 40),

                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: AppStrings.t(context, 'email'),
                              prefixIcon: Icon(Icons.email_outlined,
                                  size: 20, color: cs.onSurfaceVariant),
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: _isLoading
                                ? null
                                : (_) => _run(() =>
                                    widget.authService.signInEmailPassword(
                                      _emailController.text.trim(),
                                      _passwordController.text.trim(),
                                    )),
                            decoration: InputDecoration(
                              labelText: AppStrings.t(context, 'password'),
                              prefixIcon: Icon(Icons.lock_outline,
                                  size: 20, color: cs.onSurfaceVariant),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Forgot password
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              onPressed: _isLoading ? null : _sendPasswordReset,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                AppStrings.t(context, 'forgot_password'),
                                style:
                                    TextStyle(fontSize: 13, color: cs.primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Login button (primary)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => _run(() =>
                                      widget.authService.signInEmailPassword(
                                        _emailController.text.trim(),
                                        _passwordController.text.trim(),
                                      )),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(AppStrings.t(context, 'login')),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Sign up button (secondary)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => _run(() =>
                                      widget.authService.signUpEmailPassword(
                                        _emailController.text.trim(),
                                        _passwordController.text.trim(),
                                      )),
                              child: Text(AppStrings.t(context, 'signup')),
                            ),
                          ),

                          const SizedBox(height: 24),

                          Row(
                            children: [
                              Expanded(
                                  child: Divider(
                                      color:
                                          goldAccent.withValues(alpha: 0.15))),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 18),
                                child: Text(
                                  Localizations.localeOf(context)
                                              .languageCode ==
                                          'ar'
                                      ? 'أو'
                                      : 'or',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: cs.onSurfaceVariant),
                                ),
                              ),
                              Expanded(
                                  child: Divider(
                                      color:
                                          goldAccent.withValues(alpha: 0.15))),
                            ],
                          ),

                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () =>
                                      _run(widget.authService.signInWithGoogle),
                              icon: Icon(Icons.g_mobiledata,
                                  size: 24,
                                  color: isDark ? Colors.white : null),
                              label:
                                  Text(AppStrings.t(context, 'google_sign_in')),
                            ),
                          ),

                          if (_successMessage != null) ...[
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF388E3C)
                                    .withValues(alpha: isDark ? 0.15 : 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF388E3C)
                                      .withValues(alpha: isDark ? 0.3 : 0.2),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline,
                                      color: Color(0xFF388E3C), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _successMessage!,
                                      style: const TextStyle(
                                          color: Color(0xFF388E3C),
                                          fontSize: 13,
                                          height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (_error != null) ...[
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD32F2F)
                                    .withValues(alpha: isDark ? 0.15 : 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFD32F2F)
                                      .withValues(alpha: isDark ? 0.3 : 0.2),
                                  width: 0.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: Color(0xFFD32F2F), size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                              color: Color(0xFFD32F2F),
                                              fontSize: 13,
                                              height: 1.4),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_showResetOption) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: AlignmentDirectional.centerEnd,
                                      child: TextButton.icon(
                                        onPressed: _isLoading
                                            ? null
                                            : _sendPasswordReset,
                                        icon: const Icon(Icons.email_outlined,
                                            size: 16),
                                        label: Text(AppStrings.t(
                                            context, 'reset_password')),
                                        style: TextButton.styleFrom(
                                            foregroundColor:
                                                const Color(0xFFD32F2F)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],

                          if (widget.onDevBypass != null) ...[
                            const SizedBox(height: 24),
                            Divider(color: goldAccent.withValues(alpha: 0.15)),
                            const SizedBox(height: 8),
                            Text(
                              'Dev Mode (backend BYPASS_AUTH=true)',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.6)),
                            ),
                            const SizedBox(height: 8),
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
          ),
        ),
      ),
    );
  }
}
