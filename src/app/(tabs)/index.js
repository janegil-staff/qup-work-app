// /qup-work-app/src/app/(tabs)/index.js
// Utforsk: the landing page. Open to everyone; adapts when you're in pro mode.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { Pressable, RefreshControl, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { NotificationBell } from '@/components/NotificationBell';
import { TimerBanner } from '@/components/TimerBanner';
import { Avatar } from '@/components/Avatar';
import { Blueprint } from '@/components/Blueprint';
import { Button } from '@/components/Button';
import { CategoryTile } from '@/components/CategoryTile';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { JobTicket } from '@/components/JobTicket';
import { ProTile } from '@/components/ProTile';
import { SearchBar } from '@/components/SearchBar';
import { colors, fonts, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { api, errorMessage } from '@/lib/api';
import { useI18n } from '@/i18n';
import { useCategories } from '@/lib/categories';
import { categoryName } from '@/lib/format';
import { useRequireLogin } from '@/lib/useRequireLogin';

const STEPS = [
  ['STEP_1_TITLE', 'STEP_1_TEXT'],
  ['STEP_2_TITLE', 'STEP_2_TEXT'],
  ['STEP_3_TITLE', 'STEP_3_TEXT'],
];

// Only promises the app keeps today
const TRUST = [
  ['star-outline', 'TRUST_REVIEWS'],
  ['shield-checkmark-outline', 'TRUST_VERIFIED'],
  ['hand-left-outline', 'TRUST_FREE'],
];

export default function ExploreScreen() {
  const insets = useSafeAreaInsets();
  const { user, isPro } = useAuth();
  const { t, language } = useI18n();
  const requireLogin = useRequireLogin();
  const { roots, childrenOf } = useCategories();
  const isProMode = user?.activeRole === 'pro';

  const [query, setQuery] = useState('');
  const [jobs, setJobs] = useState([]);
  const [pros, setPros] = useState([]);
  const [showAllCategories, setShowAllCategories] = useState(false);
  const [error, setError] = useState(null);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    try {
      const [jobRes, proRes] = await Promise.all([api('/jobs/feed?limit=3'), api('/pros?limit=8')]);
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

  // Customers look for people, pros look for work
  const searchTarget = isProMode ? '/jobs' : '/pros';
  const openCategory = (id) => router.push({ pathname: searchTarget, params: { category: id } });
  const categories = showAllCategories ? roots : roots.slice(0, 6);
  const examples = (id) =>
    childrenOf(id)
      .slice(0, 3)
      .map((c, i) => (i === 0 ? categoryName(c) : categoryName(c).toLocaleLowerCase()))
      .join(', ');

  return (
    <ScrollView
      style={styles.screen}
      contentContainerStyle={{ paddingBottom: spacing.xxxl }}
      keyboardShouldPersistTaps="handled"
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={colors.hivis} />}
    >
      <FocusStatusBar style="light" />

      {/* HERO */}
      <View style={[styles.hero, { paddingTop: insets.top + spacing.lg }]}>
        <Blueprint />
        <View style={styles.topRow}>
          <View style={styles.brand}>
            <View style={styles.brandMark} />
            <AppText onDark style={styles.brandText}>
              Qup Work
            </AppText>
          </View>
          <View style={styles.topActions}>
            <Pressable
              onPress={() => router.push('/language')}
              accessibilityRole="button"
              accessibilityLabel={t('LANGUAGE')}
              hitSlop={8}
              style={styles.languageButton}
            >
              <Ionicons name="globe-outline" size={18} color={colors.textOnDark} />
              <AppText variant="smallStrong" onDark>
                {language.code.slice(0, 2).toUpperCase()}
              </AppText>
            </Pressable>
            <NotificationBell onDark />
            {user ? (
              <Pressable onPress={() => router.push('/profile')} accessibilityLabel={t('TAB_PROFILE')} hitSlop={8}>
                <Avatar name={user.name} url={user.avatarUrl} size={36} />
              </Pressable>
            ) : (
              <Pressable onPress={() => router.push('/login')} accessibilityRole="button" hitSlop={10}>
                <AppText variant="bodyStrong" onDark style={styles.underline}>
                  {t('LOG_IN')}
                </AppText>
              </Pressable>
            )}
          </View>
        </View>

        <TimerBanner onDark style={{ marginHorizontal: spacing.xl, marginTop: spacing.lg }} />

        <View style={styles.heroText}>
          <AppText onDark style={styles.headline} accessibilityRole="header">
            {isProMode ? t('HERO_TITLE_PRO') : t('HERO_TITLE')}
          </AppText>
          <AppText variant="body" onDark muted style={styles.lede}>
            {isProMode ? t('HERO_TEXT_PRO') : t('HERO_TEXT')}
          </AppText>
        </View>

        {/* room for the drawing */}
        <View style={{ height: 236 }} />
      </View>

      {/* Search card, overlapping the hero */}
      <View style={styles.searchCard}>
        <SearchBar
          value={query}
          onChangeText={setQuery}
          onSubmit={(q) => q && router.push({ pathname: searchTarget, params: { q } })}
          placeholder={isProMode ? t('SEARCH_JOBS') : t('SEARCH_PROS')}
          filled
        />
        {isProMode ? (
          <Button title={t('SEE_ALL_OPEN_JOBS')} icon="clipboard-outline" onPress={() => router.push('/jobs')} />
        ) : (
          <Button title={t('POST_JOB_FREE')} icon="add" onPress={() => requireLogin(() => router.push('/new-job'))} />
        )}
      </View>

      <ErrorBanner message={error} onRetry={load} style={{ marginHorizontal: spacing.xl, marginTop: spacing.xl }} />

      {/* Categories */}
      {roots.length ? (
        <View style={styles.section}>
          <AppText variant="h1" style={styles.sectionTitle} accessibilityRole="header">
            {isProMode ? t('CATEGORIES_TITLE_PRO') : t('CATEGORIES_TITLE')}
          </AppText>
          <View style={styles.tiles}>
            {categories.map((c) => (
              <CategoryTile key={c._id} category={c} examples={examples(c._id)} onPress={() => openCategory(c._id)} />
            ))}
          </View>
          {roots.length > 6 ? (
            <Pressable onPress={() => setShowAllCategories((v) => !v)} accessibilityRole="button" hitSlop={8}>
              <AppText variant="smallStrong" style={[styles.underline, { alignSelf: 'flex-start' }]}>
                {showAllCategories ? t('SHOW_LESS') : t('ALL_CATEGORIES', { n: roots.length })}
              </AppText>
            </Pressable>
          ) : null}
        </View>
      ) : null}

      {/* Latest jobs */}
      {jobs.length ? (
        <View style={styles.section}>
          <View style={styles.sectionHead}>
            <View style={{ flex: 1, gap: 2 }}>
              <AppText variant="h1" style={styles.sectionTitle} accessibilityRole="header">
                {t('NEW_JOBS')}
              </AppText>
              <AppText variant="small" muted>
                {t('NEW_JOBS_TEXT')}
              </AppText>
            </View>
            <Pressable onPress={() => router.push('/jobs')} accessibilityRole="link" hitSlop={10}>
              <AppText variant="smallStrong" style={styles.underline}>
                {t('SEE_ALL')}
              </AppText>
            </Pressable>
          </View>
          {jobs.map((job) => (
            <JobTicket key={job._id} job={job} onPress={() => router.push(`/job/${job._id}`)} />
          ))}
        </View>
      ) : null}

      {/* How it works (a real sequence, so it's numbered) */}
      {!isProMode ? (
        <View style={styles.section}>
          <AppText variant="h1" style={styles.sectionTitle} accessibilityRole="header">
            {t('HOW_IT_WORKS')}
          </AppText>
          <View>
            {STEPS.map(([title, text], i) => (
              <View key={title} style={styles.step}>
                <View style={{ alignItems: 'center' }}>
                  <View style={styles.stepNumber}>
                    <AppText style={styles.stepNumberText} color={colors.hivis}>
                      {i + 1}
                    </AppText>
                  </View>
                  {i < STEPS.length - 1 ? <View style={styles.stepLine} /> : null}
                </View>
                <View style={[styles.stepBody, i < STEPS.length - 1 && { paddingBottom: spacing.xl }]}>
                  <AppText variant="title">{t(title)}</AppText>
                  <AppText variant="small" muted>
                    {t(text)}
                  </AppText>
                </View>
              </View>
            ))}
          </View>
        </View>
      ) : null}

      {/* Featured pros */}
      {pros.length ? (
        <View style={[styles.section, { paddingHorizontal: 0 }]}>
          <View style={[styles.sectionHead, { paddingHorizontal: spacing.xl }]}>
            <AppText variant="h1" style={[styles.sectionTitle, { flex: 1 }]} accessibilityRole="header">
              {t('TOP_RATED_PROS')}
            </AppText>
          </View>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.proRow}>
            {pros.map((pro) => (
              <ProTile key={pro._id} pro={pro} onPress={() => router.push(`/pro/${pro.user?._id}`)} />
            ))}
          </ScrollView>
          <Pressable
            onPress={() => router.push('/pros')}
            accessibilityRole="link"
            hitSlop={8}
            style={{ paddingHorizontal: spacing.xl }}
          >
            <AppText variant="smallStrong" style={[styles.underline, { alignSelf: 'flex-start' }]}>
              {t('SEE_ALL_PROS')}
            </AppText>
          </Pressable>
        </View>
      ) : null}

      {/* Trust + invitation to pros */}
      {!isProMode ? (
        <View style={[styles.section, { gap: spacing.lg }]}>
          <View style={styles.trust}>
            {TRUST.map(([icon, text]) => (
              <View key={text} style={styles.trustRow}>
                <Ionicons name={icon} size={24} color={colors.pine} />
                <AppText variant="bodyStrong" style={{ flex: 1, fontSize: 15 }}>
                  {t(text)}
                </AppText>
              </View>
            ))}
          </View>

          {!isPro ? (
            <View style={styles.invite}>
              <AppText variant="h2" onDark>
                {t('PRO_INVITE_TITLE')}
              </AppText>
              <AppText variant="small" onDark muted style={{ maxWidth: 300 }}>
                {t('PRO_INVITE_TEXT')}
              </AppText>
              <Button
                title={t('BECOME_PRO')}
                small
                style={{ alignSelf: 'flex-start', marginTop: spacing.xs }}
                onPress={() => (user ? router.push('/profile') : router.push('/register'))}
              />
            </View>
          ) : null}
        </View>
      ) : null}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },

  hero: { backgroundColor: colors.slate, overflow: 'hidden' },
  topRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.xl,
  },
  brand: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  topActions: { flexDirection: 'row', alignItems: 'center', gap: spacing.lg },
  languageButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    height: 32,
    paddingHorizontal: 10,
    borderRadius: radius.pill,
    backgroundColor: colors.slateRaised,
  },
  brandMark: { width: 14, height: 14, backgroundColor: colors.hivis, transform: [{ rotate: '45deg' }] },
  brandText: { fontFamily: fonts.heavy, fontSize: 18, letterSpacing: -0.3 },
  heroText: { gap: spacing.md, paddingHorizontal: spacing.xl, marginTop: spacing.xxl, maxWidth: 520 },
  headline: { fontFamily: fonts.heavy, fontSize: 44, lineHeight: 47, letterSpacing: -1.6 },
  lede: { fontSize: 17, lineHeight: 25, maxWidth: 360 },

  searchCard: {
    marginTop: -58,
    marginHorizontal: spacing.xl,
    backgroundColor: colors.paper,
    borderRadius: radius.lg,
    padding: spacing.lg,
    gap: spacing.md,
    shadowColor: colors.slate,
    shadowOpacity: 0.18,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 12 },
    elevation: 8,
  },

  section: { marginTop: 40, paddingHorizontal: spacing.xl, gap: spacing.md },
  sectionHead: { flexDirection: 'row', alignItems: 'flex-end', gap: spacing.md },
  sectionTitle: { fontSize: 24, lineHeight: 28, letterSpacing: -0.5 },
  underline: { borderBottomWidth: 2, borderBottomColor: colors.hivis, paddingBottom: 1 },
  tiles: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },

  step: { flexDirection: 'row', gap: spacing.lg },
  stepNumber: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: colors.slate,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stepNumberText: { fontFamily: fonts.heavy, fontSize: 17, lineHeight: 20 },
  stepLine: { width: 2, flex: 1, backgroundColor: colors.line, marginTop: 6 },
  stepBody: { flex: 1, gap: 4, paddingTop: spacing.sm },

  proRow: { gap: spacing.md, paddingHorizontal: spacing.xl },

  trust: { backgroundColor: colors.paper, borderRadius: radius.lg, padding: spacing.xl, gap: spacing.lg },
  trustRow: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  invite: { backgroundColor: colors.slate, borderRadius: radius.lg, padding: 22, gap: spacing.md },
});
