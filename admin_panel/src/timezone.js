// timezone.js — Centralized date & time formatting for CleanConnect
// CleanConnect operates in Ghana (GMT / UTC+0, Africa/Accra).
// Explicitly specifying the timezone ensures that all dates and times
// are rendered in Ghana local time regardless of the administrator's
// machine timezone, browser profile, or VPN settings.

export const APP_TIMEZONE = 'Africa/Accra';

export const formatDateTime = (date) => {
  if (!date) return '—';
  const d = date instanceof Date ? date : new Date(date);
  if (isNaN(d.getTime())) return '—';
  return (
    d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', timeZone: APP_TIMEZONE }) +
    ' @ ' +
    d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', timeZone: APP_TIMEZONE })
  );
};

export const formatDate = (date, options = {}) => {
  if (!date) return '—';
  const d = date instanceof Date ? date : new Date(date);
  if (isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    timeZone: APP_TIMEZONE,
    ...options,
  });
};

export const formatTime = (date) => {
  if (!date) return '—';
  const d = date instanceof Date ? date : new Date(date);
  if (isNaN(d.getTime())) return '—';
  return d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', timeZone: APP_TIMEZONE });
};

export const formatRelative = (date) => {
  if (!date) return '—';
  const d = date instanceof Date ? date : new Date(date);
  if (isNaN(d.getTime())) return '—';
  const diff = Math.floor((Date.now() - d.getTime()) / 1000);
  if (diff < 60) return 'Just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
};

