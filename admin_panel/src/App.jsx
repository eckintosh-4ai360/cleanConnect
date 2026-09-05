import React, { useState, useEffect, useMemo } from 'react';
import { supabase } from './supabase';
import { useAuth } from './AuthContext';
import Login from './components/Login';
import SetPassword from './components/SetPassword';
import Dashboard from './components/Dashboard';
import Customers from './components/Customers';
import Bins from './components/Bins';
import Riders from './components/Riders';
import FleetMap from './components/FleetMap';
import Sites from './components/Sites';
import Collections from './components/Collections';
import PickupRequests from './components/PickupRequests';
import IncidentReports from './components/IncidentReports';
import WasteWorkers from './components/WasteWorkers';
import Routes from './components/Routes';
import Payments from './components/Payments';
import Maintenance from './components/Maintenance';
import Reports from './components/Reports';
import Settings from './components/Settings';
import UserManagement from './components/UserManagement';
import { roleLabel, tabsForRole } from './roles';

export default function App() {
  const { session, profile, loading, needsPasswordSetup, completePasswordSetup } = useAuth();

  if (loading) {
    return (
      <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--bg-app)' }}>
        <span style={{ color: 'var(--text-secondary)', fontSize: '13px' }}>Loading…</span>
      </div>
    );
  }

  // A recovery link signs the user in before they have a password, so this has
  // to come ahead of the profile gate: an invited user has a valid session but
  // nothing they could sign in with again tomorrow.
  if (session && needsPasswordSetup) {
    return <SetPassword email={session.user?.email} onDone={completePasswordSetup} />;
  }

  if (!session || !profile) {
    return <Login />;
  }

  return <AdminShell profile={profile} />;
}

function AdminShell({ profile }) {
  const { signOut } = useAuth();
  const [activeTab, setActiveTab] = useState(() => {
    return localStorage.getItem('activeTab') || 'Dashboard';
  });
  const [theme, setTheme] = useState(() => {
    return localStorage.getItem('theme') || 'light';
  });
  const [searchQuery, setSearchQuery] = useState('');
  const [notifications, setNotifications] = useState([]);
  const [showNotifDrawer, setShowNotifDrawer] = useState(false);

  const adminName = profile?.full_name || 'Admin';
  const adminPhoto = profile?.profile_picture_url || null;
  const allowedTabs = useMemo(() => tabsForRole(profile?.role), [profile?.role]);

  // Synchronize CSS custom data theme values and persist preference
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('theme', theme);
  }, [theme]);

  // Persist the active sidebar tab so a page refresh doesn't bounce back to Dashboard
  useEffect(() => {
    localStorage.setItem('activeTab', activeTab);
  }, [activeTab]);

  // A stale localStorage tab — or a role change made while signed in — can point
  // at a page this user is no longer shown. Send them to their first page.
  useEffect(() => {
    if (allowedTabs.length > 0 && !allowedTabs.includes(activeTab)) {
      setActiveTab(allowedTabs[0]);
    }
  }, [allowedTabs, activeTab]);

  // Real-time Platform Notifications
  const mapNotifRow = (r) => ({
    id: r.id,
    title: r.title,
    message: r.message,
    type: r.type,
    isRead: r.is_read,
    createdAt: r.created_at ? new Date(r.created_at) : new Date(),
  });

  useEffect(() => {
    let mounted = true;

    supabase
      .from('admin_notifications')
      .select('*')
      .order('created_at', { ascending: false })
      .then(({ data, error }) => {
        if (mounted && !error) setNotifications(data.map(mapNotifRow));
        if (error) console.warn('Notification fetch:', error);
      });

    const channel = supabase
      .channel('admin_notifications_changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'admin_notifications' },
        (payload) => {
          setNotifications((prev) => {
            if (payload.eventType === 'INSERT') {
              return [mapNotifRow(payload.new), ...prev];
            }
            if (payload.eventType === 'UPDATE') {
              return prev.map((n) => (n.id === payload.new.id ? mapNotifRow(payload.new) : n));
            }
            if (payload.eventType === 'DELETE') {
              return prev.filter((n) => n.id !== payload.old.id);
            }
            return prev;
          });
        }
      )
      .subscribe();

    return () => {
      mounted = false;
      supabase.removeChannel(channel);
    };
  }, []);

  const toggleTheme = () => {
    setTheme(prev => prev === 'light' ? 'dark' : 'light');
  };

  const unreadCount = notifications.filter((n) => !n.isRead).length;

  const handleMarkAllRead = async () => {
    const unreadIds = notifications.filter((n) => !n.isRead).map((n) => n.id);
    if (unreadIds.length === 0) return;
    const { error } = await supabase
      .from('admin_notifications')
      .update({ is_read: true })
      .in('id', unreadIds);
    if (error) console.error('Failed to mark all notifications read:', error);
  };

  const handleNotificationClick = async (n) => {
    if (!n.isRead) {
      const { error } = await supabase
        .from('admin_notifications')
        .update({ is_read: true })
        .eq('id', n.id);
      if (error) console.warn('Failed to mark notification read:', error);
    }
    if (n.type === 'bin_registered' || n.type === 'bin_requested') {
      setActiveTab('Bins');
    } else if (n.type === 'pickup_requested' || n.type === 'customer_registered') {
      setActiveTab('Customers');
    } else if (n.type === 'collection_completed') {
      setActiveTab('Collections');
    } else if (n.type === 'incident_reported') {
      setActiveTab('Waste Reports');
    } else if (n.type === 'support_ticket') {
      setActiveTab('Settings');
    }
    setShowNotifDrawer(false);
  };

  const formatNotifTime = (date) => {
    if (!date) return 'Just now';
    const diff = Math.floor((Date.now() - date.getTime()) / 1000);
    if (diff < 60) return `${diff}s ago`;
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return date.toLocaleDateString();
  };

  // Sidebar Menu Items with Inline Custom Vector Paths
  const menuItems = [
    {
      name: 'Dashboard',
      icon: (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <rect x="3" y="3" width="7" height="9" /><rect x="14" y="3" width="7" height="5" /><rect x="14" y="12" width="7" height="9" /><rect x="3" y="16" width="7" height="5" />
        </svg>
      )
    },
    {
      name: 'Customers',
      icon: (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
        </svg>
      )
    },
    {
      name: 'Bins',
      icon: (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M7 4h10l-1 17H8L7 4z" /><path d="M5 4h14" /><path d="M9 4V2h6v2" /><path d="M10 9h4" /><path d="M10 13h4" />
        </svg>
      )
    },
    {
      name: 'Riders',
      icon: (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <circle cx="5.5" cy="18.5" r="2.5" /><circle cx="18.5" cy="18.5" r="2.5" /><path d="M3 16h18v2H3zM5.5 16l3-6h8.5l2.5 6" />
        </svg>
      )
    },
    {
      name: 'Fleet Map',
      icon: (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <polygon points="1 6 8 3 16 6 23 3 23 18 16 21 8 18 1 21 1 6" /><line x1="8" y1="3" x2="8" y2="18" /><line x1="16" y1="6" x2="16" y2="21" />
        </svg>
      )
    },
    {
      name: 'Sites',
      icon: (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" /><circle cx="12" cy="10" r="3" />
        </svg>
      )
    },
    {
      name: 'Collections',
      icon: (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z" /><polyline points="3.27 6.96 12 12.01 20.73 6.96" /><line x1="12" y1="22.08" x2="12" y2="12" />
        </svg>
      )
    },
    {
      name: 'Pickups',
      icon: (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2" /><rect x="9" y="3" width="6" height="4" rx="2" /><line x1="9" y1="12" x2="15" y2="12" /><line x1="9" y1="16" x2="13" y2="16" />
        </svg>
      )
    },
    {
      name: 'Waste Reports',
      icon: (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M12 9v4M12 17h.01" /><path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
        </svg>
      )
    },
    {
      name: 'Waste Workers',
      icon: (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M20 20 8.5 8.5" /><path d="m2.5 5.5 3-3 4 4-3 3z" /><path d="M17 17.5 22 14l-2.5-4-5 3" />
        </svg>
      )
    },
    {
      name: 'Routes',
      icon: (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <line x1="6" y1="3" x2="6" y2="15" /><circle cx="18" cy="6" r="3" /><circle cx="6" cy="18" r="3" /><path d="M18 9a9 9 0 0 1-9 9" />
        </svg>
      )
    },
    {
      name: 'Payments',
      icon: (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <line x1="12" y1="1" x2="12" y2="23" /><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
        </svg>
      )
    },
    {
      name: 'Maintenance',
      icon: (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z" />
        </svg>
      )
    },
    {
      name: 'Reports',
      icon: (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <line x1="18" y1="20" x2="18" y2="10" /><line x1="12" y1="20" x2="12" y2="4" /><line x1="6" y1="20" x2="6" y2="14" />
        </svg>
      )
    },
    {
      name: 'Users',
      icon: (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><line x1="19" y1="8" x2="19" y2="14" /><line x1="22" y1="11" x2="16" y2="11" />
        </svg>
      )
    },
    {
      name: 'Settings',
      icon: (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
        </svg>
      )
    }
  ];

  // Dynamically Render Active Screen Component
  const renderActiveScreen = () => {
    if (!allowedTabs.includes(activeTab)) return <Dashboard />;

    switch (activeTab) {
      case 'Dashboard':
        return <Dashboard />;
      case 'Customers':
        return <Customers />;
      case 'Bins':
        return <Bins />;
      case 'Riders':
        return <Riders />;
      case 'Fleet Map':
        return <FleetMap />;
      case 'Sites':
        return <Sites />;
      case 'Collections':
        return <Collections />;
      case 'Pickups':
        return <PickupRequests />;
      case 'Waste Reports':
        return <IncidentReports />;
      case 'Waste Workers':
        return <WasteWorkers />;
      case 'Routes':
        return <Routes />;
      case 'Payments':
        return <Payments />;
      case 'Maintenance':
        return <Maintenance />;
      case 'Reports':
        return <Reports />;
      case 'Users':
        return <UserManagement />;
      case 'Settings':
        return <Settings />;
      default:
        return <Dashboard />;
    }
  };

  return (
    <div className="app-container">
      {/* ── Left Sidebar Navigation ── */}
      <aside className="sidebar">
        <div className="sidebar-brand">
          <img
            src="/app-icon.png"
            alt="CleanConnect"
            width="32"
            height="32"
            style={{ borderRadius: '8px', display: 'block', flexShrink: 0 }}
          />
          <span className="sidebar-title">CleanConnect Admin</span>
        </div>

        <nav className="sidebar-menu">
          {menuItems.filter((item) => allowedTabs.includes(item.name)).map((item) => (
            <div
              key={item.name}
              className={`sidebar-item ${activeTab === item.name ? 'active' : ''}`}
              onClick={() => setActiveTab(item.name)}
            >
              {item.icon}
              {item.name}
            </div>
          ))}
        </nav>

        <div className="sidebar-footer">
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--color-success)' }}></div>
            <span style={{ fontSize: '11px', color: 'var(--text-secondary)', fontWeight: 'bold' }}>Server Live</span>
          </div>
          <button className="action-btn" style={{ width: '28px', height: '28px' }} onClick={signOut} title="Sign out">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/></svg>
          </button>
        </div>
      </aside>

      {/* ── Right Content Viewport ── */}
      <main className="main-viewport">
        {/* Top Header */}
        <header className="top-header">
          {/* Search bar */}
          <div className="header-search">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--text-muted)" strokeWidth="2.5"><circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" /></svg>
            <input
              type="text"
              placeholder={`Search ${activeTab.toLowerCase()}...`}
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>

          {/* Action Tools */}
          <div className="header-actions">
            {/* Theme Toggle */}
            <button className="action-btn" onClick={toggleTheme} aria-label="Toggle Theme">
              {theme === 'light' ? (
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" /></svg>
              ) : (
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="5" /><line x1="12" y1="1" x2="12" y2="3" /><line x1="12" y1="21" x2="12" y2="23" /><line x1="4.22" y1="4.22" x2="5.64" y2="5.64" /><line x1="18.36" y1="18.36" x2="19.78" y2="19.78" /><line x1="1" y1="12" x2="3" y2="12" /><line x1="21" y1="12" x2="23" y2="12" /><line x1="4.22" y1="19.78" x2="5.64" y2="18.36" /><line x1="18.36" y1="5.64" x2="19.78" y2="4.22" /></svg>
              )}
            </button>

            {/* Notification Center */}
            <div style={{ position: 'relative' }}>
              <button
                className="action-btn"
                onClick={() => setShowNotifDrawer(!showNotifDrawer)}
                aria-label="Notifications"
                style={{ position: 'relative' }}
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 0 1-3.46 0" />
                </svg>
                {unreadCount > 0 && (
                  <span
                    style={{
                      position: 'absolute',
                      top: '-3px',
                      right: '-3px',
                      background: 'var(--color-danger)',
                      color: 'white',
                      fontSize: '10px',
                      fontWeight: 'bold',
                      borderRadius: '50%',
                      width: '16px',
                      height: '16px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      boxShadow: '0 0 8px rgba(239, 68, 68, 0.5)',
                    }}
                  >
                    {unreadCount > 9 ? '9+' : unreadCount}
                  </span>
                )}
              </button>

              {/* Real-time Notification Popover / Drawer */}
              {showNotifDrawer && (
                <div
                  style={{
                    position: 'absolute',
                    top: '48px',
                    right: '0',
                    width: '360px',
                    maxHeight: '440px',
                    background: 'var(--bg-sidebar)',
                    backdropFilter: 'var(--glass-blur)',
                    border: '1px solid var(--border-glass)',
                    borderRadius: '16px',
                    boxShadow: 'var(--shadow-premium)',
                    zIndex: 1000,
                    display: 'flex',
                    flexDirection: 'column',
                    overflow: 'hidden',
                  }}
                >
                  <div
                    style={{
                      padding: '14px 16px',
                      borderBottom: '1px solid var(--border-divider)',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <h4 style={{ fontSize: '14px', fontWeight: '800' }}>Platform Notifications</h4>
                      {unreadCount > 0 && (
                        <span
                          style={{
                            background: 'var(--color-primary)',
                            color: 'white',
                            fontSize: '10px',
                            padding: '2px 6px',
                            borderRadius: '10px',
                            fontWeight: 'bold',
                          }}
                        >
                          {unreadCount} new
                        </span>
                      )}
                    </div>
                    {unreadCount > 0 && (
                      <button
                        onClick={handleMarkAllRead}
                        style={{
                          background: 'transparent',
                          border: 'none',
                          color: 'var(--color-primary)',
                          fontSize: '11px',
                          fontWeight: '700',
                          cursor: 'pointer',
                        }}
                      >
                        Mark all read
                      </button>
                    )}
                  </div>

                  <div style={{ overflowY: 'auto', flex: 1, padding: '8px' }}>
                    {notifications.length === 0 ? (
                      <div style={{ padding: '32px', textAlign: 'center', color: 'var(--text-muted)', fontSize: '13px' }}>
                        No platform alerts recorded yet.
                      </div>
                    ) : (
                      notifications.map((n) => (
                        <div
                          key={n.id}
                          onClick={() => handleNotificationClick(n)}
                          style={{
                            padding: '12px',
                            borderRadius: '10px',
                            marginBottom: '6px',
                            background: !n.isRead ? 'rgba(2, 132, 199, 0.08)' : 'transparent',
                            borderLeft: !n.isRead ? '3px solid var(--color-primary)' : '3px solid transparent',
                            cursor: 'pointer',
                            transition: 'var(--transition-smooth)',
                          }}
                        >
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <span style={{ fontSize: '12px', fontWeight: '800', color: !n.isRead ? 'var(--color-primary)' : 'var(--text-primary)' }}>
                              {n.title}
                            </span>
                            <span style={{ fontSize: '10px', color: 'var(--text-muted)' }}>
                              {formatNotifTime(n.createdAt)}
                            </span>
                          </div>
                          <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px', lineHeight: '1.4' }}>
                            {n.message}
                          </p>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              )}
            </div>

            {/* Profile Info */}
            <div className="user-profile-badge" title="Edit profile in Settings">
              {adminPhoto ? (
                <img src={adminPhoto} alt="Admin" className="user-avatar" style={{ objectFit: 'cover' }} />
              ) : (
                <div className="user-avatar" style={{
                  background: 'linear-gradient(135deg, var(--color-primary), var(--color-info))',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: '16px', fontWeight: '900', color: 'white',
                }}>
                  {adminName[0]?.toUpperCase() || 'A'}
                </div>
              )}
              <div style={{ display: 'flex', flexDirection: 'column', lineHeight: '1.2' }}>
                <span className="user-name">{adminName.split(' ')[0]}</span>
                <span style={{ fontSize: '10px', color: 'var(--text-muted)', fontWeight: '700' }}>
                  {roleLabel(profile?.role)}
                </span>
              </div>
            </div>
          </div>
        </header>

        {/* Dynamic page contents */}
        {renderActiveScreen()}
      </main>
    </div>
  );
}
