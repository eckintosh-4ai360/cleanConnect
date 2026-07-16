import React, { useState } from 'react';

export default function Maintenance() {
  const [vehicles, setVehicles] = useState([
    { id: 'VH-102', name: 'Nissan Waste Compactor', type: 'Truck', zone: 'Airport Zone', status: 'Active', load: '65%' },
    { id: 'VH-103', name: 'JMC Tricycle Carrier', type: 'Tricycle', zone: 'Labadi Beach', status: 'In Service', load: '80%' },
    { id: 'VH-104', name: 'Dongfeng Heavy Carrier', type: 'Truck', zone: 'East Legon', status: 'Active', load: '20%' },
    { id: 'VH-105', name: 'Lifan Cargo Trike', type: 'Tricycle', zone: 'Cantonments', status: 'Repair Needed', load: '0%' },
  ]);

  const [showAddModal, setShowAddModal] = useState(false);

  const handleRegisterVehicle = (e) => {
    e.preventDefault();
    const formData = new FormData(e.target);
    const newVehicle = {
      id: `VH-10${vehicles.length + 2}`,
      name: formData.get('name'),
      type: formData.get('type'),
      zone: formData.get('zone'),
      status: 'Active',
      load: '0%',
    };
    setVehicles([...vehicles, newVehicle]);
    setShowAddModal(false);
  };

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
              </tr>
            </thead>
            <tbody>
              {vehicles.map((v) => (
                <tr key={v.id}>
                  <td style={{ fontWeight: '700', color: 'var(--color-primary)' }}>{v.id}</td>
                  <td style={{ fontWeight: '600' }}>{v.name}</td>
                  <td>{v.type}</td>
                  <td>{v.zone}</td>
                  <td>{v.load}</td>
                  <td>
                    <span className={`badge ${
                      v.status === 'Active' || v.status === 'In Service' ? 'badge-active' : 'badge-defaulter'
                    }`}>
                      {v.status}
                    </span>
                  </td>
                </tr>
              ))}
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
                <button type="submit" className="btn-primary">Add Fleet Asset</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
