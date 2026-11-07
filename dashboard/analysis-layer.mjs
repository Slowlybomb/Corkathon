import { buildAnalysis, valueColor } from './analysis.mjs';

// One deck.gl overlay shares MapLibre's WebGL context; Three.js keeps the drone.
export function createAnalysisOverlay(map,{beforeId,onChange=()=>{},onInspect=()=>{},onError=()=>{}}={}){
  const deck=window.deck;
  if(!deck?.MapLibreOverlay||!deck?.ColumnLayer){onError('Analysis library could not load. Reload with internet access; the map and camera module link remain available.');return null;}
  let survey={findings:[]},filter='all',view='3d',data=buildAnalysis(survey,filter);
  let settings={mode:'columns',opacity:.76,radius:80,heightScale:1},selectedIndex=-1;
  const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
  const overlay=new deck.MapLibreOverlay({interleaved:true,layers:[],onError:error=>{console.error(error);onError('Analysis rendering failed. Reload to restore the analysis layer.');}});
  map.addControl(overlay);
  function inspect(object,index){
    if(!object){onInspect(null);return;}
    selectedIndex=index;
    onInspect({...object,metric:data.metric,unit:data.unit,min:data.min,max:data.max});
  }
  function render(){
    const fieldScale=map.getZoom()>=9;
    const raised=settings.mode==='columns'&&view==='3d';
    overlay.setProps({layers:[new deck.ColumnLayer({
      id:'field-analysis',beforeId,data:data.cells,
      visible:fieldScale&&data.cells.length>0,
      diskResolution:6,radius:settings.radius,coverage:.94,
      radiusUnits:'meters',extruded:raised,elevationScale:240*settings.heightScale,
      getPosition:cell=>cell.position,getElevation:cell=>cell.normalised,
      getFillColor:cell=>valueColor(cell.normalised),
      opacity:settings.opacity,pickable:true,autoHighlight:true,
      highlightedObjectIndex:selectedIndex,highlightColor:[255,201,185,110],
      flatShading:true,material:{ambient:.65,diffuse:.5,shininess:6,specularColor:[0,0,0]},
      stroked:!raised,getLineColor:[254,254,227,90],lineWidthUnits:'pixels',getLineWidth:.5,
      transitions:reduced?{}:{getElevation:220},
      onHover:info=>{
        map.getCanvas().style.cursor=info.object?'pointer':'';
        window.dispatchEvent(new CustomEvent('analysis-hover',{detail:info.object?{x:info.x,y:info.y,value:info.object.value,metric:data.metric,unit:data.unit}:null}));
      },
      onClick:info=>{if(info.object){inspect(info.object,info.index);render();return true;}return false;},
    })]});
    onChange({...data,fieldScale,raised,settings});
  }
  function rebuild(){data=buildAnalysis(survey,filter);selectedIndex=-1;onInspect(null);window.dispatchEvent(new CustomEvent('analysis-hover',{detail:null}));render();}
  let fieldScale=map.getZoom()>=9;
  map.on('zoom',()=>{const next=map.getZoom()>=9;if(next!==fieldScale){fieldScale=next;render();}});
  map.on('remove',()=>{overlay.finalize();});
  return {
    setData(value,layer){survey=value;filter=layer;rebuild();},
    setView(value){view=value;render();},
    setOptions(options){
      settings={...settings,...options};
      settings.opacity=Math.max(.1,Math.min(1,Number(settings.opacity)||.1));
      settings.radius=Math.max(20,Math.min(160,Number(settings.radius)||80));
      settings.heightScale=Math.max(.25,Math.min(3,Number(settings.heightScale)||1));
      render();
    },
    inspectNext(direction=1){if(!data.cells.length)return;const index=selectedIndex<0?(direction<0?data.cells.length-1:0):(selectedIndex+direction+data.cells.length)%data.cells.length;inspect(data.cells[index],index);render();},
  };
}
