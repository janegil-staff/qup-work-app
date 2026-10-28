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
