import * as THREE from 'three';
import { loadDroneModel } from './drone-model.mjs';
import { telemetryAt, droneQuaternion } from './telemetry.mjs';

// Independent attitude display: its centred model has no geographic position.
export function createDroneTelemetry(panel) {
  const $ = selector => panel.querySelector(selector),
    canvas = $('canvas');
  let connected = false,
    sample = null,
    renderer,
    asset,
    loading = false,
    failed = false,
    disposed = false,
    lastPose = '';
  const scene = new THREE.Scene(),
    camera = new THREE.PerspectiveCamera(32, 1, 0.1, 100);
  camera.up.set(0, 0, 1);
  camera.position.set(3, -5, 3.2);
  camera.lookAt(0, 0, 0);
  scene.add(new THREE.AmbientLight(0xffffff, 2));
  const light = new THREE.DirectionalLight(0xfff7dc, 2.5);
  light.position.set(-3, -4, 7);
  scene.add(light);
  const drone = new THREE.Group();
  drone.name = 'phone-attitude';
  scene.add(drone);
  drone.visible = false;
  const number = value => (Number.isFinite(value) ? `${Math.round(value) === 0 ? 0 : Math.round(value)}°` : '—');
  function draw() {
    if (!renderer || canvas.hidden || panel.hidden) return;
    const width = canvas.clientWidth,
      height = canvas.clientHeight;
    if (!width || !height) return;
    renderer.setSize(width, height, false);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    renderer.render(scene, camera);
  }
  async function ensureModel() {
    if (loading || failed || asset || disposed) return;
    loading = true;
    try {
      renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
      renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
      const next = await loadDroneModel(2.6);
      if (disposed) {
        next.dispose();
        return;
      }
      asset = next;
      drone.add(asset.model);
      lastPose = '';
      render();
    } catch (error) {
      failed = true;
      console.error('Attitude model could not load', error);
      render();
    } finally {
      loading = false;
    }
  }
  function render() {
    const current = connected ? telemetryAt(sample) : { location: null, orientation: null };
    const gps = current.location,
      attitude = current.orientation,
      pose = droneQuaternion(attitude);
    $('#drone-position-reading').textContent = gps
      ? `${gps.latitude.toFixed(6)}, ${gps.longitude.toFixed(6)}`
      : connected
        ? 'Waiting for phone GPS'
        : 'GPS unavailable';
    $('#drone-gps-quality').textContent = gps
      ? `±${Math.round(gps.accuracyM)} m${gps.altitudeM == null ? '' : ` · altitude ${gps.altitudeM.toFixed(1)} m WGS84`}`
      : connected
        ? 'No geographic position displayed'
        : 'Disconnected';
    $('#drone-pitch').textContent = number(attitude?.pitchDeg);
    $('#drone-roll').textContent = number(attitude?.rollDeg);
    $('#drone-heading').textContent = number(attitude?.headingDeg);
    $('#drone-heading-reference').textContent = attitude
      ? attitude.declinationDeg == null
        ? 'Magnetic heading'
        : 'True heading'
      : 'Heading';
    $('#drone-telemetry-state').textContent = !connected
      ? 'Disconnected'
      : attitude
        ? `Phone attitude · ${attitude.accuracy} accuracy`
        : sample?.orientation
          ? 'Attitude expired'
          : 'Waiting for phone attitude';
    $('#drone-locate').disabled = !gps || Math.abs(gps.latitude) > 85;
    drone.visible = Boolean(pose);
    canvas.hidden = !pose || failed || !asset;
    $('#drone-attitude-empty').hidden = Boolean(pose && asset) && !failed;
    $('#drone-attitude-empty').textContent = failed
      ? '3D view unavailable'
      : pose && !asset
        ? 'Loading model…'
        : connected
          ? 'Waiting for attitude'
          : 'Disconnected';
    if (!pose) {
      lastPose = '';
      return;
    }
    drone.quaternion.fromArray(pose);
    ensureModel();
    const key = pose.join(',');
    if (key !== lastPose) {
      lastPose = key;
      draw();
    }
  }
  const observer = new ResizeObserver(draw);
  observer.observe(canvas);
  const timer = setInterval(() => {
    if (!panel.hidden) render();
  }, 500);
  $('#drone-locate').onclick = () => window.dispatchEvent(new Event('phone-locate'));
  function destroy() {
    disposed = true;
    clearInterval(timer);
    observer.disconnect();
    asset?.dispose();
    renderer?.dispose();
  }
  window.addEventListener('pagehide', destroy, { once: true });
  return {
    setConnection(value) {
      connected = value;
      sample = null;
      panel.hidden = false;
      render();
    },
    setSample(value) {
      sample = value;
      render();
    },
    hide() {
      panel.hidden = true;
    },
  };
}
