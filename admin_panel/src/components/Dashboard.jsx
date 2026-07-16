import React from 'react';

export default function Dashboard() {
  const topRiders = [
    { name: 'Kofi Mensah', collections: 145, rating: 4.9, avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100' },
    { name: 'Ama Osei', collections: 132, rating: 4.8, avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100' },
    { name: 'Kwame Antwi', collections: 121, rating: 4.7, avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100' },
    { name: 'Abena Asare', collections: 110, rating: 4.9, avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100' },
  ];

  const recentCollections = [
    { id: '#COL-8890', site: 'Labadi Beach Estate', weight: '240 kg', status: 'Completed', time: '10 mins ago' },
    { id: '#COL-8889', site: 'Cantoment Plaza', weight: '180 kg', status: 'Completed', time: '24 mins ago' },
    { id: '#COL-8888', site: 'East Legon Mall', weight: '540 kg', status: 'Completed', time: '1 hr ago' },
    { id: '#COL-8887', site: 'Ridge Medical Hub', weight: '320 kg', status: 'Pending', time: '2 hrs ago' },
  ];

  return (
    <div className="page-content">
      {/* ── Page Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>Overview Dashboard</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Real-time operations summary for EcoFlow logistics.
          </p>
        </div>
        <button className="btn-primary">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 5v14M5 12h14"/></svg>
          New Task Dispatch
        </button>
      </div>

      {/* ── Key Performance Metrics ── */}
      <div className="metrics-grid">
        <div className="card-glass metric-card">
          <div className="metric-header">
            <span className="metric-title">Total Revenue</span>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--color-primary)" strokeWidth="2"><path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
          </div>
          <span className="metric-value">$124.5k</span>
          <div className="metric-footer trend-up">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M18 15l-6-6-6 6"/></svg>
            <span>+12% this month</span>
          </div>
        </div>

        <div className="card-glass metric-card">
          <div className="metric-header">
            <span className="metric-title">Active Riders</span>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--color-info)" strokeWidth="2"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 7a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></svg>
          </div>
          <span className="metric-value">42</span>
          <div className="metric-footer trend-up">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M18 15l-6-6-6 6"/></svg>
            <span>+8% active now</span>
          </div>
        </div>

        <div className="card-glass metric-card">
          <div className="metric-header">
            <span className="metric-title">Waste Collected</span>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--color-success)" strokeWidth="2"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16zM3.27 6.96L12 12.01l8.73-5.05M12 22.08V12"/></svg>
          </div>
          <span className="metric-value">842 <span style={{ fontSize: '16px' }}>Tons</span></span>
          <div className="metric-footer trend-up">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M18 15l-6-6-6 6"/></svg>
            <span>+4.2% volume</span>
          </div>
        </div>

        <div className="card-glass metric-card">
          <div className="metric-header">
            <span className="metric-title">CO2 Saved</span>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--color-accent)" strokeWidth="2"><path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
          </div>
          <span className="metric-value">14B <span style={{ fontSize: '16px' }}>kg</span></span>
          <div className="metric-footer trend-down">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M18 9l-6 6-6-6"/></svg>
            <span>-1.2% offset</span>
          </div>
        </div>
      </div>

      {/* ── Splitted Visual Graphs & Leaderboard ── */}
      <div className="split-layout">
        {/* Trend Graph */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3 style={{ fontSize: '16px' }}>Growth & Volume Trends</h3>
            <div style={{ display: 'flex', gap: '8px' }}>
              <button className="btn-outline" style={{ padding: '6px 12px', fontSize: '11px' }}>Daily</button>
              <button className="btn-primary" style={{ padding: '6px 12px', fontSize: '11px' }}>Weekly</button>
              <button className="btn-outline" style={{ padding: '6px 12px', fontSize: '11px' }}>Monthly</button>
            </div>
          </div>

          {/* SVG Visual Graph Line */}
          <div style={{ position: 'relative', width: '100%', height: '240px', background: 'rgba(0,0,0,0.01)', borderRadius: '12px' }}>
            <svg viewBox="0 0 500 200" width="100%" height="100%" preserveAspectRatio="none">
              <defs>
                <linearGradient id="gradient-area" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="var(--color-primary)" stopOpacity="0.25" />
                  <stop offset="100%" stopColor="var(--color-primary)" stopOpacity="0" />
                </linearGradient>
              </defs>
              <path d="M 0 180 Q 80 120 150 140 T 300 70 T 450 40 T 500 30 L 500 200 L 0 200 Z" fill="url(#gradient-area)" />
              <path d="M 0 180 Q 80 120 150 140 T 300 70 T 450 40 T 500 30" fill="none" stroke="var(--color-primary)" strokeWidth="3" />
              {/* Dot Markers */}
              <circle cx="150" cy="140" r="5" fill="var(--color-primary)" stroke="white" strokeWidth="2" />
              <circle cx="300" cy="70" r="5" fill="var(--color-primary)" stroke="white" strokeWidth="2" />
              <circle cx="450" cy="40" r="5" fill="var(--color-primary)" stroke="white" strokeWidth="2" />
            </svg>
            <div style={{ position: 'absolute', bottom: '10px', left: '20px', display: 'flex', justifyContent: 'space-between', right: '20px', fontSize: '11px', color: 'var(--text-secondary)' }}>
              <span>Mon</span>
              <span>Tue</span>
              <span>Wed</span>
              <span>Thu</span>
              <span>Fri</span>
              <span>Sat</span>
              <span>Sun</span>
            </div>
          </div>
        </div>

        {/* Top Performers */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <h3 style={{ fontSize: '16px' }}>Top Performing Riders</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            {topRiders.map((rider, idx) => (
              <div key={idx} style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <img src={rider.avatar} alt={rider.name} style={{ width: '40px', height: '40px', borderRadius: '50%', objectFit: 'cover' }} />
                <div style={{ flex: 1 }}>
                  <h4 style={{ fontSize: '13px', fontWeight: '700' }}>{rider.name}</h4>
                  <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                    {rider.collections} completed collections
                  </p>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '4px', background: 'rgba(245, 158, 11, 0.1)', padding: '2px 8px', borderRadius: '12px', color: 'var(--color-accent)', fontSize: '11px', fontWeight: '700' }}>
                  <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                  {rider.rating}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* ── Recent Collections Log ── */}
      <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
        <h3 style={{ fontSize: '16px' }}>Recent Collections Logs</h3>
        <div className="table-container">
          <table className="custom-table">
            <thead>
              <tr>
                <th>Collection ID</th>
                <th>Collection Site</th>
                <th>Weight Captured</th>
                <th>Status</th>
                <th>Time stamp</th>
              </tr>
            </thead>
            <tbody>
              {recentCollections.map((log, index) => (
                <tr key={index}>
                  <td style={{ fontWeight: '700', color: 'var(--color-primary)' }}>{log.id}</td>
                  <td>{log.site}</td>
                  <td>{log.weight}</td>
                  <td>
                    <span className={`badge ${log.status === 'Completed' ? 'badge-active' : 'badge-pending'}`}>
                      {log.status}
                    </span>
                  </td>
                  <td style={{ color: 'var(--text-secondary)' }}>{log.time}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
