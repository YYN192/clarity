import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/config/env_config.dart';
import '../../domain/entities/auth_user.dart';
import '../models/auth_user_model.dart';

/// Low-level client over FirebaseAuth + Google Sign-In (v7 API). Throws the
/// underlying [FirebaseAuthException] / [GoogleSignInException]; the repository
/// maps those to [Failure]s.
abstract class FirebaseAuthDataSource {
  Stream<AuthUser?> authStateChanges();
  AuthUser? currentUser();
  Future<AuthUser> signInWithEmail(String email, String password);
  Future<AuthUser> signUpWithEmail(String email, String password);
  Future<AuthUser> signInWithGoogle();
  Future<AuthUser> signInAnonymously();
  Future<AuthUser> updateDisplayName(String name);

  /// Upgrade the current (anonymous) user in place by attaching a Google
  /// credential. Preserves the uid, so Firestore data keyed by it survives.
  Future<AuthUser> linkWithGoogle();

  /// Upgrade the current (anonymous) user in place with email+password.
  Future<AuthUser> linkWithEmail(String email, String password);

  Future<void> signOut();
}

class FirebaseAuthDataSourceImpl implements FirebaseAuthDataSource {
  final FirebaseAuth firebaseAuth;
  final GoogleSignIn googleSignIn;
  final EnvConfig envConfig;

  FirebaseAuthDataSourceImpl({
    required this.firebaseAuth,
    required this.googleSignIn,
    required this.envConfig,
  });

  bool _googleInitialized = false;

  @override
  Stream<AuthUser?> authStateChanges() => firebaseAuth
      .authStateChanges()
      .map((user) => user == null ? null : AuthUserModel.fromFirebase(user));

  @override
  AuthUser? currentUser() {
    final user = firebaseAuth.currentUser;
    return user == null ? null : AuthUserModel.fromFirebase(user);
  }

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    final cred = await firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return AuthUserModel.fromFirebase(cred.user!);
  }

  @override
  Future<AuthUser> signUpWithEmail(String email, String password) async {
    final cred = await firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return AuthUserModel.fromFirebase(cred.user!);
  }

  @override
  Future<AuthUser> signInAnonymously() async {
    final cred = await firebaseAuth.signInAnonymously();
    return AuthUserModel.fromFirebase(cred.user!);
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    // Web: google_sign_in v7's authenticate() is unsupported in the browser —
    // use Firebase's own popup flow instead.
    if (kIsWeb) {
      final cred = await firebaseAuth.signInWithPopup(GoogleAuthProvider());
      return AuthUserModel.fromFirebase(cred.user!);
    }

    await _ensureGoogleInitialized();
    final account = await googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final cred = await firebaseAuth.signInWithCredential(credential);
    return AuthUserModel.fromFirebase(cred.user!);
  }

  @override
  Future<AuthUser> updateDisplayName(String name) async {
    final user = firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user', message: 'Not signed in.');
    }
    await user.updateDisplayName(name.trim());
    await user.reload();
    return AuthUserModel.fromFirebase(firebaseAuth.currentUser!);
  }

  @override
  Future<AuthUser> linkWithGoogle() async {
    final user = _requireCurrentUser();

    // Web: same popup-based flow as sign-in — authenticate() is unsupported.
    if (kIsWeb) {
      final cred = await user.linkWithPopup(GoogleAuthProvider());
      return AuthUserModel.fromFirebase(cred.user!);
    }

    await _ensureGoogleInitialized();
    final account = await googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final cred = await user.linkWithCredential(credential);
    return AuthUserModel.fromFirebase(cred.user!);
  }

  @override
  Future<AuthUser> linkWithEmail(String email, String password) async {
    final user = _requireCurrentUser();
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    final cred = await user.linkWithCredential(credential);
    return AuthUserModel.fromFirebase(cred.user!);
  }

  User _requireCurrentUser() {
    final user = firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
          code: 'no-current-user', message: 'Not signed in.');
    }
    return user;
  }

  @override
  Future<void> signOut() async {
    // Best-effort Google sign-out (no-op if not signed in with Google), then Firebase.
    try {
      await googleSignIn.signOut();
    } catch (_) {}
    await firebaseAuth.signOut();
  }

  /// google_sign_in v7 requires a one-time initialize() before authenticate().
  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    final serverClientId = envConfig.googleServerClientId;
    await googleSignIn.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    _googleInitialized = true;
  }
}
