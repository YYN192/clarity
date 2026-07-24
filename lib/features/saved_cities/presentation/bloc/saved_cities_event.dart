import 'package:equatable/equatable.dart';
import '../../domain/entities/saved_city.dart';

abstract class SavedCitiesEvent extends Equatable {
  const SavedCitiesEvent();

  @override
  List<Object?> get props => [];
}

/// Begin listening to the signed-in user's saved cities.
class SavedCitiesSubscribed extends SavedCitiesEvent {
  const SavedCitiesSubscribed();
}

class SavedCityAdded extends SavedCitiesEvent {
  final String cityName;
  const SavedCityAdded(this.cityName);

  @override
  List<Object?> get props => [cityName];
}

class SavedCityRemoved extends SavedCitiesEvent {
  final String id;
  const SavedCityRemoved(this.id);

  @override
  List<Object?> get props => [id];
}

/// Internal: a new list (or error) arrived from the repository stream.
class SavedCitiesUpdated extends SavedCitiesEvent {
  final List<SavedCity>? cities;
  final String? error;
  const SavedCitiesUpdated({this.cities, this.error});

  @override
  List<Object?> get props => [cities, error];
}
