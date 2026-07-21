import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/auth_user.dart';

/// DTO that maps a Firebase [User] to the domain [AuthUser]. Lives in the data
/// layer — the only place allowed to know about firebase_auth types.
class AuthUserModel extends AuthUser {
  const AuthUserModel({
    required super.uid,
    super.email,
    super.displayName,
    super.photoUrl,
    super.isAnonymous,
    super.createdAt,
    super.providerId,
  });

  factory AuthUserModel.fromFirebase(User user) => AuthUserModel(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
        isAnonymous: user.isAnonymous,
        createdAt: user.metadata.creationTime,
        providerId: user.isAnonymous
            ? 'anonymous'
            : (user.providerData.isNotEmpty ? user.providerData.first.providerId : null),
      );
}
