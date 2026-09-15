import React, { useEffect, useMemo, useState, useRef } from 'react';
import { APIProvider, Map as GoogleMap, AdvancedMarker, useMap } from '@vis.gl/react-google-maps';
import { supabase } from '../supabase';
import { formatDate as formatGhanaDate } from '../timezone';

const MAPS_API_KEY = import.meta.env.VITE_GOOGLE_MAPS_API_KEY || '';
const MAP_ID = import.meta.env.VITE_GOOGLE_MAPS_MAP_ID || 'DEMO_MAP_ID';

// Tarkwa. Only the opening camera position before bins are fitted into view.
const FALLBACK_CENTER = { lat: 5.3018, lng: -1.9930 };

// Matches the "5.603700, -0.187000" shape bins.gps_location is stored as
// (see GeoUtils.formatCoordinates on the Flutter side). Tolerates a trailing
// "(Fallback)" suffix or similar surrounding text.
const COORD_PATTERN = /(-?\d{1,3}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)/;

function parseGpsLocation(raw) {
  if (!raw) return null;
  const match = COORD_PATTERN.exec(raw);
  if (!match) return null;
  const lat = parseFloat(match[1]);
  const lng = parseFloat(match[2]);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  if (Math.abs(lat) > 90 || Math.abs(lng) > 180) return null;
  return { lat, lng };
}

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
  const timePart = Date.now().toString(36).toUpperCase().slice(-5);
  const randomPart = Math.floor(1000 + Math.random() * 9000);
  return `CCB-${prefix}-${timePart}${randomPart}`;
}

// Everything an admin might type to find a bin, lower-cased once per bin.
function binSearchText(bin, customer) {
  return [
    bin.serial_number,
    customer?.fullName,
    customer?.email,
    bin.type,
    bin.size,
    bin.ownership || 'company',
    bin.status || 'active',
    bin.schedule_frequency,
    bin.gps_location,
  ]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();
}

// Every word has to match somewhere, so "benjamin organic" narrows to
// Benjamin's organic bins instead of every Benjamin bin plus every organic one.
function matchesSearch(text, query) {
  return query
    .toLowerCase()
    .split(/\s+/)
    .filter(Boolean)
    .every((word) => text.includes(word));
}

const MAP_RESULT_LIMIT = 8;

const filterSelectStyle = {
  padding: '8px 10px',
  borderRadius: 'var(--border-radius-sm)',
  border: '1px solid var(--border-divider)',
  background: 'var(--bg-app)',
  color: 'var(--text-primary)',
  fontSize: '12.5px',
  outline: 'none',
};

function SearchIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--text-muted)" strokeWidth="2.5" aria-hidden="true">
      <circle cx="11" cy="11" r="8" />
      <line x1="21" y1="21" x2="16.65" y2="16.65" />
    </svg>
  );
}

function ClearSearchButton({ onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label="Clear search"
      style={{ background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer', fontSize: '16px', lineHeight: 1, padding: 0 }}
    >
      ×
    </button>
  );
}

function qrCodeUrl(serialNumber) {
  return `https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${encodeURIComponent(serialNumber)}`;
}

function formatDate(value) {
  if (!value) return 'Not recorded';
  return formatGhanaDate(value);
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
  const [showMapModal, setShowMapModal] = useState(false);
  const [registrySearch, setRegistrySearch] = useState('');
  const [ownershipFilter, setOwnershipFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [mapSearch, setMapSearch] = useState('');
  const [showMapResults, setShowMapResults] = useState(false);
  const [mapFocusBinId, setMapFocusBinId] = useState(null);
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

  const mappableBins = useMemo(
    () =>
      bins
        .map((bin) => ({ bin, position: parseGpsLocation(bin.gps_location) }))
        .filter((entry) => entry.position !== null),
    [bins]
  );

  const searchTextById = useMemo(() => {
    const texts = new Map();
    bins.forEach((bin) => texts.set(bin.id, binSearchText(bin, customerMap.get(bin.customer_id))));
    return texts;
  }, [bins, customerMap]);

  const filteredBins = useMemo(
    () =>
      bins.filter(
        (bin) =>
          (ownershipFilter === 'all' || (bin.ownership || 'company') === ownershipFilter) &&
          (statusFilter === 'all' || (bin.status || 'active') === statusFilter) &&
          matchesSearch(searchTextById.get(bin.id) || '', registrySearch)
      ),
    [bins, ownershipFilter, statusFilter, registrySearch, searchTextById]
  );
  const registryFiltered = registrySearch.trim() !== '' || ownershipFilter !== 'all' || statusFilter !== 'all';

  const isMapSearching = mapSearch.trim() !== '';
  const mapMatches = useMemo(
    () =>
      isMapSearching
        ? mappableBins.filter(({ bin }) => matchesSearch(searchTextById.get(bin.id) || '', mapSearch))
        : mappableBins,
    [isMapSearching, mappableBins, mapSearch, searchTextById]
  );
  const mapMatchIds = useMemo(() => new Set(mapMatches.map(({ bin }) => bin.id)), [mapMatches]);
  const unmappedMatchCount = isMapSearching
    ? bins.filter(
        (bin) => !parseGpsLocation(bin.gps_location) && matchesSearch(searchTextById.get(bin.id) || '', mapSearch)
      ).length
    : 0;
  const focusedMapEntry = mappableBins.find(({ bin }) => bin.id === mapFocusBinId) || null;

  const focusBinOnMap = (bin) => {
    setSelectedBin(bin);
    setMapFocusBinId(bin.id);
    setShowMapResults(false);
  };

  const openMapAtBin = (bin) => {
    setMapSearch('');
    focusBinOnMap(bin);
    setShowMapModal(true);
  };

  const showBinInRegistry = (bin) => {
    setSelectedBin(bin);
    setOwnershipFilter('all');
    setStatusFilter('all');
    setRegistrySearch(bin.serial_number || '');
    setShowMapModal(false);
  };

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

  const handleDeleteBin = async (bin) => {
    if (!window.confirm(`Delete bin ${bin.serial_number || bin.id}? This cannot be undone.`)) {
      return;
    }
    setActionLoading(true);
    try {
      const { error } = await supabase.rpc('admin_delete_bin', { p_bin_id: bin.id });
      if (error) throw error;
      if (selectedBin?.id === bin.id) setSelectedBin(null);
    } catch (err) {
      alert(`Failed to delete bin: ${err.message}`);
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
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '10px' }}>
          <h3 style={{ fontSize: '16px' }}>Registered Bin Registry</h3>
          <button className="btn-outline" style={{ padding: '8px 14px', fontSize: '12px' }} onClick={() => { setMapFocusBinId(null); setShowMapModal(true); }}>
            🗺️ View on Map ({mappableBins.length})
          </button>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
          <div className="header-search" style={{ width: 'min(340px, 100%)' }}>
            <SearchIcon />
            <input
              type="text"
              placeholder="Search serial, customer, email, type, size…"
              value={registrySearch}
              onChange={(e) => setRegistrySearch(e.target.value)}
              aria-label="Search bins"
            />
            {registrySearch && <ClearSearchButton onClick={() => setRegistrySearch('')} />}
          </div>
          <select style={filterSelectStyle} value={ownershipFilter} onChange={(e) => setOwnershipFilter(e.target.value)} aria-label="Filter by ownership">
            <option value="all">All ownership</option>
            <option value="company">Company</option>
            <option value="personal">Personal</option>
          </select>
          <select style={filterSelectStyle} value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} aria-label="Filter by status">
            <option value="all">All statuses</option>
            {statusOptions.map((status) => (
              <option key={status} value={status}>{capitalize(status)}</option>
            ))}
          </select>
          <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
            {registryFiltered
              ? `Showing ${filteredBins.length} of ${bins.length} bins`
              : `${bins.length} bin${bins.length === 1 ? '' : 's'}`}
          </span>
          {registryFiltered && (
            <button
              type="button"
              className="btn-outline"
              style={{ padding: '6px 10px', fontSize: '11px' }}
              onClick={() => { setRegistrySearch(''); setOwnershipFilter('all'); setStatusFilter('all'); }}
            >
              Clear filters
            </button>
          )}
        </div>
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
              ) : filteredBins.length === 0 ? (
                <tr>
                  <td colSpan="8" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>
                    No bins match your search.
                  </td>
                </tr>
              ) : (
                filteredBins.map((bin) => (
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
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <button
                          className="btn-outline"
                          style={{ padding: '8px 12px', fontSize: '11px' }}
                          disabled={!parseGpsLocation(bin.gps_location)}
                          title={parseGpsLocation(bin.gps_location) ? 'Show this bin on the map' : 'No saved location'}
                          onClick={(e) => {
                            e.stopPropagation();
                            openMapAtBin(bin);
                          }}
                        >
                          Map
                        </button>
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
                        <button
                          className="btn-outline"
                          style={{ padding: '8px 12px', fontSize: '11px', color: 'var(--color-danger, #d33)' }}
                          disabled={actionLoading}
                          onClick={(e) => {
                            e.stopPropagation();
                            handleDeleteBin(bin);
                          }}
                        >
                          Delete
                        </button>
                      </div>
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

      {showMapModal && (
        <div className="modal-overlay">
          <div
            className="modal-content"
            style={{ maxWidth: '96vw', width: '100%', height: '92vh', maxHeight: '92vh' }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div>
                <h3 style={{ fontSize: '18px' }}>Bin Locations</h3>
                <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                  Where registered bins are scattered — green for company-owned (CCB), blue for personal (PB).
                </p>
              </div>
              <button className="btn-outline" style={{ padding: '6px 12px', fontSize: '11px' }} onClick={() => setShowMapModal(false)}>
                Close
              </button>
            </div>

            <div style={{ position: 'relative', flex: 1, minHeight: 0, borderRadius: '10px', overflow: 'hidden', border: '1px solid var(--border-divider)', marginTop: '16px' }}>
              {!MAPS_API_KEY ? (
                <MissingMapKeyNotice />
              ) : (
                <APIProvider apiKey={MAPS_API_KEY}>
                  <GoogleMap
                    mapId={MAP_ID}
                    defaultCenter={mappableBins.length > 0 ? mappableBins[0].position : FALLBACK_CENTER}
                    defaultZoom={12}
                    gestureHandling="greedy"
                    disableDefaultUI={false}
                    mapTypeControl={false}
                    streetViewControl={false}
                    fullscreenControl={false}
                    style={{ width: '100%', height: '100%' }}
                  >
                    <FitBinBounds entries={mappableBins} />
                    <MapSearchFocus
                      focused={focusedMapEntry}
                      matches={mapMatches}
                      isSearching={isMapSearching}
                    />
                    {mappableBins.map(({ bin, position }) => (
                      <AdvancedMarker
                        key={bin.id}
                        position={position}
                        zIndex={bin.id === mapFocusBinId ? 1000 : mapMatchIds.has(bin.id) ? 10 : 1}
                        title={`${bin.serial_number || 'No serial'} — ${customerName(bin.customer_id)}`}
                      >
                        <BinMapPin
                          bin={bin}
                          dimmed={isMapSearching && !mapMatchIds.has(bin.id)}
                          focused={bin.id === mapFocusBinId}
                          onClick={() => focusBinOnMap(bin)}
                        />
                      </AdvancedMarker>
                    ))}
                  </GoogleMap>
                </APIProvider>
              )}

              {MAPS_API_KEY && (
                <div
                  style={{
                    position: 'absolute',
                    top: '12px',
                    left: '12px',
                    zIndex: 2,
                    width: 'min(380px, calc(100% - 24px))',
                    display: 'flex',
                    flexDirection: 'column',
                    gap: '6px',
                  }}
                >
                  <div className="header-search" style={{ width: '100%', background: 'var(--bg-card)', boxShadow: '0 4px 14px rgba(0,0,0,0.18)' }}>
                    <SearchIcon />
                    <input
                      type="text"
                      autoFocus
                      placeholder="Find a bin: serial, customer, type…"
                      value={mapSearch}
                      aria-label="Search bins on the map"
                      onChange={(e) => {
                        setMapSearch(e.target.value);
                        setMapFocusBinId(null);
                        setShowMapResults(true);
                      }}
                      onFocus={() => setShowMapResults(true)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' && mapMatches.length > 0) focusBinOnMap(mapMatches[0].bin);
                        if (e.key === 'Escape') setShowMapResults(false);
                      }}
                    />
                    {mapSearch && (
                      <ClearSearchButton
                        onClick={() => {
                          setMapSearch('');
                          setMapFocusBinId(null);
                        }}
                      />
                    )}
                  </div>

                  {isMapSearching && showMapResults && (
                    <div
                      style={{
                        maxHeight: '320px',
                        overflowY: 'auto',
                        borderRadius: 'var(--border-radius-sm)',
                        border: '1px solid var(--border-divider)',
                        background: 'var(--bg-card)',
                        boxShadow: '0 6px 18px rgba(0,0,0,0.2)',
                        fontSize: '12.5px',
                      }}
                    >
                      {mapMatches.length === 0 ? (
                        <div style={{ padding: '10px 12px', color: 'var(--text-muted)' }}>
                          No bins on the map match “{mapSearch.trim()}”.
                        </div>
                      ) : (
                        mapMatches.slice(0, MAP_RESULT_LIMIT).map(({ bin }) => (
                          <button
                            key={bin.id}
                            type="button"
                            onClick={() => focusBinOnMap(bin)}
                            style={{
                              display: 'block',
                              width: '100%',
                              textAlign: 'left',
                              padding: '9px 12px',
                              background: bin.id === mapFocusBinId ? 'var(--border-divider)' : 'transparent',
                              border: 'none',
                              borderBottom: '1px solid var(--border-divider)',
                              color: 'var(--text-primary)',
                              cursor: 'pointer',
                            }}
                          >
                            <strong style={{ display: 'block' }}>{bin.serial_number || 'No serial'}</strong>
                            <span style={{ color: 'var(--text-secondary)', textTransform: 'capitalize' }}>
                              {customerName(bin.customer_id)} · {bin.type} ({bin.size}) · {bin.ownership || 'company'}
                            </span>
                          </button>
                        ))
                      )}
                      {mapMatches.length > MAP_RESULT_LIMIT && (
                        <div style={{ padding: '8px 12px', color: 'var(--text-muted)' }}>
                          {mapMatches.length - MAP_RESULT_LIMIT} more on the map — keep typing to narrow down.
                        </div>
                      )}
                      {unmappedMatchCount > 0 && (
                        <div style={{ padding: '8px 12px', color: 'var(--text-muted)' }}>
                          {unmappedMatchCount} matching bin{unmappedMatchCount === 1 ? ' has' : 's have'} no saved location.
                        </div>
                      )}
                    </div>
                  )}
                </div>
              )}

              {MAPS_API_KEY && focusedMapEntry && (
                <FocusedBinCard
                  bin={focusedMapEntry.bin}
                  customer={customerName(focusedMapEntry.bin.customer_id)}
                  onShowInRegistry={() => showBinInRegistry(focusedMapEntry.bin)}
                  onClose={() => setMapFocusBinId(null)}
                />
              )}

              {MAPS_API_KEY && (
                <div
                  style={{
                    position: 'absolute',
                    bottom: '12px',
                    left: '12px',
                    display: 'flex',
                    gap: '14px',
                    padding: '8px 14px',
                    borderRadius: '10px',
                    background: 'var(--bg-card-hover)',
                    backdropFilter: 'var(--glass-blur)',
                    border: '1px solid var(--border-divider)',
                    fontSize: '12px',
                    fontWeight: 600,
                    color: 'var(--text-primary)',
                  }}
                >
                  <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <span style={{ width: '10px', height: '10px', borderRadius: '50%', background: 'var(--color-success)' }} />
                    Company (CCB)
                  </span>
                  <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <span style={{ width: '10px', height: '10px', borderRadius: '50%', background: 'var(--color-info)' }} />
                    Personal (PB)
                  </span>
                </div>
              )}
            </div>

            {bins.length - mappableBins.length > 0 && (
              <p style={{ fontSize: '11.5px', color: 'var(--text-muted)', marginTop: '10px' }}>
                {bins.length - mappableBins.length} bin{bins.length - mappableBins.length === 1 ? '' : 's'} without a saved location not shown.
              </p>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

/**
 * Frames every plotted bin once the map is ready, then leaves the camera
 * alone so an admin panning around isn't yanked back on every data refresh.
 */
function FitBinBounds({ entries }) {
  const map = useMap();
  const hasFitted = useRef(false);

  useEffect(() => {
    if (!map || entries.length === 0 || hasFitted.current) return;
    hasFitted.current = true;

    if (entries.length === 1) {
      map.setCenter(entries[0].position);
      map.setZoom(14);
      return;
    }

    const bounds = new window.google.maps.LatLngBounds();
    entries.forEach((entry) => bounds.extend(entry.position));
    map.fitBounds(bounds, 64);
  }, [map, entries]);

  return null;
}

/**
 * Moves the camera for the map search: frames every match as the query
 * narrows, and zooms in on a bin once one is picked. Neither runs while the
 * admin is simply browsing, so panning by hand is left alone.
 */
function MapSearchFocus({ focused, matches, isSearching }) {
  const map = useMap();
  const focusedId = focused?.bin.id;
  const matchKey = isSearching ? matches.map(({ bin }) => bin.id).join(',') : '';

  useEffect(() => {
    if (!map || !focused) return;
    map.panTo(focused.position);
    map.setZoom(Math.max(map.getZoom() ?? 0, 17));
    // Only when a different bin is picked, not on every data refresh.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [map, focusedId]);

  useEffect(() => {
    if (!map || !matchKey || focusedId) return;
    if (matches.length === 1) {
      map.panTo(matches[0].position);
      map.setZoom(16);
      return;
    }
    const bounds = new window.google.maps.LatLngBounds();
    matches.forEach((entry) => bounds.extend(entry.position));
    map.fitBounds(bounds, 80);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [map, matchKey]);

  return null;
}

function FocusedBinCard({ bin, customer, onShowInRegistry, onClose }) {
  const status = bin.status || 'active';
  return (
    <div
      style={{
        position: 'absolute',
        top: '12px',
        right: '12px',
        zIndex: 2,
        width: 'min(280px, calc(100% - 24px))',
        padding: '12px 14px',
        borderRadius: 'var(--border-radius-sm)',
        border: '1px solid var(--border-divider)',
        background: 'var(--bg-card)',
        boxShadow: '0 6px 18px rgba(0,0,0,0.2)',
        fontSize: '12.5px',
        color: 'var(--text-primary)',
        display: 'flex',
        flexDirection: 'column',
        gap: '6px',
      }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: '8px' }}>
        <strong style={{ fontSize: '13.5px' }}>{bin.serial_number || 'No serial'}</strong>
        <ClearSearchButton onClick={onClose} />
      </div>
      <span>{customer}</span>
      <span style={{ color: 'var(--text-secondary)', textTransform: 'capitalize' }}>
        {bin.type} ({bin.size}) · {bin.ownership || 'company'} · {status}
      </span>
      <span style={{ color: 'var(--text-muted)', fontSize: '11.5px' }}>{bin.gps_location}</span>
      <button className="btn-outline" type="button" style={{ padding: '6px 10px', fontSize: '11px', alignSelf: 'flex-start', marginTop: '4px' }} onClick={onShowInRegistry}>
        Show in registry
      </button>
    </div>
  );
}

function BinMapPin({ bin, onClick, dimmed = false, focused = false }) {
  const isPersonal = (bin.ownership || 'company') === 'personal';
  const color = isPersonal ? 'var(--color-info)' : 'var(--color-success)';
  const size = focused ? 40 : 30;

  return (
    <div onClick={onClick} style={{ cursor: 'pointer', opacity: dimmed ? 0.3 : 1, transition: 'opacity 120ms' }}>
      <div
        style={{
          width: `${size}px`,
          height: `${size}px`,
          borderRadius: '50%',
          background: color,
          border: '3px solid #fff',
          boxShadow: focused
            ? '0 0 0 4px var(--color-primary), 0 3px 12px rgba(0,0,0,0.35)'
            : '0 3px 10px rgba(0,0,0,0.28)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: '#fff',
          fontSize: '12px',
          fontWeight: 800,
        }}
      >
        {isPersonal ? 'P' : 'C'}
      </div>
    </div>
  );
}

function MissingMapKeyNotice() {
  return (
    <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '32px', background: 'var(--bg-app)' }}>
      <div style={{ maxWidth: '420px', textAlign: 'center' }}>
        <h4 style={{ fontSize: '15px', marginBottom: '8px' }}>Google Maps key not configured</h4>
        <p style={{ color: 'var(--text-secondary)', fontSize: '12.5px', lineHeight: 1.6 }}>
          Create <code>admin_panel/.env.local</code> with a browser key that has the{' '}
          <strong>Maps JavaScript API</strong> enabled, then restart the dev server:
        </p>
        <pre style={{ background: 'var(--bg-app)', border: '1px solid var(--border-divider)', borderRadius: '8px', padding: '10px 14px', fontSize: '11.5px', margin: '10px 0', textAlign: 'left', overflowX: 'auto' }}>
          VITE_GOOGLE_MAPS_API_KEY=AIza...
        </pre>
      </div>
    </div>
  );
}
