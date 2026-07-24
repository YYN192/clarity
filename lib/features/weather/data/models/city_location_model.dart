import '../../domain/entities/city_location.dart';

class CityLocationModel extends CityLocation {
  const CityLocationModel({
    required super.name,
    super.state,
    required super.country,
    required super.lat,
    required super.lon,
  });

  /// One entry of the OpenWeather `/geo/1.0/direct` response array.
  ///
  /// [locale] picks a translated display name from `local_names` when the
  /// geocoder has one, so a Bulgarian user sees "София" rather than "Sofia".
  factory CityLocationModel.fromJson(
    Map<String, dynamic> json, {
    String locale = 'en',
  }) {
    final localNames = json['local_names'];
    final localized =
        localNames is Map<String, dynamic> ? localNames[locale] as String? : null;
    return CityLocationModel(
      name: localized ?? json['name'] as String? ?? '',
      state: json['state'] as String?,
      country: json['country'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
    );
  }
}
