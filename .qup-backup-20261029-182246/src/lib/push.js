// /qup-work-app/src/lib/push.js
// Push notifications through Expo. The API sends a push for every in-app notification
// (see qup-work-api/src/utils/push.js); this file gets the phone's token to the API.
//
// Needs a development build or a store build with an EAS project id in app.json
// (extra.eas.projectId, set by `eas init`). In Expo Go, on the web and on simulators it
// quietly does nothing, and the in-app notifications work as before.
import Constants from 'expo-constants';
import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';
import { api } from '@/lib/api';

// Show notifications while the app is open too (the bell badge updates as well)
try {
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowBanner: true,
      shouldShowList: true,
      shouldPlaySound: false,
      shouldSetBadge: false,
    }),
  });
} catch {
  // Not available on this platform (web)
}

const projectId = () => Constants.expoConfig?.extra?.eas?.projectId ?? Constants.easConfig?.projectId;

export const pushSupported = () => Platform.OS !== 'web' && Boolean(projectId());

let lastSent = null; // `${token}|${locale}`, so we don't send the same thing again

// Asks for permission (the first time), then registers the token with the API.
// Returns the token, or null when push isn't possible or was declined.
export async function registerForPush(locale) {
  if (!pushSupported()) return null;
  try {
    if (Platform.OS === 'android') {
      await Notifications.setNotificationChannelAsync('default', {
        name: 'Qup Work',
        importance: Notifications.AndroidImportance.HIGH,
      });
    }
    let { status } = await Notifications.getPermissionsAsync();
    if (status !== 'granted') ({ status } = await Notifications.requestPermissionsAsync());
    if (status !== 'granted') return null;

    const { data: token } = await Notifications.getExpoPushTokenAsync({ projectId: projectId() });
    const key = `${token}|${locale}`;
    if (key !== lastSent) {
      await api('/auth/me/push-tokens', { method: 'POST', body: { token, platform: Platform.OS, locale } });
      lastSent = key;
    }
    return token;
  } catch (err) {
    // Simulator, Expo Go, no network: push is a bonus, never a blocker
    if (__DEV__) console.log('push registration skipped:', err?.message);
    return null;
  }
}

// After logout the API drops all tokens itself; this just forgets what we sent
export function forgetPushToken() {
  lastSent = null;
}
