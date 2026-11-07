import { survey as sample } from './sample-data.mjs';
import { findingsForLayer, retainSelection } from './survey.mjs';
import { createFieldMap, normaliseFeed } from './map.mjs';

const $ = selector => document.querySelector(selector);
const survey = structuredClone(sample);
let selected = survey.findings[0]?.id, layer = 'all', elapsed = 0, playing = false, speed = 1, previousFrame = 0;
let socket = null, toastTimer, demo = true;
const formatTime = value => `${String(Math.floor(value/60)).padStart(2,'0')}:${String(Math.floor(value%60)).padStart(2,'0')}`;
const escape = value => String(value).replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const map = createFieldMap($('#map'),survey,selectFinding);

function renderFindings(){
  const findings=findingsForLayer(survey.findings,layer);
  selected=retainSelection(findings,selected);
  $('#finding-count').textContent=findings.length;
  $('#finding-list').replaceChildren();
  findings.forEach(finding=>{
    const button=document.createElement('button');button.className=`finding-item ${finding.id===selected?'active':''}`;
    button.dataset.id=finding.id;button.setAttribute('aria-pressed',finding.id===selected);
    const number=String(survey.findings.indexOf(finding)+1).padStart(2,'0');
    button.innerHTML=`<span class="finding-number ${finding.tone==='teal'?'teal':''}">${number}</span><span class="finding-copy"><strong>${escape(finding.title)}</strong><small>${formatTime(finding.time)} · ${demo?'Sample finding':'Received finding'}</small></span><svg class="icon" aria-hidden="true"><use href="#i-chevron"/></svg>`;
    button.onclick=()=>selectFinding(finding.id);$('#finding-list').append(button);
  });
  if(!findings.length)$('#finding-list').innerHTML='<div class="empty-state"><h3>No assessment available</h3><p>This layer has no supporting observations. Missing data does not mean the field is healthy.</p></div>';
  renderDetail();map.setLayer(layer);map.setSelected(selected);updateSourceLabels();
}
function updateSourceLabels(){
  const view=$('#view-2d').getAttribute('aria-pressed')==='true'?'2D':'3D';
  $('#map-mode-label').textContent=`${view} ${demo?'sample':'feed'} view`;
  $('#survey-context').textContent=`Cork, Ireland · ${demo?'Sample survey':'Feed observations'}`;
  $('#legend-note').textContent=layer==='soil'?'No supported soil-property data':demo?'Illustrative intensity · not a measurement':'Feed locations · no measured intensity';
  $('.legend-scale').hidden=!demo;
}
function renderDetail(){
  const finding=survey.findings.find(item=>item.id===selected);
  const detail=$('#finding-detail');
  if(!finding){detail.hidden=true;return;}detail.hidden=false;
  detail.innerHTML=`<div class="detail-top"><span class="evidence-label">${demo?'Hand-authored example':'Feed result'}</span><span class="evidence-status ${finding.tone==='teal'?'teal':''}">${escape(finding.status)}</span></div><h3>${escape(finding.title)}</h3><p>${escape(finding.description)}</p><div class="inspection-action"><svg class="icon" aria-hidden="true"><use href="#i-pin"/></svg><div><strong>Suggested check</strong><p>${escape(finding.action)}</p></div></div>`;
}
function selectFinding(id){
  const finding=survey.findings.find(item=>item.id===id);if(!finding)return;
  selected=id;elapsed=finding.time;playing=false;
  document.querySelectorAll('.finding-item').forEach(button=>{const active=button.dataset.id===id;button.classList.toggle('active',active);button.setAttribute('aria-pressed',active);});
  renderDetail();map.setSelected(id);updateReplay();
}
function updateReplay(){
  map.setTime(elapsed);$('#timeline').value=elapsed;$('#elapsed').textContent=formatTime(elapsed);
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
$('#play').onclick=()=>{if(elapsed>=survey.duration)elapsed=0;playing=!playing;updateReplay();};
$('#timeline').oninput=event=>{elapsed=Number(event.target.value);playing=false;updateReplay();};
$('#speed').onclick=()=>{speed=speed===1?2:speed===2?4:1;$('#speed').textContent=`${speed}×`;$('#speed').setAttribute('aria-label',`Playback speed, ${speed} times`);};
$('#layers').onclick=event=>{
  const button=event.target.closest('[data-layer]');if(!button)return;layer=button.dataset.layer;
  $('#layers').querySelectorAll('button').forEach(item=>{const active=item===button;item.classList.toggle('active',active);item.setAttribute('aria-pressed',active);item.querySelector('.layer-check')?.remove();if(active){const check=document.createElement('span');check.className='layer-check';check.textContent='✓';item.append(check);}});
  const findings=findingsForLayer(survey.findings,layer);if(!findings.some(item=>item.id===selected))selected=findings[0]?.id;
  $('#legend-note').textContent=layer==='soil'?'No supported soil-property data':demo?'Illustrative intensity · not a measurement':'Feed locations · no measured intensity';
  renderFindings();
};
for(const view of ['2d','3d'])$(`#view-${view}`).onclick=()=>{
  map.setView(view);for(const other of ['2d','3d']){const active=other===view;$(`#view-${other}`).classList.toggle('active',active);$(`#view-${other}`).setAttribute('aria-pressed',active);}
  $('#map-mode-label').textContent=`${view.toUpperCase()} ${demo?'sample':'feed'} view`;
};
$('#zoom-in').onclick=()=>map.zoomBy(1.2);$('#zoom-out').onclick=()=>map.zoomBy(1/1.2);$('#fit').onclick=()=>map.fit();

// Shared disclosure behaviour for both floating modules; scroll stays inside panels.
function wireDisclosure(buttonId,contentId){const button=$(buttonId),content=$(contentId);button.onclick=()=>{const expanded=button.getAttribute('aria-expanded')!=='true';button.setAttribute('aria-expanded',expanded);button.setAttribute('aria-label',`${expanded?'Collapse':'Expand'} ${buttonId.includes('layers')?'field layers':'observations'}`);content.hidden=!expanded;if(expanded&&matchMedia('(max-width:700px), (max-height:560px)').matches){const other=$(buttonId.includes('layers')?'#observations-toggle':'#layers-toggle');if(other.getAttribute('aria-expanded')==='true')other.click();}};}
wireDisclosure('#layers-toggle','#layer-content');wireDisclosure('#observations-toggle','#observations-content');
if(matchMedia('(max-width:700px), (max-height:560px)').matches){$('#layers-toggle').click();$('#observations-toggle').click();}
function showToast(message){$('#toast').textContent=message;$('#toast').hidden=false;clearTimeout(toastTimer);toastTimer=setTimeout(()=>$('#toast').hidden=true,3200);}
$('#export').onclick=()=>{
  const url=URL.createObjectURL(new Blob([JSON.stringify({...survey,note:demo?'Illustrative sample; no AI analysis or flight.':'Feed observations unvalidated; route remains simulated.'},null,2)],{type:'application/json'}));
  const link=document.createElement('a');link.href=url;link.download='corkathon-survey.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);showToast('Findings exported');
};
const setup=$('#connection-panel'),setupToggle=$('#connection-toggle');
function toggleSetup(open){setup.hidden=!open;setupToggle.setAttribute('aria-expanded',open);if(open)$('#source').focus();else setupToggle.focus();}
setupToggle.onclick=()=>toggleSetup(setup.hidden);$('.close-panel').onclick=()=>toggleSetup(false);
$('#source').onchange=()=>{const live=$('#source').value==='live';$('#endpoint-fields').hidden=!live;$('#endpoint').disabled=!live;};
document.addEventListener('keydown',event=>{if(event.key==='Escape'&&!setup.hidden)toggleSetup(false);});
document.addEventListener('pointerdown',event=>{if(!setup.hidden&&!setup.contains(event.target)&&!setupToggle.contains(event.target))toggleSetup(false);});
function connectionStatus(message,label,state=''){$('#connection-status').textContent=message;$('#connection-label').textContent=label;$('#connection-dot').className=`status-dot ${state}`;}
$('#connection-form').onsubmit=event=>{
  event.preventDefault();
  if($('#source').value==='demo'){
    if(socket){socket.onclose=null;socket.close();socket=null;}
    survey.findings=structuredClone(sample.findings);survey.source=sample.source;survey.illustrative=true;demo=true;selected=survey.findings[0]?.id;playing=false;elapsed=0;map.setSurvey(survey);renderFindings();updateReplay();
    $('#source-credit').textContent='Sample data · illustrative map & simulated positions';connectionStatus('Using six hand-authored observations.','Demo source');showToast('Sample survey loaded');return;
  }
  let address;try{address=new URL($('#endpoint').value);if(!['ws:','wss:'].includes(address.protocol))throw new Error();if(location.protocol==='https:'&&address.protocol==='ws:')throw new Error();}catch{connectionStatus('Enter a valid ws:// or wss:// address. HTTPS pages require wss://.','Not connected','failed');return;}
  let current;
  try{current=new WebSocket(address.href);}catch{connectionStatus('Could not open this WebSocket address. Check the URL and browser security settings.','Connection failed','failed');return;}
  if(socket){socket.onclose=null;socket.close();}
  socket=current;
  connectionStatus('Opening connection…','Connecting');
  current.onopen=()=>{if(socket!==current)return;connectionStatus('Connected. Waiting for observations with map x/y positions.','Connected','connected');};
  current.onmessage=event=>{
    if(socket!==current)return;
    try{const findings=normaliseFeed(JSON.parse(event.data));if(!findings.length){connectionStatus('Message received, but no usable map x/y observations. Existing data retained.','Connected','connected');return;}
      survey.findings=findings;survey.source='Connected WebSocket feed';survey.illustrative=false;demo=false;selected=findings[0].id;playing=false;map.setSurvey(survey);renderFindings();updateReplay();$('#source-credit').textContent='Feed observations · illustrative map & simulated route';connectionStatus(`Received ${findings.length} observations. Results remain unvalidated.`,'Connected','connected');
    }catch{connectionStatus('Message could not be read as JSON. Existing observations retained.','Connected','connected');}
  };
  current.onerror=()=>{if(socket===current)connectionStatus('Connection failed. Check the address and that the phone or AI feed is running.','Connection failed','failed');};
  current.onclose=()=>{if(socket===current)connectionStatus('Connection closed. Last observations retained; apply the connection to reconnect.','Disconnected','failed');};
};
let lastDraw=0;
function frame(now){
  if(playing&&previousFrame){elapsed=Math.min(survey.duration,elapsed+Math.min((now-previousFrame)/1000,.25)*speed);if(elapsed>=survey.duration)playing=false;if(now-lastDraw>33||!playing){updateReplay();lastDraw=now;}}
  previousFrame=now;requestAnimationFrame(frame);
}
renderFindings();updateReplay();requestAnimationFrame(frame);
