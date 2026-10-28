// /qup-work-app/src/app/contract/[id].js
// The work after an offer is accepted. Both sides see the same page:
//   pro      → start a step, mark it as done (with photos and a note)
//   customer → approve a step or ask for changes, then complete the job and leave a review
// Steps go: pending → in progress → waiting for approval → approved (or back via "changes").
// Hours (timer + entries) are in components/HoursSection.js, invoices in InvoicesSection.js.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { useCallback, useRef, useState } from 'react';
import { ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { BackButton } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { Button } from '@/components/Button';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { HoursSection } from '@/components/HoursSection';
import { InvoicesSection } from '@/components/InvoicesSection';
import { Loading } from '@/components/Loading';
import { Perforation } from '@/components/Perforation';
import { PhotoPicker } from '@/components/PhotoPicker';
import { PhotoStrip } from '@/components/PhotoStrip';
import { Sheet } from '@/components/Sheet';
import { SignInPrompt } from '@/components/SignInPrompt';
import { StarInput } from '@/components/StarInput';
import { StatusBadge } from '@/components/StatusBadge';
import { TextField } from '@/components/TextField';
import { colors, fonts, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { api, errorMessage } from '@/lib/api';
import { openChat } from '@/lib/chat';
import { confirm } from '@/lib/confirm';
import { formatDate, formatMinutes, formatNok } from '@/lib/format';
import { useI18n } from '@/i18n';

export default function ContractScreen() {
  const { id } = useLocalSearchParams();
  const { user } = useAuth();
  const { t } = useI18n();
  const insets = useSafeAreaInsets();

  if (!user) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md }]}>
        <View style={{ paddingHorizontal: spacing.xl }}>
          <BackButton />
        </View>
        <SignInPrompt icon="document-text-outline" title={t('CONTRACT')} text={t('CONTRACT_GUEST_TEXT')} />
      </View>
    );
  }
  return <ContractView key={id} contractId={id} />;
}

function ContractView({ contractId }) {
  const { t } = useI18n();
  const insets = useSafeAreaInsets();
  const [data, setData] = useState(null);
  const [loadError, setLoadError] = useState(null);
  const [actionError, setActionError] = useState(null);
  const [busy, setBusy] = useState(null); // `${milestoneId}:${action}` | 'complete' | 'chat'
  const [sheet, setSheet] = useState(null); // { type: 'submit' | 'changes', milestone } | { type: 'review' }
  const alive = useRef(true);

  const load = useCallback(async () => {
    try {
      const res = await api(`/contracts/${contractId}`);
      if (!alive.current) return;
      setData(res);
      setLoadError(null);
    } catch (err) {
      if (alive.current) setLoadError(errorMessage(err));
    }
  }, [contractId]);

  useFocusEffect(
    useCallback(() => {
      alive.current = true;
      load();
      return () => {
        alive.current = false;
      };
    }, [load])
  );

  if (loadError && !data) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md }]}>
        <View style={{ paddingHorizontal: spacing.xl }}>
          <BackButton />
        </View>
        <EmptyState icon="document-text-outline" title={t('CONTRACT_NOT_FOUND')} text={loadError} actionTitle={t('TRY_AGAIN')} onAction={load} />
      </View>
    );
  }
  if (!data) return <Loading dark />;

  const { contract, side, milestones, hours, myReview } = data;
  const isPro = side === 'pro';
  const active = contract.status === 'active';
  const completed = contract.status === 'completed';
  const steps = milestones.filter((m) => m.status !== 'cancelled');
  const approved = steps.filter((m) => m.status === 'approved').length;
  const allApproved = steps.length > 0 && approved === steps.length;
  const waitingForCustomer = steps.filter((m) => m.status === 'submitted').length;

  // The other side of the deal
  const other = isPro
    ? { user: contract.customer, name: contract.customer?.name ?? contract.client?.name, avatarUrl: contract.customer?.avatarUrl, role: t('CUSTOMER') }
    : { user: contract.pro, name: contract.company?.name ?? contract.pro?.name, avatarUrl: contract.company?.logoUrl ?? contract.pro?.avatarUrl, role: t('PRO') };
  // Only the main pro reviews the customer, and only customers with an account can be reviewed
  const canReview = completed && !myReview && (isPro ? Boolean(contract.customer) : true);

  async function run(key, fn) {
    setBusy(key);
    setActionError(null);
    try {
      await fn();
      await load();
      return true;
    } catch (err) {
      setActionError(errorMessage(err));
      return false;
    } finally {
      setBusy(null);
    }
  }

  const ms = (m, action) => `/contracts/${contract._id}/milestones/${m._id}/${action}`;

  const start = (m) => run(`${m._id}:start`, () => api(ms(m, 'start'), { method: 'POST' }));

  async function approve(m) {
    const ok = await confirm({
      title: t('APPROVE_STEP_TITLE'),
      message: t('APPROVE_STEP_TEXT', { title: m.title }),
      confirmText: t('APPROVE'),
    });
    if (ok) run(`${m._id}:approve`, () => api(ms(m, 'approve'), { method: 'POST', body: {} }));
  }

  async function complete() {
    const ok = await confirm({ title: t('COMPLETE_JOB_TITLE'), message: t('COMPLETE_JOB_TEXT'), confirmText: t('COMPLETE_JOB') });
    if (!ok) return;
    const done = await run('complete', () => api(`/contracts/${contract._id}/complete`, { method: 'POST' }));
    if (done) setSheet({ type: 'review' }); // the natural next thing to do
  }

  async function message() {
    if (!other.user?._id) return;
    setBusy('chat');
    setActionError(null);
    try {
      await openChat({ participant: other.user._id, job: contract.job?._id });
    } catch (err) {
      setActionError(errorMessage(err));
    } finally {
      setBusy(null);
    }
  }

  const price =
    contract.priceType === 'hourly'
      ? { main: t('PRICE_PER_HOUR', { price: formatNok(contract.hourlyRate) }), sub: t('PRICE_HOURLY') }
      : { main: formatNok(contract.totalAmount), sub: t(contract.priceType === 'estimate' ? 'PRICE_ESTIMATE' : 'PRICE_FIXED') };

  const facts = [
    contract.startDate && { icon: 'play-outline', label: t('FACT_START'), value: formatDate(contract.startDate) },
    contract.endDate && { icon: 'flag-outline', label: t('FACT_END'), value: formatDate(contract.endDate) },
    (contract.priceType === 'hourly' || hours.minutes > 0) && {
      icon: 'time-outline',
      label: t('FACT_HOURS_LOGGED'),
      value: formatMinutes(hours.minutes),
    },
    {
      icon: contract.paymentMethod === 'escrow' ? 'shield-checkmark-outline' : 'receipt-outline',
      label: t('FACT_PAYMENT'),
      value: contract.paymentMethod === 'escrow' ? t('PAYMENT_ESCROW') : t('PAYMENT_INVOICE'),
    },
  ].filter(Boolean);

  // What the bottom bar offers right now
  let bottom = null;
  if (active && !isPro && allApproved) {
    bottom = <Button title={t('COMPLETE_JOB')} icon="checkmark-done" loading={busy === 'complete'} onPress={complete} />;
  } else if (active && !isPro && waitingForCustomer) {
    bottom = (
      <AppText variant="smallStrong" center color={colors.info}>
        {t('STEPS_WAITING_FOR_YOU', { n: waitingForCustomer })}
      </AppText>
    );
  } else if (active && isPro && allApproved && contract.customer) {
    bottom = (
      <AppText variant="small" muted center>
        {t('WAITING_FOR_CUSTOMER_TO_COMPLETE')}
      </AppText>
    );
  } else if (canReview) {
    bottom = <Button title={t('RATE_NAME', { name: other.name ?? '' })} icon="star" onPress={() => setSheet({ type: 'review' })} />;
  }

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="light" />
      <ScrollView contentContainerStyle={{ paddingBottom: spacing.xxl }}>
        <View style={[styles.hero, { paddingTop: insets.top + spacing.md }]}>
          <View style={styles.heroTop}>
            <BackButton onDark />
            <StatusBadge status={contract.status} kind="contract" />
          </View>
          <View style={{ gap: 4 }}>
            <AppText variant="caption" onDark muted style={styles.kicker}>
              {t('CONTRACT')}
            </AppText>
            <AppText variant="h1" onDark accessibilityRole="header">
              {contract.title}
            </AppText>
          </View>
          <View style={styles.party}>
            <Avatar name={other.name} url={other.avatarUrl} size={44} />
            <View style={{ flex: 1 }}>
              <AppText variant="caption" onDark muted>
                {other.role}
              </AppText>
              <AppText variant="bodyStrong" onDark numberOfLines={1}>
                {other.name ?? t('UNKNOWN')}
              </AppText>
            </View>
            {other.user?._id ? (
              <Button title={t('MESSAGE')} icon="chatbubble-outline" variant="outlineOnDark" small loading={busy === 'chat'} onPress={message} />
            ) : null}
          </View>
        </View>

        <View style={styles.ticket}>
          <View style={styles.ticketTop}>
            <View style={{ flex: 1, gap: 2 }}>
              <AppText variant="caption" muted>
                {t('AGREED_PRICE')}
              </AppText>
              <AppText variant="h2">{price.main}</AppText>
              <AppText variant="caption" muted>
                {price.sub}
              </AppText>
            </View>
          </View>
          <Perforation notchColor={colors.concrete} />
          <View style={styles.facts}>
            {facts.map((f) => (
              <View key={f.label} style={styles.fact}>
                <Ionicons name={f.icon} size={18} color={colors.textMuted} />
                <AppText variant="small" muted style={{ width: 118 }}>
                  {f.label}
                </AppText>
                <AppText variant="smallStrong" style={{ flex: 1, textAlign: 'right' }}>
                  {f.value}
                </AppText>
              </View>
            ))}
            {steps.length ? (
              <View style={{ gap: 6, marginTop: spacing.xs }}>
                <View style={styles.progressTrack} accessibilityRole="progressbar" accessibilityValue={{ min: 0, max: steps.length, now: approved }}>
                  <View style={[styles.progressFill, { width: `${(approved / steps.length) * 100}%` }]} />
                </View>
                <AppText variant="caption" muted>
                  {t('STEPS_APPROVED', { done: approved, total: steps.length })}
                </AppText>
              </View>
            ) : null}
          </View>
        </View>

        {completed ? (
          <View style={[styles.section, styles.doneBanner]}>
            <Ionicons name="checkmark-circle" size={22} color={colors.pine} />
            <AppText variant="bodyStrong" color={colors.pine} style={{ flex: 1 }}>
              {t('JOB_COMPLETED_ON', { date: formatDate(contract.completedAt) })}
            </AppText>
          </View>
        ) : null}

        <View style={styles.section}>
          <ErrorBanner message={actionError} />
        </View>

        {/* On hourly jobs the hours come first; otherwise they're extra detail under the steps */}
        {contract.priceType === 'hourly' ? <HoursSection contract={contract} side={side} onChanged={load} /> : null}

        <View style={styles.section}>
          <AppText variant="title">{t('STEPS_TITLE')}</AppText>
          <View>
            {milestones.map((m, i) => (
              <MilestoneRow
                key={m._id}
                milestone={m}
                number={i + 1}
                last={i === milestones.length - 1}
                hourly={contract.priceType === 'hourly'}
                side={side}
                active={active}
                busy={busy}
                onStart={() => start(m)}
                onSubmit={() => setSheet({ type: 'submit', milestone: m })}
                onApprove={() => approve(m)}
                onChanges={() => setSheet({ type: 'changes', milestone: m })}
              />
            ))}
          </View>
        </View>

        {contract.priceType !== 'hourly' ? <HoursSection contract={contract} side={side} onChanged={load} /> : null}

        <InvoicesSection contract={contract} side={side} hours={hours} onChanged={load} />

        {completed && myReview ? (
          <View style={[styles.section, styles.reviewCard]}>
            <AppText variant="caption" muted>
              {t('YOUR_REVIEW')}
            </AppText>
            <View style={{ flexDirection: 'row', gap: 2 }} accessibilityLabel={t('RATING_OUT_OF_5', { n: myReview.rating })}>
              {[1, 2, 3, 4, 5].map((n) => (
                <Ionicons key={n} name={n <= myReview.rating ? 'star' : 'star-outline'} size={18} color={colors.hivisDeep} />
              ))}
            </View>
            {myReview.comment ? <AppText variant="body">{myReview.comment}</AppText> : null}
          </View>
        ) : null}
      </ScrollView>

      {bottom ? <BottomBar>{bottom}</BottomBar> : null}

      <SubmitSheet
        milestone={sheet?.type === 'submit' ? sheet.milestone : null}
        onClose={() => setSheet(null)}
        onSend={(body) => run(`${sheet.milestone._id}:submit`, () => api(ms(sheet.milestone, 'submit'), { method: 'POST', body }))}
      />
      <ChangesSheet
        milestone={sheet?.type === 'changes' ? sheet.milestone : null}
        onClose={() => setSheet(null)}
        onSend={(feedback) =>
          run(`${sheet.milestone._id}:changes`, () => api(ms(sheet.milestone, 'request-changes'), { method: 'POST', body: { feedback } }))
        }
      />
      <ReviewSheet
        visible={sheet?.type === 'review' && canReview}
        name={other.name}
        onClose={() => setSheet(null)}
        onSend={(body) => run('review', () => api('/reviews', { method: 'POST', body: { ...body, contract: contract._id } }))}
      />
    </View>
  );
}

// One step on the timeline: number (or a tick), title, status, what was delivered, and the buttons
function MilestoneRow({ milestone: m, number, last, hourly, side, active, busy, onStart, onSubmit, onApprove, onChanges }) {
  const { t } = useI18n();
  const done = m.status === 'approved';
  const isBusy = (action) => busy === `${m._id}:${action}`;
  const anyBusy = Boolean(busy);

  let actions = null;
  if (active && side === 'pro') {
    if (m.status === 'pending') {
      actions = (
        <>
          <Button title={t('START')} icon="play" variant="dark" small loading={isBusy('start')} disabled={anyBusy} onPress={onStart} style={{ flexGrow: 1 }} />
          <Button title={t('MARK_AS_DONE')} variant="outline" small disabled={anyBusy} onPress={onSubmit} style={{ flexGrow: 1 }} />
        </>
      );
    } else if (m.status === 'in_progress' || m.status === 'changes_requested') {
      actions = <Button title={t('MARK_AS_DONE')} icon="checkmark" small disabled={anyBusy} onPress={onSubmit} style={{ flexGrow: 1 }} />;
    } else if (m.status === 'submitted') {
      actions = (
        <AppText variant="small" muted>
          {t('WAITING_FOR_APPROVAL')}
        </AppText>
      );
    }
  } else if (active && side === 'customer') {
    if (m.status === 'submitted') {
      actions = (
        <>
          <Button title={t('APPROVE')} icon="checkmark" small loading={isBusy('approve')} disabled={anyBusy} onPress={onApprove} style={{ flexGrow: 1 }} />
          <Button title={t('ASK_FOR_CHANGES')} variant="outline" small disabled={anyBusy} onPress={onChanges} style={{ flexGrow: 1 }} />
        </>
      );
    } else if (m.status === 'in_progress' || m.status === 'changes_requested') {
      actions = (
        <AppText variant="small" muted>
          {t('PRO_IS_WORKING')}
        </AppText>
      );
    }
  }

  return (
    <View style={styles.step}>
      {/* The rail: a numbered stub, joined to the next one by a line */}
      <View style={styles.rail}>
        <View style={[styles.stepNo, done && styles.stepNoDone, m.status === 'submitted' && styles.stepNoWaiting]}>
          {done ? (
            <Ionicons name="checkmark" size={18} color={colors.paper} />
          ) : (
            <AppText style={styles.stepNoText} color={m.status === 'submitted' ? colors.slate : colors.text}>
              {number}
            </AppText>
          )}
        </View>
        {!last ? <View style={[styles.railLine, done && { backgroundColor: colors.pine }]} /> : null}
      </View>

      <View style={[styles.stepCard, last && { marginBottom: 0 }]}>
        <View style={styles.stepHead}>
          <AppText variant="title" style={{ flex: 1 }}>
            {m.title}
          </AppText>
          {!hourly && m.amount != null ? <AppText variant="smallStrong">{formatNok(m.amount)}</AppText> : null}
        </View>
        <View style={styles.stepMeta}>
          <StatusBadge status={m.status} kind="milestone" />
          {m.dueDate && !done ? (
            <AppText variant="caption" muted>
              {t('DUE_DATE', { date: formatDate(m.dueDate) })}
            </AppText>
          ) : null}
          {done && m.approvedAt ? (
            <AppText variant="caption" muted>
              {t('APPROVED_ON', { date: formatDate(m.approvedAt) })}
            </AppText>
          ) : null}
        </View>

        {m.description ? (
          <AppText variant="small" muted>
            {m.description}
          </AppText>
        ) : null}

        {m.status === 'changes_requested' && m.feedback ? (
          <View style={[styles.note, styles.noteChanges]}>
            <AppText variant="caption" color={colors.danger}>
              {t('CHANGES_REQUESTED_LABEL')}
            </AppText>
            <AppText variant="small">{m.feedback}</AppText>
          </View>
        ) : null}

        {m.submissionNote && ['submitted', 'approved', 'changes_requested'].includes(m.status) ? (
          <View style={styles.note}>
            <AppText variant="caption" muted>
              {t('NOTE_FROM_PRO')}
            </AppText>
            <AppText variant="small">{m.submissionNote}</AppText>
          </View>
        ) : null}

        {done && m.feedback ? (
          <View style={styles.note}>
            <AppText variant="caption" muted>
              {t('COMMENT_FROM_CUSTOMER')}
            </AppText>
            <AppText variant="small">{m.feedback}</AppText>
          </View>
        ) : null}

        {m.customerSignature?.name ? (
          <AppText variant="caption" muted>
            {t('SIGNED_BY', { name: m.customerSignature.name })}
          </AppText>
        ) : null}

        <PhotoStrip attachments={m.attachments} />

        {actions ? <View style={styles.stepActions}>{actions}</View> : null}
      </View>
    </View>
  );
}

// Pro: "Mark as done" with an optional note and photos
function SubmitSheet({ milestone, onClose, onSend }) {
  const { t } = useI18n();
  const [note, setNote] = useState('');
  const [photos, setPhotos] = useState([]);
  const [uploading, setUploading] = useState(false);
  const [sending, setSending] = useState(false);
  const [sheetKey, setSheetKey] = useState(0); // fresh picker each time it opens

  function close() {
    setNote('');
    setPhotos([]);
    setSheetKey((k) => k + 1);
    onClose();
  }

  async function send() {
    setSending(true);
    const ok = await onSend({ submissionNote: note.trim() || undefined, attachments: photos });
    setSending(false);
    if (ok) close();
  }

  return (
    <Sheet visible={Boolean(milestone)} onClose={close} title={t('MARK_AS_DONE')} subtitle={milestone?.title}>
      <AppText variant="small" muted>
        {t('SUBMIT_STEP_INTRO')}
      </AppText>
      <PhotoPicker key={sheetKey} tag="after" label={t('PHOTOS_OF_WORK')} onChange={setPhotos} onBusyChange={setUploading} />
      <TextField
        label={t('NOTE_TO_CUSTOMER')}
        value={note}
        onChangeText={setNote}
        multiline
        placeholder={t('NOTE_TO_CUSTOMER_PLACEHOLDER')}
        maxLength={3000}
      />
      <Button
        title={uploading ? t('UPLOADING_PHOTOS') : t('SEND_FOR_APPROVAL')}
        icon="send"
        loading={sending}
        disabled={uploading}
        onPress={send}
      />
    </Sheet>
  );
}

// Customer: "Ask for changes" needs a few words on what's missing
function ChangesSheet({ milestone, onClose, onSend }) {
  const { t } = useI18n();
  const [feedback, setFeedback] = useState('');
  const [sending, setSending] = useState(false);

  function close() {
    setFeedback('');
    onClose();
  }

  async function send() {
    setSending(true);
    const ok = await onSend(feedback.trim());
    setSending(false);
    if (ok) close();
  }

  return (
    <Sheet visible={Boolean(milestone)} onClose={close} title={t('ASK_FOR_CHANGES')} subtitle={milestone?.title}>
      <TextField
        label={t('WHAT_SHOULD_CHANGE')}
        value={feedback}
        onChangeText={setFeedback}
        multiline
        placeholder={t('WHAT_SHOULD_CHANGE_PLACEHOLDER')}
        maxLength={3000}
        autoFocus
      />
      <Button title={t('SEND_TO_PRO')} icon="send" loading={sending} disabled={feedback.trim().length < 3} onPress={send} />
    </Sheet>
  );
}

// Stars and a few words, once the job is completed
function ReviewSheet({ visible, name, onClose, onSend }) {
  const { t } = useI18n();
  const [rating, setRating] = useState(0);
  const [comment, setComment] = useState('');
  const [sending, setSending] = useState(false);

  async function send() {
    setSending(true);
    const ok = await onSend({ rating, comment: comment.trim() || undefined });
    setSending(false);
    if (ok) onClose();
  }

  return (
    <Sheet visible={visible} onClose={onClose} title={t('RATE_NAME', { name: name ?? '' })} subtitle={t('REVIEW_INTRO')}>
      <StarInput value={rating} onChange={setRating} />
      <TextField
        label={t('REVIEW_COMMENT')}
        value={comment}
        onChangeText={setComment}
        multiline
        placeholder={t('REVIEW_COMMENT_PLACEHOLDER')}
        maxLength={3000}
      />
      <Button title={t('PUBLISH_REVIEW')} icon="star" loading={sending} disabled={!rating} onPress={send} />
    </Sheet>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  hero: {
    backgroundColor: colors.slate,
    paddingHorizontal: spacing.xl,
    paddingBottom: spacing.xxxl + spacing.lg,
    gap: spacing.lg,
  },
  heroTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  kicker: { textTransform: 'uppercase', letterSpacing: 1.2 },
  party: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    paddingTop: spacing.md,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: colors.slateLine,
  },
  ticket: { marginTop: -spacing.xxxl, marginHorizontal: spacing.xl, backgroundColor: colors.paper, borderRadius: radius.ticket },
  ticketTop: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, padding: spacing.lg },
  facts: { padding: spacing.lg, paddingTop: spacing.sm, gap: spacing.md },
  fact: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  progressTrack: { height: 8, borderRadius: 4, backgroundColor: colors.concrete, overflow: 'hidden' },
  progressFill: { height: '100%', borderRadius: 4, backgroundColor: colors.pine },
  section: { marginTop: spacing.xl, marginHorizontal: spacing.xl, gap: spacing.md, maxWidth: 640 },
  doneBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    padding: spacing.lg,
    borderRadius: radius.ticket,
    backgroundColor: colors.pineSoft,
  },
  step: { flexDirection: 'row', gap: spacing.md },
  rail: { alignItems: 'center', width: 34 },
  stepNo: {
    width: 34,
    height: 34,
    borderRadius: 6,
    backgroundColor: colors.paper,
    borderWidth: 1.5,
    borderColor: colors.line,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stepNoDone: { backgroundColor: colors.pine, borderColor: colors.pine },
  stepNoWaiting: { backgroundColor: colors.hivis, borderColor: colors.hivis },
  stepNoText: { fontFamily: fonts.heavy, fontSize: 15, lineHeight: 18 },
  railLine: { flex: 1, width: 2, backgroundColor: colors.line, marginVertical: 4 },
  stepCard: {
    flex: 1,
    backgroundColor: colors.paper,
    borderRadius: radius.ticket,
    padding: spacing.lg,
    gap: spacing.sm,
    marginBottom: spacing.md,
  },
  stepHead: { flexDirection: 'row', alignItems: 'flex-start', gap: spacing.sm },
  stepMeta: { flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap', gap: spacing.sm },
  note: { borderLeftWidth: 3, borderLeftColor: colors.line, paddingLeft: spacing.md, gap: 2 },
  noteChanges: { borderLeftColor: colors.danger },
  stepActions: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginTop: spacing.xs },
  reviewCard: { backgroundColor: colors.paper, borderRadius: radius.ticket, padding: spacing.lg, gap: spacing.sm },
});
