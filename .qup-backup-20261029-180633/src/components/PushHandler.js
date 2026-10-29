// /qup-work-app/src/components/PushHandler.js
// Lives once in the root layout. While someone is logged in it:
//   - registers the phone for push (again when the language changes, so the text matches)
//   - opens the right screen when a push is tapped, also when it started the app
//   - refreshes the badges when a push arrives while the app is open
import * as Notifications from 'expo-notifications';
import { router } from 'expo-router';
import { useEffect, useRef } from 'react';
import { useAuth } from '@/context/AuthContext';
import { useUnread } from '@/context/UnreadContext';
import { useI18n } from '@/i18n';
import { api } from '@/lib/api';
import { describeNotification } from '@/lib/notifications';
import { forgetPushToken, pushSupported, registerForPush } from '@/lib/push';

export function PushHandler() {
  const { user } = useAuth();
  const { language } = useI18n();
  const { refreshUnread } = useUnread();
  const userId = user?._id;
  const handled = useRef(new Set()); // notification ids already opened
  const refresh = useRef(refreshUnread);
  refresh.current = refreshUnread;

  useEffect(() => {
    if (!userId) {
      forgetPushToken();
      return;
    }
    registerForPush(language.code);
  }, [userId, language.code]);

  useEffect(() => {
    if (!userId || !pushSupported()) return undefined;

    function open(response) {
      const request = response?.notification?.request;
      if (!request || handled.current.has(request.identifier)) return;
      handled.current.add(request.identifier);
      const data = request.content.data ?? {};
      if (data.notificationId) api(`/notifications/${data.notificationId}/read`, { method: 'POST' }).catch(() => {});
      const { target } = describeNotification({ type: data.type, data, title: request.content.title, body: request.content.body });
      router.push(target ?? '/notifications');
      refresh.current();
    }

    // Tapped while the app was closed
    Notifications.getLastNotificationResponseAsync()
      .then(open)
      .catch(() => {});

    const tapped = Notifications.addNotificationResponseReceivedListener(open);
    const received = Notifications.addNotificationReceivedListener(() => refresh.current());
    return () => {
      tapped.remove();
      received.remove();
    };
  }, [userId]);

  return null;
}
