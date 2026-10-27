// /qup-work-app/src/app/my-jobs.js
// As a customer: the jobs I've posted. As a pro: the jobs I'm working on.
import { router, useFocusEffect } from 'expo-router';
import { useCallback } from 'react';
import { FlatList, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton } from '@/components/BackButton';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { JobTicket } from '@/components/JobTicket';
import { Loading } from '@/components/Loading';
import { SignInPrompt } from '@/components/SignInPrompt';
import { colors, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { usePaged } from '@/lib/usePaged';

export default function MyJobsScreen() {
  const insets = useSafeAreaInsets();
  const { user } = useAuth();
  const { t } = useI18n();
  const isProMode = user?.activeRole === 'pro';
  const list = usePaged(`/jobs?role=${isProMode ? 'pro' : 'customer'}`, { enabled: Boolean(user) });

  // Refresh when coming back (e.g. after posting a job)
  useFocusEffect(
    useCallback(() => {
      if (user) list.reload();
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [user?._id, isProMode])
  );

  const header = (
    <View style={[styles.header, { paddingTop: insets.top + spacing.md }]}>
      <BackButton />
      <AppText variant="h1" accessibilityRole="header">
        {isProMode ? t('MY_ASSIGNMENTS') : t('MY_JOBS')}
      </AppText>
    </View>
  );

  if (!user) {
    return (
      <View style={styles.screen}>
        {header}
        <SignInPrompt icon="briefcase-outline" title={t('MY_JOBS_GUEST_TITLE')} text={t('MY_JOBS_GUEST_TEXT')} />
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
          keyExtractor={(job) => job._id}
          renderItem={({ item }) => <JobTicket job={item} showStatus onPress={() => router.push(`/job/${item._id}`)} />}
          contentContainerStyle={styles.list}
          ItemSeparatorComponent={() => <View style={{ height: spacing.md }} />}
          onEndReached={list.loadMore}
          refreshing={list.refreshing}
          onRefresh={list.refresh}
          ListHeaderComponent={list.error ? <ErrorBanner message={list.error} onRetry={list.reload} style={{ marginBottom: spacing.md }} /> : null}
          ListEmptyComponent={
            list.error ? null : isProMode ? (
              <EmptyState
                icon="construct-outline"
                title={t('NO_ASSIGNMENTS')}
                text={t('NO_ASSIGNMENTS_TEXT')}
                actionTitle={t('SEE_JOBS')}
                onAction={() => router.push('/jobs')}
              />
            ) : (
              <EmptyState
                icon="briefcase-outline"
                title={t('NO_JOBS')}
                text={t('NO_JOBS_TEXT')}
                actionTitle={t('POST_JOB')}
                onAction={() => router.push('/new-job')}
              />
            )
          }
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  header: { paddingHorizontal: spacing.xl, gap: spacing.md, paddingBottom: spacing.md },
  list: { padding: spacing.xl, paddingTop: spacing.sm, flexGrow: 1 },
});
