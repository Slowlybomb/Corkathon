import { createPhoneLink, cameraImageEvidence } from './phone.mjs';
import { readTelemetry, telemetryAt } from './telemetry.mjs';
import { createResultsClient } from './phone-results.mjs';

const $=selector=>document.querySelector(selector);
let connected=false,pending=null,timer,bytes=0,receiving=false;
let telemetry=null;
const sensorStates={off:'Enable sharing on the phone',permission_required:'Allow precise location on the phone',disabled:'Turn on phone location',unavailable:'Sensor unavailable',searching:'Waiting for a reading',stale:'Reading expired',unreliable:'Compass unreliable · move away from metal'};
function renderTelemetry(){
  const current=telemetryAt(telemetry),position=current.location,orientation=current.orientation;
  $('#phone-gps').textContent=position?`${position.latitude.toFixed(6)}, ${position.longitude.toFixed(6)} · ±${Math.round(position.accuracyM)} m`:connected?(telemetry?.location?'GPS fix expired':sensorStates[telemetry?.gpsState]??'Waiting for phone GPS'):'Disconnected';
  $('#phone-altitude').textContent=position?.altitudeM!=null?`${position.altitudeM.toFixed(1)} m (WGS84)${position.altitudeAccuracyM!=null?` · ±${position.altitudeAccuracyM.toFixed(0)} m`:''}`:'Unavailable';
  $('#phone-speed').textContent=position?.speedMps!=null?`${position.speedMps.toFixed(1)} m/s`:'Unavailable';
  $('#phone-orientation').textContent=orientation?`${orientation.headingDeg==null?'Heading unavailable':`${orientation.headingDeg.toFixed(0)}° ${orientation.declinationDeg==null?'magnetic':'true'}`} · ${orientation.accuracy} accuracy`:connected?(telemetry?.orientation?'Orientation expired':sensorStates[telemetry?.orientationState]??'Waiting for phone orientation'):'Disconnected';
  $('#phone-tilt').textContent=orientation?`Pitch ${orientation.pitchDeg?.toFixed(0)??'—'}° · roll ${orientation.rollDeg?.toFixed(0)??'—'}°`:'Unavailable';
  $('#phone-locate').disabled=!position||Math.abs(position.latitude)>85;
}
setInterval(renderTelemetry,1000);
const log=message=>{
  const item=document.createElement('li');item.textContent=`${new Date().toLocaleTimeString()}  ${String(message).slice(0,500)}`;
  $('#phone-log').prepend(item);while($('#phone-log').children.length>50)$('#phone-log').lastChild.remove();
};
function finish(message){clearTimeout(timer);pending=null;receiving=false;$('#phone-request-status').textContent=message;$('#phone-capture').disabled=!connected;}
function failed(error){const message=error.message??String(error);$('#phone-status').textContent=message;log(message);}
const link=createPhoneLink({
  onState(state,name){
    connected=state==='connected';
    if(!connected){telemetry=null;results?.reset();}
    renderTelemetry();
    $('#phone-status').textContent=({disconnected:'Disconnected. Start Bluetooth in the Android app.',connecting:'Choose the camera module in the Bluetooth device picker…',authenticating:'Checking the camera module connection code…',connected:`Connected to ${name??'camera module'} over Bluetooth LE.`})[state];
    $('#phone-dot').className=`status-dot ${connected?'connected':''}`;
    $('#phone-connect').disabled=state!=='disconnected';$('#phone-pin').disabled=state!=='disconnected';
    $('#phone-disconnect').disabled=state==='disconnected';
    for(const id of ['ping','capture','stop','results'])$(`#phone-${id}`).disabled=!connected;
    if(!connected){finish('Capture requires a connected camera module.');$('#phone-camera').textContent='Unknown';$('#phone-battery').textContent='Unknown';$('#phone-model').textContent='Not connected';$('#phone-link-mode').textContent='Bluetooth LE';}
    log(state);
    window.dispatchEvent(new CustomEvent('phone-link-state',{detail:{connected}}));
  },
  onError:failed,
  onProgress(count){
    if(!pending||!receiving)return;bytes+=count;
    $('#phone-request-status').textContent=`Receiving packet · ${(bytes/1024).toFixed(1)} kB received. Image appears when transfer finishes.`;
  },
  onPacket(packet,transitMs){
    if(packet.v!==1){log('Ignored unsupported packet version');return;}
    if(results.handle(packet))return;
    switch(packet.type){
      case 'ready':log('Camera module code accepted');break;
      case 'status':
        $('#phone-camera').textContent=packet.camera==='capturing'?'Capturing':packet.camera==='off'?`Off · ${packet.armed?'requests allowed':'requests blocked'}`:'Unknown';
        $('#phone-model').textContent=({results_ready:'Results ready on the phone',on_device:'On the phone · run a survey',not_connected:'Not connected'})[packet.model]??'Status unavailable';
        $('#phone-battery').textContent=typeof packet.battery==='number'&&packet.battery>=0&&packet.battery<=100?`${packet.battery}%`:'Unknown';
        $('#phone-link-mode').textContent=packet.simulatedBps===1000?'BLE · simulated 1 kbit/s limit':'Bluetooth LE · no LoRa simulation';
        break;
      case 'pong':log('Camera module responded');break;
      case 'telemetry':{
        const sample=readTelemetry(packet,Date.now(),transitMs);if(!sample){log('Ignored invalid sensor packet');break;}
        telemetry=sample;renderTelemetry();
        window.dispatchEvent(new CustomEvent('phone-telemetry',{detail:sample}));break;
      }
      case 'ack':if(packet.id===pending){receiving=true;$('#phone-request-status').textContent='Camera module accepted the image request. Capturing and transferring…';}break;
      case 'image':{
        if(packet.id!==pending){log('Ignored image from a cancelled or expired request');break;}
        const image=cameraImageEvidence(packet);
        if(!image){finish('Camera module returned an invalid image.');break;}
        $('#phone-image').src=image.src;$('#phone-image-wrap').hidden=false;
        $('#phone-image-caption').textContent=`Stationary camera module capture · ${image.capturedAt?new Date(image.capturedAt).toLocaleString():'capture time unavailable'} · ${image.location?`phone GPS ±${Math.round(image.location.accuracyM)} m`:'location not attached'}`;
        window.dispatchEvent(new CustomEvent('phone-image',{detail:image}));
        finish('Image received. Camera is released after capture; this is a still image.');log('Image received');break;
      }
      case 'error':log(packet.message??'Camera module error');if(!packet.id||packet.id===pending)finish(String(packet.message??'Camera module request failed').slice(0,500));else failed(String(packet.message??'Camera module command failed'));break;
      case 'log':log(packet.message??'Camera module log');break;
      case 'observations':window.dispatchEvent(new CustomEvent('phone-observations',{detail:packet}));log('Observations received · unvalidated');break;
      default:log('Ignored unknown camera module packet');
    }
  },
});
const results=createResultsClient({send:(command,id,extra)=>link.send(command,id,extra)});
$('#phone-results').onclick=async()=>{
  $('#phone-results').disabled=true;$('#phone-results-status').textContent='Asking the phone for its model results…';
  try{
    const scene=await results.requestScene();
    $('#phone-results-status').textContent=`${scene.layers.length} layers computed on the phone. Each layer is requested over Bluetooth when chosen in Field layers.`;
    log('Model result list received');window.dispatchEvent(new CustomEvent('phone-results',{detail:scene}));
  }catch(error){$('#phone-results-status').textContent=error.message;failed(error);}
  finally{$('#phone-results').disabled=!connected;}
};
$('#phone-form').onsubmit=async event=>{event.preventDefault();try{await link.connect($('#phone-pin').value.trim());}catch(error){failed(error);}};
$('#phone-disconnect').onclick=()=>link.disconnect();
$('#phone-locate').onclick=()=>window.dispatchEvent(new Event('phone-locate'));
$('#phone-ping').onclick=()=>link.send('ping').catch(failed);
$('#phone-capture').onclick=async()=>{
  $('#phone-capture').disabled=true;bytes=0;receiving=false;
  $('#phone-request-status').textContent='Sending image request…';
  try{pending=crypto.randomUUID();timer=setTimeout(()=>finish('Image request timed out. Disconnect to abandon an unfinished transfer, then reconnect.'),420000);await link.send('capture',pending);}
  catch(error){finish(error.message);failed(error);}
};
$('#phone-stop').onclick=async()=>{try{await link.send('stop_camera');finish('Camera stop requested. A completed image transfer may still finish.');}catch(error){failed(error);}};
window.addEventListener('pagehide',()=>link.disconnect());
window.addEventListener('phone-disconnect',()=>link.disconnect());
if(!navigator.bluetooth){$('#phone-connect').disabled=true;$('#phone-support').textContent='Bluetooth access is unavailable here. Use desktop Chrome on localhost or HTTPS, and enable Bluetooth.';}
log('Model results come only from a survey computed on the phone. No synthetic findings are sent.');
