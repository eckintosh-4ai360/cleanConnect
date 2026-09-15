// timezone.js — Centralized date & time formatting for CleanConnect
// CleanConnect operates in Ghana (GMT / UTC+0, Africa/Accra).
// Explicitly specifying the timezone ensures that all dates and times
// are rendered in Ghana local time regardless of the administrator's
// machine timezone, browser profile, or VPN settings.

import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from './supabase';

export const APP_TIMEZONE = 'Africa/Accra';

// ── Server-corrected clock ──────────────────────────────────────────────────
// The taskbar can show the right time while the computer's clock is hours off:
// a PC left on a foreign time zone (say US Pacific) with its clock hand-set to
// Ghana time is 7 hours ahead in absolute terms. Timestamps from the database
// are correct, so every "x ago" computed from Date.now() came out 7 hours too
// old. Measure the difference against the Supabase server once and apply it
// everywhere the panel asks "what time is it now?".
let clockOffsetMs = 0;
const clockListeners = new Set();

/** Current time in epoch milliseconds, corrected to the server's clock. */
export const serverNow = () => Date.now() + clockOffsetMs;

/** How far this computer's clock is behind (+) or ahead (-) of the server. */
export const getClockOffsetMs = () => clockOffsetMs;

export const onClockOffsetChange = (listener) => {
  clockListeners.add(listener);
  return () => clockListeners.delete(listener);
};

export async function syncServerClock() {
  try {
    const sentAt = Date.now();
    const res = await fetch(`${SUPABASE_URL}/rest/v1/pricing_plans?select=id&limit=1`, {
      headers: { apikey: SUPABASE_PUBLISHABLE_KEY },
      cache: 'no-store',
    });
    const receivedAt = Date.now();
    const serverTime = Date.parse(res.headers.get('date') || '');
    if (!Number.isFinite(serverTime)) return;

    // The Date header has one-second resolution, so compare against the
    // middle of that second and the middle of the round trip, and ignore
    // anything within a few seconds.
    const measured = serverTime + 500 - (sentAt + receivedAt) / 2;
    const next = Math.abs(measured) < 5000 ? 0 : Math.round(measured);
    if (next !== clockOffsetMs) {
      clockOffsetMs = next;
      clockListeners.forEach((listener) => listener(next));
    }
  } catch {
    // Offline or blocked: keep the last known offset.
  }
}

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
  const diff = Math.floor((serverNow() - d.getTime()) / 1000);
  if (diff < 60) return 'Just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
};

