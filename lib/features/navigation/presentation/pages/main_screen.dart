import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/localizer.dart';
import '../../../weather/presentation/pages/weather_page.dart';
import '../../../weather/presentation/pages/forecast_page.dart';
import '../../../weather/presentation/widgets/clay_container.dart';
import '../../../weather/presentation/bloc/weather_bloc.dart';
import '../../../weather/presentation/bloc/weather_event.dart';
import '../../../weather/presentation/bloc/weather_state.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/domain/entities/app_settings.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../saved_cities/domain/entities/saved_city.dart';
import '../../../saved_cities/presentation/bloc/saved_cities_bloc.dart';
import '../../../saved_cities/presentation/bloc/saved_cities_event.dart';
import '../../../saved_cities/presentation/bloc/saved_cities_state.dart';
import '../../../weather/presentation/bloc/city_search_bloc.dart';
import '../../../weather/presentation/pages/city_search_page.dart';
import '../../../../core/di/injection_container.dart';
import 'menu_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final ScrollController _scrollController = ScrollController();
  // Separate controllers for the wide layout, where both panes are attached at
  // once — one controller cannot drive two scroll positions.
  final ScrollController _todayScrollController = ScrollController();
  final ScrollController _forecastScrollController = ScrollController();
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _currentIndex);
    final settings = context.read<SettingsBloc>().state.settings;
    final unitString = settings.temperatureUnit == TemperatureUnit.celsius ? 'metric' : 'imperial';
    final locale = Localizer.getLocaleCode(settings.language);
    context.read<WeatherBloc>().add(LoadInitialWeather(units: unitString, locale: locale));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // A phone that hasn't been opened in a week would otherwise keep week-old
    // coordinates and be alerted about somewhere it no longer is.
    if (state == AppLifecycleState.resumed) {
      context.read<WeatherBloc>().add(const RefreshAlertLocation());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _todayScrollController.dispose();
    _forecastScrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textPrimary),
              onPressed: () {
                // Read the blocs from *this* context, not the route's. A pushed
                // route sits above the router-level providers, so resolving
                // SavedCitiesBloc/WeatherBloc inside pageBuilder throws
                // ProviderNotFoundError. (SettingsBloc happens to work because
                // it is provided app-wide in main.dart.)
                final settingsBloc = context.read<SettingsBloc>();
                final savedCitiesBloc = context.read<SavedCitiesBloc>();
                final weatherBloc = context.read<WeatherBloc>();
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        MultiBlocProvider(
                      providers: [
                        BlocProvider.value(value: settingsBloc),
                        BlocProvider.value(value: savedCitiesBloc),
                        BlocProvider.value(value: weatherBloc),
                      ],
                      child: const MenuScreen(),
                    ),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const begin = Offset(-1.0, 0.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOutCubic;
                      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                  ),
                );
              },
            ),
            title: Text(Localizer.localize('app_name', settingsState.settings.language), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            actions: [
              _buildBookmarkAction(context),
              IconButton(
                icon: const Icon(Icons.search, color: AppColors.textPrimary),
                onPressed: () => _openSearch(context),
              ),
            ],
          ),
          body: BlocListener<SettingsBloc, SettingsState>(
            listenWhen: (previous, current) =>
                previous.settings.temperatureUnit != current.settings.temperatureUnit ||
                previous.settings.language != current.settings.language,
            listener: (context, state) {
              final weatherBloc = context.read<WeatherBloc>();
              final weatherState = weatherBloc.state;
              final unitString = state.settings.temperatureUnit == TemperatureUnit.celsius
                  ? 'metric'
                  : 'imperial';
              final locale = Localizer.getLocaleCode(state.settings.language);
              
              if (weatherState is WeatherLoaded) {
                weatherBloc.add(GetWeatherEvent(weatherState.weather.cityName, units: unitString, locale: locale));
              } else {
                weatherBloc.add(LoadInitialWeather(units: unitString, locale: locale));
              }
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Phones page between Today and Forecast; anything wider has
                // room to show both at once, so the pager and its bottom nav
                // would just be hiding half the screen.
                if (screenTypeOf(constraints.maxWidth) == ScreenType.phone) {
                  return _buildPagedView();
                }
                return _buildSideBySideView();
              },
            ),
          ),
        );
      },
    );
  }

  /// Bookmark toggle for the city currently on screen. Hidden until weather has
  /// loaded, since there is nothing to save before then.
  Widget _buildBookmarkAction(BuildContext context) {
    return BlocBuilder<WeatherBloc, WeatherState>(
      builder: (context, weatherState) {
        if (weatherState is! WeatherLoaded) return const SizedBox.shrink();
        final city = weatherState.weather.cityName;

        return BlocBuilder<SavedCitiesBloc, SavedCitiesState>(
          builder: (context, savedState) {
            final saved = savedState.contains(city);
            return IconButton(
              icon: Icon(
                saved ? Icons.bookmark : Icons.bookmark_border,
                color: AppColors.textPrimary,
              ),
              tooltip: Localizer.localize(
                saved ? 'remove_city' : 'save_city',
                context.read<SettingsBloc>().state.settings.language,
              ),
              onPressed: () {
                // Saved cities live under the account's uid; without one the
                // write dies in Firestore rules. Tell the user instead of
                // failing silently.
                if (context.read<AuthBloc>().state is! Authenticated) {
                  final language =
                      context.read<SettingsBloc>().state.settings.language;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                        content: Text(Localizer.localize(
                            'sign_in_to_save', language))));
                  return;
                }
                final bloc = context.read<SavedCitiesBloc>();
                if (saved) {
                  bloc.add(SavedCityRemoved(SavedCity.idFor(city)));
                } else {
                  bloc.add(SavedCityAdded(city));
                }
              },
            );
          },
        );
      },
    );
  }

  /// Phone layout: one page at a time, with the floating bottom nav.
  Widget _buildPagedView() {
    return Stack(
      children: [
        PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            WeatherPage(key: const ValueKey(0), scrollController: _scrollController),
            ForecastPage(key: const ValueKey(1), scrollController: _scrollController),
          ],
        ),
        Positioned(
          bottom: 32,
          left: 24,
          right: 24,
          // Cap + center the nav so it doesn't span the whole width on
          // tablet/desktop.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: _buildBottomNav(),
            ),
          ),
        ),
      ],
    );
  }

  /// Tablet/desktop layout: both panes visible, no pager and no bottom nav.
  ///
  /// Each pane scrolls independently — sharing `_scrollController` across two
  /// simultaneously-attached views would throw, since a ScrollController can
  /// only drive one position at a time.
  Widget _buildSideBySideView() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: WeatherPage(
                key: const ValueKey('wide-today'),
                scrollController: _todayScrollController,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 3,
              child: ForecastPage(
                key: const ValueKey('wide-forecast'),
                scrollController: _forecastScrollController,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return ClayContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                left: _currentIndex * itemWidth,
                width: itemWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.warmAccent.withValues(alpha: 0.8),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildNavItem(
                      0,
                      Icons.calendar_today,
                      Localizer.localize('today', context.read<SettingsBloc>().state.settings.language),
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      1,
                      Icons.wb_sunny_outlined,
                      Localizer.localize('forecast', context.read<SettingsBloc>().state.settings.language),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_currentIndex != index) {
          setState(() => _currentIndex = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSearch(BuildContext context) {
    // Capture from this context — a pushed route's context sits above the
    // router-level providers (see HANDOFF §3, Provider scope).
    final settingsBloc = context.read<SettingsBloc>();
    final weatherBloc = context.read<WeatherBloc>();
    final savedCitiesBloc = context.read<SavedCitiesBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: settingsBloc),
            BlocProvider.value(value: weatherBloc),
            BlocProvider.value(value: savedCitiesBloc),
            BlocProvider(create: (_) => sl<CitySearchBloc>()),
          ],
          child: const CitySearchPage(),
        ),
      ),
    );
  }
}
