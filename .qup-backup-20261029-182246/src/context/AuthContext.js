// /qup-work-app/src/context/AuthContext.js
// Holds the logged-in user for the whole app.
//   const { user, login, logout } = useAuth();
//
// useAuth() gives you:
//   session        { user, companies, proProfile } from GET /auth/me, or null
//   user           session.user, or null when logged out
//   isLoading      true while we check for a saved login on app start
//   isPro          the user has the pro role
//   login(email, password), register(name, email, password), logout()
//   refreshSession()   reload /auth/me (e.g. after creating a company)
//   setActiveRole('customer' | 'pro')
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { api, ApiError, setOnSessionExpired } from '@/lib/api';
import { tokenStore } from '@/lib/tokenStore';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null);
  const [isLoading, setIsLoading] = useState(true);

  const refreshSession = useCallback(async () => {
    const data = await api('/auth/me');
    setSession(data);
  }, []);

  // On app start: if we have a saved login, load the user
  useEffect(() => {
    setOnSessionExpired(() => setSession(null));

    (async () => {
      try {
        if (await tokenStore.getRefresh()) await refreshSession();
      } catch (err) {
        if (err instanceof ApiError && err.status === 401) await tokenStore.clear();
        // Offline (status 0): the user sees the login screen, tokens are kept for next start
      } finally {
        setIsLoading(false);
      }
    })();

    return () => setOnSessionExpired(null);
  }, [refreshSession]);

  const startSession = useCallback(
    async (data) => {
      await tokenStore.set(data.accessToken, data.refreshToken);
      await refreshSession();
    },
    [refreshSession]
  );

  const login = useCallback(
    async (email, password) => {
      const data = await api('/auth/login', {
        method: 'POST',
        body: { email: email.trim(), password },
        auth: false,
      });
      await startSession(data);
    },
    [startSession]
  );

  const register = useCallback(
    async (name, email, password) => {
      const data = await api('/auth/register', {
        method: 'POST',
        body: { name: name.trim(), email: email.trim(), password },
        auth: false,
      });
      await startSession(data);
    },
    [startSession]
  );

  const logout = useCallback(async () => {
    try {
      await api('/auth/logout', { method: 'POST' });
    } catch {
      // Even if the server can't be reached, log out locally
    }
    await tokenStore.clear();
    setSession(null);
  }, []);

  const setActiveRole = useCallback(
    async (role) => {
      await api('/auth/me', { method: 'PATCH', body: { activeRole: role } });
      await refreshSession();
    },
    [refreshSession]
  );

  const value = useMemo(
    () => ({
      session,
      user: session?.user ?? null,
      isLoading,
      isPro: session?.user.roles.includes('pro') ?? false,
      login,
      register,
      logout,
      refreshSession,
      setActiveRole,
    }),
    [session, isLoading, login, register, logout, refreshSession, setActiveRole]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside <AuthProvider>');
  return ctx;
}
