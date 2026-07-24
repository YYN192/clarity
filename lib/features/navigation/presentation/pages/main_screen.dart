import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'menu_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final ScrollController _scrollController = ScrollController();
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
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        BlocProvider.value(
                      value: context.read<SettingsBloc>(),
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
              IconButton(
                icon: const Icon(Icons.search, color: AppColors.textPrimary),
                onPressed: () => _showSearchDialog(context),
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
            child: Stack(
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
            ),
          ),
        );
      },
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

  void _showSearchDialog(BuildContext context) {
    final controller = TextEditingController();
    final weatherBloc = context.read<WeatherBloc>();
    final settings = context.read<SettingsBloc>().state.settings;
    final language = settings.language;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(Localizer.localize('search_city', language),
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: Localizer.localize('enter_city', language),
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.textSecondary)),
            focusedBorder:
                const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.functionalBlue)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(Localizer.localize('cancel', language), style: const TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final locale = Localizer.getLocaleCode(language);
                weatherBloc.add(GetWeatherEvent(controller.text, locale: locale));
              }
              Navigator.pop(dialogContext);
            },
            child: Text(Localizer.localize('search', language),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.functionalBlue)),
          ),
        ],
      ),
    );
  }
}
