import * as THREE from 'three';
import { loadDroneModel } from './drone-model.mjs';
import { findingsForLayer } from './survey.mjs';
import { demoArea, coordinatesFor, surveyBounds } from './geo.mjs';
import { createAnalysisOverlay } from './analysis-layer.mjs';
import { telemetryAt, droneQuaternion } from './telemetry.mjs';
import { createFlight, stepFlight } from './flight.mjs';

const collection=features=>({type:'FeatureCollection',features});
const feature=(geometry,properties={})=>({type:'Feature',geometry,properties});

export function createFieldMap(container,initialSurvey,onSelect,onStatus=()=>{},onBasemapChange=()=>{},onAnalysisChange=()=>{},onCellInspect=()=>{}){
  const maplibregl=window.maplibregl;
  if(!maplibregl)throw new Error('MapLibre did not load');
  let survey=initialSurvey,layer='all',selected=survey.findings[0]?.id,view='3d',ready=false,basemap='satellite';
  let liveTelemetry=null,located=false,follow=false,flight=null,followFrame=0,lastFrame=0;
  const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
  const map=new maplibregl.Map({
    container,style:'https://tiles.openfreemap.org/styles/liberty',
    center:[demoArea.center.longitude,demoArea.center.latitude],zoom:12.5,pitch:52,bearing:-12,
    maxPitch:70,attributionControl:false,canvasContextAttributes:{antialias:true},
  });
  map.addControl(new maplibregl.AttributionControl({compact:true}),'bottom-right');
  map.getCanvas().setAttribute('aria-label','Geographic field map. Drag to pan, right-drag to rotate. Findings are available in the observations list.');
  const origin=maplibregl.MercatorCoordinate.fromLngLat([demoArea.center.longitude,demoArea.center.latitude],0);
  const meter=origin.meterInMercatorCoordinateUnits();
  function local(point,altitude=0){
    const mercator=maplibregl.MercatorCoordinate.fromLngLat(coordinatesFor(point),altitude);
    return new THREE.Vector3((mercator.x-origin.x)/meter,-(mercator.y-origin.y)/meter,(mercator.z-origin.z)/meter);
  }
  const scene=new THREE.Scene(),camera=new THREE.Camera();
  scene.add(new THREE.AmbientLight(0xffffff,2));
  const light=new THREE.DirectionalLight(0xfff7dc,2.5);light.position.set(-1500,-2500,4500);scene.add(light);
  const drone=new THREE.Group();drone.name='survey-drone';scene.add(drone);
  let renderer,mixer,droneAsset,modelGeneration=0,modelRequested=false,analysis,analysisError=null;
  let analysisOptions={};
  function ensureDroneModel(){
    if(!renderer||(!follow&&!telemetryAt(liveTelemetry).location)||modelRequested)return;
    modelRequested=true;
    const generation=++modelGeneration;
    loadDroneModel().then(asset=>{
      if(generation!==modelGeneration){asset.dispose();return;}
      droneAsset=asset;mixer=asset.mixer;drone.add(asset.model);
      mixer.setTime(0);map.triggerRepaint();
    }).catch(error=>{
      if(generation!==modelGeneration)return;
      console.error('Drone model could not load',error);
      onStatus('Drone model could not load. The position marker remains available when position data exists.');
    });
  }
  const threeLayer={
    id:'drone-3d',type:'custom',renderingMode:'3d',
    onAdd(_map,gl){
      renderer=new THREE.WebGLRenderer({canvas:map.getCanvas(),context:gl,antialias:true});renderer.autoClear=false;
      ensureDroneModel();
    },
    render(_gl,args){
      // Local meshes use Mercator. Native map layers wrap around the globe at wider scales.
      if(view!=='3d'||args.defaultProjectionData.projectionTransition>0)return;
      const projection=new THREE.Matrix4().fromArray(args.defaultProjectionData.mainMatrix);
      const model=new THREE.Matrix4().makeTranslation(origin.x,origin.y,origin.z).scale(new THREE.Vector3(meter,-meter,meter));
      camera.projectionMatrix.copy(projection).multiply(model);
      renderer.resetState();renderer.render(scene,camera);
    },
    onRemove(){modelGeneration++;modelRequested=false;droneAsset?.dispose();droneAsset=null;mixer=null;drone.clear();renderer?.dispose();},
  };
  function visibleFindings(){return findingsForLayer(survey.findings,layer);}
  function updateData(){
    if(!ready)return;
    const findings=visibleFindings();
    map.getSource('findings').setData(collection(findings.map(finding=>feature({type:'Point',coordinates:coordinatesFor(finding)},{id:finding.id,number:String(survey.findings.indexOf(finding)+1).padStart(2,'0')}))));
    analysis?.setData(survey,layer);
    map.setPaintProperty('finding-points','circle-color',['case',['==',['get','id'],selected??''],'#fefee3','#2c6e49']);
    updateTelemetryPosition();
  }
  function updateTelemetryPosition(){
    const current=telemetryAt(liveTelemetry),point=current.location;
    const plottable=point&&Math.abs(point.latitude)<=85;
    if(ready)map.getSource('drone-position').setData(collection(plottable?[feature({type:'Point',coordinates:[point.longitude,point.latitude]},{source:'phone-gps',accuracyM:point.accuracyM})]:[]));
    if(follow){map.triggerRepaint();return;}
    const attitude=droneQuaternion(current.orientation);
    // GPS without attitude remains a point; no fabricated yaw, tilt, altitude, or rotor motion.
    drone.visible=Boolean(plottable&&attitude)&&view==='3d';
    if(plottable){
      ensureDroneModel();drone.position.copy(local(point,point.altitudeM??0));
      if(attitude)drone.quaternion.fromArray(attitude);
      if(ready&&!located){located=true;locateDrone();}
    }
    mixer?.setTime(0);map.triggerRepaint();
  }
  function stepFollow(now){
    if(!follow||!flight)return;
    const dt=Math.min(.1,Math.max(0,(now-lastFrame)/1000));lastFrame=now;
    const camera=stepFlight(flight,telemetryAt(liveTelemetry),dt);
    drone.position.copy(local(flight,120));
    const pose=droneQuaternion({headingDeg:flight.heading??0,pitchDeg:flight.pitch,rollDeg:flight.roll});if(pose)drone.quaternion.fromArray(pose);
    drone.visible=view==='3d';ensureDroneModel();
    map.jumpTo(camera);
    followFrame=requestAnimationFrame(stepFollow);
  }
  function setFollow(on){
    if(on===follow)return;
    follow=on;cancelAnimationFrame(followFrame);
    if(on){flight=createFlight(demoArea);lastFrame=performance.now();followFrame=requestAnimationFrame(stepFollow);}
    else{flight=null;if(ready)map.easeTo({roll:0,duration:reduced?0:300});updateTelemetryPosition();}
  }
  function fit(){
    const bounds=surveyBounds(survey);
    if(!bounds){locateDrone();return;}
    const compact=container.clientWidth<1000||container.clientHeight<560;
    map.fitBounds(bounds,{maxZoom:17,padding:compact?{top:110,bottom:130,left:25,right:25}:{top:125,bottom:160,left:290,right:335},duration:reduced?0:650,pitch:view==='3d'?52:0,bearing:view==='3d'?-12:0});
  }
  function locateDrone(){
    const point=telemetryAt(liveTelemetry).location;
    if(!point||Math.abs(point.latitude)>85)return;
    map.easeTo({center:[point.longitude,point.latitude],zoom:16,duration:reduced?0:650});
  }
  const telemetryTimer=setInterval(()=>{if(liveTelemetry)updateTelemetryPosition();},1000);
  map.on('remove',()=>clearInterval(telemetryTimer));
  function setBasemap(value){
    if(!['map','satellite'].includes(value))return;
    basemap=value;
    if(ready){
      // Keep the style and shared WebGL context alive; only the raster visibility changes.
      map.setLayoutProperty('satellite-imagery','visibility',value==='satellite'?'visible':'none');
    }
    onBasemapChange(value);onStatus(analysisError);
  }
  map.on('load',()=>{
    map.setProjection({type:view==='3d'?'globe':'mercator'});
    // World-scale labels clutter the globe rim in this MapLibre version. Keep local labels.
    for(const item of map.getStyle().layers.filter(item=>item.type==='symbol')){
      const maximum=item.maxzoom??24;
      map.setLayerZoomRange(item.id,Math.min(maximum,Math.max(4,item.minzoom??0)),maximum);
    }
    map.addSource('satellite-imagery',{
      type:'raster',tileSize:256,maxzoom:19,
      tiles:['https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'],
      attribution:'Imagery &copy; <a href="https://www.arcgis.com/home/item.html?id=10df2279f9684e4a9f6a7f08febac2a9" target="_blank" rel="noopener">Esri</a>, Vantor, Earthstar Geographics, and the GIS User Community',
    });
    // Added above the base style and below every survey layer, including Three.js.
    map.addLayer({id:'satellite-imagery',type:'raster',source:'satellite-imagery',layout:{visibility:'none'},paint:{'raster-fade-duration':150}});
    map.addLayer(threeLayer);
    analysis=createAnalysisOverlay(map,{beforeId:'drone-3d',onChange:onAnalysisChange,onInspect:onCellInspect,onError:message=>{analysisError=message;onStatus(message);}});
    analysis?.setOptions(analysisOptions);
    analysis?.setView(view);
    map.addSource('findings',{type:'geojson',data:collection([])});
    map.addLayer({id:'finding-points',type:'circle',source:'findings',paint:{'circle-radius':11,'circle-color':'#2c6e49','circle-stroke-color':'#fefee3','circle-stroke-width':2}});
    map.addLayer({id:'finding-labels',type:'symbol',source:'findings',layout:{'text-field':['get','number'],'text-size':10,'text-allow-overlap':true},paint:{'text-color':'#153526','text-halo-color':'#fefee3','text-halo-width':1.3}});
    map.addSource('drone-position',{type:'geojson',data:collection([])});
    map.addLayer({id:'drone-point',type:'circle',source:'drone-position',paint:{'circle-radius':6,'circle-color':'#ffc9b9','circle-stroke-color':'#153526','circle-stroke-width':2}});
    ready=true;updateData();fit();setBasemap(basemap);
    map.on('click','finding-points',event=>{const id=event.features?.[0]?.properties?.id;if(id)onSelect(id);});
    map.on('mouseenter','finding-points',()=>map.getCanvas().style.cursor='pointer');map.on('mouseleave','finding-points',()=>map.getCanvas().style.cursor='');
  });
  map.on('error',event=>{
    if(event.sourceId==='satellite-imagery'){
      if(basemap==='satellite'){
        setBasemap('map');
        onStatus('Satellite imagery could not load. Showing the map; check internet access before trying again.');
      }
      return;
    }
    onStatus('Map source could not load. Check internet access and reload.');
  });
  map.on('webglcontextlost',()=>onStatus('The graphics context was lost. Reload to restore the map.'));
  const observer=new ResizeObserver(()=>map.resize());observer.observe(container);
  return {
    setBasemap,
    setAnalysisOptions(options){analysisOptions={...analysisOptions,...options};analysis?.setOptions(analysisOptions);},
    inspectAnalysisCell(direction){analysis?.inspectNext(direction);},
    setView(value){view=value;analysis?.setView(value);if(ready){map.setProjection({type:value==='3d'?'globe':'mercator'});}map.easeTo({pitch:value==='3d'?52:0,bearing:value==='3d'?-12:0,duration:reduced?0:500});updateTelemetryPosition();},
    setLayer(value){layer=value;updateData();},setSelected(value){selected=value;if(ready)map.setPaintProperty('finding-points','circle-color',['case',['==',['get','id'],selected??''],'#fefee3','#2c6e49']);},
    setSurvey(value){survey=value;updateData();},
    setTelemetry(value){liveTelemetry=value;if(!value)located=false;updateTelemetryPosition();},
    locateDrone,setFollow,followMode(){return flight?.mode??null;},
    zoomBy(factor){map.easeTo({zoom:map.getZoom()+Math.log2(factor),duration:reduced?0:200});},fit,
  };
}
