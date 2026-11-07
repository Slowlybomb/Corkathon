import test from 'node:test';
import assert from 'node:assert/strict';
import * as geo from './geo.mjs';

test('only supplied geographic positions can place observations', () => {
  assert.deepEqual(geo.coordinatesFor({ longitude: -8.22, latitude: 51.95, x: 0, y: 0 }), [-8.22, 51.95]);
  assert.equal(geo.coordinatesFor({ x: 500, y: 450 }), null);
  assert.deepEqual(geo.normaliseFeed({ label: 'Old sample', position: { x: 400, y: 300 } }), []);
  assert.deepEqual(geo.normaliseFeed({ findings: [{ x: 400, y: 300, value: 10 }] }), []);
});

test('feed retains real positions and supplied layer names without inventing an assessment category', () => {
  const finding = geo.normaliseFeed({
    observations: [{ label: 'Point', lat: 51.949961, lon: -8.220098, layer: 'soil carbon' }],
  })[0];
  assert.deepEqual(geo.coordinatesFor(finding), [-8.220098, 51.949961]);
  assert.equal(finding.layer, 'soil carbon');
  assert.equal(geo.normaliseFeed({ coordinates: [-8.22, 51.95] })[0].layer, 'observations');
  for (const input of [
    { status: 'ready' },
    [{ x: 'oops', y: 1 }],
    [{ lat: 95, lon: -8.22 }],
    [{ lat: null, lon: -8.22 }],
  ])
    assert.deepEqual(geo.normaliseFeed(input), []);
});

test('map fitting uses loaded scene bounds or real observations, with no empty-workspace extent', () => {
  assert.equal(typeof geo.surveyBounds, 'function');
  assert.equal(geo.surveyBounds({ findings: [] }), null);
  assert.deepEqual(
    geo.surveyBounds({
      findings: [
        { lat: 52, lon: -9 },
        { lat: 51.9, lon: -8.1 },
        { x: 100, y: 100 },
      ],
    }),
    [
      [-9, 51.9],
      [-8.1, 52],
    ],
  );
  assert.deepEqual(
    geo.surveyBounds({
      scene: {
        bounds: [
          [-9, 51],
          [-8, 52],
        ],
      },
      findings: [{ lat: 55, lon: 1 }],
    }),
    [
      [-9, 51],
      [-8, 52],
    ],
  );
});
