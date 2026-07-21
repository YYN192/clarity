---
name: clarity-architecture
description: >-
  The architectural rules that keep the Clarity codebase consistent — use
  whenever writing, refactoring, or reviewing any Dart code in this repo, or when
  deciding where a class belongs. Codifies the feature-first Clean Architecture,
  layer boundaries, dartz Either error handling, get_it DI registration, and the
  flutter_bloc conventions exactly as this project already does them. Goal:
  maintain the structure the way it is. Pair with clarity-navigation (the map),
  clarity-add-feature (step-by-step), clarity-design-system, clarity-responsive.
---

# Clarity — Architecture & Structure Rules

Keep new code indistinguishable from existing code. Clarity uses **feature-first
Clean Architecture** (Reso Coder style). Match these patterns exactly; don't
introduce new state-management, error-handling, or DI approaches.

## Layer boundaries (dependencies point inward)

```
presentation ─▶ domain ◀─ data
   (BLoC/UI)   (entities,   (models, datasources,
               usecases,     repo implementations)
               repo iface)
```

Per feature: `features/<name>/{domain,data,presentation}/`.

| Layer | Folder | Contains | May import | Must NOT import |
|---|---|---|---|---|
| domain | `domain/entities`, `domain/usecases`, `domain/repositories` | `Equatable` entities, `UseCase` classes, abstract repo interfaces | `dartz`, `equatable`, core/error | `flutter`, `bloc`, `dio`, any model/DTO |
| data | `data/models`, `data/datasources`, `data/repositories` | DTO models (extend entities), `Dio` datasources, repo impls | domain, `dio`, core/error, core/config | `flutter` widgets, `bloc` |
| presentation | `presentation/bloc`, `presentation/pages`, `presentation/widgets` | BLoCs, pages, widgets | domain, `flutter`, `flutter_bloc` | `data/datasources`, models directly |

Rules:
- **UI talks to BLoC only.** A widget never calls a repository, datasource, or
  usecase directly — it `add`s an event / reads `state`.
- **BLoC depends on the UseCase** (`GetWeather`), not on the repository. (Settings is
  the deliberate exception — see below.)
- **Domain is pure Dart.** No `package:flutter`, no `dio`, no models. If you're
  importing a DTO into `domain/`, you've crossed a boundary.
- **Only entities cross out of data.** The `WeatherModel` DTO extends `Weather` and is
  returned as a `Weather` — callers never see the model type.

## Error handling — `Either<Failure, T>`, never throw across layers

This is non-negotiable and used everywhere. Pattern:

1. **Datasource** throws typed `Exception`s from `core/error/exceptions.dart`
   (`ApiKeyException`, `NotFoundException`, `RateLimitException`, `NetworkException`,
   `ServerException`). See `weather_remote_data_source.dart:_handleError`.
2. **RepositoryImpl** wraps calls in `try/catch`, maps each exception to a `Failure`
   from `core/error/failures.dart`, and returns `Either<Failure, T>`:
   ```dart
   try {
     final remote = await remoteDataSource.getWeatherByCity(city, units: units, locale: locale);
     return Right(remote);                 // Model is-a Entity → returned as Right
   } on ApiKeyException {
     return const Left(ApiKeyFailure());
   } on NotFoundException {
     return const Left(NotFoundFailure());
   } on RateLimitException {
     return const Left(RateLimitFailure());
   } on NetworkException {
     return const Left(NetworkFailure());
   } catch (e) {
     return Left(ServerFailure(e.toString()));
   }
   ```
3. **UseCase** returns the `Either` straight through (add domain validation here if
   needed — see `GetWeather` returning `Left(ServerFailure('Invalid parameters'))`).
4. **BLoC** resolves it with `.fold`:
   ```dart
   result.fold(
     (failure) => emit(WeatherError(failure.message)),
     (weather) => emit(WeatherLoaded(weather, units: units)),
   );
   ```

Every `Failure` carries a `.message`. To add a new failure type, add it to
`failures.dart` (extend `Failure`, provide a default message) **and** a matching
`Exception` + `_handleError` branch if it originates from the API.

## Use cases — the `UseCase<Type, Params>` base

`core/usecases/usecase.dart` defines:
```dart
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}
class NoParams {}
```
A use case is a class with a single `call(params)`. Params are an `Equatable` class
(see `WeatherParams`). Use `NoParams` when there are no inputs. Invoke as a function:
`await getWeather(WeatherParams(...))`.

## BLoC conventions

- `Bloc<Event, State>`; register handlers in the constructor with
  `on<SomeEvent>(_onSomeEvent)`. Handlers are `Future<void> _onX(Event, Emitter)`.
- **States**: `abstract class XState extends Equatable` with a `const` ctor and
  `props`, plus concrete subclasses (`XInitial`, `XLoading`, `XLoaded`, `XError`).
  This project does **not** use Dart `sealed` classes for states — follow the
  Equatable pattern already in `weather_state.dart` for consistency.
- **Events**: same Equatable style (`weather_event.dart`). Settings uses the
  `part`/`part of` single-file style (`settings_bloc.dart` with
  `part 'settings_event.dart';`) — either style is acceptable; match the feature
  you're in.
- Emit `Loading` before async work, then `Loaded`/`Error`.
- **Cross-BLoC reaction** goes through `BlocListener`, not direct calls — see
  `main_screen.dart` where a settings change (unit/language) triggers a weather
  refetch via `listenWhen` + `context.read<WeatherBloc>().add(...)`.

### The Settings exception
`SettingsBloc` has **no data/domain repository** — it reads/writes SharedPreferences
directly with string keys (`'setting_language'`, `'setting_temp_unit'`, …) in
`_loadSettings`/`_onUpdateSettings`. This is the established pattern for simple
local prefs; don't build a full clean stack for settings unless it grows. If you add
persisted settings, add a key constant and read/write it in both methods.

## Dependency injection — `injection_container.dart` is the only wiring place

`sl = GetIt.instance`. Registration rules (follow exactly):
- **BLoCs** → `sl.registerFactory(() => XBloc(dep: sl(), ...))` (fresh instance per use).
- **UseCases, Repositories, DataSources, Services** → `sl.registerLazySingleton(...)`.
  Register interfaces by their abstract type: `sl.registerLazySingleton<WeatherRepository>(() => WeatherRepositoryImpl(remoteDataSource: sl()))`.
- **External singletons** (`SharedPreferences`, `Dio`, `EnvConfig`) are registered in
  the `//! External` / top section; `SharedPreferences` is awaited.
- Sections are delimited by `//! Features - X`, `//! Core`, `//! External` comments —
  keep that layout.
- A BLoC is provided to the widget tree via `BlocProvider(create: (_) => sl<XBloc>())`
  (see `app_router.dart` for `WeatherBloc`, `main.dart` for `SettingsBloc`).

## Naming & file conventions

- Files `snake_case.dart`; one primary class per file; classes `PascalCase`.
- Per feature: `<feature>_bloc.dart`, `<feature>_event.dart`, `<feature>_state.dart`,
  `<feature>_page.dart`, entities in `domain/entities/<entity>.dart`, DTO in
  `data/models/<entity>_model.dart` named `<Entity>Model`, repo interface
  `<Feature>Repository`, impl `<Feature>RepositoryImpl`, datasource
  `<Feature>RemoteDataSource`(+`Impl`), usecase a verb (`GetWeather`).
- Import within a feature with relative paths (`../../domain/...`); the codebase does
  not use package: imports for its own files.

## Anti-patterns to reject in review (all currently avoided — keep it that way)

- A widget importing anything from `data/` or calling a usecase/repo directly.
- Throwing an exception out of a repository or usecase instead of returning `Left`.
- A hardcoded user-facing string not wrapped in `Localizer.localize`.
- A new dependency created with `new`/constructor in a widget instead of via `sl`.
- Domain code importing `flutter`, `dio`, or a model.
- Using `dynamic` for a typed entity (there are a couple in `forecast_page.dart`
  helpers — do not copy that; type them as `Weather`/`DailyForecast`).
