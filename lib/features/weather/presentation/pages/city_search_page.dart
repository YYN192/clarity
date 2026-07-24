import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/localizer.dart';
import '../../../saved_cities/presentation/bloc/saved_cities_bloc.dart';
import '../../../saved_cities/presentation/bloc/saved_cities_state.dart';
import '../../../settings/domain/entities/app_settings.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/entities/city_location.dart';
import '../bloc/city_search_bloc.dart';
import '../bloc/weather_bloc.dart';
import '../bloc/weather_event.dart';
import '../widgets/clay_container.dart';

/// Full-screen search-as-you-type city picker.
///
/// Keystrokes are debounced 350ms before hitting the geocoder; picking a
/// suggestion fetches weather by that suggestion's exact coordinates. With an
/// empty field the user's saved cities show as one-tap shortcuts.
class CitySearchPage extends StatefulWidget {
  const CitySearchPage({super.key});

  @override
  State<CitySearchPage> createState() => _CitySearchPageState();
}

class _CitySearchPageState extends State<CitySearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;

  static const _debounceDuration = Duration(milliseconds: 350);

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String text) {
    _debounce?.cancel();
    final locale =
        Localizer.getLocaleCode(context.read<SettingsBloc>().state.settings.language);
    _debounce = Timer(_debounceDuration, () {
      if (!mounted) return;
      context.read<CitySearchBloc>().add(CitySearchQueryChanged(text, locale: locale));
    });
  }

  ({String units, String locale}) _prefs(BuildContext context) {
    final settings = context.read<SettingsBloc>().state.settings;
    return (
      units: settings.temperatureUnit == TemperatureUnit.celsius ? 'metric' : 'imperial',
      locale: Localizer.getLocaleCode(settings.language),
    );
  }

  void _selectSuggestion(BuildContext context, CityLocation city) {
    final prefs = _prefs(context);
    context.read<WeatherBloc>().add(SelectCityEvent(
          cityName: city.name,
          lat: city.lat,
          lon: city.lon,
          units: prefs.units,
          locale: prefs.locale,
        ));
    Navigator.of(context).pop();
  }

  /// Keyboard-submit fallback: plain name lookup, same as the old dialog but
  /// without dropping the user's units.
  void _submitFreeText(BuildContext context, String text) {
    if (text.trim().isEmpty) return;
    final prefs = _prefs(context);
    context.read<WeatherBloc>().add(
        GetWeatherEvent(text.trim(), units: prefs.units, locale: prefs.locale));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<SettingsBloc>().state.settings.language;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          Localizer.localize('search_city', language),
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClayContainer(
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: _onQueryChanged,
                      onSubmitted: (text) => _submitFreeText(context, text),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        icon: const Icon(Icons.search, color: AppColors.textSecondary),
                        hintText: Localizer.localize('enter_city', language),
                        hintStyle: const TextStyle(color: AppColors.textSecondary),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (context, value, _) => value.text.isEmpty
                              ? const SizedBox.shrink()
                              : IconButton(
                                  icon: const Icon(Icons.clear,
                                      color: AppColors.textSecondary, size: 20),
                                  onPressed: () {
                                    _controller.clear();
                                    _onQueryChanged('');
                                  },
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(child: _buildBody(context, language)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, String language) {
    return BlocBuilder<CitySearchBloc, CitySearchState>(
      builder: (context, state) {
        switch (state.status) {
          case CitySearchStatus.idle:
            return _buildSavedShortcuts(context, language);
          case CitySearchStatus.loading:
            return const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 24),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.cloudShadow),
                ),
              ),
            );
          case CitySearchStatus.error:
            return _message(
                Localizer.localize('search_failed', language));
          case CitySearchStatus.loaded:
            if (state.results.isEmpty) {
              return _message(Localizer.localize('no_results', language));
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: state.results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final city = state.results[index];
                return GestureDetector(
                  onTap: () => _selectSuggestion(context, city),
                  child: ClayContainer(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            color: AppColors.textPrimary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            city.label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(Icons.north_east,
                            color: AppColors.textSecondary, size: 16),
                      ],
                    ),
                  ),
                );
              },
            );
        }
      },
    );
  }

  /// Empty-field state: the user's saved cities as one-tap shortcuts.
  Widget _buildSavedShortcuts(BuildContext context, String language) {
    return BlocBuilder<SavedCitiesBloc, SavedCitiesState>(
      builder: (context, state) {
        if (state.cities.isEmpty) return const SizedBox.shrink();
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
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final city in state.cities)
                  GestureDetector(
                    onTap: () {
                      final prefs = _prefs(context);
                      context.read<WeatherBloc>().add(GetWeatherEvent(
                            city.name,
                            units: prefs.units,
                            locale: prefs.locale,
                          ));
                      Navigator.of(context).pop();
                    },
                    child: ClayContainer(
                      borderRadius: 20,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Text(
                        city.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _message(String text) => Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child:
              Text(text, style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
}
