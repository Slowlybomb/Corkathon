import * as THREE from 'three';
import { positionAt, findingsForLayer } from './survey.mjs';
import { demoArea, coordinatesFor, localToLngLat, areaBounds } from './geo.mjs';

const colors=['#2c6e49','#4c956c','#fefee3','#ffc9b9','#d68c45'];
const collection=features=>({type:'FeatureCollection',features});
const feature=(geometry,properties={})=>({type:'Feature',geometry,properties});

export function createFieldMap(container,initialSurvey,onSelect,onStatus=()=>{}){
  const maplibregl=window.maplibregl;
  if(!maplibregl)throw new Error('MapLibre did not load');
  let survey=initialSurvey,layer='all',selected=survey.findings[0]?.id,view='3d',time=0,ready=false;
  const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
  const map=new maplibregl.Map({
    container,style:'https://tiles.openfreemap.org/styles/liberty',
    center:[demoArea.center.longitude,demoArea.center.latitude],zoom:12.5,pitch:52,bearing:-12,
    maxPitch:70,attributionControl:false,canvasContextAttributes:{antialias:true},
  });
  map.addControl(new maplibregl.AttributionControl({compact:true}),'bottom-right');
  map.getCanvas().setAttribute('aria-label','Cork demo map. Drag to pan, right-drag to rotate. Findings are available in the observations list.');
  const origin=maplibregl.MercatorCoordinate.fromLngLat([demoArea.center.longitude,demoArea.center.latitude],0);
  const meter=origin.meterInMercatorCoordinateUnits();
  function local(point,altitude=0){
    const mercator=maplibregl.MercatorCoordinate.fromLngLat(coordinatesFor(point),altitude);
    return new THREE.Vector3((mercator.x-origin.x)/meter,-(mercator.y-origin.y)/meter,(mercator.z-origin.z)/meter);
  }
  const scene=new THREE.Scene(),camera=new THREE.Camera();
  scene.add(new THREE.AmbientLight(0xffffff,2));
  const light=new THREE.DirectionalLight(0xfff7dc,2.5);light.position.set(-1500,-2500,4500);scene.add(light);
  const columns=new THREE.Group();scene.add(columns);
  const drone=new THREE.Group();scene.add(drone);
  const body=new THREE.Mesh(new THREE.SphereGeometry(25,16,12),new THREE.MeshStandardMaterial({color:0xffc9b9,roughness:.65}));
  body.scale.set(1,.7,.4);drone.add(body);
  const armMaterial=new THREE.MeshStandardMaterial({color:0x153526,roughness:.7});
  for(const rotation of [-Math.PI/4,Math.PI/4]){const arm=new THREE.Mesh(new THREE.BoxGeometry(105,7,7),armMaterial);arm.rotation.z=rotation;drone.add(arm);}
  const rotorGeometry=new THREE.CylinderGeometry(20,20,3,20);rotorGeometry.rotateX(Math.PI/2);
  const rotorMaterial=new THREE.MeshStandardMaterial({color:0xfefee3,roughness:.8});
  for(const x of [-36,36])for(const y of [-36,36]){const rotor=new THREE.Mesh(rotorGeometry,rotorMaterial);rotor.position.set(x,y,4);drone.add(rotor);}
  let renderer;
  const threeLayer={
    id:'drone-analysis-3d',type:'custom',renderingMode:'3d',
    onAdd(_map,gl){renderer=new THREE.WebGLRenderer({canvas:map.getCanvas(),context:gl,antialias:true});renderer.autoClear=false;},
    render(_gl,args){
      const projection=new THREE.Matrix4().fromArray(args.defaultProjectionData.mainMatrix);
      const model=new THREE.Matrix4().makeTranslation(origin.x,origin.y,origin.z).scale(new THREE.Vector3(meter,-meter,meter));
      camera.projectionMatrix.copy(projection).multiply(model);
      renderer.resetState();renderer.render(scene,camera);
    },
    onRemove(){columns.traverse(object=>{if(object.isMesh){object.geometry.dispose();object.material.dispose();}});body.geometry.dispose();body.material.dispose();rotorGeometry.dispose();rotorMaterial.dispose();drone.children.filter(child=>child!==body&&child.geometry!==rotorGeometry).forEach(child=>child.geometry.dispose());armMaterial.dispose();renderer?.dispose();},
  };
  function visibleFindings(){return findingsForLayer(survey.findings,layer);}
  function flatCells(){
    if(!survey.illustrative||layer==='soil')return [];
    const findings=visibleFindings();if(!findings.length)return [];
    // ponytail: demo cells derived only from sample fixtures; not an agronomic raster.
    const cells=[];
    for(let y=175;y<=700;y+=30)for(let x=250;x<=730;x+=30){
      let value=.08;
      for(const finding of findings)value=Math.max(value,Math.exp(-((x-finding.x)**2+(y-finding.y)**2)/6500)*.95);
      const index=value<.22?0:value<.42?1:value<.66?2:value<.83?3:4;
      const ring=[[x,y],[x+27,y],[x+27,y+27],[x,y+27],[x,y]].map(([px,py])=>localToLngLat(px,py));
      cells.push(feature({type:'Polygon',coordinates:[ring]},{x:x+13.5,y:y+13.5,height:10+value*220,color:colors[index]}));
    }
    return cells;
  }
  function rebuildColumns(cells){
    columns.children.slice().forEach(mesh=>{columns.remove(mesh);mesh.geometry.dispose();mesh.material.dispose();});
    if(!cells.length)return;
    const geometry=new THREE.BoxGeometry(145,145,1);
    const material=new THREE.MeshStandardMaterial({roughness:.9});
    const mesh=new THREE.InstancedMesh(geometry,material,cells.length);
    const matrix=new THREE.Matrix4();
    cells.forEach((cell,index)=>{const props=cell.properties,point=local(props,props.height/2);matrix.makeScale(1,1,props.height).setPosition(point);mesh.setMatrixAt(index,matrix);mesh.setColorAt(index,new THREE.Color(props.color));});
    mesh.instanceMatrix.needsUpdate=true;if(mesh.instanceColor)mesh.instanceColor.needsUpdate=true;
    mesh.computeBoundingSphere();columns.add(mesh);
  }
  function updateData(){
    if(!ready)return;
    const findings=visibleFindings();
    map.getSource('findings').setData(collection(findings.map(finding=>feature({type:'Point',coordinates:coordinatesFor(finding)},{id:finding.id,number:String(survey.findings.indexOf(finding)+1).padStart(2,'0')}))));
    const cells=flatCells();map.getSource('analysis').setData(collection(cells));rebuildColumns(cells);
    map.setPaintProperty('finding-points','circle-color',['case',['==',['get','id'],selected??''],'#fefee3','#2c6e49']);
    map.setLayoutProperty('analysis-flat','visibility',view==='2d'?'visible':'none');
    columns.visible=view==='3d';updateTime();
  }
  function updateTime(){
    const point=positionAt(survey.route,time);if(!point)return;
    // The visual drone and 100 m height are explicitly simulated, not telemetry.
    drone.position.copy(local(point,100));drone.visible=view==='3d';
    if(ready)map.getSource('drone-position').setData(collection([feature({type:'Point',coordinates:coordinatesFor(point)})]));
    map.triggerRepaint();
  }
  function fit(){
    const compact=container.clientWidth<1000||container.clientHeight<560;
    map.fitBounds(areaBounds(),{padding:compact?{top:110,bottom:130,left:25,right:25}:{top:125,bottom:160,left:290,right:335},duration:reduced?0:650,pitch:view==='3d'?52:0,bearing:view==='3d'?-12:0});
  }
  map.on('load',()=>{
    map.setProjection({type:'mercator'});
    const corners=[demoArea.topLeft,demoArea.topRight,demoArea.bottomRight,demoArea.bottomLeft,demoArea.topLeft].map(point=>[point.longitude,point.latitude]);
    map.addSource('survey-extent',{type:'geojson',data:feature({type:'Polygon',coordinates:[corners]})});
    map.addLayer({id:'survey-extent-line',type:'line',source:'survey-extent',paint:{'line-color':'#2c6e49','line-width':2,'line-dasharray':[4,3]}});
    map.addSource('analysis',{type:'geojson',data:collection([])});
    map.addLayer({id:'analysis-flat',type:'fill',source:'analysis',paint:{'fill-color':['get','color'],'fill-opacity':.7}});
    map.addSource('survey-route',{type:'geojson',data:feature({type:'LineString',coordinates:survey.route.map(coordinatesFor)})});
    map.addLayer({id:'survey-route-line',type:'line',source:'survey-route',paint:{'line-color':'#2c6e49','line-width':2,'line-dasharray':[3,3]}});
    map.addLayer(threeLayer);
    map.addSource('findings',{type:'geojson',data:collection([])});
    map.addLayer({id:'finding-points',type:'circle',source:'findings',paint:{'circle-radius':11,'circle-color':'#2c6e49','circle-stroke-color':'#fefee3','circle-stroke-width':2}});
    map.addLayer({id:'finding-labels',type:'symbol',source:'findings',layout:{'text-field':['get','number'],'text-size':10,'text-allow-overlap':true},paint:{'text-color':'#153526','text-halo-color':'#fefee3','text-halo-width':1.3}});
    map.addSource('drone-position',{type:'geojson',data:collection([])});
    map.addLayer({id:'drone-point',type:'circle',source:'drone-position',paint:{'circle-radius':6,'circle-color':'#ffc9b9','circle-stroke-color':'#153526','circle-stroke-width':2}});
    ready=true;updateData();fit();onStatus(null);
    map.on('click','finding-points',event=>{const id=event.features?.[0]?.properties?.id;if(id)onSelect(id);});
    map.on('mouseenter','finding-points',()=>map.getCanvas().style.cursor='pointer');map.on('mouseleave','finding-points',()=>map.getCanvas().style.cursor='');
  });
  map.on('error',()=>onStatus('Map source could not load. Check internet access and reload.'));
  map.on('webglcontextlost',()=>onStatus('The graphics context was lost. Reload to restore the map.'));
  const observer=new ResizeObserver(()=>map.resize());observer.observe(container);
  return {
    setView(value){view=value;columns.visible=value==='3d';drone.visible=value==='3d';if(ready){map.setLayoutProperty('analysis-flat','visibility',value==='2d'?'visible':'none');}map.easeTo({pitch:value==='3d'?52:0,bearing:value==='3d'?-12:0,duration:reduced?0:500});map.triggerRepaint();},
    setLayer(value){layer=value;updateData();},setSelected(value){selected=value;if(ready)map.setPaintProperty('finding-points','circle-color',['case',['==',['get','id'],selected??''],'#fefee3','#2c6e49']);},
    setTime(value){time=value;updateTime();},setSurvey(value){survey=value;updateData();},
    zoomBy(factor){map.easeTo({zoom:map.getZoom()+Math.log2(factor),duration:reduced?0:200});},fit,
  };
}
