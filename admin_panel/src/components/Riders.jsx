import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import {
  collection,
  onSnapshot,
  doc,
  updateDoc,
  addDoc,
  serverTimestamp,
  query,
  orderBy,
  where,
} from 'firebase/firestore';

export default function Riders() {
  const [riders, setRiders] = useState([]);
  const [selectedRider, setSelectedRider] = useState(null);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    let riderDocs = [];
    let userDocs = [];

    const updateCombined = () => {
      const map = new Map();

      userDocs.forEach((u) => {
        const role = (u.role || '').toLowerCase();
        if (role === 'rider') {
          map.set(u.id, {
            id: u.id,
            fullName: u.fullName || u.displayName || 'Rider',
            email: u.email || '—',
            phoneNumber: u.phoneNumber || u.phone || '—',
            vehicleType: u.vehicleType || 'Motorbike',
            licenseNumber: u.licenseNumber || 'DL-GH-20240312',
            nationalIdNumber: u.nationalIdNumber || 'GHA-0012345678',
            status: u.status || 'active',
            rating: u.rating || 5.0,
            totalCollections: u.totalCollections || 0,
            totalWeightKg: u.totalWeightKg || 0.0,
            earningsThisMonth: u.earningsThisMonth || 0.0,
            efficiencyScore: u.efficiencyScore || 100.0,
            ...u,
          });
        }
      });

      riderDocs.forEach((r) => {
        const existing = map.get(r.id) || {};
        map.set(r.id, {
          ...existing,
          ...r,
          fullName: r.fullName || r.displayName || existing.fullName || 'Rider',
        });
      });

      const merged = Array.from(map.values());
      setRiders(merged);
      if (merged.length > 0 && !selectedRider) {
        setSelectedRider(merged[0]);
      }
      setLoading(false);
    };

    const unsubRiders = onSnapshot(collection(db, 'riders'), (snap) => {
      riderDocs = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      updateCombined();
    }, (err) => {
      console.warn('Riders listener:', err);
      setLoading(false);
    });

    const unsubUsers = onSnapshot(collection(db, 'users'), (snap) => {
      userDocs = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      updateCombined();
    }, (err) => {
      console.warn('Users listener:', err);
      setLoading(false);
    });

    return () => {
      unsubRiders();
      unsubUsers();
    };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // Keep selectedRider in sync with live updates
  useEffect(() => {
    if (selectedRider) {
      const updated = riders.find(r => r.id === selectedRider.id);
      if (updated) setSelectedRider(updated);
    }
  }, [riders]); // eslint-disable-line react-hooks/exhaustive-deps

  const handleAddRider = async (e) => {
    e.preventDefault();
    const form = new FormData(e.target);
    setActionLoading(true);
    try {
      await addDoc(collection(db, 'riders'), {
        fullName: form.get('name'),
        phoneNumber: form.get('phone'),
        vehicleType: form.get('vehicle'),
        licenseNumber: form.get('license') || '',
        nationalIdNumber: '',
        email: form.get('email') || '',
        status: 'active',
        rating: 0,
        totalCollections: 0,
        totalWeightKg: 0,
        earningsThisMonth: 0,
        efficiencyScore: 0,
        createdAt: serverTimestamp(),
      });
      setShowAddModal(false);
    } catch (err) {
      alert('Failed to register rider: ' + err.message);
    }
    setActionLoading(false);
  };

  const handleSetRiderStatus = async (rider, status) => {
    try {
      await updateDoc(doc(db, 'riders', rider.id), {
        status,
        updatedAt: serverTimestamp(),
      });
      // Also sync users collection
      try {
        await updateDoc(doc(db, 'users', rider.id), {
          status,
          updatedAt: serverTimestamp(),
        });
      } catch (_) {}
    } catch (err) {
      alert('Failed to update rider status: ' + err.message);
    }
  };

  const handleUploadRiderPhoto = async (e) => {
    const file = e.target.files?.[0];
    if (!file || !selectedRider) return;

    const reader = new FileReader();
    reader.onload = async () => {
      const dataUrl = reader.result;
      try {
        await updateDoc(doc(db, 'riders', selectedRider.id), {
          photoUrl: dataUrl,
          profilePhotoUrl: dataUrl,
          updatedAt: serverTimestamp(),
        });
        try {
          await updateDoc(doc(db, 'users', selectedRider.id), {
            photoUrl: dataUrl,
            profilePhotoUrl: dataUrl,
            updatedAt: serverTimestamp(),
          });
        } catch (_) {}
        alert('Rider photo updated successfully!');
      } catch (err) {
        alert('Failed to update photo: ' + err.message);
      }
    };
    reader.readAsDataURL(file);
  };

  const activeCount = riders.filter(r => r.status === 'active').length;

  // Map positions for live riders (deterministic from index)
  const pinPositions = [
    { x: 120, y: 80 }, { x: 260, y: 140 }, { x: 80, y: 220 },
    { x: 310, y: 70 }, { x: 180, y: 200 }, { x: 340, y: 190 },
  ];
  const pinColors = ['#0284c7', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#06b6d4'];

  return (
    <div className="page-content">
      {/* ── Page Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>Rider Fleet Operations</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Track active drivers, manage vehicle registrations, and deploy new routes.
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
            {activeCount} / {riders.length} Active
          </span>
          <button className="btn-primary" onClick={() => setShowAddModal(true)}>
            + Register New Rider
          </button>
        </div>
      </div>

      {/* ── Main Split View ── */}
      <div className="split-layout">
        {/* Left: Riders List */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <h3 style={{ fontSize: '16px' }}>Driver Roster</h3>
          <div className="table-container">
            <table className="custom-table">
              <thead>
                <tr>
                  <th>Rider Name</th>
                  <th>Vehicle Info</th>
                  <th>Rating</th>
                  <th>Collections</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr><td colSpan="5" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>Loading riders...</td></tr>
                ) : riders.length === 0 ? (
                  <tr><td colSpan="5" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>No riders registered yet.</td></tr>
                ) : (
                  riders.map((r) => (
                    <tr
                      key={r.id}
                      onClick={() => setSelectedRider(r)}
                      style={{ cursor: 'pointer', background: selectedRider?.id === r.id ? 'var(--border-divider)' : 'transparent' }}
                    >
                      <td style={{ fontWeight: '700' }}>{r.fullName}</td>
                      <td style={{ fontSize: '12px' }}>{r.vehicleType}</td>
                      <td style={{ color: 'var(--color-accent)', fontWeight: '700' }}>
                        {r.rating > 0 ? `★ ${r.rating.toFixed(1)}` : '—'}
                      </td>
                      <td>{r.totalCollections ?? 0}</td>
                      <td>
                        <span
                          className={`badge ${r.status === 'active' ? 'badge-active' : r.status === 'disabled' ? 'badge-defaulter' : ''}`}
                          style={{ background: r.status === 'offline' ? 'rgba(0,0,0,0.05)' : '' }}
                        >
                          {r.status === 'active' ? 'Active' : r.status === 'disabled' ? 'Disabled' : 'Offline'}
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Right: Fleet Tracking Map + Details */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div>
            <h3 style={{ fontSize: '16px' }}>Live Fleet Tracking Map</h3>
            <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '4px' }}>
              Vector map of rider geographical coordinate updates.
            </p>
          </div>

          {/* SVG Map */}
          <div style={{ position: 'relative', width: '100%', height: '300px', background: 'var(--bg-app)', border: '1px solid var(--border-divider)', borderRadius: '12px', overflow: 'hidden' }}>
            <svg viewBox="0 0 400 300" width="100%" height="100%">
              {/* Grid lines */}
              {[100, 200, 300].map(x => (
                <line key={`vl-${x}`} x1={x} y1="0" x2={x} y2="300" stroke="var(--border-divider)" strokeWidth="1" strokeDasharray="4" />
              ))}
              {[100, 200].map(y => (
                <line key={`hl-${y}`} x1="0" y1={y} x2="400" y2={y} stroke="var(--border-divider)" strokeWidth="1" strokeDasharray="4" />
              ))}
              {/* Roads */}
              <path d="M 50 0 L 50 300 M 0 150 L 400 150 M 250 0 C 250 100, 320 200, 320 300" fill="none" stroke="var(--border-glass)" strokeWidth="8" />
              <path d="M 50 0 L 50 300 M 0 150 L 400 150 M 250 0 C 250 100, 320 200, 320 300" fill="none" stroke="var(--bg-sidebar)" strokeWidth="4" />
              {/* Live rider pins */}
              {riders.filter(r => r.status === 'active').map((r, i) => {
                const pos = pinPositions[i % pinPositions.length];
                const color = pinColors[i % pinColors.length];
                const isSelected = selectedRider?.id === r.id;
                return (
                  <g key={r.id} style={{ cursor: 'pointer' }} onClick={() => setSelectedRider(r)}>
                    <circle cx={pos.x} cy={pos.y} r={isSelected ? '14' : '10'} fill={color} opacity="0.25" />
                    <circle cx={pos.x} cy={pos.y} r="6" fill={color} stroke="white" strokeWidth="1.5" />
                    {isSelected && (
                      <foreignObject x={pos.x + 10} y={pos.y - 12} width="120" height="40">
                        <div style={{ background: 'var(--bg-sidebar)', padding: '2px 6px', fontSize: '9px', borderRadius: '4px', border: '1px solid var(--border-divider)', fontWeight: 'bold', color: 'var(--text-primary)' }}>
                          {r.fullName}
                        </div>
                      </foreignObject>
                    )}
                  </g>
                );
              })}
            </svg>
          </div>

          {/* Selected Rider Details */}
          {selectedRider && (
            <div style={{ padding: '16px', background: 'var(--bg-app)', borderRadius: '8px', display: 'flex', flexDirection: 'column', gap: '12px', fontSize: '12px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <div style={{ position: 'relative', width: '48px', height: '48px', cursor: 'pointer' }} onClick={() => document.getElementById(`rider-photo-input-${selectedRider.id}`)?.click()}>
                  <img
                    src={selectedRider.photoUrl || selectedRider.profilePhotoUrl || `https://api.dicebear.com/7.x/initials/svg?seed=${selectedRider.fullName}`}
                    alt={selectedRider.fullName}
                    style={{ width: '48px', height: '48px', borderRadius: '50%', objectFit: 'cover', border: '2px solid var(--color-primary)' }}
                  />
                  <div style={{ position: 'absolute', bottom: 0, right: 0, background: 'var(--color-primary)', borderRadius: '50%', padding: '2px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg>
                  </div>
                  <input
                    id={`rider-photo-input-${selectedRider.id}`}
                    type="file"
                    accept="image/*"
                    style={{ display: 'none' }}
                    onChange={handleUploadRiderPhoto}
                  />
                </div>
                <div>
                  <h4 style={{ fontSize: '14px', fontWeight: '800' }}>{selectedRider.fullName}</h4>
                  <p style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>{selectedRider.email || '—'}</p>
                </div>
              </div>
              {[
                { label: 'Phone Number', value: selectedRider.phoneNumber || '—' },
                { label: 'Vehicle', value: selectedRider.vehicleType || '—' },
                { label: 'License No.', value: selectedRider.licenseNumber || '—' },
                { label: 'Earnings This Month', value: selectedRider.earningsThisMonth ? `GHS ${selectedRider.earningsThisMonth.toFixed(2)}` : '—' },
                { label: 'Total Collections', value: selectedRider.totalCollections ?? 0 },
                { label: 'Efficiency Score', value: selectedRider.efficiencyScore ? `${selectedRider.efficiencyScore}%` : '—' },
              ].map(({ label, value }) => (
                <div key={label} style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--border-divider)', paddingBottom: '6px' }}>
                  <span style={{ fontWeight: 'bold' }}>{label}:</span>
                  <span>{value}</span>
                </div>
              ))}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontWeight: 'bold' }}>Status:</span>
                <span style={{ color: selectedRider.status === 'active' ? 'var(--color-success)' : selectedRider.status === 'disabled' ? 'var(--color-danger)' : 'var(--text-muted)', fontWeight: 'bold' }}>
                  {selectedRider.status === 'active' ? 'Active' : selectedRider.status === 'disabled' ? 'Disabled' : 'Offline'}
                </span>
              </div>

              {/* ── Status Control ── */}
              <div style={{ background: 'var(--bg-sidebar)', borderRadius: '10px', padding: '12px', display: 'flex', flexDirection: 'column', gap: '8px', marginTop: '4px' }}>
                <span style={{ fontSize: '10px', textTransform: 'uppercase', fontWeight: '800', color: 'var(--text-muted)', letterSpacing: '0.5px' }}>Set Rider Status</span>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '6px' }}>
                  <button
                    onClick={() => handleSetRiderStatus(selectedRider, 'active')}
                    style={{
                      padding: '8px 0',
                      borderRadius: '8px',
                      border: '2px solid',
                      borderColor: selectedRider.status === 'active' ? 'var(--color-success)' : 'var(--border-divider)',
                      background: selectedRider.status === 'active' ? 'rgba(16,185,129,0.12)' : 'transparent',
                      color: selectedRider.status === 'active' ? 'var(--color-success)' : 'var(--text-secondary)',
                      fontWeight: '800',
                      fontSize: '12px',
                      cursor: 'pointer',
                      transition: 'all 0.2s',
                    }}
                  >
                    ✓ Active
                  </button>
                  <button
                    onClick={() => handleSetRiderStatus(selectedRider, 'disabled')}
                    style={{
                      padding: '8px 0',
                      borderRadius: '8px',
                      border: '2px solid',
                      borderColor: selectedRider.status === 'disabled' ? 'var(--color-danger)' : 'var(--border-divider)',
                      background: selectedRider.status === 'disabled' ? 'rgba(239,68,68,0.12)' : 'transparent',
                      color: selectedRider.status === 'disabled' ? 'var(--color-danger)' : 'var(--text-secondary)',
                      fontWeight: '800',
                      fontSize: '12px',
                      cursor: 'pointer',
                      transition: 'all 0.2s',
                    }}
                  >
                    ✕ Disabled
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* ── Add Rider Modal ── */}
      {showAddModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>Register New Rider</h3>
            <form onSubmit={handleAddRider} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div className="form-group">
                <label>Full Name</label>
                <input name="name" type="text" placeholder="e.g. John Doe" required />
              </div>
              <div className="form-group">
                <label>Email Address</label>
                <input name="email" type="email" placeholder="e.g. rider@cleanconnect.com" />
              </div>
              <div className="form-group">
                <label>Mobile Number</label>
                <input name="phone" type="text" placeholder="e.g. 0244000000" required />
              </div>
              <div className="form-group">
                <label>Vehicle Type</label>
                <select name="vehicle">
                  <option value="Motorbike">Motorbike</option>
                  <option value="Tricycle">Tricycle</option>
                  <option value="Compact Van">Compact Van</option>
                  <option value="Truck">Truck</option>
                </select>
              </div>
              <div className="form-group">
                <label>License Number</label>
                <input name="license" type="text" placeholder="e.g. DL-GH-20240312" />
              </div>
              <div className="modal-actions">
                <button type="button" className="btn-outline" onClick={() => setShowAddModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" disabled={actionLoading}>
                  {actionLoading ? 'Registering...' : 'Register Rider'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
