import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/core/error/failures.dart';
import 'package:clarity/features/saved_cities/domain/entities/saved_city.dart';
import 'package:clarity/features/saved_cities/domain/repositories/saved_cities_repository.dart';
import 'package:clarity/features/saved_cities/presentation/bloc/saved_cities_bloc.dart';
import 'package:clarity/features/saved_cities/presentation/bloc/saved_cities_event.dart';
import 'package:clarity/features/saved_cities/presentation/bloc/saved_cities_state.dart';

class _FakeRepo implements SavedCitiesRepository {
  int watchCalls = 0;
  final controllers = <StreamController<Either<Failure, List<SavedCity>>>>[];

  @override
  Stream<Either<Failure, List<SavedCity>>> watch() {
    watchCalls++;
    final c = StreamController<Either<Failure, List<SavedCity>>>();
    controllers.add(c);
    return c.stream;
  }

  @override
  Future<Either<Failure, Unit>> save(String cityName) async => const Right(unit);

  @override
  Future<Either<Failure, Unit>> remove(String id) async => const Right(unit);
}

void main() {
  test('resubscribing opens a fresh stream and abandons the dead one', () async {
    // The release-build bug: the first subscription opened while signed out
    // died with a failure, and signing in never resubscribed. The router now
    // re-adds SavedCitiesSubscribed on auth changes; the bloc must swap
    // streams cleanly when that happens.
    final repo = _FakeRepo();
    final bloc = SavedCitiesBloc(repository: repo);

    bloc.add(const SavedCitiesSubscribed());
    await Future<void>.delayed(Duration.zero);
    repo.controllers.single.add(const Left(ServerFailure('Not signed in.')));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, SavedCitiesStatus.error);

    // Auth change → resubscribe. New stream delivers the user's cities.
    bloc.add(const SavedCitiesSubscribed());
    await Future<void>.delayed(Duration.zero);
    expect(repo.watchCalls, 2);

    const sofia = SavedCity(id: 'sofia', name: 'Sofia');
    repo.controllers.last.add(const Right([sofia]));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.status, SavedCitiesStatus.loaded);
    expect(bloc.state.cities, const [sofia]);

    // The dead stream must no longer influence state.
    repo.controllers.first.add(const Left(ServerFailure('stale')));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, SavedCitiesStatus.loaded,
        reason: 'the abandoned first stream leaked into state');

    await bloc.close();
    for (final c in repo.controllers) {
      await c.close();
    }
  });
}
