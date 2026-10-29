// /qup-work-app/src/lib/notifications.js
// Turns a notification from the API into what the app shows: text in the chosen
// language, an icon, and where tapping it should go.
//
// The API also sends a Norwegian title/body. We only use those for notifications
// that don't carry the details we need (older ones, or types we don't know yet).
import { colors } from '@/constants/theme';
import { translate as t } from '@/i18n';

const job = (d) => d.jobTitle;
const to = (pathname, id) => (id ? { pathname, params: { id: String(id) } } : null);

// type → icon, colours, text builder (returns null when details are missing) and target
const KINDS = {
  new_offer: {
    icon: 'document-text',
    color: colors.slate,
    bg: colors.hivis,
    text: (d) => job(d) && d.actorName && { title: t('NOTIF_NEW_OFFER'), body: t('NOTIF_NEW_OFFER_BODY', { name: d.actorName, job: job(d) }) },
    target: (d) => to('/job/[id]', d.jobId),
  },
  offer_accepted: {
    icon: 'trophy',
    color: colors.pine,
    bg: colors.pineSoft,
    text: (d) => job(d) && { title: t('NOTIF_OFFER_ACCEPTED'), body: t('NOTIF_OFFER_ACCEPTED_BODY', { job: job(d) }) },
    target: (d) => to('/contract/[id]', d.contractId) ?? to('/job/[id]', d.jobId),
  },
  offer_rejected: {
    icon: 'close-circle',
    color: colors.textMuted,
    bg: colors.line,
    text: (d) =>
      job(d) && {
        title:
          d.reason === 'other_chosen'
            ? t('NOTIF_OFFER_OTHER_CHOSEN')
            : d.reason === 'job_cancelled'
              ? t('NOTIF_JOB_WITHDRAWN')
              : t('NOTIF_OFFER_DECLINED'),
        body: t('NOTIF_JOB_BODY', { job: job(d) }),
      },
    target: () => ({ pathname: '/my-offers' }),
  },
  milestone_submitted: {
    icon: 'checkmark-circle',
    color: colors.info,
    bg: colors.infoSoft,
    text: (d) =>
      job(d) && d.stepTitle && { title: t('NOTIF_STEP_SUBMITTED'), body: t('NOTIF_STEP_SUBMITTED_BODY', { name: d.actorName ?? '', step: d.stepTitle, job: job(d) }) },
    target: (d) => to('/contract/[id]', d.contractId),
  },
  milestone_approved: {
    icon: 'checkmark-done-circle',
    color: colors.pine,
    bg: colors.pineSoft,
    text: (d) => job(d) && d.stepTitle && { title: t('NOTIF_STEP_APPROVED'), body: t('NOTIF_STEP_BODY', { step: d.stepTitle, job: job(d) }) },
    target: (d) => to('/contract/[id]', d.contractId),
  },
  changes_requested: {
    icon: 'construct',
    color: colors.danger,
    bg: colors.dangerSoft,
    text: (d) => job(d) && d.stepTitle && { title: t('NOTIF_CHANGES_REQUESTED'), body: t('NOTIF_STEP_BODY', { step: d.stepTitle, job: job(d) }) },
    target: (d) => to('/contract/[id]', d.contractId),
  },
  contract_completed: {
    icon: 'ribbon',
    color: colors.pine,
    bg: colors.pineSoft,
    text: (d) => job(d) && { title: t('NOTIF_JOB_COMPLETED'), body: t('NOTIF_JOB_BODY', { job: job(d) }) },
    target: (d) => to('/contract/[id]', d.contractId),
  },
  contract_cancelled: {
    icon: 'ban',
    color: colors.danger,
    bg: colors.dangerSoft,
    text: (d) => job(d) && { title: t('NOTIF_JOB_CANCELLED'), body: t('NOTIF_JOB_BODY', { job: job(d) }) },
    target: (d) => to('/contract/[id]', d.contractId),
  },
  invoice_received: {
    icon: 'receipt',
    color: colors.amber,
    bg: colors.amberSoft,
    text: (d) =>
      d.invoiceNumber && { title: t('NOTIF_INVOICE'), body: t('NOTIF_INVOICE_BODY', { number: d.invoiceNumber, name: d.actorName ?? '' }) },
    target: (d) => to('/invoice/[id]', d.invoiceId) ?? to('/contract/[id]', d.contractId),
  },
  new_review: {
    icon: 'star',
    color: colors.hivisDeep,
    bg: colors.hivisSoft,
    text: (d) =>
      job(d) && d.rating && { title: t('NOTIF_REVIEW'), body: t('NOTIF_REVIEW_BODY', { name: d.actorName ?? '', rating: d.rating, job: job(d) }) },
    target: (d) => to('/contract/[id]', d.contractId),
  },
  new_message: {
    icon: 'chatbubble',
    color: colors.slate,
    bg: colors.concrete,
    text: (d) => d.actorName && { title: d.actorName, body: d.preview ?? t('ATTACHMENT') },
    target: (d) => to('/conversation/[id]', d.conversationId),
  },
};

const FALLBACK = { icon: 'notifications', color: colors.slate, bg: colors.concrete, text: () => null, target: () => null };

export function describeNotification(n) {
  const kind = KINDS[n.type] ?? FALLBACK;
  const data = n.data ?? {};
  const text = kind.text(data) || { title: n.title, body: n.body };
  return { ...text, icon: kind.icon, color: kind.color, bg: kind.bg, target: kind.target(data) };
}
