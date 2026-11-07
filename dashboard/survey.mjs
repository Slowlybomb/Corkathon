export function findingsForLayer(findings, layer) {
  return findings.filter(finding => layer === 'all' || finding.layer === layer);
}

export function retainSelection(findings, selected) {
  return findings.some(finding => finding.id === selected) ? selected : findings[0]?.id;
}
