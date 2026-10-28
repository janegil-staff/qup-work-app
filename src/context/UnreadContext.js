// /qup-work-app/src/context/UnreadContext.js
// Unread counts for the badges:
//   unread                → messages (badge on the Messages tab)
//   notificationsUnread   → everything else (badge on the bell); chat messages are left out
//   const { unread, notificationsUnread, refreshUnread } = useUnread();
//
// Checks when you log in, when the app comes back to the foreground, and every
// 30 seconds while it's open. Call refreshUnread() after reading something so the
// badge drops straight away.
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { AppState } from 'react-native';
import { useAuth } from '@/context/AuthContext';
import { api } from '@/lib/api';

const POLL_MS = 30000;
export const BELL_EXCLUDE = 'new_message';

const UnreadContext = createContext({ unread: 0, notificationsUnread: 0, refreshUnread: () => {} });

export function UnreadProvider({ children }) {
  const { user } = useAuth();
  const userId = user?._id;
  const [unread, setUnread] = useState(0);
  const [notificationsUnread, setNotificationsUnread] = useState(0);

  const refreshUnread = useCallback(async () => {
    if (!userId) return;
    // Two small requests; one failing shouldn't hide the other
    const [messages, notifications] = await Promise.allSettled([
      api('/conversations/unread'),
      api(`/notifications/unread-count?exclude=${BELL_EXCLUDE}`),
    ]);
    if (messages.status === 'fulfilled') setUnread(messages.value.unread);
    if (notifications.status === 'fulfilled') setNotificationsUnread(notifications.value.count);
    // Offline or a hiccup: keep the last numbers, try again on the next tick
  }, [userId]);

  useEffect(() => {
    if (!userId) {
      setUnread(0);
      setNotificationsUnread(0);
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

  const value = useMemo(() => ({ unread, notificationsUnread, refreshUnread }), [unread, notificationsUnread, refreshUnread]);
  return <UnreadContext.Provider value={value}>{children}</UnreadContext.Provider>;
}

export const useUnread = () => useContext(UnreadContext);
