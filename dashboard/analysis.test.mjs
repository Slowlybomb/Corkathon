import test from 'node:test';
import assert from 'node:assert/strict';
import { buildAnalysis, valueColor } from './analysis.mjs';
import { normaliseFeed } from './geo.mjs';

test('unvalued live findings never produce a synthetic analysis surface', () => {
  const result = buildAnalysis(
    { illustrative: false, findings: [{ id: 'a', latitude: 51.95, longitude: -8.22 }] },
    'all',
    80,
  );
  assert.deepEqual(result.cells, []);
});

test('live zero values survive feed adaptation and layer selection keeps value ranges separate', () => {
  const findings = normaliseFeed({
    observations: [
      { latitude: 51.95, longitude: -8.22, value: 0, metric: 'Moisture index', unit: 'index', layer: 'moisture' },
      { latitude: 51.951, longitude: -8.221, value: 10, metric: 'Moisture index', unit: 'index', layer: 'moisture' },
      { latitude: 51.952, longitude: -8.222, value: 999, metric: 'Other', layer: 'coverage' },
    ],
  });
  const result = buildAnalysis({ illustrative: false, findings }, 'moisture', 80);
  assert.equal(result.cells.length, 2);
  assert.equal(result.cells[0].value, 0);
  assert.deepEqual([result.min, result.max], [0, 10]);
  assert.equal(result.metric, 'Moisture index');
  assert.equal(result.unit, 'index');
  assert.equal(result.cells[1].normalised, 1);
});

test('different metrics are not silently combined into one colour scale', () => {
  const result = buildAnalysis(
    {
      illustrative: false,
      findings: [
        { id: 'a', latitude: 51.95, longitude: -8.22, value: 1, metric: 'Index', unit: 'index' },
        { id: 'b', latitude: 51.951, longitude: -8.221, value: 20, metric: 'Temperature', unit: 'C' },
      ],
    },
    'all',
    80,
  );
  assert.equal(result.cells.length, 0);
  assert.match(result.note, /metric/);
});

test('legacy illustrative flags cannot generate numeric data for unassessed observations', () => {
  const survey = {
    illustrative: true,
    findings: [{ id: 'old', layer: 'coverage', x: 500, y: 450, latitude: 51.95, longitude: -8.22 }],
  };
  assert.equal(buildAnalysis(survey, 'coverage').cells.length, 0);
});

test('values without geographic positions cannot appear on the map', () => {
  const survey = { findings: [{ id: 'old', x: 500, y: 450, value: 100 }] };
  assert.deepEqual(buildAnalysis(survey, 'all').cells, []);
});

test('colour ramp clamps to the approved endpoints', () => {
  assert.deepEqual(valueColor(-2), [44, 110, 73]);
  assert.deepEqual(valueColor(1), [214, 140, 69]);
  assert.deepEqual(valueColor(0.5), [254, 254, 227]);
});
