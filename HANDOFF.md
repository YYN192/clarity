# Clarity — Session Handoff

**Last updated:** 2026-07-21 · **Commit:** `f4186a0` · **Remote:** `github.com/YYN192/clarity` (in sync)
**Health:** `flutter analyze` → *No issues found*. App builds and runs on the Android emulator.

Read this first, then `AGENTS.md` (graph tooling) and `CLAUDE_MEMORY.md` (deep architecture).

---

## 1. Current state — what actually works

| Area | Status |
|---|---|
| Android build & run | ✅ Verified on emulator (real weather rendering) |
| Firebase project | ✅ `clarity-d3d92`, configured for iOS/Android/Web |
| Auth: email/password, Google, anonymous | ✅ Wired; Google verified end-to-end on Android |
| FCM push (client side) | ✅ Token generated, stored in Firestore, verified |
| Firestore | ✅ DB created, rules published for `fcm_tokens` |
| Alert backend (GitHub Actions) | ✅ **Delivery proven end-to-end** — forced alert reached the emulator tray (run `29829775305`) |
| Alert secrets | ✅ `FIREBASE_SERVICE_ACCOUNT` + `OPENWEATHER_API_KEY` set; verified via `gh secret list` |
| iOS push | ❌ **Impossible** — user has no Apple Developer account |
| Tests | ❌ None written |

---

## 2. Pending work — RANKED

**The user's stated #1 priority was: get real push notifications reaching phones in areas
with extreme weather.** That is now **achieved** — see P0 below. The remaining P0 item is
0.5 (register a real device). **P1 is the current mission.**

### ✅ P0 — DONE 2026-07-21. Alerts fire and reach devices.

Delivery is proven end-to-end. Getting there took fixing **two code bugs**, not just
adding the secrets — the dispatcher had never completed a single run.

| # | Task | Status |
|---|---|---|
| 0.1 | Add 2 GitHub repo secrets | ✅ Both set; `gh secret list` confirms exact names |
| 0.2 | Prove delivery with a forced test | ✅ Run `29829775305` → `sent 1`; notification confirmed in the emulator tray via `dumpsys notification` |
| 0.3 | Verify a real classification | ✅ `dry_run` on `main` → `1 device … Los Altos: clear … sent 0` |
| 0.4 | Confirm background delivery | ✅ App backgrounded with `KEYCODE_HOME` (process alive), alert arrived as an OS tray notification, not a SnackBar |
| 0.5 | **Register a second real device** | ⬜ **STILL OPEN** — only the emulator is registered; multi-device grouping remains unproven |

**Two bugs fixed to get here** (both silent — the workflow exited 0 while sending nothing):

1. `9830a79` — `index.mjs` used the legacy `admin.*` namespace API while `package.json`
   pins `firebase-admin ^14.2.0`, which removed it from the ESM default export.
   `admin.credential`, `admin.firestore`, `admin.messaging` are all `undefined` on v14.
   Crashed at startup; four call sites, not just the one in the traceback.
2. `f4186a0` — `FORCE_ALERT` was only read inside `shouldSend()`, which runs *after*
   `main()` has already `continue`d past any cell where `classify()` returned `null`.
   It bypassed the cooldown but never the classification, so in calm weather it was a
   no-op that still logged `clear … sent 0`.

**Known weaknesses — now live and worth addressing (still P0-adjacent):**
- **Stale coordinates** — `updateLocation` only runs when weather loads (app opened). A phone
  that hasn't opened the app in a week has week-old coordinates. Consider refreshing on
  app resume, or storing a `locationUpdatedAt` and skipping devices that are too stale.
- **Thresholds are untested against real severe weather.** `classify()` in
  `tools/weather-alerts/index.mjs` is a first pass (condition ids + wind ≥17.2 m/s + temp
  ≥40/≤-20). Tune once you see real firings.
- **Current conditions ≠ forecast.** This alerts on weather happening *now*, not incoming.
  Upgrading to One Call 3.0 `alerts` (real government warnings) is ~15 lines but needs a card.
- **GitHub disables scheduled workflows after 60 days of repo inactivity.**

### 🟠 P1 — Correctness/safety issues that will bite
| # | Task | Why it matters |
|---|---|---|
| 1.1 | **Night icons render as a sun** | `WeatherIconMapper` emits `'Clear Night'`/`'Partly Cloudy Night'`; `ClayWeatherIcon` has no cases → falls through to sunny. Visible daily bug. |
| 1.2 | **Bundle id `com.example.clarity`** | Google Play **rejects** `com.example.*`. Blocks release. Changing it requires re-running `flutterfire configure`. |
| 1.3 | **No tests at all** | `detect-changes` already flags: AppColors, _MainScreenState, MenuScreen, SettingsPage, WeatherPage untested (risk 0.35). |

### 🟡 P2 — Cleanup / consistency
| # | Task |
|---|---|
| 2.1 | Remove unused deps: `http`, `translator`, `lottie` (imported nowhere). |
| 2.2 | Settings toggle still uses bright `functionalBlue` — user rejected that blue on profile. Switch to `cloudShadow` slate. |
| ~~2.3~~ | ~~Delete stale `MEMORY_INDEX.md`~~ — ✅ done `5717f71` (content was fully covered by `CLAUDE_MEMORY.md`). |

### 🟢 P3 — Enhancements
| # | Task |
|---|---|
| 3.1 | Tablet/desktop master-detail (`main_screen.dart` uses `PageView` at all widths; see `clarity-responsive`). |
| 3.2 | Guest → real account linking (anonymous upgrade flow). |
| 3.3 | Real Google logo asset on the login button (currently `Icons.g_mobiledata_rounded`). |
| 3.4 | Saved-locations feature (the Stitch mockup showed it; app only stores one `last_selected_city`). |

### ⚪ P4 — Won't do / blocked indefinitely
- **iOS push** — needs a paid Apple Developer account. User doesn't have one. Don't propose APNs work.
- **Cloud Functions backend** — needs Blaze + credit card. User chose GitHub Actions.

### Testing the alert pipeline (added for exactly this purpose)
```bash
# locally, from tools/weather-alerts/ (needs the two env vars set):
DRY_RUN=1     node index.mjs   # log what would be sent, send nothing
FORCE_ALERT=1 node index.mjs   # push a test alert regardless of weather
```
Or from the Actions tab — *Run workflow* exposes both as checkboxes.

`gh` is installed and authed (scopes `repo`, `workflow`), so the fastest loop is the CLI:
```bash
gh workflow run "Severe weather alerts" --ref main -f dry_run=true  -f force_alert=false
gh workflow run "Severe weather alerts" --ref main -f dry_run=false -f force_alert=true
RID=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch $RID --exit-status
gh run view  $RID --log-failed          # or --log for the full output
gh secret list                          # names + timestamps only, never values
```

Confirm a push actually landed (don't trust `sent 1` alone — that only means FCM accepted it):
```bash
adb shell dumpsys notification --noredact | grep -A30 "pkg=com.example.clarity" \
  | grep -E "android\.(title|text)"
```

### Deliberately deferred (decided, don't relitigate)
- **One Call 3.0 alerts** — the alert backend classifies severity from the *free* 2.5 API
  (condition ids + wind/temp thresholds). Real government-issued alerts need a One Call
  subscription with a card. User chose free. ~15-line swap in `fetchWeather`/`classify` if revisited.
- **Backend host** — user chose GitHub Actions cron over Cloud Functions (avoids the Blaze
  plan / credit card). Same script would run on a Raspberry Pi via cron.
- **Profile stat grid** — the Stitch mockup showed *fabricated* stats (342 Days Active,
  128 Reports Shared, 94% Forecast Accuracy, 12 Badges). Those are replaced with **real**
  values (Days Active from `createdAt`, Language, Units, Alerts) to avoid showing users fake
  data. Offer to revert only if asked.

---

## 3. Gotchas that will cost you hours (learned the hard way)

### code-review-graph
- **`callees_of` on a class or method ALWAYS returns 0 for Dart.** CALLS edges use the
  **file** as `source_qualified` (no `::Class.method`). Query the **file path** instead:
  `query callees_of "lib/features/weather/presentation/bloc/weather_bloc.dart"` → 15 results.
- **Bare names are ambiguous** — `callers_of "WeatherBloc"` returns `status: ambiguous`
  (FTS matches the class *and* its methods). Pass the full qualified name.
- Only **24%** of CALLS targets resolve to real nodes (Dart 27%); the rest are bare
  names like `WeatherError`, `emit`, `fold`.
- **Communities are directory-based, not feature-based.** There is ONE `lib/features`
  community (182 nodes, misleadingly named `pages-weather`) containing auth+weather+
  settings+navigation, and one `lib/core`. Do not expect per-feature clusters.
- **"0 cross-community edges" is an artifact, not decoupling.** All 82 `File` nodes have
  `community_id = NULL`, and `IMPORTS_FROM` edges are File→File, so no edge ever has two
  community-assigned endpoints. Coupling warnings structurally cannot fire.
- **MCP tools need a restart *in this directory*.** `.mcp.json` is read from the directory
  the session starts in, and it lives at the repo root — there is no `~/.mcp.json`. A session
  started in `~` (or anywhere else) silently gets **no** graph tools no matter how many times
  you restart. Launch with `cd ~/StudioProjects/clarity && claude`. If they're still missing,
  the CLI has every equivalent: `search`, `query`, `impact`, `communities`, `architecture`,
  `detect-changes`, `dead-code` — all read the same `graph.db`.
- `detect-changes` previously reported risk 0.00 because the repo had one commit
  (`HEAD~1` didn't resolve). There are 3 commits now, so it works.

### Alert pipeline (learned proving P0)
- **`firebase-admin` v13+ removed the `admin.*` namespace API from the ESM default export.**
  `import admin from 'firebase-admin'` gives you `initializeApp`/`cert` but **not**
  `.credential`, `.firestore` or `.messaging`. Use the modular sub-paths
  (`firebase-admin/app`, `/firestore`, `/messaging`). Verify against a real install before
  believing any snippet — most examples online are v11/v12 and will crash on v14.
- **A green workflow run does not mean a notification was sent.** Both bugs above exited 0.
  Always read the tail of the log for `sent N`, and confirm on the device with `dumpsys`.
- **`sent 1` only means FCM *accepted* the message**, not that it rendered. Check the device.
- **Foreground vs background matters.** With the app foregrounded you get an in-app SnackBar
  and *no* tray entry. Background it with `adb shell input keyevent KEYCODE_HOME` — never
  `am force-stop`, which kills the process (and any `flutter run`) and exits 0.
- **The 6h cooldown is per `{device, alert.key}`.** `force_alert` uses key `test`, so it never
  collides with a real alert's cooldown — repeated forced tests always fire.
- **GitHub cron does not start immediately** after a workflow file first lands; the first
  scheduled run can be missed entirely. Use `workflow_dispatch` to test, never wait on cron.
- **`gh workflow run --ref <branch>`** dispatches on any branch, but the `*/30` **schedule only
  runs on the default branch** — a fix sitting on a feature branch does nothing for real alerts.

### Android / emulator
- `adb`, `emulator`, `flutter` are **not on the user's fish PATH**. Use full paths:
  `~/Library/Android/sdk/platform-tools/adb`, or run
  `fish_add_path ~/Library/Android/sdk/platform-tools ~/Library/Android/sdk/emulator`.
- Launching an AVD that's already running gives a **FATAL "same AVD"** error. Check
  `adb devices` first — Android Studio runs it headless (`-qt-hide-window`) and mirrors it.
- `adb shell am force-stop <pkg>` also **terminates `flutter run`** (it exits 0).
- Grant permissions without dialogs: `adb shell pm grant com.example.clarity android.permission.ACCESS_FINE_LOCATION`
  (also `ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS`).
- Set a GPS fix: `adb emu geo fix -122.084 37.422`.
- `E/GoogleApiManager: SecurityException: Unknown calling package name 'com.google.android.gms'`
  is **benign emulator noise**, not an app bug.

### Build/runtime landmines already fixed — don't reintroduce
- `geocoding: ^2.1.1` broke the Android build (`:geocoding_android` compiled against
  android-33 while its AndroidX deps require 34+). It was **unused** and got removed.
  `geolocator` is safe — it uses `compileSdk flutter.compileSdkVersion`.
- `AndroidManifest.xml` had **no permissions at all**. `INTERNET` was only in the *debug*
  manifest, so release builds would have had no network. Now declares INTERNET +
  ACCESS_FINE/COARSE_LOCATION + POST_NOTIFICATIONS.
- `minSdk` is fine — `flutter.minSdkVersion` = 24, and `firebase_auth` needs ≥ 23.

### Design system
- `AppColors.shadowLight` is **45% white** (`Color(0x73FFFFFF)`), not opaque. Opaque white
  is invisible on cream but glows harshly onto dark surfaces. Don't "fix" it back.
- `ClayContainer(inset: true)` gives the **sunken** variant (backed by `flutter_inset_shadow`).
  Raised outer + sunken inner chips is the core clay contrast.
- The raised highlight reaches ~25px — keep ≥28px between a clay surface and any dark element.
- Primary buttons use the **muted slate** `AppColors.cloudShadow`, never `functionalBlue`.

---

## 4. Architecture quick reference

`presentation → domain ← data`, feature-first, `Either<Failure,T>` everywhere, GetIt `sl`
in `injection_container.dart` (BLoCs = `registerFactory`, rest = `registerLazySingleton`).
All user-facing strings via `Localizer.localize(key, language)` with keys in `lib/l10n/app_en.arb`.

**Alert pipeline (the newest, least obvious subsystem):**
```
toggle ON → NotificationService.enable() → permission → FCM token
          → Firestore fcm_tokens/{token} {uid, platform, lat, lon, city, units, lang}
WeatherBloc._emitLoaded() → updateLocation() keeps lat/lon fresh
GitHub Actions (*/30) → tools/weather-alerts/index.mjs
          → group by ~11km grid → OpenWeather 2.5 → classify → 6h cooldown → Admin SDK push
```
Foreground messages → in-app SnackBar (global `scaffoldMessengerKey`).
Background/terminated → OS tray (automatic).

---

## 5. How to verify you haven't broken anything

```bash
flutter analyze                      # must be "No issues found!"
code-review-graph status             # graph health
code-review-graph detect-changes     # risk-scored diff (works now)
flutter run -d emulator-5554         # needs an emulator already booted
```

Secrets check before any push:
```bash
git check-ignore -v assets/.env      # must be ignored
git ls-files | grep -iE "\.env|serviceaccount|adminsdk"   # must be empty
```

---

## 6. Skills to load

`clarity-architecture` first for any Dart. Then `clarity-add-feature` (new code),
`clarity-design-system` + `clarity-responsive` (UI), `clarity-navigation` (finding things).
Full list in `AGENTS.md`.
