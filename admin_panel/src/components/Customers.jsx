import React, { useState } from 'react';

export default function Customers() {
  const [selectedCustomer, setSelectedCustomer] = useState({
    name: 'Acme Corp',
    code: 'CLI-88220',
    type: 'Commercial',
    address: 'East Legon Logistics Hub, Accra',
    outstanding: '$4,250.00',
    dueDays: '15 Days',
    avatar: 'https://images.unsplash.com/photo-1560179707-f14e90ef3623?w=100',
    logs: [
      { date: 'Nov 5, 2026', type: 'First Notice', msg: 'Automated first payment demand sent via Text & Mail. Invoice balance due in 5 days.' },
      { date: 'Oct 30, 2026', type: 'Follow Up Call', msg: 'Spoke with Accounts Payable. Promised invoice clearance regarding waste weight details.' },
    ]
  });

  const [customers, setCustomers] = useState([
    { name: 'Acme Corp', code: 'CLI-88220', type: 'Commercial', balance: '$4,250.00', status: 'Defaulter', days: 15 },
    { name: 'Summit Tech Solutions', code: 'CLI-88145', type: 'Enterprise', balance: '$2,800.00', status: 'Defaulter', days: 10 },
    { name: 'Glow Hair Salon', code: 'CLI-88092', type: 'Retail', balance: '$450.00', status: 'Outstanding', days: 4 },
    { name: 'Golden Spoon Bakery', code: 'CLI-88011', type: 'Commercial', balance: '$0.00', status: 'Active', days: 0 },
    { name: 'Accra Mall Plaza', code: 'CLI-87965', type: 'Enterprise', balance: '$8,200.00', status: 'Active', days: 0 },
  ]);

  const [showSuspendModal, setShowSuspendModal] = useState(false);
  const [showReminderModal, setShowReminderModal] = useState(false);
  const [notifyCustomer, setNotifyCustomer] = useState(true);

  const handleSuspendConfirm = () => {
    // Update the selected customer's status in local state to simulate backend write
    setSelectedCustomer(prev => ({
      ...prev,
      outstanding: '$4,250.00',
      dueDays: 'SUSPENDED',
      logs: [
        { date: 'Today', type: 'Service Suspended', msg: 'Service suspended due to non-payment of outstanding invoices.' },
        ...prev.logs
      ]
    }));
    setCustomers(prev => prev.map(c => c.name === selectedCustomer.name ? { ...c, status: 'Suspended' } : c));
    setShowSuspendModal(false);
  };

  return (
    <div className="page-content">
      {/* ── Page Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>Customers & Defaulters Management</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Monitor outstanding invoices, dispatch billing reminders, and configure service status.
          </p>
        </div>
        <div style={{ display: 'flex', gap: '10px' }}>
          <button className="btn-outline" onClick={() => setShowReminderModal(true)}>
            Batch Send Reminders
          </button>
          <button className="btn-primary">
            + New Customer Account
          </button>
        </div>
      </div>

      {/* ── Metric summaries ── */}
      <div className="metrics-grid">
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-danger)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Total Outstanding</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-danger)' }}>$15,700.00</span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-accent)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Critical Accounts (+10 Days)</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-accent)' }}>2 Accounts</span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-success)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Active Billing Agreements</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-success)' }}>156 Clients</span>
        </div>
      </div>

      {/* ── Main content grid: Split layout ── */}
      <div className="split-layout">
        {/* Left Side: Customers list */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <h3 style={{ fontSize: '16px' }}>Client Accounts Directory</h3>
          <div className="table-container">
            <table className="custom-table">
              <thead>
                <tr>
                  <th>Client</th>
                  <th>ID Code</th>
                  <th>Contract type</th>
                  <th>Outstanding</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {customers.map((c, index) => (
                  <tr
                    key={index}
                    onClick={() => {
                      setSelectedCustomer({
                        name: c.name,
                        code: c.code,
                        type: c.type,
                        address: c.name === 'Acme Corp' ? 'East Legon Logistics Hub, Accra' : 'Airport Residential Office, Accra',
                        outstanding: c.balance,
                        dueDays: c.status === 'Suspended' ? 'SUSPENDED' : `${c.days} Days`,
                        avatar: c.name === 'Acme Corp' ? 'https://images.unsplash.com/photo-1560179707-f14e90ef3623?w=100' : 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=100',
                        logs: [
                          { date: 'Nov 5, 2026', type: 'First Notice', msg: `Invoice billing reminders sent out automatically to ${c.name}.` }
                        ]
                      });
                    }}
                    style={{ cursor: 'pointer', background: selectedCustomer.name === c.name ? 'var(--border-divider)' : 'transparent' }}
                  >
                    <td style={{ fontWeight: '700' }}>{c.name}</td>
                    <td style={{ color: 'var(--text-secondary)' }}>{c.code}</td>
                    <td>{c.type}</td>
                    <td style={{ color: c.days > 0 ? 'var(--color-danger)' : 'var(--text-primary)', fontWeight: c.days > 0 ? '700' : 'normal' }}>
                      {c.balance}
                    </td>
                    <td>
                      <span className={`badge ${
                        c.status === 'Active' ? 'badge-active' :
                        c.status === 'Outstanding' ? 'badge-pending' : 'badge-defaulter'
                      }`}>
                        {c.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Right Side: Defaulter Detail Card */}
        {selectedCustomer && (
          <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px', border: '1px solid rgba(239, 68, 68, 0.25)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <img src={selectedCustomer.avatar} alt={selectedCustomer.name} style={{ width: '48px', height: '48px', borderRadius: '8px', objectFit: 'cover' }} />
              <div>
                <h4 style={{ fontSize: '15px', fontWeight: '800' }}>{selectedCustomer.name}</h4>
                <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '2px' }}>{selectedCustomer.code} • {selectedCustomer.type}</p>
              </div>
            </div>

            <div style={{ borderTop: '1px solid var(--border-divider)', padding: '16px 0', display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div>
                <span style={{ fontSize: '10px', textTransform: 'uppercase', fontWeight: '700', color: 'var(--text-muted)' }}>Location Address</span>
                <p style={{ fontSize: '12px', marginTop: '4px', fontWeight: '600' }}>{selectedCustomer.address}</p>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', background: 'var(--bg-app)', padding: '12px', borderRadius: '8px' }}>
                <div>
                  <span style={{ fontSize: '10px', textTransform: 'uppercase', fontWeight: '700', color: 'var(--text-muted)' }}>Outstanding Due</span>
                  <p style={{ fontSize: '16px', fontWeight: '800', color: 'var(--color-danger)', marginTop: '4px' }}>{selectedCustomer.outstanding}</p>
                </div>
                <div>
                  <span style={{ fontSize: '10px', textTransform: 'uppercase', fontWeight: '700', color: 'var(--text-muted)' }}>Overdue Period</span>
                  <p style={{ fontSize: '16px', fontWeight: '800', color: 'var(--color-accent)', marginTop: '4px' }}>{selectedCustomer.dueDays}</p>
                </div>
              </div>
            </div>

            {/* Communication log */}
            <div>
              <h4 style={{ fontSize: '12px', fontWeight: '700', textTransform: 'uppercase', color: 'var(--text-secondary)', marginBottom: '12px' }}>
                Communication Logs
              </h4>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                {selectedCustomer.logs.map((log, i) => (
                  <div key={i} style={{ borderLeft: '2px solid var(--color-primary)', paddingLeft: '10px', fontSize: '11px' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: '700' }}>
                      <span>{log.type}</span>
                      <span style={{ color: 'var(--text-secondary)' }}>{log.date}</span>
                    </div>
                    <p style={{ color: 'var(--text-secondary)', marginTop: '4px', lineHeight: '140%' }}>{log.msg}</p>
                  </div>
                ))}
              </div>
            </div>

            {/* Quick Actions Panel */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginTop: 'auto' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                <button className="btn-primary" style={{ justifyContent: 'center' }} onClick={() => alert('Invoice request resent successfully!')}>
                  Resend Invoice
                </button>
                <button className="btn-outline" style={{ justifyContent: 'center' }} onClick={() => alert('Reminder SMS & Mail sent!')}>
                  Send Reminder
                </button>
              </div>
              {selectedCustomer.dueDays !== 'SUSPENDED' && (
                <button className="btn-danger" style={{ justifyContent: 'center' }} onClick={() => setShowSuspendModal(true)}>
                  Suspend Service
                </button>
              )}
            </div>
          </div>
        )}
      </div>

      {/* ── Suspend Service Confirmation Modal ── */}
      {showSuspendModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', color: 'var(--color-danger)' }}>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0zM12 9v4M12 17h.01"/></svg>
              <h3 style={{ fontSize: '18px' }}>Confirm Service Suspension?</h3>
            </div>
            <p style={{ fontSize: '13px', color: 'var(--text-secondary)', lineHeight: '150%' }}>
              You are about to suspend sanitation pickup services for <strong>{selectedCustomer.name}</strong> ({selectedCustomer.code}) due to unpaid balances.
            </p>

            <div style={{ background: 'var(--bg-app)', padding: '16px', borderRadius: '8px', fontSize: '12px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span>Scheduled Collection Cancelled:</span>
                <strong style={{ color: 'var(--color-danger)' }}>Yes</strong>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span>Notify Customer via Text/Mail:</span>
                <label className="switch">
                  <input type="checkbox" checked={notifyCustomer} onChange={(e) => setNotifyCustomer(e.target.checked)} />
                  <span className="slider"></span>
                </label>
              </div>
            </div>

            <div className="modal-actions">
              <button className="btn-outline" onClick={() => setShowSuspendModal(false)}>Cancel</button>
              <button className="btn-danger" onClick={handleSuspendConfirm}>Confirm Suspension</button>
            </div>
          </div>
        </div>
      )}

      {/* ── Batch Send Reminders Modal ── */}
      {showReminderModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>Batch Send Payment Reminders</h3>
            <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
              Configure and broadcast billing demand notices to all clients with outstanding balances.
            </p>

            <div className="form-group">
              <label>Broadcasting Recipients</label>
              <select defaultValue="all-defaulters">
                <option value="all-defaulters">All Outstanding Accounts (3 accounts found)</option>
                <option value="critical">Critical Only (+10 Overdue Days)</option>
              </select>
            </div>

            <div className="form-group">
              <label>Reminder Message Template</label>
              <textarea
                rows="4"
                defaultValue="Dear Customer, this is a reminder that your garbage collection bill has a pending balance of [Balance]. Please clear to avoid service suspension."
              />
            </div>

            <div className="modal-actions">
              <button className="btn-outline" onClick={() => setShowReminderModal(false)}>Cancel</button>
              <button className="btn-primary" onClick={() => {
                alert('Broadcasted payment reminders to 3 customers successfully.');
                setShowReminderModal(false);
              }}>
                Broadcast Notices
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
