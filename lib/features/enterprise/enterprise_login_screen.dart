import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class EnterpriseLoginScreen extends StatefulWidget {
  const EnterpriseLoginScreen({super.key});

  @override
  State<EnterpriseLoginScreen> createState() => _EnterpriseLoginScreenState();
}

class _EnterpriseLoginScreenState extends State<EnterpriseLoginScreen> {
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final gUser = await GoogleSignIn().signIn();
      if (gUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final gAuth = await gUser.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
      if (mounted) context.go('/ent-home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront, size: 80, color: AppColors.primary),
              const SizedBox(height: 24),
              Text('CampusSetu Enterprise', style: AppTypography.soraHeading2()),
              const SizedBox(height: 8),
              Text('Partner Portal for Deals & Offers', style: AppTypography.interBody(color: AppColors.inkSoft)),
              const SizedBox(height: 48),
              _isLoading 
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _signIn,
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in with Google'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
