import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/weather_bloc.dart';
import '../bloc/weather_event.dart';
import '../bloc/weather_state.dart';
import '../../../settings/domain/entities/app_settings.dart';
import '../widgets/clay_container.dart';
import '../widgets/clay_weather_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/localizer.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/entities/weather.dart';
import 'package:intl/intl.dart';

class WeatherPage extends StatelessWidget {
  final ScrollController? scrollController;
  const WeatherPage({super.key, this.scrollController});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        return BlocBuilder<WeatherBloc, WeatherState>(
          builder: (context, weatherState) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: _buildContent(context, weatherState, settingsState.settings.language),
            );
          },
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, WeatherState weatherState, String language) {
    // Responsive placeholder height — a fraction of the screen instead of a
    // fixed 600px that overflows small screens and wastes space on large ones.
    final placeholderHeight = MediaQuery.sizeOf(context).height * 0.7;

    if (weatherState is WeatherLoading) {
      return SizedBox(
        key: const ValueKey('loading'),
        height: placeholderHeight,
        child: const Center(child: CircularProgressIndicator()),
      );
    } else if (weatherState is WeatherError) {
      return SizedBox(
        key: const ValueKey('error'),
        height: placeholderHeight,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(weatherState.message, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final settings = context.read<SettingsBloc>().state.settings;
                  context.read<WeatherBloc>().add(LoadInitialWeather(
                        units: settings.temperatureUnit == TemperatureUnit.celsius
                            ? 'metric'
                            : 'imperial',
                        locale: Localizer.getLocaleCode(settings.language),
                      ));
                },
                child: Text(Localizer.localize('retry', language)),
              ),
            ],
          ),
        ),
      );
    } else if (weatherState is WeatherLoaded) {
      return SingleChildScrollView(
        key: const ValueKey('loaded'),
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 140),
        // Cap content width and center it so it doesn't stretch edge-to-edge on
        // tablet/web/desktop.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Breakpoints.maxContentWidth),
            child: _buildWeatherContent(context, weatherState, language),
          ),
        ),
      );
    } else {
      return SizedBox(
        key: const ValueKey('initial'),
        height: placeholderHeight,
        child: Center(child: Text(Localizer.localize('search_for_a_city', language))),
      );
    }
  }

  Widget _buildWeatherContent(BuildContext context, WeatherLoaded state, String language) {
    final weather = state.weather;
    final localeCode = Localizer.getLocaleCode(language);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(weather.cityName,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ),
        Text(DateFormat('EEEE, MMM d', localeCode).format(DateTime.now()),
          style: const TextStyle(fontSize: 18, color: AppColors.textSecondary)),
        const SizedBox(height: 40),

        // Current Weather Card
        ClayContainer(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('${weather.temperature.round()}°',
                            style: const TextStyle(fontSize: 96, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(weather.condition,
                            style: const TextStyle(fontSize: 24, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    flex: 2,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        // Icon scales with the space it's given rather than a fixed 140.
                        final iconSize = c.maxWidth.clamp(80.0, 160.0);
                        return ClayWeatherIcon(condition: weather.condition, size: iconSize);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Text('H: ${weather.highTemp.round()}°',
                    style: const TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                  const SizedBox(width: 20),
                  Text('L: ${weather.lowTemp.round()}°',
                    style: const TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 48),
        Text(Localizer.localize('today', language),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 20),

        // Hourly Forecast — fills the width with flex when it fits, scrolls when it doesn't.
        _HourlyForecastStrip(items: weather.hourlyForecast, localeCode: localeCode),

        const SizedBox(height: 48),
        Text(Localizer.localize('next_days', language),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 20),

        // Daily Forecast List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: weather.dailyForecast.length,
          separatorBuilder: (context, index) => const SizedBox(height: 20),
          itemBuilder: (context, index) {
            final daily = weather.dailyForecast[index];
            return _buildDailyForecastCard(context, daily, localeCode);
          },
        ),
      ],
    );
  }

  Widget _buildDailyForecastCard(BuildContext context, DailyForecast daily, String localeCode) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(24),
      child: ClayContainer(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(DateFormat('EEE', localeCode).format(daily.date),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
            ),
            const Spacer(),
            ClayWeatherIcon(condition: daily.condition, size: 40),
            const Spacer(),
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text('${daily.highTemp.round()}°',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text('${daily.lowTemp.round()}°',
                        style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal hourly strip that adapts to width: when every item fits at a
/// comfortable minimum width it distributes them across the row with flex
/// (`Expanded`) — filling tablet/desktop widths — otherwise it falls back to a
/// horizontal scroll with edge fades.
class _HourlyForecastStrip extends StatelessWidget {
  final List<HourlyForecast> items;
  final String localeCode;
  const _HourlyForecastStrip({required this.items, required this.localeCode});

  static const double _minItemWidth = 88;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final needed = _minItemWidth * items.length + gap * (items.length - 1);
        final fits = constraints.maxWidth >= needed;

        if (fits) {
          // Fill the available width evenly — no scrolling on large screens.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Expanded(child: _HourlyForecastItem(hourly: items[i], localeCode: localeCode)),
              ],
            ],
          );
        }

        // Narrow: scroll horizontally with a soft edge fade (design system pattern).
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white.withValues(alpha: 0.0),
              Colors.white,
              Colors.white,
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.05, 0.95, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: SizedBox(
            // Taller than the card + generous padding so the neumorphic shadow
            // (offset 8 / blur 16 ≈ 25px reach) paints fully instead of being
            // clipped by this horizontal viewport on small screens. Also pushes
            // the first card past the leading edge fade.
            height: 204,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(width: gap),
              itemBuilder: (context, index) => SizedBox(
                width: _minItemWidth,
                child: _HourlyForecastItem(hourly: items[index], localeCode: localeCode),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HourlyForecastItem extends StatefulWidget {
  final HourlyForecast hourly;
  final String localeCode;
  const _HourlyForecastItem({required this.hourly, required this.localeCode});

  @override
  State<_HourlyForecastItem> createState() => _HourlyForecastItemState();
}

class _HourlyForecastItemState extends State<_HourlyForecastItem> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: () {},
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: ClayContainer(
          borderRadius: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(DateFormat('h a', widget.localeCode).format(widget.hourly.dateTime),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ),
              const SizedBox(height: 12),
              ClayWeatherIcon(condition: widget.hourly.condition, size: 44),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('${widget.hourly.temperature.round()}°',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
