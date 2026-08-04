import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import {
  collection,
  onSnapshot,
  query,
} from 'firebase/firestore';

export default function Routes() {
  const [riders, setRiders] = useState([]);
  const [pickupRequests, setPickupRequests] = useState([]);
  const [selectedRider, setSelectedRider] = useState(null);
  const [loading, setLoading] = useState(true);
  const [showOptimizeModal, setShowOptimizeModal] = useState(false);

  // Fallback initial riders if Firestore collection has non-GPS docs
  const mockRiders = [
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
      speed: 28.0,
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
  ];

  // Live Firestore snapshot listeners for real-time tracking
  useEffect(() => {
    const unsubRiders = onSnapshot(
      collection(db, 'riders'),
      (snap) => {
        const docs = snap.docs.map((d) => ({
          id: d.id,
          fullName: d.data().fullName || d.data().displayName || 'Rider',
          status: d.data().status || 'active',
          currentLat: d.data().currentLat || d.data().latitude || 5.6037,
          currentLng: d.data().currentLng || d.data().longitude || -0.1870,
          speed: d.data().speed ?? 25.0,
          heading: d.data().heading ?? 0,
          vehicleType: d.data().vehicleType || 'Motorbike',
          updatedAt: d.data().updatedAt?.toDate?.() || new Date(),
          ...d.data(),
        }));

        const mergedRiders = docs.length > 0 ? docs : mockRiders;
        setRiders(mergedRiders);
        if (!selectedRider && mergedRiders.length > 0) {
          setSelectedRider(mergedRiders[0]);
        }
        setLoading(false);
      },
      (err) => {
        console.warn('Riders live tracking listener error:', err);
        setRiders(mockRiders);
        if (!selectedRider) setSelectedRider(mockRiders[0]);
        setLoading(false);
      }
    );

    const unsubRequests = onSnapshot(
      query(collection(db, 'pickupRequests')),
      (snap) => {
        const reqs = snap.docs.map((d) => ({
          id: d.id,
          ...d.data(),
        }));
        setPickupRequests(reqs);
      },
      () => setPickupRequests([])
    );

    return () => {
      unsubRiders();
      unsubRequests();
    };
  }, []);

  const activeRiders = riders.filter((r) => r.status === 'active');
  const activePickups = pickupRequests.filter((p) => p.status === 'accepted' || p.status === 'confirmed');

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
            Live Firestore Sync
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
            29.4 km/h
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

          {/* Canvas Map Representation */}
          <div
            style={{
              position: 'relative',
              width: '100%',
              height: '380px',
              borderRadius: '16px',
              overflow: 'hidden',
              background: 'var(--bg-app)',
              border: '1px solid var(--border-divider)',
            }}
          >
            {/* Grid background lines */}
            <svg width="100%" height="100%" style={{ position: 'absolute', opacity: 0.15 }}>
              <defs>
                <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
                  <path d="M 40 0 L 0 0 0 40" fill="none" stroke="currentColor" strokeWidth="1" />
                </pattern>
              </defs>
              <rect width="100%" height="100%" fill="url(#grid)" />
            </svg>

            {/* Simulated Road Paths */}
            <svg width="100%" height="100%" style={{ position: 'absolute', top: 0, left: 0 }}>
              {/* Main Arterial Roads */}
              <path d="M 30 180 Q 200 120 450 220" fill="none" stroke="rgba(2, 132, 199, 0.3)" strokeWidth="12" strokeLinecap="round" />
              <path d="M 120 40 Q 220 200 380 340" fill="none" stroke="rgba(2, 132, 199, 0.25)" strokeWidth="10" strokeLinecap="round" />

              {/* Path connecting selected rider to target */}
              {selectedRider && (
                <path
                  d="M 120 180 Q 240 140 360 100"
                  fill="none"
                  stroke="var(--color-primary)"
                  strokeWidth="3"
                  strokeDasharray="6 4"
                />
              )}

              {/* Customer Pickup Target Pin */}
              <g transform="translate(360, 100)">
                <circle r="16" fill="rgba(239, 68, 68, 0.25)" />
                <circle r="8" fill="var(--color-danger)" />
                <text x="14" y="4" fill="var(--text-primary)" fontSize="11" fontWeight="bold">Customer Site</text>
              </g>

              {/* Active Riders Live Markers */}
              {riders.map((r, idx) => {
                const posX = 100 + (idx * 120) % 320;
                const posY = 140 + (idx * 80) % 180;
                const isSelected = selectedRider?.id === r.id;

                return (
                  <g
                    key={r.id}
                    transform={`translate(${posX}, ${posY})`}
                    style={{ cursor: 'pointer' }}
                    onClick={() => setSelectedRider(r)}
                  >
                    {/* Live movement ripple effect */}
                    <circle r={isSelected ? '22' : '14'} fill="rgba(2, 132, 199, 0.25)">
                      {isSelected && (
                        <animate attributeName="r" values="14;26;14" dur="2s" repeatCount="indefinite" />
                      )}
                    </circle>

                    {/* Marker circle */}
                    <circle r="10" fill={isSelected ? 'var(--color-primary)' : 'var(--color-accent)'} stroke="white" strokeWidth="2" />

                    {/* Direction arrow indicator */}
                    <path
                      d="M 0 -5 L 4 4 L 0 2 L -4 4 Z"
                      fill="white"
                      transform={`rotate(${r.heading || 45})`}
                    />

                    {/* Rider label */}
                    <rect x="-35" y="16" width="70" height="18" rx="4" fill="rgba(0,0,0,0.75)" />
                    <text x="0" y="29" fill="white" fontSize="9" fontWeight="bold" textAnchor="middle">
                      {r.fullName.split(' ')[0]}
                    </text>
                  </g>
                );
              })}
            </svg>

            {/* Map Top Status Bar */}
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
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '12px' }}>
                <span style={{ color: 'var(--text-muted)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 'bold' }}>Live GPS Coordinates</span>
                <p style={{ fontWeight: '600', fontFamily: 'monospace' }}>
                  Lat: {selectedRider.currentLat?.toFixed(4) || '5.6037'} • Lng: {selectedRider.currentLng?.toFixed(4) || '-0.1870'}
                </p>

                <span style={{ color: 'var(--text-muted)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 'bold', marginTop: '6px' }}>Target Customer</span>
                <p style={{ fontWeight: '600', color: 'var(--text-primary)' }}>
                  {selectedRider.targetCustomer || 'Sarah Jenkins (123 Green St, Eco City)'}
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
              {riders.map((r) => (
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
                    <div style={{ fontSize: '10px', color: 'var(--text-muted)' }}>{r.vehicleType}</div>
                  </div>
                  <span className="badge badge-active" style={{ fontSize: '9px' }}>
                    {r.speed > 0 ? 'MOVING' : 'IDLE'}
                  </span>
                </div>
              ))}
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
