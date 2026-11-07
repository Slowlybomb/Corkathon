import { positionAt, findingsForLayer } from './survey.mjs';

export function projectPoint(x, y, height, camera) {
  const dx = x - 500, dy = y - 450;
  return {
    x: camera.x + (dx * Math.cos(camera.angle) - dy * Math.sin(camera.angle)) * camera.scale,
    y: camera.y + ((dx * Math.sin(camera.angle) + dy * Math.cos(camera.angle)) * Math.cos(camera.pitch) - height * Math.sin(camera.pitch)) * camera.scale,
  };
}

// Deliberately permissive prototype adapter; no required on-wire schema.
export function normaliseFeed(message) {
  const records = Array.isArray(message) ? message : message?.findings ?? message?.observations ?? [message];
  if (!Array.isArray(records)) return [];
  return records.slice(0, 1000).flatMap((item, index) => {
    if (!item || typeof item !== 'object') return [];
    const point = item.position ?? item;
    const x = Number(point.x), y = Number(point.y);
    if (!Number.isFinite(x) || !Number.isFinite(y) || x < 0 || y < 0 || x > 1000 || y > 900) return [];
    const layer = ['coverage', 'moisture', 'anomalies', 'soil'].includes(item.layer) ? item.layer : 'anomalies';
    return [{ id: `feed-${index}`, title: String(item.title ?? item.label ?? 'Received observation').slice(0, 120), x, y, layer,
      time: Math.max(0, Math.min(150, Number(item.time) || 0)), tone: layer === 'coverage' ? 'teal' : 'amber',
      status: 'Received · unvalidated', description: String(item.description ?? 'Received from the connected feed. Review the supporting evidence.').slice(0, 2000),
      action: String(item.action ?? 'Review this observation before taking action.').slice(0, 500) }];
  });
}

export function createFieldMap(canvas, initialSurvey, onSelect) {
  const ctx = canvas.getContext('2d');
  let survey = initialSurvey, layer = 'all', selected = initialSurvey.findings[0]?.id;
  let view = '3d', time = 0, zoom = 1, panX = 0, panY = 0, angle = -.16;
  let width = 0, height = 0, hitPoints = [], drag = null;
  const image = new Image();
  const camera = () => { const fit = fitCamera(width,height,view,angle); return {...fit,x:fit.x+panX,y:fit.y+panY,scale:fit.scale*zoom}; };
  function polygon(points, fill, stroke) {
    ctx.beginPath(); points.forEach((p, i) => i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y)); ctx.closePath();
    if (fill) { ctx.fillStyle = fill; ctx.fill(); }
    if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = 1; ctx.stroke(); }
  }
  function render() {
    if (!width || !height) return;
    const dpr = Math.min(devicePixelRatio || 1, 2);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.clearRect(0, 0, width, height);
    ctx.fillStyle = '#314b35'; ctx.fillRect(0, 0, width, height);
    const cam = camera();
    const p = (x, y, z = 0) => projectPoint(x, y, z, cam);
    if (image.complete && image.naturalWidth) {
      const a = p(0, 0), b = p(1000, 0), c = p(0, 900);
      ctx.save(); ctx.transform((b.x-a.x)/1000, (b.y-a.y)/1000, (c.x-a.x)/900, (c.y-a.y)/900, a.x, a.y);
      ctx.drawImage(image, 0, 0, 1000, 900); ctx.restore();
    }
    const findings = findingsForLayer(survey.findings, layer);
    // ponytail: fixed illustrative grid, not a GIS raster or measured soil surface.
    // Replace this derived sample surface when georeferenced AI output exists.
    const cells = [];
    if (survey.illustrative && layer !== 'soil' && findings.length) {
      for (let y = 190; y < 705; y += 18) for (let x = 250; x < 745; x += 18) {
        if (x < 265-(y-148)*.095 || x > 778-(y-225)*.147 || y < 148+(x-265)*.15 || y > 657+(x-215)*.2) continue;
        let intensity = .08;
        for (const finding of findings) intensity = Math.max(intensity, Math.exp(-((x-finding.x)**2+(y-finding.y)**2)/6500) * .92);
        intensity = Math.min(1, intensity + (Math.sin(x*.052)*Math.cos(y*.037)+1)*.035);
        cells.push({ x, y, intensity, depth: (x-500)*Math.sin(cam.angle)+(y-450)*Math.cos(cam.angle) });
      }
    }
    cells.sort((a,b) => a.depth-b.depth);
    for (const cell of cells) {
      const { x, y, intensity: v } = cell;
      const z = view === '3d' ? 3 + v * 75 : 0;
      const color = v < .22 ? '#2c6e49' : v < .42 ? '#4c956c' : v < .66 ? '#fefee3' : v < .83 ? '#ffc9b9' : '#d68c45';
      const a = p(x,y,z), b = p(x+16,y,z), c = p(x+16,y+16,z), d = p(x,y+16,z);
      if (view === '3d') {
        polygon([b,c,p(x+16,y+16),p(x+16,y)], '#245138');
        polygon([d,c,p(x+16,y+16),p(x,y+16)], v > .66 ? '#aa713c' : '#3e7855');
      }
      polygon([a,b,c,d], color);
    }
    ctx.lineWidth = 1.4; ctx.strokeStyle = '#fefee3b3'; ctx.beginPath();
    [[265,148],[778,225],[700,753],[215,657],[265,148]].forEach(([x,y],i)=>{ const pt=p(x,y);i?ctx.lineTo(pt.x,pt.y):ctx.moveTo(pt.x,pt.y); }); ctx.stroke();
    ctx.setLineDash([4,6]); ctx.lineWidth=1.5; ctx.strokeStyle='#fefee3b0'; ctx.beginPath();
    survey.route.forEach((point,i)=>{const pt=p(point.x,point.y,3);i?ctx.lineTo(pt.x,pt.y):ctx.moveTo(pt.x,pt.y);});ctx.stroke();ctx.setLineDash([]);
    const label=p(475,735);ctx.font='600 12px Manrope, sans-serif';ctx.textAlign='center';ctx.fillStyle='#fefee3';ctx.shadowColor='#102c20';ctx.shadowBlur=5;ctx.fillText(survey.name,label.x,label.y);ctx.shadowBlur=0;
    hitPoints=[];
    findings.forEach(finding=>{
      const point=p(finding.x,finding.y,view==='3d'?93:3), ground=p(finding.x,finding.y,2);
      ctx.beginPath();ctx.moveTo(ground.x,ground.y);ctx.lineTo(point.x,point.y);ctx.strokeStyle='#fefee38c';ctx.lineWidth=1;ctx.stroke();
      ctx.beginPath();ctx.arc(point.x,point.y,selected===finding.id?17:13,0,Math.PI*2);ctx.fillStyle=selected===finding.id?'#fefee3':'#153526';ctx.fill();ctx.strokeStyle='#fefee3';ctx.lineWidth=1;ctx.stroke();
      ctx.fillStyle=selected===finding.id?'#2c6e49':'#fefee3';ctx.font='700 10px Manrope, sans-serif';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(String(survey.findings.indexOf(finding)+1).padStart(2,'0'),point.x,point.y);
      hitPoints.push({...point,id:finding.id});
    });
    const drone=positionAt(survey.route,time);
    if(drone){const pt=p(drone.x,drone.y,view==='3d'?120:8);ctx.beginPath();ctx.arc(pt.x,pt.y,9,0,Math.PI*2);ctx.fillStyle='#ffc9b9';ctx.fill();ctx.strokeStyle='#102c20';ctx.lineWidth=2;ctx.stroke();ctx.fillStyle='#102c20';ctx.font='700 9px Manrope, sans-serif';ctx.fillText('D',pt.x,pt.y+.5);}
    ctx.textBaseline='alphabetic';
  }
  function resize(){width=canvas.clientWidth;height=canvas.clientHeight;const dpr=Math.min(devicePixelRatio||1,2);canvas.width=Math.round(width*dpr);canvas.height=Math.round(height*dpr);render();}
  image.onload=render; image.src='assets/field-map.svg';
  new ResizeObserver(resize).observe(canvas);
  canvas.addEventListener('pointerdown',event=>{drag={x:event.clientX,y:event.clientY,panX,panY,angle,moved:false};canvas.setPointerCapture(event.pointerId);});
  canvas.addEventListener('pointermove',event=>{if(!drag)return;const dx=event.clientX-drag.x,dy=event.clientY-drag.y;if(Math.hypot(dx,dy)>4)drag.moved=true;if(event.shiftKey&&view==='3d')angle=drag.angle+dx*.005;else{panX=drag.panX+dx;panY=drag.panY+dy;}render();});
  canvas.addEventListener('pointerup',event=>{if(!drag)return;if(!drag.moved){const rect=canvas.getBoundingClientRect();const hit=hitPoints.find(point=>Math.hypot(point.x-event.clientX+rect.left,point.y-event.clientY+rect.top)<24);if(hit)onSelect(hit.id);}drag=null;});
  canvas.addEventListener('pointercancel',()=>{drag=null;});
  canvas.addEventListener('wheel',event=>{event.preventDefault();zoom=Math.max(.5,Math.min(3,zoom*(event.deltaY>0?.93:1.07)));render();},{passive:false});
  canvas.addEventListener('keydown',event=>{
    if(['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','+','=','-'].includes(event.key))event.preventDefault();
    if(event.key==='ArrowLeft')panX+=30;if(event.key==='ArrowRight')panX-=30;if(event.key==='ArrowUp')panY+=30;if(event.key==='ArrowDown')panY-=30;
    if(event.key==='+'||event.key==='=')zoom=Math.min(3,zoom*1.15);if(event.key==='-')zoom=Math.max(.5,zoom/1.15);render();
  });
  resize();
  return {
    setView(value){view=value;render();},setLayer(value){layer=value;render();},setSelected(value){selected=value;render();},setTime(value){time=value;render();},
    setSurvey(value){survey=value;render();},zoomBy(factor){zoom=Math.max(.5,Math.min(3,zoom*factor));render();},fit(){zoom=1;panX=0;panY=0;angle=-.16;render();},
  };
}

export function fitCamera(width, height, view = '3d', angle = -.16) {
  const base = { x: 0, y: 0, scale: 1, angle: view === '3d' ? angle : 0, pitch: view === '3d' ? .88 : 0 };
  const bounds = [[265,148],[778,225],[700,753],[215,657]].flatMap(([x,y]) => [projectPoint(x,y,0,base),projectPoint(x,y,view === '3d' ? 120 : 0,base)]);
  const minX=Math.min(...bounds.map(p=>p.x)), maxX=Math.max(...bounds.map(p=>p.x));
  const minY=Math.min(...bounds.map(p=>p.y)), maxY=Math.max(...bounds.map(p=>p.y));
  const left=width>=1100?282:20, right=width>=1100?width-330:width-20;
  const top=104, bottom=height-128;
  const scale=Math.max(.05,Math.min((right-left)/(maxX-minX),(bottom-top)/(maxY-minY)));
  return {...base,scale,x:(left+right)/2-(minX+maxX)*scale/2,y:(top+bottom)/2-(minY+maxY)*scale/2};
}
