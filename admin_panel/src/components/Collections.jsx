import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import {
  collection,
  onSnapshot,
  query,
  orderBy,
  where,
} from 'firebase/firestore';

export default function Collections() {
  const [collections, setCollections] = useState([]);
  const [filter, setFilter] = useState('All');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, 'collections'), orderBy('collectedAt', 'desc'));
    const unsub = onSnapshot(q, (snap) => {
      setCollections(
        snap.docs.map((d) => ({
          id: d.id,
          ...d.data(),
          collectedAt: d.data().collectedAt?.toDate?.() ?? null,
        }))
      );
      setLoading(false);
    });
    return () => unsub();
  }, []);

  const filteredLogs = collections.filter((c) => {
    if (filter === 'All') return true;
    if (filter === 'Completed') return c.status === 'completed';
    if (filter === 'Pending') return c.status !== 'completed';
    return true;
  });

  const formatDateTime = (date) => {
    if (!date) return '—';
    return date.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) +
      ' @ ' + date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
  };

  const completedCount = collections.filter(c => c.status === 'completed').length;
  const totalWeight = collections.reduce((sum, c) => sum + (c.weightKg ?? 0), 0);
  const totalOffset = collections.reduce((sum, c) => sum + (c.carbonOffset ?? 0), 0);

  return (
    <div className="page-content">
      {/* ── Page Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>Waste Collections History</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Real-time QR code receipts, weight audits, and carbon offset logs.
          </p>
        </div>
        <div style={{ display: 'flex', gap: '8px' }}>
          {['All', 'Completed', 'Pending'].map((f) => (
            <button
              key={f}
              className={`btn-outline ${filter === f ? 'btn-primary' : ''}`}
              style={{ padding: '8px 16px', fontSize: '12px' }}
              onClick={() => setFilter(f)}
            >
              {f}
            </button>
          ))}
        </div>
      </div>

      {/* ── Summary Metrics ── */}
      <div className="metrics-grid">
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-primary)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Total Collections</span>
          <span className="metric-value" style={{ fontSize: '24px' }}>{collections.length}</span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-success)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Total Weight Captured</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-success)' }}>
            {totalWeight.toFixed(1)} kg
          </span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-info)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Carbon Offset Saved</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-info)' }}>
            {totalOffset.toFixed(1)} kg CO₂
          </span>
        </div>
      </div>

      {/* ── Collections Table ── */}
      <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
        <h3 style={{ fontSize: '16px' }}>Collection Audits ({completedCount} Completed)</h3>
        <div className="table-container">
          <table className="custom-table">
            <thead>
              <tr>
                <th>Job ID</th>
                <th>Customer / Site</th>
                <th>Assigned Rider</th>
                <th>Bin Type</th>
                <th>Audited Weight</th>
                <th>Offset Saved</th>
                <th>QR Verified</th>
                <th>Date & Time</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan="9" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>Loading collections...</td></tr>
              ) : filteredLogs.length === 0 ? (
                <tr><td colSpan="9" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>No collection records found.</td></tr>
              ) : (
                filteredLogs.map((log) => (
                  <tr key={log.id}>
                    <td style={{ fontWeight: '700', color: 'var(--color-primary)' }}>#{log.id.slice(0, 8).toUpperCase()}</td>
                    <td style={{ fontWeight: '600' }}>{log.customerName ?? log.address ?? '—'}</td>
                    <td>{log.riderName ?? '—'}</td>
                    <td style={{ textTransform: 'capitalize' }}>{log.binType ?? '—'}</td>
                    <td>{log.weightKg != null ? `${log.weightKg} kg` : '—'}</td>
                    <td style={{ color: 'var(--color-success)', fontWeight: 'bold' }}>
                      {log.carbonOffset != null ? `${log.carbonOffset} kg` : '—'}
                    </td>
                    <td>
                      <span style={{ display: 'flex', alignItems: 'center', gap: '6px', color: log.qrVerified ? 'var(--color-success)' : 'var(--text-muted)', fontSize: '12px', fontWeight: 'bold' }}>
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                          {log.qrVerified
                            ? <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14M22 4L12 14.01l-3-3" />
                            : (<><circle cx="12" cy="12" r="10" /><line x1="12" y1="8" x2="12" y2="12" /><line x1="12" y1="16" x2="12.01" y2="16" /></>)
                          }
                        </svg>
                        {log.qrVerified ? 'Verified' : 'Bypassed'}
                      </span>
                    </td>
                    <td style={{ color: 'var(--text-secondary)' }}>{formatDateTime(log.collectedAt)}</td>
                    <td>
                      <span className={`badge ${log.status === 'completed' ? 'badge-active' : 'badge-pending'}`}>
                        {log.status ?? 'pending'}
                      </span>
                    </td>
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
