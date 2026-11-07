// User-supplied WGS84 positions and their UTM zone 29N (EPSG:32629) references.
export const demoArea = {
  crs: 'EPSG:32629',
  center: { easting:553600, northing:5755760, latitude:51.949961, longitude:-8.220098 },
  topLeft: { easting:550720, northing:5758640, latitude:51.976123, longitude:-8.261574 },
  topRight: { easting:556480, northing:5758640, latitude:51.975567, longitude:-8.177723 },
  bottomLeft: { easting:550720, northing:5752880, latitude:51.924339, longitude:-8.262424 },
  bottomRight: { easting:556480, northing:5752880, latitude:51.923784, longitude:-8.178670 },
};

// Only the disposable x/y fixtures use bilinear placement. This is not a UTM conversion.
export function localToLngLat(x,y) {
  const u=x/1000,v=y/900;
  return ['longitude','latitude'].map(key => {
    const top=demoArea.topLeft[key]+u*(demoArea.topRight[key]-demoArea.topLeft[key]);
    const bottom=demoArea.bottomLeft[key]+u*(demoArea.bottomRight[key]-demoArea.bottomLeft[key]);
    return top+v*(bottom-top);
  });
}
function numeric(value){return (typeof value==='number'||typeof value==='string'&&value.trim()!=='')&&Number.isFinite(Number(value))?Number(value):NaN;}
function geographicPoint(item){
  const point=item.position??item,coordinates=item.coordinates??item.geometry?.coordinates;
  const longitude=point.longitude??point.lng??point.lon??coordinates?.[0];
  const latitude=point.latitude??point.lat??coordinates?.[1];
  const lng=numeric(longitude),lat=numeric(latitude);
  return Number.isFinite(lng)&&Number.isFinite(lat)&&Math.abs(lng)<=180&&Math.abs(lat)<=85?[lng,lat]:null;
}
export function coordinatesFor(item){return geographicPoint(item)??localToLngLat(item.x,item.y);}
export function areaBounds(){
  const corners=[demoArea.topLeft,demoArea.topRight,demoArea.bottomLeft,demoArea.bottomRight];
  return [[Math.min(...corners.map(p=>p.longitude)),Math.min(...corners.map(p=>p.latitude))],[Math.max(...corners.map(p=>p.longitude)),Math.max(...corners.map(p=>p.latitude))]];
}

// Same WGS84 inverse UTM series as lib/geo/utm.cy; returns MapLibre's [lon, lat].
export function utmToLngLat(easting,northing,crs){
  const match=/^EPSG:(326|327)(0[1-9]|[1-5][0-9]|60)$/.exec(crs);
  if(!match||!Number.isFinite(easting)||!Number.isFinite(northing))throw new Error('Expected WGS84 UTM coordinates.');
  const f=1/298.257223563,n=f/(2-f),a=6378137/(1+n)*(1+n*n/4+n**4/64);
  const xi=(northing-(match[1]==='327'?10000000:0))/(.9996*a),eta=(easting-500000)/(.9996*a);
  const beta=[n/2-2*n*n/3+37*n**3/96,n*n/48+n**3/15,17*n**3/480];
  let xp=xi,ep=eta;
  beta.forEach((b,i)=>{const k=2*(i+1);xp-=b*Math.sin(k*xi)*Math.cosh(k*eta);ep-=b*Math.cos(k*xi)*Math.sinh(k*eta);});
  const chi=Math.asin(Math.sin(xp)/Math.cosh(ep));
  const latitude=chi+(2*n-2*n*n/3-2*n**3)*Math.sin(2*chi)+(7*n*n/3-8*n**3/5)*Math.sin(4*chi)+56*n**3/15*Math.sin(6*chi);
  return [Number(match[2])*6-183+Math.atan2(Math.sinh(ep),Math.cos(xp))*180/Math.PI,latitude*180/Math.PI];
}
export function normaliseFeed(message){
  const records=Array.isArray(message)?message:message?.findings??message?.observations??[message];
  if(!Array.isArray(records))return [];
  return records.slice(0,1000).flatMap((item,index)=>{
    if(!item||typeof item!=='object')return [];
    const point=item.position??item,geo=geographicPoint(item),x=numeric(point.x),y=numeric(point.y);
    if(!geo&&(!Number.isFinite(x)||!Number.isFinite(y)||x<0||y<0||x>1000||y>900))return [];
    const layer=['coverage','moisture','anomalies','soil'].includes(item.layer)?item.layer:'anomalies';
    const value=numeric(item.value);
    return [{id:`feed-${index}`,title:String(item.title??item.label??'Received observation').slice(0,120),
      ...(geo?{longitude:geo[0],latitude:geo[1]}:{x,y}),
      ...(Number.isFinite(value)?{value,metric:String(item.metric??`Model value (${layer})`).slice(0,100),unit:String(item.unit??'').slice(0,40)}:{}),layer,time:Math.max(0,Math.min(150,numeric(item.time)||0)),tone:layer==='coverage'?'teal':'amber',
      status:'Received · unvalidated',description:String(item.description??'Received from the connected feed. Review the supporting evidence.').slice(0,2000),
      action:String(item.action??'Review this observation before taking action.').slice(0,500)}];
  });
}
