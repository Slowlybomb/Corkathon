import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import * as geo from './geo.mjs';
import { buildAnalysis } from './analysis.mjs';

import * as scene from './scene.mjs';
const manifest = {
  name:'Cork · Sentinel-2 L2A 2023-05-30',crs:'EPSG:32629',width:2,height:2,
  pixel_size_m:10,origin_x:550720,origin_y:5758640,
  nodata_float32:-9999,nodata_uint8:255,
  layers:[
    {name:'ndvi',file:'layers/ndvi.f32',type:'float32',units:'index',group:'surface',min:0,max:1,mean:.4},
    {name:'ph_0-5cm',file:'layers/ph_0-5cm.f32',type:'float32',units:'pH',group:'soil',depth_cm:[0,5],min:4,max:7,mean:6},
    {name:'field_zones',file:'layers/field_zones.u8',type:'uint8',units:'zone',group:'fields'},
    {name:'elevation',file:'layers/elevation.f32',type:'float32',units:'m above sea level',group:'terrain'},
    {name:'true_color',file:'layers/true_color.rgb8',type:'uint8 x3 (RGB)',units:'display',group:'surface'},
  ],
  notes:'Soil labels are SoilGrids predictions, not field samples. Weather is ERA5-Land.',
  sources:'Sentinel-2, ISRIC SoilGrids, ERA5-Land',
};
function floats(values){const buffer=new ArrayBuffer(values.length*4),view=new DataView(buffer);values.forEach((value,index)=>view.setFloat32(index*4,value,true));return Buffer.from(buffer);}

test('UTM placement matches supplied Cork and southern-hemisphere reference positions',()=>{
  assert.equal(typeof geo.utmToLngLat,'function');
  for(const [e,n,crs,want] of [
    [550720,5758640,'EPSG:32629',[-8.261574,51.976123]],
    [556480,5752880,'EPSG:32629',[-8.178670,51.923784]],
    [500000,10000000,'EPSG:32729',[-9,0]],
    [500000,0,'EPSG:32632',[9,0]],
  ]){const actual=geo.utmToLngLat(e,n,crs);actual.forEach((value,index)=>assert.ok(Math.abs(value-want[index])<.000002,`${actual} vs ${want}`));}
});

test('documented manifest and little-endian raster load into the shared analysis without no-data',async t=>{
  assert.equal(typeof scene.loadScene,'function');
  const server=createServer((req,res)=>{
    if(req.url==='/cork/manifest.json'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify(manifest));}
    else if(req.url==='/cork/layers/ndvi.f32')res.end(floats([0,-9999,.5,NaN]));
    else if(req.url==='/cork/layers/ph_0-5cm.f32')res.end(floats([4,5,6,7]));
    else{res.writeHead(404);res.end();}
  });
  await new Promise(done=>server.listen(0,'127.0.0.1',done));t.after(()=>server.close());
  const url=`http://127.0.0.1:${server.address().port}/cork/manifest.json`;
  const loaded=await scene.loadScene(url);
  assert.deepEqual(loaded.layers.map(item=>item.name),['ndvi','ph_0-5cm']);
  const survey=await scene.loadSceneLayer(loaded,'ndvi');
  assert.equal(survey.findings.length,2);assert.equal(survey.findings[0].value,0);
  assert.deepEqual(survey.findings.map(item=>item.pixel),[0,2]);
  assert.ok(survey.findings[1].latitude<survey.findings[0].latitude,'Rows progress south');
  assert.ok(survey.findings[0].longitude>-8.261574,'Position is at the pixel centre');
  assert.equal(survey.scene.manifestUrl,url);assert.equal(survey.scene.notes,manifest.notes);
  const analysis=buildAnalysis(survey,'all');
  assert.deepEqual(analysis.cells.map(cell=>cell.value),[0,.5]);
  assert.equal(analysis.unit,'index');
  assert.match(analysis.note,/sampled pixels/i);
  const soil=await scene.loadSceneLayer(loaded,'ph_0-5cm');
  assert.match(soil.findings[0].status,/estimate/i);
  assert.match(soil.findings[0].description,/SoilGrids/);
  assert.deepEqual(soil.scene.depth_cm,[0,5]);
  await assert.rejects(scene.loadSceneLayer(loaded,'field_zones'),/numeric/i);
  await assert.rejects(scene.loadScene(url.replace('manifest.json','missing.json')),/404/);
});

test('raster validation rejects bad metadata, paths, truncation and an entirely missing layer',async()=>{
  assert.equal(typeof scene.validateManifest,'function');
  for(const patch of [{width:0},{height:2.5},{width:100000000},{crs:'EPSG:4326'},{pixel_size_m:0},{origin_y:null},{layers:[]}]){
    assert.throws(()=>scene.validateManifest({...manifest,...patch}),/manifest|UTM|numeric/i);
  }
  assert.throws(()=>scene.validateManifest({...manifest,layers:[{...manifest.layers[0],file:'../secret.f32'}]}),/path/i);
  const loaded={manifest:scene.validateManifest(manifest),url:'https://example.org/cork/manifest.json',layers:manifest.layers.slice(0,2)};
  for(const values of [[1],[-9999,-9999,-9999,-9999]]){
    await assert.rejects(scene.loadSceneLayer(loaded,'ndvi',{fetcher:async()=>new Response(floats(values))}),/size|valid pixels/i);
  }
});

test('large rasters expose a bounded selection of real pixels, keeping zero and the original pixel indices',async()=>{
  assert.equal(typeof scene.loadSceneLayer,'function');
  const m=scene.validateManifest({...manifest,width:576,height:576});
  const data=new Float32Array(576*576);data[19]=.75;
  const survey=await scene.loadSceneLayer({manifest:m,url:'https://example.org/cork/manifest.json',layers:m.layers},'ndvi',{fetcher:async()=>new Response(data)});
  assert.ok(survey.findings.length<=1000);
  assert.equal(survey.scene.stride,19);
  assert.equal(survey.findings[1].pixel,19);assert.equal(survey.findings[1].value,.75);
  assert.match(survey.scene.note,/19/);
});
