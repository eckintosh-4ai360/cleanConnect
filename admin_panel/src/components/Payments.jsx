import React, { useState } from 'react';

export default function Payments() {
  const [invoices, setInvoices] = useState([
    { id: 'INV-1300482', client: 'Acme Corp', amount: '$2,150.00', date: 'Oct 15, 2026', status: 'Unpaid', method: 'Bank Transfer' },
    { id: 'INV-1300481', client: 'Acme Corp', amount: '$2,100.00', date: 'Sep 15, 2026', status: 'Unpaid', method: 'Bank Transfer' },
    { id: 'INV-1300475', client: 'Summit Tech Solutions', amount: '$2,800.00', date: 'Oct 10, 2026', status: 'Unpaid', method: 'Mobile Money' },
    { id: 'INV-1300462', client: 'Glow Hair Salon', amount: '$450.00', date: 'Oct 04, 2026', status: 'Overdue', method: 'Mobile Money' },
    { id: 'INV-1300450', client: 'Golden Spoon Bakery', amount: '$600.00', date: 'Oct 01, 2026', status: 'Paid', method: 'Card Payment' },
  ]);

  const [selectedInvoice, setSelectedInvoice] = useState(invoices[0]);
  const [showBatchModal, setShowBatchModal] = useState(false);

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
          <span className="metric-value" style={{ fontSize: '24px' }}>$32,450.00</span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-success)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Invoices Paid</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-success)' }}>$24,350.00</span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-danger)' }}>
          <span className="metric-title" style={{ fontSize: '10px' }}>Unpaid Balances</span>
          <span className="metric-value" style={{ fontSize: '24px', color: 'var(--color-danger)' }}>$8,100.00</span>
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
                {invoices.map((inv) => (
                  <tr
                    key={inv.id}
                    onClick={() => setSelectedInvoice(inv)}
                    style={{ cursor: 'pointer', background: selectedInvoice.id === inv.id ? 'var(--border-divider)' : 'transparent' }}
                  >
                    <td style={{ fontWeight: '700', color: 'var(--color-primary)' }}>{inv.id}</td>
                    <td style={{ fontWeight: '600' }}>{inv.client}</td>
                    <td>{inv.amount}</td>
                    <td>{inv.date}</td>
                    <td>
                      <span className={`badge ${
                        inv.status === 'Paid' ? 'badge-active' :
                        inv.status === 'Unpaid' ? 'badge-pending' : 'badge-defaulter'
                      }`}>
                        {inv.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Right Side: Invoice details */}
        {selectedInvoice && (
          <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <h3 style={{ fontSize: '16px' }}>Invoice Details ({selectedInvoice.id})</h3>

            <div style={{ background: 'var(--bg-app)', padding: '16px', borderRadius: '8px', display: 'flex', flexDirection: 'column', gap: '12px', fontSize: '12px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ fontWeight: 'bold', color: 'var(--text-secondary)' }}>Client Name:</span>
                <strong style={{ fontSize: '13px' }}>{selectedInvoice.client}</strong>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ fontWeight: 'bold', color: 'var(--text-secondary)' }}>Invoice Date:</span>
                <span>{selectedInvoice.date}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ fontWeight: 'bold', color: 'var(--text-secondary)' }}>Payment Method:</span>
                <span>{selectedInvoice.method}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderTop: '1px solid var(--border-divider)', paddingTop: '10px' }}>
                <span style={{ fontWeight: 'bold', fontSize: '13px' }}>Total Amount:</span>
                <strong style={{ fontSize: '15px', color: 'var(--color-primary)' }}>{selectedInvoice.amount}</strong>
              </div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              <button className="btn-primary" style={{ justifyContent: 'center' }} onClick={() => alert('Receipt sent to customer email!')}>
                Email Payment Receipt
              </button>
              <button className="btn-outline" style={{ justifyContent: 'center' }} onClick={() => {
                alert(`Invoice ${selectedInvoice.id} marked as Paid successfully.`);
                setInvoices(prev => prev.map(inv => inv.id === selectedInvoice.id ? { ...inv, status: 'Paid' } : inv));
                setSelectedInvoice(prev => ({ ...prev, status: 'Paid' }));
              }}>
                Mark as Paid
              </button>
            </div>
          </div>
        )}
      </div>

      {/* ── Send Batch Invoices Modal ── */}
      {showBatchModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>Send Batch Invoices</h3>
            <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
              Generate and deliver monthly trash collection invoices to client billing emails.
            </p>
            <div className="form-group">
              <label>Billing Cycle</label>
              <select defaultValue="current">
                <option value="current">Current Month (October 2026)</option>
                <option value="previous">Previous Month (September 2026)</option>
              </select>
            </div>
            <div className="modal-actions">
              <button className="btn-outline" onClick={() => setShowBatchModal(false)}>Cancel</button>
              <button className="btn-primary" onClick={() => {
                alert('Batch invoices generated and sent to all 5 register customer domains.');
                setShowBatchModal(false);
              }}>
                Generate & Dispatch
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
