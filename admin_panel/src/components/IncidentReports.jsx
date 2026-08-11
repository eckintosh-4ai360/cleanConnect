import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import {
  collection,
  onSnapshot,
  query,
  orderBy,
  doc,
  updateDoc,
  addDoc,
  serverTimestamp,
} from 'firebase/firestore';

export default function IncidentReports() {
  const [reports, setReports] = useState([]);
  const [riders, setRiders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('All');
  const [selectedReport, setSelectedReport] = useState(null);
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    const q = query(
      collection(db, 'incidentReports'),
      orderBy('createdAt', 'desc')
    );
    const unsub = onSnapshot(
      q,
      (snap) => {
        const docs = snap.docs.map((d) => ({
          id: d.id,
          ...d.data(),
          createdAt: d.data().createdAt?.toDate?.() ?? new Date(),
        }));
        setReports(docs);
        setLoading(false);
      },
      (err) => {
        console.warn('IncidentReports listener error:', err);
        setLoading(false);
      }
    );
    return () => unsub();
  }, []);

  // Merge 'riders' + 'users' (role === 'rider') the same way the Riders screen does,
  // so newly-registered riders show up in the assignment dropdown right away.
  useEffect(() => {
    let riderDocs = [];
    let userDocs = [];

    const updateCombined = () => {
      const map = new Map();
      userDocs.forEach((u) => {
        if ((u.role || '').toLowerCase() === 'rider') {
          map.set(u.id, {
            id: u.id,
            fullName: u.fullName || u.displayName || 'Rider',
            status: u.status || 'active',
          });
        }
      });
      riderDocs.forEach((r) => {
        const existing = map.get(r.id) || {};
        map.set(r.id, {
          id: r.id,
          fullName: r.fullName || r.displayName || existing.fullName || 'Rider',
          status: r.status || existing.status || 'active',
        });
      });
      setRiders(Array.from(map.values()));
    };

    const unsubRiders = onSnapshot(collection(db, 'riders'), (snap) => {
      riderDocs = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      updateCombined();
    });
    const unsubUsers = onSnapshot(collection(db, 'users'), (snap) => {
      userDocs = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      updateCombined();
    });

    return () => {
      unsubRiders();
      unsubUsers();
    };
  }, []);

  const filtered = reports.filter((r) => {
    if (filter === 'All') return true;
    if (filter === 'Pending') return r.status === 'pending';
    if (filter === 'Assigned') return r.status === 'assigned';
    if (filter === 'In Progress') return r.status === 'in_progress';
    if (filter === 'Resolved') return r.status === 'resolved';
    return true;
  });

  const pendingCount = reports.filter((r) => r.status === 'pending').length;
  const assignedCount = reports.filter((r) => r.status === 'assigned' || r.status === 'in_progress').length;
  const resolvedCount = reports.filter((r) => r.status === 'resolved').length;

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
    if (status === 'assigned') return 'badge-active';
    if (status === 'in_progress') return 'badge-active';
    if (status === 'resolved') return 'badge-active';
    return 'badge-pending';
  };

  const statusLabel = (status) => {
    if (status === 'in_progress') return 'IN PROGRESS';
    return (status || 'pending').toUpperCase();
  };

  const mapsUrl = (location) => {
    if (!location) return null;
    const parts = location.split(',');
    if (parts.length < 2) return null;
    const lat = parts[0].trim();
    const lng = parts[1].split('(')[0].trim();
    return `https://www.google.com/maps?q=${lat},${lng}`;
  };

  const handleAssign = async (report, riderId) => {
    if (!riderId) return;
    const rider = riders.find((r) => r.id === riderId);
    if (!rider) return;

    setActionLoading(true);
    try {
      const update = {
        assignedRiderId: rider.id,
        assignedRiderName: rider.fullName,
        status: 'assigned',
        updatedAt: serverTimestamp(),
      };

      await updateDoc(doc(db, 'incidentReports', report.id), update);

      if (report.reporterId) {
        try {
          await updateDoc(
            doc(db, 'customers', report.reporterId, 'incidentReports', report.id),
            update
          );
        } catch (_) {}
      }

      await addDoc(collection(db, 'riders', rider.id, 'notifications'), {
        title: 'New Report Assigned',
        message: `You've been assigned a new incident report: ${report.description?.slice(0, 80) || 'Waste/gutter issue'}`,
        type: 'incident_assigned',
        reportId: report.id,
        isRead: false,
        createdAt: serverTimestamp(),
      });

      setSelectedReport((prev) => (prev?.id === report.id ? { ...prev, ...update } : prev));
    } catch (err) {
      alert('Failed to assign worker: ' + err.message);
    }
    setActionLoading(false);
  };

  const handleUpdateStatus = async (report, newStatus) => {
    setActionLoading(true);
    try {
      const update = { status: newStatus, updatedAt: serverTimestamp() };
      await updateDoc(doc(db, 'incidentReports', report.id), update);
      if (report.reporterId) {
        try {
          await updateDoc(
            doc(db, 'customers', report.reporterId, 'incidentReports', report.id),
            update
          );
        } catch (_) {}
      }
      setSelectedReport((prev) => (prev?.id === report.id ? { ...prev, ...update } : prev));
    } catch (err) {
      alert('Failed to update status: ' + err.message);
    }
    setActionLoading(false);
  };

  const activeRiders = riders.filter((r) => r.status === 'active');

  return (
    <div className="page-content">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>Waste & Gutter Reports</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Incidents reported by customers via the mobile app — assign a worker to resolve them.
          </p>
        </div>
        <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
          {['All', 'Pending', 'Assigned', 'In Progress', 'Resolved'].map((f) => (
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
          <span className="metric-title" style={{ fontSize: '10px' }}>Awaiting Assignment</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-accent)' }}>{pendingCount}</span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-primary)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Being Worked On</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-primary)' }}>{assignedCount}</span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-success)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Resolved</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-success)' }}>{resolvedCount}</span>
        </div>
      </div>

      <div className="split-layout">
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <h3 style={{ fontSize: '16px' }}>All Reports ({filtered.length})</h3>
          <div className="table-container">
            <table className="custom-table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Reporter</th>
                  <th>Description</th>
                  <th>Location</th>
                  <th>Status</th>
                  <th>Submitted</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr><td colSpan="6" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>Loading reports...</td></tr>
                ) : filtered.length === 0 ? (
                  <tr>
                    <td colSpan="6" style={{ textAlign: 'center', color: 'var(--text-muted)', padding: '32px' }}>
                      {filter === 'Pending' ? 'No pending reports.' : 'No reports found.'}
                    </td>
                  </tr>
                ) : (
                  filtered.map((report) => (
                    <tr
                      key={report.id}
                      onClick={() => setSelectedReport(report)}
                      style={{ cursor: 'pointer', background: selectedReport?.id === report.id ? 'var(--border-divider)' : 'transparent' }}
                    >
                      <td style={{ fontWeight: '700', color: 'var(--color-primary)' }}>#{report.id.slice(0, 8).toUpperCase()}</td>
                      <td style={{ fontWeight: '600' }}>{report.reporterName ?? 'Customer'}</td>
                      <td style={{ maxWidth: '220px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {report.description ?? '—'}
                      </td>
                      <td style={{ color: 'var(--text-secondary)', fontSize: '12px' }}>{report.location ?? '—'}</td>
                      <td><span className={`badge ${statusBadgeClass(report.status)}`}>{statusLabel(report.status)}</span></td>
                      <td style={{ color: 'var(--text-muted)', fontSize: '12px' }}>{formatRelative(report.createdAt)}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        {selectedReport ? (
          <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px', border: '1px solid rgba(2,132,199,0.2)', minWidth: '300px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div>
                <h4 style={{ fontSize: '15px', fontWeight: '800' }}>Report Detail</h4>
                <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '2px' }}>#{selectedReport.id.slice(0, 8).toUpperCase()}</p>
              </div>
              <span className={`badge ${statusBadgeClass(selectedReport.status)}`} style={{ fontSize: '11px' }}>
                {statusLabel(selectedReport.status)}
              </span>
            </div>

            {selectedReport.mediaUrl && (
              selectedReport.mediaType === 'video' ? (
                <video controls src={selectedReport.mediaUrl} style={{ width: '100%', borderRadius: '10px', maxHeight: '220px' }} />
              ) : (
                <img
                  src={selectedReport.mediaUrl}
                  alt="Incident"
                  style={{ width: '100%', borderRadius: '10px', maxHeight: '220px', objectFit: 'cover' }}
                />
              )
            )}

            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', background: 'var(--bg-app)', padding: '14px', borderRadius: '10px' }}>
              {[
                { label: 'Reporter', value: selectedReport.reporterName ?? '—' },
                { label: 'Contact', value: selectedReport.reporterPhone || 'Not provided' },
                { label: 'Description', value: selectedReport.description ?? '—' },
                {
                  label: 'Location',
                  value: selectedReport.location ?? '—',
                  link: mapsUrl(selectedReport.location),
                },
                { label: 'Submitted', value: formatDateTime(selectedReport.createdAt) },
                ...(selectedReport.assignedRiderName
                  ? [{ label: 'Assigned Worker', value: selectedReport.assignedRiderName }]
                  : []),
              ].map(({ label, value, link }) => (
                <div key={label}>
                  <span style={{ fontSize: '10px', textTransform: 'uppercase', fontWeight: '700', color: 'var(--text-muted)' }}>{label}</span>
                  <p style={{ fontSize: '12px', fontWeight: '600', marginTop: '3px' }}>
                    {value}
                    {link && (
                      <a href={link} target="_blank" rel="noreferrer" style={{ marginLeft: '8px', color: 'var(--color-primary)' }}>
                        View on map
                      </a>
                    )}
                  </p>
                </div>
              ))}
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginTop: 'auto' }}>
              {(selectedReport.status === 'pending' || selectedReport.status === 'assigned') && (
                <div>
                  <span style={{ fontSize: '10px', textTransform: 'uppercase', fontWeight: '700', color: 'var(--text-muted)' }}>
                    {selectedReport.status === 'pending' ? 'Assign Worker' : 'Reassign Worker'}
                  </span>
                  <select
                    defaultValue=""
                    disabled={actionLoading}
                    onChange={(e) => handleAssign(selectedReport, e.target.value)}
                    style={{ width: '100%', marginTop: '6px', padding: '10px', borderRadius: '8px' }}
                  >
                    <option value="" disabled>Select a worker...</option>
                    {activeRiders.map((r) => (
                      <option key={r.id} value={r.id}>{r.fullName}</option>
                    ))}
                  </select>
                </div>
              )}
              {selectedReport.status === 'in_progress' && (
                <button className="btn-primary" style={{ justifyContent: 'center' }} disabled={actionLoading} onClick={() => handleUpdateStatus(selectedReport, 'resolved')}>
                  {actionLoading ? 'Updating...' : 'Mark as Resolved'}
                </button>
              )}
              {selectedReport.status === 'resolved' && (
                <p style={{ textAlign: 'center', fontSize: '12px', color: 'var(--text-muted)' }}>
                  This report has been resolved.
                </p>
              )}
            </div>
          </div>
        ) : (
          <div className="card-glass" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: '12px', color: 'var(--text-muted)', minWidth: '300px' }}>
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
              <path d="M12 9v4M12 17h.01" />
              <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
            </svg>
            <p style={{ fontSize: '13px', textAlign: 'center' }}>Select a report to view full details and assign a worker.</p>
          </div>
        )}
      </div>
    </div>
  );
}
