import React, { useState, useRef } from 'react';

export default function Settings() {
  const [superAdminAccess, setSuperAdminAccess] = useState(true);
  const [zones, setZones] = useState([
    { id: 'ZN-01', name: 'Airport Residential Hub', status: 'Active' },
    { id: 'ZN-02', name: 'East Legon Sector B', status: 'Active' },
    { id: 'ZN-03', name: 'Labadi Beach Sector C', status: 'Active' },
    { id: 'ZN-04', name: 'Cantonments Embassy Area', status: 'Suspended' },
  ]);

  const [showZoneModal, setShowZoneModal] = useState(false);

  // Admin profile state persisted in localStorage
  const [adminPhoto, setAdminPhoto] = useState(
    () => localStorage.getItem('adminPhoto') || null
  );
  const [adminName, setAdminName] = useState(
    () => localStorage.getItem('adminName') || 'Super Admin'
  );
  const [adminEmail, setAdminEmail] = useState(
    () => localStorage.getItem('adminEmail') || 'admin@cleanconnect.com'
  );
  const [isEditingProfile, setIsEditingProfile] = useState(false);
  const [nameInput, setNameInput] = useState(adminName);
  const [emailInput, setEmailInput] = useState(adminEmail);
  const photoInputRef = useRef(null);

  const handleAdminPhotoUpload = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      const dataUrl = reader.result;
      setAdminPhoto(dataUrl);
      localStorage.setItem('adminPhoto', dataUrl);
      // Dispatch a storage event to update the header
      window.dispatchEvent(new StorageEvent('storage', {
        key: 'adminPhoto',
        newValue: dataUrl,
      }));
    };
    reader.readAsDataURL(file);
  };

  const handleSaveProfile = () => {
    setAdminName(nameInput);
    setAdminEmail(emailInput);
    localStorage.setItem('adminName', nameInput);
    localStorage.setItem('adminEmail', emailInput);
    window.dispatchEvent(new StorageEvent('storage', { key: 'adminName', newValue: nameInput }));
    setIsEditingProfile(false);
  };

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

      <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>

        {/* ── Admin Account Profile ── */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <h3 style={{ fontSize: '16px' }}>Admin Account Profile</h3>

          <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
            {/* Clickable Avatar */}
            <div
              style={{ position: 'relative', width: '72px', height: '72px', cursor: 'pointer', flexShrink: 0 }}
              onClick={() => photoInputRef.current?.click()}
              title="Click to change profile photo"
            >
              {adminPhoto ? (
                <img
                  src={adminPhoto}
                  alt="Admin"
                  style={{ width: '72px', height: '72px', borderRadius: '50%', objectFit: 'cover', border: '3px solid var(--color-primary)' }}
                />
              ) : (
                <div style={{
                  width: '72px', height: '72px', borderRadius: '50%',
                  background: 'linear-gradient(135deg, var(--color-primary), var(--color-info))',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: '28px', fontWeight: '900', color: 'white',
                  border: '3px solid var(--color-primary)',
                }}>
                  {adminName[0]?.toUpperCase() || 'A'}
                </div>
              )}
              <div style={{
                position: 'absolute', bottom: 0, right: 0,
                background: 'var(--color-primary)', borderRadius: '50%',
                padding: '5px', display: 'flex', alignItems: 'center', justifyContent: 'center',
                boxShadow: '0 2px 8px rgba(0,0,0,0.3)',
              }}>
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5">
                  <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/>
                  <circle cx="12" cy="13" r="4"/>
                </svg>
              </div>
              <input
                ref={photoInputRef}
                type="file"
                accept="image/*"
                style={{ display: 'none' }}
                onChange={handleAdminPhotoUpload}
              />
            </div>

            {/* Name & Email */}
            <div style={{ flex: 1 }}>
              {isEditingProfile ? (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  <input
                    value={nameInput}
                    onChange={(e) => setNameInput(e.target.value)}
                    placeholder="Full Name"
                    style={{
                      padding: '8px 12px', borderRadius: '8px', fontSize: '14px',
                      border: '1px solid var(--border-divider)', background: 'var(--bg-app)',
                      color: 'var(--text-primary)',
                    }}
                  />
                  <input
                    value={emailInput}
                    onChange={(e) => setEmailInput(e.target.value)}
                    placeholder="Email"
                    style={{
                      padding: '8px 12px', borderRadius: '8px', fontSize: '13px',
                      border: '1px solid var(--border-divider)', background: 'var(--bg-app)',
                      color: 'var(--text-primary)',
                    }}
                  />
                  <div style={{ display: 'flex', gap: '8px', marginTop: '4px' }}>
                    <button className="btn-primary" style={{ padding: '6px 14px', fontSize: '12px' }} onClick={handleSaveProfile}>Save</button>
                    <button className="btn-outline" style={{ padding: '6px 14px', fontSize: '12px' }} onClick={() => setIsEditingProfile(false)}>Cancel</button>
                  </div>
                </div>
              ) : (
                <>
                  <h4 style={{ fontSize: '18px', fontWeight: '800' }}>{adminName}</h4>
                  <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>{adminEmail}</p>
                  <p style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '2px' }}>Super Administrator • CleanConnect Platform</p>
                  <button
                    className="btn-outline"
                    style={{ marginTop: '10px', padding: '5px 12px', fontSize: '11px' }}
                    onClick={() => { setNameInput(adminName); setEmailInput(adminEmail); setIsEditingProfile(true); }}
                  >
                    ✏️ Edit Profile
                  </button>
                </>
              )}
            </div>
          </div>

          <p style={{ fontSize: '11px', color: 'var(--text-muted)', fontStyle: 'italic' }}>
            Click the avatar above to change your profile photo. Changes are saved locally.
          </p>
        </div>

        {/* ── Roles & Permissions ── */}
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

        {/* ── Service Zones ── */}
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

