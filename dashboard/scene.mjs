import { utmToLngLat } from './geo.mjs';

export function validateManifest(m){
  if(!m||!Number.isSafeInteger(m.width)||!Number.isSafeInteger(m.height)||m.width<1||m.height<1||m.width*m.height>16000000||
    !Number.isFinite(m.pixel_size_m)||m.pixel_size_m<=0||!Number.isFinite(m.origin_x)||!Number.isFinite(m.origin_y)||!Array.isArray(m.layers)||
    (m.nodata_float32!==undefined&&!Number.isFinite(m.nodata_float32))){
    throw new Error('Invalid scene manifest dimensions or geographic metadata.');
  }
  utmToLngLat(m.origin_x,m.origin_y,m.crs);
  const layers=m.layers.filter(item=>item?.type==='float32'&&item.group!=='terrain');
  if(!layers.length)throw new Error('The scene manifest has no supported numeric analysis layers.');
  const names=new Set();
  for(const item of layers){
    if(typeof item.name!=='string'||!item.name||names.has(item.name)||!/^layers\/[A-Za-z0-9_.-]+\.f32$/.test(item.file))throw new Error('Invalid or duplicate numeric layer name or file path.');
    names.add(item.name);
  }
  return m;
}
async function fetchChecked(url,{fetcher=globalThis.fetch,signal}={}){
  const response=await fetcher(url,{signal});
  if(!response.ok)throw new Error(`Scene request failed (${response.status}). Check the manifest and layer addresses.`);
  return response;
}
export async function loadScene(address,options={}){
  const url=new URL(address,globalThis.location?.href);
  if(!['http:','https:'].includes(url.protocol)||url.username||url.password)throw new Error('Use an HTTP or HTTPS scene manifest address.');
  const manifest=validateManifest(await (await fetchChecked(url.href,options)).json());
  return {manifest,url:url.href,layers:manifest.layers.filter(item=>item.type==='float32'&&item.group!=='terrain')};
}
export async function loadSceneLayer(scene,name,options={}){
  const {manifest:m}=scene,L=scene.layers.find(item=>item.name===name);
  if(!L||L.type!=='float32'||L.group==='terrain')throw new Error('Choose a numeric analysis layer.');
  const buffer=await (await fetchChecked(new URL(L.file,scene.url).href,options)).arrayBuffer();
  if(buffer.byteLength!==m.width*m.height*4)throw new Error('Raster size does not match the scene manifest. Existing data retained.');
  const values=new DataView(buffer),findings=[];
  // ponytail: sample real pixels for the existing observation UI (max 1,000), not interpolation.
  // A raster renderer can replace this preview when full-resolution inspection is needed.
  let stride=Math.max(1,Math.ceil(Math.sqrt(m.width*m.height/1000)));
  while(Math.ceil(m.width/stride)*Math.ceil(m.height/stride)>1000)stride++;
  const metric=L.name.replaceAll('_',' '),unit=String(L.units??''),soil=L.group==='soil';
  const note=`Satellite export · sampled pixels every ${stride} row(s)/column(s) · values unvalidated · display radius is illustrative`;
  for(let row=0;row<m.height;row+=stride){
    for(let col=0;col<m.width;col+=stride){
      const pixel=row*m.width+col,value=values.getFloat32(pixel*4,true);
      if(!Number.isFinite(value)||value===(m.nodata_float32??-9999))continue;
      const [longitude,latitude]=utmToLngLat(m.origin_x+(col+.5)*m.pixel_size_m,m.origin_y-(row+.5)*m.pixel_size_m,m.crs);
      if(!Number.isFinite(longitude)||!Number.isFinite(latitude)||Math.abs(longitude)>180||Math.abs(latitude)>85)throw new Error('Scene pixels fall outside the supported geographic area.');
      findings.push({id:`scene-${name}-${pixel}`,title:`${metric}: ${Number(value.toPrecision(5))} ${unit}`,longitude,latitude,value,metric,unit,pixel,
        layer:L.group??'observations',tone:'teal',
        status:soil?'Model estimate · unvalidated':'Satellite export · unvalidated',
        description:`${m.name??'Satellite scene'}. Pixel row ${row+1}, column ${col+1}; ${m.pixel_size_m} m grid. ${String(m.notes??'').slice(0,4000)}`,
        action:soil?'Compare this estimate with field samples before taking action.':'Review the source scene and ground conditions before taking action.'});
    }
  }
  if(!findings.length)throw new Error('No valid pixels in this layer preview. Existing data retained.');
  const corners=[utmToLngLat(m.origin_x,m.origin_y,m.crs),utmToLngLat(m.origin_x+m.width*m.pixel_size_m,m.origin_y,m.crs),
    utmToLngLat(m.origin_x,m.origin_y-m.height*m.pixel_size_m,m.crs),utmToLngLat(m.origin_x+m.width*m.pixel_size_m,m.origin_y-m.height*m.pixel_size_m,m.crs)];
  const bounds=[[Math.min(...corners.map(p=>p[0])),Math.min(...corners.map(p=>p[1]))],[Math.max(...corners.map(p=>p[0])),Math.max(...corners.map(p=>p[1]))]];
  return {name:String(m.name??'Satellite scene'),source:'Satellite scene',findings,
    scene:{manifestUrl:scene.url,layer:name,depth_cm:L.depth_cm??null,crs:m.crs,pixel_size_m:m.pixel_size_m,width:m.width,height:m.height,stride,bounds,
      notes:String(m.notes??''),sources:String(m.sources??''),note}};
}
