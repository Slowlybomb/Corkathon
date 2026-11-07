import test from 'node:test';
import assert from 'node:assert/strict';
import * as telemetry from './telemetry.mjs';

const packet = {
  v: 1,
  type: 'telemetry',
  sentAt: 1794056400000,
  location: {
    latitude: 51.95,
    longitude: -8.22,
    accuracyM: 6,
    altitudeM: 110,
    capturedAt: 1794056400000,
    ageMs: 200,
    mock: false,
  },
  orientation: {
    quaternion: [0, 0, 0, 1],
    headingDeg: 0,
    pitchDeg: 0,
    rollDeg: 0,
    reference: 'magnetic',
    declinationDeg: 0,
    accuracy: 'high',
    capturedAt: 1794056400000,
    ageMs: 50,
  },
};

test('phone telemetry preserves device GPS and orientation independently, including zero readings', () => {
  assert.equal(typeof telemetry.readTelemetry, 'function');
  const sample = telemetry.readTelemetry(packet, 1000);
  assert.equal(sample.location.latitude, 51.95);
  assert.equal(sample.location.altitudeM, 110);
  assert.equal(sample.orientation.headingDeg, 0);
  assert.equal(telemetry.readTelemetry({ ...packet, location: null }, 1000).location, null);
  assert.equal(telemetry.readTelemetry({ ...packet, orientation: null }, 1000).orientation, null);
  const zero = telemetry.readTelemetry(
    { ...packet, location: { ...packet.location, latitude: 0, longitude: 0, altitudeM: 0, accuracyM: 0 } },
    1000,
  );
  assert.equal(zero.location.longitude, 0);
  assert.equal(zero.location.altitudeM, 0);
  for (const location of [
    { ...packet.location, latitude: 91 },
    { ...packet.location, longitude: '-8.22' },
    { ...packet.location, accuracyM: -1 },
    { ...packet.location, mock: true },
    { ...packet.location, ageMs: 15001 },
  ]) {
    assert.equal(telemetry.readTelemetry({ ...packet, location }, 1000).location, null);
  }
  for (const orientation of [
    { ...packet.orientation, quaternion: [0, 0, 0, 0] },
    { ...packet.orientation, accuracy: 'unreliable' },
    { ...packet.orientation, ageMs: 3001 },
  ]) {
    assert.equal(telemetry.readTelemetry({ ...packet, orientation }, 1000).orientation, null);
  }
  assert.equal(telemetry.readTelemetry({ ...packet, v: 2 }, 1000), null);
});

test('lost updates expire independently without moving the drone to sample coordinates or inventing altitude', () => {
  assert.equal(typeof telemetry.telemetryAt, 'function');
  const sample = telemetry.readTelemetry({ ...packet, location: { ...packet.location, altitudeM: null } }, 1000);
  const fresh = telemetry.telemetryAt(sample, 1000);
  assert.equal(fresh.location.altitudeM, null);
  assert.equal(telemetry.telemetryAt(sample, 4000).orientation, null);
  assert.ok(telemetry.telemetryAt(sample, 4000).location);
  assert.equal(telemetry.telemetryAt(sample, 16000).location, null);
  assert.deepEqual(telemetry.telemetryAt(null, 1000), { location: null, orientation: null });
  assert.equal(
    telemetry.readTelemetry(packet, 1000, 4000).orientation,
    null,
    'Slow BLE transfer must age the sensor reading',
  );
  assert.ok(telemetry.readTelemetry(packet, 1000, 4000).location);
  assert.equal(telemetry.readTelemetry(packet, 1000, 16000).location, null);
});

test('reported zero pitch and roll keep the model level at every heading', () => {
  assert.equal(typeof telemetry.droneQuaternion, 'function');
  const near = (actual, expected) =>
    actual.forEach((n, i) => assert.ok(Math.abs(n - expected[i]) < 1e-6, `${actual} != ${expected}`));
  near(telemetry.droneQuaternion(packet.orientation), [0, 0, 1, 0]);
  near(telemetry.droneQuaternion({ ...packet.orientation, headingDeg: 90, declinationDeg: 90 }), [
    0,
    0,
    Math.SQRT1_2,
    Math.SQRT1_2,
  ]);
  // Reported angles are authoritative, even if a sender supplies a differently framed quaternion.
  near(
    telemetry.droneQuaternion({ ...packet.orientation, quaternion: [Math.SQRT1_2, 0, 0, Math.SQRT1_2] }),
    [0, 0, 1, 0],
  );
  near(telemetry.droneQuaternion({ ...packet.orientation, headingDeg: 180 }), [0, 0, 0, 1]);
  assert.equal(telemetry.droneQuaternion(null), null);
  assert.equal(telemetry.droneQuaternion({ ...packet.orientation, pitchDeg: null }), null);
});

test('pitch and roll rotate the displayed body using the same signed angles as the phone', () => {
  const rotate = ([x, y, z, w], [a, b, c]) => [
    (1 - 2 * (y * y + z * z)) * a + 2 * (x * y - z * w) * b + 2 * (x * z + y * w) * c,
    2 * (x * y + z * w) * a + (1 - 2 * (x * x + z * z)) * b + 2 * (y * z - x * w) * c,
    2 * (x * z - y * w) * a + 2 * (y * z + x * w) * b + (1 - 2 * (x * x + y * y)) * c,
  ];
  const near = (a, b) => a.forEach((n, i) => assert.ok(Math.abs(n - b[i]) < 1e-6, `${a} != ${b}`));
  // Upright model nose -Y follows phone top +Y. Android positive pitch is nose-down.
  near(rotate(telemetry.droneQuaternion({ ...packet.orientation, pitchDeg: 30 }), [0, -1, 0]), [
    0,
    Math.sqrt(3) / 2,
    -0.5,
  ]);
  near(rotate(telemetry.droneQuaternion({ ...packet.orientation, pitchDeg: -30 }), [0, -1, 0]), [
    0,
    Math.sqrt(3) / 2,
    0.5,
  ]);
  near(rotate(telemetry.droneQuaternion({ ...packet.orientation, rollDeg: 30 }), [0, 0, 1]), [
    0.5,
    0,
    Math.sqrt(3) / 2,
  ]);
  near(rotate(telemetry.droneQuaternion({ ...packet.orientation, headingDeg: 90, pitchDeg: 30 }), [0, -1, 0]), [
    Math.sqrt(3) / 2,
    0,
    -0.5,
  ]);
});
