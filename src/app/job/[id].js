// /qup-work-app/src/app/job/[id].js
// One job as a big work-order ticket. Public for open jobs; acting on it needs an account.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { useCallback, useState } from 'react';
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
import { Perforation } from '@/components/Perforation';
import { StatusBadge } from '@/components/StatusBadge';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { api, errorMessage } from '@/lib/api';
import { useI18n } from '@/i18n';
import { budgetText, categoryIcon, categoryName, formatDate, placeText, timeAgo, URGENCY } from '@/lib/format';

export default function JobScreen() {
  const { id } = useLocalSearchParams();
  const insets = useSafeAreaInsets();
  const { user, isPro } = useAuth();
  const { t } = useI18n();
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);

  // Reload when coming back from the offer form or login
  useFocusEffect(
    useCallback(() => {
      let alive = true;
      api(`/jobs/${id}`)
        .then((res) => alive && (setData(res), setError(null)))
        .catch((err) => alive && setError(errorMessage(err)));
      return () => {
        alive = false;
      };
    }, [id, user?._id])
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

  const { job, side, myOfferStatus } = data;
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

        {side === 'guest' || side === 'viewer' ? (
          <AppText variant="small" muted style={styles.privacy}>
            {t('ADDRESS_PRIVACY_NOTE')}
          </AppText>
        ) : null}
      </ScrollView>

      <JobActions job={job} side={side} myOfferStatus={myOfferStatus} isPro={isPro} />
    </View>
  );
}

// Opens (or creates) the conversation with the customer about this job
function MessageCustomerButton({ job, variant = 'outline' }) {
  const { t } = useI18n();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  if (!job.customer?._id) return null;

  async function open() {
    setBusy(true);
    setError(null);
    try {
      const res = await api('/conversations', {
        method: 'POST',
        body: { participant: job.customer._id, job: job._id },
      });
      router.push({ pathname: '/conversation/[id]', params: { id: res.conversation._id } });
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
        title={t('MESSAGE_CUSTOMER', { name: job.customer.name })}
        icon="chatbubble-outline"
        variant={variant}
        loading={busy}
        onPress={open}
      />
    </>
  );
}

// What the button at the bottom does depends on who's looking
function JobActions({ job, side, myOfferStatus, isPro }) {
  const { t } = useI18n();
  if (side === 'guest') {
    return (
      <BottomBar>
        <Button title={t('LOG_IN_TO_OFFER')} variant="dark" onPress={() => router.push('/login')} />
      </BottomBar>
    );
  }

  if (side === 'viewer') {
    if (myOfferStatus) {
      return (
        <BottomBar>
          <View style={styles.note}>
            <Ionicons name="checkmark-circle" size={20} color={colors.pine} />
            <AppText variant="bodyStrong" color={colors.pine}>
              {t('OFFER_ALREADY_SENT')}
            </AppText>
          </View>
          <MessageCustomerButton job={job} />
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
    return (
      <BottomBar>
        <Button
          title={t('MAKE_OFFER')}
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
        <MessageCustomerButton job={job} variant="dark" />
      </BottomBar>
    );
  }

  if (side === 'customer') {
    return (
      <BottomBar>
        <AppText variant="small" muted center>
          {job.offerCount ? t('CUSTOMER_OFFERS_RECEIVED', { n: job.offerCount }) : t('CUSTOMER_WAITING_FOR_OFFERS')}
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
  person: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  privacy: { marginTop: spacing.xl, marginHorizontal: spacing.xl },
  note: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: spacing.sm, minHeight: 44 },
});
