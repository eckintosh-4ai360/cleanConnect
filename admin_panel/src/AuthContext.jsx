import React, { createContext, useContext, useEffect, useState } from 'react';
import { supabase } from './supabase';
import { isBackOfficeRole, roleLabel } from './roles';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null);
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  const [authError, setAuthError] = useState(null);

  useEffect(() => {
    let cancelled = false;

    const loadProfile = async (currentSession) => {
      if (!currentSession?.user) {
        if (!cancelled) {
          setProfile(null);
          setLoading(false);
        }
        return;
      }

      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', currentSession.user.id)
        .single();

      if (cancelled) return;

      // Every back-office role signs in here, not just 'admin'; which pages
      // they then see is decided by roles.js. A deactivated account is turned
      // away at the door — is_admin() would refuse its queries anyway, so
      // letting it in would just render an empty, confusing panel.
      if (error || !data || !isBackOfficeRole(data.role)) {
        await supabase.auth.signOut();
        setAuthError('This account does not have admin panel access.');
        setProfile(null);
        setLoading(false);
        return;
      }

      if (data.status !== 'active') {
        await supabase.auth.signOut();
        setAuthError(`This ${roleLabel(data.role)} account has been deactivated. Contact an administrator.`);
        setProfile(null);
        setLoading(false);
        return;
      }

      setProfile(data);
      setLoading(false);
    };

    supabase.auth.getSession().then(({ data: { session: initialSession } }) => {
      if (cancelled) return;
      setSession(initialSession);
      loadProfile(initialSession);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, newSession) => {
      if (cancelled) return;
      setSession(newSession);
      setLoading(true);
      loadProfile(newSession);
    });

    return () => {
      cancelled = true;
      subscription.unsubscribe();
    };
  }, []);

  const signIn = async (email, password) => {
    setAuthError(null);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) {
      setAuthError(error.message);
      throw error;
    }
  };

  const signOut = () => supabase.auth.signOut();

  // Lets pages that edit the admin's own profile (Settings) pull the fresh
  // row immediately, instead of waiting for the next sign-in to see it.
  const refreshProfile = async () => {
    if (!session?.user) return;
    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', session.user.id)
      .single();
    if (!error && data) setProfile(data);
  };

  return (
    <AuthContext.Provider
      value={{ session, profile, loading, authError, signIn, signOut, setAuthError, refreshProfile }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
