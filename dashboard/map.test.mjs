import test from 'node:test';
import assert from 'node:assert/strict';
import { projectPoint, normaliseFeed } from './map.mjs';

test('flat projection preserves map positions and 3D height lifts columns', () => {
  const camera = { x: 100, y: 200, scale: 2, angle: 0, pitch: 0 };
  assert.deepEqual(projectPoint(510, 460, 0, camera), { x: 120, y: 220 });
  const tilted = { ...camera, pitch: Math.PI / 3 };
  const ground = projectPoint(500, 450, 0, tilted);
  const raised = projectPoint(500, 450, 40, tilted);
  assert.equal(ground.x, raised.x);
  assert.ok(raised.y < ground.y - 60);
});

test('feed accepts a list or findings wrapper and rejects malformed coordinates', () => {
  const record = { label: 'Patch', position: { x: 400, y: 300 } };
  assert.equal(normaliseFeed([record])[0].title, 'Patch');
  assert.equal(normaliseFeed({ findings: [record] })[0].x, 400);
  assert.deepEqual(normaliseFeed({ findings: [{ title: 'Bad', x: 'oops', y: 1 }] }), []);
  assert.deepEqual(normaliseFeed({ status: 'ready' }), []);
  assert.deepEqual(normaliseFeed([{ title: 'Outside', x: 10001, y: 0 }]), []);
});

test('fit keeps the field inside phone and short landscape viewports', async () => {
  const { fitCamera } = await import('./map.mjs');
  for (const [width,height] of [[390,844],[844,390],[1440,900]]) for (const view of ['2d','3d']) {
    const camera=fitCamera(width,height,view);
    for (const [x,y] of [[265,148],[778,225],[700,753],[215,657]]) {
      const point=projectPoint(x,y,0,camera);
      assert.ok(point.x>=19 && point.x<=width-19, `${view}: x=${point.x}`);
      assert.ok(point.y>=103 && point.y<=height-127, `${view}: y=${point.y}`);
    }
  }
});
