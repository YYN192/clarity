import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ClayWeatherIcon extends StatelessWidget {
  final String condition;
  final double size;

  const ClayWeatherIcon({
    super.key,
    required this.condition,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    // In a real app, this would return an SVG or CustomPaint with claymorphic shadows.
    // Here we use Icons as placeholders but styled with "clay" colors.
    IconData iconData;
    Color color;

    switch (condition) {
      case 'Clear Sky':
        iconData = Icons.wb_sunny_rounded;
        color = AppColors.warmAccent;
        break;
      case 'Partly Cloudy':
        iconData = Icons.cloud_queue_rounded;
        color = AppColors.inactiveBlueGray;
        break;
      case 'Cloudy':
        iconData = Icons.cloud_rounded;
        color = AppColors.atmosphericBlueGray;
        break;
      case 'Rain':
        iconData = Icons.umbrella_rounded;
        color = AppColors.functionalBlue;
        break;
      case 'Storm':
        iconData = Icons.thunderstorm_rounded;
        color = AppColors.textPrimary;
        break;
      case 'Snow':
        iconData = Icons.ac_unit_rounded;
        color = Colors.white;
        break;
      default:
        iconData = Icons.wb_sunny_rounded;
        color = AppColors.warmAccent;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: Icon(
        iconData,
        size: size * 0.6,
        color: color,
      ),
    );
  }
}
