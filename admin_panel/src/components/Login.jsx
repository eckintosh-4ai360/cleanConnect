import React, { useState } from 'react';
import { useAuth } from '../AuthContext';

export default function Login() {
  const { signIn, authError, setAuthError, sendPasswordReset } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [notice, setNotice] = useState(null);

  const handleForgotPassword = async () => {
    if (!email.trim()) {
      setAuthError('Enter your email address first, then choose "Forgot password".');
      return;
    }
    setAuthError(null);
    try {
      await sendPasswordReset(email.trim());
      setNotice(`We've emailed a link to ${email.trim()} for setting a new password.`);
    } catch (e) {
      setAuthError(e.message);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await signIn(email, password);
    } catch (_) {
      // authError is already set inside signIn
    }
    setSubmitting(false);
  };

  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'var(--bg-app)',
      }}
    >
      <div
        className="card-glass"
        style={{ width: '360px', display: 'flex', flexDirection: 'column', gap: '24px', padding: '36px' }}
      >
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '10px' }}>
          <img
            src="/app-icon.png"
            alt="CleanConnect"
            width="48"
            height="48"
            style={{ borderRadius: '12px', display: 'block' }}
          />
          <h2 style={{ fontSize: '20px' }}>CleanConnect Admin</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', textAlign: 'center' }}>
            Sign in to manage operations.
          </p>
        </div>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <div className="form-group">
            <label>Email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => {
                setEmail(e.target.value);
                setNotice(null);
                if (authError) setAuthError(null);
              }}
              required
              autoFocus
            />
          </div>
          <div className="form-group">
            <label>Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                if (authError) setAuthError(null);
              }}
              required
            />
          </div>

          {authError && (
            <p style={{ color: 'var(--color-danger)', fontSize: '12px', margin: 0 }}>{authError}</p>
          )}
          {notice && (
            <p style={{ color: 'var(--color-success)', fontSize: '12px', margin: 0 }}>{notice}</p>
          )}

          <button type="submit" className="btn-primary" disabled={submitting} style={{ width: '100%' }}>
            {submitting ? 'Signing in…' : 'Sign In'}
          </button>

          <button
            type="button"
            onClick={handleForgotPassword}
            style={{
              background: 'transparent',
              border: 'none',
              color: 'var(--color-primary)',
              fontSize: '12px',
              fontWeight: '700',
              cursor: 'pointer',
              padding: 0,
            }}
          >
            Forgot password?
          </button>
        </form>
      </div>
    </div>
  );
}
