import test from 'node:test';
import assert from 'node:assert/strict';
import { findingsForLayer } from './survey.mjs';

test('analysis layers exclude unrelated findings without changing the dataset', () => {
  const findings = [
    { id: 'a', layer: 'coverage' },
    { id: 'b', layer: 'moisture' },
  ];
  assert.deepEqual(findingsForLayer(findings, 'coverage'), [{ id: 'a', layer: 'coverage' }]);
  assert.deepEqual(findingsForLayer(findings, 'all'), findings);
  assert.deepEqual(findingsForLayer(findings, 'soil'), []);
  assert.equal(findings.length, 2);
});

test('source replacement keeps selection inside the active filtered layer', async () => {
  const { retainSelection } = await import('./survey.mjs');
  const findings = [
    { id: 'coverage-1', layer: 'coverage' },
    { id: 'wet-1', layer: 'moisture' },
  ];
  const visible = findingsForLayer(findings, 'moisture');
  assert.equal(retainSelection(visible, 'coverage-1'), 'wet-1');
  assert.equal(retainSelection(visible, 'wet-1'), 'wet-1');
  assert.equal(retainSelection([], 'wet-1'), undefined);
});
