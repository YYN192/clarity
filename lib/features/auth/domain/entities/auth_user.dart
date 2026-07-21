import 'package:equatable/equatable.dart';

/// A signed-in user, independent of Firebase. Pure Dart — the domain layer must
/// not know about firebase_auth types.
class AuthUser extends Equatable {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isAnonymous;

  /// Account creation time (from Firebase user metadata). Null when unknown.
  final DateTime? createdAt;

  /// Primary sign-in provider id: 'google.com', 'password', 'anonymous', …
  final String? providerId;

  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.isAnonymous = false,
    this.createdAt,
    this.providerId,
  });

  @override
  List<Object?> get props =>
      [uid, email, displayName, photoUrl, isAnonymous, createdAt, providerId];
}
