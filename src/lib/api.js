// /qup-work-app/src/lib/api.js
// One function for every API call:
//   const { data } = await api('/jobs');
//   await api('/jobs', { method: 'POST', body: { title: 'Nytt bad' } });
//
// - Adds the access token automatically
// - If it has expired (401), refreshes it once and retries the request
// - Throws ApiError with the API's own message, ready to show to the user
import { translate as t } from '@/i18n';
import { tokenStore } from './tokenStore';

export const API_URL = (process.env.EXPO_PUBLIC_API_URL ?? 'http://localhost:4000/api/v1').replace(/\/$/, '');

export class ApiError extends Error {
  constructor(message, status, details) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.details = details;
  }
}

// Called when the refresh token is no longer valid → AuthContext logs the user out
let onSessionExpired = null;
export function setOnSessionExpired(handler) {
  onSessionExpired = handler;
}

// If several requests get 401 at the same time, they share one refresh call
let refreshing = null;

async function refreshAccessToken() {
  const refreshToken = await tokenStore.getRefresh();
  if (!refreshToken) return null;

  try {
    const res = await fetch(`${API_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken }),
    });
    if (!res.ok) {
      if (res.status === 401) await tokenStore.clear();
      return null;
    }
    const data = await res.json();
    await tokenStore.set(data.accessToken, data.refreshToken);
    return data.accessToken;
  } catch {
    return null; // offline: keep the tokens and try again later
  }
}

export async function api(path, options = {}) {
  const { method = 'GET', body, auth = true } = options;

  const send = (token) =>
    fetch(API_URL + path, {
      method,
      headers: {
        Accept: 'application/json',
        ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });

  const token = auth ? await tokenStore.getAccess() : null;

  let res;
  try {
    res = await send(token);
    if (res.status === 401 && auth && token) {
      refreshing ??= refreshAccessToken().finally(() => {
        refreshing = null;
      });
      const newToken = await refreshing;
      if (!newToken) {
        // Refresh token still saved → the refresh failed because we're offline
        if (await tokenStore.getRefresh()) {
          throw new ApiError(t('ERROR_OFFLINE'), 0);
        }
        onSessionExpired?.();
        throw new ApiError(t('ERROR_SESSION_EXPIRED'), 401);
      }
      res = await send(newToken);
    }
  } catch (err) {
    if (err instanceof ApiError) throw err;
    throw new ApiError(t('ERROR_OFFLINE'), 0);
  }

  if (res.status === 204) return null;

  const data = await res.json().catch(() => null);
  if (!res.ok) {
    throw new ApiError(
      data?.error?.message ?? t('ERROR_STATUS', { status: res.status }),
      res.status,
      data?.error?.details
    );
  }
  return data;
}

// Show an error to the user in a friendly way
export function errorMessage(err) {
  if (err instanceof ApiError) {
    if (err.details) return `${err.message}: ${Object.values(err.details).join(', ')}`;
    return err.message;
  }
  return t('ERROR_GENERIC');
}
