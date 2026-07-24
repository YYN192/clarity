import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

import {
  COOLDOWN_MS,
  STALE_LOCATION_MS,
  TEST_ALERT,
  alertFor,
  buildBody,
  classify,
  groupByGrid,
  isLocationStale,
  selectAlertableDevices,
  shouldSend,
} from './alert-rules.mjs';

/** A Firestore-Timestamp-shaped stub. */
const ts = (ms) => ({ toMillis: () => ms });

/** Calm conditions: clear sky, mild, still. */
const calm = {
  name: 'Sofia',
  weather: [{ id: 800, description: 'clear sky' }],
  main: { temp: 20 },
  wind: { speed: 2 },
};

const withCondition = (id, description = 'severe weather') => ({
  ...calm,
  weather: [{ id, description }],
});

describe('classify', () => {
  test('returns null for unremarkable weather', () => {
    assert.equal(classify(calm), null);
  });

  test('maps each severe condition family to its own key', () => {
    const cases = [
      [781, 'tornado'],
      [901, 'tropical-storm'],
      [212, 'thunderstorm'],
      [503, 'heavy-rain'],
      [511, 'freezing'],
      [613, 'freezing'],
      [602, 'heavy-snow'],
      [762, 'atmospheric'],
    ];
    for (const [id, key] of cases) {
      assert.equal(classify(withCondition(id)).key, key, `condition id ${id}`);
    }
  });

  test('wind threshold is inclusive at gale force (17.2 m/s)', () => {
    assert.equal(classify({ ...calm, wind: { speed: 17.19 } }), null);
    assert.equal(classify({ ...calm, wind: { speed: 17.2 } }).key, 'high-wind');
  });

  test('gusts count even when sustained wind is calm', () => {
    const gusty = { ...calm, wind: { speed: 3, gust: 20 } };
    assert.equal(classify(gusty).key, 'high-wind');
  });

  test('temperature thresholds are inclusive at +40 and -20', () => {
    assert.equal(classify({ ...calm, main: { temp: 39.9 } }), null);
    assert.equal(classify({ ...calm, main: { temp: 40 } }).key, 'extreme-heat');
    assert.equal(classify({ ...calm, main: { temp: -19.9 } }), null);
    assert.equal(classify({ ...calm, main: { temp: -20 } }).key, 'extreme-cold');
  });

  test('survives a malformed payload rather than throwing', () => {
    assert.equal(classify({}), null);
    assert.equal(classify({ weather: [], main: {}, wind: {} }), null);
  });

  test('severe conditions outrank the wind and temperature rules', () => {
    const stormyAndWindy = { ...withCondition(212), wind: { speed: 30 } };
    assert.equal(classify(stormyAndWindy).key, 'thunderstorm');
  });
});

describe('alertFor', () => {
  test('calm weather produces nothing by default', () => {
    assert.equal(alertFor(calm), null);
  });

  test('force mode substitutes a test alert when conditions are calm', () => {
    // The regression: FORCE_ALERT was only consulted after the classify()
    // bail-out, so forcing during calm weather silently sent nothing.
    assert.equal(alertFor(calm, { forceAlert: true }), TEST_ALERT);
  });

  test('force mode does not mask real severe weather', () => {
    assert.equal(alertFor(withCondition(781), { forceAlert: true }).key, 'tornado');
  });
});

describe('isLocationStale', () => {
  const now = 1_000_000_000_000;

  test('a position within the window is fresh', () => {
    const device = { locationUpdatedAt: ts(now - 1000) };
    assert.equal(isLocationStale(device, { now }), false);
  });

  test('a position older than the window is stale', () => {
    const device = { locationUpdatedAt: ts(now - STALE_LOCATION_MS - 1) };
    assert.equal(isLocationStale(device, { now }), true);
  });

  test('falls back to updatedAt when locationUpdatedAt is missing', () => {
    // Documents written before locationUpdatedAt existed must not all be
    // treated as stale, or every already-registered device goes dark.
    const legacy = { updatedAt: ts(now - 1000) };
    assert.equal(isLocationStale(legacy, { now }), false);

    const oldLegacy = { updatedAt: ts(now - STALE_LOCATION_MS - 1) };
    assert.equal(isLocationStale(oldLegacy, { now }), true);
  });

  test('locationUpdatedAt wins over a fresher updatedAt', () => {
    // Toggling units refreshes updatedAt without moving the device, so only
    // locationUpdatedAt says anything about where it is.
    const device = {
      locationUpdatedAt: ts(now - STALE_LOCATION_MS - 1),
      updatedAt: ts(now),
    };
    assert.equal(isLocationStale(device, { now }), true);
  });

  test('a device with no timestamps is allowed through', () => {
    assert.equal(isLocationStale({}, { now }), false);
  });
});

describe('selectAlertableDevices', () => {
  const now = 1_000_000_000_000;
  const fresh = ts(now - 1000);

  test('drops devices with no coordinates or no token', () => {
    const { devices } = selectAlertableDevices(
      [
        { token: 'a', lat: 1, lon: 2, locationUpdatedAt: fresh },
        { token: 'b', lat: null, lon: 2, locationUpdatedAt: fresh },
        { token: null, lat: 1, lon: 2, locationUpdatedAt: fresh },
        { token: 'd', locationUpdatedAt: fresh },
      ],
      { now },
    );
    assert.deepEqual(devices.map((d) => d.token), ['a']);
  });

  test('reports how many were dropped as stale', () => {
    const { devices, staleCount } = selectAlertableDevices(
      [
        { token: 'a', lat: 1, lon: 2, locationUpdatedAt: fresh },
        { token: 'b', lat: 1, lon: 2, locationUpdatedAt: ts(now - STALE_LOCATION_MS - 1) },
      ],
      { now },
    );
    assert.deepEqual(devices.map((d) => d.token), ['a']);
    assert.equal(staleCount, 1);
  });

  test('unusable devices are not counted as stale', () => {
    const { staleCount } = selectAlertableDevices(
      [{ token: null, lat: 1, lon: 2 }],
      { now },
    );
    assert.equal(staleCount, 0);
  });

  test('coordinate 0 is a valid position, not a missing one', () => {
    const { devices } = selectAlertableDevices(
      [{ token: 'a', lat: 0, lon: 0, locationUpdatedAt: fresh }],
      { now },
    );
    assert.equal(devices.length, 1);
  });
});

describe('groupByGrid', () => {
  test('nearby devices share one cell, distant ones do not', () => {
    const groups = groupByGrid([
      { lat: 42.71, lon: 23.32 },
      { lat: 42.68, lon: 23.34 }, // ~same 0.1° cell
      { lat: 37.42, lon: -122.08 },
    ]);
    assert.equal(groups.size, 2);
    assert.equal(groups.get('42.7,23.3').length, 2);
  });
});

describe('shouldSend', () => {
  const now = 1_000_000_000_000;
  const alert = { key: 'thunderstorm' };

  test('sends when this device has never had this alert', () => {
    assert.equal(shouldSend({ lastAlertKey: 'high-wind' }, alert, { now }), true);
  });

  test('suppresses a repeat inside the cooldown', () => {
    const device = { lastAlertKey: 'thunderstorm', lastAlertAt: ts(now - 1000) };
    assert.equal(shouldSend(device, alert, { now }), false);
  });

  test('sends again once the cooldown has elapsed', () => {
    const device = {
      lastAlertKey: 'thunderstorm',
      lastAlertAt: ts(now - COOLDOWN_MS - 1),
    };
    assert.equal(shouldSend(device, alert, { now }), true);
  });

  test('force mode bypasses the cooldown', () => {
    const device = { lastAlertKey: 'thunderstorm', lastAlertAt: ts(now) };
    assert.equal(shouldSend(device, alert, { forceAlert: true, now }), true);
  });

  test('a device that has never been alerted is sendable', () => {
    assert.equal(shouldSend({}, alert, { now }), true);
  });
});

describe('buildBody', () => {
  const alert = { detail: '{city} — currently {temp}.' };

  test('prefers the device city, falling back to the API name', () => {
    assert.match(buildBody(alert, { city: 'Krasno Selo' }, calm), /^Krasno Selo/);
    assert.match(buildBody(alert, {}, calm), /^Sofia/);
    assert.match(buildBody(alert, {}, { main: { temp: 1 } }), /^your area/);
  });

  test('renders temperature in the device own units', () => {
    assert.match(buildBody(alert, { units: 'metric' }, calm), /20°C/);
    assert.match(buildBody(alert, { units: 'imperial' }, calm), /68°F/);
  });
});
