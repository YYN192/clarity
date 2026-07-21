# Clarity Weather - Comprehensive Developer Guide & Memory Index

## 🌍 Project Purpose
**Clarity** is a high-fidelity Flutter weather application built with a **Neumorphic (Soft UI)** design language. It focuses on delivering real-time weather, hourly/daily forecasts, and severe alerts with extreme visual polish and a "Motion as Language" philosophy.

---

## 🏗️ Architecture: Feature-First Clean Architecture
This project follows **Reso Coder's Clean Architecture** standard, strictly separating Business Logic (Domain) from Implementation (Data) and UI (Presentation).

### 1. Layered Structure (The "Onion")
Dependencies only point **inward** toward the Domain.

- **Domain Layer (The Core)**:
    - **Entities**: Plain Dart objects representing business data (e.g., `Weather`). Must use `Equatable`.
    - **Use Cases**: Single-task classes (e.g., `GetWeather`). Standardized by the `UseCase` base class in `lib/core/usecases/`.
    - **Repositories (Contracts)**: Abstract interfaces defining data requirements.
- **Data Layer (Implementation)**:
    - **Models**: DTOs extending Entities. Responsible for JSON serialization (`fromJson`).
    - **Repositories (Implementation)**: Concrete logic that orchestrates Data Sources (Remote/Local) and handles error catching.
    - **Data Sources**: Low-level clients for API (`Dio`) or Persistence (`SharedPreferences`).
- **Presentation Layer (UI & State)**:
    - **BLoC**: Manages state by accepting **Events** and emitting **States**.
    - **Pages/Widgets**: UI components that react to BLoC states.

### 2. Standardized Data Flow
1. **UI** dispatches an **Event** to **BLoC**.
2. **BLoC** calls a **UseCase** (Domain).
3. **UseCase** calls a **Repository Interface** (Domain).
4. **Repository Implementation** (Data) fetches data from a **DataSource** (API/Cache).
5. **DataSource** returns a **Model** (Data).
6. **Repository** returns the data as an **Entity** (Domain) wrapped in an `Either<Failure, T>`.
7. **BLoC** emits a new **State** with the Entity.
8. **UI** rebuilds.

---

## 🛠️ Tech Stack & Key Libraries
- **State Management**: `flutter_bloc`
- **Functional Programming**: `dartz` (specifically for the `Either` type in error handling).
- **Dependency Injection**: `get_it` (centralized in `lib/core/di/injection_container.dart`).
- **Navigation**: `go_router` (configured in `lib/core/router/`).
- **Design System**: Neumorphic elements powered by `clay_containers`.
- **Typography**: `google_fonts` (Bricolage Grotesque).
- **Persistence**: `shared_preferences`.
- **Networking**: `dio`.

---

## 📝 Coding Conventions & Best Practices

### 1. Error Handling (Functional Approach)
We **do not** throw exceptions in repositories or use cases. Instead, we return an `Either<Failure, T>`.
- **Left**: `Failure` (e.g., `ServerFailure`, `NetworkFailure` defined in `lib/core/error/failures.dart`).
- **Right**: The success data (`T`).
- **Usage in BLoC**:
  ```dart
  final result = await getWeather(params);
  result.fold(
    (failure) => emit(WeatherError(failure.message)),
    (weather) => emit(WeatherLoaded(weather)),
  );
  ```

### 2. Dependency Injection (DI)
Every new service, repository, use case, or BLoC **must** be registered in `lib/core/di/injection_container.dart`.
- Use `registerFactory` for BLoCs (needs new instance per use).
- Use `registerLazySingleton` for Repositories, Use Cases, and Data Sources.

### 3. Neumorphic UI Design
Maintain the "Soft UI" look using:
- **Surfaces**: `AppColors.getSurface(isDarkMode)`.
- **Containers**: Use `ClayContainer` with appropriate `spread`, `depth`, and `borderRadius`.
- **Interactions**: Sliding "pills" for toggles and navigation indicators.

### 4. Motion as Language
Animations are first-class citizens:
- **Page Transitions**: Use `PageView` for horizontal sliding between main screens.
- **Content Transitions**: Use `AnimatedSwitcher` for fading between Loading and Loaded states.
- **Edge Polishing**: Use `ShaderMask` with `LinearGradient` for smooth fades on the edges of lists. 
    - *Best Practice*: Always wrap the `SizedBox` (the viewport) with the `ShaderMask`, and avoid `Clip.none` on the child `ListView` to prevent sharp vertical artifacts during scrolling.

---

## 🌐 Localization & Global Settings
- **Crowdin Integration**: The project uses Crowdin for automated translations.
    - **Config**: `crowdin.yml` in the project root.
    - **CLI Commands**: Use `crowdin push` to upload sources and `crowdin pull` to fetch translations.
    - **Source File**: `lib/l10n/app_en.arb`.
- **Localizer**: A dynamic `Localizer` class (`lib/core/utils/localizer.dart`) loads `.arb` files from the `lib/l10n/` directory at runtime.
    - **Initialization**: `Localizer.init()` is called in `main.dart` to preload all available translations into memory.
- **Settings**: `SettingsBloc` persists units and language preferences.

---

## 📁 Key File Locations
- **Core Infrastructure**: `lib/core/`
    - `theme/`: `AppColors` and `AppTheme`.
    - `error/`: Base `Failure` and `Exception` classes.
    - `utils/`: `Localizer` and formatting helpers.
    - `di/`: `injection_container.dart`.
- **Feature Template**: `lib/features/<name>/`
    - `domain/entities/`, `domain/usecases/`, `domain/repositories/`
    - `data/models/`, `data/repositories/`, `data/datasources/`
    - `presentation/bloc/`, `presentation/pages/`, `presentation/widgets/`

---

## 🚀 Recent Changes & Roadmap
- ✅ Locked app into **Light Mode** (removed Dark/System mode support).
- ✅ Reverted ThemeExtension architecture to static color helpers in `AppColors`.
- ✅ Kept Crowdin CLI automation and dynamic `Localizer` for 30+ languages.
- ✅ Kept High/Low temperature data mapping fixes in `WeatherModel`.
- ✅ Kept all layout and clipping fixes (horizontal list padding and adaptive metric cards).
- ✅ Protected "Clarity" brand name across all translations.

---

## 🎨 Design Philosophy: "Tactile Clarity"
Clarity follows a **Tactile Neumorphic** design philosophy.
1.  **Depth as State**: Interactive elements should feel like they exist in 3D space.
    - **Idle State**: Raised above the surface (outer shadows).
    - **Selected/Pressed State**: Embossed into the surface (inner shadows).
2.  **Harmonious Palette**: Avoid pure black (`#000000`) or pure white for surfaces. Use tinted grays to allow shadows to "breathe".
3.  **Unobstructed Shadows**: Shadows are as important as the widgets themselves. Viewports must have enough padding to allow shadows to paint fully without being clipped.
4.  **Semantic Hierarchy**: Use Material 3 semantic roles (`onSurface`, `onSurfaceVariant`) for text to ensure legibility across all theme modes.
- 🚧 Planned: Persistent city search history.
- 🚧 Planned: Interactive weather map using MapBox/Google Maps.
