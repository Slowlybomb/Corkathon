import test from 'node:test';
import assert from 'node:assert/strict';
import { createFlight, stepFlight } from './flight.mjs';
import { demoArea } from './geo.mjs';

const level={headingDeg:0,pitchDeg:0,rollDeg:0};
const run=(flight,sample,seconds)=>{let camera;for(let t=0;t<seconds;t+=.05)camera=stepFlight(flight,sample,.05);return camera;};
const metresNorth=(a,b)=>(b.latitude-a.latitude)*111320;
const metresEast=(a,b)=>(b.longitude-a.longitude)*111320*Math.cos(a.latitude*Math.PI/180);

test('walking outside the survey area replays the movement from the survey centre', () => {
  const flight=createFlight(demoArea),start={latitude:51.8985,longitude:-8.4756};
  run(flight,{location:start,orientation:level},2);
  assert.equal(flight.mode,'gps-relative');
  assert.ok(Math.abs(metresNorth(demoArea.center,flight))<1);
  run(flight,{location:{latitude:start.latitude+100/111320,longitude:start.longitude},orientation:level},10);
  assert.ok(Math.abs(metresNorth(demoArea.center,flight)-100)<1,'moved 100 m north');
  assert.ok(Math.abs(metresEast(demoArea.center,flight))<1,'no sideways drift');
});

test('a GPS fix inside the survey area places the drone at the real position', () => {
  const flight=createFlight(demoArea),fix={latitude:demoArea.center.latitude+.005,longitude:demoArea.center.longitude-.01};
  run(flight,{location:fix,orientation:level},10);
  assert.equal(flight.mode,'gps');
  assert.ok(Math.abs(metresNorth(fix,flight))<1&&Math.abs(metresEast(fix,flight))<1);
});

test('without GPS a level phone hovers and a forward tilt flies along the heading', () => {
  const flight=createFlight(demoArea);
  run(flight,{location:null,orientation:{headingDeg:90,pitchDeg:0,rollDeg:0}},3);
  assert.equal(flight.mode,'tilt');
  assert.ok(Math.abs(metresEast(demoArea.center,flight))<1,'level phone stays put');
  run(flight,{location:null,orientation:{headingDeg:90,pitchDeg:20,rollDeg:0}},5);
  assert.ok(metresEast(demoArea.center,flight)>50,'nose-down tilt flies east when heading east');
  assert.ok(Math.abs(metresNorth(demoArea.center,flight))<5);
});

test('heading smoothing takes the short way round and the camera follows it', () => {
  const flight=createFlight(demoArea);
  run(flight,{location:null,orientation:{headingDeg:350,pitchDeg:0,rollDeg:0}},3);
  const camera=run(flight,{location:null,orientation:{headingDeg:10,pitchDeg:0,rollDeg:0}},.3);
  assert.ok(flight.heading>350||flight.heading<10,`heading ${flight.heading} stayed near north`);
  assert.equal(camera.bearing,flight.heading);
});

test('the drone never leaves the survey area', () => {
  const flight=createFlight(demoArea);
  run(flight,{location:null,orientation:{headingDeg:0,pitchDeg:40,rollDeg:0}},400);
  assert.ok(flight.latitude<=flight.bounds.north&&flight.latitude>=flight.bounds.south);
});
