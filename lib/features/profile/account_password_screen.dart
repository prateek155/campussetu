import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class AccountPasswordScreen extends StatefulWidget {
  const AccountPasswordScreen({super.key});

  @override
  State<AccountPasswordScreen> createState() => _AccountPasswordScreenState();
}

class _AccountPasswordScreenState extends State<AccountPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hasPassword = AuthService().hasEmailPasswordProvider;
  bool _showPassword = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _setPassword() async {
    if (_busy) return;
    if (_password.text.length < 8) {
      _message('Use at least 8 characters for your password.');
      return;
    }
    if (_password.text != _confirm.text) {
      _message('The passwords do not match.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService().setPasswordForCurrentAccount(_password.text);
      if (!mounted) return;
      setState(() {
        _hasPassword = true;
        _password.clear();
        _confirm.clear();
      });
      _message(
          'Password set. Google and email sign-in now use the same account.');
    } on FirebaseAuthException catch (error) {
      _message(_firebaseError(error));
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _firebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'weak-password':
        return 'Choose a stronger password with at least 8 characters.';
      case 'requires-recent-login':
        return 'Sign out, sign in with Google again, then set your password.';
      case 'network-request-failed':
        return 'Network issue. Check your connection and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase yet.';
      case 'credential-already-in-use':
      case 'email-already-in-use':
        return 'This email belongs to another account. No new profile was created.';
      default:
        return error.message ?? 'Could not set the password. Please try again.';
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Password & sign-in', style: AppTypography.soraHeading3()),
        backgroundColor: AppColors.bg,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.isDark ? AppColors.darkTile : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.inkMuted.withValues(alpha: 0.28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_user_outlined,
                          color: AppColors.cyanDeep, size: 30),
                      const SizedBox(height: 12),
                      Text('Your sign-in email',
                          style: AppTypography.interLabel()),
                      const SizedBox(height: 4),
                      Text(user?.email ?? 'No email is linked',
                          style: AppTypography.interBody(color: AppColors.ink)),
                      const SizedBox(height: 12),
                      Text(
                        _hasPassword
                            ? 'Email and password sign-in is enabled for this same CampusSetu account.'
                            : 'Add a password to sign in with this email too. Google sign-in will keep working, and your profile stays the same.',
                        style: AppTypography.interBodySmall(
                            color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_hasPassword) ...[
                  FilledButton.icon(
                    onPressed: () {
                      final email = user?.email ?? '';
                      final query = Uri(queryParameters: {
                        'mode': 'forgot',
                        if (email.isNotEmpty) 'email': email,
                      }).query;
                      context.go('${AppRoutes.emailLogin}?$query');
                    },
                    icon: const Icon(Icons.lock_reset_rounded),
                    label: const Text('Reset password with email OTP'),
                  ),
                ] else ...[
                  TextField(
                    controller: _password,
                    obscureText: !_showPassword,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'New password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(_showPassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirm,
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _setPassword(),
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon: Icon(Icons.lock_reset_rounded),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Use at least 8 characters.',
                      style:
                          AppTypography.interCaption(color: AppColors.inkSoft)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _setPassword,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.password_rounded),
                      label: Text(_busy ? 'Setting password…' : 'Set password'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'CampusSetu never stores your raw password in its database. Firebase securely manages the sign-in credential.',
                  textAlign: TextAlign.center,
                  style: AppTypography.interCaption(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
