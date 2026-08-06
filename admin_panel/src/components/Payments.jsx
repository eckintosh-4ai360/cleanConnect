import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import {
  collection,
  onSnapshot,
  doc,
  updateDoc,
  addDoc,
  writeBatch,
  getDocs,
  serverTimestamp,
  increment,
  query,
  orderBy,
  where,
} from 'firebase/firestore';

export default function Payments() {
  const [invoices, setInvoices] = useState([]);
  const [selectedInvoice, setSelectedInvoice] = useState(null);
  const [loading, setLoading] = useState(true);
  const [showBatchModal, setShowBatchModal] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [billingCycle, setBillingCycle] = useState('current');

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
    setActionLoading(true);
    try {
      const customersSnap = await getDocs(collection(db, 'customers'));
      const customers = customersSnap.docs
        .map((d) => ({ id: d.id, ...d.data() }))
        .filter((customer) => customer.subscriptionStatus !== 'suspended');

      if (customers.length === 0) {
        alert('No active customers found to invoice.');
        setActionLoading(false);
        return;
      }

      const now = new Date();
      const cycleDate =
        billingCycle === 'previous'
          ? new Date(now.getFullYear(), now.getMonth() - 1, 1)
          : new Date(now.getFullYear(), now.getMonth(), 1);
      const cycleKey = `${cycleDate.getFullYear()}-${String(cycleDate.getMonth() + 1).padStart(2, '0')}`;
      const cycleLabel = cycleDate.toLocaleDateString('en-US', {
        month: 'long',
        year: 'numeric',
      });

      const existingSnap = await getDocs(
        query(collection(db, 'payments'), where('billingCycle', '==', cycleKey)),
      );
      const alreadyInvoiced = new Set(
        existingSnap.docs.map((invoiceDoc) => invoiceDoc.data().customerId),
      );

      const invoiceCustomers = customers.filter(
        (customer) => !alreadyInvoiced.has(customer.id),
      );

      if (invoiceCustomers.length === 0) {
        alert(`All active customers already have ${cycleLabel} invoices.`);
        setActionLoading(false);
        setShowBatchModal(false);
        return;
      }

      const batch = writeBatch(db);
      invoiceCustomers.forEach((customer) => {
        const amount = Number(customer.subscriptionFee ?? 0) || 50;
        const customerName =
          customer.displayName || customer.fullName || customer.email || 'Customer';
        const invoiceRef = doc(collection(db, 'payments'));
        const invoice = {
          customerId: customer.id,
          customerName,
          customerEmail: customer.email ?? '',
          amount,
          billingCycle: cycleKey,
          invoiceDate: serverTimestamp(),
          dueDate: new Date(now.getFullYear(), now.getMonth(), now.getDate() + 14),
          status: 'unpaid',
          method: customer.paymentMethod ?? 'Mobile Money',
          description: `${cycleLabel} waste collection service invoice`,
          sentAt: serverTimestamp(),
        };

        batch.set(invoiceRef, invoice);
        batch.set(
          doc(db, 'customers', customer.id),
          {
            outstandingBalance: increment(amount),
            lastInvoiceId: invoiceRef.id,
            lastInvoiceDate: serverTimestamp(),
            updatedAt: serverTimestamp(),
          },
          { merge: true },
        );
        batch.set(doc(collection(db, 'customers', customer.id, 'serviceHistory')), {
          title: `${cycleLabel} Service Invoice`,
          type: 'payment',
          date: serverTimestamp(),
          status: 'pending',
          amountPaid: amount,
          receiptNumber: invoiceRef.id,
          invoiceId: invoiceRef.id,
        });
      });

      await batch.commit();
      await addDoc(collection(db, 'admin_notifications'), {
        title: 'Batch Invoices Sent',
        message: `${invoiceCustomers.length} ${cycleLabel} invoice${invoiceCustomers.length === 1 ? '' : 's'} sent to customers.`,
        type: 'payment',
        isRead: false,
        createdAt: serverTimestamp(),
      });

      alert(`Sent ${invoiceCustomers.length} ${cycleLabel} invoice${invoiceCustomers.length === 1 ? '' : 's'} to customers.`);
      setShowBatchModal(false);
    } catch (err) {
      alert('Failed to send batch invoices: ' + err.message);
    }
    setActionLoading(false);
  };

  // Derived metrics
  const totalInvoiced = invoices.reduce((s, i) => s + (i.amount ?? 0), 0);
  const totalPaid = invoices.filter(i => i.status === 'paid').reduce((s, i) => s + (i.amount ?? 0), 0);
  const totalUnpaid = invoices.filter(i => i.status !== 'paid').reduce((s, i) => s + (i.amount ?? 0), 0);
  const paystackCount = invoices.filter(i => (i.method ?? '').toLowerCase().includes('paystack')).length;

  const formatDate = (date) => {
    if (!date) return '—';
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  };

  const statusBadge = (status) => {
    if (status === 'paid') return 'badge-active';
    if (status === 'overdue') return 'badge-defaulter';
    return 'badge-pending';
  };

  const methodIcon = (method) => {
    if (!method) return '💳';
    const m = method.toLowerCase();
    if (m.includes('mobile')) return '📱';
    if (m.includes('card') || m.includes('credit') || m.includes('debit')) return '💳';
    if (m.includes('paystack')) return '🔒';
    return '💳';
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
            GHS {totalInvoiced.toFixed(2)}
          </span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-success)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Invoices Paid</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-success)' }}>
            GHS {totalPaid.toFixed(2)}
          </span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-danger)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Unpaid Balances</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-danger)' }}>
            GHS {totalUnpaid.toFixed(2)}
          </span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-primary)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Paystack Payments</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-primary)' }}>
            {paystackCount}
          </span>
          <span style={{ fontSize: '10px', color: 'var(--text-muted)' }}>transactions</span>
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
                  <th>Method</th>
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
                      <td>GHS {(inv.amount ?? 0).toFixed(2)}</td>
                      <td>{formatDate(inv.invoiceDate)}</td>
                      <td>
                        <span title={inv.method ?? '—'} style={{ fontSize: '16px' }}>
                          {methodIcon(inv.method)}
                        </span>
                        {' '}
                        <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                          {inv.method?.includes('Paystack') ? 'Paystack' : (inv.method ?? '—')}
                        </span>
                      </td>
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

              {/* Paystack Reference Row */}
              {selectedInvoice.paymentReference && (
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontWeight: 'bold', color: 'var(--text-secondary)' }}>Paystack Ref:</span>
                  <span
                    style={{
                      fontFamily: 'monospace',
                      fontSize: '11px',
                      background: 'var(--border-divider)',
                      padding: '2px 8px',
                      borderRadius: '6px',
                      color: 'var(--color-primary)',
                      letterSpacing: '0.5px',
                    }}
                  >
                    {selectedInvoice.paymentReference}
                  </span>
                </div>
              )}

              <div style={{ display: 'flex', justifyContent: 'space-between', borderTop: '1px solid var(--border-divider)', paddingTop: '10px' }}>
                <span style={{ fontWeight: 'bold', fontSize: '13px' }}>Total Amount:</span>
                <strong style={{ fontSize: '15px', color: 'var(--color-primary)' }}>GHS {(selectedInvoice.amount ?? 0).toFixed(2)}</strong>
              </div>

              {/* Paystack Secured badge */}
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px', paddingTop: '4px' }}>
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="var(--text-muted)" strokeWidth="2"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
                <span style={{ fontSize: '10px', color: 'var(--text-muted)' }}>Secured by Paystack</span>
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
              Generate monthly trash collection invoices and deliver them to customer app accounts.
            </p>
            <div className="form-group">
              <label>Billing Cycle</label>
              <select value={billingCycle} onChange={(e) => setBillingCycle(e.target.value)}>
                <option value="current">Current Month</option>
                <option value="previous">Previous Month</option>
              </select>
            </div>
            <div className="modal-actions">
              <button className="btn-outline" onClick={() => setShowBatchModal(false)} disabled={actionLoading}>Cancel</button>
              <button className="btn-primary" onClick={handleGenerateBatch} disabled={actionLoading}>
                {actionLoading ? 'Sending...' : 'Generate & Dispatch'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
