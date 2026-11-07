import test from 'node:test';
import assert from 'node:assert/strict';
import { demoArea, localToLngLat, coordinatesFor, normaliseFeed, areaBounds } from './geo.mjs';

test('sample grid corners map to the supplied geographic survey corners', () => {
  assert.deepEqual(localToLngLat(0,0),[-8.261574,51.976123]);
  assert.deepEqual(localToLngLat(1000,0),[-8.177723,51.975567]);
  assert.deepEqual(localToLngLat(0,900),[-8.262424,51.924339]);
  assert.deepEqual(localToLngLat(1000,900),[-8.178670,51.923784]);
  const midpoint=localToLngLat(500,450);
  assert.ok(Math.abs(midpoint[0]-demoArea.center.longitude)<.00001);
  assert.ok(Math.abs(midpoint[1]-demoArea.center.latitude)<.00001);
});

test('geographic coordinates take priority over disposable sample x/y', () => {
  assert.deepEqual(coordinatesFor({longitude:-8.22,latitude:51.95,x:0,y:0}),[-8.22,51.95]);
  assert.deepEqual(areaBounds(),[[-8.262424,51.923784],[-8.177723,51.976123]]);
});

test('feed accepts geographic records and legacy sample records, rejecting bad positions', () => {
  const record={label:'Patch',position:{x:400,y:300}};
  assert.equal(normaliseFeed([record])[0].title,'Patch');
  assert.equal(normaliseFeed({findings:[record]})[0].x,400);
  assert.deepEqual(coordinatesFor(normaliseFeed({observations:[{title:'Ground',lat:51.949961,lon:-8.220098}]})[0]),[-8.220098,51.949961]);
  assert.equal(normaliseFeed({label:'Point',coordinates:[-8.22,51.95]})[0].latitude,51.95);
  for(const input of [{status:'ready'},[{x:'oops',y:1}],[{x:10001,y:0}],[{lat:95,lon:-8.22}],[{lat:null,lon:-8.22}]])assert.deepEqual(normaliseFeed(input),[]);
});
