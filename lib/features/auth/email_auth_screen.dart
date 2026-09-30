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
  final bool startPasswordReset;
  final String? initialEmail;

  const EmailAuthScreen({
    super.key,
    this.startPasswordReset = false,
    this.initialEmail,
  });

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _resetMode = false;
  int _resetStep = 0;
  int _resendSeconds = 0;
  bool _busy = false;
  bool _showPassword = false;
  String? _resetToken;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _email.text = widget.initialEmail ?? '';
    _resetMode = widget.startPasswordReset;
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final result = await AuthService().signInWithEmailPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
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
        _showInfo('If your account exists, a 4-digit code is on its way.');
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
    if (!RegExp(r'^[1-9]{4}$').hasMatch(code)) {
      _showError('Enter the 4-digit code from your email.');
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
          return 'Email/password sign-in is not enabled in Firebase yet.';
      }
    }
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is String)
        return data['error'] as String;
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
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success),
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
        title: Text(isReset ? 'Reset password' : 'Email sign in',
            style: AppTypography.soraHeading3()),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.cyanDeep.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.cyanDeep.withValues(alpha: 0.22)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.lock_outline_rounded,
                            color: AppColors.cyanDeep, size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isReset
                                ? 'Verify your email, then choose a new password.'
                                : 'Sign in to your existing CampusSetu account with email and password.',
                            style: AppTypography.interBody(
                                color: AppColors.ink, size: 14),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 22),
                    if (!isReset) ..._signInFields(),
                    if (isReset) ..._resetFields(),
                    if (!isReset) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : _startReset,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _primaryButton(
                        label: 'Sign in',
                        icon: Icons.login_rounded,
                        onPressed: _busy ? null : _signIn,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Google accounts can add email sign-in from Profile → Settings → Password.',
                        textAlign: TextAlign.center,
                        style: AppTypography.interCaption(
                            color: AppColors.inkSoft),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed:
                            _busy ? null : () => context.go(AppRoutes.welcome),
                        icon: const Icon(Icons.account_circle_outlined),
                        label: const Text('Continue with Google instead'),
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

  List<Widget> _signInFields() => [
        _emailField(),
        const SizedBox(height: 14),
        TextFormField(
          controller: _password,
          obscureText: !_showPassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _signIn(),
          validator: (value) =>
              (value == null || value.isEmpty) ? 'Enter your password.' : null,
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

  List<Widget> _resetFields() => [
        _emailField(readOnly: _resetStep > 0),
        const SizedBox(height: 14),
        if (_resetStep == 0) ...[
          Text('We’ll email you a one-time 4-digit code.',
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
            maxLength: 4,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[1-9]')),
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: _decoration('4-digit code', Icons.password_rounded)
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
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon),
          label: Text(_busy ? 'Please wait…' : label),
        ),
      );
}
