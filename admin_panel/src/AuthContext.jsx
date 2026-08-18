import React, { createContext, useContext, useEffect, useState } from 'react';
import { supabase } from './supabase';

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

      if (error || !data || data.role !== 'admin') {
        await supabase.auth.signOut();
        setAuthError('This account does not have admin access.');
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

  return (
    <AuthContext.Provider
      value={{ session, profile, loading, authError, signIn, signOut, setAuthError }}
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
