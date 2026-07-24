import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/navigation/presentation/pages/main_screen.dart';
import '../../features/saved_cities/presentation/bloc/saved_cities_bloc.dart';
import '../../features/saved_cities/presentation/bloc/saved_cities_event.dart';
import '../../features/weather/presentation/bloc/weather_bloc.dart';
import '../di/injection_container.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (context) => sl<WeatherBloc>()),
            BlocProvider(
              create: (context) =>
                  sl<SavedCitiesBloc>()..add(const SavedCitiesSubscribed()),
            ),
          ],
          child: const MainScreen(),
        ),
      ),
    ],
  );
}
