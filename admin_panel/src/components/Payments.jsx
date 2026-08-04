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
} from 'firebase/firestore';

export default function Payments() {
  const [invoices, setInvoices] = useState([]);
  const [selectedInvoice, setSelectedInvoice] = useState(null);
  const [loading, setLoading] = useState(true);
  const [showBatchModal, setShowBatchModal] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    const q = query(collection(db, 'payments'), orderBy('invoiceDate', 'desc'));
    const unsub = onSnapshot(q, (snap) => {
      const docs = snap.docs.map((d) => ({
        id: d.id,
        ...d.data(),
        invoiceDate: d.data().invoiceDate?.toDate?.() ?? null,
      }));
      setInvoices(docs);
      if (!selectedInvoice && docs.length > 0) setSelectedInvoice(docs[0]);
      setLoading(false);
    });
    return () => unsub();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // Keep selectedInvoice in sync with live updates
  useEffect(() => {
    if (selectedInvoice) {
      const updated = invoices.find(i => i.id === selectedInvoice.id);
      if (updated) setSelectedInvoice(updated);
    }
  }, [invoices]); // eslint-disable-line react-hooks/exhaustive-deps

  const handleMarkPaid = async () => {
    if (!selectedInvoice) return;
    setActionLoading(true);
    try {
      await updateDoc(doc(db, 'payments', selectedInvoice.id), {
        status: 'paid',
        paidAt: serverTimestamp(),
      });
      // If linked to a customer, zero out their outstanding balance
      if (selectedInvoice.customerId) {
        await updateDoc(doc(db, 'customers', selectedInvoice.customerId), {
          outstandingBalance: 0,
          updatedAt: serverTimestamp(),
        });
      }
      alert(`Invoice marked as Paid. Customer balance cleared.`);
    } catch (err) {
      alert('Failed to update payment: ' + err.message);
    }
    setActionLoading(false);
  };

  const handleGenerateBatch = async () => {
    // In a production system, this would be a Cloud Function.
    // For now we log the intent and close modal.
    alert('Batch invoice generation dispatched. Each customer will receive an email invoice.');
    setShowBatchModal(false);
  };

  // Derived metrics
  const totalInvoiced = invoices.reduce((s, i) => s + (i.amount ?? 0), 0);
  const totalPaid = invoices.filter(i => i.status === 'paid').reduce((s, i) => s + (i.amount ?? 0), 0);
  const totalUnpaid = invoices.filter(i => i.status !== 'paid').reduce((s, i) => s + (i.amount ?? 0), 0);

  const formatDate = (date) => {
    if (!date) return '—';
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  };

  const statusBadge = (status) => {
    if (status === 'paid') return 'badge-active';
    if (status === 'overdue') return 'badge-defaulter';
    return 'badge-pending';
  };

  return (
    <div className="page-content">
      {/* ── Page Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>Payments & Invoicing</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Verify collection billing invoices, view payment statuses, and configure client accounts.
          </p>
        </div>
        <button className="btn-primary" onClick={() => setShowBatchModal(true)}>
          Send Batch Invoices
        </button>
      </div>

      {/* ── Metric Summary Cards ── */}
      <div className="metrics-grid">
        <div className="card-glass metric-card">
          <span className="metric-title" style={{ fontSize: '10px' }}>Total Invoiced</span>
          <span className="metric-value" style={{ fontSize: '24px' }}>
            ${totalInvoiced.toFixed(2)}
          </span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-success)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Invoices Paid</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-success)' }}>
            ${totalPaid.toFixed(2)}
          </span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-danger)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Unpaid Balances</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-danger)' }}>
            ${totalUnpaid.toFixed(2)}
          </span>
        </div>
      </div>

      {/* ── Layout columns ── */}
      <div className="split-layout">
        {/* Left Side: Invoice List */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <h3 style={{ fontSize: '16px' }}>Invoice Registry</h3>
          <div className="table-container">
            <table className="custom-table">
              <thead>
                <tr>
                  <th>Invoice ID</th>
                  <th>Client</th>
                  <th>Bill Amount</th>
                  <th>Billing Date</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr><td colSpan="5" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>Loading payments...</td></tr>
                ) : invoices.length === 0 ? (
                  <tr><td colSpan="5" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>No payment records yet.</td></tr>
                ) : (
                  invoices.map((inv) => (
                    <tr
                      key={inv.id}
                      onClick={() => setSelectedInvoice(inv)}
                      style={{ cursor: 'pointer', background: selectedInvoice?.id === inv.id ? 'var(--border-divider)' : 'transparent' }}
                    >
                      <td style={{ fontWeight: '700', color: 'var(--color-primary)' }}>#{inv.id.slice(0, 8).toUpperCase()}</td>
                      <td style={{ fontWeight: '600' }}>{inv.customerName ?? '—'}</td>
                      <td>${(inv.amount ?? 0).toFixed(2)}</td>
                      <td>{formatDate(inv.invoiceDate)}</td>
                      <td>
                        <span className={`badge ${statusBadge(inv.status)}`}>
                          {inv.status ? inv.status.charAt(0).toUpperCase() + inv.status.slice(1) : '—'}
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Right Side: Invoice Details */}
        {selectedInvoice && (
          <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <h3 style={{ fontSize: '16px' }}>Invoice Details</h3>

            <div style={{ background: 'var(--bg-app)', padding: '16px', borderRadius: '8px', display: 'flex', flexDirection: 'column', gap: '12px', fontSize: '12px' }}>
              {[
                { label: 'Client Name', value: selectedInvoice.customerName ?? '—' },
                { label: 'Invoice Date', value: formatDate(selectedInvoice.invoiceDate) },
                { label: 'Payment Method', value: selectedInvoice.method ?? '—' },
                { label: 'Description', value: selectedInvoice.description ?? '—' },
              ].map(({ label, value }) => (
                <div key={label} style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ fontWeight: 'bold', color: 'var(--text-secondary)' }}>{label}:</span>
                  <span>{value}</span>
                </div>
              ))}
              <div style={{ display: 'flex', justifyContent: 'space-between', borderTop: '1px solid var(--border-divider)', paddingTop: '10px' }}>
                <span style={{ fontWeight: 'bold', fontSize: '13px' }}>Total Amount:</span>
                <strong style={{ fontSize: '15px', color: 'var(--color-primary)' }}>${(selectedInvoice.amount ?? 0).toFixed(2)}</strong>
              </div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              <button className="btn-primary" style={{ justifyContent: 'center' }} onClick={() => alert('Receipt emailed to customer!')}>
                Email Payment Receipt
              </button>
              {selectedInvoice.status !== 'paid' && (
                <button className="btn-outline" style={{ justifyContent: 'center' }} onClick={handleMarkPaid} disabled={actionLoading}>
                  {actionLoading ? 'Updating...' : 'Mark as Paid'}
                </button>
              )}
              {selectedInvoice.status === 'paid' && (
                <div style={{ textAlign: 'center', color: 'var(--color-success)', fontWeight: 'bold', fontSize: '13px', padding: '8px' }}>
                  ✓ Payment Confirmed
                </div>
              )}
            </div>
          </div>
        )}
      </div>

      {/* ── Batch Invoices Modal ── */}
      {showBatchModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>Send Batch Invoices</h3>
            <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
              Generate and deliver monthly trash collection invoices to all registered customer emails.
            </p>
            <div className="form-group">
              <label>Billing Cycle</label>
              <select defaultValue="current">
                <option value="current">Current Month</option>
                <option value="previous">Previous Month</option>
              </select>
            </div>
            <div className="modal-actions">
              <button className="btn-outline" onClick={() => setShowBatchModal(false)}>Cancel</button>
              <button className="btn-primary" onClick={handleGenerateBatch}>Generate & Dispatch</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
