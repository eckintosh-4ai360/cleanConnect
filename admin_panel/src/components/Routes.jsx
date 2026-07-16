import React, { useState } from 'react';

export default function Routes() {
  const [routes, setRoutes] = useState([
    { id: 'RTE-702', rider: 'Kofi Mensah', stops: 6, completed: 4, status: 'In Progress', efficiency: '94%', time: '1 hr remaining' },
    { id: 'RTE-703', rider: 'Ama Osei', stops: 5, completed: 5, status: 'Completed', efficiency: '98%', time: 'Finished' },
    { id: 'RTE-704', rider: 'Kwame Antwi', stops: 8, completed: 2, status: 'In Progress', efficiency: '88%', time: '3 hrs remaining' },
    { id: 'RTE-705', rider: 'Abena Asare', stops: 4, completed: 0, status: 'Dispatched', efficiency: '92%', time: '4 hrs remaining' },
  ]);

  const [showOptimizeModal, setShowOptimizeModal] = useState(false);

  const triggerOptimization = () => {
    alert('AI Route optimization pipeline executed. 4 collection pathways rescheduled for high fuel efficiency.');
    setShowOptimizeModal(false);
  };

  return (
    <div className="page-content">
      {/* ── Page Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>Route Optimization & Dispatch</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Calculate efficient pickup sequences using AI location routing.
          </p>
        </div>
        <button className="btn-primary" onClick={() => setShowOptimizeModal(true)}>
          Optimize All Routes
        </button>
      </div>

      {/* ── Routes Grid ── */}
      <div className="metrics-grid">
        {routes.map((route) => {
          const progress = (route.completed / route.stops) * 100;
          return (
            <div key={route.id} className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <div>
                  <h4 style={{ fontSize: '15px', fontWeight: '800' }}>Route {route.id}</h4>
                  <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '2px' }}>Driver: <strong>{route.rider}</strong></p>
                </div>
                <span className={`badge ${route.status === 'Completed' ? 'badge-active' : 'badge-pending'}`}>
                  {route.status}
                </span>
              </div>

              {/* Progress Slider */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '11px', fontWeight: 'bold' }}>
                  <span style={{ color: 'var(--text-secondary)' }}>Stops Completed:</span>
                  <span>{route.completed} / {route.stops}</span>
                </div>
                <div style={{ width: '100%', height: '8px', background: 'var(--bg-app)', borderRadius: '4px', overflow: 'hidden' }}>
                  <div style={{ width: `${progress}%`, height: '100%', background: 'linear-gradient(to right, var(--color-primary), var(--color-info))', borderRadius: '4px' }}></div>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', background: 'var(--bg-app)', padding: '10px', borderRadius: '8px', fontSize: '11px' }}>
                <div>
                  <span style={{ color: 'var(--text-muted)' }}>Path Efficiency:</span>
                  <p style={{ fontSize: '13px', fontWeight: 'bold', color: 'var(--color-success)', marginTop: '2px' }}>{route.efficiency}</p>
                </div>
                <div>
                  <span style={{ color: 'var(--text-muted)' }}>ETA Timeline:</span>
                  <p style={{ fontSize: '13px', fontWeight: 'bold', marginTop: '2px' }}>{route.time}</p>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* ── Route Optimize Modal ── */}
      {showOptimizeModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>Optimize Active Dispatch Routes</h3>
            <p style={{ fontSize: '13px', color: 'var(--text-secondary)', lineHeight: '140%' }}>
              Running the optimization engine re-calculates all stop lists for active drivers based on live traffic, coordinates, and bin fill capacities.
            </p>
            <div style={{ padding: '16px', background: 'var(--bg-app)', borderRadius: '8px', fontSize: '12px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
              <div>• Reduce carbon emission output by ~14%</div>
              <div>• Decrease average transit time per stop by ~9 mins</div>
              <div>• Target priority bins with fill level &gt;80% first</div>
            </div>
            <div className="modal-actions">
              <button className="btn-outline" onClick={() => setShowOptimizeModal(false)}>Cancel</button>
              <button className="btn-primary" onClick={triggerOptimization}>Execute Optimizer</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
