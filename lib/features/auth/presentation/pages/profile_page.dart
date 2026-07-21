import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/localizer.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../weather/presentation/widgets/clay_container.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../settings/domain/entities/app_settings.dart';
import '../../domain/entities/auth_user.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Profile screen — matte claymorphic layout adapted from the Clarity Clay
/// System reference: a slate primary action (no bright accent), raised stat
/// cards, and *sunken* molded surfaces (badge, account card, icon chips).
/// Rendered entirely in the app's ClayContainer + AppColors + Bricolage.
class ProfilePage extends StatelessWidget {
  final AuthUser user;
  const ProfilePage({super.key, required this.user});

  /// The reference's muted "primary" slate (≈ #4f5d71) — Clarity's cloudShadow.
  static const Color _slate = AppColors.cloudShadow;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        final settings = settingsState.settings;
        final lang = settings.language;
        final localeCode = Localizer.getLocaleCode(lang);

        return BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) => current is AuthError,
          listener: (context, state) {
            if (state is AuthError) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.message)));
            }
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: _slate),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: Text(Localizer.localize('profile', lang),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              centerTitle: false,
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: Breakpoints.maxContentWidth),
                    child: Column(
                      children: [
                        _header(lang),
                        const SizedBox(height: 32),
                        _statsGrid(settings, localeCode, lang),
                        const SizedBox(height: 36),
                        _sectionHeader(Localizer.localize('account_details', lang)),
                        const SizedBox(height: 14),
                        _accountDetails(lang, localeCode),
                        const SizedBox(height: 32),
                        _sectionHeader(Localizer.localize('my_preferences', lang)),
                        const SizedBox(height: 14),
                        _preferences(context, settings, lang),
                        const SizedBox(height: 36),
                        _actions(context, lang),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---- Header -------------------------------------------------------------

  Widget _header(String lang) {
    return Column(
      children: [
        ClayContainer(
          shape: BoxShape.circle,
          padding: const EdgeInsets.all(6),
          child: CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.surface,
            backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                ? NetworkImage(user.photoUrl!)
                : null,
            child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                ? const Icon(Icons.person, size: 48, color: _slate)
                : null,
          ),
        ),
        const SizedBox(height: 18),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(_displayName(lang),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 12),
        // Sunken "molded" badge.
        ClayContainer(
          inset: true,
          borderRadius: 20,
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Text(_accountTypeLabel(lang),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
        ),
      ],
    );
  }

  String _displayName(String lang) {
    if (user.displayName != null && user.displayName!.isNotEmpty) return user.displayName!;
    if (user.isAnonymous) return Localizer.localize('guest', lang);
    return user.email ?? '—';
  }

  String _accountTypeLabel(String lang) {
    if (user.isAnonymous) return Localizer.localize('guest', lang);
    switch (user.providerId) {
      case 'google.com':
        return Localizer.localize('google_account', lang);
      case 'password':
        return Localizer.localize('email_account', lang);
      default:
        return Localizer.localize('member', lang);
    }
  }

  // ---- Stats (raised) -----------------------------------------------------

  Widget _statsGrid(AppSettings settings, String localeCode, String lang) {
    final daysActive =
        user.createdAt != null ? DateTime.now().difference(user.createdAt!).inDays : 0;

    final stats = <_Stat>[
      _Stat(Icons.calendar_today_rounded, '$daysActive', Localizer.localize('days_active', lang)),
      _Stat(Icons.translate_rounded, localeCode.toUpperCase(), Localizer.localize('language', lang)),
      _Stat(
        Icons.thermostat_rounded,
        settings.temperatureUnit == TemperatureUnit.celsius ? '°C' : '°F',
        Localizer.localize('units', lang),
      ),
      _Stat(
        Icons.notifications_none_rounded,
        settings.severeWeatherAlerts ? Localizer.localize('on', lang) : Localizer.localize('off', lang),
        Localizer.localize('alerts', lang),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 560 ? 4 : 2;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: cols == 4 ? 1.0 : 1.15,
          children: [for (final s in stats) _statCard(s)],
        );
      },
    );
  }

  Widget _statCard(_Stat s) {
    return ClayContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(s.icon, color: _slate, size: 24),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(s.value,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _slate)),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(s.label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  // ---- Account details (sunken group) -------------------------------------

  Widget _accountDetails(String lang, String localeCode) {
    final memberSince =
        user.createdAt != null ? DateFormat.yMMMM(localeCode).format(user.createdAt!) : '—';
    return ClayContainer(
      inset: true,
      borderRadius: 24,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        children: [
          _detailRow(Icons.mail_outline_rounded, Localizer.localize('email', lang),
              user.email ?? Localizer.localize('guest_session', lang)),
          _rowDivider(),
          _detailRow(Icons.schedule_rounded, Localizer.localize('member_since', lang), memberSince),
          _rowDivider(),
          _detailRow(Icons.shield_outlined, Localizer.localize('account_type', lang), _accountTypeLabel(lang)),
        ],
      ),
    );
  }

  Widget _rowDivider() => Divider(height: 1, thickness: 1, color: AppColors.shadowLight);

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _slate),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 15)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  // ---- Preferences (raised rows, sunken chips) ----------------------------

  Widget _preferences(BuildContext context, AppSettings settings, String lang) {
    final units = settings.temperatureUnit == TemperatureUnit.celsius ? '°C' : '°F';
    final langCode = Localizer.getLocaleCode(settings.language).toUpperCase();
    return Column(
      children: [
        _prefRow(
          Icons.notifications_none_rounded,
          Localizer.localize('notification_settings', lang),
          settings.severeWeatherAlerts ? Localizer.localize('on', lang) : Localizer.localize('off', lang),
          () => _openSettings(context),
        ),
        const SizedBox(height: 16),
        _prefRow(
          Icons.tune_rounded,
          Localizer.localize('app_preferences', lang),
          '$units · $langCode',
          () => _openSettings(context),
        ),
      ],
    );
  }

  Widget _prefRow(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClayContainer(
        borderRadius: 24,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClayContainer(
              inset: true,
              borderRadius: 14,
              color: AppColors.surface,
              padding: const EdgeInsets.all(11),
              child: Icon(icon, color: _slate, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<SettingsBloc>(),
          child: const SettingsPage(),
        ),
      ),
    );
  }

  // ---- Actions ------------------------------------------------------------

  Widget _actions(BuildContext context, String lang) {
    final loading = context.watch<AuthBloc>().state is AuthLoading;
    return Column(
      children: [
        if (!user.isAnonymous) ...[
          // Primary — muted slate, not a bright accent.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: loading ? null : () => _showEditNameDialog(context, lang),
            child: ClayContainer(
              borderRadius: 20,
              color: _slate,
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(Localizer.localize('edit_profile', lang),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
              ),
            ),
          ),
          // Clears the raised highlight's ~25px reach so it can't wash onto the
          // dark primary button above.
          const SizedBox(height: 28),
        ],
        // Secondary — matte clay.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: loading ? null : () => context.read<AuthBloc>().add(const AuthSignOutRequested()),
          child: ClayContainer(
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: loading
                ? const Center(
                    child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded, color: AppColors.textPrimary, size: 22),
                      const SizedBox(width: 8),
                      Text(Localizer.localize('sign_out', lang),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  void _showEditNameDialog(BuildContext context, String lang) {
    final authBloc = context.read<AuthBloc>();
    final controller = TextEditingController(text: user.displayName ?? '');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(Localizer.localize('edit_name', lang),
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: Localizer.localize('display_name', lang),
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textSecondary)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _slate)),
          ),
          onSubmitted: (_) {
            final name = controller.text.trim();
            if (name.isNotEmpty) authBloc.add(AuthDisplayNameUpdateRequested(name));
            Navigator.pop(dialogContext);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(Localizer.localize('cancel', lang),
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) authBloc.add(AuthDisplayNameUpdateRequested(name));
              Navigator.pop(dialogContext);
            },
            child: Text(Localizer.localize('save', lang),
                style: const TextStyle(fontWeight: FontWeight.bold, color: _slate)),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _slate)),
    );
  }
}

class _Stat {
  final IconData icon;
  final String value;
  final String label;
  const _Stat(this.icon, this.value, this.label);
}
