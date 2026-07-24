/**
 * Clarity — severe weather alert dispatcher.
 *
 * Runs on a schedule (GitHub Actions). For every device registered in the
 * `fcm_tokens` Firestore collection with alerts enabled and a known location:
 *   1. drop devices whose position is too stale to trust
 *   2. group devices by a coarse lat/lon grid (so a city = one API call)
 *   3. fetch current conditions from OpenWeather (free /data/2.5/weather)
 *   4. classify severity from the condition id + wind/temperature thresholds
 *   5. skip anything already sent recently (dedupe)
 *   6. push via Firebase Admin, and prune tokens the device has unregistered
 *
 * The decision logic lives in `alert-rules.mjs` so it can be unit-tested; this
 * file is the IO shell (secrets, Firestore, HTTP, FCM).
 *
 * Secrets (env): OPENWEATHER_API_KEY, FIREBASE_SERVICE_ACCOUNT (service-account JSON).
 */
// firebase-admin v13+ dropped the `admin.*` namespace API in ESM: the default
// export carries no `.credential` / `.firestore` / `.messaging`. Use the
// modular sub-path entry points instead.
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

import {
  STALE_LOCATION_MS,
  alertFor,
  buildBody,
  groupByGrid,
  selectAlertableDevices,
  shouldSend,
} from './alert-rules.mjs';

const OPENWEATHER_API_KEY = process.env.OPENWEATHER_API_KEY;
const FIREBASE_SERVICE_ACCOUNT = process.env.FIREBASE_SERVICE_ACCOUNT;

if (!OPENWEATHER_API_KEY || !FIREBASE_SERVICE_ACCOUNT) {
  console.error('Missing OPENWEATHER_API_KEY and/or FIREBASE_SERVICE_ACCOUNT env vars.');
  process.exit(1);
}

initializeApp({
  credential: cert(JSON.parse(FIREBASE_SERVICE_ACCOUNT)),
});

const db = getFirestore();
const messaging = getMessaging();

const COLLECTION = 'fcm_tokens';

/** Log what would be sent, send nothing, write nothing. */
const DRY_RUN = process.env.DRY_RUN === '1';
/** Ignore real conditions + cooldown and push a test alert. Proves delivery
 *  end-to-end when the weather is calm. */
const FORCE_ALERT = process.env.FORCE_ALERT === '1';
/** Override the staleness cutoff (days) without editing code. */
const STALE_AFTER_MS = process.env.STALE_AFTER_DAYS
  ? Number(process.env.STALE_AFTER_DAYS) * 24 * 60 * 60 * 1000
  : STALE_LOCATION_MS;

async function fetchWeather(lat, lon) {
  const url =
    `https://api.openweathermap.org/data/2.5/weather` +
    `?lat=${lat}&lon=${lon}&units=metric&appid=${OPENWEATHER_API_KEY}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`OpenWeather responded ${res.status}`);
  return res.json();
}

async function sendTo(device, alert, weather) {
  if (DRY_RUN) {
    console.log(`  [dry-run] would send "${alert.title}" → ${buildBody(alert, device, weather)}`);
    return true;
  }
  try {
    await messaging.send({
      token: device.token,
      notification: { title: alert.title, body: buildBody(alert, device, weather) },
      data: { type: 'severe_weather', key: alert.key },
      android: { priority: 'high' },
    });
    await db.collection(COLLECTION).doc(device.id).update({
      lastAlertKey: alert.key,
      lastAlertAt: FieldValue.serverTimestamp(),
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

  const registered = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  const { devices, staleCount } = selectAlertableDevices(registered, {
    maxAgeMs: STALE_AFTER_MS,
  });

  if (staleCount > 0) {
    const days = Math.round(STALE_AFTER_MS / (24 * 60 * 60 * 1000));
    console.log(`Skipping ${staleCount} device(s) with a position older than ${days}d.`);
  }

  if (devices.length === 0) {
    console.log('No registered devices with a fresh known location — nothing to do.');
    return;
  }

  const groups = groupByGrid(devices);
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

    const alert = alertFor(weather, { forceAlert: FORCE_ALERT });
    if (!alert) {
      console.log(`${cell} (${weather.name}): clear`);
      continue;
    }

    console.log(`${cell} (${weather.name}): ${alert.key} → ${group.length} device(s)`);
    for (const device of group) {
      if (!shouldSend(device, alert, { forceAlert: FORCE_ALERT })) {
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
