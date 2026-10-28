// /qup-work-app/src/app/my-offers.js
// As a pro: every offer I've sent, newest activity first, filtered by status.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { FlatList, Pressable, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton } from '@/components/BackButton';
import { ChoiceChips } from '@/components/ChoiceChips';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { Perforation } from '@/components/Perforation';
import { SignInPrompt } from '@/components/SignInPrompt';
import { StatusBadge } from '@/components/StatusBadge';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { categoryIcon, categoryName, offerPrice, placeText, timeAgo } from '@/lib/format';
import { usePaged } from '@/lib/usePaged';

const FILTERS = [
  { value: '', label: 'ALL' },
  { value: 'pending', label: 'OFFER_STATUS_PENDING' },
  { value: 'accepted', label: 'OFFER_STATUS_ACCEPTED' },
  { value: 'rejected,expired,withdrawn', label: 'OFFERS_FILTER_CLOSED' },
];

export default function MyOffersScreen() {
  const insets = useSafeAreaInsets();
  const { user } = useAuth();
  const { t } = useI18n();
  const [filter, setFilter] = useState('');
  const list = usePaged(`/offers/mine${filter ? `?status=${filter}` : ''}`, { enabled: Boolean(user) });

  // Refresh when coming back (an offer may have been withdrawn or accepted meanwhile)
  useFocusEffect(
    useCallback(() => {
      if (user) list.reload();
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [user?._id])
  );

  const header = (
    <View style={[styles.header, { paddingTop: insets.top + spacing.md }]}>
      <BackButton />
      <AppText variant="h1" accessibilityRole="header">
        {t('MY_OFFERS')}
      </AppText>
      {user ? (
        <ChoiceChips options={FILTERS.map((f) => ({ ...f, label: t(f.label) }))} value={filter} onChange={setFilter} />
      ) : null}
    </View>
  );

  if (!user) {
    return (
      <View style={styles.screen}>
        {header}
        <SignInPrompt icon="document-text-outline" title={t('MY_OFFERS')} text={t('MY_OFFERS_GUEST_TEXT')} />
      </View>
    );
  }

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="dark" />
      {header}
      {list.status === 'loading' ? (
        <Loading />
      ) : (
        <FlatList
          data={list.items}
          keyExtractor={(o) => o._id}
          renderItem={({ item }) => <OfferRow offer={item} />}
          contentContainerStyle={styles.list}
          ItemSeparatorComponent={() => <View style={{ height: spacing.md }} />}
          onEndReached={list.loadMore}
          refreshing={list.refreshing}
          onRefresh={list.refresh}
          ListHeaderComponent={
            list.error ? <ErrorBanner message={list.error} onRetry={list.reload} style={{ marginBottom: spacing.md }} /> : null
          }
          ListEmptyComponent={
            list.error ? null : (
              <EmptyState
                icon="document-text-outline"
                title={filter ? t('NO_OFFERS_IN_FILTER') : t('NO_OFFERS_SENT')}
                text={filter ? null : t('NO_OFFERS_SENT_TEXT')}
                actionTitle={filter ? null : t('SEE_JOBS')}
                onAction={() => router.push('/jobs')}
              />
            )
          }
        />
      )}
    </View>
  );
}

// A small ticket: the job on top, my price and the status on the stub
function OfferRow({ offer }) {
  const { t } = useI18n();
  const job = offer.job;
  const price = offerPrice(offer);
  const open = () => job?._id && router.push({ pathname: '/job/[id]', params: { id: job._id } });

  return (
    <Pressable
      onPress={open}
      disabled={!job}
      accessibilityRole="button"
      style={({ pressed }) => [styles.ticket, pressed && { transform: [{ scale: 0.985 }] }]}
    >
      <View style={styles.main}>
        {job?.category ? (
          <View style={styles.category}>
            <View style={styles.categoryIcon}>
              <Ionicons name={categoryIcon(job.category.icon)} size={13} color={colors.slate} />
            </View>
            <AppText variant="caption" muted>
              {categoryName(job.category)}
            </AppText>
          </View>
        ) : null}
        <AppText variant="title" numberOfLines={2}>
          {job?.title ?? t('JOB_NOT_FOUND')}
        </AppText>
        <AppText variant="small" muted>
          {[job ? placeText(job) : null, t('SENT_AGO', { time: timeAgo(offer.createdAt) })].filter(Boolean).join(' · ')}
        </AppText>
      </View>

      <Perforation notchColor={colors.concrete} />

      <View style={styles.stub}>
        <View style={{ flex: 1, gap: 2 }}>
          <AppText variant="price" numberOfLines={1}>
            {price.main}
          </AppText>
          <AppText variant="caption" muted numberOfLines={1}>
            {price.sub}
          </AppText>
        </View>
        <StatusBadge status={offer.status} kind="offer" />
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  header: { paddingHorizontal: spacing.xl, gap: spacing.md, paddingBottom: spacing.md },
  list: { padding: spacing.xl, paddingTop: spacing.sm, flexGrow: 1 },
  ticket: { backgroundColor: colors.paper, borderRadius: radius.ticket },
  main: { padding: spacing.lg, paddingBottom: spacing.md, gap: spacing.sm },
  category: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  categoryIcon: {
    width: 20,
    height: 20,
    borderRadius: 4,
    backgroundColor: colors.hivis,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stub: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.sm,
    paddingBottom: spacing.lg,
  },
});
