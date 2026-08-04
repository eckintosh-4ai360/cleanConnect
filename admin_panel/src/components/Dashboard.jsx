import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import {
  collection,
  query,
  orderBy,
  limit,
  onSnapshot,
  where,
  getDocs,
} from 'firebase/firestore';

export default function Dashboard() {
  const [topRiders, setTopRiders] = useState([]);
  const [recentCollections, setRecentCollections] = useState([]);
  const [pickupRequests, setPickupRequests] = useState([]);
  const [metrics, setMetrics] = useState({
    totalRevenue: 0,
    activeRiders: 0,
    wasteCollectedKg: 0,
    co2SavedKg: 0,
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // ── 0. Real-time Pickup Requests ──────────────────────────────────────
    const requestsQ = query(
      collection(db, 'pickupRequests'),
      orderBy('createdAt', 'desc'),
      limit(5)
    );
    const unsubRequests = onSnapshot(
      requestsQ,
      (snap) => {
        setPickupRequests(
          snap.docs.map((doc) => ({
            id: doc.id,
            ...doc.data(),
            createdAt: doc.data().createdAt?.toDate?.() ?? new Date(),
          }))
        );
        setLoading(false);
      },
      () => { setPickupRequests([]); setLoading(false); }
    );

    // ── 1. Real-time: Recent Collections ──────────────────────────────────
    const collectionsQ = query(
      collection(db, 'collections'),
      orderBy('collectedAt', 'desc'),
      limit(10)
    );
    const unsubCollections = onSnapshot(collectionsQ, (snap) => {
      const logs = snap.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
        collectedAt: doc.data().collectedAt?.toDate?.() ?? new Date(),
      }));
      setRecentCollections(logs);

      const totalWeight = logs.reduce((sum, c) => sum + (c.weightKg ?? 0), 0);
      const totalCO2 = logs.reduce((sum, c) => sum + (c.carbonOffset ?? 0), 0);
      setMetrics((prev) => ({
        ...prev,
        wasteCollectedKg: parseFloat(totalWeight.toFixed(1)),
        co2SavedKg: parseFloat(totalCO2.toFixed(1)),
      }));
      setLoading(false);
    });

    // ── 2. Real-time: Active Riders Count ─────────────────────────────────
    const ridersQ = query(
      collection(db, 'riders'),
      where('status', '==', 'active')
    );
    const unsubRiders = onSnapshot(ridersQ, (snap) => {
      setMetrics((prev) => ({ ...prev, activeRiders: snap.size }));
    });

    // ── 3. Real-time: Top Riders by totalCollections ───────────────────────
    const topRidersQ = query(
      collection(db, 'riders'),
      orderBy('totalCollections', 'desc'),
      limit(4)
    );
    const unsubTopRiders = onSnapshot(topRidersQ, (snap) => {
      setTopRiders(
        snap.docs.map((doc) => ({
          id: doc.id,
          name: doc.data().fullName ?? 'Unknown',
          collections: doc.data().totalCollections ?? 0,
          rating: doc.data().rating ?? 0,
          avatar: doc.data().photoUrl ?? `https://api.dicebear.com/7.x/initials/svg?seed=${doc.data().fullName}`,
        }))
      );
    });

    // ── 4. One-time: Total Revenue from payments ────────────────────────
    const fetchRevenue = async () => {
      try {
        const paidQ = query(
          collection(db, 'payments'),
          where('status', '==', 'paid')
        );
        const snap = await getDocs(paidQ);
        const total = snap.docs.reduce(
          (sum, d) => sum + (d.data().amount ?? 0),
          0
        );
        setMetrics((prev) => ({
          ...prev,
          totalRevenue: parseFloat(total.toFixed(2)),
        }));
      } catch (_) {}
    };
    fetchRevenue();

    return () => {
      unsubRequests();
      unsubCollections();
      unsubRiders();
      unsubTopRiders();
    };
  }, []);

  // ── Format helpers ──────────────────────────────────────────────────────
  const formatTime = (date) => {
    if (!date) return '—';
    const diff = Math.floor((Date.now() - date.getTime()) / 1000);
    if (diff < 60) return `${diff}s ago`;
    if (diff < 3600) return `${Math.floor(diff / 60)} min ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)} hr ago`;
    return `${Math.floor(diff / 86400)} days ago`;
  };

  const formatWeight = (kg) =>
    kg >= 1000 ? `${(kg / 1000).toFixed(1)} T` : `${kg} kg`;

  const formatCurrency = (val) =>
    val >= 1000 ? `$${(val / 1000).toFixed(1)}k` : `$${val.toFixed(2)}`;

  return (
    <div className="page-content">
      {/* ── Page Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>Overview Dashboard</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Real-time operations summary for CleanConnect logistics.
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--color-success)', display: 'inline-block' }} />
          <span style={{ fontSize: '11px', color: 'var(--text-secondary)', fontWeight: 'bold' }}>
            Live Firestore
          </span>
        </div>
      </div>

      {/* ── Key Performance Metrics ── */}
      <div className="metrics-grid">
        <div className="card-glass metric-card">
          <div className="metric-header">
            <span className="metric-title">Total Revenue</span>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--color-primary)" strokeWidth="2">
              <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
            </svg>
          </div>
          <span className="metric-value">{loading ? '—' : formatCurrency(metrics.totalRevenue)}</span>
          <div className="metric-footer trend-up">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <path d="M18 15l-6-6-6 6" />
            </svg>
            <span>From paid invoices</span>
          </div>
        </div>

        <div className="card-glass metric-card">
          <div className="metric-header">
            <span className="metric-title">Active Riders</span>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--color-info)" strokeWidth="2">
              <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 7a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" />
            </svg>
          </div>
          <span className="metric-value">{loading ? '—' : metrics.activeRiders}</span>
          <div className="metric-footer trend-up">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <path d="M18 15l-6-6-6 6" />
            </svg>
            <span>Currently on duty</span>
          </div>
        </div>

        <div className="card-glass metric-card">
          <div className="metric-header">
            <span className="metric-title">Waste Collected</span>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--color-success)" strokeWidth="2">
              <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16zM3.27 6.96L12 12.01l8.73-5.05M12 22.08V12" />
            </svg>
          </div>
          <span className="metric-value">
            {loading ? '—' : formatWeight(metrics.wasteCollectedKg)}
          </span>
          <div className="metric-footer trend-up">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <path d="M18 15l-6-6-6 6" />
            </svg>
            <span>From recent logs</span>
          </div>
        </div>

        <div className="card-glass metric-card">
          <div className="metric-header">
            <span className="metric-title">CO2 Saved</span>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--color-accent)" strokeWidth="2">
              <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
            </svg>
          </div>
          <span className="metric-value">
            {loading ? '—' : `${metrics.co2SavedKg} `}
            <span style={{ fontSize: '16px' }}>kg</span>
          </span>
          <div className="metric-footer trend-up">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <path d="M18 15l-6-6-6 6" />
            </svg>
            <span>Carbon offset total</span>
          </div>
        </div>
      </div>

      {/* ── Splitted Visual Graphs & Leaderboard ── */}
      <div className="split-layout">
        {/* Trend Graph (visual only - SVG) */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3 style={{ fontSize: '16px' }}>Growth & Volume Trends</h3>
            <div style={{ display: 'flex', gap: '8px' }}>
              <button className="btn-outline" style={{ padding: '6px 12px', fontSize: '11px' }}>Daily</button>
              <button className="btn-primary" style={{ padding: '6px 12px', fontSize: '11px' }}>Weekly</button>
              <button className="btn-outline" style={{ padding: '6px 12px', fontSize: '11px' }}>Monthly</button>
            </div>
          </div>
          <div style={{ position: 'relative', width: '100%', height: '240px', background: 'rgba(0,0,0,0.01)', borderRadius: '12px' }}>
            <svg viewBox="0 0 500 200" width="100%" height="100%" preserveAspectRatio="none">
              <defs>
                <linearGradient id="gradient-area" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="var(--color-primary)" stopOpacity="0.25" />
                  <stop offset="100%" stopColor="var(--color-primary)" stopOpacity="0" />
                </linearGradient>
              </defs>
              <path d="M 0 180 Q 80 120 150 140 T 300 70 T 450 40 T 500 30 L 500 200 L 0 200 Z" fill="url(#gradient-area)" />
              <path d="M 0 180 Q 80 120 150 140 T 300 70 T 450 40 T 500 30" fill="none" stroke="var(--color-primary)" strokeWidth="3" />
              <circle cx="150" cy="140" r="5" fill="var(--color-primary)" stroke="white" strokeWidth="2" />
              <circle cx="300" cy="70" r="5" fill="var(--color-primary)" stroke="white" strokeWidth="2" />
              <circle cx="450" cy="40" r="5" fill="var(--color-primary)" stroke="white" strokeWidth="2" />
            </svg>
            <div style={{ position: 'absolute', bottom: '10px', left: '20px', display: 'flex', justifyContent: 'space-between', right: '20px', fontSize: '11px', color: 'var(--text-secondary)' }}>
              <span>Mon</span><span>Tue</span><span>Wed</span><span>Thu</span><span>Fri</span><span>Sat</span><span>Sun</span>
            </div>
          </div>
        </div>

        {/* Top Performers - Live from Firestore */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <h3 style={{ fontSize: '16px' }}>Top Performing Riders</h3>
          {loading ? (
            <p style={{ color: 'var(--text-secondary)', fontSize: '13px' }}>Loading riders...</p>
          ) : topRiders.length === 0 ? (
            <p style={{ color: 'var(--text-secondary)', fontSize: '13px' }}>No riders registered yet.</p>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              {topRiders.map((rider, idx) => (
                <div key={idx} style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <img src={rider.avatar} alt={rider.name}
                    style={{ width: '40px', height: '40px', borderRadius: '50%', objectFit: 'cover' }}
                    onError={(e) => { e.target.src = `https://api.dicebear.com/7.x/initials/svg?seed=${rider.name}`; }}
                  />
                  <div style={{ flex: 1 }}>
                    <h4 style={{ fontSize: '13px', fontWeight: '700' }}>{rider.name}</h4>
                    <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                      {rider.collections} completed collections
                    </p>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '4px', background: 'rgba(245, 158, 11, 0.1)', padding: '2px 8px', borderRadius: '12px', color: 'var(--color-accent)', fontSize: '11px', fontWeight: '700' }}>
                    <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor">
                      <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
                    </svg>
                    {rider.rating.toFixed(1)}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* ── Customer Pickup Requests Log - Live ── */}
      <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
        <h3 style={{ fontSize: '16px' }}>Live Customer Pickup Requests</h3>
        <div className="table-container">
          <table className="custom-table">
            <thead>
              <tr>
                <th>Request ID</th>
                <th>Customer</th>
                <th>Bin Types</th>
                <th>Time Slot & Location</th>
                <th>Status</th>
                <th>Requested At</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan="6" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>Loading...</td></tr>
              ) : pickupRequests.length === 0 ? (
                <tr><td colSpan="6" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>No pickup requests submitted yet.</td></tr>
              ) : (
                pickupRequests.map((req) => (
                  <tr key={req.id}>
                    <td style={{ fontWeight: '700', color: 'var(--color-primary)' }}>#{req.id.slice(0, 8).toUpperCase()}</td>
                    <td style={{ fontWeight: '700' }}>{req.customerName ?? 'Customer'}</td>
                    <td>{Array.isArray(req.binTypes) ? req.binTypes.join(', ') : 'General'}</td>
                    <td>{req.location ?? '—'} ({req.timeSlot ?? 'Flexible'})</td>
                    <td>
                      <span className={`badge ${req.status === 'pending' ? 'badge-pending' : 'badge-active'}`}>
                        {req.status?.toUpperCase() ?? 'PENDING'}
                      </span>
                    </td>
                    <td style={{ color: 'var(--text-secondary)' }}>{formatTime(req.createdAt)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── Recent Collections Log - Live ── */}
      <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
        <h3 style={{ fontSize: '16px' }}>Recent Collections Logs</h3>
        <div className="table-container">
          <table className="custom-table">
            <thead>
              <tr>
                <th>Collection ID</th>
                <th>Collection Site</th>
                <th>Rider</th>
                <th>Weight Captured</th>
                <th>Status</th>
                <th>Time Stamp</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan="6" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>Loading...</td></tr>
              ) : recentCollections.length === 0 ? (
                <tr><td colSpan="6" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>No collections recorded yet.</td></tr>
              ) : (
                recentCollections.map((log) => (
                  <tr key={log.id}>
                    <td style={{ fontWeight: '700', color: 'var(--color-primary)' }}>#{log.id.slice(0, 8).toUpperCase()}</td>
                    <td>{log.customerName ?? log.address ?? '—'}</td>
                    <td>{log.riderName ?? '—'}</td>
                    <td>{log.weightKg ? `${log.weightKg} kg` : '—'}</td>
                    <td>
                      <span className={`badge ${log.status === 'completed' ? 'badge-active' : 'badge-pending'}`}>
                        {log.status ?? 'pending'}
                      </span>
                    </td>
                    <td style={{ color: 'var(--text-secondary)' }}>{formatTime(log.collectedAt)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
