import { validateManifest } from './scene.mjs';

export async function decodeU8(data) {
  const bytes = Uint8Array.from(atob(data), char => char.charCodeAt(0));
  const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream('deflate'));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

export function createResultsClient({ send, timeoutMs = 120000, onPart = () => {} }) {
  const waiting = new Map(),
    cache = new Map();
  let header = null;
  function request(command, extra = {}) {
    const id = globalThis.crypto.randomUUID();
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        waiting.delete(id);
        reject(new Error('The phone did not answer in time. Check the Bluetooth connection.'));
      }, timeoutMs);
      waiting.set(id, {
        parts: [],
        resolve: value => {
          clearTimeout(timer);
          resolve(value);
        },
        reject: error => {
          clearTimeout(timer);
          reject(error);
        },
      });
      send(command, id, extra).catch(error => {
        const entry = waiting.get(id);
        waiting.delete(id);
        entry?.reject(error);
      });
    });
  }
  return {
    handle(packet) {
      const entry = waiting.get(packet?.id);
      if (!entry || !['results', 'results_layer', 'error'].includes(packet.type)) return false;
      if (packet.type === 'error') {
        waiting.delete(packet.id);
        entry.reject(new Error(String(packet.message ?? 'The phone could not send model results.').slice(0, 300)));
        return true;
      }
      if (packet.type === 'results_layer' && Number(packet.parts) > 1) {
        entry.parts[packet.part] = packet.data;
        const received = entry.parts.filter(item => typeof item === 'string').length;
        onPart(received, packet.parts);
        if (received < packet.parts) return true;
        packet = { ...packet, data: entry.parts.join('') };
      }
      waiting.delete(packet.id);
      entry.resolve(packet);
      return true;
    },
    async requestScene() {
      const packet = await request('results');
      const { v, type, id, sentAt, encoding, grid, stride, ...manifest } = packet;
      header = validateManifest(manifest);
      cache.clear();
      return header;
    },
    async layer(name, grid = 192) {
      const key = `${name}@${grid}`;
      if (cache.has(key)) return cache.get(key);
      const packet = await request('results_layer', { layer: name, grid });
      const q = await decodeU8(packet.data),
        n = packet.grid;
      if (!Number.isSafeInteger(n) || q.length !== n * n) throw new Error('Model layer has an unexpected size.');
      const min = Number(packet.min),
        max = Number(packet.max),
        values = new Float32Array(n * n);
      for (let i = 0; i < q.length; i++) values[i] = q[i] === 255 ? Number.NaN : min + ((max - min) * q[i]) / 254;
      const layer = { name, grid: n, min, max, values };
      cache.set(key, layer);
      return layer;
    },
    reset() {
      for (const entry of waiting.values()) entry.reject(new Error('Bluetooth disconnected.'));
      waiting.clear();
      cache.clear();
      header = null;
    },
  };
}
