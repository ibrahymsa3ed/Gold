import 'package:flutter/material.dart';

import '../l10n.dart';
import '../services/auth_service.dart';
import '../widgets/ig_logo.dart';
import '../widgets/premium_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
    this.onGuestLogin,
  });
  final AuthService authService;
  final VoidCallback? onGuestLogin;

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

  void _showSignUpDialog() {
    final signUpEmail = TextEditingController();
    final signUpPassword = TextEditingController();
    final signUpConfirm = TextEditingController();
    bool obscure1 = true;
    bool obscure2 = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          String? dialogError;

          Future<void> doSignUp() async {
            final email = signUpEmail.text.trim();
            final pass = signUpPassword.text.trim();
            final confirm = signUpConfirm.text.trim();

            if (email.isEmpty || pass.isEmpty) {
              setDialogState(() => dialogError = 'Please fill all fields.');
              return;
            }
            if (pass != confirm) {
              setDialogState(() => dialogError = 'Passwords do not match.');
              return;
            }
            if (pass.length < 6) {
              setDialogState(
                  () => dialogError = 'Password must be at least 6 characters.');
              return;
            }

            Navigator.of(ctx).pop();
            _run(() => widget.authService.signUpEmailPassword(email, pass));
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1816),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(
              AppStrings.t(ctx, 'signup'),
              style: const TextStyle(
                color: Color(0xFFF1E6D3),
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: signUpEmail,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(
                        color: Color(0xFFE8E0D0), fontSize: 15),
                    decoration: _goldInputDecoration(
                      label: AppStrings.t(ctx, 'email'),
                      icon: Icons.email_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: signUpPassword,
                    obscureText: obscure1,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(
                        color: Color(0xFFE8E0D0), fontSize: 15),
                    decoration: _goldInputDecoration(
                      label: AppStrings.t(ctx, 'password'),
                      icon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setDialogState(() => obscure1 = !obscure1),
                        icon: Icon(
                          obscure1
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: _textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: signUpConfirm,
                    obscureText: obscure2,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(
                        color: Color(0xFFE8E0D0), fontSize: 15),
                    onSubmitted: (_) => doSignUp(),
                    decoration: _goldInputDecoration(
                      label: Localizations.localeOf(ctx).languageCode == 'ar'
                          ? 'تأكيد كلمة المرور'
                          : 'Confirm Password',
                      icon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setDialogState(() => obscure2 = !obscure2),
                        icon: Icon(
                          obscure2
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: _textMuted,
                        ),
                      ),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      dialogError!,
                      style: const TextStyle(
                          color: Color(0xFFD32F2F), fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(foregroundColor: _textMuted),
                child: Text(
                  Localizations.localeOf(ctx).languageCode == 'ar'
                      ? 'إلغاء'
                      : 'Cancel',
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_goldLight, _gold, _goldDeep],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: doSignUp,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Text(
                        AppStrings.t(ctx, 'signup'),
                        style: const TextStyle(
                          color: _darkBg,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

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
                                      color: _gold.withValues(alpha: 0.8)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Login button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [_goldLight, _gold, _goldDeep],
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
                                              AppStrings.t(context, 'login'),
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

                            // Sign Up button — opens popup
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: TextButton(
                                onPressed:
                                    _isLoading ? null : _showSignUpDialog,
                                style: TextButton.styleFrom(
                                  foregroundColor: _gold,
                                  textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                                child: Text(AppStrings.t(context, 'signup')),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Continue with Google
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
                                  isAr
                                      ? 'تسجيل الدخول بـ Google'
                                      : 'Continue with Google',
                                  style: const TextStyle(
                                      color: Color(0xFFE8E0D0),
                                      fontSize: 15),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: _gold.withValues(alpha: 0.25),
                                      width: 0.8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Login as Guest
                            if (widget.onGuestLogin != null)
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OutlinedButton.icon(
                                  onPressed:
                                      _isLoading ? null : widget.onGuestLogin,
                                  icon: Icon(Icons.person_outline,
                                      size: 20,
                                      color:
                                          _textMuted.withValues(alpha: 0.8)),
                                  label: Text(
                                    isAr
                                        ? 'الدخول كضيف'
                                        : 'Login as Guest',
                                    style: TextStyle(
                                        color:
                                            _textMuted.withValues(alpha: 0.9),
                                        fontSize: 15),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                        color: _textMuted
                                            .withValues(alpha: 0.2),
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
