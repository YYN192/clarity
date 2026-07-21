import 'package:equatable/equatable.dart';
import '../../domain/entities/auth_user.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthSignInWithEmailRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthSignInWithEmailRequested(this.email, this.password);

  @override
  List<Object?> get props => [email, password];
}

class AuthSignUpWithEmailRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthSignUpWithEmailRequested(this.email, this.password);

  @override
  List<Object?> get props => [email, password];
}

class AuthSignInWithGoogleRequested extends AuthEvent {
  const AuthSignInWithGoogleRequested();
}

class AuthSignInAnonymouslyRequested extends AuthEvent {
  const AuthSignInAnonymouslyRequested();
}

class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

class AuthDisplayNameUpdateRequested extends AuthEvent {
  final String name;
  const AuthDisplayNameUpdateRequested(this.name);

  @override
  List<Object?> get props => [name];
}

/// Internal: fired whenever the FirebaseAuth stream reports a change.
class AuthUserChanged extends AuthEvent {
  final AuthUser? user;
  const AuthUserChanged(this.user);

  @override
  List<Object?> get props => [user];
}
