// Camera-module telemetry uses only fresh phone GPS and orientation readings.
const finite=value=>typeof value==='number'&&Number.isFinite(value);
const age=(value,limit)=>finite(value)&&value>=0&&value<=limit;
const optional=value=>finite(value)?value:null;
export function readLocation(value){
  if(!value||!finite(value.latitude)||Math.abs(value.latitude)>90||!finite(value.longitude)||Math.abs(value.longitude)>180||
    !finite(value.accuracyM)||value.accuracyM<0||!age(value.ageMs,15000)||value.mock!==false||!finite(value.capturedAt)||value.capturedAt<=0)return null;
  return {latitude:value.latitude,longitude:value.longitude,accuracyM:value.accuracyM,altitudeM:optional(value.altitudeM),
    altitudeAccuracyM:finite(value.altitudeAccuracyM)&&value.altitudeAccuracyM>=0?value.altitudeAccuracyM:null,
    speedMps:finite(value.speedMps)&&value.speedMps>=0?value.speedMps:null,capturedAt:value.capturedAt,ageMs:value.ageMs,mock:false};
}
function readOrientation(value){
  const q=value?.quaternion;
  if(!Array.isArray(q)||q.length!==4||!q.every(finite)||!age(value.ageMs,3000)||
    !['low','medium','high'].includes(value.accuracy)||value.reference!=='magnetic'||!finite(value.capturedAt)||value.capturedAt<=0)return null;
  const norm=Math.hypot(...q);if(norm<.5||norm>1.5)return null;
  return {quaternion:q.map(n=>n/norm),headingDeg:finite(value.headingDeg)&&value.headingDeg>=0&&value.headingDeg<360?value.headingDeg:null,
    pitchDeg:finite(value.pitchDeg)&&Math.abs(value.pitchDeg)<=180?value.pitchDeg:null,rollDeg:finite(value.rollDeg)&&Math.abs(value.rollDeg)<=180?value.rollDeg:null,
    reference:'magnetic',declinationDeg:finite(value.declinationDeg)&&Math.abs(value.declinationDeg)<=180?value.declinationDeg:null,
    accuracy:value.accuracy,capturedAt:value.capturedAt,ageMs:value.ageMs};
}
export function readTelemetry(packet,receivedAt=Date.now(),transitMs=0){
  if(packet?.v!==1||packet.type!=='telemetry'||!finite(packet.sentAt)||!finite(receivedAt)||!finite(transitMs)||transitMs<0)return null;
  const states=['off','permission_required','disabled','unavailable','searching','stale','live','unreliable'];
  const aged=value=>value&&({...value,ageMs:finite(value.ageMs)?value.ageMs+transitMs:null});
  return {receivedAt,location:readLocation(aged(packet.location)),orientation:readOrientation(aged(packet.orientation)),
    gpsState:states.includes(packet.gpsState)?packet.gpsState:'unavailable',orientationState:states.includes(packet.orientationState)?packet.orientationState:'unavailable'};
}
export function telemetryAt(sample,now=Date.now()){
  const elapsed=Math.max(0,now-(sample?.receivedAt??now));
  return {location:sample?.location&&age(sample.location.ageMs+elapsed,15000)?sample.location:null,
    orientation:sample?.orientation&&age(sample.orientation.ageMs+elapsed,3000)?sample.orientation:null};
}
function multiply([x,y,z,w],[a,b,c,d]){return [w*a+x*d+y*c-z*b,w*b-x*c+y*d+z*a,w*c+x*b-y*a+z*d,w*d-x*a-y*b-z*c];}
export function droneQuaternion(orientation){
  if(!orientation||![orientation.headingDeg,orientation.pitchDeg,orientation.rollDeg].every(finite))return null;
  const heading=-orientation.headingDeg*Math.PI/360,pitch=-orientation.pitchDeg*Math.PI/360,roll=orientation.rollDeg*Math.PI/360;
  // Android azimuth/pitch/roll: Rz(-heading) Rx(-pitch) Ry(roll).
  // headingDeg already includes declination when available. Apply the mount alignment last.
  return multiply(multiply(multiply([0,0,Math.sin(heading),Math.cos(heading)],[Math.sin(pitch),0,0,Math.cos(pitch)]),[0,Math.sin(roll),0,Math.cos(roll)]),[0,0,1,0]);
}
