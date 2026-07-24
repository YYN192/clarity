import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/localizer.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../weather/presentation/widgets/clay_container.dart';
import '../bloc/settings_bloc.dart';
import '../../domain/entities/app_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final settings = state.settings;
        
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(Localizer.localize('settings', settings.language), 
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            centerTitle: false,
          ),
          body: SingleChildScrollView(
            // Center content at a max width on tablet/web/desktop by growing the
            // horizontal padding; stays at 24 on phones.
            padding: EdgeInsets.symmetric(
              horizontal: ((MediaQuery.sizeOf(context).width - Breakpoints.maxContentWidth) / 2)
                  .clamp(24.0, double.infinity),
              vertical: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Localizer.localize('preferences', settings.language),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text(Localizer.localize('tailor_clarity', settings.language),
                    style: const TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary
                    )),
                const SizedBox(height: 32),
                
                _buildSettingSection(
                  icon: Icons.language,
                  label: Localizer.localize('language', settings.language),
                  child: ClayContainer(
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: settings.language,
                        isExpanded: true,
                        items: ['English', 'Spanish', 'French', 'German', 'Bulgarian']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            context.read<SettingsBloc>().add(
                                UpdateSettings(settings.copyWith(language: val)));
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSettingSection(
                  icon: Icons.thermostat,
                  label: Localizer.localize('temperature', settings.language),
                  child: _buildAnimatedToggle<TemperatureUnit>(
                    value: settings.temperatureUnit,
                    options: {
                      TemperatureUnit.celsius: 'Celsius (°C)',
                      TemperatureUnit.fahrenheit: 'Fahrenheit (°F)',
                    },
                    onChanged: (val) {
                      context.read<SettingsBloc>().add(
                          UpdateSettings(settings.copyWith(temperatureUnit: val)));
                    },
                  ),
                ),
                const SizedBox(height: 24),
                _buildSettingSection(
                  icon: Icons.air,
                  label: Localizer.localize('wind_speed', settings.language),
                  child: _buildAnimatedToggle<WindSpeedUnit>(
                    value: settings.windSpeedUnit,
                    options: {
                      WindSpeedUnit.kmh: 'km/h',
                      WindSpeedUnit.mph: 'mph',
                      WindSpeedUnit.ms: 'm/s',
                    },
                    onChanged: (val) {
                      context.read<SettingsBloc>().add(
                          UpdateSettings(settings.copyWith(windSpeedUnit: val)));
                    },
                  ),
                ),
                const SizedBox(height: 24),
                _buildSettingSection(
                  icon: Icons.unfold_more,
                  label: Localizer.localize('pressure', settings.language),
                  child: _buildAnimatedToggle<PressureUnit>(
                    value: settings.pressureUnit,
                    options: {
                      PressureUnit.hPa: 'hPa',
                      PressureUnit.inHg: 'inHg',
                      PressureUnit.mmHg: 'mmHg',
                    },
                    onChanged: (val) {
                      context.read<SettingsBloc>().add(
                          UpdateSettings(settings.copyWith(pressureUnit: val)));
                    },
                  ),
                ),
                const SizedBox(height: 24),
                _buildSettingSection(
                  icon: Icons.notifications_none,
                  label: Localizer.localize('severe_alerts', settings.language),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(Localizer.localize('receive_notifications', settings.language), 
                        style: const TextStyle(color: AppColors.textPrimary)),
                      Switch(
                        value: settings.severeWeatherAlerts,
                        onChanged: (val) {
                          context.read<SettingsBloc>().add(UpdateSettings(
                              settings.copyWith(severeWeatherAlerts: val)));
                        },
                        activeThumbColor: AppColors.cloudShadow,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingSection(
      {required IconData icon,
      required String label,
      required Widget child,
      String? description}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.atmosphericBlueGray),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16,
                  color: AppColors.textPrimary
                )),
          ],
        ),
        const SizedBox(height: 12),
        child,
        if (description != null) ...[
          const SizedBox(height: 8),
          Text(description,
              style: const TextStyle(
                  fontSize: 12, 
                  fontStyle: FontStyle.italic, 
                  color: AppColors.textSecondary)),
        ],
      ],
    );
  }

  Widget _buildAnimatedToggle<T>(
      {required T value,
      required Map<T, String> options,
      required ValueChanged<T> onChanged}) {
    final activeIndex = options.keys.toList().indexOf(value);

    return ClayContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pillWidth = constraints.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                left: activeIndex * pillWidth,
                width: pillWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.selectedItem,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        offset: const Offset(2, 2),
                        blurRadius: 4,
                      )
                    ],
                  ),
                ),
              ),
              Row(
                children: options.entries.map((entry) {
                  final isSelected = entry.key == value;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(entry.key),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
