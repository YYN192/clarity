import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/localizer.dart';
import '../../../weather/presentation/widgets/clay_container.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/pages/auth_gate.dart';

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
                  const Spacer(),
                  
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
