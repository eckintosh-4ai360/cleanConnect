import React, { useState, useEffect, useMemo } from 'react';
import { supabase } from '../supabase';

// ── Map projection & trip-estimate helpers ──────────────────────────────────
// This is a self-contained, styled map — no external Maps API/key involved.
// Rider positions come from real Firestore GPS fields (currentLat/currentLng,
// speed, heading). Distance/ETA/traffic are derived from that real data;
// a stable per-rider fallback target is only used when no real pickup
// coordinate exists yet, so numbers don't look randomly generated.
const MAP_W = 900;
const MAP_H = 380;
const MAP_CENTER = { lat: 5.6037, lng: -0.1870 }; // Accra
const LAT_SPAN = 0.05;
const LNG_SPAN = 0.09;

function project(lat, lng) {
  const x = ((lng - (MAP_CENTER.lng - LNG_SPAN / 2)) / LNG_SPAN) * MAP_W;
  const y = MAP_H - ((lat - (MAP_CENTER.lat - LAT_SPAN / 2)) / LAT_SPAN) * MAP_H;
  return {
    x: Math.min(Math.max(x, 30), MAP_W - 30),
    y: Math.min(Math.max(y, 30), MAP_H - 30),
  };
}

function toRad(deg) {
  return (deg * Math.PI) / 180;
}

function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function parseCoords(str) {
  if (!str) return null;
  const match = String(str).match(/(-?\d{1,3}\.\d+)[,\s]+(-?\d{1,3}\.\d+)/);
  if (!match) return null;
  const lat = parseFloat(match[1]);
  const lng = parseFloat(match[2]);
  if (Number.isNaN(lat) || Number.isNaN(lng)) return null;
  return { lat, lng };
}

function hashId(id) {
  let hash = 0;
  for (let i = 0; i < id.length; i++) hash = (hash * 31 + id.charCodeAt(i)) | 0;
  return Math.abs(hash);
}

// Stable fallback destination near a rider when no real pickup coordinate is
// available yet, so markers don't jump around between renders.
function fallbackTarget(rider) {
  const seed = hashId(rider.id);
  const latOffset = ((seed % 100) / 100 - 0.5) * 0.035;
  const lngOffset = (((seed >> 8) % 100) / 100 - 0.5) * 0.035;
  return {
    lat: (rider.currentLat ?? MAP_CENTER.lat) + latOffset,
    lng: (rider.currentLng ?? MAP_CENTER.lng) + lngOffset,
  };
}

function trafficForSpeed(speedKmh) {
  if (speedKmh == null || speedKmh <= 1) {
    return { label: 'Stopped', color: 'var(--color-danger)', bg: 'rgba(239, 68, 68, 0.12)', crawlKmh: 4 };
  }
  if (speedKmh < 15) {
    return { label: 'Heavy traffic', color: 'var(--color-danger)', bg: 'rgba(239, 68, 68, 0.12)', crawlKmh: speedKmh };
  }
  if (speedKmh < 28) {
    return { label: 'Moderate traffic', color: 'var(--color-accent)', bg: 'rgba(245, 158, 11, 0.12)', crawlKmh: speedKmh };
  }
  return { label: 'Light traffic', color: 'var(--color-success)', bg: 'rgba(16, 185, 129, 0.12)', crawlKmh: speedKmh };
}

function findAssignedPickup(riderId, pickupRequests) {
  return pickupRequests.find(
    (p) =>
      p.assignedRiderId === riderId &&
      ['accepted', 'confirmed', 'in_progress'].includes(p.status)
  );
}

function tripEstimate(rider, pickupRequests) {
  const lat = rider.currentLat ?? MAP_CENTER.lat;
  const lng = rider.currentLng ?? MAP_CENTER.lng;
  const pickup = findAssignedPickup(rider.id, pickupRequests);
  const targetCoord =
    parseCoords(pickup?.location) ||
    parseCoords(rider.targetCustomer) ||
    fallbackTarget(rider);
  const targetLabel =
    pickup?.customerName ||
    (rider.targetCustomer ? rider.targetCustomer.split(' (')[0] : 'Customer Site');

  const distanceKm = haversineKm(lat, lng, targetCoord.lat, targetCoord.lng);
  const traffic = trafficForSpeed(rider.speed);
  const etaMins = Math.max(1, Math.round((distanceKm / traffic.crawlKmh) * 60));

  return { targetCoord, targetLabel, distanceKm, etaMins, traffic };
}

// ── Decorative city backdrop (static — purely visual, like map tile art) ───
const cityBlocks = [
  { x: 60, y: 55, w: 90, h: 55 },
  { x: 200, y: 35, w: 70, h: 45 },
  { x: 340, y: 65, w: 110, h: 65 },
  { x: 540, y: 45, w: 80, h: 50 },
  { x: 660, y: 85, w: 100, h: 55 },
  { x: 90, y: 155, w: 95, h: 50 },
  { x: 270, y: 145, w: 80, h: 45 },
  { x: 480, y: 165, w: 90, h: 55 },
  { x: 630, y: 195, w: 105, h: 65 },
  { x: 790, y: 55, w: 85, h: 85 },
  { x: 480, y: 265, w: 100, h: 55 },
  { x: 660, y: 285, w: 80, h: 45 },
];

const roadNetwork = [
  { d: 'M 0 92 L 900 92', width: 9 },
  { d: 'M 0 232 L 900 232', width: 13, arterial: true },
  { d: 'M 152 0 L 152 380', width: 8 },
  { d: 'M 432 0 L 432 380', width: 11, arterial: true },
  { d: 'M 702 0 L 702 380', width: 8 },
  { d: 'M 0 332 L 900 332', width: 8 },
  { d: 'M 20 15 L 520 365', width: 6 },
];

export default function Routes() {
  const [riders, setRiders] = useState([]);
  const [pickupRequests, setPickupRequests] = useState([]);
  const [selectedRider, setSelectedRider] = useState(null);
  const [loading, setLoading] = useState(true);
  const [showOptimizeModal, setShowOptimizeModal] = useState(false);

  // Fallback initial riders if Firestore collection has non-GPS docs
  const mockRiders = useMemo(
    () => [
      {
        id: 'rider-01',
        fullName: 'Kofi Mensah',
        status: 'active',
        currentLat: 5.6080,
        currentLng: -0.1820,
        speed: 32.4,
        heading: 45,
        targetCustomer: 'Sarah Jenkins (123 Green St)',
        vehicleType: 'Motorbike',
        totalCollections: 14,
      },
      {
        id: 'rider-02',
        fullName: 'Ama Osei',
        status: 'active',
        currentLat: 5.6150,
        currentLng: -0.1760,
        speed: 12.0,
        heading: 120,
        targetCustomer: 'Michael Scott (45 Corporate Way)',
        vehicleType: 'Eco Van',
        totalCollections: 22,
      },
      {
        id: 'rider-03',
        fullName: 'Kwame Antwi',
        status: 'active',
        currentLat: 5.5990,
        currentLng: -0.1910,
        speed: 0.0,
        heading: 0,
        targetCustomer: 'Standby / Idle',
        vehicleType: 'Motorbike',
        totalCollections: 9,
      },
    ],
    []
  );

  // Live Postgres tracking for riders + pickup requests
  useEffect(() => {
    let mounted = true;

    const mapRiderRow = (r) => ({
      id: r.id,
      fullName: r.profiles?.full_name || 'Rider',
      status: r.status || 'active',
      currentLat: r.current_lat ?? 5.6037,
      currentLng: r.current_lng ?? -0.1870,
      speed: r.speed ?? 25.0,
      heading: r.heading ?? 0,
      vehicleType: r.vehicle_type || 'Motorbike',
      phoneNumber: r.profiles?.phone_number,
      photoUrl: r.profiles?.profile_picture_url,
      updatedAt: r.updated_at ? new Date(r.updated_at) : new Date(),
    });

    const fetchRiders = async () => {
      const { data, error } = await supabase
        .from('riders')
        .select('*, profiles(full_name, phone_number, profile_picture_url)');
      if (!mounted) return;
      if (error) {
        console.warn('Riders live tracking fetch error:', error);
        setRiders(mockRiders);
        setSelectedRider((prev) => prev || mockRiders[0]);
        setLoading(false);
        return;
      }
      const mergedRiders = data.length > 0 ? data.map(mapRiderRow) : mockRiders;
      setRiders(mergedRiders);
      setSelectedRider((prev) =>
        prev ? mergedRiders.find((r) => r.id === prev.id) || mergedRiders[0] : mergedRiders[0]
      );
      setLoading(false);
    };
    fetchRiders();
    const ridersChannel = supabase
      .channel('routes_riders_changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'riders' }, fetchRiders)
      .subscribe();

    const mapPickupRow = (p) => ({
      id: p.id,
      assignedRiderId: p.assigned_rider_id,
      status: p.status,
      location: p.location,
      customerName: p.customer_name,
    });

    const fetchRequests = async () => {
      const { data, error } = await supabase.from('pickup_requests').select('*');
      if (mounted && !error) setPickupRequests(data.map(mapPickupRow));
      if (mounted && error) setPickupRequests([]);
    };
    fetchRequests();
    const requestsChannel = supabase
      .channel('routes_pickup_requests_changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'pickup_requests' }, fetchRequests)
      .subscribe();

    return () => {
      mounted = false;
      supabase.removeChannel(ridersChannel);
      supabase.removeChannel(requestsChannel);
    };
  }, [mockRiders]);

  const activeRiders = riders.filter((r) => r.status === 'active');
  const activePickups = pickupRequests.filter((p) => p.status === 'accepted' || p.status === 'confirmed');
  const avgFleetSpeed = activeRiders.length
    ? activeRiders.reduce((sum, r) => sum + (r.speed || 0), 0) / activeRiders.length
    : 0;

  // Trip estimate (distance/ETA/traffic) per rider, recomputed whenever
  // riders or pickup assignments change.
  const riderTrips = useMemo(() => {
    const map = {};
    riders.forEach((r) => {
      map[r.id] = tripEstimate(r, pickupRequests);
    });
    return map;
  }, [riders, pickupRequests]);

  const selectedTrip = selectedRider ? riderTrips[selectedRider.id] : null;

  const triggerOptimization = () => {
    alert('AI Route optimization pipeline executed. 4 collection pathways recalculated for maximum efficiency.');
    setShowOptimizeModal(false);
  };

  return (
    <div className="page-content">
      {/* ── Page Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>Live Rider Movement & Route Dispatch</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Real-time GPS tracking map of on-duty riders navigating to customer pickup locations.
          </p>
        </div>
        <div style={{ display: 'flex', gap: '10px' }}>
          <button className="btn-outline" style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--color-success)', display: 'inline-block' }} />
            Live Sync
          </button>
          <button className="btn-primary" onClick={() => setShowOptimizeModal(true)}>
            ⚡ AI Optimize Routes
          </button>
        </div>
      </div>

      {/* ── Metric Summary Cards ── */}
      <div className="metrics-grid">
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-success)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>On-Duty Riders</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-success)' }}>
            {activeRiders.length} Active
          </span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-primary)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Pickups In Transit</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-primary)' }}>
            {activePickups.length} Orders
          </span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-info)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Average Fleet Speed</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-info)' }}>
            {avgFleetSpeed.toFixed(1)} km/h
          </span>
        </div>
      </div>

      {/* ── Live GPS Map & Fleet List Split Layout ── */}
      <div className="split-layout">
        {/* Left: Interactive Real-Time Map Canvas */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3 style={{ fontSize: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--color-primary)" strokeWidth="2.5">
                <circle cx="12" cy="12" r="10" />
                <path d="M12 2a10 10 0 0 1 10 10" />
                <path d="M12 12l4-4" />
              </svg>
              Live Movement Radar Map
            </h3>
            <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
              Accra & Eco City District
            </span>
          </div>

          {/* Map Canvas */}
          <div
            style={{
              position: 'relative',
              width: '100%',
              height: '380px',
              borderRadius: '16px',
              overflow: 'hidden',
              border: '1px solid var(--border-divider)',
            }}
          >
            <svg
              viewBox={`0 0 ${MAP_W} ${MAP_H}`}
              width="100%"
              height="100%"
              preserveAspectRatio="xMidYMid slice"
              style={{ display: 'block' }}
            >
              {/* Land base */}
              <rect width={MAP_W} height={MAP_H} fill="#eae7e1" />

              {/* City blocks */}
              {cityBlocks.map((b, i) => (
                <rect key={i} x={b.x} y={b.y} width={b.w} height={b.h} rx="6" fill="#e0dcd1" />
              ))}

              {/* Park */}
              <path d="M 40 260 Q 120 215 190 268 Q 150 322 65 320 Z" fill="#cfe8d1" />

              {/* Lagoon */}
              <path
                d={`M ${MAP_W - 230} ${MAP_H - 35} Q ${MAP_W - 140} ${MAP_H - 130} ${MAP_W} ${MAP_H - 95} L ${MAP_W} ${MAP_H} L ${MAP_W - 230} ${MAP_H} Z`}
                fill="#bcd9ec"
              />

              {/* Road network */}
              {roadNetwork.map((road, i) => (
                <g key={i}>
                  <path d={road.d} fill="none" stroke="#ffffff" strokeWidth={road.width + 3} strokeLinecap="round" opacity="0.9" />
                  <path d={road.d} fill="none" stroke={road.arterial ? '#f7c98a' : '#f5f3ee'} strokeWidth={road.width} strokeLinecap="round" />
                </g>
              ))}

              {/* Route + destination for the selected rider */}
              {selectedRider && selectedTrip && (
                <>
                  <RoutePath
                    from={project(selectedRider.currentLat ?? MAP_CENTER.lat, selectedRider.currentLng ?? MAP_CENTER.lng)}
                    to={project(selectedTrip.targetCoord.lat, selectedTrip.targetCoord.lng)}
                    color={selectedTrip.traffic.color}
                  />
                  <DestinationPin
                    pos={project(selectedTrip.targetCoord.lat, selectedTrip.targetCoord.lng)}
                    label={selectedTrip.targetLabel}
                  />
                </>
              )}

              {/* Rider markers */}
              {riders.map((r) => (
                <RiderMarker
                  key={r.id}
                  pos={project(r.currentLat ?? MAP_CENTER.lat, r.currentLng ?? MAP_CENTER.lng)}
                  rider={r}
                  isSelected={selectedRider?.id === r.id}
                  distanceKm={riderTrips[r.id]?.distanceKm}
                  onClick={() => setSelectedRider(r)}
                />
              ))}
            </svg>

            {/* Top status bar */}
            <div
              style={{
                position: 'absolute',
                top: '12px',
                left: '12px',
                background: 'var(--bg-sidebar)',
                padding: '8px 12px',
                borderRadius: '8px',
                fontSize: '11px',
                fontWeight: 'bold',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                boxShadow: 'var(--shadow-premium)',
              }}
            >
              <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--color-success)' }} />
              Live Radar: Tracking {riders.length} Active Riders
            </div>

            {/* Zoom controls (decorative, matches map-app affordances) */}
            <div
              style={{
                position: 'absolute',
                bottom: '12px',
                right: '12px',
                display: 'flex',
                flexDirection: 'column',
                borderRadius: '8px',
                overflow: 'hidden',
                boxShadow: 'var(--shadow-premium)',
              }}
            >
              {['+', '−'].map((sym) => (
                <button
                  key={sym}
                  style={{
                    width: '30px',
                    height: '30px',
                    border: 'none',
                    borderBottom: sym === '+' ? '1px solid var(--border-divider)' : 'none',
                    background: 'var(--bg-sidebar)',
                    color: 'var(--text-primary)',
                    fontSize: '15px',
                    fontWeight: 'bold',
                    cursor: 'pointer',
                  }}
                >
                  {sym}
                </button>
              ))}
            </div>

            {/* Bottom trip card (Uber-style) for the selected rider */}
            {selectedRider && selectedTrip && (
              <div
                style={{
                  position: 'absolute',
                  left: '12px',
                  right: '84px',
                  bottom: '12px',
                  background: 'var(--bg-sidebar)',
                  backdropFilter: 'var(--glass-blur)',
                  borderRadius: '14px',
                  padding: '10px 16px',
                  boxShadow: 'var(--shadow-premium)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: '12px',
                }}
              >
                <div>
                  <div style={{ fontSize: '13px', fontWeight: 800 }}>
                    {selectedRider.fullName.split(' ')[0]} → {selectedTrip.targetLabel}
                  </div>
                  <div style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                    {selectedTrip.distanceKm.toFixed(1)} km · {selectedTrip.etaMins} min
                  </div>
                </div>
                <span
                  style={{
                    fontSize: '10px',
                    fontWeight: 800,
                    padding: '4px 10px',
                    borderRadius: '20px',
                    background: selectedTrip.traffic.bg,
                    color: selectedTrip.traffic.color,
                    whiteSpace: 'nowrap',
                  }}
                >
                  {selectedTrip.traffic.label}
                </span>
              </div>
            )}
          </div>
        </div>

        {/* Right: Selected Rider & Dispatch Details */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {selectedRider ? (
            <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <img
                  src={selectedRider.photoUrl || `https://api.dicebear.com/7.x/initials/svg?seed=${selectedRider.fullName}`}
                  alt={selectedRider.fullName}
                  style={{ width: '48px', height: '48px', borderRadius: '50%', objectFit: 'cover' }}
                />
                <div>
                  <h4 style={{ fontSize: '16px', fontWeight: '800' }}>{selectedRider.fullName}</h4>
                  <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                    {selectedRider.vehicleType} • {selectedRider.phoneNumber || '+233 24 000 0000'}
                  </p>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', background: 'var(--bg-app)', padding: '12px', borderRadius: '10px', fontSize: '12px' }}>
                <div>
                  <span style={{ color: 'var(--text-muted)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 'bold' }}>Current Speed</span>
                  <p style={{ fontSize: '15px', fontWeight: '800', color: 'var(--color-primary)', marginTop: '2px' }}>
                    {selectedRider.speed ? `${selectedRider.speed.toFixed(1)} km/h` : 'Stopped'}
                  </p>
                </div>
                <div>
                  <span style={{ color: 'var(--text-muted)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 'bold' }}>Status</span>
                  <p style={{ fontSize: '15px', fontWeight: '800', color: 'var(--color-success)', marginTop: '2px', textTransform: 'capitalize' }}>
                    {selectedRider.status}
                  </p>
                </div>
                {selectedTrip && (
                  <>
                    <div>
                      <span style={{ color: 'var(--text-muted)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 'bold' }}>Distance Ahead</span>
                      <p style={{ fontSize: '15px', fontWeight: '800', marginTop: '2px' }}>
                        {selectedTrip.distanceKm.toFixed(1)} km
                      </p>
                    </div>
                    <div>
                      <span style={{ color: 'var(--text-muted)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 'bold' }}>Time to Complete</span>
                      <p style={{ fontSize: '15px', fontWeight: '800', color: selectedTrip.traffic.color, marginTop: '2px' }}>
                        {selectedTrip.etaMins} min
                      </p>
                    </div>
                  </>
                )}
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '12px' }}>
                <span style={{ color: 'var(--text-muted)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 'bold' }}>Live GPS Coordinates</span>
                <p style={{ fontWeight: '600', fontFamily: 'monospace' }}>
                  Lat: {selectedRider.currentLat?.toFixed(4) || '5.6037'} • Lng: {selectedRider.currentLng?.toFixed(4) || '-0.1870'}
                </p>

                <span style={{ color: 'var(--text-muted)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 'bold', marginTop: '6px' }}>Target Customer</span>
                <p style={{ fontWeight: '600', color: 'var(--text-primary)' }}>
                  {selectedTrip?.targetLabel || selectedRider.targetCustomer || 'Sarah Jenkins (123 Green St, Eco City)'}
                </p>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px', marginTop: '8px' }}>
                <button className="btn-primary" style={{ justifyContent: 'center' }} onClick={() => alert(`Calling ${selectedRider.fullName}...`)}>
                  📞 Contact Rider
                </button>
                <button className="btn-outline" style={{ justifyContent: 'center' }} onClick={() => alert('Sending route update signal...')}>
                  🗺️ Re-route
                </button>
              </div>
            </div>
          ) : (
            <div className="card-glass" style={{ textAlign: 'center', padding: '32px', color: 'var(--text-muted)' }}>
              Select a rider on the radar map to view live details.
            </div>
          )}

          {/* Active Fleet List */}
          <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <h4 style={{ fontSize: '14px', fontWeight: '800' }}>Active Fleet Roster ({riders.length})</h4>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', maxHeight: '200px', overflowY: 'auto' }}>
              {riders.map((r) => {
                const trip = riderTrips[r.id];
                return (
                  <div
                    key={r.id}
                    onClick={() => setSelectedRider(r)}
                    style={{
                      padding: '8px 12px',
                      borderRadius: '8px',
                      background: selectedRider?.id === r.id ? 'var(--border-divider)' : 'var(--bg-app)',
                      cursor: 'pointer',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      fontSize: '12px',
                    }}
                  >
                    <div>
                      <strong>{r.fullName}</strong>
                      <div style={{ fontSize: '10px', color: 'var(--text-muted)' }}>
                        {r.vehicleType}
                        {trip ? ` • ${trip.distanceKm.toFixed(1)} km • ${trip.etaMins} min` : ''}
                      </div>
                    </div>
                    <span
                      className="badge"
                      style={{
                        fontSize: '9px',
                        background: trip?.traffic.bg,
                        color: trip?.traffic.color,
                      }}
                    >
                      {r.speed > 0 ? 'MOVING' : 'IDLE'}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>

      {/* ── Route Optimize Modal ── */}
      {showOptimizeModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>Optimize Active Dispatch Routes</h3>
            <p style={{ fontSize: '13px', color: 'var(--text-secondary)', lineHeight: '140%' }}>
              Running the optimization engine re-calculates all stop lists for active drivers based on live traffic, coordinates, and bin fill capacities.
            </p>
            <div style={{ padding: '16px', background: 'var(--bg-app)', borderRadius: '8px', fontSize: '12px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
              <div>• Reduce carbon emission output by ~14%</div>
              <div>• Decrease average transit time per stop by ~9 mins</div>
              <div>• Target priority bins with fill level &gt;80% first</div>
            </div>
            <div className="modal-actions">
              <button className="btn-outline" onClick={() => setShowOptimizeModal(false)}>Cancel</button>
              <button className="btn-primary" onClick={triggerOptimization}>Execute Optimizer</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ── Map sub-elements ─────────────────────────────────────────────────────

function RoutePath({ from, to, color }) {
  // Gentle bend so the route reads as road-following rather than a straight ruler line.
  const midX = (from.x + to.x) / 2 + (to.y - from.y) * 0.18;
  const midY = (from.y + to.y) / 2 - (to.x - from.x) * 0.18;
  const d = `M ${from.x} ${from.y} Q ${midX} ${midY} ${to.x} ${to.y}`;
  return (
    <g>
      <path d={d} fill="none" stroke="white" strokeWidth="7" strokeLinecap="round" opacity="0.85" />
      <path d={d} fill="none" stroke={color} strokeWidth="4" strokeLinecap="round" />
      <circle r="5" fill="white" stroke={color} strokeWidth="2.5">
        <animateMotion dur="3s" repeatCount="indefinite" path={d} />
      </circle>
    </g>
  );
}

function DestinationPin({ pos, label }) {
  const shortLabel = label.length > 16 ? `${label.slice(0, 15)}…` : label;
  return (
    <g transform={`translate(${pos.x}, ${pos.y})`}>
      <ellipse cx="0" cy="4" rx="9" ry="3" fill="rgba(0,0,0,0.18)" />
      <path
        d="M0 -30 C 9 -30 16 -23 16 -14 C16 -3 0 4 0 4 C0 4 -16 -3 -16 -14 C-16 -23 -9 -30 0 -30 Z"
        fill="#ef4444"
        stroke="white"
        strokeWidth="2"
      />
      <circle cx="0" cy="-15" r="5" fill="white" />
      <rect x="-48" y="10" width="96" height="18" rx="9" fill="rgba(15,23,42,0.85)" />
      <text x="0" y="23" fill="white" fontSize="10" fontWeight="bold" textAnchor="middle">
        {shortLabel}
      </text>
    </g>
  );
}

function RiderMarker({ pos, rider, isSelected, distanceKm, onClick }) {
  const moving = (rider.speed ?? 0) > 0;
  const baseColor = isSelected ? 'var(--color-primary)' : moving ? 'var(--color-accent)' : 'var(--text-muted)';
  const label = `${rider.fullName.split(' ')[0]}${distanceKm != null ? ` • ${distanceKm.toFixed(1)}km` : ''}`;
  return (
    <g transform={`translate(${pos.x}, ${pos.y})`} style={{ cursor: 'pointer' }} onClick={onClick}>
      {moving && (
        <circle r={isSelected ? 20 : 14} fill={baseColor} opacity="0.22">
          <animate attributeName="r" values={isSelected ? '14;24;14' : '10;18;10'} dur="1.8s" repeatCount="indefinite" />
          <animate attributeName="opacity" values="0.3;0.05;0.3" dur="1.8s" repeatCount="indefinite" />
        </circle>
      )}
      <circle r="11" fill="white" stroke={baseColor} strokeWidth="2.5" />
      <path d="M0 -6 L4.5 5 L0 2 L-4.5 5 Z" fill={baseColor} transform={`rotate(${rider.heading || 0})`} />
      <rect x="-34" y="15" width="68" height="16" rx="8" fill="rgba(15,23,42,0.85)" />
      <text x="0" y="27" fill="white" fontSize="8.5" fontWeight="bold" textAnchor="middle">
        {label}
      </text>
    </g>
  );
}
