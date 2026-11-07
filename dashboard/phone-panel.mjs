import { createPhoneLink } from './phone.mjs';

const $=selector=>document.querySelector(selector);
let connected=false,pending=null,timer,bytes=0,receiving=false;
const log=message=>{
  const item=document.createElement('li');item.textContent=`${new Date().toLocaleTimeString()}  ${String(message).slice(0,500)}`;
  $('#phone-log').prepend(item);while($('#phone-log').children.length>50)$('#phone-log').lastChild.remove();
};
function finish(message){clearTimeout(timer);pending=null;receiving=false;$('#phone-request-status').textContent=message;$('#phone-capture').disabled=!connected;}
function failed(error){const message=error.message??String(error);$('#phone-status').textContent=message;log(message);}
const link=createPhoneLink({
  onState(state,name){
    connected=state==='connected';
    $('#phone-status').textContent=({disconnected:'Disconnected. Start Bluetooth in the Android app.',connecting:'Choose the camera module in the Bluetooth device picker…',authenticating:'Checking the camera module connection code…',connected:`Connected to ${name??'camera module'} over Bluetooth LE.`})[state];
    $('#phone-dot').className=`status-dot ${connected?'connected':''}`;
    $('#phone-connect').disabled=state!=='disconnected';$('#phone-pin').disabled=state!=='disconnected';
    $('#phone-disconnect').disabled=state==='disconnected';
    for(const id of ['ping','capture','stop'])$(`#phone-${id}`).disabled=!connected;
    if(!connected){finish('Capture requires a connected camera module.');$('#phone-camera').textContent='Unknown';$('#phone-battery').textContent='Unknown';$('#phone-model').textContent='Not connected';$('#phone-link-mode').textContent='Bluetooth LE';}
    log(state);
    window.dispatchEvent(new CustomEvent('phone-link-state',{detail:{connected}}));
  },
  onError:failed,
  onProgress(count){
    if(!pending||!receiving)return;bytes+=count;
    $('#phone-request-status').textContent=`Receiving packet · ${(bytes/1024).toFixed(1)} kB received. Image appears when transfer finishes.`;
  },
  onPacket(packet){
    if(packet.v!==1){log('Ignored unsupported packet version');return;}
    switch(packet.type){
      case 'ready':log('Camera module code accepted');break;
      case 'status':
        $('#phone-camera').textContent=packet.camera==='capturing'?'Capturing':packet.camera==='off'?`Off · ${packet.armed?'requests allowed':'requests blocked'}`:'Unknown';
        $('#phone-model').textContent=packet.model==='not_connected'?'Not connected':'Status unavailable';
        $('#phone-battery').textContent=typeof packet.battery==='number'&&packet.battery>=0&&packet.battery<=100?`${packet.battery}%`:'Unknown';
        $('#phone-link-mode').textContent=packet.simulatedBps===1000?'BLE · simulated 1 kbit/s limit':'Bluetooth LE · no LoRa simulation';
        break;
      case 'pong':log('Camera module responded');break;
      case 'ack':if(packet.id===pending){receiving=true;$('#phone-request-status').textContent='Camera module accepted the image request. Capturing and transferring…';}break;
      case 'image':{
        if(packet.id!==pending){log('Ignored image from a cancelled or expired request');break;}
        if(packet.mime!=='image/jpeg'||typeof packet.base64!=='string'||packet.base64.length>44000||!/^\/9j\/[A-Za-z0-9+/]*={0,2}$/.test(packet.base64)){finish('Camera module returned an invalid image.');break;}
        $('#phone-image').src=`data:image/jpeg;base64,${packet.base64}`;$('#phone-image-wrap').hidden=false;
        const captured=new Date(packet.capturedAt);
        $('#phone-image-caption').textContent=`Stationary camera module capture · ${Number.isFinite(captured.getTime())?captured.toLocaleString():'capture time unavailable'} · location not attached`;
        finish('Image received. Camera is released after capture; this is a still image.');log('Image received');break;
      }
      case 'error':log(packet.message??'Camera module error');if(!packet.id||packet.id===pending)finish(String(packet.message??'Camera module request failed').slice(0,500));else failed(String(packet.message??'Camera module command failed'));break;
      case 'log':log(packet.message??'Camera module log');break;
      case 'observations':window.dispatchEvent(new CustomEvent('phone-observations',{detail:packet}));log('Observations received · unvalidated');break;
      default:log('Ignored unknown camera module packet');
    }
  },
});
$('#phone-form').onsubmit=async event=>{event.preventDefault();try{await link.connect($('#phone-pin').value.trim());}catch(error){failed(error);}};
$('#phone-disconnect').onclick=()=>link.disconnect();
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
log('No model is connected. No synthetic findings are sent.');
