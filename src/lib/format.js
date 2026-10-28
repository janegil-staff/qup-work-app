// /qup-work-app/src/lib/format.js
// Formatting helpers. Text comes from the translation files via translate(),
// so they follow the chosen language.
import Ionicons from '@expo/vector-icons/Ionicons';
import { colors } from '@/constants/theme';
import { currentLocale, hasTranslation, translate as t } from '@/i18n';

// 125000 øre → "1 250 kr"   (the marketplace is in NOK; shows øre only when there are any)
export function formatNok(ore) {
  if (ore == null) return '';
  const negative = ore < 0;
  const abs = Math.abs(Math.round(ore));
  const kroner = Math.floor(abs / 100);
  const rest = abs % 100;
  const withSpaces = String(kroner).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  const decimals = rest ? `,${String(rest).padStart(2, '0')}` : '';
  return `${negative ? '−' : ''}${withSpaces}${decimals} kr`;
}

// Budget on a job: "5 000–10 000 kr", "Up to 8 000 kr", "From 2 000 kr" or "Price by agreement"
export function budgetText(budget) {
  const min = budget?.min;
  const max = budget?.max;
  if (min != null && max != null) {
    return t('BUDGET_RANGE', { min: formatNok(min).replace(' kr', ''), max: formatNok(max) });
  }
  if (max != null) return t('BUDGET_UP_TO', { max: formatNok(max) });
  if (min != null) return t('BUDGET_FROM', { min: formatNok(min) });
  return t('BUDGET_NEGOTIABLE');
}

export function placeText(job) {
  if (job.workType === 'remote') return t('REMOTE_WORK');
  return job.address?.city ?? job.address?.municipality ?? t('PLACE_NOT_GIVEN');
}

// "27 Oct" / "27. okt." in the chosen language; adds the year when it isn't this year
export function formatDate(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  const sameYear = d.getFullYear() === new Date().getFullYear();
  try {
    return new Intl.DateTimeFormat(currentLocale(), {
      day: 'numeric',
      month: 'short',
      ...(sameYear ? {} : { year: 'numeric' }),
    }).format(d);
  } catch {
    return d.toISOString().slice(0, 10);
  }
}

// "now", "5 min ago", "3 h ago", "yesterday", then a date
export function timeAgo(iso) {
  if (!iso) return '';
  const diffMin = Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
  if (diffMin < 1) return t('TIME_NOW');
  if (diffMin < 60) return t('TIME_MINUTES_AGO', { n: diffMin });
  const hours = Math.floor(diffMin / 60);
  if (hours < 24) return t('TIME_HOURS_AGO', { n: hours });
  if (hours < 48) return t('TIME_YESTERDAY');
  return formatDate(iso);
}

// "14:05" (or "2:05 PM") in the chosen language
export function formatTime(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  try {
    return new Intl.DateTimeFormat(currentLocale(), { hour: 'numeric', minute: '2-digit' }).format(d);
  } catch {
    return d.toTimeString().slice(0, 5);
  }
}

export const isSameDay = (a, b) => new Date(a).toDateString() === new Date(b).toDateString();

// Divider between days in a chat: "Today", "Yesterday", "Monday" (this week), then a date
export function dayLabel(iso) {
  const d = new Date(iso);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const day = new Date(d);
  day.setHours(0, 0, 0, 0);
  const daysAgo = Math.round((today - day) / 86400000);
  if (daysAgo === 0) return t('TODAY');
  if (daysAgo === 1) return t('YESTERDAY');
  if (daysAgo > 1 && daysAgo < 7) {
    try {
      return new Intl.DateTimeFormat(currentLocale(), { weekday: 'long' }).format(d);
    } catch {
      return formatDate(iso);
    }
  }
  return formatDate(iso);
}

// Translation keys; look them up with t() when rendering
export const URGENCY = {
  asap: 'URGENCY_ASAP',
  within_week: 'URGENCY_WITHIN_WEEK',
  within_month: 'URGENCY_WITHIN_MONTH',
  flexible: 'URGENCY_FLEXIBLE',
};

export const JOB_STATUS = {
  draft: { label: 'STATUS_DRAFT', color: colors.textMuted, bg: colors.line },
  open: { label: 'STATUS_OPEN', color: colors.pine, bg: colors.pineSoft },
  assigned: { label: 'STATUS_ASSIGNED', color: colors.info, bg: colors.infoSoft },
  in_progress: { label: 'STATUS_IN_PROGRESS', color: colors.amber, bg: colors.amberSoft },
  completed: { label: 'STATUS_COMPLETED', color: colors.pine, bg: colors.pineSoft },
  cancelled: { label: 'STATUS_CANCELLED', color: colors.danger, bg: colors.dangerSoft },
};

export const OFFER_STATUS = {
  pending: { label: 'OFFER_STATUS_PENDING', color: colors.amber, bg: colors.amberSoft },
  accepted: { label: 'OFFER_STATUS_ACCEPTED', color: colors.pine, bg: colors.pineSoft },
  rejected: { label: 'OFFER_STATUS_REJECTED', color: colors.danger, bg: colors.dangerSoft },
  withdrawn: { label: 'OFFER_STATUS_WITHDRAWN', color: colors.textMuted, bg: colors.line },
  expired: { label: 'OFFER_STATUS_EXPIRED', color: colors.textMuted, bg: colors.line },
};

export const CONTRACT_STATUS = {
  active: { label: 'CONTRACT_STATUS_ACTIVE', color: colors.info, bg: colors.infoSoft },
  completed: { label: 'STATUS_COMPLETED', color: colors.pine, bg: colors.pineSoft },
  cancelled: { label: 'STATUS_CANCELLED', color: colors.danger, bg: colors.dangerSoft },
  disputed: { label: 'CONTRACT_STATUS_DISPUTED', color: colors.danger, bg: colors.dangerSoft },
};

export const MILESTONE_STATUS = {
  pending: { label: 'MILESTONE_STATUS_PENDING', color: colors.textMuted, bg: colors.line },
  in_progress: { label: 'STATUS_IN_PROGRESS', color: colors.amber, bg: colors.amberSoft },
  submitted: { label: 'MILESTONE_STATUS_SUBMITTED', color: colors.info, bg: colors.infoSoft },
  changes_requested: { label: 'MILESTONE_STATUS_CHANGES', color: colors.danger, bg: colors.dangerSoft },
  approved: { label: 'MILESTONE_STATUS_APPROVED', color: colors.pine, bg: colors.pineSoft },
  cancelled: { label: 'STATUS_CANCELLED', color: colors.textMuted, bg: colors.line },
};

// 200 → "3 h 20 min", 45 → "45 min"
export function formatMinutes(minutes) {
  const m = Math.max(0, Math.round(minutes ?? 0));
  const h = Math.floor(m / 60);
  const rest = m % 60;
  if (!h) return t('DURATION_MIN', { m: rest });
  if (!rest) return t('DURATION_H', { h });
  return t('DURATION_H_MIN', { h, m: rest });
}

// Price on an offer, as a big line and a small one underneath:
//   fixed    → "8 000 kr"      / "Fixed price"
//   hourly   → "950 kr/h"      / "About 7 600 kr in total" (or "Hourly rate")
//   estimate → "12 000 kr"     / "Estimate"
export function offerPrice(offer) {
  if (offer.priceType === 'hourly') {
    const total = offer.estimatedTotal ?? (offer.estimatedHours ? offer.amount * offer.estimatedHours : null);
    return {
      main: t('PRICE_PER_HOUR', { price: formatNok(offer.amount) }),
      sub: total ? t('ESTIMATE_TOTAL', { total: formatNok(total) }) : t('PRICE_HOURLY'),
    };
  }
  return { main: formatNok(offer.amount), sub: t(offer.priceType === 'estimate' ? 'PRICE_ESTIMATE' : 'PRICE_FIXED') };
}

// Categories come from the API in Norwegian. The app translates the ones it knows by slug
// (CAT_ELEKTRIKER, CAT_RORLEGGER_BAD, ...) and shows the API name for anything new.
export function categoryName(category) {
  if (!category) return '';
  if (category.slug) {
    const key = `CAT_${category.slug.toUpperCase().replace(/-/g, '_')}`;
    if (hasTranslation(key)) return t(key);
  }
  return category.name;
}

// Category icons from the API → valid Ionicons names (with a safe fallback)
const ICON_ALIASES = {
  truck: 'car',
  palette: 'color-palette',
  code: 'code-slash',
  apps: 'apps',
};

export function categoryIcon(name) {
  const base = ICON_ALIASES[name] ?? name ?? 'construct';
  const outline = `${base}-outline`;
  if (Ionicons.glyphMap[outline]) return outline;
  if (Ionicons.glyphMap[base]) return base;
  return 'construct-outline';
}
