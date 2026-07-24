import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/saved_city.dart';
import '../../domain/repositories/saved_cities_repository.dart';
import '../datasources/saved_cities_remote_data_source.dart';

class SavedCitiesRepositoryImpl implements SavedCitiesRepository {
  final SavedCitiesRemoteDataSource dataSource;

  SavedCitiesRepositoryImpl({required this.dataSource});

  @override
  Stream<Either<Failure, List<SavedCity>>> watch() {
    // The stream itself can throw synchronously (not signed in), so build it
    // lazily and fold both that and later stream errors into a Left.
    late final Stream<Either<Failure, List<SavedCity>>> stream;
    try {
      stream = dataSource
          .watch()
          .map<Either<Failure, List<SavedCity>>>((cities) => Right(cities))
          .handleError(
            (Object error) => Left<Failure, List<SavedCity>>(_toFailure(error)),
          );
    } catch (e) {
      return Stream.value(Left(_toFailure(e)));
    }
    return stream;
  }

  @override
  Future<Either<Failure, Unit>> save(String cityName) =>
      _guard(() => dataSource.save(cityName));

  @override
  Future<Either<Failure, Unit>> remove(String id) =>
      _guard(() => dataSource.remove(id));

  Future<Either<Failure, Unit>> _guard(Future<void> Function() action) async {
    try {
      await action();
      return const Right(unit);
    } catch (e) {
      return Left(_toFailure(e));
    }
  }

  Failure _toFailure(Object error) {
    if (error is ServerException) {
      return ServerFailure(error.message ?? 'Could not reach saved cities.');
    }
    return ServerFailure(error.toString());
  }
}
