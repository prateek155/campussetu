// lib/features/faculty/auth/faculty_register_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';

class FacultyRegisterScreen extends StatefulWidget {
  const FacultyRegisterScreen({super.key});

  @override
  State<FacultyRegisterScreen> createState() => _FacultyRegisterScreenState();
}

class _FacultyRegisterScreenState extends State<FacultyRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _collegeC = TextEditingController();
  final _subjectC = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameC.dispose(); _emailC.dispose(); _passC.dispose();
    _collegeC.dispose(); _subjectC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final dio = Dio(BaseOptions(baseUrl: dotenv.env['API_BASE_URL'] ?? ''));
      await dio.post('/quiz/faculty/register', data: {
        'name': _nameC.text.trim(),

        'email': _emailC.text.trim().toLowerCase(),
        'password': _passC.text,
        'college_name': _collegeC.text.trim(),
        'subject': _subjectC.text.trim(),
      });
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Request Submitted! 🎉'),
          content: const Text(
            'Your registration request has been sent to the admin for approval.\n\n'
            'You will be able to login once your account is approved.',
          ),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(context); context.go('/faculty/login'); },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? 'Something went wrong. Please try again.';
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
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo & Title
                      const Icon(Icons.school, size: 56, color: Color(0xFF6C63FF)),
                      const SizedBox(height: 12),
                      const Text(
                        'Faculty Registration',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Submit your details for admin approval',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 28),

                      // Name
                      TextFormField(
                        controller: _nameC,
                        decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: _emailC,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
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
                        validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
                      ),
                      const SizedBox(height: 16),

                      // College Name
                      TextFormField(
                        controller: _collegeC,
                        decoration: const InputDecoration(labelText: 'College / University Name', prefixIcon: Icon(Icons.account_balance_outlined)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'College name is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Subject
                      TextFormField(
                        controller: _subjectC,
                        decoration: const InputDecoration(labelText: 'Subject You Teach', prefixIcon: Icon(Icons.book_outlined)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Subject is required' : null,
                      ),
                      const SizedBox(height: 28),

                      // Submit Button
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Submit for Approval', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Already have account
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Already approved? '),
                          TextButton(
                            onPressed: () => context.go('/faculty/login'),
                            child: const Text('Login here', style: TextStyle(color: Color(0xFF6C63FF))),
                          ),
                        ],
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
