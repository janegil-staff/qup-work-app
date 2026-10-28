// /qup-work-app/src/context/TimerContext.js
// The pro's running timer, shared by the whole app (only one can run at a time).
//   const { running, start, stop, discard, refreshTimer } = useTimer();
//   running → { _id, startedAt, contract: { _id, title } } or null
//
// The timer lives on the server, so it keeps going when the app is closed.
// We check it when you log in and whenever the app comes back to the foreground.
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { AppState } from 'react-native';
import { useAuth } from '@/context/AuthContext';
import { api, ApiError } from '@/lib/api';

const TimerContext = createContext({
  running: null,
  refreshTimer: async () => {},
  start: async () => {},
  stop: async () => {},
  discard: async () => {},
});

export function TimerProvider({ children }) {
  const { user, isPro } = useAuth();
  const userId = user?._id;
  const [running, setRunning] = useState(null);

  const refreshTimer = useCallback(async () => {
    if (!userId || !isPro) {
      setRunning(null);
      return;
    }
    try {
      const res = await api('/time-entries/running');
      setRunning(res.entry);
    } catch {
      // Offline: keep what we had
    }
  }, [userId, isPro]);

  useEffect(() => {
    refreshTimer();
    const sub = AppState.addEventListener('change', (state) => state === 'active' && refreshTimer());
    return () => sub.remove();
  }, [refreshTimer]);

  const start = useCallback(
    async (contractId, milestoneId) => {
      try {
        await api('/time-entries/start', { method: 'POST', body: { contract: contractId, milestone: milestoneId } });
      } catch (err) {
        // Started on another phone meanwhile: show that one instead of an error
        if (!(err instanceof ApiError && err.status === 409)) throw err;
      }
      await refreshTimer();
    },
    [refreshTimer]
  );

  const stop = useCallback(
    async ({ breakMinutes, note } = {}) => {
      const res = await api('/time-entries/stop', { method: 'POST', body: { breakMinutes, note } });
      setRunning(null);
      return res.entry;
    },
    []
  );

  // Throw away a timer started by mistake
  const discard = useCallback(async () => {
    if (!running) return;
    await api(`/time-entries/${running._id}`, { method: 'DELETE' });
    setRunning(null);
  }, [running]);

  const value = useMemo(() => ({ running, refreshTimer, start, stop, discard }), [running, refreshTimer, start, stop, discard]);
  return <TimerContext.Provider value={value}>{children}</TimerContext.Provider>;
}

export const useTimer = () => useContext(TimerContext);

// Seconds since a date, updated every second while `active`
export function useElapsed(startedAt, active = true) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    if (!startedAt || !active) return undefined;
    setNow(Date.now());
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, [startedAt, active]);
  return startedAt ? Math.max(0, Math.floor((now - new Date(startedAt).getTime()) / 1000)) : 0;
}

// 3725 → "1:02:05"
export function formatClock(seconds) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}
