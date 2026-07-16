import React, { useState } from 'react';

export default function Riders() {
  const [riders, setRiders] = useState([
    { name: 'Kofi Mensah', id: 'RID-0024', phone: '0244558812', vehicle: 'Motorbike (M-20-AS)', location: 'Airport Residential', status: 'Active', color: '#0284c7' },
    { name: 'Ama Osei', id: 'RID-0031', phone: '0208119934', vehicle: 'Tricycle (T-22-EX)', location: 'East Legon', status: 'Active', color: '#10b981' },
    { name: 'Kwame Antwi', id: 'RID-0012', phone: '0554881122', vehicle: 'Motorbike (M-19-KO)', location: 'Cantonments', status: 'Active', color: '#f59e0b' },
    { name: 'Abena Asare', id: 'RID-0044', phone: '0277338844', vehicle: 'Motorbike (M-21-LM)', location: 'Labadi Estate', status: 'Active', color: '#ef4444' },
    { name: 'Yaw Preko', id: 'RID-0019', phone: '0243110022', vehicle: 'Tricycle (T-21-GA)', location: 'Off Duty', status: 'Offline', color: '#94a3b8' },
  ]);

  const [selectedRider, setSelectedRider] = useState(riders[0]);
  const [showAddModal, setShowAddModal] = useState(false);

  const handleAddRider = (e) => {
    e.preventDefault();
    const formData = new FormData(e.target);
    const newRider = {
      name: formData.get('name'),
      id: `RID-00${riders.length + 1}`,
      phone: formData.get('phone'),
      vehicle: formData.get('vehicle'),
      location: 'Assigned',
      status: 'Active',
      color: '#06b6d4',
    };
    setRiders([...riders, newRider]);
    setShowAddModal(false);
  };

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
        <button className="btn-primary" onClick={() => setShowAddModal(true)}>
          + Register New Rider
        </button>
      </div>

      {/* ── Main Split View ── */}
      <div className="split-layout">
        {/* Left: Riders List */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <h3 style={{ fontSize: '16px' }}>Active Driver Roster</h3>
          <div className="table-container">
            <table className="custom-table">
              <thead>
                <tr>
                  <th>Rider Name</th>
                  <th>ID Code</th>
                  <th>Vehicle Info</th>
                  <th>Last Reported</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {riders.map((r, idx) => (
                  <tr
                    key={idx}
                    onClick={() => setSelectedRider(r)}
                    style={{ cursor: 'pointer', background: selectedRider.id === r.id ? 'var(--border-divider)' : 'transparent' }}
                  >
                    <td style={{ fontWeight: '700' }}>{r.name}</td>
                    <td style={{ color: 'var(--text-secondary)' }}>{r.id}</td>
                    <td style={{ fontSize: '12px' }}>{r.vehicle}</td>
                    <td>{r.location}</td>
                    <td>
                      <span className={`badge ${r.status === 'Active' ? 'badge-active' : ''}`} style={{ background: r.status === 'Offline' ? 'rgba(0,0,0,0.05)' : '' }}>
                        {r.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Right: Fleet Tracking Map */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div>
            <h3 style={{ fontSize: '16px' }}>Live Fleet Tracking Map</h3>
            <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '4px' }}>
              Vector map of rider geographical coordinate updates.
            </p>
          </div>

          {/* SVG Map Layout */}
          <div style={{ position: 'relative', width: '100%', height: '300px', background: 'var(--bg-app)', border: '1px solid var(--border-divider)', borderRadius: '12px', overflow: 'hidden' }}>
            <svg viewBox="0 0 400 300" width="100%" height="100%">
              {/* Map grid lines */}
              <line x1="100" y1="0" x2="100" y2="300" stroke="var(--border-divider)" strokeWidth="1" strokeDasharray="4" />
              <line x1="200" y1="0" x2="200" y2="300" stroke="var(--border-divider)" strokeWidth="1" strokeDasharray="4" />
              <line x1="300" y1="0" x2="300" y2="300" stroke="var(--border-divider)" strokeWidth="1" strokeDasharray="4" />
              <line x1="0" y1="100" x2="400" y2="100" stroke="var(--border-divider)" strokeWidth="1" strokeDasharray="4" />
              <line x1="0" y1="200" x2="400" y2="200" stroke="var(--border-divider)" strokeWidth="1" strokeDasharray="4" />

              {/* Map roads/routes */}
              <path d="M 50 0 L 50 300 M 0 150 L 400 150 M 250 0 C 250 100, 320 200, 320 300" fill="none" stroke="var(--border-glass)" strokeWidth="8" />
              <path d="M 50 0 L 50 300 M 0 150 L 400 150 M 250 0 C 250 100, 320 200, 320 300" fill="none" stroke="var(--bg-sidebar)" strokeWidth="4" />

              {/* Vector pins for active riders */}
              {riders.filter(r => r.status === 'Active').map((r, i) => {
                // Approximate location positions for mapping visualization
                const coords = [
                  { x: 120, y: 80 },
                  { x: 260, y: 140 },
                  { x: 80, y: 220 },
                  { x: 310, y: 70 },
                ];
                const pos = coords[i % coords.length];
                const isSelected = selectedRider.id === r.id;

                return (
                  <g key={r.id} style={{ cursor: 'pointer' }} onClick={() => setSelectedRider(r)}>
                    <circle cx={pos.x} cy={pos.y} r={isSelected ? '12' : '8'} fill={r.color} opacity="0.3" />
                    <circle cx={pos.x} cy={pos.y} r="6" fill={r.color} stroke="white" strokeWidth="1.5" />
                    {isSelected && (
                      <foreignObject x={pos.x + 10} y={pos.y - 12} width="120" height="40">
                        <div style={{ background: 'var(--bg-sidebar)', padding: '2px 6px', fontSize: '9px', borderRadius: '4px', border: '1px solid var(--border-divider)', fontWeight: 'bold', boxShadow: 'var(--shadow-card)', color: 'var(--text-primary)' }}>
                          {r.name}
                        </div>
                      </foreignObject>
                    )}
                  </g>
                );
              })}
            </svg>
          </div>

          {/* Selected Rider Details Panel */}
          {selectedRider && (
            <div style={{ padding: '16px', background: 'var(--bg-app)', borderRadius: '8px', display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '12px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--border-divider)', paddingBottom: '8px' }}>
                <span style={{ fontWeight: 'bold' }}>Rider Code:</span>
                <span>{selectedRider.id}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--border-divider)', paddingBottom: '8px' }}>
                <span style={{ fontWeight: 'bold' }}>Mobile Number:</span>
                <span>{selectedRider.phone}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--border-divider)', paddingBottom: '8px' }}>
                <span style={{ fontWeight: 'bold' }}>Vehicle Assigned:</span>
                <span>{selectedRider.vehicle}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ fontWeight: 'bold' }}>Status:</span>
                <span style={{ color: selectedRider.status === 'Active' ? 'var(--color-success)' : 'var(--text-muted)', fontWeight: 'bold' }}>
                  {selectedRider.status}
                </span>
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
                <label>Mobile Number</label>
                <input name="phone" type="text" placeholder="e.g. 0244000000" required />
              </div>
              <div className="form-group">
                <label>Vehicle Type / Reg No</label>
                <input name="vehicle" type="text" placeholder="e.g. Motorbike (M-24-AS)" required />
              </div>
              <div className="modal-actions">
                <button type="button" className="btn-outline" onClick={() => setShowAddModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary">Register Account</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
