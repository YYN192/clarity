import 'package:equatable/equatable.dart';

/// A geocoded place returned by city search — enough to disambiguate
/// same-named cities and to fetch weather by exact coordinates.
class CityLocation extends Equatable {
  final String name;

  /// Region/state, when the geocoder provides one (mostly US/large countries).
  final String? state;

  /// ISO 3166 country code, e.g. 'BG'.
  final String country;

  final double lat;
  final double lon;

  const CityLocation({
    required this.name,
    this.state,
    required this.country,
    required this.lat,
    required this.lon,
  });

  /// "Sofia, BG" / "Springfield, Illinois, US" — what the suggestion row shows.
  String get label =>
      [name, if (state != null && state!.isNotEmpty) state, country].join(', ');

  @override
  List<Object?> get props => [name, state, country, lat, lon];
}
