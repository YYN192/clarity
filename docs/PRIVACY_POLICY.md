---
layout: default
title: Privacy Policy
---

# Privacy Policy — Clarity

**Last updated: 24 July 2026**

Clarity is a weather app that shows current conditions and forecasts, and can
send severe-weather alerts for where your device is. This policy explains what
it collects, why, and what you can do about it.

**Contact:** [clarity.weather.app@gmail.com](mailto:clarity.weather.app@gmail.com)

## What Clarity collects

**Location.** With your permission, Clarity reads your device's location to show
local weather and to decide which severe-weather alerts apply to you. Your
coordinates are stored in Clarity's backend (Google Firebase Cloud Firestore)
alongside your device's notification token so alerts can be targeted. Location
is only read while you are using the app; Clarity does not track you in the
background.

If you deny location access, the app still works — it falls back to a default
city and to cities you search for. Severe-weather alerts will not be
location-accurate without it.

**Account information.** If you create an account or sign in with Google,
Firebase Authentication stores your email address and, where you provide one, a
display name. You may instead use Clarity as a guest, which creates an anonymous
account identified only by a random id.

**Saved cities.** Cities you bookmark are stored against your account so they
appear on your other devices.

**Notification token.** If you enable severe-weather alerts, Clarity stores the
push token Google issues for your device, together with the coordinates, units
and language needed to send you a correctly formatted alert.

Clarity does **not** collect contacts, photos, files, browsing history,
advertising identifiers, or payment information. There is no advertising and no
analytics or tracking SDK.

## Why it collects it

Solely to provide the app's features: showing weather where you are, letting you
save cities across devices, and delivering severe-weather warnings. Your data is
not sold, rented, or shared for advertising, and is not used to build a profile
of you.

## Who else is involved

- **Google Firebase** (Authentication, Cloud Firestore, Cloud Messaging) — stores
  your account, saved cities and notification token. See Google's privacy policy
  at https://policies.google.com/privacy
- **OpenWeather** — receives coordinates or a city name in order to return
  weather data. See https://openweather.co.uk/privacy-policy

Requests to OpenWeather carry location but no account identifier, so weather
lookups are not linked to your identity by that provider.

## How long it is kept

Account data and saved cities are kept until you delete your account or ask for
them to be removed. Notification tokens are removed when you turn alerts off,
uninstall the app, or when a delivery attempt shows the token is no longer valid.

## Your choices

- **Location:** revoke at any time in Android Settings → Apps → Clarity →
  Permissions. The app continues to work.
- **Notifications:** turn severe-weather alerts off inside the app, or mute the
  "Severe weather alerts" channel in Android's notification settings.
- **Account and data deletion:** email the address above and your account,
  saved cities and notification tokens will be deleted. Uninstalling removes
  local data but not data already stored against your account.

## Children

Clarity is not directed at children under 13 and does not knowingly collect
their personal information.

## Security

Data in transit uses HTTPS. Data at rest is held in Google Firebase under access
rules that restrict each user's records to that user; notification tokens are not
readable by clients at all.

## Changes

Material changes will be reflected here with an updated date. Continuing to use
Clarity after a change means you accept the revised policy.
