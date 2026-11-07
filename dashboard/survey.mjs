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
