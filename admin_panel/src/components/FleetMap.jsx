import React, { useState, useEffect, useMemo, useCallback, useRef } from 'react';
import { APIProvider, Map, AdvancedMarker, useMap } from '@vis.gl/react-google-maps';
import { supabase } from '../supabase';

const MAPS_API_KEY = import.meta.env.VITE_GOOGLE_MAPS_API_KEY || '';
const MAP_ID = import.meta.env.VITE_GOOGLE_MAPS_MAP_ID || 'DEMO_MAP_ID';

// Accra. Only the opening camera position — it is replaced as soon as any
// rider reports a fix.
const FALLBACK_CENTER = { lat: 5.6037, lng: -0.187 };

// A rider whose last fix is older than this is treated as offline on the map.
// Well past the 5s upload cadence the app uses, so it only trips on a real gap.
const STALE_AFTER_MS = 90 * 1000;

/**
 * Live fleet map. Every rider carrying a GPS fix is plotted from
 * riders.current_lat / current_lng and moved over Supabase Realtime, which is
 * the same feed the customer's tracking screen and the rider's own navigation
 * screen read from.
 */
export default function FleetMap() {
  const [riders, setRiders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedId, setSelectedId] = useState(null);
  const [filter, setFilter] = useState('all');

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
      .subscribe();

    return () => {
      mounted = false;
      supabase.removeChannel(channel);
    };
  }, []);

  const isStale = useCallback(
    (rider) => !rider.lastUpdate || Date.now() - rider.lastUpdate.getTime() > STALE_AFTER_MS,
    []
  );

  const locatedRiders = useMemo(
    () =>
      riders.filter(
        (r) => typeof r.lat === 'number' && typeof r.lng === 'number'
      ),
    [riders]
  );

  const visibleRiders = useMemo(() => {
    if (filter === 'live') return locatedRiders.filter((r) => !isStale(r));
    if (filter === 'stale') return locatedRiders.filter((r) => isStale(r));
    return locatedRiders;
  }, [locatedRiders, filter, isStale]);

  const selectedRider = visibleRiders.find((r) => r.id === selectedId) || null;

  const liveCount = locatedRiders.filter((r) => !isStale(r)).length;
  const noLocationCount = riders.length - locatedRiders.length;

  if (!MAPS_API_KEY) {
    return <MissingKeyNotice />;
  }

  return (
    <div style={styles.page}>
      <header style={styles.header}>
        <div>
          <h1 style={styles.title}>Live Fleet Map</h1>
          <p style={styles.subtitle}>
            Rider positions stream in over Realtime as their devices report.
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
              {visibleRiders.map((rider) => (
                <AdvancedMarker
                  key={rider.id}
                  position={{ lat: rider.lat, lng: rider.lng }}
                  onClick={() => setSelectedId(rider.id)}
                  title={rider.fullName}
                >
                  <RiderPin
                    rider={rider}
                    stale={isStale(rider)}
                    selected={rider.id === selectedId}
                  />
                </AdvancedMarker>
              ))}
            </Map>
          </APIProvider>
        )}

        {selectedRider && (
          <RiderCard
            rider={selectedRider}
            stale={isStale(selectedRider)}
            onClose={() => setSelectedId(null)}
          />
        )}

        {!loading && visibleRiders.length === 0 && (
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

function RiderPin({ rider, stale, selected }) {
  const color = stale ? 'var(--color-accent)' : 'var(--color-success)';

  return (
    <div
      style={{
        position: 'relative',
        transform: selected ? 'scale(1.15)' : 'scale(1)',
        transition: 'transform 0.2s ease',
      }}
    >
      <div
        style={{
          width: '34px',
          height: '34px',
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
  );
}

function RiderCard({ rider, stale, onClose }) {
  return (
    <div style={styles.card}>
      <button style={styles.cardClose} onClick={onClose} aria-label="Close">
        ×
      </button>
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
        {rider.photoUrl ? (
          <img src={rider.photoUrl} alt="" style={styles.avatar} />
        ) : (
          <div style={{ ...styles.avatar, ...styles.avatarFallback }}>
            {rider.fullName.charAt(0)}
          </div>
        )}
        <div style={{ minWidth: 0 }}>
          <div style={styles.cardName}>{rider.fullName}</div>
          <div style={styles.cardMeta}>
            {rider.vehicleType} · ★ {rider.rating.toFixed(1)}
          </div>
        </div>
      </div>

      <div style={styles.statRow}>
        <Stat label="Speed" value={`${Math.round(rider.speed)} km/h`} />
        <Stat label="Heading" value={`${Math.round(rider.heading)}°`} />
        <Stat
          label="Updated"
          value={formatAgo(rider.lastUpdate)}
          tone={stale ? 'var(--color-accent)' : 'var(--color-success)'}
        />
      </div>

      {stale && (
        <div style={styles.staleNote}>
          Last fix is over a minute old — this is their last known position, not
          where they are now.
        </div>
      )}

      {rider.phone && (
        <a href={`tel:${rider.phone}`} style={styles.callLink}>
          Call {rider.phone}
        </a>
      )}
    </div>
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
  const seconds = Math.floor((Date.now() - date.getTime()) / 1000);
  if (seconds < 60) return 'Just now';
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} h ago`;
  return date.toLocaleDateString();
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
    minHeight: '460px',
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
  card: {
    position: 'absolute',
    bottom: '16px',
    left: '16px',
    width: '278px',
    padding: '16px',
    background: 'var(--bg-card-hover)',
    backdropFilter: 'var(--glass-blur)',
    borderRadius: 'var(--border-radius-md)',
    border: '1px solid var(--border-divider)',
    boxShadow: 'var(--shadow-premium)',
  },
  cardClose: {
    position: 'absolute',
    top: '8px',
    right: '10px',
    border: 'none',
    background: 'transparent',
    fontSize: '20px',
    lineHeight: 1,
    cursor: 'pointer',
    color: 'var(--text-muted)',
  },
  avatar: {
    width: '42px',
    height: '42px',
    borderRadius: '50%',
    objectFit: 'cover',
    flexShrink: 0,
  },
  avatarFallback: {
    background: 'var(--color-primary)',
    color: '#fff',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontWeight: 700,
  },
  cardName: {
    fontSize: '14px',
    fontWeight: 700,
    color: 'var(--text-primary)',
    whiteSpace: 'nowrap',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
  },
  cardMeta: { fontSize: '12px', color: 'var(--text-secondary)' },
  statRow: {
    display: 'grid',
    gridTemplateColumns: 'repeat(3, 1fr)',
    gap: '8px',
    marginTop: '14px',
  },
  statLabel: {
    fontSize: '9.5px',
    fontWeight: 800,
    letterSpacing: '0.5px',
    color: 'var(--text-muted)',
    textTransform: 'uppercase',
  },
  statValue: { fontSize: '13px', fontWeight: 700, marginTop: '2px' },
  staleNote: {
    marginTop: '12px',
    fontSize: '11.5px',
    lineHeight: 1.5,
    color: 'var(--color-accent)',
  },
  callLink: {
    display: 'block',
    marginTop: '12px',
    textAlign: 'center',
    padding: '8px',
    borderRadius: 'var(--border-radius-sm)',
    background: 'var(--color-primary)',
    color: '#fff',
    fontSize: '12.5px',
    fontWeight: 600,
    textDecoration: 'none',
  },
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
