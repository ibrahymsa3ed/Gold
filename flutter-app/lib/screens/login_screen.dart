import 'package:flutter/material.dart';

import '../l10n.dart';
import '../services/auth_service.dart';
import '../theme/app_themes.dart';
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

  static const _gold = Color(0xFFD4AF37);
  static const _goldLight = Color(0xFFE8CD5A);
  static const _goldDeep = Color(0xFFC9A227);
  static const _darkBg = Color(0xFF0B0B0D);
  static const _inputFill = Color(0xFF1A1816);
  static const _inputBorder = Color(0xFF3A3428);
  static const _textMuted = Color(0xFF9E9688);

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

  InputDecoration _goldInputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textMuted, fontSize: 15),
      prefixIcon: Icon(icon, size: 20, color: _gold.withValues(alpha: 0.7)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _inputBorder, width: 0.8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _inputBorder, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _gold, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumBackground(
      forceDark: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 260,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF2A2210).withValues(alpha: 0.6),
                      const Color(0xFF1A1508).withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SelectionContainer.disabled(
                              child: IgLogo(
                                  size: 180, applyLightModeTone: false),
                            ),
                            const SizedBox(height: 16),
                            SelectionContainer.disabled(
                              child: Text(
                                'InstaGold',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                  color: const Color(0xFFF1E6D3),
                                  height: 1,
                                  shadows: [
                                    Shadow(
                                      color: _gold.withValues(alpha: 0.15),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 48),

                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                  color: Color(0xFFE8E0D0), fontSize: 15),
                              decoration: _goldInputDecoration(
                                label: AppStrings.t(context, 'email'),
                                icon: Icons.email_outlined,
                              ),
                            ),
                            const SizedBox(height: 16),

                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              style: const TextStyle(
                                  color: Color(0xFFE8E0D0), fontSize: 15),
                              onSubmitted: _isLoading
                                  ? null
                                  : (_) => _run(() =>
                                      widget.authService.signInEmailPassword(
                                        _emailController.text.trim(),
                                        _passwordController.text.trim(),
                                      )),
                              decoration: _goldInputDecoration(
                                label: AppStrings.t(context, 'password'),
                                icon: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: _textMuted,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),

                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: TextButton(
                                onPressed:
                                    _isLoading ? null : _sendPasswordReset,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  AppStrings.t(context, 'forgot_password'),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          _gold.withValues(alpha: 0.8)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      _goldLight,
                                      _gold,
                                      _goldDeep,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _gold.withValues(alpha: 0.25),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _isLoading
                                        ? null
                                        : () => _run(() => widget.authService
                                                .signInEmailPassword(
                                              _emailController.text.trim(),
                                              _passwordController.text.trim(),
                                            )),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Center(
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: _darkBg,
                                              ),
                                            )
                                          : Text(
                                              AppStrings.t(
                                                  context, 'login'),
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700,
                                                color: _darkBg,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => _run(() =>
                                        widget.authService
                                            .signUpEmailPassword(
                                          _emailController.text.trim(),
                                          _passwordController.text.trim(),
                                        )),
                                style: TextButton.styleFrom(
                                  foregroundColor: _gold,
                                  textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                                child:
                                    Text(AppStrings.t(context, 'signup')),
                              ),
                            ),

                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : () => _run(
                                        widget.authService.signInWithGoogle),
                                icon: const Icon(Icons.g_mobiledata,
                                    size: 24, color: Colors.white),
                                label: Text(
                                  Localizations.localeOf(context)
                                              .languageCode ==
                                          'ar'
                                      ? 'تسجيل الدخول بـ Google'
                                      : 'Continue with Google',
                                  style: const TextStyle(
                                      color: Color(0xFFE8E0D0),
                                      fontSize: 15),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color:
                                          _gold.withValues(alpha: 0.25),
                                      width: 0.8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                ),
                              ),
                            ),

                            if (_successMessage != null) ...[
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF388E3C)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF388E3C)
                                        .withValues(alpha: 0.3),
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
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFD32F2F)
                                        .withValues(alpha: 0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.error_outline,
                                            color: Color(0xFFD32F2F),
                                            size: 20),
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
                                        alignment:
                                            AlignmentDirectional.centerEnd,
                                        child: TextButton.icon(
                                          onPressed: _isLoading
                                              ? null
                                              : _sendPasswordReset,
                                          icon: const Icon(
                                              Icons.email_outlined,
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
                              const SizedBox(height: 32),
                              Divider(
                                  color: _gold.withValues(alpha: 0.12)),
                              const SizedBox(height: 8),
                              Text(
                                'Dev Mode (backend BYPASS_AUTH=true)',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _textMuted
                                        .withValues(alpha: 0.6)),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : widget.onDevBypass,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                        color: _gold
                                            .withValues(alpha: 0.2),
                                        width: 0.8),
                                    foregroundColor: _gold,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                  child: const Text('Enter as Dev User'),
                                ),
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
          ],
        ),
      ),
    );
  }
}
