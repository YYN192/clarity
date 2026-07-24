import 'package:equatable/equatable.dart';
import '../../domain/entities/saved_city.dart';

enum SavedCitiesStatus { initial, loading, loaded, error }

class SavedCitiesState extends Equatable {
  final SavedCitiesStatus status;
  final List<SavedCity> cities;
  final String? message;

  const SavedCitiesState({
    this.status = SavedCitiesStatus.initial,
    this.cities = const [],
    this.message,
  });

  bool contains(String cityName) {
    final id = SavedCity.idFor(cityName);
    return cities.any((c) => c.id == id);
  }

  SavedCitiesState copyWith({
    SavedCitiesStatus? status,
    List<SavedCity>? cities,
    String? message,
  }) {
    return SavedCitiesState(
      status: status ?? this.status,
      cities: cities ?? this.cities,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, cities, message];
}
