import test from 'node:test';
import assert from 'node:assert/strict';
import { createPacketReader, createPhoneLink, SERVICE, RX, TX } from './phone.mjs';

test('Bluetooth packets survive arbitrary byte boundaries, including UTF-8 and multiple messages', () => {
  const packets=[], errors=[];
  const read=createPacketReader(packet=>packets.push(packet), error=>errors.push(error));
  const data=new TextEncoder().encode('{"type":"log","message":"Cork 🌱"}\n{"type":"status","camera":"off"}\n');
  for(const byte of data)read(Uint8Array.of(byte));
  assert.deepEqual(packets,[{type:'log',message:'Cork 🌱'},{type:'status',camera:'off'}]);
  assert.deepEqual(errors,[]);
});

test('malformed and oversized packets are discarded without losing the next valid packet', () => {
  const packets=[], errors=[];
  const read=createPacketReader(packet=>packets.push(packet), error=>errors.push(error),64);
  read(new TextEncoder().encode('oops\n[]\n'+ 'x'.repeat(90)+'\n{"type":"ready"}\n'));
  assert.deepEqual(packets,[{type:'ready'}]);
  assert.equal(errors.length,3);
});

test('a real phone-link session authenticates before commands, writes bounded chunks, and resets on disconnect', async () => {
  const notifications=new EventTarget(), device=new EventTarget(), writes=[], states=[], received=[];
  let disconnected=0;
  device.name='Test phone';
  device.gatt={connected:true,disconnect(){this.connected=false;disconnected++;device.dispatchEvent(new Event('gattserverdisconnected'));},async connect(){return {async getPrimaryService(uuid){assert.equal(uuid,SERVICE);return {async getCharacteristic(uuid){
    if(uuid===TX)return Object.assign(notifications,{async startNotifications(){return this;}});
    assert.equal(uuid,RX);return {async writeValueWithResponse(chunk){writes.push([...chunk]);}};
  }};}};}};
  const link=createPhoneLink({bluetooth:{async requestDevice(){return device;}},onState:state=>states.push(state),onPacket:packet=>received.push(packet)});
  await assert.rejects(link.send('capture'),/connect/i);
  await link.connect('123456');
  assert.equal(states.at(-1),'authenticating');
  const emit=packet=>{const event=new Event('characteristicvaluechanged');event.targetValue=new DataView(new TextEncoder().encode(JSON.stringify(packet)+'\n').buffer);Object.defineProperty(event,'target',{value:{value:event.targetValue}});notifications.dispatchEvent(event);};
  emit({v:2,type:'ready'});
  await assert.rejects(link.send('capture'),/connect/i);
  emit({v:1,type:'ready',model:'not_connected'});
  await link.send('ping');
  assert.equal(states.at(-1),'connected');
  assert.equal(received.at(-1).type,'ready');
  assert.ok(writes.every(chunk=>chunk.length<=20));
  const packets=new TextDecoder().decode(Uint8Array.from(writes.flat())).trim().split('\n').map(JSON.parse);
  assert.equal(packets[0].command,'hello');assert.equal(packets[0].pin,'123456');assert.equal(packets[1].command,'ping');
  link.disconnect();
  assert.equal(disconnected,1);assert.equal(states.at(-1),'disconnected');
  await assert.rejects(link.send('capture'),/connect/i);
});
