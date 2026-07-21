import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// The rounded Material icon and clay tint used to represent one weather
/// condition.
typedef WeatherIconStyle = ({IconData icon, Color color});

class ClayWeatherIcon extends StatelessWidget {
  final String condition;
  final double size;

  const ClayWeatherIcon({
    super.key,
    required this.condition,
    this.size = 100,
  });

  /// Maps a condition string to its icon + tint.
  ///
  /// Every value [WeatherIconMapper.mapCodeToCondition] can return must have a
  /// case here. A missing case falls through to `default` and renders as a sun
  /// — silently, with no error — which is how night and fog states shipped
  /// looking like a sunny day. `clay_weather_icon_test.dart` locks this down.
  static WeatherIconStyle styleFor(String condition) {
    switch (condition) {
      case 'Clear Sky':
        return (icon: Icons.wb_sunny_rounded, color: AppColors.warmAccent);
      case 'Clear Night':
        return (icon: Icons.nightlight_round, color: AppColors.cloudShadow);
      case 'Partly Cloudy':
        return (
          icon: Icons.cloud_queue_rounded,
          color: AppColors.inactiveBlueGray
        );
      case 'Partly Cloudy Night':
        // nights_stay is a moon behind a cloud — the night twin of cloud_queue.
        return (icon: Icons.nights_stay_rounded, color: AppColors.cloudShadow);
      case 'Cloudy':
        return (
          icon: Icons.cloud_rounded,
          color: AppColors.atmosphericBlueGray
        );
      case 'Rain':
        return (icon: Icons.umbrella_rounded, color: AppColors.functionalBlue);
      case 'Storm':
        return (icon: Icons.thunderstorm_rounded, color: AppColors.textPrimary);
      case 'Snow':
        return (icon: Icons.ac_unit_rounded, color: Colors.white);
      case 'Fog':
        return (icon: Icons.foggy, color: AppColors.inactiveBlueGray);
      default:
        return (icon: Icons.wb_sunny_rounded, color: AppColors.warmAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = styleFor(condition);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: style.color.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: Icon(
        style.icon,
        size: size * 0.6,
        color: style.color,
      ),
    );
  }
}
