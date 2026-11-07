const METRES_PER_DEGREE = 111320;

export function areaBounds(area) {
  const corners = [area.topLeft, area.topRight, area.bottomLeft, area.bottomRight];
  return {
    west: Math.min(...corners.map(p => p.longitude)),
    east: Math.max(...corners.map(p => p.longitude)),
    south: Math.min(...corners.map(p => p.latitude)),
    north: Math.max(...corners.map(p => p.latitude)),
  };
}
const inside = (bounds, point) =>
  Boolean(point) &&
  point.longitude >= bounds.west &&
  point.longitude <= bounds.east &&
  point.latitude >= bounds.south &&
  point.latitude <= bounds.north;
const clamp = (value, low, high) => Math.max(low, Math.min(high, value));

export function createFlight(area) {
  return {
    latitude: area.center.latitude,
    longitude: area.center.longitude,
    heading: null,
    pitch: 0,
    roll: 0,
    mode: 'hover',
    anchor: null,
    bounds: areaBounds(area),
  };
}

export function stepFlight(flight, sample, dt) {
  const attitude = sample?.orientation;
  const live = Boolean(attitude) && [attitude.headingDeg, attitude.pitchDeg, attitude.rollDeg].every(Number.isFinite);
  if (live) {
    const k = 1 - Math.exp(-dt / 0.25);
    flight.heading ??= attitude.headingDeg;
    flight.heading = (flight.heading + (((attitude.headingDeg - flight.heading + 540) % 360) - 180) * k + 360) % 360;
    flight.pitch += (attitude.pitchDeg - flight.pitch) * k;
    flight.roll += (attitude.rollDeg - flight.roll) * k;
  }
  const b = flight.bounds,
    fix = sample?.location;
  const metresPerLon = METRES_PER_DEGREE * Math.cos((flight.latitude * Math.PI) / 180);
  if (fix) {
    let target;
    if (inside(b, fix)) {
      flight.mode = 'gps';
      flight.anchor = null;
      target = fix;
    } else {
      flight.mode = 'gps-relative';
      flight.anchor ??= {
        latitude: fix.latitude,
        longitude: fix.longitude,
        startLatitude: flight.latitude,
        startLongitude: flight.longitude,
      };
      const north = (fix.latitude - flight.anchor.latitude) * METRES_PER_DEGREE;
      const east =
        (fix.longitude - flight.anchor.longitude) * METRES_PER_DEGREE * Math.cos((fix.latitude * Math.PI) / 180);
      target = {
        latitude: flight.anchor.startLatitude + north / METRES_PER_DEGREE,
        longitude: flight.anchor.startLongitude + east / metresPerLon,
      };
    }
    const k = 1 - Math.exp(-dt / 0.8);
    flight.latitude += (target.latitude - flight.latitude) * k;
    flight.longitude += (target.longitude - flight.longitude) * k;
  } else flight.mode = 'hover';
  flight.latitude = clamp(flight.latitude, b.south, b.north);
  flight.longitude = clamp(flight.longitude, b.west, b.east);
  const heading = flight.heading ?? 0,
    h = (heading * Math.PI) / 180;
  return {
    center: [
      flight.longitude + (80 * Math.sin(h)) / metresPerLon,
      flight.latitude + (80 * Math.cos(h)) / METRES_PER_DEGREE,
    ],
    bearing: heading,
    pitch: clamp(60 - flight.pitch * 0.3, 40, 68),
    zoom: 16.4,
    roll: flight.roll * 0.4,
  };
}

export const flightModeText = {
  gps: 'Moving with phone GPS inside the survey area',
  'gps-relative': 'Phone GPS movement mapped onto the scene from its centre (illustrative position)',
  hover: 'No GPS fix yet: the drone hovers over the scene centre and turns with the phone',
};
