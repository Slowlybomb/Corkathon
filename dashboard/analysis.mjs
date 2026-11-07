import { findingsForLayer } from './survey.mjs';
import { coordinatesFor } from './geo.mjs';

const palette=[[44,110,73],[76,149,108],[254,254,227],[255,201,185],[214,140,69]];
export function valueColor(value){
  const position=Math.max(0,Math.min(1,value))*4;
  const lower=Math.min(3,Math.floor(position)),fraction=position-lower;
  return palette[lower].map((channel,index)=>Math.round(channel+(palette[lower+1][index]-channel)*fraction));
}

export function buildAnalysis(survey,layer){
  const findings=findingsForLayer(survey.findings,layer);
  const empty={cells:[],metric:'Model value',unit:'',min:null,max:null,note:'No numeric assessment available.'};
  if(!findings.length)return empty;
  const valued=findings.filter(item=>typeof item.value==='number'&&Number.isFinite(item.value)&&coordinatesFor(item));
  const metrics=new Set(valued.map(item=>JSON.stringify([item.metric??`Model value (${item.layer??'unknown'})`,item.unit??''])));
  if(metrics.size>1)return {...empty,note:'Choose a layer with one metric and unit before comparing values.'};
  if(!valued.length)return empty;
  const min=Math.min(...valued.map(item=>item.value)),max=Math.max(...valued.map(item=>item.value));
  const cells=valued.map(item=>({id:item.id,sourceId:item.id,position:coordinatesFor(item),value:item.value,normalised:max===min?.5:(item.value-min)/(max-min)}));
  return {...empty,cells,min,max,metric:valued[0].metric??'Model value',unit:valued[0].unit??'',note:survey.scene?.note??'Received values · unvalidated · display radius is illustrative'};
}
