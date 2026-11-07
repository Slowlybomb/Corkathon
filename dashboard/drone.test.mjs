import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

test('the packaged drone is self-contained and compatible with the dashboard loader',async()=>{
  const bytes=await readFile(new URL('./assets/drone/drone.glb',import.meta.url));
  assert.equal(bytes.toString('ascii',0,4),'glTF');
  assert.equal(bytes.readUInt32LE(4),2);
  assert.equal(bytes.readUInt32LE(8),bytes.length);
  const gltf=JSON.parse(bytes.toString('utf8',20,20+bytes.readUInt32LE(12)));
  assert.ok(gltf.scenes[gltf.scene??0].nodes.length>0);
  assert.ok(gltf.meshes.length>0);
  assert.ok(gltf.buffers.every(buffer=>!buffer.uri));
  assert.ok(gltf.images.every(image=>Number.isInteger(image.bufferView)&&!image.uri));
  const supported=new Set(['KHR_materials_specular','KHR_materials_ior','EXT_texture_webp']);
  assert.ok((gltf.extensionsRequired??[]).every(extension=>supported.has(extension)),'Asset needs an unsupported loader extension');
  const hover=gltf.animations.find(animation=>animation.name==='hover');
  assert.ok(hover?.channels.length>0,'The flying animation must remain available');
  for(const channel of hover.channels){
    assert.ok(gltf.nodes[channel.target.node]);
    const sampler=hover.samplers[channel.sampler];
    assert.ok(gltf.accessors[sampler.input].count>0&&gltf.accessors[sampler.output].count>0);
  }
});
