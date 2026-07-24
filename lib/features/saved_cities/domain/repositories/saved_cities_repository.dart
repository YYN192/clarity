import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/saved_city.dart';

/// Per-account bookmarked cities. Backed by Firestore so the list follows the
/// user across devices; anonymous users get one too, and it survives the
/// upgrade to a real account because linking preserves the uid.
abstract class SavedCitiesRepository {
  /// Emits the current list on every change. Errors arrive as a [Left].
  Stream<Either<Failure, List<SavedCity>>> watch();

  Future<Either<Failure, Unit>> save(String cityName);

  Future<Either<Failure, Unit>> remove(String id);
}
