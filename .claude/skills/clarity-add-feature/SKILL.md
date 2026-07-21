---
name: clarity-add-feature
description: >-
  Step-by-step recipe for adding a new feature, screen, data source, or setting to
  the Clarity app so it matches the existing architecture exactly — use when asked
  to "add", "build", or "create" anything new in this repo (a new page, a new API
  call, a new BLoC, a new setting, a new translated string). Walks the full
  domain→data→DI→presentation flow with the project's real patterns. Pair with
  clarity-architecture (rules), clarity-design-system (look), clarity-responsive.
---

# Clarity — Adding a New Feature

Follow this order so a new feature is indistinguishable from `weather`/`settings`.
Read `clarity-architecture` for the rules and `clarity-design-system` for the UI.
Build **inward-out**: domain → data → DI → presentation.

## A. Full new feature (with its own API/data) — the `weather` template

Create `lib/features/<feature>/` with `domain/`, `data/`, `presentation/`.

**1. Domain — entities** (`domain/entities/<name>.dart`)
- Plain `Equatable` class, pure Dart, `const` ctor, `props`. No Flutter/dio/json.

**2. Domain — repository interface** (`domain/repositories/<feature>_repository.dart`)
```dart
abstract class AirQualityRepository {
  Future<Either<Failure, AirQuality>> getByCoords(double lat, double lon);
}
```

**3. Domain — use case** (`domain/usecases/<verb>.dart`) extending the base:
```dart
class GetAirQuality extends UseCase<AirQuality, AirQualityParams> {
  final AirQualityRepository repository;
  GetAirQuality(this.repository);
  @override
  Future<Either<Failure, AirQuality>> call(AirQualityParams p) =>
      repository.getByCoords(p.lat, p.lon);
}
class AirQualityParams extends Equatable {
  final double lat, lon;
  const AirQualityParams({required this.lat, required this.lon});
  @override List<Object?> get props => [lat, lon];
}
```

**4. Data — model** (`data/models/<name>_model.dart`): `class XModel extends X` with a
`factory XModel.fromJson(...)` / `fromApiResponse(...)` (mirror `WeatherModel`). The
model IS the entity — return it directly as the entity.

**5. Data — datasource** (`data/datasources/<feature>_remote_data_source.dart`): an
abstract interface + `Impl` using `Dio`. Throw the typed exceptions from
`core/error/exceptions.dart` on failure; reuse a `_handleError(statusCode)` like
`weather_remote_data_source.dart`. Get secrets from `envConfig`.

**6. Data — repository impl** (`data/repositories/<feature>_repository_impl.dart`):
`try { return Right(await ds...); } on XException { return Left(XFailure()); } catch (e) { return Left(ServerFailure(e.toString())); }`. (Add new `Failure`/`Exception`
types to `core/error/` if the domain needs them.)

**7. Register in DI** — `lib/core/di/injection_container.dart`, under a new
`//! Features - <Feature>` section:
```dart
sl.registerFactory(() => AirQualityBloc(getAirQuality: sl()));
sl.registerLazySingleton(() => GetAirQuality(sl()));
sl.registerLazySingleton<AirQualityRepository>(
  () => AirQualityRepositoryImpl(remoteDataSource: sl()));
sl.registerLazySingleton<AirQualityRemoteDataSource>(
  () => AirQualityRemoteDataSourceImpl(dio: sl(), envConfig: sl()));
```
(`Dio`, `SharedPreferences`, `EnvConfig` are already registered — reuse via `sl()`.)

**8. Presentation — BLoC** (`presentation/bloc/`): `Bloc<Event,State>`, Equatable
event/state files (Initial/Loading/Loaded/Error), handlers via `on<Event>`, resolve
with `result.fold((f)=>emit(Error(f.message)), (d)=>emit(Loaded(d)))`. Mirror
`weather_bloc.dart`.

**9. Presentation — page/widgets** (`presentation/pages`, `presentation/widgets`):
build with `ClayContainer` + `AppColors` + `Localizer` (see `clarity-design-system`),
responsive per `clarity-responsive`. Provide the BLoC where the page is mounted:
`BlocProvider(create: (_) => sl<AirQualityBloc>(), child: ...)`.

**10. Wire navigation** — either add a `GoRoute` in `app_router.dart`, or (matching the
current app) push it with a `PageRouteBuilder`/`MaterialPageRoute`, passing existing
BLoCs down with `BlocProvider.value` (see how `menu_screen.dart` opens `SettingsPage`).

## B. New page/tab in an existing feature (no new data)
Add the page under `presentation/pages/`, reuse the feature's existing BLoC via
`context.read`/`BlocBuilder`. To add it as a tab, extend the `PageView` children and
the sliding bottom nav in `main_screen.dart` (add a `_buildNavItem` and widen the
`itemWidth = maxWidth / count`).

## C. New setting
1. Add the field (+ enum if needed) to `AppSettings` (`features/settings/domain/
   entities/app_settings.dart`): add to fields, ctor default, `copyWith`, and `props`.
2. Persist it in `SettingsBloc`: read it in `_loadSettings` (`sharedPreferences.get…`
   with a new `'setting_<x>'` key + default) and write it in `_onUpdateSettings`.
3. Add a UI control in `settings_page.dart` using `_buildSettingSection` +
   `_buildAnimatedToggle`/`Switch`/`DropdownButton`, dispatching
   `UpdateSettings(settings.copyWith(<x>: val))`.
4. If it affects weather (like unit/language), extend the `BlocListener.listenWhen`
   in `main_screen.dart` to refetch on change.

## D. New user-facing string (required for ANY visible text)
1. Add the key + value to `lib/l10n/app_en.arb` (the source of truth), with its `@key`
   metadata entry if following ARB convention.
2. Use it: `Localizer.localize('my_key', settings.language)` (get `settings.language`
   from `SettingsBloc` state). Never hardcode display text.
3. Translations: the project uses Crowdin — `crowdin push` uploads `app_en.arb`,
   `crowdin pull` fetches the 28 translations. Missing keys fall back to English then to
   the raw key (`Localizer.localize`), so the app won't crash before translations land.
4. If you add a whole new language, add it to `Localizer._languageMap` and ship
   `lib/l10n/app_<code>.arb`.

## E. New external secret / config
Add it to `assets/.env` and expose it via `EnvConfig` (`core/config/env_config.dart`),
then read `envConfig.<name>` in the datasource. `.env` holds live API keys — never
print, commit, or paste its contents.

## Pre-flight checklist
- [ ] Domain has no Flutter/dio/model imports.
- [ ] Repo returns `Either<Failure,T>`; no throws escape the data layer.
- [ ] Everything registered in `injection_container.dart` (Factory for BLoC, LazySingleton otherwise).
- [ ] BLoC depends on the UseCase, UI depends on the BLoC only.
- [ ] All strings via `Localizer`; new keys in `app_en.arb`.
- [ ] UI uses `ClayContainer`/`AppColors`/Bricolage; transitions animated.
- [ ] Layout responsive (see `clarity-responsive`) — no fixed screen-sized pixels.
- [ ] `flutter analyze` clean.
