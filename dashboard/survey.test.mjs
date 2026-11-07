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

test('drone nose follows east, north, west, and south in projected map coordinates',async()=>{
  const {routeYawAt}=await import('./survey.mjs');
  for(const [destination,nose] of [
    [{x:10,y:0},[1,0]],[{x:0,y:10},[0,1]],[{x:-10,y:0},[-1,0]],[{x:0,y:-10},[0,-1]],
  ]){
    const yaw=routeYawAt([{time:0,x:0,y:0},{time:10,...destination}],5);
    // The imported model's forward vector is map -Y after the upright correction.
    assert.ok(Math.abs(Math.sin(yaw)-nose[0])<1e-10);
    assert.ok(Math.abs(-Math.cos(yaw)-nose[1])<1e-10);
  }
});

test('heading uses the outgoing turn, final incoming direction, and deterministic scrubbing',async()=>{
  const {routeYawAt}=await import('./survey.mjs');
  const route=[{time:0,x:0,y:0},{time:10,x:10,y:0},{time:20,x:10,y:10}];
  assert.ok(Math.abs(routeYawAt(route,10)-Math.PI)<1e-10);
  assert.ok(Math.abs(routeYawAt(route,50)-Math.PI)<1e-10);
  assert.ok(Math.abs(routeYawAt(route,5)-Math.PI/2)<1e-10);
  assert.ok(Math.abs(routeYawAt(route,-5)-Math.PI/2)<1e-10);
});

test('stops retain the preceding direction and stationary routes have no inferred heading',async()=>{
  const {routeYawAt}=await import('./survey.mjs');
  const route=[{time:0,x:0,y:0},{time:10,x:10,y:0},{time:20,x:10,y:0},{time:30,x:10,y:10}];
  assert.ok(Math.abs(routeYawAt(route,15)-Math.PI/2)<1e-10);
  assert.ok(Math.abs(routeYawAt(route,20)-Math.PI)<1e-10);
  assert.equal(routeYawAt([],0),null);
  assert.equal(routeYawAt([{time:0,x:0,y:0}],0),null);
  assert.equal(routeYawAt([{time:0,x:0,y:0},{time:10,x:0,y:0}],5),null);
});

test('heading is calculated after coordinate projection rather than from sample-grid axes',async()=>{
  const {routeYawAt}=await import('./survey.mjs');
  const route=[{time:0,x:0,y:0},{time:10,x:10,y:10}];
  const yaw=routeYawAt(route,5,point=>({x:point.x*10,y:-point.y*20}));
  assert.ok(Math.abs(Math.sin(yaw)-1/Math.sqrt(5))<1e-10);
  assert.ok(Math.abs(-Math.cos(yaw)+2/Math.sqrt(5))<1e-10);
});
