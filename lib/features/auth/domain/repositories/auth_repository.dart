import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/auth_user.dart';

/// Contract for authentication. The implementation (data layer) wraps
/// FirebaseAuth + Google Sign-In; callers only see [AuthUser] and [Failure].
abstract class AuthRepository {
  /// Emits the current user, or `null` when signed out, on every auth change.
  Stream<AuthUser?> get authStateChanges;

  /// The currently signed-in user, or `null`.
  AuthUser? get currentUser;

  Future<Either<Failure, AuthUser>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Either<Failure, AuthUser>> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<Either<Failure, AuthUser>> signInWithGoogle();

  Future<Either<Failure, AuthUser>> signInAnonymously();

  /// Updates the current user's display name and returns the refreshed user.
  Future<Either<Failure, AuthUser>> updateDisplayName(String name);

  /// Upgrades the current (anonymous) user in place by attaching a Google
  /// credential. The uid is preserved, so per-account data (saved cities,
  /// alert registration ownership) survives the upgrade.
  Future<Either<Failure, AuthUser>> linkWithGoogle();

  /// Upgrades the current (anonymous) user in place with email + password.
  Future<Either<Failure, AuthUser>> linkWithEmail({
    required String email,
    required String password,
  });

  Future<Either<Failure, Unit>> signOut();
}
