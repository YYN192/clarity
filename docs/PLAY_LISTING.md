# Play Console submission pack — Clarity

Everything the Console asks for that isn't code. Drafts to paste and adjust;
the Data safety answers must match what the app actually does, and they do as
of this commit — re-check them if the data model changes.

## Build

| Field | Value |
|---|---|
| Application id | `dev.glocean.clarity` (permanent — cannot change after publish) |
| Artifact | `build/app/outputs/bundle/release/app-release.aab` |
| Build command | `flutter build appbundle --release` |
| Signing | upload keystore, `android/key.properties` (gitignored — **back it up**) |
| Version | `1.0.0+1` from `pubspec.yaml` (`versionName+versionCode`) |

Bump `version:` in `pubspec.yaml` for every upload — Play rejects a repeated
`versionCode`.

## Store listing

**App name (≤30):**
`Clarity — Weather & Alerts`

**Short description (≤80):**
`Calm, clear weather with severe-weather alerts for wherever you are.`

**Full description (≤4000):**

```
Clarity is a weather app with a calm, tactile design and one job it takes
seriously: telling you when the weather turns dangerous.

CURRENT CONDITIONS AND FORECAST
See temperature, conditions, wind, humidity, pressure, visibility and more for
your location — plus an hourly outlook and a seven-day forecast.

SEVERE WEATHER ALERTS
Turn on alerts and Clarity watches conditions where your device actually is.
Thunderstorms, heavy rain, snow, freezing precipitation, gale-force winds and
extreme heat or cold trigger a push notification, delivered to their own
notification channel so you can control them separately from everything else.

SEARCH ANY CITY
Type a few letters and pick from suggestions, disambiguated by region and
country — so you get the right Springfield. Bookmark the cities you care about
and they follow your account to every device you sign in on.

DESIGNED, NOT DECORATED
A soft neumorphic interface that stays legible in daylight, with layouts that
adapt from small phones to tablets and desktops.

YOUR LANGUAGE
Available in 29 languages.

PRIVACY
No ads, no analytics, no tracking. Location is used to show your weather and to
target severe-weather alerts — nothing else. You can use Clarity as a guest and
upgrade to a full account later without losing your saved cities.
```

**Category:** Weather · **Content rating:** Everyone · **Contains ads:** No ·
**In-app purchases:** No

**Assets still needed (not in repo):**
- App icon 512×512 PNG (derive from `assets/app_icon.png`)
- Feature graphic 1024×500
- ≥2 phone screenshots; add 7" / 10" tablet shots to list as tablet-supported —
  the wide master-detail layout is worth showing
- Privacy policy URL — **https://yyn192.github.io/clarity/PRIVACY_POLICY.html** (live; served by GitHub Pages from `main/docs`)

## Data safety form

Declare **collected and linked to the user**, none of it for advertising, all of
it "required" except where noted. No data is shared with third parties for
their own purposes; processors (Firebase, OpenWeather) are not "sharing" under
Play's definition.

| Data type | Collected | Linked | Purpose | Optional? |
|---|---|---|---|---|
| Approximate location | Yes | Yes | App functionality | Yes — app works without it |
| Precise location | Yes | Yes | App functionality | Yes — app works without it |
| Email address | Yes | Yes | Account management | Yes — guest mode available |
| User IDs | Yes | Yes | Account management, app functionality | No |
| Other (saved cities) | Yes | Yes | App functionality, personalisation | Yes |

Also answer:
- **Encrypted in transit:** Yes (HTTPS throughout)
- **Users can request deletion:** Yes — via the contact address in the policy
- **Data collected for advertising or analytics:** No

**Location permission declaration:** Clarity requests foreground location only
(`ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`) to show local weather and
target severe-weather alerts. It does **not** request background location, so
the background-location declaration form does not apply.

## Pre-launch checks

- [ ] `flutter analyze` clean and `flutter test` green (CI enforces both)
- [ ] `version:` bumped in `pubspec.yaml`
- [ ] Signed AAB built and `jarsigner -verify` reports `jar verified`
- [ ] Privacy policy URL entered in the Console: `https://yyn192.github.io/clarity/PRIVACY_POLICY.html`
- [ ] `clarity.weather.app@gmail.com` mailbox actually exists and is monitored — the policy promises deletion requests are honoured there
- [ ] Alerts verified end-to-end after any application-id change — an id change
      invalidates every existing notification token
- [ ] Firestore rules deployed (`firebase deploy --only firestore:rules`)
