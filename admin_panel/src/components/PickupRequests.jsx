import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import {
  collection,
  onSnapshot,
  query,
  orderBy,
  doc,
  updateDoc,
  serverTimestamp,
} from 'firebase/firestore';

export default function PickupRequests() {
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('All');
  const [selectedReq, setSelectedReq] = useState(null);
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    const q = query(
      collection(db, 'pickupRequests'),
      orderBy('createdAt', 'desc')
    );
    const unsub = onSnapshot(
      q,
      (snap) => {
        const docs = snap.docs.map((d) => ({
          id: d.id,
          ...d.data(),
          createdAt: d.data().createdAt?.toDate?.() ?? new Date(),
          date: d.data().date?.toDate?.() ?? null,
        }));
        setRequests(docs);
        setLoading(false);
      },
      (err) => {
        console.warn('PickupRequests listener error:', err);
        setLoading(false);
      }
    );
    return () => unsub();
  }, []);

  const filtered = requests.filter((r) => {
    if (filter === 'All') return true;
    if (filter === 'Pending') return r.status === 'pending';
    if (filter === 'Confirmed') return r.status === 'confirmed';
    if (filter === 'Completed') return r.status === 'completed';
    if (filter === 'Rejected') return r.status === 'rejected';
    return true;
  });

  const pendingCount = requests.filter((r) => r.status === 'pending').length;
  const confirmedCount = requests.filter((r) => r.status === 'confirmed').length;
  const completedCount = requests.filter((r) => r.status === 'completed').length;

  const formatDateTime = (date) => {
    if (!date) return '—';
    return (
      date.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) +
      ' @ ' +
      date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
    );
  };

  const formatRelative = (date) => {
    if (!date) return '—';
    const diff = Math.floor((Date.now() - date.getTime()) / 1000);
    if (diff < 60) return `${diff}s ago`;
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return `${Math.floor(diff / 86400)}d ago`;
  };

  const statusBadgeClass = (status) => {
    if (status === 'pending') return 'badge-pending';
    if (status === 'confirmed') return 'badge-active';
    if (status === 'completed') return 'badge-active';
    if (status === 'rejected') return 'badge-defaulter';
    return 'badge-pending';
  };

  const handleUpdateStatus = async (requestId, newStatus) => {
    setActionLoading(true);
    try {
      const update = { status: newStatus, updatedAt: serverTimestamp() };
      if (newStatus === 'completed') {
        update.completedAt = serverTimestamp();
      }

      await updateDoc(doc(db, 'pickupRequests', requestId), update);

      const req = requests.find((r) => r.id === requestId);
      if (req?.customerId) {
        try {
          await updateDoc(
            doc(db, 'customers', req.customerId, 'pickupRequests', requestId),
            update
          );
        } catch (_) {}

        if (newStatus === 'completed') {
          try {
            await updateDoc(doc(db, 'customers', req.customerId), {
              lastPickupCompletedAt: serverTimestamp(),
            });
          } catch (_) {}
        }
      }

      if (selectedReq?.id === requestId) {
        setSelectedReq((prev) => ({ ...prev, status: newStatus }));
      }
    } catch (err) {
      alert('Failed to update status: ' + err.message);
    }
    setActionLoading(false);
  };

  return (
    <div className="page-content">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>Customer Pickup Requests</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Real-time log of all pickup requests submitted by customers via the mobile app.
          </p>
        </div>
        <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
          {['All', 'Pending', 'Confirmed', 'Completed', 'Rejected'].map((f) => (
            <button
              key={f}
              className={`btn-outline ${filter === f ? 'btn-primary' : ''}`}
              style={{ padding: '8px 14px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}
              onClick={() => setFilter(f)}
            >
              {f}
              {f === 'Pending' && pendingCount > 0 && (
                <span
                  style={{
                    background: 'var(--color-danger)',
                    color: 'white',
                    fontSize: '10px',
                    fontWeight: 'bold',
                    padding: '1px 6px',
                    borderRadius: '8px',
                  }}
                >
                  {pendingCount}
                </span>
              )}
            </button>
          ))}
        </div>
      </div>

      <div className="metrics-grid">
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-accent)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Awaiting Action</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-accent)' }}>{pendingCount}</span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-primary)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Confirmed Pickups</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-primary)' }}>{confirmedCount}</span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-success)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Completed</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-success)' }}>{completedCount}</span>
        </div>
      </div>

      <div className="split-layout">
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <h3 style={{ fontSize: '16px' }}>All Requests ({filtered.length})</h3>
          <div className="table-container">
            <table className="custom-table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Customer</th>
                  <th>Bin Types</th>
                  <th>Pickup Date</th>
                  <th>Time Slot</th>
                  <th>Status</th>
                  <th>Submitted</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr><td colSpan="7" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>Loading pickup requests...</td></tr>
                ) : filtered.length === 0 ? (
                  <tr>
                    <td colSpan="7" style={{ textAlign: 'center', color: 'var(--text-muted)', padding: '32px' }}>
                      {filter === 'Pending' ? 'No pending pickup requests.' : 'No requests found.'}
                    </td>
                  </tr>
                ) : (
                  filtered.map((req) => (
                    <tr
                      key={req.id}
                      onClick={() => setSelectedReq(req)}
                      style={{ cursor: 'pointer', background: selectedReq?.id === req.id ? 'var(--border-divider)' : 'transparent' }}
                    >
                      <td style={{ fontWeight: '700', color: 'var(--color-primary)' }}>#{req.id.slice(0, 8).toUpperCase()}</td>
                      <td style={{ fontWeight: '600' }}>{req.customerName ?? 'Customer'}</td>
                      <td style={{ textTransform: 'capitalize' }}>{Array.isArray(req.binTypes) ? req.binTypes.join(', ') : 'General'}</td>
                      <td>{req.date ? req.date.toLocaleDateString('en-GB', { day: '2-digit', month: 'short' }) : '—'}</td>
                      <td style={{ color: 'var(--text-secondary)', fontSize: '12px' }}>{req.timeSlot ?? '—'}</td>
                      <td><span className={`badge ${statusBadgeClass(req.status)}`}>{req.status?.toUpperCase() ?? 'PENDING'}</span></td>
                      <td style={{ color: 'var(--text-muted)', fontSize: '12px' }}>{formatRelative(req.createdAt)}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        {selectedReq ? (
          <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px', border: '1px solid rgba(2,132,199,0.2)', minWidth: '280px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div>
                <h4 style={{ fontSize: '15px', fontWeight: '800' }}>Request Detail</h4>
                <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '2px' }}>#{selectedReq.id.slice(0, 8).toUpperCase()}</p>
              </div>
              <span className={`badge ${statusBadgeClass(selectedReq.status)}`} style={{ fontSize: '11px' }}>
                {selectedReq.status?.toUpperCase() ?? 'PENDING'}
              </span>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', background: 'var(--bg-app)', padding: '14px', borderRadius: '10px' }}>
              {[
                { label: 'Customer', value: selectedReq.customerName ?? '—' },
                { label: 'Bin Types', value: Array.isArray(selectedReq.binTypes) ? selectedReq.binTypes.join(', ') : 'General' },
                { label: 'Pickup Date', value: selectedReq.date ? selectedReq.date.toLocaleDateString('en-GB', { weekday: 'long', day: '2-digit', month: 'long', year: 'numeric' }) : '—' },
                { label: 'Time Slot', value: selectedReq.timeSlot ?? '—' },
                { label: 'Location', value: selectedReq.location ?? '—' },
                { label: 'Instructions', value: selectedReq.instructions || 'None provided' },
                { label: 'Submitted', value: formatDateTime(selectedReq.createdAt) },
                ...(selectedReq.discountAppliedPercentage > 0
                  ? [{ label: 'Discount Applied', value: `${selectedReq.discountAppliedPercentage}% (rider delay bonus)` }]
                  : []),
                ...(selectedReq.surchargeAppliedPercentage > 0
                  ? [{ label: 'Surcharge Applied', value: `${selectedReq.surchargeAppliedPercentage}% (late payment)` }]
                  : []),
              ].map(({ label, value }) => (
                <div key={label}>
                  <span style={{ fontSize: '10px', textTransform: 'uppercase', fontWeight: '700', color: 'var(--text-muted)' }}>{label}</span>
                  <p style={{ fontSize: '12px', fontWeight: '600', marginTop: '3px' }}>{value}</p>
                </div>
              ))}
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginTop: 'auto' }}>
              {selectedReq.status === 'pending' && (
                <>
                  <button className="btn-primary" style={{ justifyContent: 'center' }} disabled={actionLoading} onClick={() => handleUpdateStatus(selectedReq.id, 'confirmed')}>
                    {actionLoading ? 'Updating...' : 'Confirm Pickup'}
                  </button>
                  <button className="btn-danger" style={{ justifyContent: 'center' }} disabled={actionLoading} onClick={() => handleUpdateStatus(selectedReq.id, 'rejected')}>
                    {actionLoading ? 'Updating...' : 'Reject Request'}
                  </button>
                </>
              )}
              {selectedReq.status === 'confirmed' && (
                <button className="btn-primary" style={{ justifyContent: 'center' }} disabled={actionLoading} onClick={() => handleUpdateStatus(selectedReq.id, 'completed')}>
                  {actionLoading ? 'Updating...' : 'Mark as Completed'}
                </button>
              )}
              {(selectedReq.status === 'completed' || selectedReq.status === 'rejected') && (
                <p style={{ textAlign: 'center', fontSize: '12px', color: 'var(--text-muted)' }}>
                  This request has been {selectedReq.status}.
                </p>
              )}
            </div>
          </div>
        ) : (
          <div className="card-glass" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: '12px', color: 'var(--text-muted)', minWidth: '280px' }}>
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
              <path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2" />
              <rect x="9" y="3" width="6" height="4" rx="2" />
              <line x1="9" y1="12" x2="15" y2="12" />
              <line x1="9" y1="16" x2="13" y2="16" />
            </svg>
            <p style={{ fontSize: '13px', textAlign: 'center' }}>Select a request to view full details and take action.</p>
          </div>
        )}
      </div>
    </div>
  );
}
