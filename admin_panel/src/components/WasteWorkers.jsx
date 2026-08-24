import React, { useState, useEffect } from 'react';
import { supabase } from '../supabase';

const SPECIALTY_LABELS = {
  waste: 'Waste Clearing',
  gutter: 'Gutter Clearing',
  both: 'Waste & Gutter',
};

export default function WasteWorkers() {
  const [workers, setWorkers] = useState([]);
  const [assignedCounts, setAssignedCounts] = useState({});
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    let mounted = true;

    const fetchWorkers = async () => {
      const { data, error: err } = await supabase
        .from('waste_workers')
        .select('*')
        .order('created_at', { ascending: false });
      if (mounted && !err) setWorkers(data);
      if (mounted) setLoading(false);
      if (err) console.warn('Waste workers fetch:', err);
    };
    fetchWorkers();

    const channel = supabase
      .channel('waste_workers_admin_changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'waste_workers' }, fetchWorkers)
      .subscribe();

    return () => {
      mounted = false;
      supabase.removeChannel(channel);
    };
  }, []);

  // Open-report load per worker, so the admin can dispatch to whoever is free.
  useEffect(() => {
    let mounted = true;

    const fetchCounts = async () => {
      const { data, error: err } = await supabase
        .from('incident_reports')
        .select('assigned_worker_id')
        .in('status', ['assigned', 'in_progress']);
      if (mounted && !err) {
        const counts = {};
        data.forEach((r) => {
          if (r.assigned_worker_id) counts[r.assigned_worker_id] = (counts[r.assigned_worker_id] || 0) + 1;
        });
        setAssignedCounts(counts);
      }
    };
    fetchCounts();

    const channel = supabase
      .channel('waste_workers_load_changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'incident_reports' }, fetchCounts)
      .subscribe();

    return () => {
      mounted = false;
      supabase.removeChannel(channel);
    };
  }, []);

  const openAdd = () => {
    setEditing(null);
    setError(null);
    setShowModal(true);
  };

  const openEdit = (worker) => {
    setEditing(worker);
    setError(null);
    setShowModal(true);
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setSaving(true);
    setError(null);
    const form = new FormData(e.target);
    const payload = {
      full_name: form.get('full_name').trim(),
      phone: form.get('phone')?.trim() || null,
      zone: form.get('zone')?.trim() || null,
      specialty: form.get('specialty'),
      status: form.get('status'),
      notes: form.get('notes')?.trim() || null,
    };

    const { error: err } = editing
      ? await supabase.from('waste_workers').update(payload).eq('id', editing.id)
      : await supabase.from('waste_workers').insert(payload);

    if (err) {
      setError(err.message);
    } else {
      setShowModal(false);
      setEditing(null);
    }
    setSaving(false);
  };

  const handleToggleStatus = async (worker) => {
    const next = worker.status === 'active' ? 'inactive' : 'active';
    const { error: err } = await supabase.from('waste_workers').update({ status: next }).eq('id', worker.id);
    if (err) alert('Failed to update worker: ' + err.message);
  };

  const handleDelete = async (worker) => {
    if (!window.confirm(`Remove ${worker.full_name} from the roster? Reports already assigned to them stay on record.`)) return;
    const { error: err } = await supabase.from('waste_workers').delete().eq('id', worker.id);
    if (err) alert('Failed to remove worker: ' + err.message);
  };

  const activeCount = workers.filter((w) => w.status === 'active').length;
  const onJobCount = workers.filter((w) => (assignedCounts[w.id] || 0) > 0).length;

  return (
    <div className="page-content">
      {/* ── Page Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>Waste Workers</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            The ground crew that clears reported dumps and choked gutters. Active workers appear in the
            assignment dropdown on Waste Reports.
          </p>
        </div>
        <button className="btn-primary" onClick={openAdd}>+ Add Worker</button>
      </div>

      <div className="metrics-grid">
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-primary)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Total Workers</span>
          <span className="metric-value" style={{ fontSize: '24px' }}>{workers.length}</span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-success)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Available</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-success)' }}>{activeCount}</span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-accent)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Currently On A Job</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-accent)' }}>{onJobCount}</span>
        </div>
      </div>

      {/* ── Roster ── */}
      {loading ? (
        <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--text-secondary)', fontSize: '14px' }}>
          Loading workers…
        </div>
      ) : workers.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '80px 20px' }}>
          <div style={{ fontSize: '48px', marginBottom: '16px' }}>🧹</div>
          <h3 style={{ fontSize: '16px', marginBottom: '8px' }}>No waste workers yet</h3>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginBottom: '20px' }}>
            Add your first worker so customer reports can be assigned to someone.
          </p>
          <button className="btn-primary" onClick={openAdd}>+ Add Worker</button>
        </div>
      ) : (
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <h3 style={{ fontSize: '16px' }}>Roster ({workers.length})</h3>
          <div className="table-container">
            <table className="custom-table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Phone</th>
                  <th>Zone</th>
                  <th>Specialty</th>
                  <th>Open Jobs</th>
                  <th>Status</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {workers.map((w) => (
                  <tr key={w.id}>
                    <td style={{ fontWeight: '700' }}>{w.full_name}</td>
                    <td style={{ color: 'var(--text-secondary)', fontSize: '12px' }}>{w.phone || '—'}</td>
                    <td style={{ color: 'var(--text-secondary)', fontSize: '12px' }}>{w.zone || '—'}</td>
                    <td style={{ fontSize: '12px' }}>{SPECIALTY_LABELS[w.specialty] || w.specialty}</td>
                    <td style={{ fontWeight: '700', color: (assignedCounts[w.id] || 0) > 0 ? 'var(--color-accent)' : 'var(--text-muted)' }}>
                      {assignedCounts[w.id] || 0}
                    </td>
                    <td>
                      <span className={`badge ${w.status === 'active' ? 'badge-active' : 'badge-pending'}`}>
                        {w.status.toUpperCase()}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '6px', justifyContent: 'flex-end' }}>
                        <button
                          className="btn-outline"
                          style={{ padding: '6px 10px', fontSize: '11px' }}
                          onClick={() => openEdit(w)}
                        >
                          Edit
                        </button>
                        <button
                          className="btn-outline"
                          style={{ padding: '6px 10px', fontSize: '11px' }}
                          onClick={() => handleToggleStatus(w)}
                        >
                          {w.status === 'active' ? 'Deactivate' : 'Activate'}
                        </button>
                        <button
                          className="btn-outline"
                          style={{ padding: '6px 10px', fontSize: '11px', color: 'var(--color-danger)' }}
                          onClick={() => handleDelete(w)}
                        >
                          Remove
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ── Add / Edit Modal ── */}
      {showModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>{editing ? 'Edit Worker' : 'Add Waste Worker'}</h3>
            <form onSubmit={handleSave} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div className="form-group">
                <label>Full Name</label>
                <input name="full_name" type="text" placeholder="e.g. Kofi Mensah" defaultValue={editing?.full_name || ''} required />
              </div>
              <div className="form-group">
                <label>Phone Number</label>
                <input name="phone" type="tel" placeholder="e.g. 024 123 4567" defaultValue={editing?.phone || ''} />
              </div>
              <div className="form-group">
                <label>Zone / Area</label>
                <input name="zone" type="text" placeholder="e.g. Labadi" defaultValue={editing?.zone || ''} />
              </div>
              <div className="form-group">
                <label>Specialty</label>
                <select name="specialty" defaultValue={editing?.specialty || 'both'}>
                  <option value="both">Waste &amp; Gutter</option>
                  <option value="waste">Waste Clearing</option>
                  <option value="gutter">Gutter Clearing</option>
                </select>
              </div>
              <div className="form-group">
                <label>Status</label>
                <select name="status" defaultValue={editing?.status || 'active'}>
                  <option value="active">Active — can be assigned reports</option>
                  <option value="inactive">Inactive — hidden from assignment</option>
                </select>
              </div>
              <div className="form-group">
                <label>Notes (optional)</label>
                <input name="notes" type="text" placeholder="e.g. Works mornings only" defaultValue={editing?.notes || ''} />
              </div>
              {error && (
                <p style={{ color: 'var(--color-danger)', fontSize: '12px' }}>{error}</p>
              )}
              <div className="modal-actions">
                <button type="button" className="btn-outline" onClick={() => setShowModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" disabled={saving}>
                  {saving ? 'Saving…' : editing ? 'Save Changes' : 'Add Worker'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
