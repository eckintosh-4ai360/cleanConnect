import React, { useState, useEffect, useMemo, useCallback, useRef } from 'react';
import { APIProvider, Map, AdvancedMarker, Polyline, useMap } from '@vis.gl/react-google-maps';
import { supabase } from '../supabase';
import { serverNow, formatDate, formatTime, formatDateTime } from '../timezone';
import {
  TRAIL_COLORS,
  TRAIL_LABELS,
  analyzeTrail,
  formatKm,
  formatMinutes,
  ghanaDayRange,
  ghanaToday,
} from '../fleetTrail';

const MAPS_API_KEY = import.meta.env.VITE_GOOGLE_MAPS_API_KEY || '';
const MAP_ID = import.meta.env.VITE_GOOGLE_MAPS_MAP_ID || 'DEMO_MAP_ID';

// Tarkwa. Only the opening camera position — it is replaced as soon as any
// rider reports a fix.
const FALLBACK_CENTER = { lat: 5.3018, lng: -1.9930 };

// A rider whose last fix is older than this is treated as offline on the map.
// Well past the 5s upload cadence the app uses, so it only trips on a real gap.
const STALE_AFTER_MS = 90 * 1000;

// A trail that reaches "now" is re-read this often.
const LIVE_TRAIL_REFRESH_MS = 30 * 1000;

// Pickup windows are padded so the ride to the first stop and away from the
// last one are visible too.
const PICKUP_WINDOW_PAD_MS = 15 * 60 * 1000;

const PICKUP_COLUMNS =
  'id, customer_name, location, location_lat, location_lng, status, bin_types, time_slot, date, ' +
  'assigned_rider_id, assigned_rider_name, accepted_at, completed_at, created_at';

const shortId = (id) => `#${String(id).slice(0, 8).toUpperCase()}`;

const bikeLabel = (bike) =>
  bike ? [bike.name, bike.plate_number].filter(Boolean).join(' · ') : null;

function matchesWords(text, query) {
  return query
    .toLowerCase()
    .split(/\s+/)
    .filter(Boolean)
    .every((word) => text.includes(word));
}

/**
 * Live fleet map. Every rider carrying a GPS fix is plotted from
 * riders.current_lat / current_lng and moved over Supabase Realtime.
 *
 * Searching a bike plate, a rider or a pickup ID opens a tracking panel: who
 * has the bike, where it is now, which pickup it is on, and the day's route
 * coloured by whether each stretch was for a pickup — the view admins use to
 * spot company bikes being used for personal trips.
 */
export default function FleetMap() {
  const [riders, setRiders] = useState([]);
  const [vehicles, setVehicles] = useState([]);
  const [activePickups, setActivePickups] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');
  const [focus, setFocus] = useState(null); // { kind: 'rider'|'bike'|'pickup', id, row? }
  const [day, setDay] = useState(ghanaToday);

  // Re-render on a timer so "2 min ago" and the stale styling stay honest even
  // when no new fix arrives — that silence is exactly the state worth showing.
  const [, setTick] = useState(0);
  useEffect(() => {
    const id = setInterval(() => setTick((t) => t + 1), 15000);
    return () => clearInterval(id);
  }, []);

  const mapRiderRow = (r) => ({
    id: r.id,
    fullName: r.profiles?.full_name || 'Rider',
    phone: r.profiles?.phone_number || null,
    photoUrl: r.profiles?.profile_picture_url || null,
    vehicleType: r.vehicle_type || 'Motorbike',
    status: r.status || 'active',
    rating: Number(r.rating) || 0,
    lat: r.current_lat,
    lng: r.current_lng,
    heading: Number(r.heading) || 0,
    speed: Number(r.speed) || 0,
    lastUpdate: r.last_location_update ? new Date(r.last_location_update) : null,
  });

  useEffect(() => {
    let mounted = true;

    const fetchRiders = async () => {
      const { data, error } = await supabase
        .from('riders')
        .select('*, profiles(full_name, phone_number, profile_picture_url)');
      if (mounted && !error) setRiders(data.map(mapRiderRow));
      if (mounted) setLoading(false);
      if (error) console.warn('FleetMap riders fetch:', error);
    };
    fetchRiders();

    const fetchVehicles = async () => {
      const { data, error } = await supabase
        .from('vehicles')
        .select('id, name, type, plate_number, status, assigned_rider_id, assigned_at');
      if (mounted && !error) setVehicles(data);
      if (error) console.warn('FleetMap vehicles fetch:', error);
    };
    fetchVehicles();

    const fetchActivePickups = async () => {
      const { data, error } = await supabase
        .from('pickup_requests')
        .select(PICKUP_COLUMNS)
        .eq('status', 'accepted');
      if (mounted && !error) setActivePickups(data);
      if (error) console.warn('FleetMap active pickups fetch:', error);
    };
    fetchActivePickups();

    // A location write touches one row, so patch that row in place rather than
    // refetching the whole fleet on every ping.
    const channel = supabase
      .channel('fleet_map_rider_positions')
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'riders' },
        (payload) => {
          setRiders((prev) =>
            prev.map((rider) =>
              rider.id === payload.new.id
                ? {
                    ...rider,
                    lat: payload.new.current_lat,
                    lng: payload.new.current_lng,
                    heading: Number(payload.new.heading) || 0,
                    speed: Number(payload.new.speed) || 0,
                    status: payload.new.status || rider.status,
                    lastUpdate: payload.new.last_location_update
                      ? new Date(payload.new.last_location_update)
                      : rider.lastUpdate,
                  }
                : rider
            )
          );
        }
      )
      // INSERT and DELETE change the roster rather than a position, and carry
      // no joined profile, so those do warrant a refetch.
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'riders' }, fetchRiders)
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'riders' }, fetchRiders)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'vehicles' }, fetchVehicles)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'pickup_requests' }, fetchActivePickups)
      .subscribe();

    return () => {
      mounted = false;
      supabase.removeChannel(channel);
    };
  }, []);

  const isStale = useCallback(
    (rider) => !rider.lastUpdate || serverNow() - rider.lastUpdate.getTime() > STALE_AFTER_MS,
    []
  );

  const ridersById = useMemo(() => {
    const byId = new globalThis.Map();
    riders.forEach((r) => byId.set(r.id, r));
    return byId;
  }, [riders]);

  const bikeByRiderId = useMemo(() => {
    const byRider = new globalThis.Map();
    vehicles.forEach((v) => v.assigned_rider_id && byRider.set(v.assigned_rider_id, v));
    return byRider;
  }, [vehicles]);

  const locatedRiders = useMemo(
    () => riders.filter((r) => typeof r.lat === 'number' && typeof r.lng === 'number'),
    [riders]
  );

  // ── Focus: what the tracking panel is about ──────────────────────────────
  const [focusPickupRow, setFocusPickupRow] = useState(null);
  useEffect(() => {
    if (focus?.kind !== 'pickup') {
      setFocusPickupRow(null);
      return undefined;
    }
    let cancelled = false;
    if (focus.row) setFocusPickupRow(focus.row);
    // Re-read so status and completion time are current, not what search saw.
    supabase
      .from('pickup_requests')
      .select(PICKUP_COLUMNS)
      .eq('id', focus.id)
      .maybeSingle()
      .then(({ data }) => {
        if (!cancelled && data) setFocusPickupRow(data);
      });
    return () => {
      cancelled = true;
    };
  }, [focus]);

  // Keep a focused active pickup in step with realtime changes.
  const livePickupRow =
    focus?.kind === 'pickup'
      ? activePickups.find((p) => p.id === focus.id) || focusPickupRow
      : null;

  const trailWindow = useMemo(() => {
    if (!focus) return null;
    if (focus.kind === 'pickup') {
      const p = livePickupRow;
      if (!p) return null;
      const start = new Date(p.accepted_at || p.created_at).getTime() - PICKUP_WINDOW_PAD_MS;
      // A pickup still in progress has no end: its window runs up to now.
      const end = p.completed_at ? new Date(new Date(p.completed_at).getTime() + PICKUP_WINDOW_PAD_MS) : null;
      return { start: new Date(start), end, riderId: p.assigned_rider_id };
    }
    const [start, end] = ghanaDayRange(day);
    return { start, end };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [focus?.kind, focus?.id, day, livePickupRow?.accepted_at, livePickupRow?.completed_at, livePickupRow?.assigned_rider_id]);

  const windowIsLive = trailWindow ? !trailWindow.end || trailWindow.end.getTime() >= serverNow() : false;
  const focusKey = focus ? `${focus.kind}:${focus.id}:${day}` : null;

  const [trail, setTrail] = useState([]);
  const [trailLoading, setTrailLoading] = useState(false);
  const [trailError, setTrailError] = useState(null);
  // Which focus the loaded trail belongs to, so the camera waits for it.
  const [trailKey, setTrailKey] = useState(null);

  useEffect(() => {
    if (!focus || !trailWindow) {
      setTrail([]);
      setTrailError(null);
      return undefined;
    }
    if (focus.kind === 'pickup' && !trailWindow.riderId) {
      setTrail([]);
      setTrailKey(focusKey);
      return undefined;
    }

    let cancelled = false;
    const load = async (showSpinner) => {
      if (showSpinner) setTrailLoading(true);
      let query = supabase
        .from('rider_location_pings')
        .select('rider_id, vehicle_id, pickup_request_id, rider_status, lat, lng, speed, recorded_at')
        .gte('recorded_at', trailWindow.start.toISOString())
        .lt('recorded_at', (trailWindow.end || new Date(serverNow() + 60 * 1000)).toISOString())
        .order('recorded_at', { ascending: true })
        .limit(5000);
      if (focus.kind === 'bike') query = query.eq('vehicle_id', focus.id);
      else if (focus.kind === 'rider') query = query.eq('rider_id', focus.id);
      else query = query.eq('rider_id', trailWindow.riderId);

      const { data, error } = await query;
      if (cancelled) return;
      setTrail(error ? [] : data);
      setTrailError(error ? error.message : null);
      setTrailLoading(false);
      setTrailKey(focusKey);
    };

    load(true);
    const id = windowIsLive ? setInterval(() => load(false), LIVE_TRAIL_REFRESH_MS) : null;
    return () => {
      cancelled = true;
      if (id) clearInterval(id);
    };
    // focusKey is derived from focus and day, which are already dependencies.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [focus, trailWindow, windowIsLive]);

  // Who and what the panel is about, resolved from the focus.
  const focusBike =
    focus?.kind === 'bike'
      ? vehicles.find((v) => v.id === focus.id) || null
      : focus?.kind === 'rider'
        ? bikeByRiderId.get(focus.id) || null
        : focus?.kind === 'pickup'
          ? vehicles.find((v) => v.id === trail.find((p) => p.vehicle_id)?.vehicle_id) ||
            bikeByRiderId.get(livePickupRow?.assigned_rider_id) ||
            null
          : null;

  const lastTrailRiderId = trail.length ? trail[trail.length - 1].rider_id : null;
  const focusRiderId =
    focus?.kind === 'rider'
      ? focus.id
      : focus?.kind === 'bike'
        ? focusBike?.assigned_rider_id || lastTrailRiderId
        : focus?.kind === 'pickup'
          ? livePickupRow?.assigned_rider_id || null
          : null;
  const focusRider = focusRiderId ? ridersById.get(focusRiderId) || null : null;

  // The live fix, appended so the trail reaches the pin while it moves.
  const trailWithLive = useMemo(() => {
    if (!windowIsLive || !focusRider || typeof focusRider.lat !== 'number' || !focusRider.lastUpdate) {
      return trail;
    }
    if (focus?.kind === 'bike' && focusBike?.assigned_rider_id !== focusRider.id) return trail;
    const last = trail[trail.length - 1];
    if (last && new Date(last.recorded_at) >= focusRider.lastUpdate) return trail;
    const activeForRider = activePickups.find((p) => p.assigned_rider_id === focusRider.id);
    return [
      ...trail,
      {
        rider_id: focusRider.id,
        vehicle_id: focusBike?.id || null,
        pickup_request_id: activeForRider?.id || null,
        rider_status: focusRider.status,
        lat: focusRider.lat,
        lng: focusRider.lng,
        recorded_at: focusRider.lastUpdate.toISOString(),
      },
    ];
  }, [trail, windowIsLive, focusRider, focusBike, activePickups, focus?.kind]);

  const analysis = useMemo(() => analyzeTrail(trailWithLive), [trailWithLive]);

  // Pickups that belong in the panel: the day's jobs for the rider(s) seen on
  // the trail, or the one pickup being looked at.
  const [panelPickups, setPanelPickups] = useState([]);
  const trailRiderKey = useMemo(
    () => [...new Set([focusRiderId, ...trail.map((p) => p.rider_id)].filter(Boolean))].sort().join(','),
    [trail, focusRiderId]
  );

  useEffect(() => {
    if (!focus || focus.kind === 'pickup' || !trailRiderKey) {
      setPanelPickups([]);
      return undefined;
    }
    let cancelled = false;
    const [start, end] = ghanaDayRange(day);
    const s = start.toISOString();
    const e = end.toISOString();
    supabase
      .from('pickup_requests')
      .select(PICKUP_COLUMNS)
      .in('assigned_rider_id', trailRiderKey.split(','))
      .or(
        `and(accepted_at.gte.${s},accepted_at.lt.${e}),and(completed_at.gte.${s},completed_at.lt.${e}),status.eq.accepted`
      )
      .order('accepted_at', { ascending: true })
      .then(({ data, error }) => {
        if (cancelled) return;
        setPanelPickups(error ? [] : data);
        if (error) console.warn('FleetMap panel pickups fetch:', error);
      });
    return () => {
      cancelled = true;
    };
  }, [focus, day, trailRiderKey]);

  const mapPickups = focus?.kind === 'pickup' ? (livePickupRow ? [livePickupRow] : []) : panelPickups;

  const visibleRiders = useMemo(() => {
    let list = locatedRiders;
    if (filter === 'live') list = list.filter((r) => !isStale(r));
    if (filter === 'stale') list = list.filter((r) => isStale(r));
    if (focusRider && typeof focusRider.lat === 'number' && !list.includes(focusRider)) {
      list = [...list, focusRider];
    }
    return list;
  }, [locatedRiders, filter, isStale, focusRider]);

  const liveCount = locatedRiders.filter((r) => !isStale(r)).length;
  const noLocationCount = riders.length - locatedRiders.length;

  // Camera requests from the panel ("show this stretch", "centre on rider").
  const [cameraTarget, setCameraTarget] = useState(null);

  const selectFocus = (next) => {
    setFocus(next);
    setCameraTarget(null);
  };

  if (!MAPS_API_KEY) {
    return <MissingKeyNotice />;
  }

  return (
    <div style={styles.page}>
      <header style={styles.header}>
        <div>
          <h1 style={styles.title}>Live Fleet Map</h1>
          <p style={styles.subtitle}>
            Search a bike plate, rider or pickup ID to see where it is, who has it, and what trips it made.
          </p>
        </div>
        <div style={styles.filterRow}>
          <FilterChip
            label={`All (${locatedRiders.length})`}
            active={filter === 'all'}
            onClick={() => setFilter('all')}
          />
          <FilterChip
            label={`Live (${liveCount})`}
            active={filter === 'live'}
            onClick={() => setFilter('live')}
            dot="var(--color-success)"
          />
          <FilterChip
            label={`Stale (${locatedRiders.length - liveCount})`}
            active={filter === 'stale'}
            onClick={() => setFilter('stale')}
            dot="var(--color-accent)"
          />
        </div>
      </header>

      <FleetSearch
        riders={riders}
        vehicles={vehicles}
        activePickups={activePickups}
        bikeByRiderId={bikeByRiderId}
        ridersById={ridersById}
        onPick={selectFocus}
      />

      {noLocationCount > 0 && (
        <div style={styles.notice}>
          {noLocationCount} rider{noLocationCount === 1 ? ' has' : 's have'} never
          reported a location — they will appear here once their app sends a fix.
        </div>
      )}

      <div style={styles.mapShell}>
        {loading ? (
          <div style={styles.loading}>Loading fleet…</div>
        ) : (
          <APIProvider apiKey={MAPS_API_KEY}>
            <Map
              mapId={MAP_ID}
              defaultCenter={
                visibleRiders.length > 0
                  ? { lat: visibleRiders[0].lat, lng: visibleRiders[0].lng }
                  : FALLBACK_CENTER
              }
              defaultZoom={12}
              gestureHandling="greedy"
              disableDefaultUI={false}
              mapTypeControl={false}
              streetViewControl={false}
              fullscreenControl={false}
              style={{ width: '100%', height: '100%' }}
            >
              <FitBounds riders={visibleRiders} />
              <FocusCamera
                focusKey={focusKey}
                ready={trailKey === focusKey && !trailLoading}
                points={analysis.points}
                pickups={mapPickups}
                rider={focusRider}
              />
              <CameraTarget target={cameraTarget} />

              {analysis.segments.map((segment, index) => (
                <Polyline
                  key={`${focusKey}-${index}`}
                  path={segment.path.map(({ lat, lng }) => ({ lat, lng }))}
                  strokeColor={TRAIL_COLORS[segment.category]}
                  strokeWeight={segment.category === 'gap' ? 3 : 5}
                  strokeOpacity={segment.category === 'gap' ? 0 : 0.9}
                  icons={segment.category === 'gap' ? DASHED_LINE_ICON : undefined}
                />
              ))}

              {analysis.points.length > 0 && (
                <AdvancedMarker position={analysis.points[0]} title={`Trail start ${formatTime(analysis.points[0].at)}`}>
                  <TrailStartPin />
                </AdvancedMarker>
              )}

              {mapPickups
                .filter((p) => typeof p.location_lat === 'number' && typeof p.location_lng === 'number')
                .map((p) => (
                  <AdvancedMarker
                    key={p.id}
                    position={{ lat: p.location_lat, lng: p.location_lng }}
                    title={`${shortId(p.id)} — ${p.customer_name || 'Customer'}`}
                    onClick={() => selectFocus({ kind: 'pickup', id: p.id, row: p })}
                  >
                    <PickupPin pickup={p} />
                  </AdvancedMarker>
                ))}

              {visibleRiders.map((rider) => (
                <AdvancedMarker
                  key={rider.id}
                  position={{ lat: rider.lat, lng: rider.lng }}
                  onClick={() => selectFocus({ kind: 'rider', id: rider.id })}
                  title={rider.fullName}
                  zIndex={rider.id === focusRiderId ? 1000 : 10}
                >
                  <RiderPin
                    rider={rider}
                    bike={bikeByRiderId.get(rider.id)}
                    stale={isStale(rider)}
                    selected={rider.id === focusRiderId}
                  />
                </AdvancedMarker>
              ))}
            </Map>
          </APIProvider>
        )}

        {focus && (
          <TrackingPanel
            focus={focus}
            day={day}
            onDayChange={setDay}
            bike={focusBike}
            rider={focusRider}
            riderStale={focusRider ? isStale(focusRider) : true}
            pickup={livePickupRow}
            pickups={mapPickups}
            activePickups={activePickups}
            analysis={analysis}
            pingCount={trail.length}
            loading={trailLoading}
            error={trailError}
            windowIsLive={windowIsLive}
            ridersById={ridersById}
            onFocus={selectFocus}
            onShowPath={(path) => setCameraTarget({ path, at: Date.now() })}
            onClose={() => selectFocus(null)}
          />
        )}

        {!loading && visibleRiders.length === 0 && !focus && (
          <div style={styles.emptyOverlay}>
            <strong style={{ display: 'block', marginBottom: '4px' }}>
              No riders to show
            </strong>
            <span style={{ color: 'var(--text-secondary)' }}>
              {riders.length === 0
                ? 'No riders are registered yet.'
                : 'No rider matches this filter right now.'}
            </span>
          </div>
        )}
      </div>
    </div>
  );
}

// ── Search ──────────────────────────────────────────────────────────────────

function FleetSearch({ riders, vehicles, activePickups, bikeByRiderId, ridersById, onPick }) {
  const [query, setQuery] = useState('');
  const [open, setOpen] = useState(false);
  const [pickupResults, setPickupResults] = useState([]);
  const [searchingPickups, setSearchingPickups] = useState(false);
  const boxRef = useRef(null);

  const trimmed = query.trim();

  useEffect(() => {
    const onDocClick = (e) => {
      if (boxRef.current && !boxRef.current.contains(e.target)) setOpen(false);
    };
    document.addEventListener('mousedown', onDocClick);
    return () => document.removeEventListener('mousedown', onDocClick);
  }, []);

  // Pickups are searched server-side: short IDs can't be matched with plain
  // table filters, and older pickups aren't loaded on this page.
  useEffect(() => {
    if (trimmed.replace(/^#/, '').length < 3) {
      setPickupResults([]);
      setSearchingPickups(false);
      return undefined;
    }
    setSearchingPickups(true);
    let cancelled = false;
    const id = setTimeout(async () => {
      const { data, error } = await supabase.rpc('admin_find_pickups', { p_query: trimmed, p_limit: 8 });
      if (cancelled) return;
      setPickupResults(error ? [] : data);
      setSearchingPickups(false);
      if (error) console.warn('admin_find_pickups:', error);
    }, 300);
    return () => {
      cancelled = true;
      clearTimeout(id);
    };
  }, [trimmed]);

  const bikeResults = useMemo(() => {
    if (!trimmed) return [];
    return vehicles
      .filter((v) => {
        const rider = v.assigned_rider_id ? ridersById.get(v.assigned_rider_id) : null;
        return matchesWords(
          [v.plate_number, v.name, v.type, rider?.fullName].filter(Boolean).join(' ').toLowerCase(),
          trimmed
        );
      })
      .slice(0, 6);
  }, [vehicles, ridersById, trimmed]);

  const riderResults = useMemo(() => {
    if (!trimmed) return [];
    return riders
      .filter((r) => {
        const bike = bikeByRiderId.get(r.id);
        return matchesWords(
          [r.fullName, r.phone, bike?.plate_number, bike?.name].filter(Boolean).join(' ').toLowerCase(),
          trimmed
        );
      })
      .slice(0, 6);
  }, [riders, bikeByRiderId, trimmed]);

  // Active pickups show instantly, before the server search answers.
  const mergedPickups = useMemo(() => {
    if (!trimmed) return [];
    const term = trimmed.replace(/^#/, '').toLowerCase();
    const local = activePickups.filter(
      (p) =>
        p.id.replace(/-/g, '').startsWith(term.replace(/-/g, '')) ||
        matchesWords(`${p.customer_name || ''} ${p.assigned_rider_name || ''}`.toLowerCase(), trimmed)
    );
    const seen = new Set();
    return [...local, ...pickupResults].filter((p) => (seen.has(p.id) ? false : seen.add(p.id))).slice(0, 8);
  }, [activePickups, pickupResults, trimmed]);

  const pick = (next) => {
    onPick(next);
    setOpen(false);
  };

  const firstResult =
    bikeResults[0] ? { kind: 'bike', id: bikeResults[0].id }
    : riderResults[0] ? { kind: 'rider', id: riderResults[0].id }
    : mergedPickups[0] ? { kind: 'pickup', id: mergedPickups[0].id, row: mergedPickups[0] }
    : null;

  const nothing = !bikeResults.length && !riderResults.length && !mergedPickups.length;

  return (
    <div ref={boxRef} style={{ position: 'relative', maxWidth: '560px', width: '100%' }}>
      <div className="header-search" style={{ width: '100%' }}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--text-muted)" strokeWidth="2.5" aria-hidden="true">
          <circle cx="11" cy="11" r="8" />
          <line x1="21" y1="21" x2="16.65" y2="16.65" />
        </svg>
        <input
          type="text"
          value={query}
          placeholder="Search bike plate, rider name or pickup ID (e.g. #6E94935B)…"
          aria-label="Search the fleet"
          onChange={(e) => {
            setQuery(e.target.value);
            setOpen(true);
          }}
          onFocus={() => setOpen(true)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && firstResult) pick(firstResult);
            if (e.key === 'Escape') setOpen(false);
          }}
        />
        {query && (
          <button type="button" onClick={() => setQuery('')} aria-label="Clear search" style={styles.clearButton}>
            ×
          </button>
        )}
      </div>

      {open && trimmed && (
        <div style={styles.searchResults}>
          {bikeResults.length > 0 && <div style={styles.resultGroup}>Bikes</div>}
          {bikeResults.map((v) => {
            const rider = v.assigned_rider_id ? ridersById.get(v.assigned_rider_id) : null;
            return (
              <button key={v.id} type="button" style={styles.resultRow} onClick={() => pick({ kind: 'bike', id: v.id })}>
                <strong>{v.plate_number || v.name}</strong>
                <span style={styles.resultMeta}>
                  {v.plate_number ? `${v.name} · ` : ''}
                  {rider ? `With ${rider.fullName}` : 'Not assigned'}
                </span>
              </button>
            );
          })}

          {riderResults.length > 0 && <div style={styles.resultGroup}>Riders</div>}
          {riderResults.map((r) => {
            const bike = bikeByRiderId.get(r.id);
            return (
              <button key={r.id} type="button" style={styles.resultRow} onClick={() => pick({ kind: 'rider', id: r.id })}>
                <strong>{r.fullName}</strong>
                <span style={styles.resultMeta}>
                  {bike ? bikeLabel(bike) : 'No company bike'} · {r.status}
                </span>
              </button>
            );
          })}

          {mergedPickups.length > 0 && <div style={styles.resultGroup}>Pickups</div>}
          {mergedPickups.map((p) => (
            <button key={p.id} type="button" style={styles.resultRow} onClick={() => pick({ kind: 'pickup', id: p.id, row: p })}>
              <strong>{shortId(p.id)} · {p.customer_name || 'Customer'}</strong>
              <span style={styles.resultMeta}>
                {p.status} · {p.assigned_rider_name ? `Rider ${p.assigned_rider_name}` : 'No rider yet'} · {formatDate(p.created_at)}
              </span>
            </button>
          ))}

          {nothing && (
            <div style={{ padding: '10px 12px', color: 'var(--text-muted)' }}>
              {searchingPickups ? 'Searching…' : `Nothing matches “${trimmed}”.`}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ── Tracking panel ──────────────────────────────────────────────────────────

function TrackingPanel({
  focus,
  day,
  onDayChange,
  bike,
  rider,
  riderStale,
  pickup,
  pickups,
  activePickups,
  analysis,
  pingCount,
  loading,
  error,
  windowIsLive,
  ridersById,
  onFocus,
  onShowPath,
  onClose,
}) {
  const { stats, flags } = analysis;
  const today = ghanaToday();
  const riderActive = rider ? activePickups.filter((p) => p.assigned_rider_id === rider.id) : [];
  const movingWithoutPickup =
    rider && !riderStale && rider.speed >= 5 && riderActive.length === 0;

  const title =
    focus.kind === 'bike'
      ? bikeLabel(bike) || 'Bike'
      : focus.kind === 'rider'
        ? rider?.fullName || 'Rider'
        : pickup
          ? `${shortId(pickup.id)} · ${pickup.customer_name || 'Customer'}`
          : 'Pickup';

  return (
    <aside style={styles.panel}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '8px' }}>
        <div style={{ minWidth: 0 }}>
          <div style={styles.kindLabel}>{focus.kind === 'bike' ? 'Bike' : focus.kind === 'rider' ? 'Rider' : 'Pickup'}</div>
          <div style={styles.panelTitle}>{title}</div>
        </div>
        <button style={styles.panelClose} onClick={onClose} aria-label="Close tracking panel">×</button>
      </div>

      {focus.kind !== 'pickup' && (
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <input
            type="date"
            value={day}
            max={today}
            onChange={(e) => e.target.value && onDayChange(e.target.value)}
            style={styles.dateInput}
            aria-label="Day to review"
          />
          {day !== today && (
            <button className="btn-outline" style={{ padding: '5px 10px', fontSize: '11px' }} onClick={() => onDayChange(today)}>
              Today
            </button>
          )}
        </div>
      )}

      {/* Bike and rider */}
      <section style={styles.panelSection}>
        <Row label="Bike">
          {bike ? bikeLabel(bike) : <span style={{ color: 'var(--text-muted)' }}>No company bike linked</span>}
        </Row>
        {focus.kind === 'bike' && bike && !bike.assigned_rider_id && (
          <Row label="Assigned to">
            <span style={{ color: 'var(--text-muted)' }}>Nobody right now{rider ? ` (last ridden by ${rider.fullName})` : ''}</span>
          </Row>
        )}
        <Row label="Rider">
          {rider ? (
            <button type="button" style={styles.linkButton} onClick={() => onFocus({ kind: 'rider', id: rider.id })}>
              {rider.fullName}
            </button>
          ) : (
            <span style={{ color: 'var(--text-muted)' }}>{focus.kind === 'pickup' ? 'Not accepted yet' : '—'}</span>
          )}
        </Row>
        {rider && (
          <>
            <Row label="Status"><span style={{ textTransform: 'capitalize' }}>{rider.status}</span></Row>
            <Row label="Last fix">
              <span style={{ color: riderStale ? 'var(--color-accent)' : 'var(--color-success)' }}>
                {rider.lastUpdate ? `${formatAgo(rider.lastUpdate)} · ${Math.round(rider.speed)} km/h` : 'Never reported'}
              </span>
            </Row>
            {rider.phone && (
              <Row label="Phone"><a href={`tel:${rider.phone}`} style={styles.linkButton}>{rider.phone}</a></Row>
            )}
          </>
        )}
        {rider && typeof rider.lat === 'number' && (
          <button
            className="btn-outline"
            style={{ padding: '5px 10px', fontSize: '11px', alignSelf: 'flex-start' }}
            onClick={() => onShowPath([{ lat: rider.lat, lng: rider.lng }])}
          >
            Centre on {riderStale ? 'last known position' : 'live position'}
          </button>
        )}
      </section>

      {/* Right now */}
      {rider && (focus.kind !== 'pickup' || windowIsLive) && (
        <section style={styles.panelSection}>
          <div style={styles.sectionTitle}>Right now</div>
          {riderActive.length === 0 ? (
            <div style={{ color: movingWithoutPickup ? TRAIL_COLORS.offduty : 'var(--text-secondary)', fontWeight: movingWithoutPickup ? 700 : 400 }}>
              {movingWithoutPickup
                ? `Moving at ${Math.round(rider.speed)} km/h with no pickup in progress.`
                : 'No pickup in progress.'}
            </div>
          ) : (
            riderActive.map((p) => (
              <PickupRow key={p.id} pickup={p} onClick={() => onFocus({ kind: 'pickup', id: p.id, row: p })} />
            ))
          )}
        </section>
      )}

      {/* Pickup details */}
      {focus.kind === 'pickup' && pickup && (
        <section style={styles.panelSection}>
          <div style={styles.sectionTitle}>Pickup</div>
          <Row label="Status"><span style={{ textTransform: 'capitalize' }}>{pickup.status}</span></Row>
          <Row label="Location">{pickup.location || '—'}</Row>
          <Row label="Bins">{(pickup.bin_types || []).join(', ') || '—'}</Row>
          <Row label="Requested">{formatDateTime(pickup.created_at)}</Row>
          <Row label="Accepted">{pickup.accepted_at ? formatDateTime(pickup.accepted_at) : '—'}</Row>
          <Row label="Completed">{pickup.completed_at ? formatDateTime(pickup.completed_at) : '—'}</Row>
          {pickup.accepted_at && pickup.completed_at && (
            <Row label="Took">{formatMinutes((new Date(pickup.completed_at) - new Date(pickup.accepted_at)) / 60000)}</Row>
          )}
        </section>
      )}

      {/* Movement summary */}
      <section style={styles.panelSection}>
        <div style={styles.sectionTitle}>
          {focus.kind === 'pickup' ? 'Movement around this pickup' : `Movement on ${day === today ? 'today' : formatDate(`${day}T12:00:00Z`)}`}
        </div>
        {loading ? (
          <div style={{ color: 'var(--text-muted)' }}>Loading route…</div>
        ) : error ? (
          <div style={{ color: TRAIL_COLORS.offduty }}>Could not load the route: {error}</div>
        ) : pingCount === 0 ? (
          <div style={{ color: 'var(--text-muted)', lineHeight: 1.5 }}>
            No location history for this period. History is recorded from riders on the updated app, while they hold a
            company bike or are on a pickup.
          </div>
        ) : (
          <>
            <div style={styles.statGrid}>
              <Stat label="Total" value={formatKm(stats.totalKm)} />
              <Stat label="On pickups" value={formatKm(stats.pickupKm)} tone={TRAIL_COLORS.pickup} />
              <Stat label="No pickup" value={formatKm(stats.unassignedKm)} tone={stats.unassignedKm >= 0.3 ? TRAIL_COLORS.unassigned : undefined} />
              <Stat label="Off duty" value={formatKm(stats.offdutyKm)} tone={stats.offdutyKm >= 0.3 ? TRAIL_COLORS.offduty : undefined} />
              <Stat
                label="Signal gaps"
                value={stats.gapCount ? `${stats.gapCount} · longest ${formatMinutes(stats.longestGapMinutes)}` : 'None'}
                tone={stats.gapCount ? TRAIL_COLORS.gap : undefined}
              />
            </div>
            <Legend />
          </>
        )}
      </section>

      {/* Flags */}
      {!loading && flags.length > 0 && (
        <section style={styles.panelSection}>
          <div style={styles.sectionTitle}>Needs checking ({flags.length})</div>
          {flags.map((flag, index) => (
            <button
              key={`${flag.kind}-${index}`}
              type="button"
              style={{ ...styles.flagRow, borderLeftColor: TRAIL_COLORS[flag.kind] }}
              onClick={() => onShowPath(flag.path)}
              title="Show this stretch on the map"
            >
              <strong>
                {formatTime(flag.startAt)}–{formatTime(flag.endAt)} · {TRAIL_LABELS[flag.kind]}
              </strong>
              <span style={styles.resultMeta}>
                {flag.kind === 'gap'
                  ? `${formatMinutes(flag.minutes)} with no location${flag.km >= 0.3 ? ` · reappeared ${formatKm(flag.km)} away` : ''}`
                  : `${formatKm(flag.km)} in ${formatMinutes(flag.minutes)}`}
              </span>
            </button>
          ))}
        </section>
      )}

      {/* The day's pickups */}
      {focus.kind !== 'pickup' && pickups.length > 0 && (
        <section style={styles.panelSection}>
          <div style={styles.sectionTitle}>Pickups ({pickups.length})</div>
          {pickups.map((p) => (
            <PickupRow
              key={p.id}
              pickup={p}
              riderName={focus.kind === 'bike' ? ridersById.get(p.assigned_rider_id)?.fullName : null}
              onClick={() => onFocus({ kind: 'pickup', id: p.id, row: p })}
            />
          ))}
        </section>
      )}
    </aside>
  );
}

function PickupRow({ pickup, riderName, onClick }) {
  const when = pickup.completed_at
    ? `done ${formatTime(pickup.completed_at)}`
    : pickup.accepted_at
      ? `accepted ${formatTime(pickup.accepted_at)}`
      : pickup.status;
  return (
    <button type="button" style={styles.resultRow} onClick={onClick}>
      <strong>{shortId(pickup.id)} · {pickup.customer_name || 'Customer'}</strong>
      <span style={styles.resultMeta}>
        {pickup.status} · {when}{riderName ? ` · ${riderName}` : ''}
      </span>
      {pickup.location && <span style={styles.resultMeta}>{pickup.location}</span>}
    </button>
  );
}

function Row({ label, children }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '78px 1fr', gap: '8px', alignItems: 'baseline' }}>
      <span style={styles.statLabel}>{label}</span>
      <span style={{ fontSize: '12.5px', color: 'var(--text-primary)', minWidth: 0, overflowWrap: 'anywhere' }}>{children}</span>
    </div>
  );
}

function Legend() {
  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: '10px', marginTop: '8px' }}>
      {Object.keys(TRAIL_COLORS).map((key) => (
        <span key={key} style={{ display: 'flex', alignItems: 'center', gap: '5px', fontSize: '11px', color: 'var(--text-secondary)' }}>
          <span
            style={{
              width: '16px',
              height: 0,
              borderTop: `3px ${key === 'gap' ? 'dashed' : 'solid'} ${TRAIL_COLORS[key]}`,
              display: 'inline-block',
            }}
          />
          {TRAIL_LABELS[key]}
        </span>
      ))}
    </div>
  );
}

// ── Map helpers ─────────────────────────────────────────────────────────────

const DASHED_LINE_ICON = [
  { icon: { path: 'M 0,-1 0,1', strokeOpacity: 1, scale: 3 }, offset: '0', repeat: '12px' },
];

/**
 * Frames every visible rider once, then steps back so an admin who has zoomed
 * into one neighbourhood is not yanked out every time a marker moves.
 */
function FitBounds({ riders }) {
  const map = useMap();
  const hasFitted = useRef(false);

  useEffect(() => {
    if (!map || riders.length === 0 || hasFitted.current) return;
    hasFitted.current = true;

    if (riders.length === 1) {
      map.setCenter({ lat: riders[0].lat, lng: riders[0].lng });
      map.setZoom(14);
      return;
    }

    const bounds = new window.google.maps.LatLngBounds();
    riders.forEach((r) => bounds.extend({ lat: r.lat, lng: r.lng }));
    map.fitBounds(bounds, 64);
  }, [map, riders]);

  return null;
}

/** Frames the trail, pickups and rider once per new focus, after the trail loads. */
function FocusCamera({ focusKey, ready, points, pickups, rider }) {
  const map = useMap();
  const framedKey = useRef(null);

  useEffect(() => {
    if (!map || !focusKey || !ready || framedKey.current === focusKey) return;
    framedKey.current = focusKey;

    const coords = [
      ...points.map(({ lat, lng }) => ({ lat, lng })),
      ...pickups
        .filter((p) => typeof p.location_lat === 'number' && typeof p.location_lng === 'number')
        .map((p) => ({ lat: p.location_lat, lng: p.location_lng })),
    ];
    if (rider && typeof rider.lat === 'number') coords.push({ lat: rider.lat, lng: rider.lng });
    fitCoords(map, coords);
  }, [map, focusKey, ready, points, pickups, rider]);

  return null;
}

function CameraTarget({ target }) {
  const map = useMap();
  useEffect(() => {
    if (map && target) fitCoords(map, target.path);
  }, [map, target]);
  return null;
}

function fitCoords(map, coords) {
  if (!coords.length) return;
  if (coords.length === 1) {
    map.panTo(coords[0]);
    map.setZoom(16);
    return;
  }
  const bounds = new window.google.maps.LatLngBounds();
  coords.forEach((c) => bounds.extend(c));
  map.fitBounds(bounds, 80);
}

function RiderPin({ rider, bike, stale, selected }) {
  const color = stale ? 'var(--color-accent)' : 'var(--color-success)';

  return (
    <div
      style={{
        position: 'relative',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        transform: selected ? 'scale(1.15)' : 'scale(1)',
        transition: 'transform 0.2s ease',
      }}
    >
      <div style={{ position: 'relative' }}>
        <div
          style={{
            width: '34px',
            height: '34px',
            borderRadius: '50%',
            background: color,
            border: '3px solid #fff',
            boxShadow: selected
              ? '0 0 0 4px var(--color-primary), 0 3px 10px rgba(0,0,0,0.28)'
              : '0 3px 10px rgba(0,0,0,0.28)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#fff',
          }}
        >
          {/* Rotated to the reported heading so a glance at the map shows which
              way each vehicle is actually travelling. */}
          <svg
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="currentColor"
            style={{
              transform: `rotate(${rider.heading || 0}deg)`,
              transition: 'transform 0.6s ease',
            }}
          >
            <path d="M12 2 L19 21 L12 17 L5 21 Z" />
          </svg>
        </div>
        {!stale && (
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
      {bike?.plate_number && <span style={styles.pinTag}>{bike.plate_number}</span>}
    </div>
  );
}

function PickupPin({ pickup }) {
  const done = pickup.status === 'completed';
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', cursor: 'pointer' }}>
      <div
        style={{
          width: '22px',
          height: '22px',
          borderRadius: '50% 50% 50% 0',
          background: done ? TRAIL_COLORS.pickup : '#2563eb',
          border: '2px solid #fff',
          transform: 'rotate(-45deg)',
          boxShadow: '0 3px 8px rgba(0,0,0,0.3)',
        }}
      />
      <span style={styles.pinTag}>{shortId(pickup.id)}</span>
    </div>
  );
}

function TrailStartPin() {
  return (
    <div
      title="Start of trail"
      style={{
        width: '12px',
        height: '12px',
        borderRadius: '50%',
        background: '#fff',
        border: '3px solid #0f172a',
        boxShadow: '0 2px 6px rgba(0,0,0,0.3)',
      }}
    />
  );
}

function Stat({ label, value, tone }) {
  return (
    <div>
      <div style={styles.statLabel}>{label}</div>
      <div style={{ ...styles.statValue, color: tone || 'var(--text-primary)' }}>
        {value}
      </div>
    </div>
  );
}

function FilterChip({ label, active, onClick, dot }) {
  return (
    <button
      onClick={onClick}
      style={{
        ...styles.chip,
        background: active ? 'var(--color-primary)' : 'var(--bg-card)',
        color: active ? '#fff' : 'var(--text-secondary)',
        borderColor: active ? 'var(--color-primary)' : 'var(--border-divider)',
      }}
    >
      {dot && (
        <span
          style={{
            width: '7px',
            height: '7px',
            borderRadius: '50%',
            background: active ? '#fff' : dot,
            display: 'inline-block',
            marginRight: '6px',
          }}
        />
      )}
      {label}
    </button>
  );
}

function MissingKeyNotice() {
  return (
    <div style={styles.page}>
      <h1 style={styles.title}>Live Fleet Map</h1>
      <div style={{ ...styles.mapShell, ...styles.missingKey }}>
        <div style={{ maxWidth: '460px', textAlign: 'center' }}>
          <h2 style={{ fontSize: '16px', marginBottom: '10px' }}>
            Google Maps key not configured
          </h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', lineHeight: 1.6 }}>
            Create <code>admin_panel/.env.local</code> with a browser key that has
            the <strong>Maps JavaScript API</strong> enabled, then restart the dev
            server:
          </p>
          <pre style={styles.pre}>VITE_GOOGLE_MAPS_API_KEY=AIza...</pre>
          <p style={{ color: 'var(--text-muted)', fontSize: '12px' }}>
            Restrict the key by HTTP referrer in Google Cloud Console — a browser
            key is visible to anyone who loads the page.
          </p>
        </div>
      </div>
    </div>
  );
}

function formatAgo(date) {
  if (!date) return '—';
  const seconds = Math.floor((serverNow() - date.getTime()) / 1000);
  if (seconds < 60) return 'Just now';
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} h ago`;
  return formatDate(date);
}

const styles = {
  page: { display: 'flex', flexDirection: 'column', height: '100%', gap: '16px' },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-end',
    flexWrap: 'wrap',
    gap: '12px',
  },
  title: {
    fontSize: '22px',
    fontWeight: 700,
    color: 'var(--text-primary)',
    margin: 0,
  },
  subtitle: {
    fontSize: '13px',
    color: 'var(--text-secondary)',
    margin: '4px 0 0',
  },
  filterRow: { display: 'flex', gap: '8px', flexWrap: 'wrap' },
  chip: {
    padding: '7px 14px',
    borderRadius: 'var(--border-radius-xl)',
    border: '1px solid',
    fontSize: '12px',
    fontWeight: 600,
    cursor: 'pointer',
    fontFamily: 'inherit',
    transition: 'var(--transition-smooth)',
  },
  notice: {
    padding: '10px 14px',
    borderRadius: 'var(--border-radius-sm)',
    background: 'rgba(245, 158, 11, 0.1)',
    color: 'var(--color-accent)',
    fontSize: '12.5px',
  },
  mapShell: {
    position: 'relative',
    flex: 1,
    minHeight: '520px',
    borderRadius: 'var(--border-radius-lg)',
    overflow: 'hidden',
    border: '1px solid var(--border-divider)',
    boxShadow: 'var(--shadow-card)',
    background: 'var(--bg-card)',
  },
  loading: {
    height: '100%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    color: 'var(--text-secondary)',
    fontSize: '13px',
  },
  emptyOverlay: {
    position: 'absolute',
    top: '50%',
    left: '50%',
    transform: 'translate(-50%, -50%)',
    background: 'var(--bg-card-hover)',
    backdropFilter: 'var(--glass-blur)',
    padding: '18px 24px',
    borderRadius: 'var(--border-radius-md)',
    border: '1px solid var(--border-divider)',
    fontSize: '13px',
    textAlign: 'center',
    color: 'var(--text-primary)',
  },
  clearButton: {
    background: 'none',
    border: 'none',
    color: 'var(--text-muted)',
    cursor: 'pointer',
    fontSize: '16px',
    lineHeight: 1,
    padding: 0,
  },
  searchResults: {
    position: 'absolute',
    top: 'calc(100% + 6px)',
    left: 0,
    right: 0,
    zIndex: 50,
    maxHeight: '380px',
    overflowY: 'auto',
    borderRadius: 'var(--border-radius-sm)',
    border: '1px solid var(--border-divider)',
    background: 'var(--bg-card)',
    boxShadow: '0 8px 24px rgba(0,0,0,0.22)',
    fontSize: '12.5px',
  },
  resultGroup: {
    padding: '8px 12px 4px',
    fontSize: '10px',
    fontWeight: 800,
    letterSpacing: '0.5px',
    textTransform: 'uppercase',
    color: 'var(--text-muted)',
  },
  resultRow: {
    display: 'flex',
    flexDirection: 'column',
    gap: '2px',
    width: '100%',
    textAlign: 'left',
    padding: '8px 12px',
    background: 'transparent',
    border: 'none',
    borderBottom: '1px solid var(--border-divider)',
    color: 'var(--text-primary)',
    cursor: 'pointer',
    fontFamily: 'inherit',
    fontSize: '12.5px',
  },
  resultMeta: { color: 'var(--text-secondary)', fontSize: '11.5px', textTransform: 'none' },
  panel: {
    position: 'absolute',
    top: '12px',
    right: '12px',
    bottom: '12px',
    width: 'min(360px, calc(100% - 24px))',
    overflowY: 'auto',
    padding: '14px 16px',
    display: 'flex',
    flexDirection: 'column',
    gap: '12px',
    background: 'var(--bg-card)',
    borderRadius: 'var(--border-radius-md)',
    border: '1px solid var(--border-divider)',
    boxShadow: 'var(--shadow-premium)',
    color: 'var(--text-primary)',
  },
  kindLabel: {
    fontSize: '10px',
    fontWeight: 800,
    letterSpacing: '0.5px',
    textTransform: 'uppercase',
    color: 'var(--color-primary)',
  },
  panelTitle: { fontSize: '15px', fontWeight: 800, overflowWrap: 'anywhere' },
  panelClose: {
    border: 'none',
    background: 'transparent',
    fontSize: '22px',
    lineHeight: 1,
    cursor: 'pointer',
    color: 'var(--text-muted)',
  },
  panelSection: {
    display: 'flex',
    flexDirection: 'column',
    gap: '6px',
    paddingTop: '10px',
    borderTop: '1px solid var(--border-divider)',
    fontSize: '12.5px',
  },
  sectionTitle: { fontSize: '12px', fontWeight: 800, color: 'var(--text-primary)' },
  dateInput: {
    padding: '6px 8px',
    borderRadius: 'var(--border-radius-sm)',
    border: '1px solid var(--border-divider)',
    background: 'var(--bg-app)',
    color: 'var(--text-primary)',
    fontSize: '12px',
    fontFamily: 'inherit',
  },
  linkButton: {
    background: 'none',
    border: 'none',
    padding: 0,
    color: 'var(--color-primary)',
    fontWeight: 700,
    cursor: 'pointer',
    fontFamily: 'inherit',
    fontSize: '12.5px',
    textAlign: 'left',
    textDecoration: 'none',
  },
  statGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(2, 1fr)',
    gap: '8px',
  },
  flagRow: {
    display: 'flex',
    flexDirection: 'column',
    gap: '2px',
    width: '100%',
    textAlign: 'left',
    padding: '7px 10px',
    background: 'var(--bg-app)',
    border: '1px solid var(--border-divider)',
    borderLeft: '4px solid',
    borderRadius: 'var(--border-radius-sm)',
    color: 'var(--text-primary)',
    cursor: 'pointer',
    fontFamily: 'inherit',
    fontSize: '12px',
  },
  pinTag: {
    marginTop: '3px',
    padding: '1px 6px',
    borderRadius: '6px',
    background: 'rgba(15,23,42,0.85)',
    color: '#fff',
    fontSize: '10px',
    fontWeight: 700,
    whiteSpace: 'nowrap',
  },
  statLabel: {
    fontSize: '9.5px',
    fontWeight: 800,
    letterSpacing: '0.5px',
    color: 'var(--text-muted)',
    textTransform: 'uppercase',
  },
  statValue: { fontSize: '13px', fontWeight: 700, marginTop: '2px' },
  missingKey: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '32px',
  },
  pre: {
    background: 'var(--bg-app)',
    border: '1px solid var(--border-divider)',
    borderRadius: 'var(--border-radius-sm)',
    padding: '10px 14px',
    fontSize: '12px',
    margin: '12px 0',
    textAlign: 'left',
    overflowX: 'auto',
  },
};
