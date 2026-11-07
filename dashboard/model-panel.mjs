import { utmToLngLat } from './geo.mjs';

const RELIEF = [
  [16, 44, 32],
  [44, 110, 73],
  [76, 149, 108],
  [214, 140, 69],
  [255, 201, 185],
];
const YIELD = [
  [165, 0, 38],
  [215, 48, 39],
  [244, 109, 67],
  [253, 174, 97],
  [254, 224, 139],
  [217, 239, 139],
  [166, 217, 106],
  [102, 189, 99],
  [26, 152, 80],
  [0, 104, 55],
];
const ZONES = [
  [244, 214, 246],
  [201, 120, 205],
  [118, 34, 135],
];
const GROUPS = {
  fields: 'Fields',
  soil: 'Soil · model on the phone',
  surface: 'Vegetation and water',
  weather: 'Weather · ERA5-Land observed',
};
const NAMES = {
  field_boundary_score: 'Field boundaries',
  ph: 'pH',
  soc_gkg: 'Organic carbon',
  clay_pct: 'Clay',
  sand_pct: 'Sand',
  ndvi: 'NDVI (vegetation)',
  ndmi: 'NDMI (moisture)',
  ndwi: 'NDWI (water)',
  temperature_c: 'Air temperature',
  humidity_pct: 'Humidity',
  soil_moisture_m3m3: 'Soil moisture',
  water_balance_30d_mm: '30-day water balance',
};
const THUMBS = [
  ['ph_0-5cm', 'pH'],
  ['soc_gkg_0-5cm', 'Organic carbon'],
  ['clay_pct_0-5cm', 'Clay'],
  ['sand_pct_0-5cm', 'Sand'],
  ['ndvi', 'NDVI'],
  ['ndmi', 'Moisture'],
];
const DEPTHS = ['0-5', '5-15', '15-30', '30-60', '60-100', '100-200'];
const FAST = 96;
const SVG = 'http://www.w3.org/2000/svg';

function soilParts(name) {
  return /^(ph|soc_gkg|clay_pct|sand_pct)_(.+)cm$/.exec(name);
}
function label(item) {
  const depth = soilParts(item.name);
  const base = depth ? NAMES[depth[1]] : (NAMES[item.name] ?? item.name.replaceAll('_', ' '));
  return `${base}${depth ? ` · ${depth[2]} cm` : ''}${item.units ? ` (${item.units})` : ''}`;
}
function ramp(stops, t) {
  const x = Math.max(0, Math.min(1, t)) * (stops.length - 1),
    i = Math.min(stops.length - 2, Math.floor(x)),
    f = x - i;
  return stops[i].map((value, k) => Math.round(value + f * (stops[i + 1][k] - value)));
}
export const rampColor = t => ramp(RELIEF, t);
const gradient = stops => `linear-gradient(90deg,${stops.map(([r, g, b]) => `rgb(${r},${g},${b})`).join(',')})`;
const fmt = value => (Number.isFinite(value) ? Number(value.toPrecision(3)).toLocaleString('en-IE') : '—');
function node(name, attributes, text) {
  const el = document.createElementNS(SVG, name);
  for (const [k, v] of Object.entries(attributes)) if (v !== undefined) el.setAttribute(k, v);
  if (text != null) el.textContent = text;
  return el;
}
function quantile(values, q) {
  const finite = [...values].filter(Number.isFinite).sort((a, b) => a - b);
  return finite[Math.min(finite.length - 1, Math.floor(finite.length * q))];
}
function rangeOf(layer) {
  return { low: quantile(layer.values, 0.02) ?? layer.min, high: quantile(layer.values, 0.98) ?? layer.max };
}

export function histogram(values, low, high, bins = 24) {
  const counts = new Array(bins).fill(0),
    span = high > low ? high - low : 1;
  for (const value of values)
    if (Number.isFinite(value)) counts[Math.max(0, Math.min(bins - 1, Math.floor(((value - low) / span) * bins)))]++;
  return counts;
}

export function paint(layer, mask, mode, range) {
  const n = layer.grid,
    canvas = document.createElement('canvas');
  canvas.width = n;
  canvas.height = n;
  const context = canvas.getContext('2d'),
    image = context.createImageData(n, n),
    values = layer.values,
    span = range.high > range.low ? range.high - range.low : 1;
  const boundaries = layer.name === 'field_boundary_score',
    cuts = [quantile(values, 1 / 3), quantile(values, 2 / 3)];
  for (let i = 0; i < values.length; i++) {
    const value = values[i];
    if (!Number.isFinite(value)) continue;
    if (boundaries) {
      if (value >= mask.cut) image.data.set([254, 254, 227, 235], i * 4);
      continue;
    }
    if (mask && !mask.inside[i]) continue;
    const color =
      mode === 'zones' ? ZONES[value < cuts[0] ? 0 : value < cuts[1] ? 1 : 2] : ramp(YIELD, (value - range.low) / span);
    image.data.set([...color, 228], i * 4);
  }
  context.putImageData(image, 0, 0);
  return canvas;
}

export function createModelPanel(map) {
  const $ = selector => document.querySelector(selector),
    panel = $('#model-panel');
  let client = null,
    manifest = null,
    request = 0,
    current = null,
    range = null,
    compareMap = null;
  const masks = new Map();
  const status = text => {
    $('#model-status').textContent = text;
  };
  const style = () => $('#model-style').value;
  function corners() {
    const m = manifest,
      w = m.width * m.pixel_size_m,
      h = m.height * m.pixel_size_m;
    return [
      utmToLngLat(m.origin_x, m.origin_y, m.crs),
      utmToLngLat(m.origin_x + w, m.origin_y, m.crs),
      utmToLngLat(m.origin_x + w, m.origin_y - h, m.crs),
      utmToLngLat(m.origin_x, m.origin_y - h, m.crs),
    ];
  }
  async function fieldMask(grid) {
    if (masks.has(grid)) return masks.get(grid);
    const [edges, green] = await Promise.all([client.layer('field_boundary_score', grid), client.layer('ndvi', grid)]);
    const cut = quantile(edges.values, 0.82);
    const mask = {
      grid,
      cut,
      inside: Uint8Array.from(edges.values, (value, i) => (value < cut && green.values[i] > 0.25 ? 1 : 0)),
    };
    masks.set(grid, mask);
    return mask;
  }
  function render() {
    if (!current || !range) return;
    const mode = style(),
      mask = masks.get(current.grid);
    if (mode === 'relief') {
      map.setHeatmapOpacity(0);
      map.setSurface({
        values: current.values,
        grid: current.grid,
        low: range.low,
        high: range.high,
        corners: corners(),
        height: Number($('#model-height').value),
        color: rampColor,
      });
      $('#model-legend').style.background = gradient(RELIEF);
      return;
    }
    map.clearSurface();
    map.setHeatmap({ url: paint(current, mask, mode, range).toDataURL(), coordinates: corners(), opacity: 1 });
    $('#model-legend').style.background =
      current.name === 'field_boundary_score'
        ? 'linear-gradient(90deg,#fefee3,#fefee3)'
        : mode === 'zones'
          ? gradient(ZONES)
          : gradient(YIELD);
  }
  function drawHistogram(layer) {
    const svg = $('#model-histogram'),
      counts = histogram(layer.values, range.low, range.high),
      peak = Math.max(...counts, 1),
      width = 240 / counts.length,
      stops = style() === 'relief' ? RELIEF : YIELD;
    svg.replaceChildren(
      ...counts.map((count, i) => {
        const h = (56 * count) / peak,
          [r, g, b] = ramp(stops, (i + 0.5) / counts.length);
        return node('rect', {
          x: i * width + 1,
          y: 58 - h,
          width: width - 2,
          height: Math.max(h, 0.5),
          rx: 1.5,
          fill: `rgb(${r},${g},${b})`,
        });
      }),
      node('text', { x: 0, y: 69 }, fmt(range.low)),
      node('text', { x: 240, y: 69, 'text-anchor': 'end' }, fmt(range.high)),
    );
  }
  function drawProfile(name) {
    const parts = soilParts(name),
      wrap = $('#model-profile-wrap');
    wrap.hidden = !parts;
    if (!parts) return;
    const means = DEPTHS.map(depth =>
        Number(manifest.layers.find(item => item.name === `${parts[1]}_${depth}cm`)?.mean),
      ),
      finite = means.filter(Number.isFinite);
    const low = Math.min(...finite),
      high = Math.max(...finite),
      span = high > low ? high - low : 1,
      x = value => 70 + (150 * (value - low)) / span,
      row = i => 12 + i * 18;
    const children = [];
    means.forEach((value, i) => {
      const selected = `${parts[1]}_${DEPTHS[i]}cm` === name,
        [r, g, b] = ramp(YIELD, (value - low) / span);
      children.push(node('text', { x: 0, y: row(i) + 3 }, `${DEPTHS[i]} cm`));
      children.push(
        node('rect', {
          x: 62,
          y: row(i) - 6,
          width: Math.max(4, x(value) - 62),
          height: 12,
          rx: 3,
          fill: `rgb(${r},${g},${b})`,
          opacity: selected ? 1 : 0.5,
        }),
      );
      children.push(
        node(
          'text',
          {
            x: Math.min(236, x(value) + 4),
            y: row(i) + 3,
            'text-anchor': x(value) > 200 ? 'end' : 'start',
            fill: selected ? '#fefee3' : undefined,
          },
          fmt(value),
        ),
      );
    });
    $('#model-profile').replaceChildren(...children);
  }
  function draw(layer) {
    range = rangeOf(layer);
    const finite = [...layer.values].filter(Number.isFinite),
      mean = finite.reduce((sum, value) => sum + value, 0) / Math.max(1, finite.length);
    render();
    drawHistogram(layer);
    drawProfile(layer.name);
    const item = manifest.layers.find(entry => entry.name === layer.name),
      mask = masks.get(layer.grid);
    const fieldShare = mask ? Math.round((100 * mask.inside.reduce((a, b) => a + b, 0)) / mask.inside.length) : null;
    $('#model-min').textContent = fmt(range.low);
    $('#model-max').textContent = fmt(range.high);
    $('#model-unit').textContent = item?.units ?? '';
    $('#model-mean').textContent = fmt(mean);
    $('#model-low').textContent = fmt(range.low);
    $('#model-high').textContent = fmt(range.high);
    $('#model-note').textContent =
      `${item?.source ? `Source: ${item.source}. ` : ''}${style() === 'relief' ? 'Relief height shows the value, not terrain.' : `Shown on detected field interiors${fieldShare == null ? '' : ` (${fieldShare}% of the scene)`}; roads, hedges and buildings stay clear.`} Estimates, not field measurements.`;
  }
  async function load(name, grid) {
    await fieldMask(grid);
    return client.layer(name, grid);
  }
  async function show() {
    if (!client || !manifest) return;
    const name = $('#model-layer').value,
      grid = Number($('#model-quality').value),
      mine = ++request,
      started = performance.now();
    const item = manifest.layers.find(entry => entry.name === name);
    try {
      if (grid > FAST) {
        status(`Loading ${label(item)} from the phone…`);
        const quick = await load(name, FAST);
        if (mine !== request) return;
        current = quick;
        draw(quick);
        status(
          `${label(item)} · sharpening to ${Math.round((manifest.width * manifest.pixel_size_m) / grid)} m cells over Bluetooth…`,
        );
      } else status(`Loading ${label(item)} from the phone…`);
      const layer = await load(name, grid);
      if (mine !== request) return;
      current = layer;
      draw(layer);
      status(
        `${label(item)} · ${layer.grid} × ${layer.grid} cells of ${Math.round((manifest.width * manifest.pixel_size_m) / layer.grid)} m · ${((performance.now() - started) / 1000).toFixed(1)} s over Bluetooth`,
      );
      drawCompare();
      thumbnails();
    } catch (error) {
      if (mine === request) status(error.message);
    }
  }
  async function thumbnails() {
    const box = $('#model-thumbs');
    if (box.childElementCount) return;
    const mask = await fieldMask(FAST);
    for (const [name, title] of THUMBS) {
      if (!manifest.layers.some(item => item.name === name)) continue;
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'model-thumb';
      button.title = `Show ${title}`;
      const caption = document.createElement('span');
      caption.textContent = title;
      button.onclick = () => {
        $('#model-layer').value = name;
        show();
      };
      box.append(button);
      try {
        const layer = await client.layer(name, FAST),
          canvas = paint(layer, mask, 'heatmap', rangeOf(layer));
        button.append(canvas, caption);
      } catch {
        button.append(caption);
      }
    }
  }
  function ensureCompareMap() {
    if (compareMap) return compareMap;
    const main = map.getMap(),
      maplibregl = window.maplibregl;
    compareMap = new maplibregl.Map({
      container: 'map-compare',
      interactive: false,
      attributionControl: false,
      center: main.getCenter(),
      zoom: main.getZoom(),
      bearing: main.getBearing(),
      pitch: main.getPitch(),
      maxPitch: 85,
      style: {
        version: 8,
        sources: {
          imagery: {
            type: 'raster',
            tileSize: 256,
            maxzoom: 19,
            tiles: ['https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'],
            attribution: 'Imagery &copy; Esri, Vantor, Earthstar Geographics, and the GIS User Community',
          },
        },
        layers: [{ id: 'imagery', type: 'raster', source: 'imagery' }],
      },
    });
    compareMap.addControl(new maplibregl.AttributionControl({ compact: true }), 'bottom-right');
    const sync = () =>
      compareMap.jumpTo({
        center: main.getCenter(),
        zoom: main.getZoom(),
        bearing: main.getBearing(),
        pitch: main.getPitch(),
      });
    main.on('move', sync);
    return compareMap;
  }
  async function drawCompare() {
    const name = $('#model-compare').value,
      on = name !== '';
    document.querySelector('.field-workspace').classList.toggle('compare', on);
    $('#map-compare').hidden = !on;
    $('#compare-labels').hidden = !on;
    if (!on || !manifest) return;
    const grid = Number($('#model-quality').value),
      target = ensureCompareMap(),
      item = manifest.layers.find(entry => entry.name === name);
    $('#compare-left').textContent = label(manifest.layers.find(entry => entry.name === $('#model-layer').value));
    $('#compare-right').textContent = `${label(item)} · loading…`;
    try {
      const layer = await load(name, grid),
        url = paint(layer, masks.get(grid), style() === 'relief' ? 'heatmap' : style(), rangeOf(layer)).toDataURL();
      const apply = () => {
        const source = target.getSource('compare');
        if (source) source.updateImage({ url, coordinates: corners() });
        else {
          target.addSource('compare', { type: 'image', url, coordinates: corners() });
          target.addLayer({
            id: 'compare',
            type: 'raster',
            source: 'compare',
            paint: { 'raster-resampling': 'linear', 'raster-fade-duration': 0 },
          });
        }
      };
      if (target.isStyleLoaded()) apply();
      else target.once('load', apply);
      $('#compare-right').textContent = label(item);
    } catch (error) {
      $('#compare-right').textContent = error.message;
    }
  }
  $('#model-layer').onchange = show;
  $('#model-quality').onchange = show;
  $('#model-compare').onchange = drawCompare;
  $('#model-style').onchange = () => {
    $('#model-relief').hidden = style() !== 'relief';
    if (current) draw(current);
    drawCompare();
  };
  $('#model-height').oninput = () => {
    $('#model-height-output').textContent = `${$('#model-height').value} m`;
    if (style() === 'relief') render();
  };
  $('#model-fit').onclick = () => map.fitArea();
  return {
    open(nextManifest, nextClient) {
      manifest = nextManifest;
      client = nextClient;
      masks.clear();
      $('#model-thumbs').replaceChildren();
      panel.hidden = false;
      const groups = new Map();
      for (const item of manifest.layers) {
        const g = item.group ?? 'fields';
        if (!groups.has(g)) groups.set(g, []);
        groups.get(g).push(item);
      }
      const options = () =>
        [...groups].map(([group, items]) => {
          const optgroup = document.createElement('optgroup');
          optgroup.label = GROUPS[group] ?? group;
          optgroup.append(
            ...items.map(item => {
              const option = document.createElement('option');
              option.value = item.name;
              option.textContent = label(item);
              return option;
            }),
          );
          return optgroup;
        });
      $('#model-layer').replaceChildren(...options());
      const off = document.createElement('option');
      off.value = '';
      off.textContent = 'Off';
      $('#model-compare').replaceChildren(off, ...options());
      $('#model-compare').value = '';
      $('#model-layer').value = manifest.layers.some(item => item.name === 'field_boundary_score')
        ? 'field_boundary_score'
        : manifest.layers[0].name;
      $('#model-title').textContent = `Drone model · ${manifest.computed?.device ?? 'phone'}`;
      show();
    },
    status,
  };
}
