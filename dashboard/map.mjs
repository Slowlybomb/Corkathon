import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { positionAt, findingsForLayer, routeYawAt } from './survey.mjs';
import { demoArea, coordinatesFor, areaBounds } from './geo.mjs';
import { createAnalysisOverlay } from './analysis-layer.mjs';

const collection=features=>({type:'FeatureCollection',features});
const feature=(geometry,properties={})=>({type:'Feature',geometry,properties});

export function createFieldMap(container,initialSurvey,onSelect,onStatus=()=>{},onBasemapChange=()=>{},onAnalysisChange=()=>{},onCellInspect=()=>{}){
  const maplibregl=window.maplibregl;
  if(!maplibregl)throw new Error('MapLibre did not load');
  let survey=initialSurvey,layer='all',selected=survey.findings[0]?.id,view='3d',time=0,ready=false,basemap='satellite';
  const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
  const map=new maplibregl.Map({
    container,style:'https://tiles.openfreemap.org/styles/liberty',
    center:[demoArea.center.longitude,demoArea.center.latitude],zoom:12.5,pitch:52,bearing:-12,
    maxPitch:70,attributionControl:false,canvasContextAttributes:{antialias:true},
  });
  map.addControl(new maplibregl.AttributionControl({compact:true}),'bottom-right');
  map.getCanvas().setAttribute('aria-label','Cork survey map. Drag to pan, right-drag to rotate. Findings are available in the observations list.');
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
  let renderer,mixer,modelGeneration=0,modelRequested=false,analysis,analysisError=null;
  let analysisOptions={};
  function disposeObject(root){
    const resources=new Set(),images=new Set();
    root.traverse(object=>{
      if(object.geometry)resources.add(object.geometry);
      if(object.skeleton)resources.add(object.skeleton);
      for(const material of object.material?(Array.isArray(object.material)?object.material:[object.material]):[]){
        resources.add(material);
        for(const value of Object.values(material))if(value?.isTexture){resources.add(value);if(value.source?.data?.close)images.add(value.source.data);}
      }
    });
    resources.forEach(resource=>resource.dispose());images.forEach(image=>image.close());
  }
  function ensureDroneModel(){
    if(!renderer||!survey.route.length||modelRequested)return;
    modelRequested=true;
    const generation=++modelGeneration;
    new GLTFLoader().load(new URL('./assets/drone/drone.glb',import.meta.url).href,gltf=>{
      if(generation!==modelGeneration){disposeObject(gltf.scene);return;}
      const model=new THREE.Group();model.rotation.x=Math.PI/2;model.add(gltf.scene);
      const hover=gltf.animations.find(clip=>clip.name==='hover');
      if(hover){mixer=new THREE.AnimationMixer(gltf.scene);mixer.clipAction(hover).play();mixer.setTime(0);}
        // Update skin bindings before measuring the animated pose; cached bind-pose boxes are offset.
        model.updateMatrixWorld(true);
        const bounds=new THREE.Box3().setFromObject(model,true),size=bounds.getSize(new THREE.Vector3());
      const span=Math.max(size.x,size.y);
      if(!Number.isFinite(span)||span<=0){mixer?.stopAllAction();mixer=null;disposeObject(gltf.scene);onStatus('Drone model has invalid dimensions. The simulated position marker remains available.');return;}
      // Exaggerated display size in map metres; this is not the drone's physical size.
      const scale=140/span;model.scale.setScalar(scale);
      model.position.copy(bounds.getCenter(new THREE.Vector3())).multiplyScalar(-scale);
      drone.add(model);mixer?.setTime(reduced?0:time);map.triggerRepaint();
    },undefined,error=>{
      if(generation!==modelGeneration)return;
      console.error('Drone model could not load',error);
      onStatus('Drone model could not load. The simulated position marker remains available.');
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
    onRemove(){modelGeneration++;modelRequested=false;mixer?.stopAllAction();if(mixer)mixer.uncacheRoot(mixer.getRoot());mixer=null;disposeObject(drone);drone.clear();renderer?.dispose();},
  };
  function visibleFindings(){return findingsForLayer(survey.findings,layer);}
  function updateData(){
    if(!ready)return;
    const findings=visibleFindings();
    map.getSource('findings').setData(collection(findings.map(finding=>feature({type:'Point',coordinates:coordinatesFor(finding)},{id:finding.id,number:String(survey.findings.indexOf(finding)+1).padStart(2,'0')}))));
    analysis?.setData(survey,layer);
    map.setPaintProperty('finding-points','circle-color',['case',['==',['get','id'],selected??''],'#fefee3','#2c6e49']);
    map.getSource('survey-route').setData(collection(survey.route.length>1?[feature({type:'LineString',coordinates:survey.route.map(coordinatesFor)})]:[]));
    updateTime();
  }
  function updateTime(){
    const point=positionAt(survey.route,time);
    drone.visible=Boolean(point)&&view==='3d';
    if(ready)map.getSource('drone-position').setData(collection(point?[feature({type:'Point',coordinates:coordinatesFor(point)})]:[]));
    if(!point){map.triggerRepaint();return;}
    ensureDroneModel();
    // The visual drone and 100 m height are explicitly simulated, not telemetry.
    drone.position.copy(local(point,100));drone.visible=view==='3d';
    const yaw=routeYawAt(survey.route,time,local);
    if(yaw!==null)drone.rotation.z=yaw;
    mixer?.setTime(reduced?0:time);
    map.triggerRepaint();
  }
  function fit(){
    const compact=container.clientWidth<1000||container.clientHeight<560;
    map.fitBounds(survey.scene?.bounds??areaBounds(),{padding:compact?{top:110,bottom:130,left:25,right:25}:{top:125,bottom:160,left:290,right:335},duration:reduced?0:650,pitch:view==='3d'?52:0,bearing:view==='3d'?-12:0});
  }
  function setBasemap(value){
    if(!['map','satellite'].includes(value))return;
    basemap=value;
    if(ready){
      // Keep the style and shared WebGL context alive; only the raster visibility changes.
      map.setLayoutProperty('satellite-imagery','visibility',value==='satellite'?'visible':'none');
      const lineColor=value==='satellite'?'#fefee3':'#2c6e49';
      map.setPaintProperty('survey-extent-line','line-color',lineColor);
      map.setPaintProperty('survey-route-line','line-color',lineColor);
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
    const corners=[demoArea.topLeft,demoArea.topRight,demoArea.bottomRight,demoArea.bottomLeft,demoArea.topLeft].map(point=>[point.longitude,point.latitude]);
    map.addSource('survey-extent',{type:'geojson',data:feature({type:'Polygon',coordinates:[corners]})});
    map.addLayer({id:'survey-extent-line',type:'line',source:'survey-extent',paint:{'line-color':'#2c6e49','line-width':2,'line-dasharray':[4,3]}});
    map.addSource('survey-route',{type:'geojson',data:collection([])});
    map.addLayer({id:'survey-route-line',type:'line',source:'survey-route',paint:{'line-color':'#2c6e49','line-width':2,'line-dasharray':[3,3]}});
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
    setView(value){view=value;analysis?.setView(value);drone.visible=value==='3d'&&survey.route.length>0;if(ready){map.setProjection({type:value==='3d'?'globe':'mercator'});}map.easeTo({pitch:value==='3d'?52:0,bearing:value==='3d'?-12:0,duration:reduced?0:500});map.triggerRepaint();},
    setLayer(value){layer=value;updateData();},setSelected(value){selected=value;if(ready)map.setPaintProperty('finding-points','circle-color',['case',['==',['get','id'],selected??''],'#fefee3','#2c6e49']);},
    setTime(value){time=value;updateTime();},setSurvey(value){survey=value;updateData();},
    zoomBy(factor){map.easeTo({zoom:map.getZoom()+Math.log2(factor),duration:reduced?0:200});},fit,
  };
}
