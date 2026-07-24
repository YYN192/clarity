import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/core/error/failures.dart';
import 'package:clarity/features/auth/domain/entities/auth_user.dart';
import 'package:clarity/features/auth/domain/repositories/auth_repository.dart';
import 'package:clarity/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:clarity/features/auth/presentation/bloc/auth_event.dart';
import 'package:clarity/features/auth/presentation/bloc/auth_state.dart';

const _guest = AuthUser(uid: 'uid-1', isAnonymous: true, providerId: 'anonymous');
const _upgraded =
    AuthUser(uid: 'uid-1', isAnonymous: false, providerId: 'google.com');

class _FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();

  AuthUser? current = _guest;
  Either<Failure, AuthUser> linkResult = const Right(_upgraded);

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  AuthUser? get currentUser => current;

  @override
  Future<Either<Failure, AuthUser>> linkWithGoogle() async => linkResult;

  @override
  Future<Either<Failure, AuthUser>> linkWithEmail(
          {required String email, required String password}) async =>
      linkResult;

  @override
  Future<Either<Failure, AuthUser>> signInWithEmail(
          {required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, AuthUser>> signUpWithEmail(
          {required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, AuthUser>> signInWithGoogle() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, AuthUser>> signInAnonymously() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, AuthUser>> updateDisplayName(String name) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> signOut() => throw UnimplementedError();

  void dispose() => _controller.close();
}

void main() {
  late _FakeAuthRepository repo;
  late AuthBloc bloc;

  setUp(() {
    repo = _FakeAuthRepository();
    bloc = AuthBloc(repo);
  });

  tearDown(() async {
    await bloc.close();
    repo.dispose();
  });

  test('successful link upgrades in place, keeping the uid', () async {
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const AuthLinkWithGoogleRequested());
    await Future<void>.delayed(Duration.zero);

    expect(states.last, const Authenticated(_upgraded));
    expect((states.last as Authenticated).user.uid, _guest.uid,
        reason: 'linking must preserve the uid or per-account data orphans');
    await sub.cancel();
  });

  test('failed link keeps the guest session', () async {
    repo.linkResult = const Left(AuthFailure('That account is already in use.'));
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const AuthLinkWithEmailRequested('a@b.c', 'hunter22'));
    await Future<void>.delayed(Duration.zero);

    expect(states.whereType<AuthError>(), hasLength(1));
    expect(states.last, const Authenticated(_guest),
        reason: 'a failed upgrade must never sign the guest out');
    expect(states.whereType<Unauthenticated>(), isEmpty);
    await sub.cancel();
  });
}
