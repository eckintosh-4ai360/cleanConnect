// fleetTrail.js — turns a rider's GPS pings into what an admin needs to judge
// how a company bike was used: which stretches were for pickups, which were
// not, what happened while the rider was off duty, and where the signal went
// quiet.
//
// Pings come from rider_location_pings (see update_rider_location): a point
// every 30 m+ while moving (at most every 15 s) and every 2 minutes while
// parked, each tagged with the pickup in progress and the rider's status.

import { serverNow } from './timezone';

/** A silence longer than this is a signal gap, not a parked bike. */
export const GAP_MINUTES = 10;

/** Non-pickup travel shorter than this is GPS noise or moving around a yard. */
export const FLAG_MIN_KM = 0.3;

export const TRAIL_COLORS = {
  pickup: '#10b981',
  unassigned: '#f59e0b',
  offduty: '#ef4444',
  gap: '#94a3b8',
};

export const TRAIL_LABELS = {
  pickup: 'On a pickup',
  unassigned: 'On duty, no pickup',
  offduty: 'Off duty',
  gap: 'No signal',
};

const OFF_DUTY_STATUSES = new Set(['offline', 'disabled', 'pending_approval']);

export function haversineKm(a, b) {
  const toRad = (deg) => (deg * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

export function pingCategory(ping) {
  if (ping.pickup_request_id) return 'pickup';
  if (OFF_DUTY_STATUSES.has(ping.rider_status)) return 'offduty';
  return 'unassigned';
}

/**
 * @param {Array} pings rider_location_pings rows, any order
 * @returns {{ points, segments, stats, flags }}
 */
export function analyzeTrail(pings) {
  const points = (pings || [])
    .map((p) => ({
      lat: Number(p.lat),
      lng: Number(p.lng),
      at: new Date(p.recorded_at),
      category: p.category || pingCategory(p),
      pickupId: p.pickup_request_id || null,
      vehicleId: p.vehicle_id || null,
      riderId: p.rider_id || null,
    }))
    .filter((p) => Number.isFinite(p.lat) && Number.isFinite(p.lng) && !Number.isNaN(p.at.getTime()))
    .sort((a, b) => a.at - b.at);

  const stats = {
    totalKm: 0,
    pickupKm: 0,
    unassignedKm: 0,
    offdutyKm: 0,
    gapCount: 0,
    longestGapMinutes: 0,
    untrackedKm: 0,
  };
  const segments = [];
  let current = null;

  const close = () => {
    if (current && current.path.length > 1) segments.push(current);
    current = null;
  };

  for (let i = 1; i < points.length; i++) {
    const a = points[i - 1];
    const b = points[i];
    const minutes = (b.at - a.at) / 60000;
    const km = haversineKm(a, b);

    if (minutes > GAP_MINUTES) {
      close();
      segments.push({ category: 'gap', path: [a, b], startAt: a.at, endAt: b.at, km, minutes });
      stats.gapCount += 1;
      stats.longestGapMinutes = Math.max(stats.longestGapMinutes, minutes);
      if (km >= FLAG_MIN_KM) stats.untrackedKm += km;
      continue;
    }

    // A leg belongs to what the rider was doing when it ended.
    const category = b.category;
    if (!current || current.category !== category) {
      close();
      current = { category, path: [a], startAt: a.at, endAt: a.at, km: 0 };
    }
    current.path.push(b);
    current.endAt = b.at;
    current.km += km;

    stats.totalKm += km;
    stats[`${category}Km`] += km;
  }
  close();

  const flags = segments
    .filter((s) => (s.category === 'gap' ? true : s.category !== 'pickup' && s.km >= FLAG_MIN_KM))
    .map((s) => ({
      kind: s.category,
      startAt: s.startAt,
      endAt: s.endAt,
      km: s.km,
      minutes: (s.endAt - s.startAt) / 60000,
      path: s.path,
    }));

  return { points, segments, stats, flags };
}

// ── Ghana calendar days (Africa/Accra is UTC+0, no daylight saving) ─────────

/** "2026-09-15" for today in Ghana, from the server-corrected clock. */
export function ghanaToday() {
  return new Date(serverNow()).toISOString().slice(0, 10);
}

/** [start, end) of a Ghana calendar day given as "YYYY-MM-DD". */
export function ghanaDayRange(day) {
  const [y, m, d] = day.split('-').map(Number);
  const start = new Date(Date.UTC(y, m - 1, d));
  return [start, new Date(start.getTime() + 24 * 60 * 60 * 1000)];
}

export function formatKm(km) {
  if (!km) return '0 km';
  return km < 1 ? `${Math.round(km * 1000)} m` : `${km.toFixed(1)} km`;
}

export function formatMinutes(minutes) {
  const total = Math.round(minutes);
  if (total < 60) return `${total} min`;
  const h = Math.floor(total / 60);
  const m = total % 60;
  return m ? `${h} h ${m} min` : `${h} h`;
}
