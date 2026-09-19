// notificationRouting.js — which sidebar page owns each admin notification.
//
// One table drives two things that used to disagree: where a click in the
// notification drawer lands, and the unread badge a sidebar page carries.
// The `type` values are the ones written by the database triggers and RPCs in
// supabase/migrations (grep `insert into public.admin_notifications`), by
// supabase/functions/admin-delete-user, and by the app's support-ticket flow.
//
// A type that is missing here is not an error: it still counts towards the
// bell, it just has no page of its own to badge.
export const TAB_BY_NOTIF_TYPE = {
  customer_registered: 'Customers',
  bin_registered: 'Bins',
  bin_requested: 'Bins',
  rider_registered: 'Riders',
  pickup_requested: 'Pickups',
  pickup_accepted: 'Pickups',
  pickup_cancelled: 'Pickups',
  pickup_released: 'Pickups',
  pickup_completed: 'Collections',
  incident_reported: 'Waste Reports',
  support_ticket: 'Settings',
  payment: 'Payments',
  pricing_updated: 'Payments',
  staff_registered: 'Users',
  staff_removed: 'Users',
};

/** The sidebar page a notification belongs to, or null if it has no page. */
export function tabForNotifType(type) {
  return TAB_BY_NOTIF_TYPE[type] ?? null;
}

/** { 'Pickups': 3, 'Bins': 1, … } — unread only, pages with none left out. */
export function unreadCountsByTab(notifications) {
  const counts = {};
  for (const n of notifications) {
    if (n.isRead) continue;
    const tab = TAB_BY_NOTIF_TYPE[n.type];
    if (!tab) continue;
    counts[tab] = (counts[tab] ?? 0) + 1;
  }
  return counts;
}

/** Badge text. Caps the width of the pill without hiding that there are more. */
export function formatBadgeCount(count) {
  return count > 99 ? '99+' : String(count);
}
