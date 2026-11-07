import { findingsForLayer } from './survey.mjs';
import { coordinatesFor, localToLngLat } from './geo.mjs';

const palette=[[44,110,73],[76,149,108],[254,254,227],[255,201,185],[214,140,69]];
export function valueColor(value){
  const position=Math.max(0,Math.min(1,value))*4;
  const lower=Math.min(3,Math.floor(position)),fraction=position-lower;
  return palette[lower].map((channel,index)=>Math.round(channel+(palette[lower+1][index]-channel)*fraction));
}

export function buildAnalysis(survey,layer,radius=80){
  radius=Math.max(20,Math.min(300,Number(radius)||80));
  const findings=findingsForLayer(survey.findings,layer);
  const sample=survey.illustrative===true;
  const empty={cells:[],sample,metric:sample?'Sample variation':'Model value',unit:sample?'index':'',min:null,max:null,note:'No numeric assessment available.'};
  if(!findings.length)return empty;
  if(sample){
    if(layer==='soil')return empty;
    const cells=[];
    // ponytail: a disposable hex lattice in the demo extent, not field interpolation.
    // Swap this fixture for model values/footprints once the AI output is agreed.
    const stepX=1.5*radius,stepY=Math.sqrt(3)*radius;
    let column=0;
    for(let east=1450;east<4250;east+=stepX,column++){
      let row=0;
      for(let south=1150+(column%2)*stepY/2;south<4450;south+=stepY,row++){
        const x=east/5760*1000,y=south/5760*900;
        let value=.06;
        for(const finding of findings)value=Math.max(value,Math.exp(-((x-finding.x)**2+(y-finding.y)**2)/6500)*.94);
        cells.push({id:`sample-${column}-${row}`,position:localToLngLat(x,y),value,normalised:value});
      }
    }
    return {...empty,cells,min:0,max:1,note:'Illustrative index · not a soil measurement'};
  }
  const valued=findings.filter(item=>typeof item.value==='number'&&Number.isFinite(item.value));
  const metrics=new Set(valued.map(item=>JSON.stringify([item.metric??`Model value (${item.layer??'unknown'})`,item.unit??''])));
  if(metrics.size>1)return {...empty,note:'Choose a layer with one metric and unit before comparing values.'};
  if(!valued.length)return empty;
  const min=Math.min(...valued.map(item=>item.value)),max=Math.max(...valued.map(item=>item.value));
  const cells=valued.map(item=>({id:item.id,sourceId:item.id,position:coordinatesFor(item),value:item.value,normalised:max===min?.5:(item.value-min)/(max-min)}));
  return {...empty,cells,min,max,metric:valued[0].metric??'Model value',unit:valued[0].unit??'',note:'Received values · unvalidated · display radius is illustrative'};
}
