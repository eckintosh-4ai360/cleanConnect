import React, { useEffect, useMemo, useState } from 'react';
import { supabase } from '../supabase';

const initialBinForm = {
  customerId: '',
  customerName: '',
  type: 'recycling',
  size: '240L',
  ownership: 'company',
  gpsLocation: '',
  scheduleFrequency: 'Weekly',
};

const statusOptions = ['active', 'maintenance', 'inactive', 'disabled'];

function generateSerialNumber(type = 'bin') {
  const prefix = type === 'organic' ? 'ORG' : 'REC';
  const now = new Date();
  const datePart = [
    now.getUTCFullYear(),
    String(now.getUTCMonth() + 1).padStart(2, '0'),
    String(now.getUTCDate()).padStart(2, '0'),
  ].join('');
  const timePart = now.getTime().toString(36).toUpperCase().slice(-5);
  const randomPart = Math.floor(1000 + Math.random() * 9000);
  return `CCB-${prefix}-${datePart}-${timePart}${randomPart}`;
}

function qrCodeUrl(serialNumber) {
  return `https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${encodeURIComponent(serialNumber)}`;
}

function formatDate(value) {
  if (!value) return 'Not recorded';
  return new Date(value).toLocaleDateString();
}

function formatPercent(value) {
  return `${Math.round((Number(value) || 0) * 100)}%`;
}

function capitalize(value) {
  if (!value) return 'Unknown';
  return `${value[0].toUpperCase()}${value.slice(1)}`;
}

export default function Bins() {
  const [bins, setBins] = useState([]);
  const [requests, setRequests] = useState([]);
  const [customers, setCustomers] = useState([]);
  const [selectedBin, setSelectedBin] = useState(null);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [binForm, setBinForm] = useState(initialBinForm);
  const [editForm, setEditForm] = useState({
    status: 'active',
    fillLevelPercentage: 0,
    scheduleFrequency: 'Weekly',
  });

  useEffect(() => {
    let mounted = true;

    const fetchBins = async () => {
      const { data, error } = await supabase
        .from('bins')
        .select('*')
        .order('registered_at', { ascending: false });
      if (mounted && !error) setBins(data);
    };
    fetchBins();
    const binsChannel = supabase
      .channel('bins_admin_changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'bins' }, fetchBins)
      .subscribe();

    const fetchRequests = async () => {
      const { data, error } = await supabase
        .from('bin_requests')
        .select('*')
        .order('created_at', { ascending: false });
      if (mounted && !error) setRequests(data);
    };
    fetchRequests();
    const requestsChannel = supabase
      .channel('bin_requests_admin_changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'bin_requests' }, fetchRequests)
      .subscribe();

    const fetchCustomers = async () => {
      const { data, error } = await supabase
        .from('customers')
        .select('id, profiles(full_name, email)');
      if (mounted && !error) {
        setCustomers(data.map((c) => ({
          id: c.id,
          displayName: c.profiles?.full_name,
          fullName: c.profiles?.full_name,
          email: c.profiles?.email,
        })));
      }
    };
    fetchCustomers();
    const customersChannel = supabase
      .channel('bins_customers_changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'customers' }, fetchCustomers)
      .subscribe();

    return () => {
      mounted = false;
      supabase.removeChannel(binsChannel);
      supabase.removeChannel(requestsChannel);
      supabase.removeChannel(customersChannel);
    };
  }, []);

  const customerMap = useMemo(() => {
    const map = new Map();
    customers.forEach((customer) => map.set(customer.id, customer));
    return map;
  }, [customers]);

  const pendingRequests = requests.filter((request) => request.status !== 'assigned');
  const activeBins = bins.filter((bin) => (bin.status || 'active') === 'active');
  const companyBins = bins.filter((bin) => (bin.ownership || 'company') === 'company');

  const customerName = (customerId, fallback) => {
    const customer = customerMap.get(customerId);
    return fallback || customer?.displayName || customer?.fullName || 'Customer';
  };

  const handleFormChange = (field, value) => {
    setBinForm((current) => ({ ...current, [field]: value }));
  };

  const handleCustomerSelect = (customerId) => {
    const customer = customerMap.get(customerId);
    setBinForm((current) => ({
      ...current,
      customerId,
      customerName: customer?.displayName || customer?.fullName || current.customerName,
    }));
  };

  const createBinForCustomer = async ({
    customerId,
    type,
    size,
    ownership = 'company',
    gpsLocation = '',
    scheduleFrequency = 'Weekly',
    requestId = null,
  }) => {
    const serialNumber = generateSerialNumber(type);
    const { data, error } = await supabase.rpc('admin_create_bin', {
      p_customer_id: customerId,
      p_serial_number: serialNumber,
      p_type: type,
      p_size: size,
      p_ownership: ownership,
      p_gps_location: gpsLocation,
      p_schedule_frequency: scheduleFrequency,
      p_request_id: requestId,
    });
    if (error) throw error;
    return { binId: data.id, serialNumber, qrUrl: data.qr_code_url };
  };

  const handleAssignRequest = async (request) => {
    setActionLoading(true);
    try {
      const result = await createBinForCustomer({
        customerId: request.customer_id,
        type: request.type || 'recycling',
        size: request.size || '240L',
        ownership: 'company',
        gpsLocation: request.gps_location || '',
        requestId: request.id,
      });
      alert(`Bin assigned with serial number ${result.serialNumber}`);
    } catch (err) {
      alert(`Failed to assign bin: ${err.message}`);
    }
    setActionLoading(false);
  };

  const handleCreateBin = async (e) => {
    e.preventDefault();
    if (!binForm.customerId) {
      alert('Please select a customer.');
      return;
    }

    setActionLoading(true);
    try {
      const result = await createBinForCustomer(binForm);
      setShowCreateModal(false);
      setBinForm(initialBinForm);
      alert(`Bin created with serial number ${result.serialNumber}`);
    } catch (err) {
      alert(`Failed to create bin: ${err.message}`);
    }
    setActionLoading(false);
  };

  const openEditModal = (bin) => {
    setSelectedBin(bin);
    setEditForm({
      status: bin.status || 'active',
      fillLevelPercentage: Math.round((bin.fill_level_percentage || 0) * 100),
      scheduleFrequency: bin.schedule_frequency || 'Weekly',
    });
    setShowEditModal(true);
  };

  const handleUpdateBin = async (e) => {
    e.preventDefault();
    if (!selectedBin?.id) return;

    setActionLoading(true);
    try {
      const { error } = await supabase
        .from('bins')
        .update({
          status: editForm.status,
          fill_level_percentage: Math.max(0, Math.min(100, Number(editForm.fillLevelPercentage))) / 100,
          schedule_frequency: editForm.scheduleFrequency,
        })
        .eq('id', selectedBin.id);
      if (error) throw error;
      setShowEditModal(false);
    } catch (err) {
      alert(`Failed to update bin: ${err.message}`);
    }
    setActionLoading(false);
  };

  return (
    <div className="page-content">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '16px' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>Bins Management</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Assign company bins, generate serial numbers, and manage QR-coded bin records.
          </p>
        </div>
        <button className="btn-primary" onClick={() => setShowCreateModal(true)}>
          + Create Company Bin
        </button>
      </div>

      <div className="metrics-grid">
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-primary)' }}>
          <span className="metric-title">Total Bins</span>
          <span className="metric-value" style={{ fontSize: '28px' }}>{bins.length}</span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-success)' }}>
          <span className="metric-title">Active Bins</span>
          <span className="metric-value" style={{ fontSize: '28px', color: 'var(--color-success)' }}>{activeBins.length}</span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-accent)' }}>
          <span className="metric-title">Pending Requests</span>
          <span className="metric-value" style={{ fontSize: '28px', color: 'var(--color-accent)' }}>{pendingRequests.length}</span>
        </div>
        <div className="card-glass metric-card" style={{ borderLeft: '4px solid var(--color-info)' }}>
          <span className="metric-title">Company Owned</span>
          <span className="metric-value" style={{ fontSize: '28px', color: 'var(--color-info)' }}>{companyBins.length}</span>
        </div>
      </div>

      <div className="split-layout">
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '18px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3 style={{ fontSize: '16px' }}>Pending Bin Requests</h3>
            <span className="badge badge-pending">{pendingRequests.length} OPEN</span>
          </div>
          <div className="table-container">
            <table className="custom-table">
              <thead>
                <tr>
                  <th>Customer</th>
                  <th>Type</th>
                  <th>Size</th>
                  <th>Location</th>
                  <th>Requested</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {pendingRequests.length === 0 ? (
                  <tr>
                    <td colSpan="6" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>
                      No pending company-bin requests.
                    </td>
                  </tr>
                ) : (
                  pendingRequests.map((request) => (
                    <tr key={request.id}>
                      <td style={{ fontWeight: '700' }}>{customerName(request.customer_id)}</td>
                      <td style={{ textTransform: 'capitalize' }}>{request.type || 'recycling'}</td>
                      <td>{request.size || '240L'}</td>
                      <td>{request.gps_location || 'Not provided'}</td>
                      <td style={{ color: 'var(--text-secondary)', fontSize: '12px' }}>{formatDate(request.created_at)}</td>
                      <td>
                        <button
                          className="btn-primary"
                          style={{ padding: '8px 12px', fontSize: '11px' }}
                          disabled={actionLoading}
                          onClick={() => handleAssignRequest(request)}
                        >
                          Assign Bin
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <h3 style={{ fontSize: '16px' }}>QR Serial Preview</h3>
          {selectedBin ? (
            <>
              <div style={{ background: 'white', padding: '16px', borderRadius: '8px', width: 'fit-content' }}>
                <img src={selectedBin.qr_code_url || qrCodeUrl(selectedBin.serial_number)} alt={selectedBin.serial_number} width="160" height="160" />
              </div>
              <div>
                <span style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: '800' }}>Serial Number</span>
                <p style={{ fontSize: '16px', fontWeight: '900', marginTop: '4px' }}>{selectedBin.serial_number}</p>
              </div>
              <div style={{ fontSize: '12px', color: 'var(--text-secondary)', lineHeight: '1.6' }}>
                {capitalize(selectedBin.type)} bin assigned to {customerName(selectedBin.customer_id)}.
              </div>
              <button className="btn-outline" onClick={() => navigator.clipboard?.writeText(selectedBin.serial_number)}>
                Copy Serial
              </button>
            </>
          ) : (
            <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
              Select a bin from the registry to view its QR code.
            </p>
          )}
        </div>
      </div>

      <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '18px' }}>
        <h3 style={{ fontSize: '16px' }}>Registered Bin Registry</h3>
        <div className="table-container">
          <table className="custom-table">
            <thead>
              <tr>
                <th>Serial / QR</th>
                <th>Customer</th>
                <th>Type</th>
                <th>Ownership</th>
                <th>Fill</th>
                <th>Status</th>
                <th>Registered</th>
                <th>Control</th>
              </tr>
            </thead>
            <tbody>
              {bins.length === 0 ? (
                <tr>
                  <td colSpan="8" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>
                    No bins registered yet.
                  </td>
                </tr>
              ) : (
                bins.map((bin) => (
                  <tr
                    key={bin.id}
                    onClick={() => setSelectedBin(bin)}
                    style={{ cursor: 'pointer', background: selectedBin?.id === bin.id ? 'var(--border-divider)' : 'transparent' }}
                  >
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <img
                          src={bin.qr_code_url || qrCodeUrl(bin.serial_number)}
                          alt={bin.serial_number}
                          width="44"
                          height="44"
                          style={{ background: 'white', padding: '4px', borderRadius: '6px' }}
                        />
                        <strong>{bin.serial_number || 'No serial'}</strong>
                      </div>
                    </td>
                    <td>{customerName(bin.customer_id)}</td>
                    <td style={{ textTransform: 'capitalize' }}>{bin.type} ({bin.size})</td>
                    <td style={{ textTransform: 'capitalize' }}>{bin.ownership || 'company'}</td>
                    <td>{formatPercent(bin.fill_level_percentage)}</td>
                    <td>
                      <span className={`badge ${
                        bin.status === 'maintenance' ? 'badge-pending'
                        : bin.status === 'inactive' || bin.status === 'disabled' ? 'badge-defaulter'
                        : 'badge-active'
                      }`}>
                        {(bin.status || 'active').toUpperCase()}
                      </span>
                    </td>
                    <td>{formatDate(bin.registered_at)}</td>
                    <td>
                      <button
                        className="btn-outline"
                        style={{ padding: '8px 12px', fontSize: '11px' }}
                        onClick={(e) => {
                          e.stopPropagation();
                          openEditModal(bin);
                        }}
                      >
                        Manage
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {showCreateModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>Create Company Bin</h3>
            <form onSubmit={handleCreateBin} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div className="form-group">
                <label>Customer</label>
                <select value={binForm.customerId} onChange={(e) => handleCustomerSelect(e.target.value)} required>
                  <option value="">Select customer</option>
                  {customers.map((customer) => (
                    <option key={customer.id} value={customer.id}>
                      {customer.displayName || customer.fullName || customer.email || customer.id}
                    </option>
                  ))}
                </select>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div className="form-group">
                  <label>Bin Type</label>
                  <select value={binForm.type} onChange={(e) => handleFormChange('type', e.target.value)}>
                    <option value="recycling">Recycling</option>
                    <option value="organic">Organic</option>
                  </select>
                </div>
                <div className="form-group">
                  <label>Capacity</label>
                  <select value={binForm.size} onChange={(e) => handleFormChange('size', e.target.value)}>
                    <option value="120L">120L Small</option>
                    <option value="240L">240L Large</option>
                    <option value="360L">360L Extra Large</option>
                  </select>
                </div>
              </div>
              <div className="form-group">
                <label>Location</label>
                <input
                  value={binForm.gpsLocation}
                  onChange={(e) => handleFormChange('gpsLocation', e.target.value)}
                  placeholder="GPS coordinates or service location"
                />
              </div>
              <div className="form-group">
                <label>Collection Frequency</label>
                <select value={binForm.scheduleFrequency} onChange={(e) => handleFormChange('scheduleFrequency', e.target.value)}>
                  <option value="Weekly">Weekly</option>
                  <option value="Bi-weekly">Bi-weekly</option>
                  <option value="Monthly">Monthly</option>
                </select>
              </div>
              <div style={{ background: 'var(--bg-app)', borderRadius: '8px', padding: '12px', fontSize: '12px', color: 'var(--text-secondary)' }}>
                A serial number and QR code will be generated automatically when this bin is created.
              </div>
              <div className="modal-actions">
                <button type="button" className="btn-outline" onClick={() => setShowCreateModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" disabled={actionLoading}>
                  {actionLoading ? 'Creating...' : 'Create Bin'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {showEditModal && selectedBin && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>Manage Bin</h3>
            <div style={{ display: 'flex', gap: '14px', alignItems: 'center', background: 'var(--bg-app)', padding: '12px', borderRadius: '8px' }}>
              <img src={selectedBin.qr_code_url || qrCodeUrl(selectedBin.serial_number)} alt={selectedBin.serial_number} width="72" height="72" style={{ background: 'white', padding: '6px', borderRadius: '8px' }} />
              <div>
                <strong>{selectedBin.serial_number}</strong>
                <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                  {capitalize(selectedBin.type)} bin for {customerName(selectedBin.customer_id)}
                </p>
              </div>
            </div>
            <form onSubmit={handleUpdateBin} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div className="form-group">
                <label>Status</label>
                <select value={editForm.status} onChange={(e) => setEditForm((current) => ({ ...current, status: e.target.value }))}>
                  {statusOptions.map((status) => (
                    <option key={status} value={status}>{capitalize(status)}</option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label>Fill Level (%)</label>
                <input
                  type="number"
                  min="0"
                  max="100"
                  value={editForm.fillLevelPercentage}
                  onChange={(e) => setEditForm((current) => ({ ...current, fillLevelPercentage: e.target.value }))}
                />
              </div>
              <div className="form-group">
                <label>Collection Frequency</label>
                <select value={editForm.scheduleFrequency} onChange={(e) => setEditForm((current) => ({ ...current, scheduleFrequency: e.target.value }))}>
                  <option value="Weekly">Weekly</option>
                  <option value="Bi-weekly">Bi-weekly</option>
                  <option value="Monthly">Monthly</option>
                </select>
              </div>
              <div className="modal-actions">
                <button type="button" className="btn-outline" onClick={() => setShowEditModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" disabled={actionLoading}>
                  {actionLoading ? 'Saving...' : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
