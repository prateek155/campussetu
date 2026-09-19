import 'package:firebase_auth/firebase_auth.dart';
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
  bool _isCacheValid() => _cachedToken != null && _cachedAt != null && DateTime.now().difference(_cachedAt!).inMinutes < 50;

  Future<Map<String, dynamic>> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential cred = await _auth.signInWithCredential(credential);
    final String idToken = await cred.user!.getIdToken(false) ?? '';

    _cachedToken = idToken;
    _cachedAt = DateTime.now();
    ApiService().setToken(idToken);

    final response = await ApiService().getMe().timeout(const Duration(seconds: 10), onTimeout: () => throw Exception('Server cold start, retrying...'));
    return response;
  }

  Future<String> getIdToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid()) return _cachedToken!;
    final token = await _auth.currentUser?.getIdToken(forceRefresh) ?? '';
    if (token.isNotEmpty) { _cachedToken = token; _cachedAt = DateTime.now(); }
    return token;
  }

  Future<void> signOut() async {
    _cachedToken = null;
    _cachedAt = null;
    ApiService().clearToken();
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }
}
