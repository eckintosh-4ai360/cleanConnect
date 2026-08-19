import React, { useState, useEffect, useMemo, useRef } from 'react';
import {
  APIProvider,
  Map,
  AdvancedMarker,
  Polyline,
  useMap,
  useMapsLibrary,
} from '@vis.gl/react-google-maps';
import { supabase } from '../supabase';

const MAPS_API_KEY = import.meta.env.VITE_GOOGLE_MAPS_API_KEY || '';
const MAP_ID = import.meta.env.VITE_GOOGLE_MAPS_MAP_ID || 'DEMO_MAP_ID';

// Accra — opening camera position, replaced as soon as any rider reports a fix.
const FALLBACK_CENTER = { lat: 5.6037, lng: -0.187 };

// ── Trip-estimate helpers ────────────────────────────────────────────────────
// Rider positions come from real riders.current_lat/current_lng GPS fields.
// Distance/ETA start from haversine + reported speed (cheap, computed for
// every rider on every render) and get upgraded to a real driving route via
// the Directions API for whichever rider is currently selected — see
// useDrivingRoute below. That mirrors the mobile app's DirectionsService,
// which also only fetches a real route for the trip actually on screen.

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
    lat: (rider.currentLat ?? FALLBACK_CENTER.lat) + latOffset,
    lng: (rider.currentLng ?? FALLBACK_CENTER.lng) + lngOffset,
  };
}

function trafficForSpeed(speedKmh) {
  if (speedKmh == null || speedKmh <= 1) {
    return { label: 'Stopped', color: 'var(--color-danger)', hex: '#ef4444', bg: 'rgba(239, 68, 68, 0.12)', crawlKmh: 4 };
  }
  if (speedKmh < 15) {
    return { label: 'Heavy traffic', color: 'var(--color-danger)', hex: '#ef4444', bg: 'rgba(239, 68, 68, 0.12)', crawlKmh: speedKmh };
  }
  if (speedKmh < 28) {
    return { label: 'Moderate traffic', color: 'var(--color-accent)', hex: '#f59e0b', bg: 'rgba(245, 158, 11, 0.12)', crawlKmh: speedKmh };
  }
  return { label: 'Light traffic', color: 'var(--color-success)', hex: '#10b981', bg: 'rgba(16, 185, 129, 0.12)', crawlKmh: speedKmh };
}

function findAssignedPickup(riderId, pickupRequests) {
  return pickupRequests.find(
    (p) =>
      p.assignedRiderId === riderId &&
      ['accepted', 'confirmed', 'in_progress'].includes(p.status)
  );
}

function tripEstimate(rider, pickupRequests) {
  const lat = rider.currentLat ?? FALLBACK_CENTER.lat;
  const lng = rider.currentLng ?? FALLBACK_CENTER.lng;
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

export default function Routes() {
  const [riders, setRiders] = useState([]);
  const [pickupRequests, setPickupRequests] = useState([]);
  const [selectedRider, setSelectedRider] = useState(null);
  const [loading, setLoading] = useState(true);
  const [showOptimizeModal, setShowOptimizeModal] = useState(false);

  // Fallback initial riders if Supabase returns nothing (e.g. dev DB with no
  // riders yet) so the page still demonstrates the layout.
  const mockRiders = useMemo(
    () => [
      {
        id: 'rider-01',
        fullName: 'Kofi Mensah',
        status: 'active',
        currentLat: 5.608,
        currentLng: -0.182,
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
        currentLat: 5.615,
        currentLng: -0.176,
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
        currentLat: 5.599,
        currentLng: -0.191,
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
      currentLng: r.current_lng ?? -0.187,
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

  // Straight-line distance/ETA per rider, recomputed whenever riders or
  // pickup assignments change. Cheap enough to run for the whole fleet; the
  // real driving route (below) is only ever fetched for the selected rider.
  const riderTrips = useMemo(() => {
    const map = {};
    riders.forEach((r) => {
      map[r.id] = tripEstimate(r, pickupRequests);
    });
    return map;
  }, [riders, pickupRequests]);

  const selectedTrip = selectedRider ? riderTrips[selectedRider.id] : null;

  const selectedOrigin = selectedRider
    ? { lat: selectedRider.currentLat ?? FALLBACK_CENTER.lat, lng: selectedRider.currentLng ?? FALLBACK_CENTER.lng }
    : null;
  const selectedDestination = selectedTrip?.targetCoord ?? null;

  // Populated by RouteOverlay, which calls useMapsLibrary('routes') — that
  // hook only works inside the <APIProvider> tree, so the fetch itself has
  // to live in a component rendered inside <Map>, not here. RouteOverlay
  // reports back up through this setter (referentially stable, so it is
  // safe as an effect dependency there).
  const [driving, setDriving] = useState(EMPTY_ROUTE);

  // Real routed numbers win once the Directions API answers; until then (or
  // if it errors — no key, quota, no road route) the haversine estimate above
  // keeps the card populated instead of showing nothing.
  const displayDistanceKm = driving.distanceKm ?? selectedTrip?.distanceKm ?? null;
  const displayEtaMins = driving.etaMins ?? selectedTrip?.etaMins ?? null;

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
        {/* Left: Real Google Map */}
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
            {!MAPS_API_KEY ? (
              <MissingKeyNotice />
            ) : loading ? (
              <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-secondary)', fontSize: '13px' }}>
                Loading map…
              </div>
            ) : (
              <APIProvider apiKey={MAPS_API_KEY}>
                <Map
                  mapId={MAP_ID}
                  defaultCenter={
                    riders.length > 0
                      ? { lat: riders[0].currentLat ?? FALLBACK_CENTER.lat, lng: riders[0].currentLng ?? FALLBACK_CENTER.lng }
                      : FALLBACK_CENTER
                  }
                  defaultZoom={13}
                  gestureHandling="greedy"
                  disableDefaultUI={false}
                  mapTypeControl={false}
                  streetViewControl={false}
                  fullscreenControl={false}
                  zoomControl={true}
                  style={{ width: '100%', height: '100%' }}
                >
                  <FitBounds riders={riders} />

                  {selectedRider && selectedTrip && (
                    <RouteOverlay
                      origin={selectedOrigin}
                      destination={selectedDestination}
                      color={selectedTrip.traffic.hex}
                      label={selectedTrip.targetLabel}
                      onRouteUpdate={setDriving}
                    />
                  )}

                  {riders.map((r) => (
                    <AdvancedMarker
                      key={r.id}
                      position={{ lat: r.currentLat ?? FALLBACK_CENTER.lat, lng: r.currentLng ?? FALLBACK_CENTER.lng }}
                      onClick={() => setSelectedRider(r)}
                      title={r.fullName}
                    >
                      <RiderPin rider={r} isSelected={selectedRider?.id === r.id} />
                    </AdvancedMarker>
                  ))}
                </Map>
              </APIProvider>
            )}

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
                pointerEvents: 'none',
              }}
            >
              <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--color-success)' }} />
              Live Radar: Tracking {riders.length} Active Riders
            </div>

            {/* Bottom trip card (Uber-style) for the selected rider */}
            {selectedRider && selectedTrip && (
              <div
                style={{
                  position: 'absolute',
                  left: '12px',
                  right: '12px',
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
                    {displayDistanceKm != null ? `${displayDistanceKm.toFixed(1)} km` : '—'} ·{' '}
                    {displayEtaMins != null ? `${displayEtaMins} min` : '—'}
                    {driving.isReal ? ' · driving route' : ' · straight-line est.'}
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
                        {displayDistanceKm != null ? `${displayDistanceKm.toFixed(1)} km` : '—'}
                      </p>
                    </div>
                    <div>
                      <span style={{ color: 'var(--text-muted)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 'bold' }}>Time to Complete</span>
                      <p style={{ fontSize: '15px', fontWeight: '800', color: selectedTrip.traffic.color, marginTop: '2px' }}>
                        {displayEtaMins != null ? `${displayEtaMins} min` : '—'}
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

// ── Real driving route ───────────────────────────────────────────────────────

const EMPTY_ROUTE = { path: null, distanceKm: null, etaMins: null, isReal: false };

/**
 * Fetches a real road-following route from the Directions API for one
 * origin/destination pair (the currently selected rider only — fetching this
 * for the whole fleet on every position tick would be needless Directions
 * calls). Degrades to EMPTY_ROUTE (never throws) when the 'routes' library
 * hasn't loaded yet, there is no key, or the API errors — callers fall back
 * to the haversine estimate, same pattern as the mobile app's
 * DirectionsService.
 *
 * Must be called from a component rendered inside <APIProvider> (i.e. inside
 * <Map>) — useMapsLibrary reads that context and returns null forever
 * otherwise, which silently stuck this on the straight-line fallback the
 * first time this was wired up one level too high in the tree.
 */
function useDrivingRoute(origin, destination) {
  const routesLibrary = useMapsLibrary('routes');
  const [state, setState] = useState(EMPTY_ROUTE);

  // Round to ~11m so GPS jitter doesn't re-trigger a Directions request.
  const originKey = origin ? `${origin.lat.toFixed(4)},${origin.lng.toFixed(4)}` : null;
  const destKey = destination ? `${destination.lat.toFixed(4)},${destination.lng.toFixed(4)}` : null;

  useEffect(() => {
    if (!routesLibrary || !origin || !destination) {
      setState(EMPTY_ROUTE);
      return;
    }

    // Clear any previous rider's route immediately rather than leaving it on
    // screen until the new one resolves.
    setState(EMPTY_ROUTE);

    let cancelled = false;
    const service = new routesLibrary.DirectionsService();

    service
      .route({
        origin,
        destination,
        travelMode: window.google.maps.TravelMode.DRIVING,
      })
      .then((result) => {
        if (cancelled) return;
        const route = result.routes?.[0];
        const leg = route?.legs?.[0];
        if (!route || !leg) {
          setState(EMPTY_ROUTE);
          return;
        }
        setState({
          path: route.overview_path.map((p) => ({ lat: p.lat(), lng: p.lng() })),
          distanceKm: leg.distance ? leg.distance.value / 1000 : null,
          etaMins: leg.duration ? Math.max(1, Math.round(leg.duration.value / 60)) : null,
          isReal: true,
        });
      })
      .catch((e) => {
        if (cancelled) return;
        console.warn('Directions request failed, falling back to straight-line estimate:', e);
        setState(EMPTY_ROUTE);
      });

    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [routesLibrary, originKey, destKey]);

  return state;
}

// Standard Google Maps dashed-line recipe: hide the solid stroke and draw a
// repeating line symbol along the path instead.
const DASHED_LINE_ICON = [
  { icon: { path: 'M 0,-1 0,1', strokeOpacity: 1, scale: 3 }, offset: '0', repeat: '14px' },
];

/**
 * Route polyline + destination pin for the selected rider's trip. Owns the
 * Directions fetch itself (via useDrivingRoute) since this is the component
 * actually rendered inside <Map>, and reports the result back up to the
 * parent panel/roster through onRouteUpdate.
 */
function RouteOverlay({ origin, destination, color, label, onRouteUpdate }) {
  const driving = useDrivingRoute(origin, destination);

  useEffect(() => {
    onRouteUpdate(driving);
  }, [driving, onRouteUpdate]);

  const linePath = driving.path ?? (origin && destination ? [origin, destination] : null);
  // A real road-following route is drawn solid; the straight-line fallback
  // used while it loads (or if Directions errors) is drawn dashed so it
  // never reads as an actual road-following path.
  const polylineProps = driving.path
    ? { strokeOpacity: 0.95 }
    : { strokeOpacity: 0, icons: DASHED_LINE_ICON };

  return (
    <>
      {linePath && (
        <Polyline path={linePath} strokeColor={color} strokeWeight={5} {...polylineProps} />
      )}
      {destination && <AdvancedMarker position={destination}><DestinationPin label={label} /></AdvancedMarker>}
    </>
  );
}

/**
 * Frames every rider once on load, then steps back so an admin who has
 * zoomed into one neighbourhood is not yanked out every time a marker moves.
 */
function FitBounds({ riders }) {
  const map = useMap();
  const hasFitted = useRef(false);

  useEffect(() => {
    if (!map || riders.length === 0 || hasFitted.current) return;
    hasFitted.current = true;

    if (riders.length === 1) {
      map.setCenter({ lat: riders[0].currentLat ?? FALLBACK_CENTER.lat, lng: riders[0].currentLng ?? FALLBACK_CENTER.lng });
      map.setZoom(14);
      return;
    }

    const bounds = new window.google.maps.LatLngBounds();
    riders.forEach((r) => bounds.extend({ lat: r.currentLat ?? FALLBACK_CENTER.lat, lng: r.currentLng ?? FALLBACK_CENTER.lng }));
    map.fitBounds(bounds, 64);
  }, [map, riders]);

  return null;
}

function RiderPin({ rider, isSelected }) {
  const moving = (rider.speed ?? 0) > 0;
  const color = isSelected ? '#2563eb' : moving ? '#f59e0b' : '#94a3b8';

  return (
    <div style={{ position: 'relative', transform: isSelected ? 'scale(1.15)' : 'scale(1)', transition: 'transform 0.2s ease' }}>
      <div
        style={{
          width: '30px',
          height: '30px',
          borderRadius: '50%',
          background: color,
          border: '3px solid #fff',
          boxShadow: '0 3px 10px rgba(0,0,0,0.28)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: '#fff',
        }}
      >
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="currentColor"
          style={{ transform: `rotate(${rider.heading || 0}deg)`, transition: 'transform 0.6s ease' }}
        >
          <path d="M12 2 L19 21 L12 17 L5 21 Z" />
        </svg>
      </div>
      {moving && (
        <span
          style={{
            position: 'absolute',
            inset: '-6px',
            borderRadius: '50%',
            border: `2px solid ${color}`,
            opacity: 0.35,
            pointerEvents: 'none',
          }}
        />
      )}
    </div>
  );
}

function DestinationPin({ label }) {
  const shortLabel = label && label.length > 18 ? `${label.slice(0, 17)}…` : label;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', transform: 'translateY(-10px)' }}>
      <div
        style={{
          width: '26px',
          height: '26px',
          borderRadius: '50% 50% 50% 0',
          background: '#ef4444',
          border: '2px solid #fff',
          transform: 'rotate(-45deg)',
          boxShadow: '0 3px 8px rgba(0,0,0,0.3)',
        }}
      />
      {shortLabel && (
        <span
          style={{
            marginTop: '4px',
            background: 'rgba(15,23,42,0.85)',
            color: '#fff',
            fontSize: '10px',
            fontWeight: 'bold',
            padding: '3px 8px',
            borderRadius: '8px',
            whiteSpace: 'nowrap',
          }}
        >
          {shortLabel}
        </span>
      )}
    </div>
  );
}

function MissingKeyNotice() {
  return (
    <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '32px', background: 'var(--bg-card)' }}>
      <div style={{ maxWidth: '420px', textAlign: 'center' }}>
        <h4 style={{ fontSize: '15px', marginBottom: '10px' }}>Google Maps key not configured</h4>
        <p style={{ color: 'var(--text-secondary)', fontSize: '12.5px', lineHeight: 1.6 }}>
          Create <code>admin_panel/.env.local</code> with a browser key that has the{' '}
          <strong>Maps JavaScript API</strong> and <strong>Directions API</strong> enabled, then
          restart the dev server:
        </p>
        <pre
          style={{
            background: 'var(--bg-app)',
            border: '1px solid var(--border-divider)',
            borderRadius: 'var(--border-radius-sm)',
            padding: '10px 14px',
            fontSize: '11.5px',
            margin: '12px 0',
            textAlign: 'left',
            overflowX: 'auto',
          }}
        >
          VITE_GOOGLE_MAPS_API_KEY=AIza...
        </pre>
      </div>
    </div>
  );
}
