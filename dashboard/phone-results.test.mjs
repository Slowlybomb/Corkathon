import test from 'node:test';
import assert from 'node:assert/strict';
import { deflateSync } from 'node:zlib';
import { createResultsClient } from './phone-results.mjs';
import { loadSceneLayer } from './scene.mjs';

test('phone model results load one layer at a time through the scene loader', async () => {
  const width=576,stride=19,grid=31,sent=[];
  const values=Float32Array.from({length:grid*grid},(_,i)=>5+i/1000);
  const header={v:1,type:'results',name:'Cork survey computed on the phone (test)',crs:'EPSG:32629',width,height:width,pixel_size_m:10,
    origin_x:550720,origin_y:5758640,nodata_float32:-9999,stride,grid,
    layers:[{name:'ph_0-5cm',file:'layers/ph_0-5cm.f32',type:'float32',units:'pH',group:'soil',depth_cm:[0,5]}]};
  const data=Buffer.from(deflateSync(Buffer.from(values.buffer))).toString('base64');
  const client=createResultsClient({send:async(command,id,extra)=>{
    sent.push({command,...extra});
    queueMicrotask(()=>client.handle(command==='results'?{...header,id}:{v:1,type:'results_layer',id,name:extra.layer,grid,stride,data}));
  }});
  const scene=await client.requestScene();
  const layer=await loadSceneLayer(scene,'ph_0-5cm',{fetcher:scene.fetcher});
  assert.equal(layer.findings.length,961);
  assert.equal(layer.findings[0].value,values[0]);
  assert.equal(layer.findings[960].value,values[960]);
  await loadSceneLayer(scene,'ph_0-5cm',{fetcher:scene.fetcher});
  assert.deepEqual(sent.map(item=>item.command),['results','results_layer']);
});

test('phone errors reject the waiting request', async () => {
  const client=createResultsClient({send:async(command,id)=>queueMicrotask(()=>client.handle({v:1,type:'error',id,message:'No model results yet.'}))});
  await assert.rejects(client.requestScene(),/No model results yet/);
});
