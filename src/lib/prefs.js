// /qup-work-app/src/lib/prefs.js
// Small device settings (like the chosen language). SecureStore on phones,
// localStorage on web. Never throws: a failed read just means "not set".
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';

const isWeb = Platform.OS === 'web';

export const prefs = {
  async get(key) {
    try {
      return isWeb ? (globalThis.localStorage?.getItem(key) ?? null) : await SecureStore.getItemAsync(key);
    } catch {
      return null;
    }
  },

  async set(key, value) {
    try {
      if (isWeb) globalThis.localStorage?.setItem(key, value);
      else await SecureStore.setItemAsync(key, value);
    } catch {
      // not critical: the choice just won't survive a restart
    }
  },
};
