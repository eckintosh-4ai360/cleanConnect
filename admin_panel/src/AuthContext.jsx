import React, { createContext, useContext, useEffect, useRef, useState } from 'react';
import { supabase } from './supabase';
import { isBackOfficeRole, roleLabel } from './roles';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null);
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  const [authError, setAuthError] = useState(null);
  // True while the signed-in session came from a password-reset link. Supabase
  // signs the link's holder straight in, so without this the panel would drop
  // an invited user onto the dashboard having never set a password — and they
  // would need a fresh emailed link every time they wanted back in.
  const [needsPasswordSetup, setNeedsPasswordSetup] = useState(
    () => typeof window !== 'undefined' && window.location.hash.includes('type=recovery')
  );

  // Which user the profile in state belongs to. supabase-js re-emits auth
  // events for the same user constantly — TOKEN_REFRESHED on its refresh timer,
  // and SIGNED_IN again every time the tab regains focus — and reloading the
  // profile on those is what made the panel look like it kept refreshing
  // itself. See the listener below.
  const loadedUserId = useRef(null);

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

    // Same access checks as loadProfile, but it never touches `loading` and
    // only writes state when the row actually differs — so a background check
    // cannot blank the screen or needlessly re-render the panel.
    const revalidateProfile = async (currentSession) => {
      if (!currentSession?.user) return;

      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', currentSession.user.id)
        .single();

      if (cancelled || error || !data) return;

      if (!isBackOfficeRole(data.role) || data.status !== 'active') {
        // signOut fires SIGNED_OUT, which the listener below treats as a real
        // user change and routes back to Login.
        setAuthError(
          !isBackOfficeRole(data.role)
            ? 'This account no longer has admin panel access.'
            : `This ${roleLabel(data.role)} account has been deactivated. Contact an administrator.`
        );
        await supabase.auth.signOut();
        return;
      }

      setProfile((prev) =>
        JSON.stringify(prev) === JSON.stringify(data) ? prev : data
      );
    };

    supabase.auth.getSession().then(({ data: { session: initialSession } }) => {
      if (cancelled) return;
      loadedUserId.current = initialSession?.user?.id ?? null;
      setSession(initialSession);
      loadProfile(initialSession);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, newSession) => {
      if (cancelled) return;

      if (event === 'PASSWORD_RECOVERY') setNeedsPasswordSetup(true);
      if (event === 'SIGNED_OUT') setNeedsPasswordSetup(false);

      // Always keep the freshest access token in context.
      setSession(newSession);

      const nextUserId = newSession?.user?.id ?? null;

      // A token refresh or a tab-focus re-emit carries the same user we already
      // loaded. Re-running loadProfile there flipped `loading` back to true,
      // and App renders a bare "Loading…" while that is set — which unmounts
      // AdminShell and every page under it, then rebuilds them once the profiles
      // query returns. That is the "page keeps refreshing itself": open modals,
      // scroll position, search text and the realtime notification channel were
      // all being thrown away and recreated on every alt-tab back to the panel.
      // The account could still have been deactivated or demoted since the last
      // check, so re-read it — just silently, leaving `loading` alone so the
      // shell stays mounted.
      if (nextUserId === loadedUserId.current) {
        revalidateProfile(newSession);
        return;
      }

      // A genuinely different user (or a sign-out): this one does need the full
      // gated reload.
      loadedUserId.current = nextUserId;
      setLoading(true);
      loadProfile(newSession);
    });

    return () => {
      cancelled = true;
      subscription.unsubscribe();
    };
  }, []);

  // Called once the recovery-session user has actually chosen a password.
  const completePasswordSetup = () => {
    setNeedsPasswordSetup(false);
    if (typeof window !== 'undefined' && window.location.hash) {
      // Drop the recovery token so a refresh doesn't reopen this screen.
      window.history.replaceState(null, '', window.location.pathname + window.location.search);
    }
  };

  const sendPasswordReset = async (email) => {
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: window.location.origin,
    });
    if (error) throw error;
  };

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
      value={{
        session,
        profile,
        loading,
        authError,
        signIn,
        signOut,
        setAuthError,
        refreshProfile,
        needsPasswordSetup,
        completePasswordSetup,
        sendPasswordReset,
      }}
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
