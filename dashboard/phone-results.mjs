import { validateManifest } from './scene.mjs';

const BASE='https://phone.bluetooth/results/manifest.json';

export async function decodeGrid(data,count){
  const bytes=Uint8Array.from(atob(data),char=>char.charCodeAt(0));
  const stream=new Blob([bytes]).stream().pipeThrough(new DecompressionStream('deflate'));
  const buffer=await new Response(stream).arrayBuffer();
  if(buffer.byteLength!==count*4)throw new Error('Model result layer has an unexpected size.');
  const view=new DataView(buffer),values=new Float32Array(count);
  for(let i=0;i<count;i++)values[i]=view.getFloat32(i*4,true);
  return values;
}

export function expandGrid(values,width,height,stride){
  const columns=Math.ceil(width/stride),rows=Math.ceil(height/stride);
  if(values.length!==columns*rows)throw new Error('Model result grid does not match the scene size.');
  const full=new Float32Array(width*height).fill(Number.NaN);
  for(let r=0;r<rows;r++)for(let c=0;c<columns;c++)full[r*stride*width+c*stride]=values[r*columns+c];
  return full.buffer;
}

export function createResultsClient({send,timeoutMs=60000}){
  const waiting=new Map(),cache=new Map();
  let header=null;
  function request(command,extra={}){
    const id=globalThis.crypto.randomUUID();
    return new Promise((resolve,reject)=>{
      const timer=setTimeout(()=>{waiting.delete(id);reject(new Error('The phone did not answer in time. Check the Bluetooth connection.'));},timeoutMs);
      waiting.set(id,{resolve:value=>{clearTimeout(timer);resolve(value);},reject:error=>{clearTimeout(timer);reject(error);}});
      send(command,id,extra).catch(error=>{const entry=waiting.get(id);waiting.delete(id);entry?.reject(error);});
    });
  }
  async function layer(name){
    if(cache.has(name))return cache.get(name);
    const packet=await request('results_layer',{layer:name});
    const grid=packet.grid,stride=packet.stride;
    if(!Number.isSafeInteger(grid)||!Number.isSafeInteger(stride)||stride!==header.stride)throw new Error('Model result layer does not match the result list.');
    const buffer=expandGrid(await decodeGrid(packet.data,grid*grid),header.width,header.height,stride);
    cache.set(name,buffer);return buffer;
  }
  async function fetcher(url){
    const path=new URL(url).pathname.replace('/results/','');
    const item=header?.layers.find(entry=>entry.file===path);
    if(!item)return new Response(null,{status:404});
    return new Response(await layer(item.name));
  }
  return {
    handle(packet){
      const entry=waiting.get(packet?.id);
      if(!entry||!['results','results_layer','error'].includes(packet.type))return false;
      waiting.delete(packet.id);
      if(packet.type==='error')entry.reject(new Error(String(packet.message??'The phone could not send model results.').slice(0,300)));
      else entry.resolve(packet);
      return true;
    },
    async requestScene(){
      const packet=await request('results');
      if(!Number.isSafeInteger(packet.stride)||packet.stride<1)throw new Error('The phone sent an invalid result list.');
      const {v,type,id,sentAt,encoding,grid,...manifest}=packet;
      header=validateManifest({...manifest,stride:packet.stride});cache.clear();
      return {manifest:header,url:BASE,layers:header.layers.filter(item=>item.type==='float32'&&item.group!=='terrain'),fetcher};
    },
    reset(){for(const entry of waiting.values())entry.reject(new Error('Bluetooth disconnected.'));waiting.clear();cache.clear();header=null;},
  };
}
