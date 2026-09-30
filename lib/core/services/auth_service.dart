import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String? _cachedToken;
  DateTime? _cachedAt;
  bool _isCacheValid() =>
      _cachedToken != null &&
      _cachedAt != null &&
      DateTime.now().difference(_cachedAt!).inMinutes < 50;

  Future<Map<String, dynamic>> signInWithGoogle() async {
    UserCredential cred;
    if (kIsWeb) {
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      cred = await _auth.signInWithPopup(googleProvider);
    } else {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google sign-in cancelled');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      cred = await _auth.signInWithCredential(credential);
    }

    return _completeSignIn(cred);
  }

  Future<Map<String, dynamic>> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _completeSignIn(credential);
  }

  Future<Map<String, dynamic>> _completeSignIn(
      UserCredential credential) async {
    final user = credential.user;
    if (user == null) throw Exception('Could not verify your account.');

    final idToken = await user.getIdToken(false);
    if (idToken == null || idToken.isEmpty)
      throw Exception('Could not verify your sign-in.');

    _cachedToken = idToken;
    _cachedAt = DateTime.now();
    ApiService().setToken(idToken);

    return ApiService().getMe().timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Server cold start, retrying...'),
        );
  }

  bool get hasEmailPasswordProvider =>
      _auth.currentUser?.providerData
          .any((provider) => provider.providerId == 'password') ??
      false;

  Future<void> setPasswordForCurrentAccount(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw Exception('Sign in again before setting a password.');
    }
    if (hasEmailPasswordProvider) {
      throw Exception(
          'A password is already set. Use Forgot password to change it.');
    }

    final credential =
        EmailAuthProvider.credential(email: email, password: password);
    try {
      await user.linkWithCredential(credential);
      await user.reload();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'credential-already-in-use' ||
          error.code == 'email-already-in-use') {
        throw Exception(
          'This email is already linked to a different CampusSetu account. Sign in to that account; no profile was duplicated.',
        );
      }
      if (error.code == 'requires-recent-login') {
        throw Exception(
            'Sign out, sign in with Google again, then set your password.');
      }
      rethrow;
    }
  }

  Future<String> getIdToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid()) return _cachedToken!;
    final token = await _auth.currentUser?.getIdToken(forceRefresh) ?? '';
    if (token.isNotEmpty) {
      _cachedToken = token;
      _cachedAt = DateTime.now();
    }
    return token;
  }

  Future<void> signOut() async {
    _cachedToken = null;
    _cachedAt = null;
    ApiService().clearToken();
    if (kIsWeb) {
      await _auth.signOut();
    } else {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    }
  }
}
