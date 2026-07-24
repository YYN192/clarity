/**
 * Pure decision logic for the severe-weather dispatcher.
 *
 * Kept free of Firebase, network and env access so it can be unit-tested:
 * `index.mjs` reads secrets and calls `process.exit` at import time, which makes
 * it unimportable from a test. Both past dispatcher bugs exited 0 while sending
 * nothing, so this is the layer worth covering.
 */

/** Don't repeat the same kind of alert to a device within this window. */
export const COOLDOWN_MS = 6 * 60 * 60 * 1000;

/** Decimal places used to group nearby devices (1 ≈ 11 km). */
export const GRID_PRECISION = 1;

/**
 * Ignore devices whose position is older than this. A phone that hasn't opened
 * the app in this long may be nowhere near its stored coordinates, and alerting
 * it about a place it has left is worse than not alerting it at all.
 */
export const STALE_LOCATION_MS = 7 * 24 * 60 * 60 * 1000;

export const cap = (s) => (s ? s.charAt(0).toUpperCase() + s.slice(1) : s);

/**
 * Map OpenWeather current-weather JSON (metric units) to an alert, or null when
 * conditions are unremarkable. Condition ids: openweathermap.org/weather-conditions
 */
export function classify(w) {
  const condition = w.weather?.[0] ?? {};
  const id = condition.id ?? 0;
  const desc = condition.description ?? 'severe weather';
  const temp = w.main?.temp ?? 0; // °C
  const wind = Math.max(w.wind?.speed ?? 0, w.wind?.gust ?? 0); // m/s

  if (id === 781 || id === 900) {
    return { key: 'tornado', title: 'Tornado warning', detail: 'Tornado reported near {city}. Seek shelter immediately.' };
  }
  if (id === 901 || id === 902) {
    return { key: 'tropical-storm', title: 'Tropical storm warning', detail: 'Severe tropical conditions expected in {city}.' };
  }
  if (id >= 200 && id <= 232) {
    return { key: 'thunderstorm', title: 'Thunderstorm warning', detail: `${cap(desc)} expected in {city}.` };
  }
  if ([502, 503, 504, 522, 531].includes(id)) {
    return { key: 'heavy-rain', title: 'Heavy rain warning', detail: `${cap(desc)} in {city} — flooding possible.` };
  }
  if (id === 511 || (id >= 611 && id <= 616)) {
    return { key: 'freezing', title: 'Freezing precipitation', detail: `${cap(desc)} in {city} — icy conditions likely.` };
  }
  if (id === 602 || id === 622) {
    return { key: 'heavy-snow', title: 'Heavy snow warning', detail: `${cap(desc)} expected in {city}.` };
  }
  if ([751, 761, 762, 771].includes(id)) {
    return { key: 'atmospheric', title: 'Hazardous conditions', detail: `${cap(desc)} reported in {city}.` };
  }
  if (wind >= 17.2) {
    // 17.2 m/s ≈ Beaufort 8 (gale)
    return { key: 'high-wind', title: 'High wind warning', detail: `Winds around ${Math.round(wind * 3.6)} km/h in {city}.` };
  }
  if (temp >= 40) {
    return { key: 'extreme-heat', title: 'Extreme heat warning', detail: 'Dangerously high temperatures in {city} ({temp}).' };
  }
  if (temp <= -20) {
    return { key: 'extreme-cold', title: 'Extreme cold warning', detail: 'Dangerously low temperatures in {city} ({temp}).' };
  }
  return null;
}

/** The synthetic alert used by FORCE_ALERT when real conditions are calm. */
export const TEST_ALERT = {
  key: 'test',
  title: 'Test alert',
  detail: 'Test alert for {city} — currently {temp}. Delivery is working.',
};

/**
 * The alert to send for a cell, or null to skip it.
 *
 * In force mode a synthetic alert substitutes for "nothing to report" — without
 * this, forcing could only ever fire during real severe weather, which defeats
 * the point of a delivery test.
 */
export function alertFor(weather, { forceAlert = false } = {}) {
  return classify(weather) ?? (forceAlert ? TEST_ALERT : null);
}

/** Millisecond timestamp from a Firestore Timestamp, or null when absent. */
function toMillis(value) {
  const ms = value?.toMillis?.();
  return typeof ms === 'number' ? ms : null;
}

/**
 * True when a device's stored position is too old to alert on.
 *
 * Falls back to `updatedAt` when `locationUpdatedAt` is missing: documents
 * written before that field existed would otherwise all look stale and stop
 * receiving alerts. A device with neither timestamp is allowed through rather
 * than silently dropped.
 */
export function isLocationStale(
  device,
  { maxAgeMs = STALE_LOCATION_MS, now = Date.now() } = {},
) {
  const at = toMillis(device.locationUpdatedAt) ?? toMillis(device.updatedAt);
  if (at === null) return false;
  return now - at > maxAgeMs;
}

/** Devices that can actually be alerted: a token, real coordinates, fresh enough. */
export function selectAlertableDevices(devices, options = {}) {
  const usable = devices.filter(
    (d) => typeof d.lat === 'number' && typeof d.lon === 'number' && d.token,
  );
  const fresh = usable.filter((d) => !isLocationStale(d, options));
  return { devices: fresh, staleCount: usable.length - fresh.length };
}

/** Group devices into coarse grid cells so nearby devices share one API call. */
export function groupByGrid(devices, precision = GRID_PRECISION) {
  const groups = new Map();
  for (const device of devices) {
    const cell = `${device.lat.toFixed(precision)},${device.lon.toFixed(precision)}`;
    if (!groups.has(cell)) groups.set(cell, []);
    groups.get(cell).push(device);
  }
  return groups;
}

/** True when this device hasn't already had this alert recently. */
export function shouldSend(
  device,
  alert,
  { forceAlert = false, cooldownMs = COOLDOWN_MS, now = Date.now() } = {},
) {
  if (forceAlert) return true; // test mode bypasses the cooldown
  if (device.lastAlertKey !== alert.key) return true;
  const lastMs = toMillis(device.lastAlertAt) ?? 0;
  return now - lastMs > cooldownMs;
}

/** Notification body text, in the device's own units. */
export function buildBody(alert, device, weather) {
  const city = device.city || weather.name || 'your area';
  const celsius = weather.main?.temp ?? 0;
  const temp =
    device.units === 'imperial'
      ? `${Math.round((celsius * 9) / 5 + 32)}°F`
      : `${Math.round(celsius)}°C`;
  return alert.detail.replace('{city}', city).replace('{temp}', temp);
}
