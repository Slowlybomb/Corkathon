import test from 'node:test';
import assert from 'node:assert/strict';
import { createAnalysisOverlay } from './analysis-layer.mjs';

test('cell inspection wraps in both directions and clears when the dataset changes',()=>{
  // Only the unavailable GPU boundary is replaced. Exercise the actual controller's
  // inspection state and callbacks, not calls made to the rendering library.
  const oldWindow=globalThis.window,oldMedia=globalThis.matchMedia;
  globalThis.window=Object.assign(new EventTarget(),{deck:{MapLibreOverlay:class{setProps(){} finalize(){}},ColumnLayer:class{}}});
  globalThis.matchMedia=()=>({matches:true});
  try{
    let inspected;
    const map={addControl(){},on(){},getZoom(){return 12;}};
    const control=createAnalysisOverlay(map,{onInspect:cell=>inspected=cell});
    control.setData({illustrative:false,findings:[
      {id:'first',latitude:51.95,longitude:-8.22,value:0},
      {id:'last',latitude:51.951,longitude:-8.221,value:10},
    ]},'all');
    control.inspectNext(-1);assert.equal(inspected.id,'last');
    control.inspectNext(1);assert.equal(inspected.id,'first');
    control.setData({findings:[]},'all');assert.equal(inspected,null);
    control.inspectNext(1);assert.equal(inspected,null);
  }finally{globalThis.window=oldWindow;globalThis.matchMedia=oldMedia;}
});
