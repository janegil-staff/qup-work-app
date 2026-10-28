// /qup-work-app/src/lib/upload.js
// Photos go straight from the phone to Cloudinary. The API only hands out a short-lived
// signature (POST /uploads/signature), so the Cloudinary secret never touches the app.
//
//   const asset = (await ImagePicker.launchCameraAsync()).assets[0];
//   const attachment = await uploadPhoto(asset, { purpose: 'milestone', tag: 'after' });
//   → { url, key, kind: 'image', tag, mimeType, size, name }   ready to send to the API
import { Platform } from 'react-native';
import { translate as t } from '@/i18n';
import { api, ApiError } from '@/lib/api';

export async function uploadPhoto(asset, { purpose = 'milestone', tag = 'other' } = {}) {
  const sig = await api('/uploads/signature', { method: 'POST', body: { purpose } });

  const form = new FormData();
  if (Platform.OS === 'web') {
    // The web picker gives a real File; fall back to fetching the blob URL
    form.append('file', asset.file ?? (await (await fetch(asset.uri)).blob()));
  } else {
    form.append('file', {
      uri: asset.uri,
      name: asset.fileName ?? `photo-${Date.now()}.jpg`,
      type: asset.mimeType ?? 'image/jpeg',
    });
  }
  form.append('api_key', sig.apiKey);
  form.append('timestamp', String(sig.timestamp));
  form.append('folder', sig.folder);
  form.append('signature', sig.signature);

  let res;
  try {
    res = await fetch(sig.uploadUrl, { method: 'POST', body: form });
  } catch {
    throw new ApiError(t('ERROR_OFFLINE'), 0);
  }
  const data = await res.json().catch(() => null);
  if (!res.ok || !data?.secure_url) {
    throw new ApiError(t('UPLOAD_FAILED'), res.status, data?.error?.message ? { cloudinary: data.error.message } : undefined);
  }

  return {
    url: data.secure_url,
    key: data.public_id,
    kind: data.resource_type === 'image' ? 'image' : 'document',
    tag,
    name: asset.fileName ?? undefined,
    mimeType: asset.mimeType ?? undefined,
    size: data.bytes,
  };
}

// A smaller, faster version of a Cloudinary photo for thumbnails:
//   thumbUrl(url, 240) → .../upload/c_fill,w_240,h_240,q_auto,f_auto/...
// Other URLs are returned unchanged.
export function thumbUrl(url, size = 240) {
  if (!url?.includes('res.cloudinary.com') || !url.includes('/upload/')) return url;
  const px = Math.round(size * 2); // sharp on high-density screens
  return url.replace('/upload/', `/upload/c_fill,w_${px},h_${px},q_auto,f_auto/`);
}

// A large version for the full-screen viewer (keeps the shape, caps the size)
export function largeUrl(url) {
  if (!url?.includes('res.cloudinary.com') || !url.includes('/upload/')) return url;
  return url.replace('/upload/', '/upload/c_limit,w_1600,h_1600,q_auto,f_auto/');
}
