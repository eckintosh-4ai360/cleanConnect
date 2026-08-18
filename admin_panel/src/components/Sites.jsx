import React, { useState, useEffect } from 'react';
import { supabase } from '../supabase';

export default function Sites() {
  const [sites, setSites] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let mounted = true;

    const fetchSites = async () => {
      const { data, error } = await supabase.from('garbage_sites').select('*');
      if (mounted && !error) setSites(data);
      if (mounted) setLoading(false);
      if (error) console.warn('Sites fetch:', error);
    };
    fetchSites();

    const channel = supabase
      .channel('garbage_sites_changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'garbage_sites' }, fetchSites)
      .subscribe();

    return () => {
      mounted = false;
      supabase.removeChannel(channel);
    };
  }, []);

  const handleAddSite = async (e) => {
    e.preventDefault();
    setSaving(true);
    const formData = new FormData(e.target);
    const { error } = await supabase.from('garbage_sites').insert({
      name: formData.get('name'),
      region: formData.get('region'),
      capacity: formData.get('capacity'),
      fill: 0,
      status: 'Normal',
      last_collected: null,
    });
    if (error) {
      console.error('Failed to add site:', error);
    } else {
      setShowAddModal(false);
      e.target.reset();
    }
    setSaving(false);
  };

  const handleDeleteSite = async (siteId) => {
    if (!window.confirm('Remove this site?')) return;
    await supabase.from('garbage_sites').delete().eq('id', siteId);
  };

  const formatDate = (ts) => {
    if (!ts) return 'Never';
    const d = new Date(ts);
    return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
  };

  return (
    <div className="page-content">
      {/* ── Page Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>Garbage Collection Sites</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Monitor bin capacity load, geo-locations, and dispatcher status values.
          </p>
        </div>
        <button className="btn-primary" onClick={() => setShowAddModal(true)}>
          + Create New Site
        </button>
      </div>

      {/* ── Body ── */}
      {loading ? (
        <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--text-secondary)', fontSize: '14px' }}>
          Loading sites…
        </div>
      ) : sites.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '80px 20px' }}>
          <div style={{ fontSize: '48px', marginBottom: '16px' }}>🗑️</div>
          <h3 style={{ fontSize: '16px', marginBottom: '8px' }}>No collection sites yet</h3>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginBottom: '20px' }}>
            Create your first garbage collection site to start tracking bin fill levels.
          </p>
          <button className="btn-primary" onClick={() => setShowAddModal(true)}>+ Create New Site</button>
        </div>
      ) : (
        <div className="metrics-grid">
          {sites.map((site) => {
            const fill = site.fill ?? 0;
            const isCritical = fill >= 80;
            return (
              <div
                key={site.id}
                className="card-glass"
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '16px',
                  border: isCritical ? '1px solid rgba(239, 68, 68, 0.2)' : '1px solid var(--border-glass)',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                  <div>
                    <h4 style={{ fontSize: '14px', fontWeight: '800' }}>{site.name}</h4>
                    <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                      {site.region}
                    </p>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <span className={`badge ${isCritical ? 'badge-defaulter' : 'badge-active'}`}>
                      {isCritical ? 'Critical' : 'Normal'}
                    </span>
                    <button
                      onClick={() => handleDeleteSite(site.id)}
                      title="Remove site"
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
                  </div>
                </div>

                {/* Fill Gauge */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '11px', fontWeight: 'bold' }}>
                    <span style={{ color: 'var(--text-secondary)' }}>Fill Load:</span>
                    <span style={{ color: isCritical ? 'var(--color-danger)' : 'var(--text-primary)' }}>{fill}%</span>
                  </div>
                  <div style={{ width: '100%', height: '8px', background: 'var(--bg-app)', borderRadius: '4px', overflow: 'hidden' }}>
                    <div
                      style={{
                        width: `${fill}%`,
                        height: '100%',
                        background: isCritical
                          ? 'linear-gradient(to right, var(--color-danger), #f87171)'
                          : 'linear-gradient(to right, var(--color-primary), var(--color-info))',
                        borderRadius: '4px',
                        transition: 'width 1s ease-out',
                      }}
                    />
                  </div>
                </div>

                <div style={{ borderTop: '1px solid var(--border-divider)', paddingTop: '12px', display: 'flex', justifyContent: 'space-between', fontSize: '11px', color: 'var(--text-secondary)' }}>
                  <span>Bin: <strong>{site.capacity || '—'}</strong></span>
                  <span>Last collected: <strong>{formatDate(site.last_collected)}</strong></span>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* ── Add Site Modal ── */}
      {showAddModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>Create New Site</h3>
            <form onSubmit={handleAddSite} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div className="form-group">
                <label>Site / Client Name</label>
                <input name="name" type="text" placeholder="e.g. Labadi Luxury Hotel" required />
              </div>
              <div className="form-group">
                <label>Region / Neighborhood</label>
                <input name="region" type="text" placeholder="e.g. Labadi" required />
              </div>
              <div className="form-group">
                <label>Bin Capacity</label>
                <select name="capacity">
                  <option value="1200L">1200 Liters</option>
                  <option value="2400L">2400 Liters</option>
                  <option value="5000L">5000 Liters</option>
                </select>
              </div>
              <div className="modal-actions">
                <button type="button" className="btn-outline" onClick={() => setShowAddModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" disabled={saving}>
                  {saving ? 'Adding…' : 'Add Site Location'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
