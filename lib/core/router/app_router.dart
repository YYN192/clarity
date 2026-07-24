import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
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
          // The saved-cities stream is bound to the uid it was opened under.
          // On a fresh install the route builds signed-out, that stream dies
          // immediately, and nothing restarts it — so saving looked broken
          // even after signing in. Resubscribe on every auth identity change
          // (sign-in, sign-out, and account switches).
          child: BlocListener<AuthBloc, AuthState>(
            listenWhen: (previous, current) {
              final prevUid =
                  previous is Authenticated ? previous.user.uid : null;
              final currUid = current is Authenticated ? current.user.uid : null;
              return prevUid != currUid;
            },
            listener: (context, _) => context
                .read<SavedCitiesBloc>()
                .add(const SavedCitiesSubscribed()),
            child: const MainScreen(),
          ),
        ),
      ),
    ],
  );
}
