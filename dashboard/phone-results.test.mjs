import test from 'node:test';
import assert from 'node:assert/strict';
import { deflateSync } from 'node:zlib';
import { createResultsClient } from './phone-results.mjs';

test('model layers arrive in parts, decode to values and are cached', async () => {
  const grid=96,sent=[];
  const q=Uint8Array.from({length:grid*grid},(_,i)=>i%255);
  const data=Buffer.from(deflateSync(Buffer.from(q))).toString('base64'),half=Math.ceil(data.length/2);
  const header={v:1,type:'results',name:'Phone survey',crs:'EPSG:32629',width:576,height:576,pixel_size_m:10,origin_x:550720,origin_y:5758640,
    layers:[{name:'ph_0-5cm',file:'layers/ph_0-5cm.f32',type:'float32',units:'pH',group:'soil'}]};
  const client=createResultsClient({send:async(command,id,extra)=>{
    sent.push({command,...extra});
    queueMicrotask(()=>{
      if(command==='results'){client.handle({...header,id});return;}
      for(const part of [1,0])client.handle({v:1,type:'results_layer',id,name:extra.layer,grid,min:4,max:6.54,part,parts:2,data:part?data.slice(half):data.slice(0,half)});
    });
  }});
  const manifest=await client.requestScene();
  assert.equal(manifest.layers.length,1);
  const layer=await client.layer('ph_0-5cm',grid);
  assert.equal(layer.values.length,grid*grid);
  assert.ok(Math.abs(layer.values[0]-4)<1e-6);
  assert.ok(Math.abs(layer.values[254]-6.54)<1e-5);
  await client.layer('ph_0-5cm',grid);
  assert.deepEqual(sent.map(item=>item.command),['results','results_layer']);
});

test('phone errors reject the waiting request', async () => {
  const client=createResultsClient({send:async(command,id)=>queueMicrotask(()=>client.handle({v:1,type:'error',id,message:'No model results yet.'}))});
  await assert.rejects(client.requestScene(),/No model results yet/);
});
