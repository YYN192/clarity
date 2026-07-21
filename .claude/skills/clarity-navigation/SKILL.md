---
name: clarity-navigation
description: >-
  Map and index of the Clarity Flutter weather app — use FIRST when opening this
  repo or when you need to find where something lives, trace a data flow, or
  understand how the codebase is organized. Covers the full lib/ file index,
  layer boundaries, entry points, key conventions, and grep recipes for locating
  code. Read this before making changes; pair with clarity-architecture (rules),
  clarity-design-system (UI), clarity-add-feature (recipes), clarity-responsive.
---

# Clarity — Codebase Index & Navigation

Clarity is a **feature-first Clean Architecture** Flutter weather app (OpenWeatherMap
API), neumorphic "claymorphism" UI, **light-mode only**, with 29-language runtime
localization. Read this to orient before touching anything.

> Read `HANDOFF.md` at the repo root first — it carries live state, open work, and the
> gotchas that cost the most time. (`MEMORY_INDEX.md` was deleted in `5717f71`; its
> content lives in `CLAUDE_MEMORY.md`.)

## Entry points (read in this order to understand a cold start)

1. `lib/main.dart` — `main()` does: `WidgetsFlutterBinding.ensureInitialized()` →
   `initializeDateFormatting()` → `EnvConfig.load()` → `di.init(envConfig)` →
   `Localizer.init()` → `runApp`. `MyApp` wraps everything in a `SettingsBloc`
   provider + `MaterialApp.router` (locked `ThemeMode.light`).
2. `lib/core/di/injection_container.dart` — the composition root. Every dependency
   is wired here (`sl` = `GetIt.instance`).
3. `lib/core/router/app_router.dart` — `go_router` with a single `/` route that
   provides `WeatherBloc` and shows `MainScreen`.
4. `lib/features/navigation/presentation/pages/main_screen.dart` — the real UI
   shell: `PageView` (WeatherPage + ForecastPage), sliding bottom nav, app bar with
   menu + city search, and the settings→weather reload `BlocListener`.

## Full lib/ index

```
lib/
├── main.dart ............................ app bootstrap + MaterialApp.router
├── core/                                  cross-feature infrastructure
│   ├── config/env_config.dart ........... loads .env (OpenWeather API key)
│   ├── di/injection_container.dart ...... get_it composition root (`sl`)
│   ├── error/
│   │   ├── exceptions.dart ............... data-layer throwables (ApiKey/NotFound/RateLimit/Network/Server)
│   │   └── failures.dart ................ domain Failure hierarchy (Equatable) returned in Either.Left
│   ├── router/app_router.dart ........... GoRouter config
│   ├── services/location_service.dart ... GPS via geolocator (LocationService interface + Impl)
│   ├── theme/
│   │   ├── app_colors.dart ............... static color palette (light only)
│   │   └── app_theme.dart ............... ThemeData.lightTheme, Bricolage Grotesque
│   ├── usecases/usecase.dart ............ abstract UseCase<Type,Params> { call() }; NoParams
│   └── utils/
│       ├── localizer.dart ............... runtime .arb loader; Localizer.localize(key, language)
│       └── weather_icon_mapper.dart ..... WeatherIconMapper.mapCodeToCondition(): OpenWeather code (e.g. '01d') → condition string
├── features/
│   ├── navigation/presentation/pages/
│   │   ├── main_screen.dart ............. PageView shell, bottom nav, search dialog
│   │   └── menu_screen.dart ............. left drawer-style menu (Home/Settings/Profile)
│   ├── settings/
│   │   ├── domain/entities/app_settings.dart ... AppSettings (Equatable) + 3 unit enums
│   │   └── presentation/
│   │       ├── bloc/settings_bloc.dart .. (uses `part` for event/state); persists to SharedPreferences
│   │       ├── bloc/settings_event.dart . part-of settings_bloc
│   │       ├── bloc/settings_state.dart . part-of settings_bloc
│   │       └── pages/settings_page.dart . unit toggles, language dropdown, alerts switch
│   └── weather/                          the flagship feature — full clean stack
│       ├── domain/
│       │   ├── entities/weather.dart .... Weather + HourlyForecast + DailyForecast (Equatable)
│       │   ├── repositories/weather_repository.dart ... abstract interface
│       │   └── usecases/get_weather.dart ............... GetWeather + WeatherParams
│       ├── data/
│       │   ├── models/weather_model.dart ............... DTO extends Weather; fromApiResponse()
│       │   ├── datasources/weather_remote_data_source.dart ... Dio calls to OpenWeather
│       │   └── repositories/weather_repository_impl.dart ..... try/catch → Either mapping
│       └── presentation/
│           ├── bloc/weather_bloc.dart / weather_event.dart / weather_state.dart
│           ├── pages/weather_page.dart ...... "Today" tab
│           ├── pages/forecast_page.dart ..... "Forecast" tab (metrics grid, conversions)
│           └── widgets/clay_container.dart / clay_weather_icon.dart
└── l10n/ ................................ 29 app_<code>.arb translation files
```

Features present: **weather** (full stack), **settings** (domain + presentation; no
data layer — persistence lives in the BLoC via SharedPreferences), **navigation**
(presentation only — the shell).

## The one data flow (memorize this)

UI event → **BLoC** → **UseCase** (`GetWeather`) → **Repository interface** →
**RepositoryImpl** (data) → **RemoteDataSource** (`Dio`) → returns **Model** →
Repo wraps in `Either<Failure, Weather>` → BLoC `.fold`s it into `WeatherLoaded` /
`WeatherError` → UI rebuilds via `BlocBuilder` + `AnimatedSwitcher`.

Concrete trace: `main_screen.dart:34` adds `LoadInitialWeather` →
`weather_bloc.dart:_onLoadInitialWeather` (checks last city in SharedPreferences,
else GPS via `LocationService`, else falls back to `'Brooklyn'`) → `getWeather(...)`
→ `weather_repository_impl.dart:getWeatherByCoords` → `weather_remote_data_source.dart`
(geocode → current → 5-day/3-hour forecast) → `WeatherModel.fromApiResponse`.

## Conventions at a glance (details in clarity-architecture)

- **State management:** `flutter_bloc`; states are `abstract class extends Equatable`
  with subclasses (Initial/Loading/Loaded/Error), not sealed classes.
- **Errors:** never thrown across layers — repos return `Either<Failure, T>` (dartz);
  BLoC uses `result.fold((failure) => …, (data) => …)`.
- **DI:** everything registered in `injection_container.dart`. BLoCs =
  `registerFactory`; repos/usecases/datasources/services = `registerLazySingleton`.
- **i18n:** every user-facing string is `Localizer.localize('key', settings.language)`.
  Keys live in `lib/l10n/app_en.arb` (source of truth) and 28 translations.
- **UI:** neumorphic — wrap content in `ClayContainer`; colors from `AppColors`;
  motion via `AnimatedSwitcher`/`AnimatedPositioned`/`PageView`.

## Grep recipes (how to find things fast)

```bash
# Where is a BLoC event handled?
grep -rn "on<.*Event>" lib/
# Every DI registration:
grep -n "register" lib/core/di/injection_container.dart
# All user-facing strings (should all go through Localizer):
grep -rn "Localizer.localize" lib/
# Find a translation key across all languages:
grep -rn '"my_key"' lib/l10n/
# Everywhere the neumorphic container is used:
grep -rn "ClayContainer" lib/
# Hardcoded sizes (responsive debt — see clarity-responsive):
grep -rn "fontSize:\|height: [0-9]" lib/features
# Exception → Failure mapping:
grep -rn "on .*Exception" lib/features/*/data/repositories/
```

## Facts that are easy to get wrong (re-verified against the code 2026-07-21)

- There is no **`clay_containers` package** — `ClayContainer` is a **custom** widget
  (`lib/features/weather/presentation/widgets/clay_container.dart`).
- `AppColors.getSurface(isDarkMode)` **does not exist**; dark mode was removed.
  `AppColors` is static light-only; `isDarkMode` fields remain but are forced `false`.
- There are **29** `.arb` files, not "30+".
- `flutter_inset_shadow` **IS used** — imported by `clay_container.dart` to back the
  `inset: true` (sunken) variant. **Do not remove it.** (Previously documented here as
  unused; that was wrong.)
- `http`, `translator`, `lottie` were removed in `5717f71` (zero imports repo-wide).
  `dio` is the HTTP client.

When these bug you, see `clarity-architecture` / `clarity-design-system` for the
canonical current rules rather than the doc.
