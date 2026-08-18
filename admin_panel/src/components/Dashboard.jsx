import React, { useState, useEffect } from 'react';
import { supabase } from '../supabase';

export default function Dashboard() {
  const [topRiders, setTopRiders] = useState([]);
  const [recentCollections, setRecentCollections] = useState([]);
  const [pickupRequests, setPickupRequests] = useState([]);
  const [todaysPickups, setTodaysPickups] = useState([]);
  const [openIncidents, setOpenIncidents] = useState([]);
  const [activitiesLoading, setActivitiesLoading] = useState(true);
  const [metrics, setMetrics] = useState({
    totalRevenue: 0,
    activeRiders: 0,
    wasteCollectedKg: 0,
    co2SavedKg: 0,
  });
  const [loading, setLoading] = useState(true);

  // ── Today's Activities: pickups scheduled for today ─────────────────────
  useEffect(() => {
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);
    const startOfTomorrow = new Date(startOfToday);
    startOfTomorrow.setDate(startOfTomorrow.getDate() + 1);

    const mapPickupRow = (r) => ({ ...r, date: r.date ? new Date(r.date) : null });

    let mounted = true;
    const fetchTodaysPickups = async () => {
      const { data, error } = await supabase
        .from('pickup_requests')
        .select('*')
        .gte('date', startOfToday.toISOString())
        .lt('date', startOfTomorrow.toISOString());
      if (mounted && !error) setTodaysPickups(data.map(mapPickupRow));
      if (mounted) setActivitiesLoading(false);
    };
    fetchTodaysPickups();

    const pickupsChannel = supabase
      .channel('dashboard_todays_pickups')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'pickup_requests' }, fetchTodaysPickups)
      .subscribe();

    const mapIncidentRow = (r) => ({ ...r, createdAt: r.created_at ? new Date(r.created_at) : new Date() });

    const fetchOpenIncidents = async () => {
      const { data, error } = await supabase.from('incident_reports').select('*');
      if (mounted && !error) {
        setOpenIncidents(data.map(mapIncidentRow).filter((r) => r.status !== 'resolved'));
      }
    };
    fetchOpenIncidents();

    const incidentsChannel = supabase
      .channel('dashboard_open_incidents')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'incident_reports' }, fetchOpenIncidents)
      .subscribe();

    return () => {
      mounted = false;
      supabase.removeChannel(pickupsChannel);
      supabase.removeChannel(incidentsChannel);
    };
  }, []);

  // ── Live metrics + activity feeds ────────────────────────────────────────
  useEffect(() => {
    let mounted = true;

    const mapPickupRequestRow = (r) => ({ ...r, createdAt: r.created_at ? new Date(r.created_at) : new Date() });
    const fetchRecentPickupRequests = async () => {
      const { data, error } = await supabase
        .from('pickup_requests')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(5);
      if (mounted && !error) setPickupRequests(data.map(mapPickupRequestRow));
      if (mounted) setLoading(false);
    };
    fetchRecentPickupRequests();
    const pickupRequestsChannel = supabase
      .channel('dashboard_pickup_requests')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'pickup_requests' }, fetchRecentPickupRequests)
      .subscribe();

    const mapCollectionRow = (r) => ({ ...r, collectedAt: r.collected_at ? new Date(r.collected_at) : new Date() });
    const fetchCollectionTotals = async () => {
      const { data, error } = await supabase.from('collection_events').select('weight_kg, carbon_offset');
      if (mounted && !error) {
        const totalWeight = data.reduce((s, r) => s + (r.weight_kg ?? 0), 0);
        const totalCO2 = data.reduce((s, r) => s + (r.carbon_offset ?? 0), 0);
        setMetrics((prev) => ({
          ...prev,
          wasteCollectedKg: parseFloat(totalWeight.toFixed(1)),
          co2SavedKg: parseFloat(totalCO2.toFixed(1)),
        }));
      }
    };
    const fetchRecentCollections = async () => {
      const { data, error } = await supabase
        .from('collection_events')
        .select('*')
        .order('collected_at', { ascending: false })
        .limit(10);
      if (mounted && !error) setRecentCollections(data.map(mapCollectionRow));
      if (mounted) setLoading(false);
      fetchCollectionTotals();
    };
    fetchRecentCollections();
    const collectionsChannel = supabase
      .channel('dashboard_collections')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'collection_events' }, fetchRecentCollections)
      .subscribe();

    const fetchActiveRiderCount = async () => {
      const { count, error } = await supabase
        .from('riders')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'active');
      if (mounted && !error) setMetrics((prev) => ({ ...prev, activeRiders: count ?? 0 }));
    };
    fetchActiveRiderCount();

    const mapTopRiderRow = (r) => ({
      id: r.id,
      name: r.profiles?.full_name ?? 'Unknown',
      collections: r.total_collections ?? 0,
      rating: r.rating ?? 0,
      avatar: r.profiles?.profile_picture_url || `https://api.dicebear.com/7.x/initials/svg?seed=${r.profiles?.full_name}`,
    });
    const fetchTopRiders = async () => {
      const { data, error } = await supabase
        .from('riders')
        .select('id, total_collections, rating, profiles(full_name, profile_picture_url)')
        .order('total_collections', { ascending: false })
        .limit(4);
      if (mounted && !error) setTopRiders(data.map(mapTopRiderRow));
    };
    fetchTopRiders();

    const ridersChannel = supabase
      .channel('dashboard_riders')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'riders' }, () => {
        fetchActiveRiderCount();
        fetchTopRiders();
      })
      .subscribe();

    const fetchRevenue = async () => {
      const { data, error } = await supabase.from('payments').select('amount').eq('status', 'paid');
      if (mounted && !error) {
        const total = data.reduce((s, d) => s + (d.amount ?? 0), 0);
        setMetrics((prev) => ({ ...prev, totalRevenue: parseFloat(total.toFixed(2)) }));
      }
    };
    fetchRevenue();
    const paymentsChannel = supabase
      .channel('dashboard_payments')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'payments' }, fetchRevenue)
      .subscribe();

    return () => {
      mounted = false;
      supabase.removeChannel(pickupRequestsChannel);
      supabase.removeChannel(collectionsChannel);
      supabase.removeChannel(ridersChannel);
      supabase.removeChannel(paymentsChannel);
    };
  }, []);

  // ── Format helpers ──────────────────────────────────────────────────────
  const formatTime = (date) => {
    if (!date) return '—';
    const diff = Math.floor((Date.now() - date.getTime()) / 1000);
    if (diff < 60) return `${diff}s ago`;
    if (diff < 3600) return `${Math.floor(diff / 60)} min ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)} hr ago`;
    return `${Math.floor(diff / 86400)} days ago`;
  };

  const formatWeight = (kg) =>
    kg >= 1000 ? `${(kg / 1000).toFixed(1)} T` : `${kg} kg`;

  const formatCurrency = (val) =>
    val >= 1000 ? `GHS ${(val / 1000).toFixed(1)}k` : `GHS ${val.toFixed(2)}`;

  // ── Today's Activities: merge scheduled pickups + open incident reports ──
  const pickupBadgeClass = (status) => {
    if (status === 'completed') return 'badge-active';
    if (status === 'rejected') return 'badge-defaulter';
    return 'badge-pending';
  };
  const incidentBadgeClass = (status) => {
    if (status === 'assigned' || status === 'in_progress') return 'badge-active';
    return 'badge-pending';
  };

  const todaysActivities = [
    ...todaysPickups.map((p) => ({
      key: `pickup-${p.id}`,
      type: 'Pickup',
      title: p.customer_name ?? 'Customer',
      subtitle: `${Array.isArray(p.bin_types) ? p.bin_types.join(', ') : 'General'} — ${p.time_slot ?? 'Flexible'}`,
      status: p.status ?? 'pending',
      badgeClass: pickupBadgeClass(p.status),
      sortTime: p.date,
    })),
    ...openIncidents.map((r) => ({
      key: `incident-${r.id}`,
      type: 'Waste/Gutter Report',
      title: r.reporter_name ?? 'Customer',
      subtitle: r.description ?? 'No description provided',
      status: r.status ?? 'pending',
      badgeClass: incidentBadgeClass(r.status),
      sortTime: r.createdAt,
    })),
  ].sort((a, b) => (a.sortTime?.getTime?.() ?? 0) - (b.sortTime?.getTime?.() ?? 0));

  return (
    <div className="page-content">
      {/* ── Page Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>Overview Dashboard</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Real-time operations summary for CleanConnect logistics.
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--color-success)', display: 'inline-block' }} />
          <span style={{ fontSize: '11px', color: 'var(--text-secondary)', fontWeight: 'bold' }}>
            Live
          </span>
        </div>
      </div>

      {/* ── Key Performance Metrics ── */}
      <div className="metrics-grid">
        <div className="card-glass metric-card">
          <div className="metric-header">
            <span className="metric-title">Total Revenue</span>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--color-primary)" strokeWidth="2">
              <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
            </svg>
          </div>
          <span className="metric-value">{loading ? '—' : formatCurrency(metrics.totalRevenue)}</span>
          <div className="metric-footer trend-up">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <path d="M18 15l-6-6-6 6" />
            </svg>
            <span>From paid invoices</span>
          </div>
        </div>

        <div className="card-glass metric-card">
          <div className="metric-header">
            <span className="metric-title">Active Riders</span>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--color-info)" strokeWidth="2">
              <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 7a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" />
            </svg>
          </div>
          <span className="metric-value">{loading ? '—' : metrics.activeRiders}</span>
          <div className="metric-footer trend-up">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <path d="M18 15l-6-6-6 6" />
            </svg>
            <span>Currently on duty</span>
          </div>
        </div>

        <div className="card-glass metric-card">
          <div className="metric-header">
            <span className="metric-title">Waste Collected</span>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--color-success)" strokeWidth="2">
              <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16zM3.27 6.96L12 12.01l8.73-5.05M12 22.08V12" />
            </svg>
          </div>
          <span className="metric-value">
            {loading ? '—' : formatWeight(metrics.wasteCollectedKg)}
          </span>
          <div className="metric-footer trend-up">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <path d="M18 15l-6-6-6 6" />
            </svg>
            <span>All-time total</span>
          </div>
        </div>

        <div className="card-glass metric-card">
          <div className="metric-header">
            <span className="metric-title">CO2 Saved</span>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--color-accent)" strokeWidth="2">
              <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
            </svg>
          </div>
          <span className="metric-value">
            {loading ? '—' : `${metrics.co2SavedKg} `}
            <span style={{ fontSize: '16px' }}>kg</span>
          </span>
          <div className="metric-footer trend-up">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <path d="M18 15l-6-6-6 6" />
            </svg>
            <span>Carbon offset total</span>
          </div>
        </div>
      </div>

      {/* ── Today's Activities - Live ── */}
      <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '18px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <h3 style={{ fontSize: '16px' }}>Today's Activities</h3>
          <span className="badge badge-pending">{todaysActivities.length} TO TRACK</span>
        </div>
        <div className="table-container">
          <table className="custom-table">
            <thead>
              <tr>
                <th>Type</th>
                <th>Customer</th>
                <th>Details</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {activitiesLoading ? (
                <tr><td colSpan="4" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>Loading today's activities...</td></tr>
              ) : todaysActivities.length === 0 ? (
                <tr><td colSpan="4" style={{ textAlign: 'center', color: 'var(--text-muted)', padding: '24px' }}>Nothing scheduled for today.</td></tr>
              ) : (
                todaysActivities.map((activity) => (
                  <tr key={activity.key}>
                    <td style={{ fontWeight: '700', color: 'var(--color-primary)' }}>{activity.type}</td>
                    <td style={{ fontWeight: '600' }}>{activity.title}</td>
                    <td style={{ color: 'var(--text-secondary)', fontSize: '12px', maxWidth: '260px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{activity.subtitle}</td>
                    <td><span className={`badge ${activity.badgeClass}`}>{activity.status.toUpperCase()}</span></td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── Splitted Visual Graphs & Leaderboard ── */}
      <div className="split-layout">
        {/* Trend Graph (visual only - SVG) */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3 style={{ fontSize: '16px' }}>Growth & Volume Trends</h3>
            <div style={{ display: 'flex', gap: '8px' }}>
              <button className="btn-outline" style={{ padding: '6px 12px', fontSize: '11px' }}>Daily</button>
              <button className="btn-primary" style={{ padding: '6px 12px', fontSize: '11px' }}>Weekly</button>
              <button className="btn-outline" style={{ padding: '6px 12px', fontSize: '11px' }}>Monthly</button>
            </div>
          </div>
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
              <circle cx="150" cy="140" r="5" fill="var(--color-primary)" stroke="white" strokeWidth="2" />
              <circle cx="300" cy="70" r="5" fill="var(--color-primary)" stroke="white" strokeWidth="2" />
              <circle cx="450" cy="40" r="5" fill="var(--color-primary)" stroke="white" strokeWidth="2" />
            </svg>
            <div style={{ position: 'absolute', bottom: '10px', left: '20px', display: 'flex', justifyContent: 'space-between', right: '20px', fontSize: '11px', color: 'var(--text-secondary)' }}>
              <span>Mon</span><span>Tue</span><span>Wed</span><span>Thu</span><span>Fri</span><span>Sat</span><span>Sun</span>
            </div>
          </div>
        </div>

        {/* Top Performers - Live from Postgres */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <h3 style={{ fontSize: '16px' }}>Top Performing Riders</h3>
          {loading ? (
            <p style={{ color: 'var(--text-secondary)', fontSize: '13px' }}>Loading riders...</p>
          ) : topRiders.length === 0 ? (
            <p style={{ color: 'var(--text-secondary)', fontSize: '13px' }}>No riders registered yet.</p>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              {topRiders.map((rider, idx) => (
                <div key={idx} style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <img src={rider.avatar} alt={rider.name}
                    style={{ width: '40px', height: '40px', borderRadius: '50%', objectFit: 'cover' }}
                    onError={(e) => { e.target.src = `https://api.dicebear.com/7.x/initials/svg?seed=${rider.name}`; }}
                  />
                  <div style={{ flex: 1 }}>
                    <h4 style={{ fontSize: '13px', fontWeight: '700' }}>{rider.name}</h4>
                    <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                      {rider.collections} completed collections
                    </p>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '4px', background: 'rgba(245, 158, 11, 0.1)', padding: '2px 8px', borderRadius: '12px', color: 'var(--color-accent)', fontSize: '11px', fontWeight: '700' }}>
                    <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor">
                      <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
                    </svg>
                    {rider.rating.toFixed(1)}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* ── Customer Pickup Requests Log - Live ── */}
      <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
        <h3 style={{ fontSize: '16px' }}>Live Customer Pickup Requests</h3>
        <div className="table-container">
          <table className="custom-table">
            <thead>
              <tr>
                <th>Request ID</th>
                <th>Customer</th>
                <th>Bin Types</th>
                <th>Time Slot & Location</th>
                <th>Status</th>
                <th>Requested At</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan="6" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>Loading...</td></tr>
              ) : pickupRequests.length === 0 ? (
                <tr><td colSpan="6" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>No pickup requests submitted yet.</td></tr>
              ) : (
                pickupRequests.map((req) => (
                  <tr key={req.id}>
                    <td style={{ fontWeight: '700', color: 'var(--color-primary)' }}>#{req.id.slice(0, 8).toUpperCase()}</td>
                    <td style={{ fontWeight: '700' }}>{req.customer_name ?? 'Customer'}</td>
                    <td>{Array.isArray(req.bin_types) ? req.bin_types.join(', ') : 'General'}</td>
                    <td>{req.location ?? '—'} ({req.time_slot ?? 'Flexible'})</td>
                    <td>
                      <span className={`badge ${req.status === 'pending' ? 'badge-pending' : 'badge-active'}`}>
                        {req.status?.toUpperCase() ?? 'PENDING'}
                      </span>
                    </td>
                    <td style={{ color: 'var(--text-secondary)' }}>{formatTime(req.createdAt)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── Recent Collections Log - Live ── */}
      <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
        <h3 style={{ fontSize: '16px' }}>Recent Collections Logs</h3>
        <div className="table-container">
          <table className="custom-table">
            <thead>
              <tr>
                <th>Collection ID</th>
                <th>Collection Site</th>
                <th>Rider</th>
                <th>Weight Captured</th>
                <th>Status</th>
                <th>Time Stamp</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan="6" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>Loading...</td></tr>
              ) : recentCollections.length === 0 ? (
                <tr><td colSpan="6" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>No collections recorded yet.</td></tr>
              ) : (
                recentCollections.map((log) => (
                  <tr key={log.id}>
                    <td style={{ fontWeight: '700', color: 'var(--color-primary)' }}>#{log.id.slice(0, 8).toUpperCase()}</td>
                    <td>{log.customer_name ?? log.address ?? '—'}</td>
                    <td>{log.rider_name ?? '—'}</td>
                    <td>{log.weight_kg ? `${log.weight_kg} kg` : '—'}</td>
                    <td>
                      <span className={`badge ${log.status === 'completed' ? 'badge-active' : 'badge-pending'}`}>
                        {log.status ?? 'pending'}
                      </span>
                    </td>
                    <td style={{ color: 'var(--text-secondary)' }}>{formatTime(log.collectedAt)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
