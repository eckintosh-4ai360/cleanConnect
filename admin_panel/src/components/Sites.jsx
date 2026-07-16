import React, { useState } from 'react';

export default function Sites() {
  const [sites, setSites] = useState([
    { id: 'STE-092', name: 'Labadi Beach Estate', region: 'Labadi', capacity: '1200L', fill: 85, status: 'Critical', lastCollected: '2 hrs ago' },
    { id: 'STE-093', name: 'Airport Residential Lane 4', region: 'Airport', capacity: '1200L', fill: 60, status: 'Normal', lastCollected: '4 hrs ago' },
    { id: 'STE-094', name: 'East Legon Mall Bin C', region: 'East Legon', capacity: '2400L', fill: 45, status: 'Normal', lastCollected: '1 day ago' },
    { id: 'STE-095', name: 'Cantonments Embassy Gate', region: 'Cantonments', capacity: '1200L', fill: 95, status: 'Critical', lastCollected: '3 hrs ago' },
    { id: 'STE-096', name: 'Ridge Medical Clinic Site A', region: 'Ridge', capacity: '2400L', fill: 20, status: 'Normal', lastCollected: '5 mins ago' },
  ]);

  const [showAddModal, setShowAddModal] = useState(false);

  const handleAddSite = (e) => {
    e.preventDefault();
    const formData = new FormData(e.target);
    const newSite = {
      id: `STE-0${90 + sites.length + 7}`,
      name: formData.get('name'),
      region: formData.get('region'),
      capacity: formData.get('capacity'),
      fill: Math.floor(Math.random() * 50) + 10,
      status: 'Normal',
      lastCollected: 'Just registered',
    };
    setSites([...sites, newSite]);
    setShowAddModal(false);
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

      {/* ── Sites Grid ── */}
      <div className="metrics-grid">
        {sites.map((site) => {
          const isCritical = site.fill >= 80;
          return (
            <div key={site.id} className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '16px', border: isCritical ? '1px solid rgba(239, 68, 68, 0.2)' : '1px solid var(--border-glass)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <div>
                  <h4 style={{ fontSize: '14px', fontWeight: '800' }}>{site.name}</h4>
                  <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '2px' }}>{site.id} • {site.region}</p>
                </div>
                <span className={`badge ${isCritical ? 'badge-defaulter' : 'badge-active'}`}>
                  {site.status}
                </span>
              </div>

              {/* Fill Gauge */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '11px', fontWeight: 'bold' }}>
                  <span style={{ color: 'var(--text-secondary)' }}>Fill Load:</span>
                  <span style={{ color: isCritical ? 'var(--color-danger)' : 'var(--text-primary)' }}>{site.fill}%</span>
                </div>
                <div style={{ width: '100%', height: '8px', background: 'var(--bg-app)', borderRadius: '4px', overflow: 'hidden' }}>
                  <div style={{ width: `${site.fill}%`, height: '100%', background: isCritical ? 'linear-gradient(to right, var(--color-danger), #f87171)' : 'linear-gradient(to right, var(--color-primary), var(--color-info))', borderRadius: '4px', transition: 'width 1s ease-out' }}></div>
                </div>
              </div>

              <div style={{ borderTop: '1px solid var(--border-divider)', paddingTop: '12px', display: 'flex', justifyContent: 'space-between', fontSize: '11px', color: 'var(--text-secondary)' }}>
                <span>Bin: <strong>{site.capacity}</strong></span>
                <span>Collected: <strong>{site.lastCollected}</strong></span>
              </div>
            </div>
          );
        })}
      </div>

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
                <button type="submit" className="btn-primary">Add Site Location</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
