import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/city_location.dart';
import '../repositories/weather_repository.dart';

class SearchCities extends UseCase<List<CityLocation>, SearchCitiesParams> {
  final WeatherRepository repository;

  SearchCities(this.repository);

  @override
  Future<Either<Failure, List<CityLocation>>> call(SearchCitiesParams params) {
    return repository.searchCities(params.query, locale: params.locale);
  }
}

class SearchCitiesParams extends Equatable {
  final String query;
  final String locale;

  const SearchCitiesParams({required this.query, this.locale = 'en'});

  @override
  List<Object?> get props => [query, locale];
}
