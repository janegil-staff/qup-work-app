// /qup-work-app/src/context/UnreadContext.js
// Total unread messages, for the badge on the Messages tab.
//   const { unread, refreshUnread } = useUnread();
//
// Checks when you log in, when the app comes back to the foreground, and every
// 30 seconds while it's open. Call refreshUnread() after reading a conversation
// so the badge drops straight away.
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { AppState } from 'react-native';
import { useAuth } from '@/context/AuthContext';
import { api } from '@/lib/api';

const POLL_MS = 30000;
const UnreadContext = createContext({ unread: 0, refreshUnread: () => {} });

export function UnreadProvider({ children }) {
  const { user } = useAuth();
  const userId = user?._id;
  const [unread, setUnread] = useState(0);

  const refreshUnread = useCallback(async () => {
    if (!userId) return;
    try {
      const res = await api('/conversations/unread');
      setUnread(res.unread);
    } catch {
      // Offline or a hiccup: keep the last number, try again on the next tick
    }
  }, [userId]);

  useEffect(() => {
    if (!userId) {
      setUnread(0);
      return undefined;
    }
    refreshUnread();
    let timer = setInterval(refreshUnread, POLL_MS);

    // Don't poll in the background; check right away when the user comes back
    const sub = AppState.addEventListener('change', (state) => {
      clearInterval(timer);
      if (state === 'active') {
        refreshUnread();
        timer = setInterval(refreshUnread, POLL_MS);
      }
    });
    return () => {
      clearInterval(timer);
      sub.remove();
    };
  }, [userId, refreshUnread]);

  const value = useMemo(() => ({ unread, refreshUnread }), [unread, refreshUnread]);
  return <UnreadContext.Provider value={value}>{children}</UnreadContext.Provider>;
}

export const useUnread = () => useContext(UnreadContext);
