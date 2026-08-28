import React, { useState, useEffect, useCallback } from 'react';
import { supabase } from '../supabase';
import { useAuth } from '../AuthContext';
import { BACK_OFFICE_ROLES, roleLabel, roleColor, tabsForRole } from '../roles';

const ROLE_VALUES = BACK_OFFICE_ROLES.map((r) => r.value);

export default function UserManagement() {
  const { profile } = useAuth();
  const [users, setUsers] = useState([]);
  const [selectedId, setSelectedId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [formRole, setFormRole] = useState('staff');
  const [formError, setFormError] = useState(null);
  const [banner, setBanner] = useState(null);
  const [editingUser, setEditingUser] = useState(null);
  const [confirmDelete, setConfirmDelete] = useState(null);

  const mapUserRow = (r) => ({
    id: r.id,
    fullName: r.full_name || 'Panel User',
    email: r.email || '—',
    phoneNumber: r.phone_number || '—',
    photoUrl: r.profile_picture_url,
    role: r.role,
    status: r.status || 'active',
    createdAt: r.created_at ? new Date(r.created_at) : null,
  });

  // profiles is deliberately not in the supabase_realtime publication (see
  // 20260818115125_enable_realtime.sql), so unlike the other admin pages this
  // one refetches after each action instead of subscribing to changes.
  const fetchUsers = useCallback(async () => {
    const { data, error } = await supabase
      .from('profiles')
      .select('id, full_name, email, phone_number, profile_picture_url, role, status, created_at')
      .in('role', ROLE_VALUES)
      .order('created_at', { ascending: true });
    if (error) {
      console.warn('Panel users fetch:', error);
      return;
    }
    setUsers(data.map(mapUserRow));
  }, []);

  useEffect(() => {
    fetchUsers().finally(() => setLoading(false));
  }, [fetchUsers]);

  const selectedUser = users.find((u) => u.id === selectedId) || null;
  const isSelf = selectedUser?.id === profile?.id;

  const flash = (message, tone = 'success') => {
    setBanner({ message, tone });
    setTimeout(() => setBanner(null), 6000);
  };

  const handleAddUser = async (e) => {
    e.preventDefault();
    const form = new FormData(e.target);
    const role = form.get('role');
    const email = String(form.get('email')).trim();
    setFormError(null);
    setActionLoading(true);

    const { data, error } = await supabase.functions.invoke('admin-create-user', {
      body: {
        email,
        fullName: String(form.get('name')).trim(),
        phoneNumber: String(form.get('phone') || '').trim() || null,
        role,
        // Only the browser knows where the panel is hosted; without this the
        // invite link falls back to the project's Site URL.
        redirectTo: window.location.origin,
      },
    });

    // functions.invoke() collapses any 4xx into a generic FunctionsHttpError,
    // so the reason that actually helps ("Only an admin can…", "email already
    // registered") is only readable off the error's response body.
    if (error) {
      let message = error.message;
      try {
        const body = await error.context?.json?.();
        if (body?.error) message = body.error;
      } catch {
        /* keep the generic message */
      }
      setFormError(message);
    } else if (data?.error) {
      setFormError(data.error);
    } else {
      setShowAddModal(false);
      // handle_new_user() writes the profiles row from the auth trigger, so the
      // response returning is our cue that it exists.
      await fetchUsers();
      flash(
        data?.inviteSent === false
          ? `${roleLabel(role)} account created, but the password-setup email could not be sent. Use "Resend setup email" to try again.`
          : `${roleLabel(role)} account created — a password-setup email has been sent to ${email}.`,
        data?.inviteSent === false ? 'danger' : 'success'
      );
    }
    setActionLoading(false);
  };

  const handleChangeRole = async (user, role) => {
    if (role === user.role) return;
    setActionLoading(true);
    const { error } = await supabase.from('profiles').update({ role }).eq('id', user.id);
    if (error) {
      flash('Failed to change role: ' + error.message, 'danger');
    } else {
      await fetchUsers();
      flash(`${user.fullName} is now ${roleLabel(role)}.`);
    }
    setActionLoading(false);
  };

  const handleSetStatus = async (user, status) => {
    if (status === user.status) return;
    setActionLoading(true);
    const { error } = await supabase.from('profiles').update({ status }).eq('id', user.id);
    if (error) {
      flash('Failed to update status: ' + error.message, 'danger');
    } else {
      await fetchUsers();
      flash(`${user.fullName} was ${status === 'active' ? 'reactivated' : 'deactivated'}.`);
    }
    setActionLoading(false);
  };

  const handleSaveEdit = async (e) => {
    e.preventDefault();
    const form = new FormData(e.target);
    setActionLoading(true);
    const { error } = await supabase
      .from('profiles')
      .update({
        full_name: String(form.get('name')).trim(),
        phone_number: String(form.get('phone') || '').trim() || null,
      })
      .eq('id', editingUser.id);
    if (error) {
      flash('Failed to save changes: ' + error.message, 'danger');
    } else {
      setEditingUser(null);
      await fetchUsers();
      flash('Details updated.');
    }
    setActionLoading(false);
  };

  const handleResendInvite = async (user) => {
    setActionLoading(true);
    const { error } = await supabase.auth.resetPasswordForEmail(user.email, {
      redirectTo: window.location.origin,
    });
    if (error) flash('Could not send the email: ' + error.message, 'danger');
    else flash(`Password-setup email sent to ${user.email}.`);
    setActionLoading(false);
  };

  const handleDelete = async (user) => {
    setActionLoading(true);
    const { data, error } = await supabase.functions.invoke('admin-delete-user', {
      body: { userId: user.id },
    });

    let message = null;
    if (error) {
      message = error.message;
      try {
        const body = await error.context?.json?.();
        if (body?.error) message = body.error;
      } catch {
        /* keep the generic message */
      }
    } else if (data?.error) {
      message = data.error;
    }

    if (message) {
      flash('Failed to delete: ' + message, 'danger');
    } else {
      setConfirmDelete(null);
      if (selectedId === user.id) setSelectedId(null);
      await fetchUsers();
      flash(`${user.fullName} was deleted.`);
    }
    setActionLoading(false);
  };

  const activeCount = users.filter((u) => u.status === 'active').length;
  const activeAdmins = users.filter((u) => u.role === 'admin' && u.status === 'active').length;

  return (
    <div className="page-content">
      {/* ── Page Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>Panel Users &amp; Roles</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Create back-office accounts — administrators, financial secretaries, supervisors, staff and support agents.
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
            {activeCount} / {users.length} Active
          </span>
          <button
            className="btn-primary"
            onClick={() => { setFormRole('staff'); setFormError(null); setShowAddModal(true); }}
          >
            + Create New User
          </button>
        </div>
      </div>

      {banner && (
        <div
          style={{
            padding: '12px 16px',
            borderRadius: '10px',
            fontSize: '12px',
            fontWeight: '700',
            background: banner.tone === 'danger' ? 'rgba(239,68,68,0.12)' : 'rgba(16,185,129,0.12)',
            color: banner.tone === 'danger' ? 'var(--color-danger)' : 'var(--color-success)',
            border: '1px solid',
            borderColor: banner.tone === 'danger' ? 'var(--color-danger)' : 'var(--color-success)',
          }}
        >
          {banner.message}
        </div>
      )}

      {/* ── Main Split View ── */}
      <div className="split-layout">
        {/* Left: Panel User Roster */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <h3 style={{ fontSize: '16px' }}>Back-Office Roster</h3>
          <div className="table-container">
            <table className="custom-table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Email</th>
                  <th>Role</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr><td colSpan="4" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>Loading users...</td></tr>
                ) : users.length === 0 ? (
                  <tr><td colSpan="4" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>No panel users yet.</td></tr>
                ) : (
                  users.map((u) => (
                    <tr
                      key={u.id}
                      onClick={() => setSelectedId(u.id)}
                      style={{ cursor: 'pointer', background: selectedId === u.id ? 'var(--border-divider)' : 'transparent' }}
                    >
                      <td style={{ fontWeight: '700' }}>
                        {u.fullName}
                        {u.id === profile?.id && (
                          <span style={{ fontSize: '10px', color: 'var(--text-muted)', fontWeight: '600' }}> (you)</span>
                        )}
                      </td>
                      <td style={{ fontSize: '12px', wordBreak: 'break-all' }}>{u.email}</td>
                      <td>
                        <span className="badge" style={{ background: `${roleColor(u.role)}22`, color: roleColor(u.role) }}>
                          {roleLabel(u.role)}
                        </span>
                      </td>
                      <td>
                        <span className={`badge ${u.status === 'active' ? 'badge-active' : 'badge-defaulter'}`}>
                          {u.status === 'active' ? 'Active' : 'Deactivated'}
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Right: Selected User Controls, or the role reference */}
        <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          {selectedUser ? (
            <>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <img
                  src={selectedUser.photoUrl || `https://api.dicebear.com/7.x/initials/svg?seed=${selectedUser.fullName}`}
                  alt={selectedUser.fullName}
                  style={{ width: '48px', height: '48px', borderRadius: '50%', objectFit: 'cover', border: `2px solid ${roleColor(selectedUser.role)}` }}
                />
                <div style={{ minWidth: 0 }}>
                  <h4 style={{ fontSize: '14px', fontWeight: '800' }}>{selectedUser.fullName}</h4>
                  <p style={{ fontSize: '11px', color: 'var(--text-secondary)', wordBreak: 'break-all' }}>{selectedUser.email}</p>
                </div>
              </div>

              <div style={{ padding: '16px', background: 'var(--bg-app)', borderRadius: '8px', display: 'flex', flexDirection: 'column', gap: '12px', fontSize: '12px' }}>
                {[
                  { label: 'Phone Number', value: selectedUser.phoneNumber },
                  { label: 'Role', value: roleLabel(selectedUser.role) },
                  { label: 'Added On', value: selectedUser.createdAt ? selectedUser.createdAt.toLocaleDateString() : '—' },
                ].map(({ label, value }) => (
                  <div key={label} style={{ display: 'flex', justifyContent: 'space-between', gap: '12px', borderBottom: '1px solid var(--border-divider)', paddingBottom: '6px' }}>
                    <span style={{ fontWeight: 'bold' }}>{label}:</span>
                    <span style={{ textAlign: 'right', wordBreak: 'break-word' }}>{value}</span>
                  </div>
                ))}
                <div>
                  <span style={{ fontWeight: 'bold' }}>Pages this role sees:</span>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: '4px', marginTop: '6px' }}>
                    {tabsForRole(selectedUser.role).map((t) => (
                      <span
                        key={t}
                        style={{ fontSize: '10px', padding: '2px 7px', borderRadius: '10px', background: 'var(--border-divider)', color: 'var(--text-secondary)', fontWeight: '700' }}
                      >
                        {t}
                      </span>
                    ))}
                  </div>
                </div>
              </div>

              {/* ── Role Control ── */}
              <div style={{ background: 'var(--bg-sidebar)', borderRadius: '10px', padding: '12px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                <span style={{ fontSize: '10px', textTransform: 'uppercase', fontWeight: '800', color: 'var(--text-muted)', letterSpacing: '0.5px' }}>Change Role</span>
                <select
                  value={selectedUser.role}
                  disabled={isSelf || actionLoading}
                  onChange={(e) => handleChangeRole(selectedUser, e.target.value)}
                  style={{
                    padding: '8px 10px', borderRadius: '8px', fontSize: '12px', fontWeight: '700',
                    border: '1px solid var(--border-divider)', background: 'var(--bg-app)',
                    color: 'var(--text-primary)', cursor: isSelf ? 'not-allowed' : 'pointer',
                  }}
                >
                  {BACK_OFFICE_ROLES.map((r) => (
                    <option key={r.value} value={r.value}>{r.label}</option>
                  ))}
                </select>
                {isSelf && (
                  <span style={{ fontSize: '10px', color: 'var(--text-muted)' }}>
                    You cannot change your own role or status — ask another administrator.
                  </span>
                )}
              </div>

              {/* ── Status Control ── */}
              <div style={{ background: 'var(--bg-sidebar)', borderRadius: '10px', padding: '12px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                <span style={{ fontSize: '10px', textTransform: 'uppercase', fontWeight: '800', color: 'var(--text-muted)', letterSpacing: '0.5px' }}>Account Access</span>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '6px' }}>
                  {[
                    { value: 'active', label: '✓ Active', color: 'var(--color-success)', tint: 'rgba(16,185,129,0.12)' },
                    { value: 'disabled', label: '✕ Deactivated', color: 'var(--color-danger)', tint: 'rgba(239,68,68,0.12)' },
                  ].map((opt) => {
                    const on = selectedUser.status === opt.value;
                    // Deactivating the last active admin would leave nobody who
                    // can create panel users or undo the change.
                    const lastAdmin = opt.value === 'disabled' && selectedUser.role === 'admin' && activeAdmins <= 1;
                    const blocked = isSelf || actionLoading || lastAdmin;
                    return (
                      <button
                        key={opt.value}
                        onClick={() => handleSetStatus(selectedUser, opt.value)}
                        disabled={blocked}
                        title={lastAdmin ? 'This is the only active administrator.' : undefined}
                        style={{
                          padding: '8px 0', borderRadius: '8px', border: '2px solid',
                          borderColor: on ? opt.color : 'var(--border-divider)',
                          background: on ? opt.tint : 'transparent',
                          color: on ? opt.color : 'var(--text-secondary)',
                          fontWeight: '800', fontSize: '12px',
                          cursor: blocked ? 'not-allowed' : 'pointer',
                          opacity: blocked && !on ? 0.5 : 1,
                          transition: 'all 0.2s',
                        }}
                      >
                        {opt.label}
                      </button>
                    );
                  })}
                </div>
                <span style={{ fontSize: '10px', color: 'var(--text-muted)' }}>
                  A deactivated user keeps their account but is refused at the panel login.
                </span>
              </div>

              {/* ── Account Actions ── */}
              <div style={{ background: 'var(--bg-sidebar)', borderRadius: '10px', padding: '12px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                <span style={{ fontSize: '10px', textTransform: 'uppercase', fontWeight: '800', color: 'var(--text-muted)', letterSpacing: '0.5px' }}>Manage Account</span>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(120px, 1fr))', gap: '6px' }}>
                  <button
                    className="btn-outline"
                    style={{ padding: '8px 10px', fontSize: '12px' }}
                    disabled={actionLoading}
                    onClick={() => setEditingUser(selectedUser)}
                  >
                    Edit Details
                  </button>
                  <button
                    className="btn-outline"
                    style={{ padding: '8px 10px', fontSize: '12px' }}
                    disabled={actionLoading}
                    onClick={() => handleResendInvite(selectedUser)}
                    title="Emails them a fresh link for choosing a password"
                  >
                    Resend Setup Email
                  </button>
                </div>
                <button
                  className="btn-danger"
                  style={{ padding: '8px 10px', fontSize: '12px', opacity: isSelf ? 0.5 : 1 }}
                  disabled={isSelf || actionLoading}
                  onClick={() => setConfirmDelete(selectedUser)}
                  title={isSelf ? 'You cannot delete your own account.' : undefined}
                >
                  Delete User
                </button>
                <span style={{ fontSize: '10px', color: 'var(--text-muted)' }}>
                  Deleting removes the account for good. To revoke access temporarily,
                  deactivate instead.
                </span>
              </div>
            </>
          ) : (
            <>
              <div>
                <h3 style={{ fontSize: '16px' }}>What Each Role Can Do</h3>
                <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                  Select a user on the left to change their role or revoke access.
                </p>
              </div>
              {BACK_OFFICE_ROLES.map((r) => (
                <div key={r.value} style={{ padding: '12px', background: 'var(--bg-app)', borderRadius: '8px', borderLeft: `3px solid ${r.color}` }}>
                  <h4 style={{ fontSize: '13px', fontWeight: '800', color: r.color }}>{r.label}</h4>
                  <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '4px', lineHeight: '1.5' }}>{r.description}</p>
                </div>
              ))}
            </>
          )}
        </div>
      </div>

      {/* ── Edit Details Modal ── */}
      {editingUser && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>Edit {editingUser.fullName}</h3>
            <form onSubmit={handleSaveEdit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div className="form-group">
                <label>Full Name</label>
                <input name="name" type="text" defaultValue={editingUser.fullName} required />
              </div>
              <div className="form-group">
                <label>Mobile Number</label>
                <input
                  name="phone"
                  type="text"
                  defaultValue={editingUser.phoneNumber === '—' ? '' : editingUser.phoneNumber}
                />
              </div>
              <p style={{ fontSize: '11px', color: 'var(--text-muted)', lineHeight: '1.5' }}>
                Role and account access are changed from the panel behind this dialog.
                Email cannot be changed here — delete the account and create it again
                under the right address.
              </p>
              <div className="modal-actions">
                <button type="button" className="btn-outline" onClick={() => setEditingUser(null)}>Cancel</button>
                <button type="submit" className="btn-primary" disabled={actionLoading}>
                  {actionLoading ? 'Saving...' : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── Delete Confirmation ── */}
      {confirmDelete && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>Delete {confirmDelete.fullName}?</h3>
            <p style={{ fontSize: '13px', color: 'var(--text-secondary)', lineHeight: '1.6' }}>
              This permanently removes the account for <strong>{confirmDelete.email}</strong>.
              They lose panel access immediately and cannot be restored — you would have to
              create them again from scratch.
            </p>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)', lineHeight: '1.6' }}>
              If you only want to revoke access for now, cancel and use Deactivated instead.
            </p>
            <div className="modal-actions">
              <button type="button" className="btn-outline" onClick={() => setConfirmDelete(null)}>Cancel</button>
              <button
                type="button"
                className="btn-danger"
                disabled={actionLoading}
                onClick={() => handleDelete(confirmDelete)}
              >
                {actionLoading ? 'Deleting...' : 'Delete Permanently'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Create User Modal ── */}
      {showAddModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ fontSize: '18px' }}>Create New Panel User</h3>
            <form onSubmit={handleAddUser} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div className="form-group">
                <label>Full Name</label>
                <input name="name" type="text" placeholder="e.g. Ama Mensah" required />
              </div>
              <div className="form-group">
                <label>Email Address</label>
                <input name="email" type="email" placeholder="e.g. ama@cleanconnect.com" required />
              </div>
              <div className="form-group">
                <label>Mobile Number</label>
                <input name="phone" type="text" placeholder="e.g. 0244000000" />
              </div>
              <div className="form-group">
                <label>Role</label>
                <select name="role" value={formRole} onChange={(e) => setFormRole(e.target.value)}>
                  {BACK_OFFICE_ROLES.map((r) => (
                    <option key={r.value} value={r.value}>{r.label}</option>
                  ))}
                </select>
                <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '6px', lineHeight: '1.5' }}>
                  {BACK_OFFICE_ROLES.find((r) => r.value === formRole)?.description}
                </p>
              </div>

              <p style={{ fontSize: '11px', color: 'var(--text-muted)', lineHeight: '1.5' }}>
                No password is set here — the new user gets an email inviting them to choose their own.
              </p>

              {formError && (
                <p style={{ fontSize: '12px', color: 'var(--color-danger)', fontWeight: '700' }}>{formError}</p>
              )}

              <div className="modal-actions">
                <button type="button" className="btn-outline" onClick={() => setShowAddModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" disabled={actionLoading}>
                  {actionLoading ? 'Creating...' : 'Create User'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
