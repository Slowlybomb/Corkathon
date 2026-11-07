import test from 'node:test';
import assert from 'node:assert/strict';
import { positionAt, findingsForLayer } from './survey.mjs';

// Catch incorrect interpolation, out-of-range playback, and mixed analysis layers.
test('replay interpolates between samples and holds at route boundaries', () => {
  const route = [{ time: 0, x: 10, y: 20 }, { time: 10, x: 30, y: 60 }];
  assert.deepEqual(positionAt(route, 5), { x: 20, y: 40 });
  assert.deepEqual(positionAt(route, -8), { x: 10, y: 20 });
  assert.deepEqual(positionAt(route, 90), { x: 30, y: 60 });
  assert.equal(positionAt([], 5), null);
});

test('analysis layers exclude unrelated findings without changing the dataset', () => {
  const findings = [{ id: 'a', layer: 'coverage' }, { id: 'b', layer: 'moisture' }];
  assert.deepEqual(findingsForLayer(findings, 'coverage'), [{ id: 'a', layer: 'coverage' }]);
  assert.deepEqual(findingsForLayer(findings, 'all'), findings);
  assert.deepEqual(findingsForLayer(findings, 'soil'), []);
  assert.equal(findings.length, 2);
});

test('source replacement keeps selection inside the active filtered layer', async () => {
  const { retainSelection } = await import('./survey.mjs');
  const findings = [{ id: 'coverage-1', layer: 'coverage' }, { id: 'wet-1', layer: 'moisture' }];
  const visible = findingsForLayer(findings, 'moisture');
  assert.equal(retainSelection(visible, 'coverage-1'), 'wet-1');
  assert.equal(retainSelection(visible, 'wet-1'), 'wet-1');
  assert.equal(retainSelection([], 'wet-1'), undefined);
});
