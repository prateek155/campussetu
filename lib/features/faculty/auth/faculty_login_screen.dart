// lib/features/faculty/auth/faculty_login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';

class FacultyLoginScreen extends StatefulWidget {
  const FacultyLoginScreen({super.key});

  @override
  State<FacultyLoginScreen> createState() => _FacultyLoginScreenState();
}

class _FacultyLoginScreenState extends State<FacultyLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      // Step 1: Firebase email/password login
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailC.text.trim(),
        password: _passC.text,
      );

      // Step 2: Verify faculty role in backend
      final idToken = await cred.user!.getIdToken();
      final dio = Dio(BaseOptions(
        baseUrl: dotenv.env['API_BASE_URL'] ?? '',
        headers: {'Authorization': 'Bearer $idToken'},
      ));

      await dio.post('/quiz/faculty/login-check');

      if (!mounted) return;
      // Navigate to quizzes
      context.go('/faculty/quizzes');
    } on FirebaseAuthException catch (e) {
      String msg = 'Login failed. Please check your credentials.';
      if (e.code == 'user-not-found') msg = 'No account found with this email.';
      if (e.code == 'wrong-password') msg = 'Incorrect password.';
      if (e.code == 'invalid-credential') msg = 'Invalid email or password.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? 'Access denied. Your account may not be approved yet.';
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo
                      const Icon(Icons.school_rounded, size: 64, color: Color(0xFF6C63FF)),
                      const SizedBox(height: 12),
                      const Text(
                        'CampuSetu',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF)),
                      ),
                      const Text(
                        'Faculty Portal',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 32),

                      // Email
                      TextFormField(
                        controller: _emailC,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email is required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passC,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Password is required' : null,
                      ),
                      const SizedBox(height: 28),

                      // Login Button
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Divider(),
                      const SizedBox(height: 12),

                      // Register link
                      const Text(
                        'New faculty member?',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => context.go('/faculty/register'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF6C63FF)),
                          foregroundColor: const Color(0xFF6C63FF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Register & Request Approval'),
                      ),
                    ],
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
