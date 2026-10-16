import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class EmailAuthScreen extends StatefulWidget {
  final bool startSignUp;
  final bool startPasswordReset;
  final String? initialEmail;

  const EmailAuthScreen({
    super.key,
    this.startSignUp = false,
    this.startPasswordReset = false,
    this.initialEmail,
  });

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _otp = TextEditingController();
  final _newPassword = TextEditingController();

  bool _isSignUp = false;
  bool _resetMode = false;
  int _resetStep = 0;
  int _resendSeconds = 0;
  bool _busy = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _termsAccepted = true;
  String? _resetToken;
  Timer? _resendTimer;
  Timer? _loginLockTimer;
  int _loginWaitSeconds = 0;

  @override
  void initState() {
    super.initState();
    _email.text = widget.initialEmail ?? '';
    _isSignUp = widget.startSignUp;
    _resetMode = widget.startPasswordReset;
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _loginLockTimer?.cancel();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _otp.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (!_isSignUp) return null;
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Enter your full name.';
    if (name.length < 2) return 'Name is too short.';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final pass = value ?? '';
    if (pass.isEmpty) return 'Enter your password.';
    if (_isSignUp && pass.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (!_isSignUp) return null;
    if (value == null || value.isEmpty) return 'Confirm your password.';
    if (value != _password.text) return 'Passwords do not match.';
    return null;
  }

  int _calculatePasswordStrength(String pass) {
    if (pass.isEmpty) return 0;
    int score = 0;
    if (pass.length >= 6) score++;
    if (pass.length >= 8) score++;
    if (RegExp(r'[A-Za-z]').hasMatch(pass) && RegExp(r'[0-9]').hasMatch(pass)) {
      score++;
    }
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pass)) score++;
    return score;
  }

  Future<void> _signUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_termsAccepted) {
      _showError('Please agree to the Terms & Privacy Policy to continue.');
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await AuthService().signUpWithEmailPassword(
        email: _email.text.trim(),
        password: _password.text,
        displayName: _name.text.trim(),
      );
      await ApiService().clearLoginFailures();
      if (!mounted) return;
      if (result['profile_complete'] == true) {
        context.go(AppRoutes.home);
      } else {
        context.go(AppRoutes.authConfirm, extra: result);
      }
    } catch (error) {
      _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final wait = await ApiService().checkLoginWaitSeconds(_email.text.trim());
      if (wait > 0) {
        _startLoginLock(wait);
        return;
      }
      final result = await AuthService().signInWithEmailPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      await ApiService().clearLoginFailures();
      if (!mounted) return;
      if (result['profile_complete'] == true) {
        context.go(AppRoutes.home);
      } else {
        context.go(AppRoutes.authConfirm, extra: result);
      }
    } catch (error) {
      if (error is FirebaseAuthException) {
        try {
          final wait = await ApiService().recordLoginFailure(_email.text.trim());
          if (wait > 0) {
            _startLoginLock(wait);
          } else {
            _showError(_friendlyError(error));
          }
        } catch (protectionError) {
          _showError(_friendlyError(protectionError));
        }
      } else {
        _showError(_friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startLoginLock(int seconds) {
    _loginLockTimer?.cancel();
    setState(() => _loginWaitSeconds = seconds);
    _loginLockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_loginWaitSeconds <= 1) {
        timer.cancel();
        setState(() => _loginWaitSeconds = 0);
      } else {
        setState(() => _loginWaitSeconds--);
      }
    });
  }

  Future<void> _requestOtp({bool isResend = false}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ApiService().requestPasswordResetOtp(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _resetMode = true;
        _resetStep = 1;
        _otp.clear();
      });
      _startResendCooldown();
      if (!isResend) {
        _showInfo('If your account exists, a 6-digit code is on its way.');
      }
    } catch (error) {
      _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _verifyOtp() async {
    final code = _otp.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showError('Enter the 6-digit code from your email.');
      return;
    }
    setState(() => _busy = true);
    try {
      final token = await ApiService().verifyPasswordResetOtp(
        email: _email.text.trim(),
        otp: code,
      );
      if (!mounted) return;
      setState(() {
        _resetToken = token;
        _resetStep = 2;
      });
    } catch (error) {
      _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeReset() async {
    if (_resetToken == null) {
      _showError('Your reset session expired. Request a new code.');
      _restartReset();
      return;
    }
    if (_newPassword.text.length < 8) {
      _showError('Use at least 8 characters for your new password.');
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      _showError('The passwords do not match.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ApiService().completePasswordReset(
        resetToken: _resetToken!,
        password: _newPassword.text,
      );
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.email?.toLowerCase() ==
          _email.text.trim().toLowerCase()) {
        await AuthService().signOut();
      }
      if (!mounted) return;
      _showInfo('Password updated. Sign in with your new password.');
      context.go(AppRoutes.emailLogin);
    } catch (error) {
      _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startReset() {
    setState(() {
      _resetMode = true;
      _resetStep = 0;
    });
  }

  void _restartReset() {
    setState(() {
      _resetToken = null;
      _resetStep = 0;
      _newPassword.clear();
      _confirmPassword.clear();
    });
  }

  void _backToSignIn() {
    _resendTimer?.cancel();
    setState(() {
      _resetMode = false;
      _resetStep = 0;
      _resetToken = null;
      _resendSeconds = 0;
      _otp.clear();
      _newPassword.clear();
      _confirmPassword.clear();
    });
  }

  String _friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'An account already exists with this email. Try logging in instead.';
        case 'weak-password':
          return 'Password is too weak. Please use at least 8 characters with letters & numbers.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Email or password is incorrect. If you joined with Google, set a password from Profile → Settings first.';
        case 'too-many-requests':
          return 'Too many attempts. Wait a little and try again.';
        case 'network-request-failed':
          return 'Network issue. Check your connection and try again.';
        case 'user-disabled':
          return 'This account is disabled. Contact CampusSetu support.';
        case 'operation-not-allowed':
          return 'Email/password authentication is not enabled in Firebase yet.';
      }
    }
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is String) {
        return data['error'] as String;
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Could not reach CampusSetu. Check your connection and try again.';
      }
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReset = _resetMode;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          onPressed: () =>
              isReset ? _backToSignIn() : context.go(AppRoutes.welcome),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          isReset
              ? 'Reset password'
              : (_isSignUp ? 'Create Account' : 'Email sign in'),
          style: AppTypography.soraHeading3(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Mode Toggle (Sign Up vs Sign In) when not resetting password
                    if (!isReset) ...[
                      _buildAuthModeSegment(),
                      const SizedBox(height: 16),
                    ],

                    // Info Header Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cyanDeep.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.cyanDeep.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isReset
                                ? Icons.lock_reset_rounded
                                : (_isSignUp
                                    ? Icons.person_add_alt_1_rounded
                                    : Icons.lock_outline_rounded),
                            color: AppColors.cyanDeep,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isReset
                                  ? 'Verify your email, then choose a new password.'
                                  : (_isSignUp
                                      ? 'Create your CampusSetu student account with your college or personal email.'
                                      : 'Sign in to your existing CampusSetu account with email and password.'),
                              style: AppTypography.interBody(
                                color: AppColors.ink,
                                size: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Dynamic Fields based on mode
                    if (!isReset && _isSignUp) ..._signUpFields(),
                    if (!isReset && !_isSignUp) ..._signInFields(),
                    if (isReset) ..._resetFields(),

                    // Sign In specific extras
                    if (!isReset && !_isSignUp) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : _startReset,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _primaryButton(
                        label: 'Sign in',
                        icon: Icons.login_rounded,
                        onPressed:
                            _busy || _loginWaitSeconds > 0 ? null : _signIn,
                      ),
                      if (_loginWaitSeconds > 0) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Too many attempts. Try again in ' +
                              (_loginWaitSeconds ~/ 60)
                                  .toString()
                                  .padLeft(2, '0') +
                              ':' +
                              (_loginWaitSeconds % 60)
                                  .toString()
                                  .padLeft(2, '0') +
                              '.',
                          textAlign: TextAlign.center,
                          style: AppTypography.interBody(
                            color: AppColors.error,
                            size: 13,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: AppTypography.interBodySmall(
                                color: AppColors.inkSoft),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() => _isSignUp = true),
                            child: const Text('Sign up here',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed:
                            _busy ? null : () => context.go(AppRoutes.welcome),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Back to Welcome Screen'),
                      ),
                    ],

                    // Sign Up specific extras
                    if (!isReset && _isSignUp) ...[
                      const SizedBox(height: 12),
                      // Terms agreement checkbox
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _termsAccepted,
                              onChanged: _busy
                                  ? null
                                  : (v) => setState(
                                      () => _termsAccepted = v ?? true),
                              activeColor: AppColors.cyanDeep,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(
                                  () => _termsAccepted = !_termsAccepted),
                              child: Text(
                                'I agree to CampusSetu Terms of Service & Privacy Policy',
                                style: AppTypography.interCaption(
                                    color: AppColors.inkSoft),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _primaryButton(
                        label: 'Create Account',
                        icon: Icons.person_add_rounded,
                        onPressed: _busy ? null : _signUp,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already registered?',
                            style: AppTypography.interBodySmall(
                                color: AppColors.inkSoft),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() => _isSignUp = false),
                            child: const Text('Sign In here',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed:
                            _busy ? null : () => context.go(AppRoutes.welcome),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Back to Welcome Screen'),
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

  Widget _buildAuthModeSegment() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.isDark
            ? AppColors.darkTile
            : Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _busy ? null : () => setState(() => _isSignUp = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: !_isSignUp
                      ? (AppColors.isDark ? AppColors.darkTileAlt : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !_isSignUp ? AppColors.neuSmallShadows : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Sign In',
                  style: TextStyle(
                    fontWeight: !_isSignUp ? FontWeight.w700 : FontWeight.w500,
                    color: !_isSignUp ? AppColors.cyanDeep : AppColors.inkSoft,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _busy ? null : () => setState(() => _isSignUp = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _isSignUp
                      ? (AppColors.isDark ? AppColors.darkTileAlt : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _isSignUp ? AppColors.neuSmallShadows : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Sign Up',
                  style: TextStyle(
                    fontWeight: _isSignUp ? FontWeight.w700 : FontWeight.w500,
                    color: _isSignUp ? AppColors.cyanDeep : AppColors.inkSoft,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _signInFields() => [
        _emailField(),
        const SizedBox(height: 14),
        TextFormField(
          controller: _password,
          obscureText: !_showPassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _signIn(),
          validator: _validatePassword,
          decoration:
              _decoration('Password', Icons.lock_outline_rounded).copyWith(
            suffixIcon: IconButton(
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon:
                  Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
            ),
          ),
        ),
      ];

  List<Widget> _signUpFields() {
    final strength = _calculatePasswordStrength(_password.text);
    return [
      TextFormField(
        controller: _name,
        keyboardType: TextInputType.name,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.name],
        validator: _validateName,
        decoration: _decoration('Full Name', Icons.person_outline_rounded),
      ),
      const SizedBox(height: 14),
      _emailField(),
      const SizedBox(height: 14),
      TextFormField(
        controller: _password,
        obscureText: !_showPassword,
        textInputAction: TextInputAction.next,
        onChanged: (_) => setState(() {}),
        validator: _validatePassword,
        decoration: _decoration('Password (min. 8 characters)',
                Icons.lock_outline_rounded)
            .copyWith(
          suffixIcon: IconButton(
            onPressed: () => setState(() => _showPassword = !_showPassword),
            icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
          ),
        ),
      ),
      if (_password.text.isNotEmpty) ...[
        const SizedBox(height: 6),
        _buildPasswordStrengthBar(strength),
      ],
      const SizedBox(height: 14),
      TextFormField(
        controller: _confirmPassword,
        obscureText: !_showConfirmPassword,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _signUp(),
        validator: _validateConfirmPassword,
        decoration: _decoration(
                'Confirm Password', Icons.lock_reset_rounded)
            .copyWith(
          suffixIcon: IconButton(
            onPressed: () => setState(
                () => _showConfirmPassword = !_showConfirmPassword),
            icon: Icon(_showConfirmPassword
                ? Icons.visibility_off
                : Icons.visibility),
          ),
        ),
      ),
    ];
  }

  Widget _buildPasswordStrengthBar(int score) {
    Color color;
    String label;
    if (score <= 1) {
      color = AppColors.error;
      label = 'Weak';
    } else if (score == 2) {
      color = AppColors.warning;
      label = 'Fair';
    } else if (score == 3) {
      color = AppColors.warning;
      label = 'Good';
    } else {
      color = AppColors.success;
      label = 'Strong';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (index) {
            final active = index < score;
            return Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: active
                      ? color
                      : (AppColors.isDark ? Colors.white12 : Colors.black12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Strength: $label',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
            Text(
              'Min 8 chars, mix letters & numbers',
              style: AppTypography.interCaption(color: AppColors.inkSoft),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _resetFields() => [
        _emailField(readOnly: _resetStep > 0),
        const SizedBox(height: 14),
        if (_resetStep == 0) ...[
          Text('We’ll email you a one-time 6-digit code.',
              style: AppTypography.interCaption(color: AppColors.inkSoft)),
          const SizedBox(height: 18),
          _primaryButton(
            label: 'Send verification code',
            icon: Icons.mark_email_read_outlined,
            onPressed: _busy ? null : () => _requestOtp(),
          ),
        ],
        if (_resetStep == 1) ...[
          TextFormField(
            controller: _otp,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: _decoration('6-digit code', Icons.password_rounded)
                .copyWith(counterText: ''),
          ),
          const SizedBox(height: 12),
          _primaryButton(
            label: 'Verify code',
            icon: Icons.verified_user_outlined,
            onPressed: _busy ? null : _verifyOtp,
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              TextButton(
                onPressed: _resendSeconds == 0 && !_busy
                    ? () => _requestOtp(isResend: true)
                    : null,
                child: Text(_resendSeconds == 0
                    ? 'Resend code'
                    : 'Resend in ${_resendSeconds}s'),
              ),
              TextButton(
                onPressed: _busy ? null : _restartReset,
                child: const Text('Change email'),
              ),
            ],
          ),
        ],
        if (_resetStep == 2) ...[
          TextFormField(
            controller: _newPassword,
            obscureText: !_showPassword,
            decoration: _decoration('New password', Icons.lock_outline_rounded),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPassword,
            obscureText: !_showPassword,
            textInputAction: TextInputAction.done,
            decoration:
                _decoration('Confirm new password', Icons.lock_reset_rounded),
          ),
          const SizedBox(height: 8),
          Text('Use at least 8 characters.',
              style: AppTypography.interCaption(color: AppColors.inkSoft)),
          const SizedBox(height: 16),
          _primaryButton(
            label: 'Update password',
            icon: Icons.check_rounded,
            onPressed: _busy ? null : _completeReset,
          ),
        ],
      ];

  Widget _emailField({bool readOnly = false}) => TextFormField(
        controller: _email,
        readOnly: readOnly,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
        validator: _validateEmail,
        decoration: _decoration('Email address', Icons.email_outlined),
      );

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppColors.isDark ? AppColors.darkTile : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) =>
      SizedBox(
        height: 52,
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.cyanDeep,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(icon, color: Colors.white),
          label: Text(
            _busy ? 'Please wait…' : label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
}
