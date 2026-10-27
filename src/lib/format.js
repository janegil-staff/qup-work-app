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
