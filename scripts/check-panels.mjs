import {spawn} from 'node:child_process';
import {createServer} from 'node:http';
import {readFile,writeFile,mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';
import {extname,resolve} from 'node:path';
import assert from 'node:assert/strict';

const root=fileURLToPath(new URL('../dashboard',import.meta.url));
const profile=await mkdtemp(resolve(tmpdir(),'ithir-panel-check-'));
const executable=process.env.CHROME??'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const sceneManifest={name:'Integration fixture · illustrative satellite values',crs:'EPSG:32629',width:2,height:2,pixel_size_m:200,origin_x:553400,origin_y:5755960,nodata_float32:-9999,
  layers:[{name:'ndvi',file:'layers/ndvi.f32',type:'float32',units:'index',group:'surface'},{name:'ph_0-5cm',file:'layers/ph_0-5cm.f32',type:'float32',units:'pH',group:'soil',depth_cm:[0,5]}],notes:'Test fixture only; no field measurements.',sources:'Browser integration fixture'};
const server=createServer(async(req,res)=>{try{const name=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  if(name==='/fixture/manifest.json'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify(sceneManifest));return;}
  if(name==='/fixture/slow-manifest.json'){res.setHeader('Content-Type','application/json');setTimeout(()=>res.end(JSON.stringify(sceneManifest)),350);return;}
  if(name.startsWith('/fixture/layers/')){const values=name.includes('ndvi')?[0,-9999,.5,.75]:[4,5,6,7],buffer=Buffer.alloc(16);values.forEach((v,i)=>buffer.writeFloatLE(v,i*4));res.end(buffer);return;}
  const file=resolve(root,'.'+(name==='/'?'/index.html':name));if(!file.startsWith(root+'/'))throw new Error();res.setHeader('Content-Type',({'.html':'text/html','.mjs':'text/javascript','.css':'text/css'})[extname(file)]??'application/octet-stream');res.end(await readFile(file));}catch{res.writeHead(404);res.end();}});
await new Promise(done=>server.listen(0,'127.0.0.1',done));
const port=server.address().port;
const chrome=spawn(executable,['--headless=new','--no-first-run','--no-default-browser-check','--remote-debugging-port=0','--user-data-dir='+profile,'--enable-unsafe-swiftshader','about:blank'],{stdio:['ignore','ignore','pipe']});
let socket;
try{
  const endpoint=await new Promise((done,reject)=>{let output='';const timer=setTimeout(()=>reject(new Error('Chrome launch timed out '+output)),15000);chrome.stderr.on('data',data=>{output+=data;const match=output.match(/DevTools listening on (ws:\/\/[^\s]+)/);if(match){clearTimeout(timer);done(match[1]);}});chrome.on('exit',(code,signal)=>reject(new Error('Chrome exited '+code+' '+signal+' '+output)));});
  socket=new WebSocket(endpoint);await new Promise(done=>socket.onopen=done);
  let seq=0;const pending=new Map(),events=[];
  socket.onmessage=event=>{const value=JSON.parse(event.data);if(value.id){const p=pending.get(value.id);pending.delete(value.id);if(value.error)p.reject(new Error(JSON.stringify(value.error)));else p.done(value.result);}else events.push(value);};
  const command=(method,params={},sessionId)=>new Promise((done,reject)=>{const id=++seq;pending.set(id,{done,reject});socket.send(JSON.stringify({id,method,params,...(sessionId?{sessionId}:{})}));});
  const target=await command('Target.createTarget',{url:'about:blank'});
  const {sessionId}=await command('Target.attachToTarget',{targetId:target.targetId,flatten:true});
  const c=(method,params)=>command(method,params,sessionId);
  const evaluate=async(expression)=>{const r=await c('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});if(r.exceptionDetails)throw new Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
  await c('Page.enable');await c('Runtime.enable');await c('Network.enable');
  // Only the Bluetooth radio is doubled. Packets, request matching, evidence and UI run for real.
  await c('Page.addScriptToEvaluateOnNewDocument',{source:`(${function(){
    let library;
    Object.defineProperty(window,'maplibregl',{configurable:true,get(){return library;},set(value){library=value;const NativeMap=value.Map;value.Map=class extends NativeMap{constructor(...args){super(...args);window.fixtureMap=this;}};}});
    const tx=new EventTarget(),device=new EventTarget();let input='';
    const emit=packet=>{const bytes=new TextEncoder().encode(JSON.stringify({v:1,...packet})+'\n');for(let i=0;i<bytes.length;i+=20){const event=new Event('characteristicvaluechanged');Object.defineProperty(event,'target',{value:{value:new DataView(bytes.slice(i,i+20).buffer)}});tx.dispatchEvent(event);}};
    window.fixturePhoneEmit=emit;
    tx.startNotifications=async()=>tx;device.name='Fixture camera module';
    const rx={async writeValueWithResponse(bytes){input+=new TextDecoder().decode(bytes);if(!input.endsWith('\n'))return;const command=JSON.parse(input);input='';
      if(command.command==='hello')emit({type:'ready'});
      if(command.command==='capture'){emit({type:'ack',id:command.id});const canvas=document.createElement('canvas');canvas.width=20;canvas.height=20;const context=canvas.getContext('2d');context.fillStyle='#4c956c';context.fillRect(0,0,20,20);emit({type:'image',id:command.id,capturedAt:1794056400000,location:window.fixturePhoneLocation,mime:'image/jpeg',base64:canvas.toDataURL('image/jpeg').split(',')[1]});}
    }};
    device.gatt={connected:true,disconnect(){this.connected=false;device.dispatchEvent(new Event('gattserverdisconnected'));},async connect(){this.connected=true;return {async getPrimaryService(){return {async getCharacteristic(uuid){return uuid.startsWith('aa7a0003')?tx:rx;}};}};}};
    Object.defineProperty(navigator,'bluetooth',{value:{async requestDevice(){if(window.fixtureCancelPairing)throw new DOMException('Device selection cancelled','NotFoundError');return device;}}});
  }.toString()})()`});

  const until=async(expression,label)=>{const end=Date.now()+45000;while(Date.now()<end){if(await evaluate('Boolean('+expression+')'))return;await new Promise(r=>setTimeout(r,100));}throw new Error('Timed out: '+label);};
  const box=selector=>evaluate(`document.querySelector(${JSON.stringify(selector)}).getBoundingClientRect().toJSON()`);
  const click=selector=>evaluate(`document.querySelector(${JSON.stringify(selector)}).click()`);
  const near=(actual,expected,label)=>assert.ok(Math.abs(actual-expected)<2,`${label}: ${actual} vs ${expected}`);
  const key=async selector=>{
    await evaluate(`document.querySelector(${JSON.stringify(selector)}).focus()`);
    return async (name,shift=false)=>{await c('Input.dispatchKeyEvent',{type:'keyDown',key:name,code:name,modifiers:shift?8:0});await c('Input.dispatchKeyEvent',{type:'keyUp',key:name,code:name});};
  };
  const drag=async(selector,dx,dy,touch=false)=>{
    const handle=await box(selector),x=handle.x+handle.width/2,y=handle.y+handle.height/2;
    if(touch){
      await c('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y,id:1}]});
      const parent=selector.replace(' .panel-resize',''),before=await box(parent);
      await c('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y,id:1},{x:30,y:790,id:2}]});
      await c('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y,id:1},{x:50,y:770,id:2}]});
      near((await box(parent)).width,before.width,'A second finger must not resize the panel');
      near((await box(parent)).height,before.height,'A second finger must not change height');
      // CDP touchEnd ends the gesture; exercise an unrelated release separately.
      await evaluate(`window.dispatchEvent(new PointerEvent('pointerup',{pointerId:999}))`);
    }
    else {await c('Input.dispatchMouseEvent',{type:'mouseMoved',x,y});await c('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',buttons:1,clickCount:1,x,y});}
    await new Promise(r=>setTimeout(r,40));
    for(let step=1;step<=4;step++){
      await new Promise(r=>setTimeout(r,25));
      const point={x:x+dx*step/4,y:y+dy*step/4};
      if(touch)await c('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{...point,id:1},{x:50,y:770,id:2}]});
      else await c('Input.dispatchMouseEvent',{type:'mouseMoved',buttons:1,...point});
    }
    if(touch)await c('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
    else await c('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',buttons:0,clickCount:1,x:x+dx,y:y+dy});
  };
  await c('Emulation.setDeviceMetricsOverride',{width:1440,height:960,deviceScaleFactor:1,mobile:false});
  await c('Page.navigate',{url:`http://localhost:${port}/`});
  await until(`document.querySelector('#play')?.dataset.playing && document.querySelectorAll('.panel-resize').length===4 && window.fixtureMap?.getSource('drone-position')`,'app, map sources, and resize controls');
  await evaluate(`(async()=>{const T=await import('three'),update=T.Object3D.prototype.updateMatrixWorld;T.Object3D.prototype.updateMatrixWorld=function(force){if(this.name==='survey-drone')window.fixtureMapDrone=this;if(this.name==='phone-attitude')window.fixtureAttitudeDrone=this;return update.call(this,force);};})()`);
  assert.equal(await evaluate(`!!document.querySelector('#source option[value="scene"]')`),true,'Satellite package is a selectable source');
  assert.equal((await box('#phone-panel')).height,0,'Closed camera popover must stay hidden');
  const original=await box('.observations-panel');
  await drag('.observations-panel .panel-resize',-90,100);
  let resized=await box('.observations-panel');
  near(resized.width,original.width+90,'Mouse changes width');near(resized.height,original.height+100,'Mouse changes height');
  near(resized.right,original.right,'Observation right anchor');near(resized.top,original.top,'Observation top anchor');
  await click('#observations-toggle');
  assert.ok((await box('.observations-panel')).height<100,'Collapse overrides explicit height');
  assert.equal(await evaluate(`getComputedStyle(document.querySelector('.observations-panel .panel-resize')).display`),'none');
  await click('#observations-toggle');near((await box('.observations-panel')).height,resized.height,'Expansion restores chosen height');
  let press=await key('.observations-panel .panel-resize');
  await press('ArrowRight');near((await box('.observations-panel')).width,resized.width-16,'Keyboard moves anchored edge');
  await press('ArrowLeft',true);near((await box('.observations-panel')).width,resized.width+24,'Shift takes larger steps');
  await press('Home');near((await box('.observations-panel')).width,original.width,'Home restores default size');
  await click('#phone-toggle');
  let before=await box('#phone-panel');await drag('#phone-panel .panel-resize',-60,30);
  resized=await box('#phone-panel');near(resized.width,before.width+60,'Camera popover resizes');near(resized.right,before.right,'Camera right anchor');
  await click('#connection-toggle');assert.equal((await box('#phone-panel')).height,0);
  before=await box('#connection-panel');await drag('#connection-panel .panel-resize',-70,70);
  resized=await box('#connection-panel');near(resized.width,before.width+70,'Source panel resizes');near(resized.height,before.height+70,'Source panel height');
  await evaluate(`document.querySelector('#source').value='demo';document.querySelector('#source').dispatchEvent(new Event('change'));document.querySelector('#connection-form').requestSubmit()`);
  await until(`document.querySelector('#finding-count').textContent==='6'`,'sample for layer controls');
  await click('#phone-toggle');
  await evaluate(`window.fixtureCancelPairing=true;document.querySelector('#phone-pin').value='123456';document.querySelector('#phone-form').requestSubmit()`);
  await until(`!document.querySelector('#phone-connect').disabled`,'cancelled pairing');
  assert.equal(await evaluate(`window.fixtureMap.getSource('survey-route')._data.features.length`),1,'Cancelled pairing preserves the sample route');
  await evaluate(`window.fixtureCancelPairing=false;document.querySelector('#phone-panel').hidePopover()`);
  before=await box('.layers-panel');await drag('.layers-panel .panel-resize',80,100);
  resized=await box('.layers-panel');near(resized.width,before.width+80,'Layer width');near(resized.height,before.height-100,'Layer shrinks from upper edge');
  near(resized.bottom,before.bottom,'Layer bottom anchor');near(resized.left,before.left,'Layer left anchor');
  await click('#layers-toggle');assert.ok((await box('.layers-panel')).height<100);
  await click('#layers-toggle');near((await box('.layers-panel')).height,resized.height,'Layer expansion restores height');
  press=await key('.observations-panel .panel-resize');
  for(let i=0;i<30;i++){await press('ArrowLeft',true);await press('ArrowDown',true);}
  resized=await box('.observations-panel');assert.ok(resized.left>=12&&resized.bottom<=936,'Enlargement stays in viewport');
  near(resized.width,640,'Maximum panel width');
  for(let i=0;i<30;i++){await press('ArrowRight',true);await press('ArrowUp',true);}
  resized=await box('.observations-panel');near(resized.width,240,'Minimum width keeps observation header controls visible');near(resized.height,160,'Minimum readable height');
  await press('Home');
  await click('#connection-toggle');
  await evaluate(`(()=>{const NativeSocket=window.WebSocket;window.WebSocket=class{constructor(){window.previousFeed=this;}close(){}};document.querySelector('#source').value='live';document.querySelector('#source').dispatchEvent(new Event('change'));document.querySelector('#endpoint').value='ws://localhost:1234';document.querySelector('#connection-form').requestSubmit();window.WebSocket=NativeSocket;window.previousFeed.onmessage({data:JSON.stringify({latitude:51.95,longitude:-8.22,label:'Old feed point'})});})()`);
  assert.equal(await evaluate(`document.querySelector('#finding-count').textContent`),'1');
  await evaluate(`window.delayedFeedMessage=window.previousFeed.onmessage;document.querySelector('#source').value='scene';document.querySelector('#source').dispatchEvent(new Event('change'));document.querySelector('#scene-url').value='/fixture/slow-manifest.json';document.querySelector('#connection-form').requestSubmit()`);
  await evaluate(`window.delayedFeedMessage({data:JSON.stringify({latitude:51.95,longitude:-8.22,label:'Stale feed packet'})})`);
  assert.equal(await evaluate(`document.querySelector('#connection-label').textContent`),'Loading scene','Old feed packets cannot cancel a newer scene request');
  await until(`document.querySelector('#finding-count').textContent==='3'`,'satellite numeric pixels');
  assert.equal(await evaluate(`document.querySelector('.replay-panel').hidden`),true,'Satellite clears simulated movement');
  assert.match(await evaluate(`document.querySelector('#legend-note').textContent`),/sampled pixels/);
  await evaluate(`document.querySelector('#scene-layer').value='ph_0-5cm';document.querySelector('#scene-layer').dispatchEvent(new Event('change'))`);
  await until(`document.querySelector('#analysis-unit').textContent==='pH'`,'soil layer selection');
  assert.equal(await evaluate(`document.querySelector('#finding-count').textContent`),'4');
  // Failed loading must preserve the active layer and observations.
  await click('#connection-toggle');
  await evaluate(`document.querySelector('#scene-url').value='/fixture/missing.json';document.querySelector('#connection-form').requestSubmit()`);
  await until(`document.querySelector('#connection-status').textContent.includes('404')`,'missing scene feedback');
  assert.equal(await evaluate(`document.querySelector('#finding-count').textContent`),'4');
  await click('#phone-toggle');
  await evaluate(`document.querySelector('#phone-pin').value='123456';document.querySelector('#phone-form').requestSubmit()`);
  await until(`!document.querySelector('#phone-capture').disabled`,'camera authentication');
  assert.equal(await evaluate(`document.querySelector('#drone-telemetry')?.hidden`),false,'Live drone telemetry is visible outside connection settings');
  await evaluate(`window.fixtureOrientation={quaternion:[0.70710678,0,0,0.70710678],headingDeg:0,pitchDeg:0,rollDeg:0,reference:'magnetic',declinationDeg:null,accuracy:'high',capturedAt:1794056400000,ageMs:0};window.fixtureSendSensors=()=>window.fixturePhoneEmit({type:'telemetry',sentAt:Date.now(),location:window.fixturePhoneLocation??null,orientation:window.fixtureOrientation,gpsState:window.fixturePhoneLocation?'live':'searching',orientationState:'live'});window.fixtureSendSensors();window.fixtureSensorTimer=setInterval(window.fixtureSendSensors,200)`);
  try{await until(`window.fixtureAttitudeDrone?.visible && window.fixtureAttitudeDrone.children.length>0`,'attitude model without GPS');}
  catch(error){
    console.error('Attitude diagnostic',await evaluate(`({state:document.querySelector('#drone-telemetry-state').textContent,canvasHidden:document.querySelector('#drone-telemetry canvas').hidden,canvasSize:document.querySelector('#drone-telemetry canvas').getBoundingClientRect().toJSON(),empty:document.querySelector('#drone-attitude-empty').textContent,model:window.fixtureAttitudeDrone?{visible:window.fixtureAttitudeDrone.visible,children:window.fixtureAttitudeDrone.children.length}:null})`));
    console.error(events.filter(e=>e.method==='Runtime.consoleAPICalled'&&e.params.type==='error').map(e=>e.params.args.map(a=>a.value??a.description)).slice(-8));throw error;
  }
  assert.equal(await evaluate(`document.querySelector('#drone-pitch').textContent`),'0°');
  assert.equal(await evaluate(`document.querySelector('#drone-roll').textContent`),'0°');
  assert.equal(await evaluate(`window.fixtureMap.getSource('drone-position')._data.features.length`),0,'No GPS creates no geographic drone');
  const levelUp=await evaluate(`(async()=>{const T=await import('three');return new T.Vector3(0,1,0).applyQuaternion(window.fixtureAttitudeDrone.children[0].getWorldQuaternion(new T.Quaternion())).toArray();})()`);
  levelUp.forEach((value,i)=>assert.ok(Math.abs(value-[0,0,1][i])<1e-5,'Zero pitch/roll levels the assembled model'));
  await click('#phone-capture');
  await until(`document.querySelector('#camera-evidence') && !document.querySelector('#camera-evidence').hidden`,'camera still evidence');
  assert.equal(await evaluate(`document.querySelector('#finding-count').textContent`),'4','Unlocated capture does not replace satellite data');
  assert.match(await evaluate(`document.querySelector('#camera-evidence-caption').textContent`),/location not attached/i);
  await evaluate(`window.fixturePhoneLocation={latitude:51.95,longitude:-8.22,accuracyM:5,altitudeM:110,capturedAt:1794056400000,ageMs:0,mock:false};window.fixtureOrientation={...window.fixtureOrientation,declinationDeg:0};window.fixtureSendSensors()`);
  await until(`document.querySelector('#phone-gps').textContent.includes('51.950000') && window.fixtureMap?.getSource('drone-position')?._data?.features?.length===1`,'phone GPS map marker');
  assert.deepEqual(await evaluate(`window.fixtureMap.getSource('drone-position')._data.features[0].geometry.coordinates`),[-8.22,51.95]);
  assert.equal(await evaluate(`window.fixtureMap.getSource('drone-position')._data.features[0].properties.source`),'phone-gps');
  assert.match(await evaluate(`document.querySelector('#phone-orientation').textContent`),/0° true/);
  assert.equal(await evaluate(`document.querySelector('#phone-locate').disabled`),false);
  await evaluate(`window.fixtureOrientation={...window.fixtureOrientation,headingDeg:90,pitchDeg:25,rollDeg:-15,declinationDeg:0};window.fixturePhoneLocation={...window.fixturePhoneLocation,longitude:-8.2199};window.fixtureSendSensors()`);
  await until(`document.querySelector('#drone-pitch').textContent==='25°' && window.fixtureMapDrone?.visible && window.fixtureMapDrone.children.length>0`,'both drone models follow live attitude');
  assert.equal(await evaluate(`document.querySelector('#drone-roll').textContent`),'-15°');
  assert.deepEqual(await evaluate(`window.fixtureMapDrone.quaternion.toArray()`),await evaluate(`window.fixtureAttitudeDrone.quaternion.toArray()`),'Map and attitude model share the phone pose');
  assert.deepEqual(await evaluate(`window.fixtureMap.getSource('drone-position')._data.features[0].geometry.coordinates`),[-8.2199,51.95],'Moving phone GPS moves the geographic drone');
  const telemetryBox=await box('#drone-telemetry'),toolsBox=await box('.map-tools');
  assert.ok(toolsBox.bottom<=telemetryBox.top,'Map controls remain above live telemetry');
  await evaluate(`document.querySelector('#phone-panel').hidePopover()`);
  const liveDesktop=await c('Page.captureScreenshot',{format:'png'});await writeFile(resolve(tmpdir(),'ithir-drone-live-desktop.png'),Buffer.from(liveDesktop.data,'base64'));
  await c('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:false});
  await new Promise(r=>setTimeout(r,150));
  const mobileTelemetry=await box('#drone-telemetry'),mobileTools=await box('.map-tools');
  assert.ok(mobileTools.bottom<=mobileTelemetry.top,'Mobile map controls remain above live telemetry');
  assert.ok(mobileTelemetry.left>=12&&mobileTelemetry.right<=378&&mobileTelemetry.bottom<=832,'Telemetry stays within the mobile viewport');
  assert.equal(await evaluate(`document.documentElement.scrollWidth===innerWidth && document.documentElement.scrollHeight===innerHeight`),true);
  const liveMobile=await c('Page.captureScreenshot',{format:'png'});await writeFile(resolve(tmpdir(),'ithir-drone-live-mobile.png'),Buffer.from(liveMobile.data,'base64'));
  await c('Emulation.setDeviceMetricsOverride',{width:1440,height:960,deviceScaleFactor:1,mobile:false});
  await evaluate(`document.querySelector('#phone-panel').showPopover()`);
  await click('#phone-locate');
  await click('#phone-capture');
  await until(`document.querySelector('#camera-evidence-caption').textContent.includes('phone GPS')`,'GPS attached to camera evidence');
  assert.equal(await evaluate(`document.querySelector('#finding-count').textContent`),'4','GPS and located captures preserve satellite analysis');
  await evaluate(`clearInterval(window.fixtureSensorTimer);window.fixturePhoneEmit({type:'telemetry',sentAt:1794056400000,location:{...window.fixturePhoneLocation,ageMs:16000},orientation:null,gpsState:'stale',orientationState:'unavailable'})`);
  await until(`window.fixtureMap.getSource('drone-position')._data.features.length===0`,'expired GPS removes drone marker');
  assert.equal(await evaluate(`document.querySelector('#phone-locate').disabled`),true);
  await click('#phone-disconnect');
  assert.equal(await evaluate(`document.querySelector('#phone-gps').textContent`),'Disconnected');
  assert.equal(await evaluate(`document.querySelector('#camera-evidence').hidden`),false,'Last capture remains after disconnect');
  await click('#phone-toggle');
  const shot=await c('Page.captureScreenshot',{format:'png'});await writeFile(resolve(tmpdir(),'ithir-panels-desktop.png'),Buffer.from(shot.data,'base64'));
  await click('#phone-toggle');
  await c('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:false});
  await new Promise(r=>setTimeout(r,150));
  await c('Emulation.setTouchEmulationEnabled',{enabled:true});
  before=await box('#phone-panel');await drag('#phone-panel .panel-resize',40,-60,true);
  resized=await box('#phone-panel');near(resized.width,before.width-40,'Touch changes width');near(resized.height,before.height-60,'Touch changes height');
  near(resized.right,before.right,'Touch retains right anchor');
  await c('Emulation.setDeviceMetricsOverride',{width:320,height:600,deviceScaleFactor:1,mobile:false});
  await new Promise(r=>setTimeout(r,150));
  resized=await box('#phone-panel');assert.ok(resized.left>=12&&resized.right<=308&&resized.bottom<=576,'Viewport shrink clamps panel');
  const page=await evaluate(`({width:innerWidth,height:innerHeight,scrollWidth:document.documentElement.scrollWidth,scrollHeight:document.documentElement.scrollHeight})`);
  assert.equal(page.scrollWidth,page.width);assert.equal(page.scrollHeight,page.height);
  const mobileShot=await c('Page.captureScreenshot',{format:'png'});await writeFile(resolve(tmpdir(),'ithir-panels-mobile.png'),Buffer.from(mobileShot.data,'base64'));
  assert.deepEqual(events.filter(e=>e.method==='Runtime.exceptionThrown').map(e=>e.params.exceptionDetails.text),[]);
  console.log('Panel and integration checks passed: resizing, viewport bounds, satellite package, layer selection, failed load retention, Bluetooth still evidence, phone GPS map placement, sensor readings, located captures, and stale/disconnect cleanup.');
}finally{socket?.close();chrome.kill();await new Promise(done=>server.close(done));await new Promise(done=>chrome.exitCode!==null||chrome.signalCode!==null?done():chrome.once('exit',done));await rm(profile,{recursive:true,force:true});}
