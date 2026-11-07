export function positionAt(route, time) {
  if (!route.length) return null;
  const end = route.findIndex(point => point.time >= time);
  const b = route[end < 0 ? route.length - 1 : end];
  const a = route[Math.max(0, end - 1)] ?? b;
  if (end <= 0) return { x: b.x, y: b.y };
  const fraction = (time - a.time) / (b.time - a.time);
  return { x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction };
}

export function findingsForLayer(findings, layer) {
  return findings.filter(finding => layer === 'all' || finding.layer === layer);
}

export function retainSelection(findings, selected) {
  return findings.some(finding => finding.id === selected) ? selected : findings[0]?.id;
}

// Local coordinates are east/north. The upright drone's nose points along -Y.
export function routeYawAt(route, time, project = point => point) {
  if (route.length < 2) return null;
  const next = route.findIndex(point => point.time > time);
  const active = Math.max(0, (next < 0 ? route.length - 1 : next) - 1);
  function segmentYaw(index) {
    if (route[index + 1].time <= route[index].time) return null;
    const a = project(route[index]), b = project(route[index + 1]);
    const dx = b.x - a.x, dy = b.y - a.y;
    if (!Number.isFinite(dx) || !Number.isFinite(dy) || Math.hypot(dx, dy) < 1e-6) return null;
    return Math.atan2(dx, -dy);
  }
  // At a stop retain the incoming heading; before the first movement face ahead.
  for (let index = active; index >= 0; index--) {
    const yaw = segmentYaw(index);
    if (yaw !== null) return yaw;
  }
  for (let index = active + 1; index < route.length - 1; index++) {
    const yaw = segmentYaw(index);
    if (yaw !== null) return yaw;
  }
  return null;
}
