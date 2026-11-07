import { findingsForLayer, retainSelection } from './survey.mjs';
import { createFieldMap } from './map.mjs';
import { normaliseFeed, coordinatesFor } from './geo.mjs';
import { loadScene, loadSceneLayer } from './scene.mjs';
import { createDroneTelemetry } from './drone-telemetry.mjs';

const $ = selector => document.querySelector(selector);
const survey = {name:'Field workspace',source:null,findings:[]};
let selected, layer = 'all';
let socket = null, toastTimer,analysisState=null;
let scenePackage=null,sceneRequest=0,sceneController=null,cameraEvidence=null;
let droneTelemetry=null,phoneConnected=false;
const escape = value => String(value).replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const map = createFieldMap($('#map'),survey,selectFinding,message=>{const notice=$('#map-notice');notice.hidden=!message;notice.textContent=message??'';},updateBasemapUi,updateAnalysisUi,inspectCell);
const dronePanel=createDroneTelemetry($('#drone-telemetry'));

function renderLayerFilters(){
  const layers=['all',...new Set(survey.findings.map(item=>item.layer??'observations').filter(name=>name!=='all'))];
  const focusedLayer=$('#layers').contains(document.activeElement)?document.activeElement.dataset.layer:null;
  if(!layers.includes(layer))layer='all';
  $('#layers').replaceChildren(...layers.map(name=>{
    const button=document.createElement('button'),swatch=document.createElement('span');
    button.className=`layer-option ${name===layer?'active':''}`;button.dataset.layer=name;button.setAttribute('aria-pressed',name===layer);
    swatch.className=`layer-swatch ${name==='all'?'all-swatch':'coverage-swatch'}`;
    button.append(swatch,document.createTextNode(name==='all'?'All observations':name.replaceAll('_',' ')));
    if(name===layer){const check=document.createElement('span');check.className='layer-check';check.textContent='✓';button.append(check);}
    return button;
  }));
  if(focusedLayer)[...$('#layers').children].find(button=>button.dataset.layer===focusedLayer)?.focus({preventScroll:true});
}
function renderFindings(){
  renderLayerFilters();
  const findings=findingsForLayer(survey.findings,layer);
  selected=retainSelection(findings,selected);
  $('#finding-count').textContent=findings.length;
  $('#finding-list').replaceChildren();
  findings.forEach(finding=>{
    const button=document.createElement('button');button.className=`finding-item ${finding.id===selected?'active':''}`;
    button.dataset.id=finding.id;button.setAttribute('aria-pressed',finding.id===selected);
    const number=String(survey.findings.indexOf(finding)+1).padStart(2,'0');
    button.innerHTML=`<span class="finding-number ${finding.tone==='teal'?'teal':''}">${number}</span><span class="finding-copy"><strong>${escape(finding.title)}</strong><small>${escape(finding.status)}</small></span><svg class="icon" aria-hidden="true"><use href="#i-chevron"/></svg>`;
    button.onclick=()=>selectFinding(finding.id);$('#finding-list').append(button);
  });
  if(!findings.length)$('#finding-list').innerHTML=survey.findings.length?'<div class="empty-state"><h3>No observations in this layer</h3><p>Choose another layer to see available findings.</p></div>':'<div class="empty-state"><h3>Your field observations, here.</h3><p>Connect your camera module or an observation feed to start reviewing your survey.</p><button id="empty-connect" class="button primary">Connect a source</button></div>';
  $('#empty-connect')?.addEventListener('click',()=>toggleSetup(true));
  $('.layers-panel').hidden=!survey.findings.length;
  $('#export').disabled=!survey.findings.length&&!cameraEvidence;
  $('#layers').hidden=Boolean(survey.scene);
  $('#scene-layer-fields').hidden=!survey.scene;
  renderDetail();map.setLayer(layer);map.setSelected(selected);updateSourceLabels();
}
function updateBasemapUi(value){
  $('#basemap-switch').querySelectorAll('button').forEach(button=>{
    const active=button.dataset.basemap===value;button.classList.toggle('active',active);button.setAttribute('aria-pressed',active);
  });
  updateSourceLabels();
}
$('#basemap-switch').onclick=event=>{const button=event.target.closest('[data-basemap]');if(button)map.setBasemap(button.dataset.basemap);};
function updateSourceLabels(){
  $('#survey-context').textContent=survey.scene?`${survey.findings.length} sampled pixels · ${survey.name}`:survey.findings.length?`${survey.findings.length} observations · ${survey.source}`:'No survey loaded';
  if(analysisState)updateAnalysisUi(analysisState);
  $('#source-credit').textContent=survey.scene?'Satellite export · sampled preview · unvalidated':survey.findings.length?'Received observations · unvalidated':'No observations loaded';
}
const formatValue=value=>Number.isFinite(value)?new Intl.NumberFormat('en-IE',{maximumFractionDigits:3}).format(value):'—';
function updateAnalysisUi(state){
  analysisState=state;
  const hasCells=state.cells.length>0;
  $('.analysis-controls').hidden=!hasCells;
  $('.legend').hidden=!hasCells;
  $('.legend-scale').hidden=!hasCells;
  $('#analysis-metric').textContent=state.metric;
  $('#analysis-kind').textContent='Unvalidated';
  $('#analysis-min').textContent=formatValue(state.min);$('#analysis-max').textContent=formatValue(state.max);
  $('#analysis-unit').textContent=state.unit||state.metric;
  $('#analysis-size-label').textContent='Display diameter';
  $('#analysis-count').textContent=`${state.cells.length.toLocaleString()} ${survey.scene?'sampled pixels':'value points'}`;
  $('#legend-note').textContent=state.cells.length&&!state.fieldScale?'Zoom in to inspect the analysis layer.':state.note;
  $('#cell-previous').disabled=!hasCells;$('#cell-next').disabled=!hasCells;
  $('#analysis-height').disabled=!state.raised;
  if(state.settings){
    $('#opacity-output').textContent=`${Math.round(state.settings.opacity*100)}%`;
    $('#size-output').textContent=`${Math.round(state.settings.radius*2)} m`;
    $('#height-output').textContent=`${state.settings.heightScale}×`;
  }
}
function inspectCell(cell){
  $('#cell-readout').textContent=cell?`${survey.scene?'Satellite pixel':'Received point'}: ${formatValue(cell.value)} ${cell.unit||cell.metric}`:'Hover, tap, or use arrows to inspect cells.';
}
$('#analysis-style').onclick=event=>{
  const button=event.target.closest('[data-analysis-mode]');if(!button)return;
  const mode=button.dataset.analysisMode;
  $('#analysis-style').querySelectorAll('button').forEach(item=>{const active=item===button;item.classList.toggle('active',active);item.setAttribute('aria-pressed',active);});
  if(mode==='columns'&&$('#view-3d').getAttribute('aria-pressed')!=='true')$('#view-3d').click();
  map.setAnalysisOptions({mode});
};
for(const [id,key,divisor] of [['analysis-opacity','opacity',100],['analysis-size','radius',2],['analysis-height','heightScale',100]]){
  $(`#${id}`).oninput=event=>map.setAnalysisOptions({[key]:Number(event.target.value)/divisor});
}
$('#cell-previous').onclick=()=>map.inspectAnalysisCell(-1);$('#cell-next').onclick=()=>map.inspectAnalysisCell(1);
window.addEventListener('analysis-hover',event=>{
  const tooltip=$('#analysis-tooltip'),cell=event.detail;
  tooltip.hidden=!cell;if(!cell)return;
  tooltip.textContent=`Unvalidated · ${cell.metric}: ${formatValue(cell.value)} ${cell.unit}`;
  tooltip.style.left=`${Math.max(12,Math.min(innerWidth-tooltip.offsetWidth-12,cell.x+16))}px`;
  tooltip.style.top=`${Math.max(12,Math.min(innerHeight-tooltip.offsetHeight-12,cell.y+16))}px`;
});
window.addEventListener('keydown',event=>{if(event.key==='Escape')$('#analysis-tooltip').hidden=true;});
function renderDetail(){
  const finding=survey.findings.find(item=>item.id===selected);
  const detail=$('#finding-detail');
  if(!finding){detail.hidden=true;return;}detail.hidden=false;
  detail.innerHTML=`<div class="detail-top"><span class="evidence-label">${survey.scene?'Satellite pixel':'Received observation'}</span><span class="evidence-status ${finding.tone==='teal'?'teal':''}">${escape(finding.status)}</span></div><h3>${escape(finding.title)}</h3><p>${escape(finding.description)}</p><div class="inspection-action"><svg class="icon" aria-hidden="true"><use href="#i-pin"/></svg><div><strong>Suggested check</strong><p>${escape(finding.action)}</p></div></div>`;
}
function selectFinding(id){
  const finding=survey.findings.find(item=>item.id===id);if(!finding)return;
  selected=id;
  document.querySelectorAll('.finding-item').forEach(button=>{const active=button.dataset.id===id;button.classList.toggle('active',active);button.setAttribute('aria-pressed',active);});
  renderDetail();map.setSelected(id);
}
$('#layers').onclick=event=>{
  const button=event.target.closest('[data-layer]');if(!button)return;layer=button.dataset.layer;
  const findings=findingsForLayer(survey.findings,layer);if(!findings.some(item=>item.id===selected))selected=findings[0]?.id;
  renderFindings();
};
for(const view of ['2d','3d'])$(`#view-${view}`).onclick=()=>{
  map.setView(view);for(const other of ['2d','3d']){const active=other===view;$(`#view-${other}`).classList.toggle('active',active);$(`#view-${other}`).setAttribute('aria-pressed',active);}
};
$('#zoom-in').onclick=()=>map.zoomBy(1.2);$('#zoom-out').onclick=()=>map.zoomBy(1/1.2);$('#fit').onclick=()=>map.fit();

// Shared disclosure behaviour for both floating modules; scroll stays inside panels.
function wireDisclosure(buttonId,contentId){const button=$(buttonId),content=$(contentId);button.onclick=()=>{const expanded=button.getAttribute('aria-expanded')!=='true';button.setAttribute('aria-expanded',expanded);button.setAttribute('aria-label',`${expanded?'Collapse':'Expand'} ${buttonId.includes('layers')?'field layers':'observations'}`);content.hidden=!expanded;if(expanded&&matchMedia('(max-width:700px), (max-height:560px)').matches){const other=$(buttonId.includes('layers')?'#observations-toggle':'#layers-toggle');if(other.getAttribute('aria-expanded')==='true')other.click();}};}
wireDisclosure('#layers-toggle','#layer-content');wireDisclosure('#observations-toggle','#observations-content');
if(matchMedia('(max-width:700px), (max-height:560px)').matches){$('#layers-toggle').click();$('#observations-toggle').click();}
function showToast(message){$('#toast').textContent=message;$('#toast').hidden=false;clearTimeout(toastTimer);toastTimer=setTimeout(()=>$('#toast').hidden=true,3200);}
$('#export').onclick=()=>{
  const url=URL.createObjectURL(new Blob([JSON.stringify({...survey,cameraEvidence,findings:survey.findings.map(finding=>({...finding,longitude:coordinatesFor(finding)[0],latitude:coordinatesFor(finding)[1]})),note:survey.scene?.note??'Received observations; results unvalidated.'},null,2)],{type:'application/json'}));
  const link=document.createElement('a');link.href=url;link.download='ithir-survey.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);showToast('Findings exported');
};
const setup=$('#connection-panel'),setupToggle=$('#connection-toggle');
function toggleSetup(open){if(open&&$('#phone-panel').matches(':popover-open'))$('#phone-panel').hidePopover();setup.hidden=!open;setupToggle.setAttribute('aria-expanded',open);if(open)$('#source').focus();else setupToggle.focus();}
$('#phone-toggle').addEventListener('click',()=>{setup.hidden=true;setupToggle.setAttribute('aria-expanded',false);});
setupToggle.onclick=()=>toggleSetup(setup.hidden);$('.close-panel').onclick=()=>toggleSetup(false);
$('#source').onchange=()=>{const live=$('#source').value==='live',scene=$('#source').value==='scene';$('#endpoint-fields').hidden=!live;$('#endpoint').disabled=!live;$('#scene-fields').hidden=!scene;$('#scene-url').disabled=!scene;};
document.addEventListener('keydown',event=>{if(event.key==='Escape'&&!setup.hidden)toggleSetup(false);});
document.addEventListener('pointerdown',event=>{if(!setup.hidden&&!setup.contains(event.target)&&!setupToggle.contains(event.target))toggleSetup(false);});
function connectionStatus(message,label,state=''){$('#connection-status').textContent=message;$('#connection-label').textContent=label;$('#connection-dot').className=`status-dot ${state}`;}
function cancelSceneLoad(){sceneRequest++;sceneController?.abort();sceneController=null;$('#scene-layer').disabled=false;}
function applySurvey(value){
  Object.assign(survey,{scene:null},value);selected=survey.findings[0]?.id;layer='all';
  map.setSurvey(survey);renderFindings();
}
async function loadSatellite(loaded,name){
  cancelSceneLoad();const request=sceneRequest;
  // Stop the old feed now; its displayed findings stay until the scene succeeds.
  if(socket){const previous=socket;socket=null;previous.onmessage=null;previous.onclose=null;previous.close();}
  sceneController=new AbortController();const options={signal:sceneController.signal,fetcher:loaded?.fetcher};
  $('#scene-layer').disabled=true;$('#scene-layer-status').textContent='Loading satellite layer…';
  connectionStatus('Loading satellite export… Existing observations remain until it is ready.','Loading scene');
  try{
    const next=loaded??await loadScene($('#scene-url').value.trim(),options);
    const data=await loadSceneLayer(next,name??next.layers.find(item=>item.name==='ndvi')?.name??next.layers[0].name,options);
    if(request!==sceneRequest)return;
    scenePackage=next;applySurvey(data);
    $('#scene-layer').replaceChildren(...next.layers.map(item=>{const option=document.createElement('option');option.value=item.name;option.textContent=`${item.name.replaceAll('_',' ')}${item.units?' · '+item.units:''}`;return option;}));
    $('#scene-layer').value=survey.scene.layer;$('#scene-layer-status').textContent=`${survey.scene.pixel_size_m} m source grid · ${survey.scene.width} × ${survey.scene.height}. ${survey.scene.sources}`;
    connectionStatus(`Loaded ${data.findings.length} sampled pixels. ${survey.scene.note}`,'Satellite scene','connected');
    if(!loaded)map.fit();
    if(!setup.hidden)toggleSetup(false);
  }catch(error){
    if(request!==sceneRequest||error.name==='AbortError')return;
    $('#scene-layer').value=survey.scene?.layer??'';
    const message=`${error.message} Existing observations retained. Check the scene address and server access.`;
    $('#scene-layer-status').textContent=message;connectionStatus(message,'Scene load failed','failed');showToast('Satellite layer could not load. Previous data retained.');
  }finally{if(request===sceneRequest){$('#scene-layer').disabled=false;sceneController=null;}}
}
$('#scene-layer').onchange=()=>{if(scenePackage)loadSatellite(scenePackage,$('#scene-layer').value);};
window.addEventListener('phone-image',event=>{
  cameraEvidence=event.detail;$('#camera-evidence-image').src=cameraEvidence.src;
  $('#camera-evidence-caption').textContent=`Stationary capture · ${cameraEvidence.capturedAt?new Date(cameraEvidence.capturedAt).toLocaleString():'capture time unavailable'} · ${cameraEvidence.location?`phone GPS ${cameraEvidence.location.latitude.toFixed(6)}, ${cameraEvidence.location.longitude.toFixed(6)} · ±${Math.round(cameraEvidence.location.accuracyM)} m`:'location not attached'}`;
  $('#camera-evidence').hidden=false;$('#export').disabled=false;showToast(cameraEvidence.location?'Camera still received · phone GPS attached':'Camera still received · location not attached');
});
window.addEventListener('phone-telemetry',event=>{droneTelemetry=event.detail;map.setTelemetry(droneTelemetry);dronePanel.setSample(droneTelemetry);});
window.addEventListener('phone-locate',()=>map.locateDrone());
function setFollow(on){
  if(on&&$('#view-3d').getAttribute('aria-pressed')!=='true')$('#view-3d').click();
  map.setFollow(on);$('#drone-follow').setAttribute('aria-pressed',on);$('#drone-follow').classList.toggle('active',on);$('#drone-follow-note').hidden=!on;
}
$('#drone-follow').onclick=()=>setFollow($('#drone-follow').getAttribute('aria-pressed')!=='true');
window.addEventListener('phone-results',event=>{loadSatellite(event.detail,'ph_0-5cm').then(()=>{if(survey.scene?.manifestUrl===event.detail.url)map.fit();});});
function receiveObservations(message,source){
  const findings=normaliseFeed(message);
  if(!findings.length)return false;
  cancelSceneLoad();applySurvey({findings,source,name:'Field observations'});
  connectionStatus(`Received ${findings.length} observations. Results remain unvalidated.`,source==='Bluetooth camera module'?'Camera module feed':'Connected','connected');
  return true;
}
window.addEventListener('phone-observations',event=>{
  if(receiveObservations(event.detail,'Bluetooth camera module')&&socket){socket.onclose=null;socket.close();socket=null;}
});
window.addEventListener('phone-link-state',event=>{
  droneTelemetry=null;if(event.detail.connected||phoneConnected){map.setTelemetry(null);dronePanel.setConnection(event.detail.connected);}phoneConnected=event.detail.connected;
  if(!event.detail.connected)setFollow(false);
  if(!event.detail.connected&&survey.source==='Bluetooth camera module')connectionStatus('Bluetooth disconnected. Last observations retained.','Disconnected','failed');
});
$('#connection-form').onsubmit=event=>{
  event.preventDefault();
  if($('#source').value==='scene'){loadSatellite();return;}
  if(!$('#source').value){connectionStatus('Choose a satellite scene or observation feed.','Data source');return;}
  let address;try{address=new URL($('#endpoint').value);if(!['ws:','wss:'].includes(address.protocol))throw new Error();if(location.protocol==='https:'&&address.protocol==='ws:')throw new Error();}catch{connectionStatus('Enter a valid ws:// or wss:// address. HTTPS pages require wss://.','Data source','failed');return;}
  let current;
  try{current=new WebSocket(address.href);}catch{connectionStatus('Could not open this WebSocket address. Check the URL and browser security settings.','Connection failed','failed');return;}
  if(socket){socket.onclose=null;socket.close();}
  socket=current;
  cancelSceneLoad();
  window.dispatchEvent(new Event('phone-disconnect'));
  connectionStatus('Opening connection…','Connecting');
  current.onopen=()=>{if(socket!==current)return;connectionStatus('Connected. Waiting for observations with latitude/longitude positions.','Connected','connected');};
  current.onmessage=event=>{
    if(socket!==current)return;
    try{if(!receiveObservations(JSON.parse(event.data),'Connected WebSocket feed'))connectionStatus('Message received, but no usable geographic positions. Existing data retained.','Connected','connected');
    }catch{connectionStatus('Message could not be read as JSON. Existing observations retained.','Connected','connected');}
  };
  current.onerror=()=>{if(socket===current)connectionStatus('Connection failed. Check the address and that the camera module or observation feed is running.','Connection failed','failed');};
  current.onclose=()=>{if(socket===current)connectionStatus('Connection closed. Last observations retained; apply the connection to reconnect.','Disconnected','failed');};
};
renderFindings();
