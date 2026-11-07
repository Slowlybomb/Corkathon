import * as THREE from 'three';
import { loadDroneModel } from './drone-model.mjs';
import { findingsForLayer } from './survey.mjs';
import { demoArea, coordinatesFor, surveyBounds } from './geo.mjs';
import { createAnalysisOverlay } from './analysis-layer.mjs';
import { telemetryAt, droneQuaternion } from './telemetry.mjs';
import { createFlight, stepFlight } from './flight.mjs';

const collection = features => ({ type: 'FeatureCollection', features });
const feature = (geometry, properties = {}) => ({ type: 'Feature', geometry, properties });

export function createFieldMap(
  container,
  initialSurvey,
  onSelect,
  onStatus = () => {},
  onBasemapChange = () => {},
  onAnalysisChange = () => {},
  onCellInspect = () => {},
) {
  const maplibregl = window.maplibregl;
  if (!maplibregl) throw new Error('MapLibre did not load');
  let survey = initialSurvey,
    layer = 'all',
    selected = survey.findings[0]?.id,
    view = '3d',
    ready = false,
    basemap = 'satellite';
  let liveTelemetry = null,
    located = false,
    cameraMode = 'free',
    flight = null,
    followFrame = 0,
    lastFrame = 0;
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const map = new maplibregl.Map({
    container,
    style: 'https://tiles.openfreemap.org/styles/liberty',
    center: [demoArea.center.longitude, demoArea.center.latitude],
    zoom: 12.5,
    pitch: 52,
    bearing: -12,
    maxPitch: 70,
    attributionControl: false,
    canvasContextAttributes: { antialias: true },
  });
  map.addControl(new maplibregl.AttributionControl({ compact: true }), 'bottom-right');
  map
    .getCanvas()
    .setAttribute(
      'aria-label',
      'Geographic field map. Drag to pan, right-drag to rotate. Findings are available in the observations list.',
    );
  const origin = maplibregl.MercatorCoordinate.fromLngLat([demoArea.center.longitude, demoArea.center.latitude], 0);
  const meter = origin.meterInMercatorCoordinateUnits();
  function local(point, altitude = 0) {
    const mercator = maplibregl.MercatorCoordinate.fromLngLat(coordinatesFor(point), altitude);
    return new THREE.Vector3(
      (mercator.x - origin.x) / meter,
      -(mercator.y - origin.y) / meter,
      (mercator.z - origin.z) / meter,
    );
  }
  const scene = new THREE.Scene(),
    camera = new THREE.Camera();
  scene.add(new THREE.AmbientLight(0xffffff, 2));
  const light = new THREE.DirectionalLight(0xfff7dc, 2.5);
  light.position.set(-1500, -2500, 4500);
  scene.add(light);
  const drone = new THREE.Group();
  drone.name = 'survey-drone';
  scene.add(drone);
  const surface = new THREE.Group();
  surface.name = 'model-surface';
  scene.add(surface);
  const frustumLines = new THREE.LineSegments(
    new THREE.BufferGeometry().setAttribute('position', new THREE.BufferAttribute(new Float32Array(48), 3)),
    new THREE.LineBasicMaterial({ color: 0xfefee3, transparent: true, opacity: 0.9 }),
  );
  const footprintGeometry = new THREE.BufferGeometry().setAttribute(
    'position',
    new THREE.BufferAttribute(new Float32Array(18), 3),
  );
  const footprint = new THREE.Mesh(
    footprintGeometry,
    new THREE.MeshBasicMaterial({
      color: 0xffc9b9,
      transparent: true,
      opacity: 0.28,
      side: THREE.DoubleSide,
      depthWrite: false,
    }),
  );
  frustumLines.frustumCulled = false;
  footprint.frustumCulled = false;
  frustumLines.visible = false;
  footprint.visible = false;
  scene.add(frustumLines, footprint);
  function updateFrustum(apex) {
    const h = ((flight.heading ?? 0) * Math.PI) / 180,
      look = (Math.max(0, Math.min(60, 30 + flight.pitch)) * Math.PI) / 180,
      half = [(35 * Math.PI) / 180, (24 * Math.PI) / 180];
    const f = [Math.sin(h), Math.cos(h), 0],
      r = [Math.cos(h), -Math.sin(h), 0];
    const c = [Math.sin(look) * f[0], Math.sin(look) * f[1], -Math.cos(look)],
      u = [Math.cos(look) * f[0], Math.cos(look) * f[1], Math.sin(look)];
    const corners = [
      [-1, 1],
      [1, 1],
      [1, -1],
      [-1, -1],
    ].map(([sx, sy]) => {
      const ray = [0, 1, 2].map(k => c[k] + sx * Math.tan(half[0]) * r[k] + sy * Math.tan(half[1]) * u[k]);
      const t = apex.z / Math.max(0.05, -ray[2]);
      return [apex.x + ray[0] * t, apex.y + ray[1] * t, 1.5];
    });
    const line = frustumLines.geometry.attributes.position,
      a = [apex.x, apex.y, apex.z];
    corners.forEach((p, i) => {
      line.set([...a, ...p], i * 6);
      line.set([...p, ...corners[(i + 1) % 4]], 24 + i * 6);
    });
    line.needsUpdate = true;
    footprintGeometry.attributes.position.set([
      ...corners[0],
      ...corners[1],
      ...corners[2],
      ...corners[0],
      ...corners[2],
      ...corners[3],
    ]);
    footprintGeometry.attributes.position.needsUpdate = true;
    frustumLines.visible = cameraMode !== 'fpv' && view === '3d';
    footprint.visible = true;
  }
  let renderer,
    mixer,
    droneAsset,
    modelGeneration = 0,
    modelRequested = false,
    analysis,
    analysisError = null;
  let analysisOptions = {};
  function ensureDroneModel() {
    if (!renderer || (!flight && !telemetryAt(liveTelemetry).location) || modelRequested) return;
    modelRequested = true;
    const generation = ++modelGeneration;
    loadDroneModel()
      .then(asset => {
        if (generation !== modelGeneration) {
          asset.dispose();
          return;
        }
        droneAsset = asset;
        mixer = asset.mixer;
        drone.add(asset.model);
        mixer.setTime(0);
        map.triggerRepaint();
      })
      .catch(error => {
        if (generation !== modelGeneration) return;
        console.error('Drone model could not load', error);
        onStatus('Drone model could not load. The position marker remains available when position data exists.');
      });
  }
  const threeLayer = {
    id: 'drone-3d',
    type: 'custom',
    renderingMode: '3d',
    onAdd(_map, gl) {
      renderer = new THREE.WebGLRenderer({ canvas: map.getCanvas(), context: gl, antialias: true });
      renderer.autoClear = false;
      ensureDroneModel();
    },
    render(_gl, args) {
      // Local meshes use Mercator. Native map layers wrap around the globe at wider scales.
      if (args.defaultProjectionData.projectionTransition > 0) return;
      const projection = new THREE.Matrix4().fromArray(args.defaultProjectionData.mainMatrix);
      const model = new THREE.Matrix4()
        .makeTranslation(origin.x, origin.y, origin.z)
        .scale(new THREE.Vector3(meter, -meter, meter));
      camera.projectionMatrix.copy(projection).multiply(model);
      renderer.resetState();
      renderer.render(scene, camera);
    },
    onRemove() {
      modelGeneration++;
      modelRequested = false;
      droneAsset?.dispose();
      droneAsset = null;
      mixer = null;
      drone.clear();
      renderer?.dispose();
    },
  };
  function visibleFindings() {
    return findingsForLayer(survey.findings, layer);
  }
  function updateData() {
    if (!ready) return;
    const findings = visibleFindings();
    map
      .getSource('findings')
      .setData(
        collection(
          findings.map(finding =>
            feature(
              { type: 'Point', coordinates: coordinatesFor(finding) },
              { id: finding.id, number: String(survey.findings.indexOf(finding) + 1).padStart(2, '0') },
            ),
          ),
        ),
      );
    analysis?.setData(survey, layer);
    map.setPaintProperty('finding-points', 'circle-color', [
      'case',
      ['==', ['get', 'id'], selected ?? ''],
      '#fefee3',
      '#2c6e49',
    ]);
    updateTelemetryPosition();
  }
  function updateTelemetryPosition() {
    const current = telemetryAt(liveTelemetry),
      point = current.location;
    const plottable = point && Math.abs(point.latitude) <= 85;
    if (ready)
      map
        .getSource('drone-position')
        .setData(
          collection(
            plottable
              ? [
                  feature(
                    { type: 'Point', coordinates: [point.longitude, point.latitude] },
                    { source: 'phone-gps', accuracyM: point.accuracyM },
                  ),
                ]
              : [],
          ),
        );
    if (flight) {
      map.triggerRepaint();
      return;
    }
    const attitude = droneQuaternion(current.orientation);
    // GPS without attitude remains a point; no fabricated yaw, tilt, altitude, or rotor motion.
    drone.visible = Boolean(plottable && attitude) && view === '3d';
    if (plottable) {
      ensureDroneModel();
      drone.position.copy(local(point, point.altitudeM ?? 0));
      if (attitude) drone.quaternion.fromArray(attitude);
      if (ready && !located) {
        located = true;
        locateDrone();
      }
    }
    mixer?.setTime(0);
    map.triggerRepaint();
  }
  function stepFollow(now) {
    if (!flight) return;
    const dt = Math.min(0.1, Math.max(0, (now - lastFrame) / 1000));
    lastFrame = now;
    const chase = stepFlight(flight, telemetryAt(liveTelemetry), dt);
    drone.position.copy(local(flight, 120));
    const pose = droneQuaternion({ headingDeg: flight.heading ?? 0, pitchDeg: flight.pitch, rollDeg: flight.roll });
    if (pose) drone.quaternion.fromArray(pose);
    drone.visible = view === '3d' && cameraMode !== 'fpv';
    ensureDroneModel();
    updateFrustum(drone.position);
    if (cameraMode === 'follow') map.jumpTo(chase);
    else if (cameraMode === 'overview')
      map.jumpTo({ center: [flight.longitude, flight.latitude], zoom: 14.3, pitch: 55, bearing: -20, roll: 0 });
    else if (cameraMode === 'fpv')
      map.jumpTo(
        map.calculateCameraOptionsFromCameraLngLatAltRotation(
          [flight.longitude, flight.latitude],
          120,
          flight.heading ?? 0,
          Math.max(0, Math.min(85, 65 - flight.pitch)),
          flight.roll,
        ),
      );
    else map.triggerRepaint();
    followFrame = requestAnimationFrame(stepFollow);
  }
  function startFlight() {
    if (flight) return;
    flight = createFlight(demoArea);
    lastFrame = performance.now();
    followFrame = requestAnimationFrame(stepFollow);
  }
  function stopFlight() {
    cancelAnimationFrame(followFrame);
    flight = null;
    frustumLines.visible = false;
    footprint.visible = false;
    updateTelemetryPosition();
  }
  function setCameraMode(mode) {
    cameraMode = mode;
    if (mode !== 'free') startFlight();
    map.setMaxPitch(mode === 'fpv' ? 85 : 70);
    if (mode === 'free' && ready)
      map.easeTo({ roll: 0, pitch: Math.min(map.getPitch(), 70), duration: reduced ? 0 : 300 });
    if (mode === 'free' && !liveTelemetry) stopFlight();
  }
  function setHeatmap({ url, coordinates, opacity }) {
    if (!ready) return;
    const source = map.getSource('phone-heatmap');
    if (source) source.updateImage({ url, coordinates });
    else {
      map.addSource('phone-heatmap', { type: 'image', url, coordinates });
      map.addLayer(
        {
          id: 'phone-heatmap',
          type: 'raster',
          source: 'phone-heatmap',
          paint: { 'raster-opacity': opacity, 'raster-resampling': 'linear', 'raster-fade-duration': 0 },
        },
        'drone-3d',
      );
    }
    map.setPaintProperty('phone-heatmap', 'raster-opacity', opacity);
  }
  function clearSurface() {
    for (const mesh of surface.children) {
      mesh.geometry.dispose();
      mesh.material.dispose();
    }
    surface.clear();
  }
  function setSurface({ values, grid, low, high, corners, height, color }) {
    clearSurface();
    const n = grid,
      geometry = new THREE.PlaneGeometry(1, 1, n - 1, n - 1),
      position = geometry.attributes.position,
      colors = new Float32Array(n * n * 3);
    const [tl, tr, br, bl] = corners,
      span = high > low ? high - low : 1;
    for (let r = 0; r < n; r++)
      for (let c = 0; c < n; c++) {
        const u = (c + 0.5) / n,
          v = (r + 0.5) / n,
          value = values[r * n + c],
          t = Number.isFinite(value) ? Math.max(0, Math.min(1, (value - low) / span)) : 0;
        const longitude = tl[0] * (1 - u) * (1 - v) + tr[0] * u * (1 - v) + br[0] * u * v + bl[0] * (1 - u) * v,
          latitude = tl[1] * (1 - u) * (1 - v) + tr[1] * u * (1 - v) + br[1] * u * v + bl[1] * (1 - u) * v;
        const p = local({ longitude, latitude }, 6 + t * height),
          i = r * n + c,
          [red, green, blue] = color(t);
        position.setXYZ(i, p.x, p.y, p.z);
        colors[i * 3] = red / 255;
        colors[i * 3 + 1] = green / 255;
        colors[i * 3 + 2] = blue / 255;
      }
    geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    geometry.computeVertexNormals();
    surface.add(
      new THREE.Mesh(
        geometry,
        new THREE.MeshStandardMaterial({
          vertexColors: true,
          roughness: 0.85,
          metalness: 0,
          side: THREE.DoubleSide,
          transparent: true,
          opacity: 0.78,
          depthWrite: false,
        }),
      ),
    );
    map.triggerRepaint();
  }
  function setHeatmapOpacity(opacity) {
    if (ready && map.getLayer('phone-heatmap')) map.setPaintProperty('phone-heatmap', 'raster-opacity', opacity);
  }
  function fitArea() {
    const c = [demoArea.topLeft, demoArea.topRight, demoArea.bottomLeft, demoArea.bottomRight];
    map.fitBounds(
      [
        [Math.min(...c.map(p => p.longitude)), Math.min(...c.map(p => p.latitude))],
        [Math.max(...c.map(p => p.longitude)), Math.max(...c.map(p => p.latitude))],
      ],
      {
        padding: { top: 130, bottom: 170, left: 330, right: 330 },
        minZoom: 12.4,
        maxZoom: 14.5,
        pitch: view === '3d' ? 55 : 0,
        duration: reduced ? 0 : 650,
      },
    );
    map.once('moveend', () => {
      if (map.getZoom() < 12.4) map.easeTo({ zoom: 12.6, duration: reduced ? 0 : 300 });
    });
  }
  function fit() {
    const bounds = surveyBounds(survey);
    if (!bounds) {
      locateDrone();
      return;
    }
    const compact = container.clientWidth < 1000 || container.clientHeight < 560;
    map.fitBounds(bounds, {
      maxZoom: 17,
      padding: compact
        ? { top: 110, bottom: 130, left: 25, right: 25 }
        : { top: 125, bottom: 160, left: 290, right: 335 },
      duration: reduced ? 0 : 650,
      pitch: view === '3d' ? 52 : 0,
      bearing: view === '3d' ? -12 : 0,
    });
  }
  function locateDrone() {
    const point = telemetryAt(liveTelemetry).location;
    if (!point || Math.abs(point.latitude) > 85) return;
    map.easeTo({ center: [point.longitude, point.latitude], zoom: 16, duration: reduced ? 0 : 650 });
  }
  const telemetryTimer = setInterval(() => {
    if (liveTelemetry) updateTelemetryPosition();
  }, 1000);
  map.on('remove', () => clearInterval(telemetryTimer));
  function setBasemap(value) {
    if (!['map', 'satellite'].includes(value)) return;
    basemap = value;
    if (ready) {
      // Keep the style and shared WebGL context alive; only the raster visibility changes.
      map.setLayoutProperty('satellite-imagery', 'visibility', value === 'satellite' ? 'visible' : 'none');
    }
    onBasemapChange(value);
    onStatus(analysisError);
  }
  map.on('load', () => {
    map.setProjection({ type: view === '3d' ? 'globe' : 'mercator' });
    // World-scale labels clutter the globe rim in this MapLibre version. Keep local labels.
    for (const item of map.getStyle().layers.filter(item => item.type === 'symbol')) {
      const maximum = item.maxzoom ?? 24;
      map.setLayerZoomRange(item.id, Math.min(maximum, Math.max(4, item.minzoom ?? 0)), maximum);
    }
    map.addSource('satellite-imagery', {
      type: 'raster',
      tileSize: 256,
      maxzoom: 19,
      tiles: ['https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'],
      attribution:
        'Imagery &copy; <a href="https://www.arcgis.com/home/item.html?id=10df2279f9684e4a9f6a7f08febac2a9" target="_blank" rel="noopener">Esri</a>, Vantor, Earthstar Geographics, and the GIS User Community',
    });
    // Added above the base style and below every survey layer, including Three.js.
    map.addLayer({
      id: 'satellite-imagery',
      type: 'raster',
      source: 'satellite-imagery',
      layout: { visibility: 'none' },
      paint: { 'raster-fade-duration': 150 },
    });
    map.addLayer(threeLayer);
    analysis = createAnalysisOverlay(map, {
      beforeId: 'drone-3d',
      onChange: onAnalysisChange,
      onInspect: onCellInspect,
      onError: message => {
        analysisError = message;
        onStatus(message);
      },
    });
    analysis?.setOptions(analysisOptions);
    analysis?.setView(view);
    map.addSource('findings', { type: 'geojson', data: collection([]) });
    map.addLayer({
      id: 'finding-points',
      type: 'circle',
      source: 'findings',
      paint: {
        'circle-radius': 11,
        'circle-color': '#2c6e49',
        'circle-stroke-color': '#fefee3',
        'circle-stroke-width': 2,
      },
    });
    map.addLayer({
      id: 'finding-labels',
      type: 'symbol',
      source: 'findings',
      layout: { 'text-field': ['get', 'number'], 'text-size': 10, 'text-allow-overlap': true },
      paint: { 'text-color': '#153526', 'text-halo-color': '#fefee3', 'text-halo-width': 1.3 },
    });
    map.addSource('drone-position', { type: 'geojson', data: collection([]) });
    map.addLayer({
      id: 'drone-point',
      type: 'circle',
      source: 'drone-position',
      paint: {
        'circle-radius': 6,
        'circle-color': '#ffc9b9',
        'circle-stroke-color': '#153526',
        'circle-stroke-width': 2,
      },
    });
    ready = true;
    updateData();
    fit();
    setBasemap(basemap);
    map.on('click', 'finding-points', event => {
      const id = event.features?.[0]?.properties?.id;
      if (id) onSelect(id);
    });
    map.on('mouseenter', 'finding-points', () => (map.getCanvas().style.cursor = 'pointer'));
    map.on('mouseleave', 'finding-points', () => (map.getCanvas().style.cursor = ''));
  });
  map.on('error', event => {
    if (event.sourceId === 'phone-heatmap' || event.error?.name === 'AbortError') return;
    if (event.sourceId === 'satellite-imagery') {
      if (basemap === 'satellite') {
        setBasemap('map');
        onStatus('Satellite imagery could not load. Showing the map; check internet access before trying again.');
      }
      return;
    }
    onStatus('Map source could not load. Check internet access and reload.');
  });
  map.on('webglcontextlost', () => onStatus('The graphics context was lost. Reload to restore the map.'));
  const observer = new ResizeObserver(() => map.resize());
  observer.observe(container);
  return {
    setBasemap,
    setAnalysisOptions(options) {
      analysisOptions = { ...analysisOptions, ...options };
      analysis?.setOptions(analysisOptions);
    },
    inspectAnalysisCell(direction) {
      analysis?.inspectNext(direction);
    },
    setView(value) {
      view = value;
      analysis?.setView(value);
      if (ready) {
        map.setProjection({ type: value === '3d' ? 'globe' : 'mercator' });
      }
      map.easeTo({ pitch: value === '3d' ? 52 : 0, bearing: value === '3d' ? -12 : 0, duration: reduced ? 0 : 500 });
      updateTelemetryPosition();
    },
    setLayer(value) {
      layer = value;
      updateData();
    },
    setSelected(value) {
      selected = value;
      if (ready)
        map.setPaintProperty('finding-points', 'circle-color', [
          'case',
          ['==', ['get', 'id'], selected ?? ''],
          '#fefee3',
          '#2c6e49',
        ]);
    },
    setSurvey(value) {
      survey = value;
      updateData();
    },
    setTelemetry(value) {
      liveTelemetry = value;
      if (!value) located = false;
      if (value) startFlight();
      else if (cameraMode === 'free') stopFlight();
      updateTelemetryPosition();
    },
    locateDrone,
    setCameraMode,
    followMode() {
      return flight?.mode ?? null;
    },
    setHeatmap,
    setHeatmapOpacity,
    fitArea,
    setSurface,
    clearSurface,
    getMap() {
      return map;
    },
    zoomBy(factor) {
      map.easeTo({ zoom: map.getZoom() + Math.log2(factor), duration: reduced ? 0 : 200 });
    },
    fit,
  };
}
