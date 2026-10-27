// /qup-work-app/src/lib/tokenStore.js
// Stores the access + refresh token securely (Keychain on iOS, Keystore on Android).
// SecureStore doesn't exist on web, so the web build falls back to localStorage.
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';

const ACCESS_KEY = 'qupwork.accessToken';
const REFRESH_KEY = 'qupwork.refreshToken';
const isWeb = Platform.OS === 'web';

// Keep the access token in memory too, so we don't hit SecureStore on every request
let accessCache;

async function read(key) {
  if (isWeb) {
    try {
      return globalThis.localStorage?.getItem(key) ?? null;
    } catch {
      return null;
    }
  }
  return SecureStore.getItemAsync(key);
}

async function write(key, value) {
  if (isWeb) {
    try {
      globalThis.localStorage?.setItem(key, value);
    } catch {
      // private mode etc. — the user just has to log in again next time
    }
    return;
  }
  await SecureStore.setItemAsync(key, value);
}

async function remove(key) {
  if (isWeb) {
    try {
      globalThis.localStorage?.removeItem(key);
    } catch {
      // ignore
    }
    return;
  }
  await SecureStore.deleteItemAsync(key);
}

export const tokenStore = {
  async getAccess() {
    if (accessCache === undefined) accessCache = await read(ACCESS_KEY);
    return accessCache;
  },

  getRefresh() {
    return read(REFRESH_KEY);
  },

  async set(accessToken, refreshToken) {
    accessCache = accessToken;
    await Promise.all([write(ACCESS_KEY, accessToken), write(REFRESH_KEY, refreshToken)]);
  },

  async clear() {
    accessCache = null;
    await Promise.all([remove(ACCESS_KEY), remove(REFRESH_KEY)]);
  },
};
