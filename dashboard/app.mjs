import { survey as sample } from './sample-data.mjs';
import { findingsForLayer, retainSelection } from './survey.mjs';
import { createFieldMap } from './map.mjs';
import { normaliseFeed, coordinatesFor, demoArea } from './geo.mjs';

const $ = selector => document.querySelector(selector);
const survey = {name:'Cork survey area',source:null,illustrative:false,duration:0,route:[],findings:[]};
let selected = survey.findings[0]?.id, layer = 'all', elapsed = 0, playing = false, speed = 1, previousFrame = 0;
let socket = null, toastTimer,animationFrame=0,analysisState=null;
const formatTime = value => `${String(Math.floor(value/60)).padStart(2,'0')}:${String(Math.floor(value%60)).padStart(2,'0')}`;
const escape = value => String(value).replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const map = createFieldMap($('#map'),survey,selectFinding,message=>{const notice=$('#map-notice');notice.hidden=!message;notice.textContent=message??'';},updateBasemapUi,updateAnalysisUi,inspectCell);

function renderFindings(){
  const findings=findingsForLayer(survey.findings,layer);
  selected=retainSelection(findings,selected);
  $('#finding-count').textContent=findings.length;
  $('#finding-list').replaceChildren();
  findings.forEach(finding=>{
    const button=document.createElement('button');button.className=`finding-item ${finding.id===selected?'active':''}`;
    button.dataset.id=finding.id;button.setAttribute('aria-pressed',finding.id===selected);
    const number=String(survey.findings.indexOf(finding)+1).padStart(2,'0');
    button.innerHTML=`<span class="finding-number ${finding.tone==='teal'?'teal':''}">${number}</span><span class="finding-copy"><strong>${escape(finding.title)}</strong><small>${survey.illustrative?formatTime(finding.time):escape(finding.status)}</small></span><svg class="icon" aria-hidden="true"><use href="#i-chevron"/></svg>`;
    button.onclick=()=>selectFinding(finding.id);$('#finding-list').append(button);
  });
  if(!findings.length)$('#finding-list').innerHTML=survey.findings.length?'<div class="empty-state"><h3>No observations in this layer</h3><p>Choose another layer to see available findings.</p></div>':'<div class="empty-state"><h3>Your field observations, here.</h3><p>Connect your camera module or an observation feed to start reviewing your survey.</p><button id="empty-connect" class="button primary">Connect a source</button></div>';
  $('#empty-connect')?.addEventListener('click',()=>toggleSetup(true));
  $('.layers-panel').hidden=!survey.findings.length;
  $('#export').disabled=!survey.findings.length;
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
  $('#survey-context').textContent=survey.illustrative?'Sample survey · illustrative positions':survey.findings.length?`${survey.findings.length} observations · ${survey.source}`:'No survey loaded';
  if(analysisState)updateAnalysisUi(analysisState);
  $('#source-credit').textContent=survey.illustrative?'Sample observations · illustrative positions & simulated route':survey.findings.length?'Received observations · unvalidated':'Survey extent · no observations loaded';
}
const formatValue=value=>Number.isFinite(value)?new Intl.NumberFormat('en-IE',{maximumFractionDigits:3}).format(value):'—';
function updateAnalysisUi(state){
  analysisState=state;
  const hasCells=state.cells.length>0;
  $('.analysis-controls').hidden=!hasCells;
  $('.legend').hidden=!hasCells;
  $('.legend-scale').hidden=!hasCells;
  $('#analysis-metric').textContent=state.metric;
  $('#analysis-kind').textContent=state.sample?'Sample':'Unvalidated';
  $('#analysis-min').textContent=formatValue(state.min);$('#analysis-max').textContent=formatValue(state.max);
  $('#analysis-unit').textContent=state.unit||state.metric;
  $('#analysis-size-label').textContent=state.sample?'Cell diameter':'Display diameter';
  $('#analysis-count').textContent=`${state.cells.length.toLocaleString()} ${state.sample?'sample cells':'value points'}`;
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
  $('#cell-readout').textContent=cell?`${cell.sample?'Sample cell':'Received point'}: ${formatValue(cell.value)} ${cell.unit||cell.metric}`:'Hover, tap, or use arrows to inspect cells.';
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
  tooltip.textContent=`${cell.sample?'Sample':'Unvalidated'} · ${cell.metric}: ${formatValue(cell.value)} ${cell.unit}`;
  tooltip.style.left=`${Math.max(12,Math.min(innerWidth-tooltip.offsetWidth-12,cell.x+16))}px`;
  tooltip.style.top=`${Math.max(12,Math.min(innerHeight-tooltip.offsetHeight-12,cell.y+16))}px`;
});
window.addEventListener('keydown',event=>{if(event.key==='Escape')$('#analysis-tooltip').hidden=true;});
function renderDetail(){
  const finding=survey.findings.find(item=>item.id===selected);
  const detail=$('#finding-detail');
  if(!finding){detail.hidden=true;return;}detail.hidden=false;
  detail.innerHTML=`<div class="detail-top"><span class="evidence-label">${survey.illustrative?'Sample observation':'Received observation'}</span><span class="evidence-status ${finding.tone==='teal'?'teal':''}">${escape(finding.status)}</span></div><h3>${escape(finding.title)}</h3><p>${escape(finding.description)}</p><div class="inspection-action"><svg class="icon" aria-hidden="true"><use href="#i-pin"/></svg><div><strong>Suggested check</strong><p>${escape(finding.action)}</p></div></div>`;
}
function selectFinding(id){
  const finding=survey.findings.find(item=>item.id===id);if(!finding)return;
  selected=id;elapsed=survey.illustrative?finding.time:0;playing=false;
  document.querySelectorAll('.finding-item').forEach(button=>{const active=button.dataset.id===id;button.classList.toggle('active',active);button.setAttribute('aria-pressed',active);});
  renderDetail();map.setSelected(id);updateReplay();
}
function updateReplay(){
  map.setTime(elapsed);$('#timeline').value=elapsed;$('#elapsed').textContent=formatTime(elapsed);
  $('.replay-panel').hidden=!survey.route.length;$('#timeline').max=survey.duration;$('#duration').textContent=formatTime(survey.duration);
  $('#reached').textContent=`${survey.findings.filter(item=>item.time<=elapsed).length} of ${survey.findings.length} reached`;
  const label=playing?'Pause survey':elapsed>=survey.duration?'Replay survey':'Play survey';
  $('#play').setAttribute('aria-label',label);
  // Keep the focused button itself stable, and only update its glyph on state changes.
  if($('#play').dataset.playing!==String(playing)){
    $('#play').dataset.playing=playing;
    $('#play').innerHTML=playing?'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 5h4v14H7zM15 5h4v14h-4z" fill="currentColor"/></svg>':'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m9 5 11 7-11 7z" fill="currentColor"/></svg>';
  }
  $('.map-mode').textContent=`${playing?'Playing':elapsed>=survey.duration?'Complete':'Paused'} · simulated route`;
}
$('#play').onclick=()=>{if(elapsed>=survey.duration)elapsed=0;playing=!playing;cancelAnimationFrame(animationFrame);previousFrame=0;if(playing)animationFrame=requestAnimationFrame(frame);updateReplay();};
$('#timeline').oninput=event=>{elapsed=Number(event.target.value);playing=false;updateReplay();};
$('#speed').onclick=()=>{speed=speed===1?2:speed===2?4:1;$('#speed').textContent=`${speed}×`;$('#speed').setAttribute('aria-label',`Playback speed, ${speed} times`);};
$('#layers').onclick=event=>{
  const button=event.target.closest('[data-layer]');if(!button)return;layer=button.dataset.layer;
  $('#layers').querySelectorAll('button').forEach(item=>{const active=item===button;item.classList.toggle('active',active);item.setAttribute('aria-pressed',active);item.querySelector('.layer-check')?.remove();if(active){const check=document.createElement('span');check.className='layer-check';check.textContent='✓';item.append(check);}});
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
  const url=URL.createObjectURL(new Blob([JSON.stringify({...survey,area:demoArea,findings:survey.findings.map(finding=>({...finding,longitude:coordinatesFor(finding)[0],latitude:coordinatesFor(finding)[1]})),note:survey.illustrative?'Illustrative sample; no AI analysis or flight.':'Received observations; results unvalidated.'},null,2)],{type:'application/json'}));
  const link=document.createElement('a');link.href=url;link.download='ithir-survey.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);showToast('Findings exported');
};
const setup=$('#connection-panel'),setupToggle=$('#connection-toggle');
function toggleSetup(open){if(open&&$('#phone-panel').matches(':popover-open'))$('#phone-panel').hidePopover();setup.hidden=!open;setupToggle.setAttribute('aria-expanded',open);if(open)$('#source').focus();else setupToggle.focus();}
$('#phone-toggle').addEventListener('click',()=>{setup.hidden=true;setupToggle.setAttribute('aria-expanded',false);});
setupToggle.onclick=()=>toggleSetup(setup.hidden);$('.close-panel').onclick=()=>toggleSetup(false);
$('#source').onchange=()=>{const live=$('#source').value==='live';$('#endpoint-fields').hidden=!live;$('#endpoint').disabled=!live;};
document.addEventListener('keydown',event=>{if(event.key==='Escape'&&!setup.hidden)toggleSetup(false);});
document.addEventListener('pointerdown',event=>{if(!setup.hidden&&!setup.contains(event.target)&&!setupToggle.contains(event.target))toggleSetup(false);});
function connectionStatus(message,label,state=''){$('#connection-status').textContent=message;$('#connection-label').textContent=label;$('#connection-dot').className=`status-dot ${state}`;}
function receiveObservations(message,source){
  const findings=normaliseFeed(message);
  if(!findings.length)return false;
  survey.findings=findings;survey.source=source;survey.illustrative=false;survey.route=[];survey.duration=0;elapsed=0;selected=findings[0].id;playing=false;
  map.setSurvey(survey);renderFindings();updateReplay();
  connectionStatus(`Received ${findings.length} observations. Results remain unvalidated.`,source==='Bluetooth camera module'?'Camera module feed':'Connected','connected');
  return true;
}
window.addEventListener('phone-observations',event=>{
  if(receiveObservations(event.detail,'Bluetooth camera module')&&socket){socket.onclose=null;socket.close();socket=null;}
});
window.addEventListener('phone-link-state',event=>{
  if(!event.detail.connected&&survey.source==='Bluetooth camera module')connectionStatus('Bluetooth disconnected. Last observations retained.','Disconnected','failed');
});
$('#connection-form').onsubmit=event=>{
  event.preventDefault();
  if($('#source').value==='demo'){
    window.dispatchEvent(new Event('phone-disconnect'));
    if(socket){socket.onclose=null;socket.close();socket=null;}
    Object.assign(survey,structuredClone(sample));selected=survey.findings[0]?.id;playing=false;elapsed=0;map.setSurvey(survey);renderFindings();updateReplay();
    connectionStatus('Sample observations and simulated movement. No field measurements.','Sample survey');toggleSetup(false);showToast('Sample survey loaded');return;
  }
  if(!$('#source').value){connectionStatus('Choose an observation feed or sample survey.','Data source');return;}
  let address;try{address=new URL($('#endpoint').value);if(!['ws:','wss:'].includes(address.protocol))throw new Error();if(location.protocol==='https:'&&address.protocol==='ws:')throw new Error();}catch{connectionStatus('Enter a valid ws:// or wss:// address. HTTPS pages require wss://.','Data source','failed');return;}
  let current;
  try{current=new WebSocket(address.href);}catch{connectionStatus('Could not open this WebSocket address. Check the URL and browser security settings.','Connection failed','failed');return;}
  if(socket){socket.onclose=null;socket.close();}
  socket=current;
  window.dispatchEvent(new Event('phone-disconnect'));
  connectionStatus('Opening connection…','Connecting');
  current.onopen=()=>{if(socket!==current)return;connectionStatus('Connected. Waiting for observations with latitude/longitude positions.','Connected','connected');};
  current.onmessage=event=>{
    if(socket!==current)return;
    try{if(!receiveObservations(JSON.parse(event.data),'Connected WebSocket feed'))connectionStatus('Message received, but no usable geographic or sample-grid positions. Existing data retained.','Connected','connected');
    }catch{connectionStatus('Message could not be read as JSON. Existing observations retained.','Connected','connected');}
  };
  current.onerror=()=>{if(socket===current)connectionStatus('Connection failed. Check the address and that the camera module or observation feed is running.','Connection failed','failed');};
  current.onclose=()=>{if(socket===current)connectionStatus('Connection closed. Last observations retained; apply the connection to reconnect.','Disconnected','failed');};
};
let lastDraw=0;
function frame(now){
  if(!playing)return;
  if(previousFrame){elapsed=Math.min(survey.duration,elapsed+Math.min((now-previousFrame)/1000,.25)*speed);if(elapsed>=survey.duration)playing=false;if(now-lastDraw>33||!playing){updateReplay();lastDraw=now;}}
  previousFrame=now;if(playing)animationFrame=requestAnimationFrame(frame);
}
renderFindings();updateReplay();
