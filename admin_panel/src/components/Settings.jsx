import React, { useState, useRef, useEffect } from 'react';
import { supabase } from '../supabase';
import { useAuth } from '../AuthContext';

const BIN_SIZES = ['120L', '240L', '360L'];

const defaultPlanForm = {
  name: '',
  frequency: 'Weekly',
  description: '',
  isPayg: false,
  prices: { '120L': '', '240L': '', '360L': '' },
};

export default function Settings() {
  const { session, profile, refreshProfile } = useAuth();

  const [superAdminAccess, setSuperAdminAccess] = useState(true);
  const [zones, setZones] = useState([
    { id: 'ZN-01', name: 'Airport Residential Hub', status: 'Active' },
    { id: 'ZN-02', name: 'East Legon Sector B', status: 'Active' },
    { id: 'ZN-03', name: 'Labadi Beach Sector C', status: 'Active' },
    { id: 'ZN-04', name: 'Cantonments Embassy Area', status: 'Suspended' },
  ]);

  const [showZoneModal, setShowZoneModal] = useState(false);

  // ── Support Tickets (from customer "Report a Problem") ───────────────────
  const [supportTickets, setSupportTickets] = useState([]);
  const [ticketsLoading, setTicketsLoading] = useState(true);
  const [ticketFilter, setTicketFilter] = useState('All');

  useEffect(() => {
    let mounted = true;
    const mapTicket = (r) => ({ ...r, createdAt: r.created_at ? new Date(r.created_at) : new Date() });

    const fetchTickets = async () => {
      setTicketsLoading(true);
      const { data, error } = await supabase
        .from('service_history')
        .select('id, customer_id, title, description, status, created_at')
        .eq('type', 'support')
        .order('created_at', { ascending: false });
      if (mounted && !error) setSupportTickets((data || []).map(mapTicket));
      if (error) console.warn('support tickets fetch:', error);
      if (mounted) setTicketsLoading(false);
    };
    fetchTickets();

    const channel = supabase
      .channel('settings_support_tickets_changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'service_history' }, fetchTickets)
      .subscribe();

    return () => {
      mounted = false;
      supabase.removeChannel(channel);
    };
  }, []);

  const handleUpdateTicketStatus = async (ticketId, newStatus) => {
    const { error } = await supabase
      .from('service_history')
      .update({ status: newStatus })
      .eq('id', ticketId);
    if (error) alert('Failed to update ticket: ' + error.message);
  };

  // ── Help & Support contact settings ──────────────────────────────
  const [contactForm, setContactForm] = useState({
    phone: '+233 24 881 4260',
    email: 'support@cleanconnect.com',
  });
  const [contactLoading, setContactLoading] = useState(false);
  const [contactSaving, setContactSaving] = useState(false);
  const [contactSaved, setContactSaved] = useState(false);

  useEffect(() => {
    let mounted = true;
    const fetchContact = async () => {
      setContactLoading(true);
      const { data, error } = await supabase
        .from('app_settings')
        .select('support_phone, support_email')
        .eq('id', true)
        .maybeSingle();
      if (mounted && !error && data) {
        setContactForm({
          phone: data.support_phone || '+233 24 881 4260',
          email: data.support_email || 'support@cleanconnect.com',
        });
      }
      if (error) console.warn('app_settings (contact) fetch:', error);
      if (mounted) setContactLoading(false);
    };
    fetchContact();
    return () => { mounted = false; };
  }, []);

  const handleSaveContact = async (e) => {
    e.preventDefault();
    if (!contactForm.phone.trim() || !contactForm.email.trim()) {
      alert('Both phone and email are required.');
      return;
    }
    setContactSaving(true);
    const { error } = await supabase.from('app_settings').upsert({
      id: true,
      support_phone: contactForm.phone.trim(),
      support_email: contactForm.email.trim(),
    }, { onConflict: 'id' });
    if (error) {
      alert('Failed to save contact settings: ' + error.message);
    } else {
      setContactSaved(true);
      setTimeout(() => setContactSaved(false), 3000);
    }
    setContactSaving(false);
  };

  // Admin profile — backed by the real profiles row now
  const adminName = profile?.full_name || 'Admin';
  const adminEmail = session?.user?.email || profile?.email || '—';
  const adminPhoto = profile?.profile_picture_url || null;
  const [isEditingProfile, setIsEditingProfile] = useState(false);
  const [nameInput, setNameInput] = useState(adminName);
  const [savingProfile, setSavingProfile] = useState(false);
  const photoInputRef = useRef(null);

  // ── Pricing Plans State ──────────────────────────────────────────────────
  const [pricingPlans, setPricingPlans] = useState([]);
  const [showPlanModal, setShowPlanModal] = useState(false);
  const [editingPlan, setEditingPlan] = useState(null); // null = create mode
  const [planForm, setPlanForm] = useState(defaultPlanForm);
  const [planLoading, setPlanLoading] = useState(false);

  useEffect(() => {
    let mounted = true;

    const fetchPlans = async () => {
      const { data, error } = await supabase
        .from('pricing_plans')
        .select('*')
        .order('created_at', { ascending: true });
      if (mounted && !error) setPricingPlans(data);
      if (error) console.warn('pricing_plans fetch:', error);
    };
    fetchPlans();

    const channel = supabase
      .channel('settings_pricing_plans_changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'pricing_plans' }, fetchPlans)
      .subscribe();

    return () => {
      mounted = false;
      supabase.removeChannel(channel);
    };
  }, []);

  const openCreatePlan = () => {
    setEditingPlan(null);
    setPlanForm(defaultPlanForm);
    setShowPlanModal(true);
  };

  const openEditPlan = (plan) => {
    setEditingPlan(plan);
    setPlanForm({
      name: plan.name || '',
      frequency: plan.frequency || 'Weekly',
      description: plan.description || '',
      isPayg: plan.is_payg || false,
      prices: {
        '120L': plan.prices?.['120L'] ?? '',
        '240L': plan.prices?.['240L'] ?? '',
        '360L': plan.prices?.['360L'] ?? '',
      },
    });
    setShowPlanModal(true);
  };

  const handlePlanFormChange = (field, value) => {
    setPlanForm((prev) => ({ ...prev, [field]: value }));
  };

  const handlePriceChange = (size, value) => {
    setPlanForm((prev) => ({
      ...prev,
      prices: { ...prev.prices, [size]: value },
    }));
  };

  const handleSavePlan = async (e) => {
    e.preventDefault();
    if (!planForm.name.trim()) { alert('Plan name is required.'); return; }

    const prices = {};
    BIN_SIZES.forEach((size) => {
      const val = parseFloat(planForm.prices[size]);
      prices[size] = isNaN(val) ? 0 : val;
    });

    const payload = {
      name: planForm.name.trim(),
      frequency: planForm.isPayg ? 'Pay-As-You-Go' : planForm.frequency,
      description: planForm.description.trim(),
      is_payg: planForm.isPayg,
      prices,
    };

    setPlanLoading(true);
    const { error } = editingPlan
      ? await supabase.from('pricing_plans').update(payload).eq('id', editingPlan.id)
      : await supabase.from('pricing_plans').insert(payload);

    if (error) {
      alert('Failed to save plan: ' + error.message);
    } else {
      setShowPlanModal(false);
    }
    setPlanLoading(false);
  };

  const handleDeletePlan = async (planId) => {
    if (!window.confirm('Delete this pricing plan? This cannot be undone.')) return;
    const { error } = await supabase.from('pricing_plans').delete().eq('id', planId);
    if (error) alert('Failed to delete plan: ' + error.message);
  };

  // ── SMS Provider (mNotify) Settings ──────────────────────────────────────
  const [smsForm, setSmsForm] = useState({ apiKey: '', senderId: '' });
  const [smsKeyVisible, setSmsKeyVisible] = useState(false);
  const [smsLoading, setSmsLoading] = useState(false);
  const [smsSaving, setSmsSaving] = useState(false);

  useEffect(() => {
    let mounted = true;
    const fetchSmsSettings = async () => {
      setSmsLoading(true);
      const { data, error } = await supabase
        .from('app_settings')
        .select('mnotify_api_key, mnotify_sender_id')
        .eq('id', true)
        .maybeSingle();
      if (mounted && !error && data) {
        setSmsForm({
          apiKey: data.mnotify_api_key || '',
          senderId: data.mnotify_sender_id || '',
        });
      }
      if (error) console.warn('app_settings (sms) fetch:', error);
      if (mounted) setSmsLoading(false);
    };
    fetchSmsSettings();
    return () => { mounted = false; };
  }, []);

  const handleSaveSmsSettings = async (e) => {
    e.preventDefault();
    setSmsSaving(true);
    const { error } = await supabase.from('app_settings').upsert({
      id: true,
      mnotify_api_key: smsForm.apiKey.trim() || null,
      mnotify_sender_id: smsForm.senderId.trim() || null,
    }, { onConflict: 'id' });
    if (error) {
      alert('Failed to save SMS settings: ' + error.message);
    } else {
      alert('SMS settings saved.');
    }
    setSmsSaving(false);
  };

  // ── Rider workload cap: how many pickups a rider may hold accepted at once ──
  const [maxPickupsForm, setMaxPickupsForm] = useState('3');
  const [maxPickupsLoading, setMaxPickupsLoading] = useState(false);
  const [maxPickupsSaving, setMaxPickupsSaving] = useState(false);

  useEffect(() => {
    let mounted = true;
    const fetchMaxPickups = async () => {
      setMaxPickupsLoading(true);
      const { data, error } = await supabase
        .from('app_settings')
        .select('max_concurrent_pickups')
        .eq('id', true)
        .maybeSingle();
      if (mounted && !error && data?.max_concurrent_pickups != null) {
        setMaxPickupsForm(String(data.max_concurrent_pickups));
      }
      if (error) console.warn('app_settings (max pickups) fetch:', error);
      if (mounted) setMaxPickupsLoading(false);
    };
    fetchMaxPickups();
    return () => { mounted = false; };
  }, []);

  const handleSaveMaxPickups = async (e) => {
    e.preventDefault();
    const parsed = parseInt(maxPickupsForm, 10);
    if (!Number.isFinite(parsed) || parsed < 1) {
      alert('Enter a whole number of 1 or more.');
      return;
    }
    setMaxPickupsSaving(true);
    const { error } = await supabase.from('app_settings').upsert({
      id: true,
      max_concurrent_pickups: parsed,
    }, { onConflict: 'id' });
    if (error) {
      alert('Failed to save rider pickup limit: ' + error.message);
    } else {
      alert('Rider pickup limit saved.');
    }
    setMaxPickupsSaving(false);
  };

  // ── Admin profile helpers ────────────────────────────────────────────────
  const handleAdminPhotoUpload = (e) => {
    const file = e.target.files?.[0];
    if (!file || !session?.user?.id) return;
    const reader = new FileReader();
    reader.onload = async () => {
      const dataUrl = reader.result;
      const { error } = await supabase
        .from('profiles')
        .update({ profile_picture_url: dataUrl })
        .eq('id', session.user.id);
      if (error) alert('Failed to update photo: ' + error.message);
      else await refreshProfile();
    };
    reader.readAsDataURL(file);
  };

  const handleSaveProfile = async () => {
    if (!session?.user?.id) return;
    setSavingProfile(true);
    const { error } = await supabase
      .from('profiles')
      .update({ full_name: nameInput })
      .eq('id', session.user.id);
    if (error) {
      alert('Failed to update profile: ' + error.message);
    } else {
      await refreshProfile();
      setIsEditingProfile(false);
    }
    setSavingProfile(false);
  };

  const handleAddZone = (e) => {
    e.preventDefault();
    const formData = new FormData(e.target);
    setZones([...zones, { id: `ZN-0${zones.length + 1}`, name: formData.get('name'), status: 'Active' }]);
    setShowZoneModal(false);
  };

  const priceLabel = (plan, size) => {
    const val = plan.prices?.[size];
    if (val == null || val === '') return '—';
    return `GHS ${Number(val).toFixed(2)}`;
  };

  return (
    <div className="page-content">
      {/* ── Page Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>System Platform Settings</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Manage organization configurations, service parameters, and administrative controls.
          </p>
        </div>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>

        {/* ── Admin Account Profile ── */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <h3 style={{ fontSize: '16px' }}>Admin Account Profile</h3>
          <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
            <div
              style={{ position: 'relative', width: '72px', height: '72px', cursor: 'pointer', flexShrink: 0 }}
              onClick={() => photoInputRef.current?.click()}
              title="Click to change profile photo"
            >
              {adminPhoto ? (
                <img src={adminPhoto} alt="Admin" style={{ width: '72px', height: '72px', borderRadius: '50%', objectFit: 'cover', border: '3px solid var(--color-primary)' }} />
              ) : (
                <div style={{ width: '72px', height: '72px', borderRadius: '50%', background: 'linear-gradient(135deg, var(--color-primary), var(--color-info))', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '28px', fontWeight: '900', color: 'white', border: '3px solid var(--color-primary)' }}>
                  {adminName[0]?.toUpperCase() || 'A'}
                </div>
              )}
              <div style={{ position: 'absolute', bottom: 0, right: 0, background: 'var(--color-primary)', borderRadius: '50%', padding: '5px', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 2px 8px rgba(0,0,0,0.3)' }}>
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg>
              </div>
              <input ref={photoInputRef} type="file" accept="image/*" style={{ display: 'none' }} onChange={handleAdminPhotoUpload} />
            </div>
            <div style={{ flex: 1 }}>
              {isEditingProfile ? (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  <input value={nameInput} onChange={(e) => setNameInput(e.target.value)} placeholder="Full Name" style={{ padding: '8px 12px', borderRadius: '8px', fontSize: '14px', border: '1px solid var(--border-divider)', background: 'var(--bg-app)', color: 'var(--text-primary)' }} />
                  <p style={{ fontSize: '11px', color: 'var(--text-muted)' }}>Email: {adminEmail} (sign-in email — contact another admin to change it)</p>
                  <div style={{ display: 'flex', gap: '8px', marginTop: '4px' }}>
                    <button className="btn-primary" style={{ padding: '6px 14px', fontSize: '12px' }} onClick={handleSaveProfile} disabled={savingProfile}>
                      {savingProfile ? 'Saving…' : 'Save'}
                    </button>
                    <button className="btn-outline" style={{ padding: '6px 14px', fontSize: '12px' }} onClick={() => setIsEditingProfile(false)}>Cancel</button>
                  </div>
                </div>
              ) : (
                <>
                  <h4 style={{ fontSize: '18px', fontWeight: '800' }}>{adminName}</h4>
                  <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>{adminEmail}</p>
                  <p style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '2px' }}>Super Administrator • CleanConnect Platform</p>
                  <button className="btn-outline" style={{ marginTop: '10px', padding: '5px 12px', fontSize: '11px' }} onClick={() => { setNameInput(adminName); setIsEditingProfile(true); }}>
                    ✏️ Edit Profile
                  </button>
                </>
              )}
            </div>
          </div>
          <p style={{ fontSize: '11px', color: 'var(--text-muted)', fontStyle: 'italic' }}>Click the avatar above to change your profile photo.</p>
        </div>

        {/* ── Subscription Pricing Plans ── */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h3 style={{ fontSize: '16px' }}>Subscription Pricing Plans</h3>
              <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                Set dynamic prices per bin capacity for each collection frequency. The mobile app reads these in real time.
              </p>
            </div>
            <button className="btn-primary" style={{ padding: '8px 14px', fontSize: '12px', whiteSpace: 'nowrap' }} onClick={openCreatePlan}>
              + Add Plan
            </button>
          </div>

          {pricingPlans.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '32px', color: 'var(--text-muted)', fontSize: '13px' }}>
              No pricing plans configured yet. Click "Add Plan" to create one.
            </div>
          ) : (
            <div className="table-container">
              <table className="custom-table">
                <thead>
                  <tr>
                    <th>Plan Name</th>
                    <th>Frequency</th>
                    <th>120L Price</th>
                    <th>240L Price</th>
                    <th>360L Price</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {pricingPlans.map((plan) => (
                    <tr key={plan.id}>
                      <td>
                        <div style={{ fontWeight: '800' }}>{plan.name}</div>
                        {plan.description && <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '2px' }}>{plan.description}</div>}
                        {plan.is_payg && <span className="badge badge-pending" style={{ fontSize: '9px', marginTop: '4px' }}>PAY-AS-YOU-GO</span>}
                      </td>
                      <td style={{ fontWeight: '600', textTransform: 'capitalize' }}>{plan.frequency || '—'}</td>
                      <td style={{ color: 'var(--color-success)', fontWeight: '700' }}>{priceLabel(plan, '120L')}</td>
                      <td style={{ color: 'var(--color-success)', fontWeight: '700' }}>{priceLabel(plan, '240L')}</td>
                      <td style={{ color: 'var(--color-success)', fontWeight: '700' }}>{priceLabel(plan, '360L')}</td>
                      <td>
                        <div style={{ display: 'flex', gap: '6px' }}>
                          <button className="btn-outline" style={{ padding: '5px 10px', fontSize: '11px' }} onClick={() => openEditPlan(plan)}>Edit</button>
                          <button
                            style={{ padding: '5px 10px', fontSize: '11px', borderRadius: '8px', border: '1px solid var(--color-danger)', background: 'transparent', color: 'var(--color-danger)', cursor: 'pointer', fontWeight: '700' }}
                            onClick={() => handleDeletePlan(plan.id)}
                          >
                            Delete
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* ── SMS Provider (mNotify) ── */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div>
            <h3 style={{ fontSize: '16px' }}>SMS Notifications (mNotify)</h3>
            <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
              Used to text customers their bin serial number when a company bin is assigned. Overrides the
              server-side MNOTIFY_API_KEY / MNOTIFY_SENDER_ID secrets once saved here.
            </p>
          </div>
          <form onSubmit={handleSaveSmsSettings} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div className="form-group">
              <label>mNotify API Key</label>
              <div style={{ display: 'flex', gap: '8px' }}>
                <input
                  type={smsKeyVisible ? 'text' : 'password'}
                  value={smsForm.apiKey}
                  onChange={(e) => setSmsForm((prev) => ({ ...prev, apiKey: e.target.value }))}
                  placeholder={smsLoading ? 'Loading…' : 'Enter mNotify API key'}
                  autoComplete="off"
                  style={{ flex: 1 }}
                />
                <button
                  type="button"
                  className="btn-outline"
                  style={{ padding: '8px 12px', fontSize: '11px', whiteSpace: 'nowrap' }}
                  onClick={() => setSmsKeyVisible((v) => !v)}
                >
                  {smsKeyVisible ? 'Hide' : 'Show'}
                </button>
              </div>
            </div>
            <div className="form-group">
              <label>Sender ID</label>
              <input
                type="text"
                value={smsForm.senderId}
                onChange={(e) => setSmsForm((prev) => ({ ...prev, senderId: e.target.value }))}
                placeholder={smsLoading ? 'Loading…' : 'e.g. CleanConnect'}
                maxLength={11}
              />
              <p style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>
                Must match a sender ID already registered with mNotify (max 11 characters).
              </p>
            </div>
            <div>
              <button className="btn-primary" type="submit" disabled={smsSaving || smsLoading} style={{ padding: '8px 16px', fontSize: '12px' }}>
                {smsSaving ? 'Saving…' : 'Save SMS Settings'}
              </button>
            </div>
          </form>
        </div>

        {/* ── Rider Workload Cap ── */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div>
            <h3 style={{ fontSize: '16px' }}>Rider Pickup Limit</h3>
            <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
              Maximum number of pickups a rider can hold accepted at the same time. Once a rider hits
              this limit, they must complete one before accepting another — prevents a single rider
              from hoarding every pending request.
            </p>
          </div>
          <form onSubmit={handleSaveMaxPickups} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div className="form-group" style={{ maxWidth: '220px' }}>
              <label>Max concurrent pickups per rider</label>
              <input
                type="number"
                min="1"
                step="1"
                value={maxPickupsForm}
                onChange={(e) => setMaxPickupsForm(e.target.value)}
                placeholder={maxPickupsLoading ? 'Loading…' : 'e.g. 3'}
              />
            </div>
            <div>
              <button className="btn-primary" type="submit" disabled={maxPickupsSaving || maxPickupsLoading} style={{ padding: '8px 16px', fontSize: '12px' }}>
                {maxPickupsSaving ? 'Saving…' : 'Save Rider Pickup Limit'}
              </button>
            </div>
          </form>
        </div>

        {/* ── Roles & Permissions ── */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <h3 style={{ fontSize: '16px' }}>Roles & Permissions</h3>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-divider)', paddingBottom: '16px' }}>
            <div>
              <h4 style={{ fontSize: '13px', fontWeight: 'bold' }}>Super Admin Access</h4>
              <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '4px' }}>Full root-level write access to database configurations.</p>
            </div>
            <label className="switch"><input type="checkbox" checked={superAdminAccess} onChange={(e) => setSuperAdminAccess(e.target.checked)} /><span className="slider"></span></label>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h4 style={{ fontSize: '13px', fontWeight: 'bold' }}>Other Route Modifications</h4>
              <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '4px' }}>Allow active optimization overrides during active rider shifts.</p>
            </div>
            <label className="switch"><input type="checkbox" defaultChecked /><span className="slider"></span></label>
          </div>
        </div>

        {/* ── Service Zones ── */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3 style={{ fontSize: '16px' }}>Active Service Zones</h3>
            <button className="btn-outline" style={{ padding: '6px 12px', fontSize: '11px' }} onClick={() => setShowZoneModal(true)}>+ Add Service Zone</button>
          </div>
          <div className="table-container">
            <table className="custom-table">
              <thead><tr><th>Zone ID</th><th>Zone Sector Area</th><th>Status</th><th>Actions</th></tr></thead>
              <tbody>
                {zones.map((zone) => (
                  <tr key={zone.id}>
                    <td style={{ fontWeight: '700', color: 'var(--color-primary)' }}>{zone.id}</td>
                    <td style={{ fontWeight: '600' }}>{zone.name}</td>
                    <td><span className={`badge ${zone.status === 'Active' ? 'badge-active' : 'badge-defaulter'}`}>{zone.status}</span></td>
                    <td>
                      <button className="btn-outline" style={{ padding: '4px 8px', fontSize: '10px' }} onClick={() => setZones(prev => prev.map(z => z.id === zone.id ? { ...z, status: z.status === 'Active' ? 'Suspended' : 'Active' } : z))}>
                        Toggle Status
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* ── Help & Support ── */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div>
            <h3 style={{ fontSize: '16px' }}>Help &amp; Support</h3>
            <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
              Official CleanConnect support contact channels. These are the details shown to customers in the mobile app.
              Editing and saving here updates what customers see immediately.
            </p>
          </div>

          <form onSubmit={handleSaveContact} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
              {/* Phone */}
              <div className="form-group" style={{ margin: 0 }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--color-success)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07A19.5 19.5 0 0 1 4.69 12a19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 3.77 1h3a2 2 0 0 1 2 1.72c.127.96.361 1.903.7 2.81a2 2 0 0 1-.45 2.11L8.09 8.91a16 16 0 0 0 6 6l.91-.91a2 2 0 0 1 2.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0 1 22 16.92z" />
                  </svg>
                  Support Phone Number
                </label>
                <input
                  type="tel"
                  value={contactForm.phone}
                  onChange={(e) => setContactForm((p) => ({ ...p, phone: e.target.value }))}
                  placeholder={contactLoading ? 'Loading…' : '+233 24 881 4260'}
                  disabled={contactLoading}
                  style={{ fontWeight: '700', fontSize: '15px' }}
                />
                <p style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>Shown on the "Call Us" card in the mobile app.</p>
              </div>

              {/* Email */}
              <div className="form-group" style={{ margin: 0 }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--color-primary)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" /><polyline points="22,6 12,13 2,6" />
                  </svg>
                  Support Email Address
                </label>
                <input
                  type="email"
                  value={contactForm.email}
                  onChange={(e) => setContactForm((p) => ({ ...p, email: e.target.value }))}
                  placeholder={contactLoading ? 'Loading…' : 'support@cleanconnect.com'}
                  disabled={contactLoading}
                  style={{ fontWeight: '700', fontSize: '15px' }}
                />
                <p style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>Shown on the "Email Support" card in the mobile app.</p>
              </div>
            </div>

            {/* Preview */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px', background: 'var(--bg-app)', borderRadius: '12px', padding: '12px 16px', border: '1px solid var(--border-glass)', opacity: contactLoading ? 0.5 : 1 }}>
                <div style={{ width: '36px', height: '36px', borderRadius: '50%', background: 'rgba(34,197,94,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--color-success)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07A19.5 19.5 0 0 1 4.69 12a19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 3.77 1h3a2 2 0 0 1 2 1.72c.127.96.361 1.903.7 2.81a2 2 0 0 1-.45 2.11L8.09 8.91a16 16 0 0 0 6 6l.91-.91a2 2 0 0 1 2.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0 1 22 16.92z" />
                  </svg>
                </div>
                <div>
                  <div style={{ fontSize: '10px', color: 'var(--text-muted)', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Mobile Preview • Call Us</div>
                  <div style={{ fontSize: '14px', fontWeight: '900', color: 'var(--text-primary)', marginTop: '3px' }}>{contactForm.phone || '—'}</div>
                </div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px', background: 'var(--bg-app)', borderRadius: '12px', padding: '12px 16px', border: '1px solid var(--border-glass)', opacity: contactLoading ? 0.5 : 1 }}>
                <div style={{ width: '36px', height: '36px', borderRadius: '50%', background: 'rgba(2,132,199,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--color-primary)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" /><polyline points="22,6 12,13 2,6" />
                  </svg>
                </div>
                <div>
                  <div style={{ fontSize: '10px', color: 'var(--text-muted)', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Mobile Preview • Email Support</div>
                  <div style={{ fontSize: '14px', fontWeight: '900', color: 'var(--text-primary)', marginTop: '3px' }}>{contactForm.email || '—'}</div>
                </div>
              </div>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <button
                className="btn-primary"
                type="submit"
                disabled={contactSaving || contactLoading}
                style={{ padding: '8px 20px', fontSize: '12px' }}
              >
                {contactSaving ? 'Saving…' : 'Save Contact Settings'}
              </button>
              {contactSaved && (
                <span style={{ fontSize: '12px', color: 'var(--color-success)', fontWeight: '700', display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><polyline points="20 6 9 17 4 12" /></svg>
                  Saved — mobile app will reflect this shortly
                </span>
              )}
            </div>
          </form>
        </div>

        {/* ── Support Tickets (Customer Problem Reports) ── */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h3 style={{ fontSize: '16px' }}>Customer Support Tickets</h3>
              <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                Reports submitted by customers via the mobile app — Missed Collection, Damaged Bin, Extra Pickup requests.
              </p>
            </div>
            <div style={{ display: 'flex', gap: '6px' }}>
              {['All', 'pending', 'resolved'].map((f) => (
                <button
                  key={f}
                  onClick={() => setTicketFilter(f)}
                  style={{
                    padding: '5px 12px', fontSize: '11px', borderRadius: '20px', fontWeight: '700', cursor: 'pointer',
                    background: ticketFilter === f ? 'var(--color-primary)' : 'transparent',
                    color: ticketFilter === f ? 'white' : 'var(--text-secondary)',
                    border: ticketFilter === f ? 'none' : '1px solid var(--border-divider)',
                  }}
                >
                  {f.charAt(0).toUpperCase() + f.slice(1)}
                </button>
              ))}
            </div>
          </div>

          {ticketsLoading ? (
            <div style={{ textAlign: 'center', padding: '32px', color: 'var(--text-muted)', fontSize: '13px' }}>Loading tickets…</div>
          ) : (() => {
            const filtered = ticketFilter === 'All' ? supportTickets : supportTickets.filter(t => t.status === ticketFilter);
            if (filtered.length === 0) {
              return (
                <div style={{ textAlign: 'center', padding: '32px', color: 'var(--text-muted)', fontSize: '13px' }}>
                  {ticketFilter === 'All' ? 'No support tickets submitted yet.' : `No ${ticketFilter} tickets.`}
                </div>
              );
            }
            return (
              <div className="table-container">
                <table className="custom-table">
                  <thead>
                    <tr>
                      <th>Category</th>
                      <th>Description</th>
                      <th>Submitted</th>
                      <th>Status</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filtered.map((ticket) => (
                      <tr key={ticket.id}>
                        <td>
                          <div style={{ fontWeight: '800', fontSize: '13px' }}>
                            {ticket.title?.replace('Support Ticket: ', '') || '—'}
                          </div>
                        </td>
                        <td style={{ maxWidth: '260px' }}>
                          <div style={{ fontSize: '12px', color: 'var(--text-secondary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {ticket.description || '—'}
                          </div>
                        </td>
                        <td style={{ fontSize: '12px', color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                          {ticket.createdAt ? ticket.createdAt.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—'}
                        </td>
                        <td>
                          <span className={`badge ${ticket.status === 'resolved' ? 'badge-active' : ticket.status === 'pending' ? 'badge-pending' : 'badge-defaulter'}`}>
                            {ticket.status || 'pending'}
                          </span>
                        </td>
                        <td>
                          {ticket.status !== 'resolved' ? (
                            <button
                              className="btn-outline"
                              style={{ padding: '4px 10px', fontSize: '11px', color: 'var(--color-success)', borderColor: 'var(--color-success)' }}
                              onClick={() => handleUpdateTicketStatus(ticket.id, 'resolved')}
                            >
                              Mark Resolved
                            </button>
                          ) : (
                            <button
                              className="btn-outline"
                              style={{ padding: '4px 10px', fontSize: '11px' }}
                              onClick={() => handleUpdateTicketStatus(ticket.id, 'pending')}
                            >
                              Reopen
                            </button>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            );
          })()}
        </div>
      </div>

      {/* ── Add/Edit Pricing Plan Modal ── */}
      {showPlanModal && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '520px', width: '100%' }}>
            <h3 style={{ fontSize: '18px', marginBottom: '4px' }}>
              {editingPlan ? 'Edit Pricing Plan' : 'Create Pricing Plan'}
            </h3>
            <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginBottom: '20px' }}>
              Set the price per bin capacity. The mobile app will show customers the price matching their bin size.
            </p>
            <form onSubmit={handleSavePlan} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div className="form-group">
                <label>Plan Name</label>
                <input value={planForm.name} onChange={(e) => handlePlanFormChange('name', e.target.value)} placeholder="e.g. Weekly Plan" required />
              </div>

              <div className="form-group">
                <label>Description (optional)</label>
                <input value={planForm.description} onChange={(e) => handlePlanFormChange('description', e.target.value)} placeholder="e.g. Most popular for busy households" />
              </div>

              {/* PAYG toggle */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'var(--bg-app)', padding: '12px', borderRadius: '8px' }}>
                <div>
                  <div style={{ fontWeight: '700', fontSize: '13px' }}>Pay-As-You-Go Plan</div>
                  <div style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '2px' }}>Customer pays per pickup, no monthly commitment</div>
                </div>
                <label className="switch">
                  <input type="checkbox" checked={planForm.isPayg} onChange={(e) => handlePlanFormChange('isPayg', e.target.checked)} />
                  <span className="slider"></span>
                </label>
              </div>

              {!planForm.isPayg && (
                <div className="form-group">
                  <label>Collection Frequency</label>
                  <select value={planForm.frequency} onChange={(e) => handlePlanFormChange('frequency', e.target.value)}>
                    <option value="Weekly">Weekly</option>
                    <option value="Bi-weekly">Bi-weekly</option>
                    <option value="Monthly">Monthly</option>
                  </select>
                </div>
              )}

              {/* Per-size pricing grid */}
              <div>
                <label style={{ fontSize: '12px', fontWeight: '700', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.5px', display: 'block', marginBottom: '10px' }}>
                  Price per Bin Capacity (GHS / {planForm.isPayg ? 'pickup' : 'month'})
                </label>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(120px, 1fr))', gap: '10px' }}>
                  {BIN_SIZES.map((size) => (
                    <div key={size} style={{ background: 'var(--bg-app)', borderRadius: '10px', padding: '12px', display: 'flex', flexDirection: 'column', gap: '6px' }}>
                      <span style={{ fontSize: '11px', fontWeight: '800', color: 'var(--text-muted)', textTransform: 'uppercase' }}>{size}</span>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                        <span style={{ fontSize: '12px', color: 'var(--text-secondary)', fontWeight: '600' }}>GHS</span>
                        <input
                          type="number"
                          min="0"
                          step="0.01"
                          placeholder="0.00"
                          value={planForm.prices[size]}
                          onChange={(e) => handlePriceChange(size, e.target.value)}
                          style={{ flex: 1, minWidth: 0, padding: '6px 8px', borderRadius: '6px', border: '1px solid var(--border-divider)', background: 'var(--bg-sidebar)', color: 'var(--text-primary)', fontSize: '14px', fontWeight: '700' }}
                        />
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="modal-actions">
                <button type="button" className="btn-outline" onClick={() => setShowPlanModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" disabled={planLoading}>
                  {planLoading ? 'Saving...' : editingPlan ? 'Save Changes' : 'Create Plan'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── Add Zone Modal ── */}
      {showZoneModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>Add Service Zone</h3>
            <form onSubmit={handleAddZone} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div className="form-group">
                <label>Zone Sector Name</label>
                <input name="name" type="text" placeholder="e.g. Airport Hills East" required />
              </div>
              <div className="modal-actions">
                <button type="button" className="btn-outline" onClick={() => setShowZoneModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary">Add Zone</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
