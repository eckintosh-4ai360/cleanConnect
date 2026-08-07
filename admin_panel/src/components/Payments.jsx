import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import {
  collection,
  onSnapshot,
  doc,
  updateDoc,
  setDoc,
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
  const [showPricingModal, setShowPricingModal] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [savingPricing, setSavingPricing] = useState(false);
  const [billingCycle, setBillingCycle] = useState('current');

  // Dynamic Subscription Pricing State (default base rates)
  const [pricingData, setPricingData] = useState({
    weekly120: 35,
    weekly240: 50,
    weekly360: 70,
    biweekly120: 65,
    biweekly240: 90,
    biweekly360: 120,
    monthly120: 110,
    monthly240: 160,
    monthly360: 210,
  });

  // Calculate Pay-As-You-Go rates automatically as Weekly Price + 30% of Weekly Price (130%)
  const payg120 = (Number(pricingData.weekly120 || 0) * 1.30).toFixed(2);
  const payg240 = (Number(pricingData.weekly240 || 0) * 1.30).toFixed(2);
  const payg360 = (Number(pricingData.weekly360 || 0) * 1.30).toFixed(2);

  // Listen to live pricingPlans from Firestore
  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'pricingPlans'), (snap) => {
      if (!snap.empty) {
        const plansMap = {};
        snap.docs.forEach(docSnap => {
          plansMap[docSnap.id] = docSnap.data();
        });

        if (plansMap['weekly']?.prices) {
          setPricingData(prev => ({
            ...prev,
            weekly120: plansMap['weekly'].prices['120L'] ?? prev.weekly120,
            weekly240: plansMap['weekly'].prices['240L'] ?? prev.weekly240,
            weekly360: plansMap['weekly'].prices['360L'] ?? prev.weekly360,
            biweekly120: plansMap['biweekly']?.prices?.['120L'] ?? prev.biweekly120,
            biweekly240: plansMap['biweekly']?.prices?.['240L'] ?? prev.biweekly240,
            biweekly360: plansMap['biweekly']?.prices?.['360L'] ?? prev.biweekly360,
            monthly120: plansMap['monthly']?.prices?.['120L'] ?? prev.monthly120,
            monthly240: plansMap['monthly']?.prices?.['240L'] ?? prev.monthly240,
            monthly360: plansMap['monthly']?.prices?.['360L'] ?? prev.monthly360,
          }));
        }
      }
    });
    return () => unsub();
  }, []);

  const handleSaveSubscriptionPrices = async (e) => {
    e.preventDefault();
    setSavingPricing(true);
    try {
      const w120 = Number(pricingData.weekly120 || 0);
      const w240 = Number(pricingData.weekly240 || 0);
      const w360 = Number(pricingData.weekly360 || 0);

      const bw120 = Number(pricingData.biweekly120 || 0);
      const bw240 = Number(pricingData.biweekly240 || 0);
      const bw360 = Number(pricingData.biweekly360 || 0);

      const m120 = Number(pricingData.monthly120 || 0);
      const m240 = Number(pricingData.monthly240 || 0);
      const m360 = Number(pricingData.monthly360 || 0);

      // PAYG rates = Weekly Price + 30% of Weekly Price (1.30 * Weekly Price)
      const p120 = Number((w120 * 1.30).toFixed(2));
      const p240 = Number((w240 * 1.30).toFixed(2));
      const p360 = Number((w360 * 1.30).toFixed(2));

      // ── Step 1: Save Core Pricing Plans to Firestore
      const batch = writeBatch(db);

      // 1. Weekly Plan Doc
      batch.set(doc(db, 'pricingPlans', 'weekly'), {
        name: 'Weekly Plan',
        frequency: 'Weekly',
        description: 'Most popular for busy households',
        isPayg: false,
        prices: { '120L': w120, '240L': w240, '360L': w360 },
        updatedAt: serverTimestamp(),
        createdAt: serverTimestamp(),
      }, { merge: true });

      // 2. Bi-weekly Plan Doc
      batch.set(doc(db, 'pricingPlans', 'biweekly'), {
        name: 'Bi-weekly Plan',
        frequency: 'Bi-weekly',
        description: 'Eco-conscious & flexible',
        isPayg: false,
        prices: { '120L': bw120, '240L': bw240, '360L': bw360 },
        updatedAt: serverTimestamp(),
        createdAt: serverTimestamp(),
      }, { merge: true });

      // 3. Monthly Plan Doc
      batch.set(doc(db, 'pricingPlans', 'monthly'), {
        name: 'Monthly Plan',
        frequency: 'Monthly',
        description: 'Low volume waste collection',
        isPayg: false,
        prices: { '120L': m120, '240L': m240, '360L': m360 },
        updatedAt: serverTimestamp(),
        createdAt: serverTimestamp(),
      }, { merge: true });

      // 4. Pay-As-You-Go Plan Doc (Automatically Weekly + 30%)
      batch.set(doc(db, 'pricingPlans', 'payg'), {
        name: 'Pay-As-You-Go',
        frequency: 'Pay-As-You-Go',
        description: 'Pay per collection request (Weekly price + 30% surcharge)',
        isPayg: true,
        prices: { '120L': p120, '240L': p240, '360L': p360 },
        updatedAt: serverTimestamp(),
        createdAt: serverTimestamp(),
      }, { merge: true });

      await batch.commit();

      // ── Step 2: Optional Settings & Admin Notification (silent fallback if rules restrict settings)
      try {
        await setDoc(doc(db, 'settings', 'subscription_pricing'), {
          weeklyFee: w240,
          biweeklyFee: bw240,
          monthlyFee: m240,
          paygFee: p240,
          paygRatio: 1.30,
          updatedAt: serverTimestamp(),
        }, { merge: true });
      } catch (settingsErr) {
        console.warn('Settings summary doc skipped:', settingsErr);
      }

      try {
        await addDoc(collection(db, 'admin_notifications'), {
          title: 'Subscription Pricing Updated',
          message: `Admin updated subscription plans. Pay-As-You-Go set to Weekly + 30% (GHS ${p240} for 240L bin).`,
          type: 'pricing_updated',
          isRead: false,
          createdAt: serverTimestamp(),
        });
      } catch (notifErr) {
        console.warn('Admin notification skipped:', notifErr);
      }

      alert(`Subscription & PAYG Prices updated successfully!\nPay-As-You-Go rate automatically set to Weekly + 30% (GHS ${p240}/pickup for 240L bin).`);
      setShowPricingModal(false);
    } catch (err) {
      alert('Failed to save subscription prices: ' + err.message);
    }
    setSavingPricing(false);
  };

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
            Verify collection billing invoices, set dynamic subscription prices, and configure client accounts.
          </p>
        </div>
        <div style={{ display: 'flex', gap: '10px' }}>
          <button className="btn-outline" style={{ display: 'flex', alignItems: 'center', gap: '6px' }} onClick={() => setShowPricingModal(true)}>
            ⚙️ Set Subscription Prices
          </button>
          <button className="btn-primary" onClick={() => setShowBatchModal(true)}>
            Send Batch Invoices
          </button>
        </div>
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

      {/* ── Active Subscription & PAYG Pricing Banner ── */}
      <div
        className="card-glass"
        style={{
          background: 'linear-gradient(135deg, rgba(62,193,107,0.08), rgba(240,165,0,0.08))',
          border: '1px solid rgba(62,193,107,0.3)',
          display: 'flex',
          justify: 'space-between',
          alignItems: 'center',
          padding: '16px 20px',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
          <div
            style={{
              width: '42px',
              height: '42px',
              borderRadius: '50%',
              background: 'var(--color-success)',
              display: 'flex',
              alignItems: 'center',
              justify: 'center',
              fontSize: '20px',
              color: 'white',
              flexShrink: 0,
            }}
          >
            🏷️
          </div>
          <div>
            <h4 style={{ fontSize: '14px', fontWeight: '800', margin: 0 }}>
              Active Subscription Rates & PAYG Pricing (Weekly + 30%)
            </h4>
            <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px', display: 'flex', gap: '16px' }}>
              <span>Weekly Plan: <strong>GHS {Number(pricingData.weekly240 || 50).toFixed(2)}</strong> (240L)</span>
              <span>•</span>
              <span style={{ color: 'var(--color-success)', fontWeight: 'bold' }}>
                PAYG Rate (Weekly + 30%): <strong>GHS {payg240}/pickup</strong> (240L)
              </span>
            </div>
          </div>
        </div>
        <button
          className="btn-outline"
          style={{ padding: '6px 14px', fontSize: '12px', whiteSpace: 'nowrap' }}
          onClick={() => setShowPricingModal(true)}
        >
          Edit Rates
        </button>
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

      {/* ── Subscription & Pay-As-You-Go Pricing Manager Modal ── */}
      {showPricingModal && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '580px', width: '100%' }}>
            <h3 style={{ fontSize: '18px', marginBottom: '4px' }}>Configure Subscription Pricing & PAYG Rates</h3>
            <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginBottom: '16px' }}>
              Set subscription prices dynamically. Pay-As-You-Go price is automatically calculated as <strong>30% of the regular Weekly Plan price</strong>.
            </p>

            <form onSubmit={handleSaveSubscriptionPrices} style={{ display: 'flex', flexDirection: 'column', gap: '18px' }}>

              {/* ── Weekly Plan Pricing ── */}
              <div style={{ background: 'var(--bg-app)', padding: '14px', borderRadius: '10px', border: '1px solid var(--border-divider)' }}>
                <h4 style={{ fontSize: '13px', fontWeight: '800', color: 'var(--color-primary)', marginBottom: '8px' }}>
                  1. Regular Weekly Plan Prices (Base Rate)
                </h4>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '10px' }}>
                  {['120L', '240L', '360L'].map((size) => {
                    const key = `weekly${size.replace('L', '')}`;
                    return (
                      <div key={size} style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                        <label style={{ fontSize: '11px', fontWeight: 'bold' }}>{size} Bin (GHS/wk)</label>
                        <input
                          type="number"
                          step="0.5"
                          min="0"
                          value={pricingData[key]}
                          onChange={(e) => setPricingData({ ...pricingData, [key]: e.target.value })}
                          required
                          style={{ padding: '8px', borderRadius: '6px', border: '1px solid var(--border-divider)', fontSize: '13px', fontWeight: '700' }}
                        />
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* ── Auto-calculated PAYG Rates Card (Weekly + 30% Rule) ── */}
              <div style={{ background: 'rgba(62,193,107,0.1)', padding: '14px', borderRadius: '10px', border: '1px solid var(--color-success)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                  <h4 style={{ fontSize: '13px', fontWeight: '800', color: 'var(--color-success)', margin: 0 }}>
                    ⚡ Pay-As-You-Go Rates (Weekly Price + 30% Surcharge)
                  </h4>
                  <span style={{ fontSize: '10px', background: 'var(--color-success)', color: 'white', padding: '2px 8px', borderRadius: '10px', fontWeight: 'bold' }}>
                    WEEKLY + 30% RULE
                  </span>
                </div>
                <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginBottom: '10px' }}>
                  Customers paying per pickup pay the weekly rate plus 30% per bin request.
                </p>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '10px' }}>
                  <div style={{ background: 'white', padding: '8px 12px', borderRadius: '6px', textAlign: 'center' }}>
                    <div style={{ fontSize: '10px', color: 'var(--text-muted)', fontWeight: 'bold' }}>120L PAYG</div>
                    <div style={{ fontSize: '15px', fontWeight: '900', color: 'var(--color-success)' }}>GHS {payg120}</div>
                    <div style={{ fontSize: '9px', color: 'var(--text-muted)' }}>GHS {pricingData.weekly120 || 0} + 30%</div>
                  </div>
                  <div style={{ background: 'white', padding: '8px 12px', borderRadius: '6px', textAlign: 'center' }}>
                    <div style={{ fontSize: '10px', color: 'var(--text-muted)', fontWeight: 'bold' }}>240L PAYG</div>
                    <div style={{ fontSize: '15px', fontWeight: '900', color: 'var(--color-success)' }}>GHS {payg240}</div>
                    <div style={{ fontSize: '9px', color: 'var(--text-muted)' }}>GHS {pricingData.weekly240 || 0} + 30%</div>
                  </div>
                  <div style={{ background: 'white', padding: '8px 12px', borderRadius: '6px', textAlign: 'center' }}>
                    <div style={{ fontSize: '10px', color: 'var(--text-muted)', fontWeight: 'bold' }}>360L PAYG</div>
                    <div style={{ fontSize: '15px', fontWeight: '900', color: 'var(--color-success)' }}>GHS {payg360}</div>
                    <div style={{ fontSize: '9px', color: 'var(--text-muted)' }}>GHS {pricingData.weekly360 || 0} + 30%</div>
                  </div>
                </div>
              </div>

              {/* ── Bi-weekly Plan Pricing ── */}
              <div style={{ background: 'var(--bg-app)', padding: '14px', borderRadius: '10px', border: '1px solid var(--border-divider)' }}>
                <h4 style={{ fontSize: '13px', fontWeight: '800', color: 'var(--text-primary)', marginBottom: '8px' }}>
                  2. Bi-weekly Plan Prices
                </h4>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '10px' }}>
                  {['120L', '240L', '360L'].map((size) => {
                    const key = `biweekly${size.replace('L', '')}`;
                    return (
                      <div key={size} style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                        <label style={{ fontSize: '11px', fontWeight: 'bold' }}>{size} Bin (GHS/bi-wk)</label>
                        <input
                          type="number"
                          step="0.5"
                          min="0"
                          value={pricingData[key]}
                          onChange={(e) => setPricingData({ ...pricingData, [key]: e.target.value })}
                          required
                          style={{ padding: '8px', borderRadius: '6px', border: '1px solid var(--border-divider)', fontSize: '13px', fontWeight: '700' }}
                        />
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* ── Monthly Plan Pricing ── */}
              <div style={{ background: 'var(--bg-app)', padding: '14px', borderRadius: '10px', border: '1px solid var(--border-divider)' }}>
                <h4 style={{ fontSize: '13px', fontWeight: '800', color: 'var(--text-primary)', marginBottom: '8px' }}>
                  3. Monthly Plan Prices
                </h4>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '10px' }}>
                  {['120L', '240L', '360L'].map((size) => {
                    const key = `monthly${size.replace('L', '')}`;
                    return (
                      <div key={size} style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                        <label style={{ fontSize: '11px', fontWeight: 'bold' }}>{size} Bin (GHS/mo)</label>
                        <input
                          type="number"
                          step="0.5"
                          min="0"
                          value={pricingData[key]}
                          onChange={(e) => setPricingData({ ...pricingData, [key]: e.target.value })}
                          required
                          style={{ padding: '8px', borderRadius: '6px', border: '1px solid var(--border-divider)', fontSize: '13px', fontWeight: '700' }}
                        />
                      </div>
                    );
                  })}
                </div>
              </div>

              <div className="modal-actions">
                <button type="button" className="btn-outline" onClick={() => setShowPricingModal(false)} disabled={savingPricing}>Cancel</button>
                <button type="submit" className="btn-primary" disabled={savingPricing}>
                  {savingPricing ? 'Updating...' : 'Save Pricing Plans'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
