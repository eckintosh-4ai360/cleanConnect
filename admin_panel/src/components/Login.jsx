import React, { useState } from 'react';
import { useAuth } from '../AuthContext';

export default function Login() {
  const { signIn, authError, setAuthError } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);

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
          <div className="sidebar-logo" style={{ width: '48px', height: '48px', fontSize: '20px' }}>
            CC
          </div>
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

          <button type="submit" className="btn-primary" disabled={submitting} style={{ width: '100%' }}>
            {submitting ? 'Signing in…' : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  );
}
