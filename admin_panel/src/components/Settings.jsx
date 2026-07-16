import React, { useState } from 'react';

export default function Settings() {
  const [superAdminAccess, setSuperAdminAccess] = useState(true);
  const [zones, setZones] = useState([
    { id: 'ZN-01', name: 'Airport Residential Hub', status: 'Active' },
    { id: 'ZN-02', name: 'East Legon Sector B', status: 'Active' },
    { id: 'ZN-03', name: 'Labadi Beach Sector C', status: 'Active' },
    { id: 'ZN-04', name: 'Cantonments Embassy Area', status: 'Suspended' },
  ]);

  const [showZoneModal, setShowZoneModal] = useState(false);

  const handleAddZone = (e) => {
    e.preventDefault();
    const formData = new FormData(e.target);
    const newZone = {
      id: `ZN-0${zones.length + 1}`,
      name: formData.get('name'),
      status: 'Active',
    };
    setZones([...zones, newZone]);
    setShowZoneModal(false);
  };

  return (
    <div className="page-content">
      {/* ── Page Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>System Platform Settings</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Manage organization configurations, service parameters, and administrative controls.
          </p>
        </div>
      </div>

      {/* ── Settings Sections ── */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
        {/* Roles & Permissions */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <h3 style={{ fontSize: '16px' }}>Roles & Permissions</h3>
          
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-divider)', paddingBottom: '16px' }}>
            <div>
              <h4 style={{ fontSize: '13px', fontWeight: 'bold' }}>Super Admin Access</h4>
              <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '4px' }}>Full root-level write access to database configurations.</p>
            </div>
            <label className="switch">
              <input type="checkbox" checked={superAdminAccess} onChange={(e) => setSuperAdminAccess(e.target.checked)} />
              <span className="slider"></span>
            </label>
          </div>

          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h4 style={{ fontSize: '13px', fontWeight: 'bold' }}>Other Route Modifications</h4>
              <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '4px' }}>Allow active optimization overrides during active rider shifts.</p>
            </div>
            <label className="switch">
              <input type="checkbox" defaultChecked />
              <span className="slider"></span>
            </label>
          </div>
        </div>

        {/* Service Zones */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3 style={{ fontSize: '16px' }}>Active Service Zones</h3>
            <button className="btn-outline" style={{ padding: '6px 12px', fontSize: '11px' }} onClick={() => setShowZoneModal(true)}>
              + Add Service Zone
            </button>
          </div>

          <div className="table-container">
            <table className="custom-table">
              <thead>
                <tr>
                  <th>Zone ID</th>
                  <th>Zone Sector Area</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {zones.map((zone) => (
                  <tr key={zone.id}>
                    <td style={{ fontWeight: '700', color: 'var(--color-primary)' }}>{zone.id}</td>
                    <td style={{ fontWeight: '600' }}>{zone.name}</td>
                    <td>
                      <span className={`badge ${zone.status === 'Active' ? 'badge-active' : 'badge-defaulter'}`}>
                        {zone.status}
                      </span>
                    </td>
                    <td>
                      <button
                        className="btn-outline"
                        style={{ padding: '4px 8px', fontSize: '10px' }}
                        onClick={() => {
                          setZones(prev => prev.map(z => z.id === zone.id ? { ...z, status: z.status === 'Active' ? 'Suspended' : 'Active' } : z));
                        }}
                      >
                        Toggle Status
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* ── Add Zone Modal ── */}
      {showZoneModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>Add Service Zone</h3>
            <form onSubmit={handleAddZone} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div className="form-group">
                <label>Zone Sector Name</label>
                <input name="name" type="text" placeholder="e.g. Airport Hills East" required />
              </div>
              <div className="modal-actions">
                <button type="button" className="btn-outline" onClick={() => setShowZoneModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary">Add Zone</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
