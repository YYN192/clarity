import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env_config.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../../features/weather/data/datasources/weather_remote_data_source.dart';
import '../../features/weather/data/repositories/weather_repository_impl.dart';
import '../../features/weather/domain/repositories/weather_repository.dart';
import '../../features/weather/domain/usecases/get_weather.dart';
import '../../features/weather/domain/usecases/search_cities.dart';
import '../../features/weather/presentation/bloc/city_search_bloc.dart';
import '../../features/weather/presentation/bloc/weather_bloc.dart';
import '../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../features/auth/data/datasources/firebase_auth_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/saved_cities/data/datasources/saved_cities_remote_data_source.dart';
import '../../features/saved_cities/data/repositories/saved_cities_repository_impl.dart';
import '../../features/saved_cities/domain/repositories/saved_cities_repository.dart';
import '../../features/saved_cities/presentation/bloc/saved_cities_bloc.dart';

final sl = GetIt.instance;

Future<void> init(EnvConfig envConfig) async {
  sl.registerSingleton<EnvConfig>(envConfig);

  //! Features - Weather
  // Bloc
  sl.registerFactory(() => WeatherBloc(
        getWeather: sl(),
        locationService: sl(),
        sharedPreferences: sl(),
        notificationService: sl(),
      ));

  //! Features - Saved cities
  sl.registerFactory(() => SavedCitiesBloc(repository: sl()));
  sl.registerLazySingleton<SavedCitiesRepository>(
    () => SavedCitiesRepositoryImpl(dataSource: sl()),
  );
  sl.registerLazySingleton<SavedCitiesRemoteDataSource>(
    () => SavedCitiesRemoteDataSourceImpl(firestore: sl(), auth: sl()),
  );

  //! Features - Settings
  sl.registerFactory(() => SettingsBloc(sharedPreferences: sl(), notificationService: sl()));

  //! Features - Auth
  sl.registerFactory(() => AuthBloc(sl()));
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(dataSource: sl()),
  );
  sl.registerLazySingleton<FirebaseAuthDataSource>(
    () => FirebaseAuthDataSourceImpl(
      firebaseAuth: sl(),
      googleSignIn: sl(),
      envConfig: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetWeather(sl()));
  sl.registerLazySingleton(() => SearchCities(sl()));
  sl.registerFactory(() => CitySearchBloc(searchCities: sl()));

  // Repository
  sl.registerLazySingleton<WeatherRepository>(
    () => WeatherRepositoryImpl(remoteDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<WeatherRemoteDataSource>(
    () => WeatherRemoteDataSourceImpl(dio: sl(), envConfig: sl()),
  );

  //! Core
  sl.registerLazySingleton<LocationService>(() => LocationServiceImpl());
  sl.registerLazySingleton<NotificationService>(
    () => NotificationServiceImpl(messaging: sl(), firestore: sl(), auth: sl()),
  );

  //! External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => Dio());
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  sl.registerLazySingleton<GoogleSignIn>(() => GoogleSignIn.instance);
  sl.registerLazySingleton<FirebaseMessaging>(() => FirebaseMessaging.instance);
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
}
