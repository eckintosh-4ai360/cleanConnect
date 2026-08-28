// roles.js — the back-office role catalogue.
//
// Kept in sync with the profiles_role_check constraint and the
// BACK_OFFICE_ROLES list in supabase/functions/admin-create-user.
//
// `tabs` decides which sidebar pages a role is shown. That is a UX filter, not
// a security boundary: every back-office role shares the same database
// privileges (see the is_admin() note in
// supabase/migrations/20260828120000_back_office_roles.sql). The privileged
// actions — creating panel users, changing a role or a status — are gated on
// the 'admin' role and enforced server-side.

export const ALL_TABS = [
  'Dashboard', 'Customers', 'Bins', 'Riders', 'Fleet Map', 'Sites', 'Collections',
  'Pickups', 'Waste Reports', 'Waste Workers', 'Routes', 'Payments', 'Maintenance',
  'Reports', 'Users', 'Settings',
];

export const BACK_OFFICE_ROLES = [
  {
    value: 'admin',
    label: 'Administrator',
    description: 'Full access to every page, plus the only role that can create or edit panel users.',
    color: '#0284c7',
    tabs: ALL_TABS,
  },
  {
    value: 'supervisor',
    label: 'Supervisor',
    description: 'Runs day-to-day operations — fleet, routes, collections and incidents. No billing or user management.',
    color: '#8b5cf6',
    tabs: [
      'Dashboard', 'Customers', 'Bins', 'Riders', 'Fleet Map', 'Sites', 'Collections',
      'Pickups', 'Waste Reports', 'Waste Workers', 'Routes', 'Maintenance', 'Reports', 'Settings',
    ],
  },
  {
    value: 'financial_secretary',
    label: 'Financial Secretary',
    description: 'Handles billing: payments, invoices, defaulters and financial reporting.',
    color: '#10b981',
    tabs: ['Dashboard', 'Customers', 'Payments', 'Reports', 'Settings'],
  },
  {
    value: 'staff',
    label: 'Staff',
    description: 'General back-office work — customers, bins, pickups and collection records.',
    color: '#f59e0b',
    tabs: ['Dashboard', 'Customers', 'Bins', 'Sites', 'Collections', 'Pickups', 'Waste Workers', 'Settings'],
  },
  {
    value: 'support',
    label: 'Support Agent',
    description: 'Answers customer queries: pickup requests, waste reports and support tickets.',
    color: '#06b6d4',
    tabs: ['Dashboard', 'Customers', 'Bins', 'Pickups', 'Waste Reports', 'Settings'],
  },
];

const byValue = new Map(BACK_OFFICE_ROLES.map((r) => [r.value, r]));

export function isBackOfficeRole(role) {
  return byValue.has(role);
}

export function roleLabel(role) {
  return byValue.get(role)?.label ?? (role ?? '—');
}

export function roleColor(role) {
  return byValue.get(role)?.color ?? 'var(--text-muted)';
}

export function tabsForRole(role) {
  return byValue.get(role)?.tabs ?? [];
}

export function canManageUsers(role) {
  return role === 'admin';
}
