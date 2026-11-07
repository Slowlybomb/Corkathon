import { readLocation } from './telemetry.mjs';

export const SERVICE = 'aa7a0001-7f6b-4c80-9f55-477f39b00001';
export const RX = 'aa7a0002-7f6b-4c80-9f55-477f39b00001';
export const TX = 'aa7a0003-7f6b-4c80-9f55-477f39b00001';

export function cameraImageEvidence(packet) {
  if (
    packet?.v !== 1 ||
    packet.type !== 'image' ||
    typeof packet.id !== 'string' ||
    !packet.id ||
    packet.mime !== 'image/jpeg' ||
    typeof packet.base64 !== 'string' ||
    packet.base64.length > 44000 ||
    !/^\/9j\/[A-Za-z0-9+/]*={0,2}$/.test(packet.base64)
  )
    return null;
  const capturedAt =
    typeof packet.capturedAt === 'number' &&
    packet.capturedAt > 0 &&
    Number.isFinite(new Date(packet.capturedAt).getTime())
      ? packet.capturedAt
      : null;
  return {
    id: packet.id,
    src: `data:image/jpeg;base64,${packet.base64}`,
    mime: packet.mime,
    capturedAt,
    location: readLocation(packet.location),
  };
}

// Byte framing keeps split UTF-8 characters intact. Discard overflow through the next newline.
export function createPacketReader(onPacket, onError = () => {}, limit = 65536, now = () => performance.now()) {
  let bytes = [],
    discard = false,
    started = null;
  return value => {
    const data = new Uint8Array(value.buffer, value.byteOffset, value.byteLength);
    for (const byte of data) {
      if (byte === 10) {
        if (!discard && bytes.length) {
          let packet;
          try {
            packet = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(Uint8Array.from(bytes)));
            if (!packet || typeof packet !== 'object' || Array.isArray(packet)) throw new Error();
          } catch {
            packet = null;
            onError('Invalid camera module packet.');
          }
          if (packet) onPacket(packet, Math.max(0, now() - started));
        }
        bytes = [];
        discard = false;
        started = null;
      } else if (!discard) {
        if (!bytes.length) started = now();
        bytes.push(byte);
        if (bytes.length > limit) {
          bytes = [];
          discard = true;
          onError('Camera module packet exceeded the size limit.');
        }
      }
    }
  };
}

export function createPhoneLink({
  bluetooth = globalThis.navigator?.bluetooth,
  onState = () => {},
  onPacket = () => {},
  onError = () => {},
  onProgress = () => {},
} = {}) {
  let device,
    rx,
    tx,
    reader,
    ready = false,
    epoch = 0,
    writes = Promise.resolve(),
    authTimer;
  const notify = event => {
    onProgress(event.target.value.byteLength);
    reader?.(event.target.value);
  };
  function reset() {
    epoch++;
    ready = false;
    rx = null;
    clearTimeout(authTimer);
    tx?.removeEventListener('characteristicvaluechanged', notify);
    tx = null;
    reader = null;
    writes = Promise.resolve();
    device?.removeEventListener('gattserverdisconnected', reset);
    device = null;
    onState('disconnected');
  }
  function disconnect() {
    const old = device;
    reset();
    if (old?.gatt.connected) old.gatt.disconnect();
  }
  function write(packet) {
    const session = epoch,
      characteristic = rx,
      data = new TextEncoder().encode(JSON.stringify(packet) + '\n');
    const result = writes.then(async () => {
      for (let offset = 0; offset < data.length; offset += 20) {
        if (session !== epoch || !characteristic) throw new Error('Camera module disconnected. Connect again.');
        await characteristic.writeValueWithResponse(data.slice(offset, offset + 20));
      }
    });
    writes = result.catch(() => {});
    return result;
  }
  async function connect(pin) {
    if (!/^\d{6}$/.test(pin)) throw new Error('Enter the six-digit code shown on the camera module.');
    if (!bluetooth) throw new Error('Open localhost or HTTPS in desktop Chrome with Bluetooth enabled.');
    disconnect();
    const session = epoch;
    onState('connecting');
    try {
      const chosen = await bluetooth.requestDevice({ filters: [{ services: [SERVICE] }] });
      if (session !== epoch) return;
      device = chosen;
      device.addEventListener('gattserverdisconnected', reset);
      const server = await device.gatt.connect();
      const service = await server.getPrimaryService(SERVICE);
      const receive = await service.getCharacteristic(TX),
        transmit = await service.getCharacteristic(RX);
      if (session !== epoch) {
        if (chosen.gatt.connected) chosen.gatt.disconnect();
        return;
      }
      tx = receive;
      rx = transmit;
      reader = createPacketReader((packet, transitMs) => {
        if (packet.v === 1 && packet.type === 'ready') {
          ready = true;
          clearTimeout(authTimer);
          onState('connected', chosen.name);
        }
        onPacket(packet, transitMs);
      }, onError);
      tx.addEventListener('characteristicvaluechanged', notify);
      await tx.startNotifications();
      if (session !== epoch) return;
      onState('authenticating');
      authTimer = setTimeout(() => {
        onError('Camera module did not accept the code. Check its screen and reconnect.');
        disconnect();
      }, 10000);
      await write({ v: 1, type: 'command', command: 'hello', pin });
    } catch (error) {
      if (session === epoch) disconnect();
      throw error;
    }
  }
  async function send(command, id = globalThis.crypto.randomUUID(), extra = {}) {
    if (!ready) throw new Error('Connect the camera module first.');
    if (!['ping', 'capture', 'stop_camera', 'results', 'results_layer'].includes(command))
      throw new Error('Unsupported camera module command.');
    await write({ ...extra, v: 1, type: 'command', command, id });
    return id;
  }
  return { connect, disconnect, send };
}
