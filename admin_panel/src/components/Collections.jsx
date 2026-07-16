import React, { useState } from 'react';

export default function Collections() {
  const [collections, setCollections] = useState([
    { id: '#COL-8890', site: 'Labadi Beach Estate', weight: '240 kg', rider: 'Kofi Mensah', status: 'Completed', date: '2026-07-16', time: '10:35 AM', qrVerified: true, carbonOffset: '12.5 kg' },
    { id: '#COL-8889', site: 'Cantoment Plaza', weight: '180 kg', rider: 'Ama Osei', status: 'Completed', date: '2026-07-16', time: '10:12 AM', qrVerified: true, carbonOffset: '9.0 kg' },
    { id: '#COL-8888', site: 'East Legon Mall', weight: '540 kg', rider: 'Kwame Antwi', status: 'Completed', date: '2026-07-15', time: '04:45 PM', qrVerified: true, carbonOffset: '28.0 kg' },
    { id: '#COL-8887', site: 'Ridge Medical Hub', weight: '320 kg', rider: 'Abena Asare', status: 'Pending', date: '2026-07-15', time: '02:30 PM', qrVerified: false, carbonOffset: '16.6 kg' },
    { id: '#COL-8886', site: 'Glow Hair Salon', weight: '45 kg', rider: 'Yaw Preko', status: 'Completed', date: '2026-07-15', time: '11:15 AM', qrVerified: true, carbonOffset: '2.3 kg' },
  ]);

  const [filter, setFilter] = useState('All');

  const filteredLogs = collections.filter(c => {
    if (filter === 'All') return true;
    return c.status === filter;
  });

  return (
    <div className="page-content">
      {/* ── Page Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>Waste Collections History</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Check historical QR code receipts, weight audits, and carbon offset logs.
          </p>
        </div>
        <div style={{ display: 'flex', gap: '8px' }}>
          <button className={`btn-outline ${filter === 'All' ? 'btn-primary' : ''}`} style={{ padding: '8px 16px', fontSize: '12px' }} onClick={() => setFilter('All')}>
            All
          </button>
          <button className={`btn-outline ${filter === 'Completed' ? 'btn-primary' : ''}`} style={{ padding: '8px 16px', fontSize: '12px' }} onClick={() => setFilter('Completed')}>
            Completed
          </button>
          <button className={`btn-outline ${filter === 'Pending' ? 'btn-primary' : ''}`} style={{ padding: '8px 16px', fontSize: '12px' }} onClick={() => setFilter('Pending')}>
            Pending
          </button>
        </div>
      </div>

      {/* ── Collections Table ── */}
      <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
        <h3 style={{ fontSize: '16px' }}>Collection Audits</h3>
        <div className="table-container">
          <table className="custom-table">
            <thead>
              <tr>
                <th>Job ID</th>
                <th>Disposal Site</th>
                <th>Assigned Driver</th>
                <th>Audited Weight</th>
                <th>Offset Saved</th>
                <th>QR Verified</th>
                <th>Date & Time</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {filteredLogs.map((log) => (
                <tr key={log.id}>
                  <td style={{ fontWeight: '700', color: 'var(--color-primary)' }}>{log.id}</td>
                  <td style={{ fontWeight: '600' }}>{log.site}</td>
                  <td>{log.rider}</td>
                  <td>{log.weight}</td>
                  <td style={{ color: 'var(--color-success)', fontWeight: 'bold' }}>{log.carbonOffset}</td>
                  <td>
                    <span style={{ display: 'flex', alignItems: 'center', gap: '6px', color: log.qrVerified ? 'var(--color-success)' : 'var(--text-muted)', fontSize: '12px', fontWeight: 'bold' }}>
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                        {log.qrVerified ? (
                          <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14M22 4L12 14.01l-3-3"/>
                        ) : (
                          <>
                            <circle cx="12" cy="12" r="10"/>
                            <line x1="12" y1="8" x2="12" y2="12"/>
                            <line x1="12" y1="16" x2="12.01" y2="16"/>
                          </>
                        )}
                      </svg>
                      {log.qrVerified ? 'Verified' : 'Bypassed'}
                    </span>
                  </td>
                  <td style={{ color: 'var(--text-secondary)' }}>{log.date} @ {log.time}</td>
                  <td>
                    <span className={`badge ${log.status === 'Completed' ? 'badge-active' : 'badge-pending'}`}>
                      {log.status}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
