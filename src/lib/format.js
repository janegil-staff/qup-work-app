// /qup-work-app/src/lib/format.js
import Ionicons from '@expo/vector-icons/Ionicons';
import { colors } from '@/constants/theme';

// 125000 øre → "1 250 kr"   (shows øre only when there are any: "1 250,50 kr")
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

// Budget on a job: "5 000–10 000 kr", "Opptil 8 000 kr", "Fra 2 000 kr" or "Pris etter avtale"
export function budgetText(budget) {
  const min = budget?.min;
  const max = budget?.max;
  if (min != null && max != null) return `${formatNok(min).replace(' kr', '')}–${formatNok(max)}`;
  if (max != null) return `Opptil ${formatNok(max)}`;
  if (min != null) return `Fra ${formatNok(min)}`;
  return 'Pris etter avtale';
}

export function placeText(job) {
  if (job.workType === 'remote') return 'Fjernarbeid';
  return job.address?.city ?? job.address?.municipality ?? 'Sted ikke oppgitt';
}

const MONTHS = ['jan', 'feb', 'mar', 'apr', 'mai', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'des'];

// "27. okt" (this year) or "27. okt 2025"
export function formatDate(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  const sameYear = d.getFullYear() === new Date().getFullYear();
  return `${d.getDate()}. ${MONTHS[d.getMonth()]}${sameYear ? '' : ` ${d.getFullYear()}`}`;
}

// "nå", "5 min siden", "3 t siden", "i går", then a date
export function timeAgo(iso) {
  if (!iso) return '';
  const diffMin = Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
  if (diffMin < 1) return 'nå';
  if (diffMin < 60) return `${diffMin} min siden`;
  const hours = Math.floor(diffMin / 60);
  if (hours < 24) return `${hours} t siden`;
  if (hours < 48) return 'i går';
  return formatDate(iso);
}

export const URGENCY = {
  asap: 'Så fort som mulig',
  within_week: 'Innen en uke',
  within_month: 'Innen en måned',
  flexible: 'Fleksibelt',
};

export const JOB_STATUS = {
  draft: { label: 'Utkast', color: colors.textMuted, bg: colors.line },
  open: { label: 'Åpen', color: colors.pine, bg: colors.pineSoft },
  assigned: { label: 'Tildelt', color: colors.info, bg: colors.infoSoft },
  in_progress: { label: 'Pågår', color: colors.amber, bg: colors.amberSoft },
  completed: { label: 'Fullført', color: colors.pine, bg: colors.pineSoft },
  cancelled: { label: 'Avbrutt', color: colors.danger, bg: colors.dangerSoft },
};

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
