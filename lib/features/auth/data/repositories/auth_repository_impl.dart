import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/firebase_auth_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthDataSource dataSource;

  AuthRepositoryImpl({required this.dataSource});

  @override
  Stream<AuthUser?> get authStateChanges => dataSource.authStateChanges();

  @override
  AuthUser? get currentUser => dataSource.currentUser();

  @override
  Future<Either<Failure, AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _guard(() => dataSource.signInWithEmail(email, password));

  @override
  Future<Either<Failure, AuthUser>> signUpWithEmail({
    required String email,
    required String password,
  }) =>
      _guard(() => dataSource.signUpWithEmail(email, password));

  @override
  Future<Either<Failure, AuthUser>> signInWithGoogle() =>
      _guard(dataSource.signInWithGoogle);

  @override
  Future<Either<Failure, AuthUser>> signInAnonymously() =>
      _guard(dataSource.signInAnonymously);

  @override
  Future<Either<Failure, AuthUser>> updateDisplayName(String name) =>
      _guard(() => dataSource.updateDisplayName(name));

  @override
  Future<Either<Failure, AuthUser>> linkWithGoogle() =>
      _guard(dataSource.linkWithGoogle);

  @override
  Future<Either<Failure, AuthUser>> linkWithEmail({
    required String email,
    required String password,
  }) =>
      _guard(() => dataSource.linkWithEmail(email, password));

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await dataSource.signOut();
      return const Right(unit);
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  /// Runs [action], mapping the two library exception types to [AuthFailure].
  Future<Either<Failure, AuthUser>> _guard(
    Future<AuthUser> Function() action,
  ) async {
    try {
      return Right(await action());
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_firebaseMessage(e)));
    } on GoogleSignInException catch (e) {
      return Left(AuthFailure(_googleMessage(e)));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  String _firebaseMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'credential-already-in-use':
        return 'That account is already in use. Sign in with it instead — '
            'your guest data cannot be merged into it.';
      case 'provider-already-linked':
        return 'This account is already linked to that sign-in method.';
      case 'weak-password':
        return 'Please choose a stronger password (6+ characters).';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  String _googleMessage(GoogleSignInException e) {
    if (e.code == GoogleSignInExceptionCode.canceled) {
      return 'Sign-in cancelled.';
    }
    return e.description ?? 'Google sign-in failed.';
  }
}
