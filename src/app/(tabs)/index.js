// /qup-work-app/src/app/(tabs)/index.js
// Utforsk: the front door. Works for guests, customers and pros.
import { router } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { RefreshControl, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { Button } from '@/components/Button';
import { CategoryChips } from '@/components/CategoryChips';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { JobTicket } from '@/components/JobTicket';
import { ProCard } from '@/components/ProCard';
import { SearchBar } from '@/components/SearchBar';
import { SectionHeader } from '@/components/SectionHeader';
import { colors, fonts, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { api, errorMessage } from '@/lib/api';
import { useCategories } from '@/lib/categories';
import { useRequireLogin } from '@/lib/useRequireLogin';

export default function ExploreScreen() {
  const insets = useSafeAreaInsets();
  const { user } = useAuth();
  const requireLogin = useRequireLogin();
  const { roots: categories } = useCategories();
  const isProMode = user?.activeRole === 'pro';

  const [query, setQuery] = useState('');
  const [jobs, setJobs] = useState([]);
  const [pros, setPros] = useState([]);
  const [error, setError] = useState(null);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    try {
      const [jobRes, proRes] = await Promise.all([api('/jobs/feed?limit=4'), api('/pros?limit=8')]);
      setJobs(jobRes.data);
      setPros(proRes.data);
      setError(null);
    } catch (err) {
      setError(errorMessage(err));
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function onRefresh() {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  }

  // Customers search for people, pros search for work
  const searchTarget = isProMode ? '/jobs' : '/pros';
  const search = (q) => router.push({ pathname: searchTarget, params: { q } });
  const openCategory = (id) => router.push({ pathname: searchTarget, params: id ? { category: id } : {} });

  return (
    <ScrollView
      style={styles.screen}
      contentContainerStyle={{ paddingBottom: spacing.xxxl }}
      keyboardShouldPersistTaps="handled"
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={colors.hivis} />}
    >
      <FocusStatusBar style="light" />

      {/* Slate hero */}
      <View style={[styles.hero, { paddingTop: insets.top + spacing.lg }]}>
        <View style={styles.topRow}>
          <View style={styles.brand}>
            <View style={styles.brandMark} />
            <AppText onDark style={styles.brandText}>
              Qup Work
            </AppText>
          </View>
          {user ? (
            <Avatar name={user.name} url={user.avatarUrl} size={36} />
          ) : (
            <Button title="Logg inn" variant="outlineOnDark" small onPress={() => router.push('/login')} />
          )}
        </View>

        <View style={styles.heroText}>
          <AppText variant="display" onDark accessibilityRole="header">
            {isProMode ? 'Finn neste oppdrag' : 'Hva skal gjøres?'}
          </AppText>
          <AppText variant="body" onDark muted>
            {isProMode
              ? 'Åpne jobber fra folk i nærheten, klare for tilbud.'
              : 'Elektriker, snekker, maler eller utvikler. Beskriv jobben og få tilbud.'}
          </AppText>
        </View>

        <View style={styles.heroSearch}>
          <SearchBar
            value={query}
            onChangeText={setQuery}
            onSubmit={(q) => q && search(q)}
            placeholder={isProMode ? 'Søk i oppdrag' : 'Søk etter fagfolk'}
            onDark
          />
          {!isProMode ? (
            <Button
              title="Legg ut en jobb"
              icon="add"
              onPress={() => requireLogin(() => router.push('/new-job'))}
            />
          ) : null}
        </View>

        <CategoryChips categories={categories} selected={null} onSelect={openCategory} onDark style={styles.heroChips} />
      </View>

      <ErrorBanner message={error} onRetry={load} style={{ margin: spacing.xl, marginBottom: 0 }} />

      {/* Latest jobs */}
      <View style={styles.section}>
        <SectionHeader title="Nye oppdrag" actionTitle="Se alle" onAction={() => router.push('/jobs')} />
        <View style={styles.list}>
          {jobs.map((job) => (
            <JobTicket key={job._id} job={job} onPress={() => router.push(`/job/${job._id}`)} />
          ))}
          {!jobs.length && !error ? (
            <AppText variant="small" muted>
              Ingen åpne oppdrag akkurat nå.
            </AppText>
          ) : null}
        </View>
      </View>

      {/* Pros */}
      {pros.length ? (
        <View style={styles.section}>
          <SectionHeader title="Fagfolk" actionTitle="Se alle" onAction={() => router.push('/pros')} />
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.proRow}>
            {pros.map((pro) => (
              <ProCard key={pro._id} pro={pro} compact onPress={() => router.push(`/pro/${pro.user?._id}`)} />
            ))}
          </ScrollView>
        </View>
      ) : null}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  hero: { backgroundColor: colors.slate, paddingBottom: spacing.xl, gap: spacing.xl },
  topRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: spacing.xl },
  brand: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  brandMark: { width: 14, height: 14, backgroundColor: colors.hivis, transform: [{ rotate: '45deg' }] },
  brandText: { fontFamily: fonts.heavy, fontSize: 18, letterSpacing: -0.3 },
  heroText: { gap: spacing.sm, paddingHorizontal: spacing.xl, maxWidth: 560 },
  heroSearch: { gap: spacing.md, paddingHorizontal: spacing.xl },
  heroChips: { paddingTop: spacing.xs },
  section: { gap: spacing.md, marginTop: spacing.xxl },
  list: { gap: spacing.md, paddingHorizontal: spacing.xl },
  proRow: { gap: spacing.md, paddingHorizontal: spacing.xl },
});
