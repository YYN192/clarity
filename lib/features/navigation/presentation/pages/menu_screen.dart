import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/localizer.dart';
import '../../../weather/presentation/widgets/clay_container.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/pages/auth_gate.dart';
import '../../../saved_cities/presentation/bloc/saved_cities_bloc.dart';
import '../../../saved_cities/presentation/bloc/saved_cities_event.dart';
import '../../../saved_cities/presentation/bloc/saved_cities_state.dart';
import '../../../settings/domain/entities/app_settings.dart';
import '../../../weather/presentation/bloc/weather_bloc.dart';
import '../../../weather/presentation/bloc/weather_event.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(Localizer.localize('app_name', state.settings.language),
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const ClayContainer(
                          shape: BoxShape.circle,
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 64),
                  _buildMenuItem(
                    context,
                    icon: Icons.home,
                    label: Localizer.localize('home', state.settings.language),
                    isSelected: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 24),
                  _buildMenuItem(
                    context,
                    icon: Icons.settings,
                    label: Localizer.localize('settings', state.settings.language),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (modalContext) => BlocProvider.value(
                            value: context.read<SettingsBloc>(),
                            child: const SettingsPage(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildMenuItem(
                    context,
                    icon: Icons.person,
                    label: Localizer.localize('profile', state.settings.language),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MultiBlocProvider(
                            providers: [
                              BlocProvider.value(value: context.read<SettingsBloc>()),
                              BlocProvider.value(value: context.read<AuthBloc>()),
                            ],
                            child: const AuthGate(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: _SavedCitiesList(language: state.settings.language),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Text(Localizer.localize('app_version', state.settings.language),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(BuildContext context,
      {required IconData icon,
      required String label,
      bool isSelected = false,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClayContainer(
        color: isSelected ? AppColors.selectedItem : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textPrimary),
            const SizedBox(width: 16),
            Text(label,
                style: const TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary
                )),
            const Spacer(),
            if (isSelected) const Icon(Icons.chevron_right, color: AppColors.textPrimary),
          ],
        ),
      ),
    );
  }
}

/// The user's bookmarked cities. Tapping one loads its weather and closes the
/// menu; the trash icon removes it. Syncs through Firestore, so the list is the
/// same on every device signed into this account.
class _SavedCitiesList extends StatelessWidget {
  const _SavedCitiesList({required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SavedCitiesBloc, SavedCitiesState>(
      builder: (context, state) {
        if (state.cities.isEmpty) {
          return Align(
            alignment: Alignment.topLeft,
            child: Text(
              Localizer.localize(
                state.status == SavedCitiesStatus.error
                    ? 'saved_cities_unavailable'
                    : 'no_saved_cities',
                language,
              ),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Localizer.localize('saved_cities', language),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                // Room for the clay shadows to paint without being clipped.
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: state.cities.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final city = state.cities[index];
                  return GestureDetector(
                    onTap: () {
                      final settings = context.read<SettingsBloc>().state.settings;
                      context.read<WeatherBloc>().add(GetWeatherEvent(
                            city.name,
                            units: settings.temperatureUnit == TemperatureUnit.celsius
                                ? 'metric'
                                : 'imperial',
                            locale: Localizer.getLocaleCode(settings.language),
                          ));
                      Navigator.of(context).pop();
                    },
                    child: ClayContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          const Icon(Icons.place_outlined,
                              color: AppColors.textPrimary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              city.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.textSecondary, size: 20),
                            tooltip: Localizer.localize('remove_city', language),
                            onPressed: () => context
                                .read<SavedCitiesBloc>()
                                .add(SavedCityRemoved(city.id)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
