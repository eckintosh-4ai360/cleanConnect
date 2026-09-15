import React, { useState, useEffect } from 'react';
import { supabase } from '../supabase';
import { formatDateTime } from '../timezone';

const STATUS_OPTIONS = ['Active', 'In Service', 'Repair Needed'];
const ASSET_TYPES = ['Motorbike', 'Tricycle', 'Truck', 'Van'];

export default function Maintenance() {
  const [vehicles, setVehicles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [saving, setSaving] = useState(false);
  const [riders, setRiders] = useState([]);
  const [assigningId, setAssigningId] = useState(null);
  const [historyVehicle, setHistoryVehicle] = useState(null);
  const [history, setHistory] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(false);

  useEffect(() => {
    let mounted = true;

    const fetchVehicles = async () => {
      const { data, error } = await supabase
        .from('vehicles')
        .select('*')
        .order('created_at', { ascending: false });
      if (mounted && !error) setVehicles(data);
      if (mounted) setLoading(false);
      if (error) console.warn('Vehicles fetch:', error);
    };
    fetchVehicles();

    const channel = supabase
      .channel('vehicles_admin_changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'vehicles' }, fetchVehicles)
      .subscribe();

    const fetchRiders = async () => {
      const { data, error } = await supabase
        .from('riders')
        .select('id, status, profiles(full_name, phone_number)');
      if (mounted && !error) {
        setRiders(
          data
            .map((r) => ({ id: r.id, status: r.status, fullName: r.profiles?.full_name || 'Rider', phone: r.profiles?.phone_number }))
            .sort((a, b) => a.fullName.localeCompare(b.fullName))
        );
      }
      if (error) console.warn('Riders fetch:', error);
    };
    fetchRiders();

    return () => {
      mounted = false;
      supabase.removeChannel(channel);
    };
  }, []);

  const riderName = (riderId) => riders.find((r) => r.id === riderId)?.fullName || 'Rider';

  // Goes through admin_assign_vehicle so a rider who already holds another
  // bike is moved off it, and the hand-over lands in the assignment history.
  const handleAssign = async (vehicle, riderId) => {
    const nextRider = riderId || null;
    if (nextRider === (vehicle.assigned_rider_id || null)) return;

    const current = vehicle.assigned_rider_id ? riderName(vehicle.assigned_rider_id) : null;
    const otherBike = nextRider ? vehicles.find((v) => v.assigned_rider_id === nextRider && v.id !== vehicle.id) : null;
    const label = vehicle.plate_number || vehicle.name;
    const message = !nextRider
      ? `Take ${label} back from ${current}? Tracking for this bike stops on their phone.`
      : otherBike
        ? `${riderName(nextRider)} already has ${otherBike.plate_number || otherBike.name}. Move them to ${label} instead?`
        : current
          ? `Move ${label} from ${current} to ${riderName(nextRider)}?`
          : `Assign ${label} to ${riderName(nextRider)}? Their app will share this bike's location at all times while it is assigned.`;
    if (!window.confirm(message)) return;

    setAssigningId(vehicle.id);
    const { error } = await supabase.rpc('admin_assign_vehicle', {
      p_vehicle_id: vehicle.id,
      p_rider_id: nextRider,
    });
    if (error) alert('Failed to assign bike: ' + error.message);
    setAssigningId(null);
  };

  const openHistory = async (vehicle) => {
    setHistoryVehicle(vehicle);
    setHistory([]);
    setHistoryLoading(true);
    const { data, error } = await supabase
      .from('vehicle_assignments')
      .select('id, rider_id, assigned_at, returned_at, assigned_by')
      .eq('vehicle_id', vehicle.id)
      .order('assigned_at', { ascending: false })
      .limit(100);
    if (error) alert('Failed to load assignment history: ' + error.message);
    setHistory(error ? [] : data);
    setHistoryLoading(false);
  };

  const handleRegisterVehicle = async (e) => {
    e.preventDefault();
    setSaving(true);
    const formData = new FormData(e.target);
    const plate = (formData.get('plate_number') || '').trim();
    const { error } = await supabase.from('vehicles').insert({
      name: formData.get('name'),
      type: formData.get('type'),
      zone: formData.get('zone'),
      plate_number: plate ? plate.toUpperCase() : null,
      status: 'Active',
      load: 0,
    });
    if (error) {
      alert(
        error.code === '23505'
          ? `A vehicle with plate number ${plate.toUpperCase()} is already registered.`
          : 'Failed to register vehicle: ' + error.message
      );
    } else {
      setShowAddModal(false);
      e.target.reset();
    }
    setSaving(false);
  };

  const handleSetStatus = async (vehicleId, status) => {
    const { error } = await supabase.from('vehicles').update({ status }).eq('id', vehicleId);
    if (error) alert('Failed to update status: ' + error.message);
  };

  const handleRemoveVehicle = async (vehicleId) => {
    if (!window.confirm('Remove this fleet asset?')) return;
    const { error } = await supabase.from('vehicles').delete().eq('id', vehicleId);
    if (error) alert('Failed to remove vehicle: ' + error.message);
  };

  const displayId = (id) => `VH-${id.slice(0, 6).toUpperCase()}`;

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
            Register company bikes and vehicles, assign each to a rider, and see who has had which bike. Assigned bikes are tracked on the Live Fleet Map.
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
                <th>Plate No.</th>
                <th>Asset Name</th>
                <th>Category</th>
                <th>Zone</th>
                <th>Assigned Rider</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan="8" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>Loading fleet…</td></tr>
              ) : vehicles.length === 0 ? (
                <tr><td colSpan="8" style={{ textAlign: 'center', color: 'var(--text-muted)', padding: '24px' }}>
                  No fleet assets registered yet. Click "Add Fleet Asset" to register the first vehicle.
                </td></tr>
              ) : (
                vehicles.map((v) => (
                  <tr key={v.id}>
                    <td style={{ fontWeight: '700', color: 'var(--color-primary)' }}>{displayId(v.id)}</td>
                    <td style={{ fontWeight: '700', whiteSpace: 'nowrap' }}>{v.plate_number || <span style={{ color: 'var(--text-muted)' }}>—</span>}</td>
                    <td style={{ fontWeight: '600' }}>{v.name}</td>
                    <td>{v.type}</td>
                    <td>{v.zone}</td>
                    <td>
                      <select
                        value={v.assigned_rider_id || ''}
                        disabled={assigningId === v.id}
                        onChange={(e) => handleAssign(v, e.target.value)}
                        aria-label={`Assign ${v.plate_number || v.name} to a rider`}
                        style={{
                          padding: '6px 8px',
                          borderRadius: 'var(--border-radius-sm)',
                          border: '1px solid var(--border-divider)',
                          background: 'var(--bg-app)',
                          color: 'var(--text-primary)',
                          fontSize: '12px',
                          maxWidth: '170px',
                        }}
                      >
                        <option value="">Unassigned</option>
                        {riders.map((r) => (
                          <option key={r.id} value={r.id}>
                            {r.fullName}
                            {vehicles.some((other) => other.assigned_rider_id === r.id && other.id !== v.id) ? ' (has a bike)' : ''}
                          </option>
                        ))}
                      </select>
                      {v.assigned_at && (
                        <div style={{ fontSize: '10.5px', color: 'var(--text-muted)', marginTop: '3px' }}>
                          since {formatDateTime(v.assigned_at)}
                        </div>
                      )}
                    </td>
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
                    <td style={{ whiteSpace: 'nowrap' }}>
                      <button
                        className="btn-outline"
                        style={{ padding: '5px 9px', fontSize: '11px', marginRight: '6px' }}
                        onClick={() => openHistory(v)}
                      >
                        History
                      </button>
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

      {/* ── Assignment History Modal ── */}
      {historyVehicle && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '560px' }}>
            <h3 style={{ fontSize: '18px' }}>
              Assignment history — {historyVehicle.plate_number || historyVehicle.name}
            </h3>
            <div className="table-container" style={{ maxHeight: '360px', overflowY: 'auto' }}>
              <table className="custom-table">
                <thead>
                  <tr>
                    <th>Rider</th>
                    <th>From</th>
                    <th>To</th>
                  </tr>
                </thead>
                <tbody>
                  {historyLoading ? (
                    <tr><td colSpan="3" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>Loading…</td></tr>
                  ) : history.length === 0 ? (
                    <tr><td colSpan="3" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>This bike has never been assigned.</td></tr>
                  ) : (
                    history.map((h) => (
                      <tr key={h.id}>
                        <td style={{ fontWeight: 600 }}>{riderName(h.rider_id)}</td>
                        <td>{formatDateTime(h.assigned_at)}</td>
                        <td>{h.returned_at ? formatDateTime(h.returned_at) : <span className="badge badge-active">CURRENT</span>}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
            <div className="modal-actions">
              <button className="btn-outline" onClick={() => setHistoryVehicle(null)}>Close</button>
            </div>
          </div>
        </div>
      )}

      {/* ── Add Fleet Asset Modal ── */}
      {showAddModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>Register Fleet Asset</h3>
            <form onSubmit={handleRegisterVehicle} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div className="form-group">
                <label>Vehicle Model / Name</label>
                <input name="name" type="text" placeholder="e.g. Haojue HJ125" required />
              </div>
              <div className="form-group">
                <label>Plate Number</label>
                <input name="plate_number" type="text" placeholder="e.g. M-24-GR 1234" required />
              </div>
              <div className="form-group">
                <label>Asset Type</label>
                <select name="type" defaultValue="Motorbike">
                  {ASSET_TYPES.map((t) => (
                    <option key={t} value={t}>{t}</option>
                  ))}
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
