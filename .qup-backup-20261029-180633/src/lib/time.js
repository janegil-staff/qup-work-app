// /qup-work-app/src/lib/time.js
// Small helpers for typing in hours by hand.

// "8" → 480, "08:30" → 510, "8.30" → 510, "0830" → 510, "17" → 1020. Invalid → null
export function parseClock(text) {
  const s = String(text ?? '').trim().replace(/\s/g, '');
  if (!s) return null;
  let h;
  let m = 0;
  const parts = s.split(/[:.,]/);
  if (parts.length === 2) {
    h = Number(parts[0]);
    m = Number(parts[1].padEnd(2, '0'));
  } else if (/^\d{3,4}$/.test(s)) {
    h = Number(s.slice(0, -2));
    m = Number(s.slice(-2));
  } else if (/^\d{1,2}$/.test(s)) {
    h = Number(s);
  } else {
    return null;
  }
  if (!Number.isInteger(h) || !Number.isInteger(m) || h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

// 510 → "08:30"
export const clockText = (minutes) =>
  `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`;

// A Date at local midnight
export function startOfDay(date = new Date()) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

// Local day + minutes after midnight → Date
export function atMinutes(day, minutes) {
  const d = startOfDay(day);
  d.setMinutes(minutes);
  return d;
}

// Minutes after local midnight for a date
export const minutesOfDay = (date) => {
  const d = new Date(date);
  return d.getHours() * 60 + d.getMinutes();
};

// The last `count` days, newest first (local midnights)
export function recentDays(count = 7) {
  const today = startOfDay();
  return Array.from({ length: count }, (_, i) => {
    const d = new Date(today);
    d.setDate(d.getDate() - i);
    return d;
  });
}

// Typing a date by hand: "27.10", "27.10.2026", "27/10/26" or "2026-10-27" → Date at local midnight.
// No year means this year. Invalid → null
export function parseDay(text) {
  const s = String(text ?? '').trim();
  if (!s) return null;
  let d;
  let m;
  let y;
  const iso = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
  const local = s.match(/^(\d{1,2})[./-](\d{1,2})(?:[./-](\d{2}|\d{4}))?\.?$/);
  if (iso) [, y, m, d] = iso.map(Number);
  else if (local) {
    d = Number(local[1]);
    m = Number(local[2]);
    y = local[3] ? Number(local[3]) : new Date().getFullYear();
    if (y < 100) y += 2000;
  } else return null;
  const date = new Date(y, m - 1, d);
  if (date.getFullYear() !== y || date.getMonth() !== m - 1 || date.getDate() !== d) return null;
  return date;
}

// Date → "27.10.2026" for putting back in a text field
export function dayInputText(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  return `${String(d.getDate()).padStart(2, '0')}.${String(d.getMonth() + 1).padStart(2, '0')}.${d.getFullYear()}`;
}

// A day as an ISO string at noon UTC-ish local, so it never slips to the day before in another time zone
export function dayToIso(date) {
  const d = new Date(date);
  d.setHours(12, 0, 0, 0);
  return d.toISOString();
}
