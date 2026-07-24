import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/localizer.dart';
import '../../../weather/presentation/widgets/clay_container.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/pages/auth_gate.dart';
import '../../../saved_cities/domain/entities/saved_city.dart';
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
            // Vertical only: the saved-cities list below must reach the drawer's
            // full width so its cards' 25px clay shadows have room to paint
            // inside the scroll viewport instead of being clipped by it. The
            // fixed sections re-apply the horizontal inset themselves.
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: _SavedCitiesList.horizontalInset),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _SavedCitiesList(language: state.settings.language),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: _SavedCitiesList.horizontalInset),
                    child: Center(
                      child: Text(Localizer.localize('app_version', state.settings.language),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ),
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
///
/// Renders full-bleed and applies its own horizontal inset, rather than sitting
/// inside the drawer's padding. A `ClayContainer`'s outer shadows reach 25px
/// (offset 8 + blur 16 + spread 1) on every side, so a card flush with a
/// clipping scroll viewport loses them entirely and reads as a flat rectangle.
class _SavedCitiesList extends StatefulWidget {
  const _SavedCitiesList({required this.language});

  final String language;

  /// Keeps cards aligned with the menu items above while leaving the viewport
  /// itself full-width, so shadows paint into this inset instead of being cut.
  static const double horizontalInset = 24;

  @override
  State<_SavedCitiesList> createState() => _SavedCitiesListState();
}

class _SavedCitiesListState extends State<_SavedCitiesList> {
  final _controller = ScrollController();

  /// Whether content continues past each edge. Drives the fade, so a list that
  /// fits isn't faded for no reason.
  bool _hasAbove = false;
  bool _hasBelow = false;

  /// Height of the fade at each edge, matched to the list's vertical padding.
  ///
  /// That alignment matters: at rest the scrim covers exactly the padding and
  /// no card, so nothing is dimmed for no reason. Only once a card scrolls into
  /// that band does it start to fade — which is precisely the "more below" cue.
  /// It also clears the 25px shadow reach, so a shadow never terminates against
  /// a visible edge.
  static const double _scrimHeight = _listVerticalPadding;

  static const double _listVerticalPadding = 28;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncEdges);
    // Positions don't exist until after first layout.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncEdges());
  }

  @override
  void dispose() {
    _controller.removeListener(_syncEdges);
    _controller.dispose();
    super.dispose();
  }

  void _syncEdges() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    // A 1px tolerance stops the fade flickering at the extremes.
    final above = position.pixels > position.minScrollExtent + 1;
    final below = position.pixels < position.maxScrollExtent - 1;
    if (above == _hasAbove && below == _hasBelow) return;
    setState(() {
      _hasAbove = above;
      _hasBelow = below;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SavedCitiesBloc, SavedCitiesState>(
      builder: (context, state) {
        if (state.cities.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: _SavedCitiesList.horizontalInset),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                Localizer.localize(
                  state.status == SavedCitiesStatus.error
                      ? 'saved_cities_unavailable'
                      : 'no_saved_cities',
                  widget.language,
                ),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        // Item count changes can invalidate the edge flags without a scroll.
        WidgetsBinding.instance.addPostFrameCallback((_) => _syncEdges());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: _SavedCitiesList.horizontalInset),
              child: Text(
                Localizer.localize('saved_cities', widget.language),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(child: _buildList(state)),
          ],
        );
      },
    );
  }

  Widget _buildList(SavedCitiesState state) {
    final list = ListView.separated(
      controller: _controller,
      // Horizontal: room for the 25px side shadows inside the viewport.
      // Vertical: same, so the first and last cards aren't shaved.
      padding: const EdgeInsets.symmetric(
        horizontal: _SavedCitiesList.horizontalInset,
        vertical: _listVerticalPadding,
      ),
      itemCount: state.cities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _cityRow(state.cities[index]),
    );

    // Scrim overlay rather than a ShaderMask.
    //
    // The hourly strips fade with ShaderMask + BlendMode.dstIn because they sit
    // over varied content. That is wrong here: dstIn fades *alpha*, so it
    // half-dissolved each card's soft grey shadow while the viewport still
    // hard-clipped it — the fade exposed the clip instead of hiding it, leaving
    // a straight line across the full width under the last card. Painting the
    // background colour over the edges instead leaves the content's alpha
    // untouched and blends into exactly the colour behind it.
    return Stack(
      children: [
        list,
        if (_hasAbove) _edgeScrim(top: true),
        if (_hasBelow) _edgeScrim(top: false),
      ],
    );
  }

  /// A short gradient of the scaffold colour over one edge of the list.
  ///
  /// Fades to `surface` at zero alpha, never `Colors.transparent` — that is
  /// transparent *black*, and interpolating towards it drags a grey cast
  /// through the gradient against this cream background.
  Widget _edgeScrim({required bool top}) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: 0,
      right: 0,
      height: _scrimHeight,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [
                AppColors.surface,
                AppColors.surface.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cityRow(SavedCity city) {
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
              tooltip: Localizer.localize('remove_city', widget.language),
              onPressed: () =>
                  context.read<SavedCitiesBloc>().add(SavedCityRemoved(city.id)),
            ),
          ],
        ),
      ),
    );
  }
}
