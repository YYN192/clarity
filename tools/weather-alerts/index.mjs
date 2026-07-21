/**
 * Clarity — severe weather alert dispatcher.
 *
 * Runs on a schedule (GitHub Actions). For every device registered in the
 * `fcm_tokens` Firestore collection with alerts enabled and a known location:
 *   1. group devices by a coarse lat/lon grid (so a city = one API call)
 *   2. fetch current conditions from OpenWeather (free /data/2.5/weather)
 *   3. classify severity from the condition id + wind/temperature thresholds
 *   4. skip anything already sent recently (dedupe)
 *   5. push via Firebase Admin, and prune tokens the device has unregistered
 *
 * Secrets (env): OPENWEATHER_API_KEY, FIREBASE_SERVICE_ACCOUNT (service-account JSON).
 */
import admin from 'firebase-admin';

const OPENWEATHER_API_KEY = process.env.OPENWEATHER_API_KEY;
const FIREBASE_SERVICE_ACCOUNT = process.env.FIREBASE_SERVICE_ACCOUNT;

if (!OPENWEATHER_API_KEY || !FIREBASE_SERVICE_ACCOUNT) {
  console.error('Missing OPENWEATHER_API_KEY and/or FIREBASE_SERVICE_ACCOUNT env vars.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(FIREBASE_SERVICE_ACCOUNT)),
});

const db = admin.firestore();
const messaging = admin.messaging();

const COLLECTION = 'fcm_tokens';
/** Don't repeat the same kind of alert to a device within this window. */
const COOLDOWN_MS = 6 * 60 * 60 * 1000;
/** Decimal places used to group nearby devices (1 ≈ 11 km). */
const GRID_PRECISION = 1;

const cap = (s) => (s ? s.charAt(0).toUpperCase() + s.slice(1) : s);

/**
 * Map OpenWeather current-weather JSON (metric units) to an alert, or null when
 * conditions are unremarkable. Condition ids: openweathermap.org/weather-conditions
 */
function classify(w) {
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

async function fetchWeather(lat, lon) {
  const url =
    `https://api.openweathermap.org/data/2.5/weather` +
    `?lat=${lat}&lon=${lon}&units=metric&appid=${OPENWEATHER_API_KEY}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`OpenWeather responded ${res.status}`);
  return res.json();
}

/** True when this device hasn't already had this alert recently. */
function shouldSend(device, alert) {
  if (device.lastAlertKey !== alert.key) return true;
  const lastMs = device.lastAlertAt?.toMillis?.() ?? 0;
  return Date.now() - lastMs > COOLDOWN_MS;
}

function buildBody(alert, device, weather) {
  const city = device.city || weather.name || 'your area';
  const celsius = weather.main?.temp ?? 0;
  const temp =
    device.units === 'imperial'
      ? `${Math.round((celsius * 9) / 5 + 32)}°F`
      : `${Math.round(celsius)}°C`;
  return alert.detail.replace('{city}', city).replace('{temp}', temp);
}

async function sendTo(device, alert, weather) {
  try {
    await messaging.send({
      token: device.token,
      notification: { title: alert.title, body: buildBody(alert, device, weather) },
      data: { type: 'severe_weather', key: alert.key },
      android: { priority: 'high' },
    });
    await db.collection(COLLECTION).doc(device.id).update({
      lastAlertKey: alert.key,
      lastAlertAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return true;
  } catch (err) {
    const code = err.errorInfo?.code ?? err.code ?? '';
    if (code.includes('registration-token-not-registered') || code.includes('invalid-argument')) {
      // The app was uninstalled or the token rotated — stop tracking it.
      console.log(`  pruning dead token ${device.id.slice(0, 12)}…`);
      await db.collection(COLLECTION).doc(device.id).delete().catch(() => {});
    } else {
      console.error(`  send failed: ${err.message}`);
    }
    return false;
  }
}

async function main() {
  const snapshot = await db
    .collection(COLLECTION)
    .where('severeWeatherAlerts', '==', true)
    .get();

  const devices = snapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((d) => typeof d.lat === 'number' && typeof d.lon === 'number' && d.token);

  if (devices.length === 0) {
    console.log('No registered devices with a known location — nothing to do.');
    return;
  }

  // Group by coarse grid cell so nearby devices share a single API call.
  const groups = new Map();
  for (const device of devices) {
    const cell = `${device.lat.toFixed(GRID_PRECISION)},${device.lon.toFixed(GRID_PRECISION)}`;
    if (!groups.has(cell)) groups.set(cell, []);
    groups.get(cell).push(device);
  }

  console.log(`${devices.length} device(s) across ${groups.size} location(s).`);

  let sent = 0;
  let skipped = 0;

  for (const [cell, group] of groups) {
    const [lat, lon] = cell.split(',');
    let weather;
    try {
      weather = await fetchWeather(lat, lon);
    } catch (err) {
      console.error(`${cell}: weather lookup failed — ${err.message}`);
      continue;
    }

    const alert = classify(weather);
    if (!alert) {
      console.log(`${cell} (${weather.name}): clear`);
      continue;
    }

    console.log(`${cell} (${weather.name}): ${alert.key} → ${group.length} device(s)`);
    for (const device of group) {
      if (!shouldSend(device, alert)) {
        skipped++;
        continue;
      }
      if (await sendTo(device, alert, weather)) sent++;
    }
  }

  console.log(`Done — sent ${sent}, skipped ${skipped} (cooldown).`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
