import 'package:equatable/equatable.dart';
import '../../domain/entities/auth_user.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Before the first auth-state event arrives (splash/gate shows a loader).
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// An auth action (sign in/up/out) is in progress.
class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  final AuthUser user;
  const Authenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// Transient — emitted right before returning to [Unauthenticated] so the UI can
/// surface the message (e.g. a SnackBar via BlocListener).
class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
