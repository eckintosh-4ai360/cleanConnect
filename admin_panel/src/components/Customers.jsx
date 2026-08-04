import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import {
  collection,
  onSnapshot,
  doc,
  updateDoc,
  addDoc,
  serverTimestamp,
  query,
  orderBy,
  where,
} from 'firebase/firestore';

export default function Customers() {
  const [customers, setCustomers] = useState([]);
  const [selectedCustomer, setSelectedCustomer] = useState(null);
  const [loading, setLoading] = useState(true);
  const [showSuspendModal, setShowSuspendModal] = useState(false);
  const [showReminderModal, setShowReminderModal] = useState(false);
  const [showAddModal, setShowAddModal] = useState(false);
  const [notifyCustomer, setNotifyCustomer] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);

  const [customerBins, setCustomerBins] = useState([]);
  const [customerRequests, setCustomerRequests] = useState([]);

  // Derived Metrics
  const totalOutstanding = customers.reduce((sum, c) => sum + (c.outstandingBalance ?? 0), 0);
  const criticalAccounts = customers.filter(c => (c.outstandingBalance ?? 0) > 0 && c.subscriptionStatus !== 'suspended').length;
  const activeClients = customers.filter(c => c.subscriptionStatus === 'active').length;

  useEffect(() => {
    let custDocs = [];
    let userDocs = [];

    const updateCombined = () => {
      const map = new Map();

      userDocs.forEach((u) => {
        const role = (u.role || '').toLowerCase();
        if (role === 'customer' || role === '' || !u.role) {
          map.set(u.id, {
            id: u.id,
            displayName: u.fullName || u.displayName || 'Customer',
            fullName: u.fullName || u.displayName || 'Customer',
            email: u.email || '—',
            phoneNumber: u.phoneNumber || u.phone || '—',
            contractType: u.contractType || 'Residential',
            subscriptionPlan: u.subscriptionPlan || 'Weekly Plan',
            subscriptionStatus: u.status || 'active',
            outstandingBalance: u.outstandingBalance || 0,
            ...u,
          });
        }
      });

      custDocs.forEach((c) => {
        const existing = map.get(c.id) || {};
        map.set(c.id, {
          ...existing,
          ...c,
          displayName: c.displayName || c.fullName || existing.displayName || 'Customer',
          fullName: c.fullName || c.displayName || existing.fullName || 'Customer',
        });
      });

      const merged = Array.from(map.values());
      setCustomers(merged);
      if (merged.length > 0 && !selectedCustomer) {
        setSelectedCustomer(merged[0]);
      }
      setLoading(false);
    };

    const unsubCust = onSnapshot(collection(db, 'customers'), (snap) => {
      custDocs = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      updateCombined();
    }, (err) => {
      console.warn('Customers listener:', err);
      setLoading(false);
    });

    const unsubUsers = onSnapshot(collection(db, 'users'), (snap) => {
      userDocs = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      updateCombined();
    }, (err) => {
      console.warn('Users listener:', err);
      setLoading(false);
    });

    return () => {
      unsubCust();
      unsubUsers();
    };
  }, []);

  // Listen to subcollections (bins & pickupRequests) for selected customer
  useEffect(() => {
    if (!selectedCustomer) {
      setCustomerBins([]);
      setCustomerRequests([]);
      return;
    }

    const binsQ = query(collection(db, 'customers', selectedCustomer.id, 'bins'));
    const unsubBins = onSnapshot(binsQ, (snap) => {
      setCustomerBins(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    }, () => setCustomerBins([]));

    const reqsQ = query(collection(db, 'customers', selectedCustomer.id, 'pickupRequests'), orderBy('createdAt', 'desc'));
    const unsubReqs = onSnapshot(reqsQ, (snap) => {
      setCustomerRequests(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    }, () => setCustomerRequests([]));

    return () => {
      unsubBins();
      unsubReqs();
    };
  }, [selectedCustomer?.id]);

  // Keep selectedCustomer in sync with live updates
  useEffect(() => {
    if (selectedCustomer) {
      const updated = customers.find(c => c.id === selectedCustomer.id);
      if (updated) setSelectedCustomer(updated);
    }
  }, [customers]);

  // ── Actions ───────────────────────────────────────────────────────────────
  const handleSuspendConfirm = async () => {
    if (!selectedCustomer) return;
    setActionLoading(true);
    try {
      await updateDoc(doc(db, 'customers', selectedCustomer.id), {
        subscriptionStatus: 'suspended',
        updatedAt: serverTimestamp(),
      });
      setShowSuspendModal(false);
    } catch (err) {
      alert('Failed to suspend: ' + err.message);
    }
    setActionLoading(false);
  };

  const handleAddCustomer = async (e) => {
    e.preventDefault();
    const form = new FormData(e.target);
    setActionLoading(true);
    try {
      await addDoc(collection(db, 'customers'), {
        displayName: form.get('name'),
        email: form.get('email'),
        phoneNumber: form.get('phone'),
        contractType: form.get('type'),
        subscriptionPlan: 'Weekly Plan',
        subscriptionFee: 0,
        subscriptionStatus: 'active',
        paymentMethod: 'Mobile Money',
        outstandingBalance: 0,
        createdAt: serverTimestamp(),
      });
      setShowAddModal(false);
    } catch (err) {
      alert('Failed to add customer: ' + err.message);
    }
    setActionLoading(false);
  };

  const handleResendInvoice = async () => {
    if (!selectedCustomer) return;
    // Log communication event in service history subcollection
    try {
      await addDoc(collection(db, 'customers', selectedCustomer.id, 'serviceHistory'), {
        title: 'Invoice Resent',
        type: 'payment',
        date: serverTimestamp(),
        status: 'pending',
        amountPaid: selectedCustomer.outstandingBalance ?? 0,
      });
      alert('Invoice resent successfully!');
    } catch {
      alert('Could not log invoice resend.');
    }
  };

  const statusBadgeClass = (status) => {
    if (status === 'active') return 'badge-active';
    if (status === 'suspended') return 'badge-defaulter';
    return 'badge-pending';
  };

  const statusLabel = (c) => {
    if (c.subscriptionStatus === 'suspended') return 'Suspended';
    if ((c.outstandingBalance ?? 0) > 0) return 'Outstanding';
    return 'Active';
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
          <button className="btn-primary" onClick={() => setShowAddModal(true)}>
            + New Customer Account
          </button>
        </div>
      </div>

      {/* ── Metric summaries ── */}
      <div className="metrics-grid">
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-danger)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Total Outstanding</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-danger)' }}>
            ${totalOutstanding.toFixed(2)}
          </span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-accent)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Outstanding Accounts</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-accent)' }}>
            {criticalAccounts} Accounts
          </span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-success)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Active Billing Agreements</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-success)' }}>
            {activeClients} Clients
          </span>
        </div>
      </div>

      {/* ── Main content grid ── */}
      <div className="split-layout">
        {/* Left: Customer List */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <h3 style={{ fontSize: '16px' }}>Client Accounts Directory</h3>
          <div className="table-container">
            <table className="custom-table">
              <thead>
                <tr>
                  <th>Client</th>
                  <th>Contract Type</th>
                  <th>Outstanding</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr><td colSpan="4" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>Loading customers...</td></tr>
                ) : customers.length === 0 ? (
                  <tr><td colSpan="4" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>No customers registered yet.</td></tr>
                ) : (
                  customers.map((c) => (
                    <tr
                      key={c.id}
                      onClick={() => setSelectedCustomer(c)}
                      style={{ cursor: 'pointer', background: selectedCustomer?.id === c.id ? 'var(--border-divider)' : 'transparent' }}
                    >
                      <td style={{ fontWeight: '700' }}>{c.displayName ?? c.fullName ?? '—'}</td>
                      <td>{c.contractType ?? c.subscriptionPlan ?? '—'}</td>
                      <td style={{ color: (c.outstandingBalance ?? 0) > 0 ? 'var(--color-danger)' : 'var(--text-primary)', fontWeight: (c.outstandingBalance ?? 0) > 0 ? '700' : 'normal' }}>
                        ${(c.outstandingBalance ?? 0).toFixed(2)}
                      </td>
                      <td>
                        <span className={`badge ${statusBadgeClass(c.subscriptionStatus)}`}>
                          {statusLabel(c)}
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Right: Customer Detail Card */}
        {selectedCustomer && (
          <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px', border: '1px solid rgba(239, 68, 68, 0.25)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <img
                src={selectedCustomer.photoUrl ?? `https://api.dicebear.com/7.x/initials/svg?seed=${selectedCustomer.displayName}`}
                alt={selectedCustomer.displayName}
                style={{ width: '48px', height: '48px', borderRadius: '8px', objectFit: 'cover' }}
              />
              <div>
                <h4 style={{ fontSize: '15px', fontWeight: '800' }}>{selectedCustomer.displayName ?? selectedCustomer.fullName}</h4>
                <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                  {selectedCustomer.contractType ?? selectedCustomer.subscriptionPlan} • {selectedCustomer.email ?? '—'}
                </p>
              </div>
            </div>

            <div style={{ borderTop: '1px solid var(--border-divider)', padding: '16px 0', display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', background: 'var(--bg-app)', padding: '12px', borderRadius: '8px' }}>
                <div>
                  <span style={{ fontSize: '10px', textTransform: 'uppercase', fontWeight: '700', color: 'var(--text-muted)' }}>Outstanding Due</span>
                  <p style={{ fontSize: '16px', fontWeight: '800', color: 'var(--color-danger)', marginTop: '4px' }}>
                    ${(selectedCustomer.outstandingBalance ?? 0).toFixed(2)}
                  </p>
                </div>
                <div>
                  <span style={{ fontSize: '10px', textTransform: 'uppercase', fontWeight: '700', color: 'var(--text-muted)' }}>Status</span>
                  <p style={{ fontSize: '16px', fontWeight: '800', color: 'var(--color-accent)', marginTop: '4px' }}>
                    {selectedCustomer.subscriptionStatus?.toUpperCase() ?? 'UNKNOWN'}
                  </p>
                </div>
              </div>

              <div>
                <span style={{ fontSize: '10px', textTransform: 'uppercase', fontWeight: '700', color: 'var(--text-muted)' }}>Payment Method</span>
                <p style={{ fontSize: '12px', marginTop: '4px', fontWeight: '600' }}>{selectedCustomer.paymentMethod ?? '—'}</p>
              </div>
              <div>
                <span style={{ fontSize: '10px', textTransform: 'uppercase', fontWeight: '700', color: 'var(--text-muted)' }}>Phone</span>
                <p style={{ fontSize: '12px', marginTop: '4px', fontWeight: '600' }}>{selectedCustomer.phoneNumber ?? '—'}</p>
              </div>

              {/* Registered Bins */}
              <div>
                <span style={{ fontSize: '10px', textTransform: 'uppercase', fontWeight: '700', color: 'var(--text-muted)' }}>
                  Registered Bins ({customerBins.length})
                </span>
                {customerBins.length === 0 ? (
                  <p style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>No bins registered yet.</p>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', marginTop: '6px' }}>
                    {customerBins.map((bin) => (
                      <div key={bin.id} style={{ background: 'var(--bg-app)', padding: '8px 10px', borderRadius: '6px', fontSize: '11px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <div>
                          <strong style={{ textTransform: 'capitalize' }}>{bin.type} Bin</strong> ({bin.size})
                          <div style={{ color: 'var(--text-muted)', fontSize: '10px' }}>S/N: {bin.serialNumber || '—'}</div>
                        </div>
                        <span className="badge badge-active" style={{ fontSize: '9px' }}>{bin.scheduleFrequency || 'Active'}</span>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Pickup Requests */}
              <div>
                <span style={{ fontSize: '10px', textTransform: 'uppercase', fontWeight: '700', color: 'var(--text-muted)' }}>
                  Pickup Requests ({customerRequests.length})
                </span>
                {customerRequests.length === 0 ? (
                  <p style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>No pickup requests submitted.</p>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', marginTop: '6px' }}>
                    {customerRequests.map((req) => (
                      <div key={req.id} style={{ background: 'var(--bg-app)', padding: '8px 10px', borderRadius: '6px', fontSize: '11px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <div>
                          <strong>{Array.isArray(req.binTypes) ? req.binTypes.join(', ') : 'Waste'}</strong>
                          <div style={{ color: 'var(--text-muted)', fontSize: '10px' }}>{req.location || 'Location specified'} ({req.timeSlot || 'Anytime'})</div>
                        </div>
                        <span className={`badge ${req.status === 'pending' ? 'badge-pending' : 'badge-active'}`} style={{ fontSize: '9px' }}>
                          {req.status?.toUpperCase()}
                        </span>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* Quick Actions */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginTop: 'auto' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                <button className="btn-primary" style={{ justifyContent: 'center' }} onClick={handleResendInvoice}>
                  Resend Invoice
                </button>
                <button className="btn-outline" style={{ justifyContent: 'center' }} onClick={() => alert('Reminder SMS & Mail sent!')}>
                  Send Reminder
                </button>
              </div>
              {selectedCustomer.subscriptionStatus !== 'suspended' && (
                <button className="btn-danger" style={{ justifyContent: 'center' }} onClick={() => setShowSuspendModal(true)}>
                  Suspend Service
                </button>
              )}
              {selectedCustomer.subscriptionStatus === 'suspended' && (
                <button className="btn-primary" style={{ justifyContent: 'center' }} onClick={async () => {
                  await updateDoc(doc(db, 'customers', selectedCustomer.id), { subscriptionStatus: 'active', updatedAt: serverTimestamp() });
                }}>
                  Reinstate Service
                </button>
              )}
            </div>
          </div>
        )}
      </div>

      {/* ── Suspend Service Modal ── */}
      {showSuspendModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', color: 'var(--color-danger)' }}>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0zM12 9v4M12 17h.01" />
              </svg>
              <h3 style={{ fontSize: '18px' }}>Confirm Service Suspension?</h3>
            </div>
            <p style={{ fontSize: '13px', color: 'var(--text-secondary)', lineHeight: '150%' }}>
              You are about to suspend sanitation pickup services for <strong>{selectedCustomer?.displayName}</strong> due to unpaid balances.
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
              <button className="btn-danger" onClick={handleSuspendConfirm} disabled={actionLoading}>
                {actionLoading ? 'Suspending...' : 'Confirm Suspension'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Add Customer Modal ── */}
      {showAddModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>New Customer Account</h3>
            <form onSubmit={handleAddCustomer} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div className="form-group">
                <label>Full Name / Business Name</label>
                <input name="name" type="text" placeholder="e.g. Acme Corp" required />
              </div>
              <div className="form-group">
                <label>Email Address</label>
                <input name="email" type="email" placeholder="e.g. billing@acme.com" required />
              </div>
              <div className="form-group">
                <label>Phone Number</label>
                <input name="phone" type="text" placeholder="e.g. 0244000000" />
              </div>
              <div className="form-group">
                <label>Contract Type</label>
                <select name="type">
                  <option value="Residential">Residential</option>
                  <option value="Commercial">Commercial</option>
                  <option value="Enterprise">Enterprise</option>
                </select>
              </div>
              <div className="modal-actions">
                <button type="button" className="btn-outline" onClick={() => setShowAddModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" disabled={actionLoading}>
                  {actionLoading ? 'Creating...' : 'Create Account'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── Batch Reminders Modal ── */}
      {showReminderModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>Batch Send Payment Reminders</h3>
            <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
              Broadcast billing demand notices to all clients with outstanding balances ({criticalAccounts} accounts).
            </p>
            <div className="form-group">
              <label>Reminder Message</label>
              <textarea rows="4" defaultValue="Dear Customer, this is a reminder that your waste collection bill has a pending balance. Please clear to avoid service suspension." />
            </div>
            <div className="modal-actions">
              <button className="btn-outline" onClick={() => setShowReminderModal(false)}>Cancel</button>
              <button className="btn-primary" onClick={() => {
                alert(`Broadcasted reminders to ${criticalAccounts} customers.`);
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
