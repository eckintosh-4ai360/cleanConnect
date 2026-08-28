import React, { useState } from 'react';
import { supabase } from '../supabase';

/// Shown when the session came from a password-reset link rather than a normal
/// sign-in — the invite a newly created panel user receives, or a "forgot
/// password" request. Supabase signs the link's holder in with a recovery
/// session, which is enough to call updateUser but nothing else useful; without
/// this screen an invited user could never set a password and would have to
/// request a fresh link every single time they wanted in.
export default function SetPassword({ email, onDone }) {
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState(null);
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);

    if (password.length < 8) {
      setError('Password must be at least 8 characters.');
      return;
    }
    if (password !== confirm) {
      setError('Those passwords do not match.');
      return;
    }

    setSubmitting(true);
    const { error: updateError } = await supabase.auth.updateUser({ password });
    setSubmitting(false);

    if (updateError) {
      setError(updateError.message);
      return;
    }
    onDone();
  };

  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'var(--bg-app)',
        padding: '24px',
      }}
    >
      <div
        className="card-glass"
        style={{ width: '360px', maxWidth: '100%', display: 'flex', flexDirection: 'column', gap: '24px', padding: '36px' }}
      >
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '10px' }}>
          <div className="sidebar-logo" style={{ width: '48px', height: '48px', fontSize: '20px' }}>
            CC
          </div>
          <h2 style={{ fontSize: '20px' }}>Choose a password</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', textAlign: 'center' }}>
            {email
              ? `Set the password for ${email}, then you're in.`
              : 'Set a password for your account, then you’re in.'}
          </p>
        </div>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <div className="form-group">
            <label>New Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => { setPassword(e.target.value); if (error) setError(null); }}
              autoComplete="new-password"
              required
              autoFocus
            />
          </div>
          <div className="form-group">
            <label>Confirm Password</label>
            <input
              type="password"
              value={confirm}
              onChange={(e) => { setConfirm(e.target.value); if (error) setError(null); }}
              autoComplete="new-password"
              required
            />
          </div>

          {error && (
            <p style={{ color: 'var(--color-danger)', fontSize: '12px', margin: 0 }}>{error}</p>
          )}

          <button type="submit" className="btn-primary" disabled={submitting} style={{ width: '100%' }}>
            {submitting ? 'Saving…' : 'Save Password & Continue'}
          </button>
        </form>
      </div>
    </div>
  );
}
