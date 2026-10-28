// /qup-work-app/src/app/job/[id].js
// One job as a big work-order ticket. Public for open jobs; acting on it needs an account.
// The customer sees the offers here and picks one; a pro sees their own offer.
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
import { Loading } from '@/components/Loading';
import { OfferCard } from '@/components/OfferCard';
import { Perforation } from '@/components/Perforation';
import { StatusBadge } from '@/components/StatusBadge';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { api, errorMessage } from '@/lib/api';
import { openChat } from '@/lib/chat';
import { confirm } from '@/lib/confirm';
import { useI18n } from '@/i18n';
import { budgetText, categoryIcon, categoryName, formatDate, offerPrice, placeText, timeAgo, URGENCY } from '@/lib/format';

export default function JobScreen() {
  const { id } = useLocalSearchParams();
  const insets = useSafeAreaInsets();
  const { user, isPro } = useAuth();
  const { t } = useI18n();
  const [data, setData] = useState(null);
  const [offers, setOffers] = useState([]);
  const [error, setError] = useState(null);
  const alive = useRef(true);

  // The job, plus its offers when I may see them (all of them as the customer, my own as a pro)
  const load = useCallback(async () => {
    try {
      const res = await api(`/jobs/${id}`);
      const showOffers = res.side === 'customer' || (res.side === 'viewer' && res.myOffer);
      const list = showOffers ? (await api(`/jobs/${id}/offers`)).offers : [];
      if (!alive.current) return;
      setData(res);
      setOffers(list);
      setError(null);
    } catch (err) {
      if (alive.current) setError(errorMessage(err));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id, user?._id]);

  // Reload when coming back from the offer form, a chat or login
  useFocusEffect(
    useCallback(() => {
      alive.current = true;
      load();
      return () => {
        alive.current = false;
      };
    }, [load])
  );

  if (error && !data) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl }]}>
        <BackButton />
        <EmptyState icon="clipboard-outline" title={t('JOB_NOT_FOUND')} text={error} />
      </View>
    );
  }
  if (!data) return <Loading dark />;

  const { job, side, myOffer } = data;
  const myOfferFull = myOffer ? offers.find((o) => o._id === myOffer._id) : null;
  const facts = [
    job.timing?.urgency && { icon: 'calendar-outline', label: t('FACT_WHEN'), value: t(URGENCY[job.timing.urgency]) },
    job.timing?.preferredStart && { icon: 'play-outline', label: t('FACT_PREFERRED_START'), value: formatDate(job.timing.preferredStart) },
    {
      icon: job.workType === 'remote' ? 'globe-outline' : 'location-outline',
      label: job.workType === 'remote' ? t('FACT_WORKPLACE') : t('FACT_PLACE'),
      value: job.workType === 'remote' ? t('REMOTE_WORK') : [job.address?.postalCode, placeText(job)].filter(Boolean).join(' '),
    },
    job.address?.line1 && { icon: 'home-outline', label: t('FACT_ADDRESS'), value: job.address.line1 },
    { icon: 'document-text-outline', label: t('FACT_OFFERS'), value: job.offerCount ? t('OFFERS_RECEIVED', { n: job.offerCount }) : t('NONE_YET') },
  ].filter(Boolean);

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="light" />
      <ScrollView contentContainerStyle={{ paddingBottom: spacing.xxl }}>
        <View style={[styles.hero, { paddingTop: insets.top + spacing.md }]}>
          <BackButton onDark />
          {job.category ? (
            <View style={styles.category}>
              <View style={styles.categoryIcon}>
                <Ionicons name={categoryIcon(job.category.icon)} size={15} color={colors.slate} />
              </View>
              <AppText variant="smallStrong" onDark muted>
                {categoryName(job.category)}
              </AppText>
            </View>
          ) : null}
          <AppText variant="h1" onDark accessibilityRole="header">
            {job.title}
          </AppText>
          <AppText variant="small" onDark muted>
            {t('POSTED_AGO', { time: timeAgo(job.publishedAt ?? job.createdAt) })}
          </AppText>
        </View>

        {/* The ticket */}
        <View style={styles.ticket}>
          <View style={styles.ticketTop}>
            <View style={{ flex: 1, gap: 2 }}>
              <AppText variant="caption" muted>
                {t('BUDGET')}
              </AppText>
              <AppText variant="h2">{budgetText(job.budget)}</AppText>
            </View>
            <StatusBadge status={job.status} />
          </View>

          <Perforation notchColor={colors.concrete} />

          <View style={styles.facts}>
            {facts.map((f) => (
              <View key={f.label} style={styles.fact}>
                <Ionicons name={f.icon} size={18} color={colors.textMuted} />
                <AppText variant="small" muted style={styles.factLabel}>
                  {f.label}
                </AppText>
                <AppText variant="smallStrong" style={{ flex: 1, textAlign: 'right' }}>
                  {f.value}
                </AppText>
              </View>
            ))}
          </View>
        </View>

        {job.description ? (
          <View style={styles.section}>
            <AppText variant="title">{t('DESCRIPTION')}</AppText>
            <AppText variant="body">{job.description}</AppText>
          </View>
        ) : null}

        {job.customer ? (
          <View style={[styles.section, styles.person]}>
            <Avatar name={job.customer.name} url={job.customer.avatarUrl} size={44} dark />
            <View>
              <AppText variant="caption" muted>
                {t('POSTED_BY')}
              </AppText>
              <AppText variant="bodyStrong">{job.customer.name}</AppText>
            </View>
          </View>
        ) : null}

        {side === 'customer' ? <CustomerOffers job={job} offers={offers} onChanged={load} /> : null}
        {myOfferFull && myOfferFull.status !== 'withdrawn' ? <MyOffer offer={myOfferFull} onChanged={load} /> : null}

        {side === 'guest' || side === 'viewer' ? (
          <AppText variant="small" muted style={styles.privacy}>
            {t('ADDRESS_PRIVACY_NOTE')}
          </AppText>
        ) : null}
      </ScrollView>

      <JobActions job={job} side={side} myOffer={myOffer} offers={offers} isPro={isPro} />
    </View>
  );
}

// "Message <name>" about this job. Opens (or creates) the conversation.
function MessageButton({ person, jobId, variant = 'outline', small }) {
  const { t } = useI18n();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  if (!person?._id) return null;

  async function open() {
    setBusy(true);
    setError(null);
    try {
      await openChat({ participant: person._id, job: jobId });
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <ErrorBanner message={error} />
      <Button
        title={small ? t('MESSAGE') : t('MESSAGE_CUSTOMER', { name: person.name })}
        icon="chatbubble-outline"
        variant={variant}
        small={small}
        loading={busy}
        onPress={open}
        style={small ? { flexGrow: 1 } : undefined}
      />
    </>
  );
}

// Accepted first, then the ones waiting for an answer, then the rest. Withdrawn ones are hidden.
const OFFER_ORDER = { accepted: 0, pending: 1, rejected: 2, expired: 3 };
const sortOffers = (offers) =>
  offers
    .filter((o) => o.status !== 'withdrawn')
    .sort((a, b) => (OFFER_ORDER[a.status] ?? 9) - (OFFER_ORDER[b.status] ?? 9) || new Date(b.createdAt) - new Date(a.createdAt));

// The customer compares the offers and accepts or declines them
function CustomerOffers({ job, offers, onChanged }) {
  const { t } = useI18n();
  const [busy, setBusy] = useState(null); // `${offerId}:accept` | `${offerId}:reject`
  const [error, setError] = useState(null);
  const list = sortOffers(offers);
  const canChoose = job.status === 'open' && !job.contract;

  async function act(offer, action) {
    const name = offer.company?.name ?? offer.pro?.name ?? '';
    const ok = await confirm(
      action === 'accept'
        ? {
            title: t('ACCEPT_OFFER_TITLE'),
            message: t('ACCEPT_OFFER_TEXT', { name, price: offerPrice(offer).main }),
            confirmText: t('ACCEPT'),
          }
        : {
            title: t('DECLINE_OFFER_TITLE'),
            message: t('DECLINE_OFFER_TEXT', { name }),
            confirmText: t('DECLINE'),
            destructive: true,
          }
    );
    if (!ok) return;
    setBusy(`${offer._id}:${action}`);
    setError(null);
    try {
      await api(`/offers/${offer._id}/${action === 'accept' ? 'accept' : 'reject'}`, { method: 'POST' });
      await onChanged();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(null);
    }
  }

  return (
    <View style={[styles.section, { gap: spacing.md }]}>
      <View style={styles.sectionHead}>
        <AppText variant="title" style={{ flex: 1 }}>
          {t('OFFERS_TITLE')}
        </AppText>
        {list.length ? (
          <AppText variant="smallStrong" muted>
            {list.length}
          </AppText>
        ) : null}
      </View>

      {canChoose && list.some((o) => o.status === 'pending') ? (
        <AppText variant="small" muted>
          {t('OFFERS_COMPARE_HINT')}
        </AppText>
      ) : null}
      <ErrorBanner message={error} />

      {list.length ? (
        list.map((offer) => (
          <OfferCard key={offer._id} offer={offer}>
            {offer.status === 'pending' && canChoose ? (
              <>
                <Button
                  title={t('ACCEPT')}
                  icon="checkmark"
                  small
                  loading={busy === `${offer._id}:accept`}
                  disabled={Boolean(busy)}
                  onPress={() => act(offer, 'accept')}
                  style={{ flexGrow: 1 }}
                />
                <Button
                  title={t('DECLINE')}
                  variant="outline"
                  small
                  loading={busy === `${offer._id}:reject`}
                  disabled={Boolean(busy)}
                  onPress={() => act(offer, 'reject')}
                  style={{ flexGrow: 1 }}
                />
                <MessageButton person={offer.pro} jobId={job._id} variant="dark" small />
              </>
            ) : offer.status === 'accepted' ? (
              <MessageButton person={offer.pro} jobId={job._id} variant="dark" small />
            ) : null}
          </OfferCard>
        ))
      ) : (
        <View style={styles.noOffers}>
          <Ionicons name="hourglass-outline" size={20} color={colors.textMuted} />
          <AppText variant="small" muted style={{ flex: 1 }}>
            {t('CUSTOMER_WAITING_FOR_OFFERS')}
          </AppText>
        </View>
      )}
    </View>
  );
}

// The pro's own offer on someone else's job, with "Withdraw" while it's waiting
function MyOffer({ offer, onChanged }) {
  const { t } = useI18n();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  async function withdraw() {
    const ok = await confirm({
      title: t('WITHDRAW_OFFER_TITLE'),
      message: t('WITHDRAW_OFFER_TEXT'),
      confirmText: t('WITHDRAW'),
      destructive: true,
    });
    if (!ok) return;
    setBusy(true);
    setError(null);
    try {
      await api(`/offers/${offer._id}/withdraw`, { method: 'POST' });
      await onChanged();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <View style={styles.section}>
      <ErrorBanner message={error} />
      <OfferCard offer={offer} mine>
        {offer.status === 'pending' ? (
          <Button title={t('WITHDRAW_OFFER')} variant="danger" small loading={busy} onPress={withdraw} style={{ flexGrow: 1 }} />
        ) : null}
      </OfferCard>
    </View>
  );
}

// What the bar at the bottom shows depends on who's looking
function JobActions({ job, side, myOffer, offers, isPro }) {
  const { t } = useI18n();
  if (side === 'guest') {
    return (
      <BottomBar>
        <Button title={t('LOG_IN_TO_OFFER')} variant="dark" onPress={() => router.push('/login')} />
      </BottomBar>
    );
  }

  if (side === 'viewer') {
    // A withdrawn offer can be replaced by a new one
    if (myOffer && myOffer.status !== 'withdrawn') {
      return (
        <BottomBar>
          {myOffer.status === 'pending' ? (
            <View style={styles.note}>
              <Ionicons name="checkmark-circle" size={20} color={colors.pine} />
              <AppText variant="bodyStrong" color={colors.pine}>
                {t('OFFER_SENT_WAITING')}
              </AppText>
            </View>
          ) : null}
          <MessageButton person={job.customer} jobId={job._id} />
        </BottomBar>
      );
    }
    if (!isPro) {
      return (
        <BottomBar>
          <AppText variant="small" muted center>
            {t('ONLY_PROS_CAN_OFFER')}
          </AppText>
        </BottomBar>
      );
    }
    if (job.status !== 'open') return null;
    return (
      <BottomBar>
        <Button
          title={myOffer ? t('MAKE_NEW_OFFER') : t('MAKE_OFFER')}
          icon="document-text-outline"
          onPress={() => router.push({ pathname: '/offer/[jobId]', params: { jobId: job._id, title: job.title } })}
        />
      </BottomBar>
    );
  }

  // The pro doing the job
  if (side === 'pro') {
    return (
      <BottomBar>
        <MessageButton person={job.customer} jobId={job._id} variant="dark" />
      </BottomBar>
    );
  }

  if (side === 'customer') {
    // Once someone is hired, the chat with them is one tap away
    if (job.pro) {
      return (
        <BottomBar>
          <MessageButton person={job.pro} jobId={job._id} variant="dark" />
        </BottomBar>
      );
    }
    const waiting = offers.filter((o) => o.status === 'pending').length;
    return (
      <BottomBar>
        <AppText variant="small" muted center>
          {waiting ? t('CUSTOMER_CHOOSE_OFFER', { n: waiting }) : t('CUSTOMER_WAITING_FOR_OFFERS')}
        </AppText>
      </BottomBar>
    );
  }

  return null;
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  hero: {
    backgroundColor: colors.slate,
    paddingHorizontal: spacing.xl,
    paddingBottom: spacing.xxxl + spacing.lg, // room for the ticket to overlap
    gap: spacing.md,
  },
  category: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginTop: spacing.sm },
  categoryIcon: {
    width: 24,
    height: 24,
    borderRadius: 5,
    backgroundColor: colors.hivis,
    alignItems: 'center',
    justifyContent: 'center',
  },
  ticket: {
    marginTop: -spacing.xxxl,
    marginHorizontal: spacing.xl,
    backgroundColor: colors.paper,
    borderRadius: radius.ticket,
  },
  ticketTop: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, padding: spacing.lg },
  facts: { padding: spacing.lg, paddingTop: spacing.sm, gap: spacing.md },
  fact: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  factLabel: { width: 118 },
  section: { marginTop: spacing.xxl, marginHorizontal: spacing.xl, gap: spacing.sm, maxWidth: 640 },
  sectionHead: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  noOffers: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.lg,
    borderRadius: radius.ticket,
    borderWidth: 1.5,
    borderStyle: 'dashed',
    borderColor: colors.line,
  },
  person: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  privacy: { marginTop: spacing.xl, marginHorizontal: spacing.xl },
  note: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: spacing.sm, minHeight: 44 },
});
