import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  addDoc,
  updateDoc,
  deleteDoc,
  doc,
  serverTimestamp,
} from 'firebase/firestore';

const STATUS_OPTIONS = ['Active', 'In Service', 'Repair Needed'];

export default function Maintenance() {
  const [vehicles, setVehicles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const q = query(collection(db, 'vehicles'), orderBy('createdAt', 'desc'));
    const unsub = onSnapshot(
      q,
      (snap) => {
        setVehicles(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
        setLoading(false);
      },
      (err) => {
        console.warn('Vehicles listener:', err);
        setLoading(false);
      }
    );
    return () => unsub();
  }, []);

  const handleRegisterVehicle = async (e) => {
    e.preventDefault();
    setSaving(true);
    const formData = new FormData(e.target);
    try {
      await addDoc(collection(db, 'vehicles'), {
        name: formData.get('name'),
        type: formData.get('type'),
        zone: formData.get('zone'),
        status: 'Active',
        load: 0,
        createdAt: serverTimestamp(),
      });
      setShowAddModal(false);
      e.target.reset();
    } catch (err) {
      alert('Failed to register vehicle: ' + err.message);
    }
    setSaving(false);
  };

  const handleSetStatus = async (vehicleId, status) => {
    try {
      await updateDoc(doc(db, 'vehicles', vehicleId), {
        status,
        updatedAt: serverTimestamp(),
      });
    } catch (err) {
      alert('Failed to update status: ' + err.message);
    }
  };

  const handleRemoveVehicle = async (vehicleId) => {
    if (!window.confirm('Remove this fleet asset?')) return;
    try {
      await deleteDoc(doc(db, 'vehicles', vehicleId));
    } catch (err) {
      alert('Failed to remove vehicle: ' + err.message);
    }
  };

  const displayId = (id) => `VH-${id.slice(0, 6).toUpperCase()}`;
  const displayLoad = (load) => `${load ?? 0}%`;

  const activeCount = vehicles.filter((v) => v.status === 'Active').length;
  const inServiceCount = vehicles.filter((v) => v.status === 'In Service').length;
  const repairCount = vehicles.filter((v) => v.status === 'Repair Needed').length;

  return (
    <div className="page-content">
      {/* ── Page Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>Maintenance & Fleet Assets</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Track waste disposal vehicles, register new chassis, and manage regional service zones.
          </p>
        </div>
        <button className="btn-primary" onClick={() => setShowAddModal(true)}>
          + Add Fleet Asset
        </button>
      </div>

      {/* ── Fleet Summary ── */}
      {!loading && vehicles.length > 0 && (
        <div className="metrics-grid">
          <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-primary)' }}>
            <span className="metric-title" style={{ fontSize: '10px' }}>Total Fleet</span>
            <span className="metric-value" style={{ fontSize: '24px' }}>{vehicles.length}</span>
          </div>
          <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-success)' }}>
            <span className="metric-title" style={{ fontSize: '10px' }}>Active</span>
            <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-success)' }}>{activeCount}</span>
          </div>
          <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-info)' }}>
            <span className="metric-title" style={{ fontSize: '10px' }}>In Service</span>
            <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-info)' }}>{inServiceCount}</span>
          </div>
          <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-danger)' }}>
            <span className="metric-title" style={{ fontSize: '10px' }}>Repair Needed</span>
            <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-danger)' }}>{repairCount}</span>
          </div>
        </div>
      )}

      {/* ── Fleet List ── */}
      <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
        <h3 style={{ fontSize: '16px' }}>Fleet Vehicles Inventory</h3>
        <div className="table-container">
          <table className="custom-table">
            <thead>
              <tr>
                <th>Vehicle ID</th>
                <th>Asset Name</th>
                <th>Category</th>
                <th>Assigned Zone</th>
                <th>Current Load</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan="7" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>Loading fleet…</td></tr>
              ) : vehicles.length === 0 ? (
                <tr><td colSpan="7" style={{ textAlign: 'center', color: 'var(--text-muted)', padding: '24px' }}>
                  No fleet assets registered yet. Click "Add Fleet Asset" to register the first vehicle.
                </td></tr>
              ) : (
                vehicles.map((v) => (
                  <tr key={v.id}>
                    <td style={{ fontWeight: '700', color: 'var(--color-primary)' }}>{displayId(v.id)}</td>
                    <td style={{ fontWeight: '600' }}>{v.name}</td>
                    <td>{v.type}</td>
                    <td>{v.zone}</td>
                    <td>{displayLoad(v.load)}</td>
                    <td>
                      <select
                        value={v.status}
                        onChange={(e) => handleSetStatus(v.id, e.target.value)}
                        className={`badge ${
                          v.status === 'Active' || v.status === 'In Service' ? 'badge-active' : 'badge-defaulter'
                        }`}
                        style={{
                          border: 'none',
                          cursor: 'pointer',
                          fontWeight: 'bold',
                          fontFamily: 'inherit',
                          appearance: 'none',
                          WebkitAppearance: 'none',
                          outline: 'none',
                        }}
                      >
                        {STATUS_OPTIONS.map((s) => (
                          <option key={s} value={s}>{s}</option>
                        ))}
                      </select>
                    </td>
                    <td>
                      <button
                        onClick={() => handleRemoveVehicle(v.id)}
                        title="Remove asset"
                        style={{
                          background: 'none',
                          border: 'none',
                          cursor: 'pointer',
                          color: 'var(--text-secondary)',
                          fontSize: '14px',
                          padding: '2px 4px',
                          borderRadius: '4px',
                          lineHeight: 1,
                        }}
                      >
                        ✕
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── Add Fleet Asset Modal ── */}
      {showAddModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>Register Fleet Asset</h3>
            <form onSubmit={handleRegisterVehicle} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div className="form-group">
                <label>Vehicle Model / Name</label>
                <input name="name" type="text" placeholder="e.g. Isuzu Compactor 150" required />
              </div>
              <div className="form-group">
                <label>Asset Type</label>
                <select name="type">
                  <option value="Truck">Truck</option>
                  <option value="Tricycle">Tricycle</option>
                  <option value="Van">Cargo Van</option>
                </select>
              </div>
              <div className="form-group">
                <label>Assigned Zone</label>
                <input name="zone" type="text" placeholder="e.g. East Legon" required />
              </div>
              <div className="modal-actions">
                <button type="button" className="btn-outline" onClick={() => setShowAddModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" disabled={saving}>
                  {saving ? 'Adding…' : 'Add Fleet Asset'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
