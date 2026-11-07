// Disposable example data. Change this freely when the AI teammate has output.
export const survey = {
  illustrative: true,
  name: 'South meadow', location: 'Cork · Illustrative field', date: '7 November 2026',
  duration: 150, source: 'Hand-authored sample',
  route: [
    { time: 0, x: 320, y: 220 }, { time: 25, x: 690, y: 280 },
    { time: 35, x: 670, y: 350 }, { time: 60, x: 300, y: 290 },
    { time: 70, x: 280, y: 420 }, { time: 95, x: 650, y: 480 },
    { time: 105, x: 630, y: 570 }, { time: 130, x: 260, y: 510 },
    { time: 140, x: 250, y: 610 }, { time: 150, x: 600, y: 670 },
  ],
  findings: [
    { id: 'F01', title: 'Uneven vegetation', layer: 'coverage', status: 'Example observation', time: 19, x: 590, y: 260, tone: 'teal', description: 'A lighter patch interrupts the surrounding vegetation. This sample illustrates how a coverage finding will appear.', action: 'Walk the patch and compare plant cover with the surrounding area.' },
    { id: 'F02', title: 'Possible wet patch', layer: 'moisture', status: 'Example estimate', time: 34, x: 670, y: 340, tone: 'amber', description: 'A darker area could be worth checking for standing water. Moisture has not been measured; this is an illustrative finding.', action: 'Check the ground for standing water and drainage issues.' },
    { id: 'F03', title: 'Exposed ground', layer: 'coverage', status: 'Example observation', time: 57, x: 345, y: 300, tone: 'teal', description: 'An example of a small area with less visible vegetation. This does not identify the cause of reduced cover.', action: 'Inspect the exposed ground and record what you find.' },
    { id: 'F04', title: 'Unusual colour pattern', layer: 'anomalies', status: 'Example observation', time: 89, x: 560, y: 465, tone: 'amber', description: 'A visual difference from the surrounding field is marked for inspection. No disease or nutrient diagnosis is implied.', action: 'Compare plants inside and outside the marked area.' },
    { id: 'F05', title: 'Sparse field edge', layer: 'coverage', status: 'Example observation', time: 128, x: 290, y: 515, tone: 'teal', description: 'This sample shows how sparse vegetation along an edge could be recorded during a survey.', action: 'Check whether the edge is a track, headland, or unexpected gap.' },
    { id: 'F06', title: 'Dark ground variation', layer: 'anomalies', status: 'Example observation', time: 148, x: 555, y: 660, tone: 'amber', description: 'An example ground-colour variation for a person to review. Its cause and soil properties remain unknown.', action: 'Inspect the area before deciding whether to take a soil sample.' },
  ],
};
