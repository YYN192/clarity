import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// App-wide auth state. Depends on the [AuthRepository] interface directly
/// (like SettingsBloc uses SharedPreferences) — the auth operations are thin
/// pass-throughs, so a use-case class per action would be pure boilerplate.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repository;
  late final StreamSubscription<AuthUser?> _userSubscription;

  AuthBloc(this._repository) : super(const AuthInitial()) {
    on<AuthUserChanged>(_onUserChanged);
    on<AuthSignInWithEmailRequested>(_onSignInEmail);
    on<AuthSignUpWithEmailRequested>(_onSignUpEmail);
    on<AuthSignInWithGoogleRequested>(_onSignInGoogle);
    on<AuthSignInAnonymouslyRequested>(_onSignInAnonymous);
    on<AuthSignOutRequested>(_onSignOut);
    on<AuthDisplayNameUpdateRequested>(_onUpdateDisplayName);

    _userSubscription =
        _repository.authStateChanges.listen((user) => add(AuthUserChanged(user)));
  }

  void _onUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    emit(event.user != null ? Authenticated(event.user!) : const Unauthenticated());
  }

  Future<void> _onSignInEmail(
          AuthSignInWithEmailRequested event, Emitter<AuthState> emit) =>
      _run(emit, () => _repository.signInWithEmail(email: event.email, password: event.password));

  Future<void> _onSignUpEmail(
          AuthSignUpWithEmailRequested event, Emitter<AuthState> emit) =>
      _run(emit, () => _repository.signUpWithEmail(email: event.email, password: event.password));

  Future<void> _onSignInGoogle(
          AuthSignInWithGoogleRequested event, Emitter<AuthState> emit) =>
      _run(emit, _repository.signInWithGoogle);

  Future<void> _onSignInAnonymous(
          AuthSignInAnonymouslyRequested event, Emitter<AuthState> emit) =>
      _run(emit, _repository.signInAnonymously);

  /// Emits Loading → then either an error (followed by Unauthenticated so the UI
  /// recovers) or Authenticated. The stream listener also emits Authenticated;
  /// Equatable dedupes the duplicate.
  Future<void> _run(
      Emitter<AuthState> emit, Future<Either<Failure, AuthUser>> Function() action) async {
    emit(const AuthLoading());
    final result = await action();
    result.fold(
      (failure) {
        emit(AuthError(failure.message));
        emit(const Unauthenticated());
      },
      (user) => emit(Authenticated(user)),
    );
  }

  Future<void> _onUpdateDisplayName(
      AuthDisplayNameUpdateRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final result = await _repository.updateDisplayName(event.name);
    result.fold(
      (failure) {
        emit(AuthError(failure.message));
        // Stay signed in on failure — don't drop the session to Unauthenticated.
        final current = _repository.currentUser;
        emit(current != null ? Authenticated(current) : const Unauthenticated());
      },
      (user) => emit(Authenticated(user)),
    );
  }

  Future<void> _onSignOut(AuthSignOutRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final result = await _repository.signOut();
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(const Unauthenticated()),
    );
  }

  @override
  Future<void> close() {
    _userSubscription.cancel();
    return super.close();
  }
}
