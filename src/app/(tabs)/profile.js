// /qup-work-app/src/app/(tabs)/profile.js
import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { useState } from 'react';
import { Alert, Platform, Pressable, ScrollView, StyleSheet, Switch, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { Button } from '@/components/Button';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Rating } from '@/components/Rating';
import { ScreenHeader } from '@/components/ScreenHeader';
import { SignInPrompt } from '@/components/SignInPrompt';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { errorMessage } from '@/lib/api';
import { useI18n } from '@/i18n';
import { formatNok } from '@/lib/format';

const COMPANY_ROLE = { owner: 'ROLE_OWNER', admin: 'ROLE_ADMIN', worker: 'ROLE_WORKER' };

export default function ProfileScreen() {
  const { session } = useAuth();
  const { t } = useI18n();

  if (!session) {
    return (
      <View style={styles.screen}>
        <FocusStatusBar style="dark" />
        <ScreenHeader title={t('TAB_PROFILE')} />
        <SignInPrompt icon="person-outline" title={t('PROFILE_GUEST_TITLE')} text={t('PROFILE_GUEST_TEXT')} />
        <View style={{ padding: spacing.xl }}>
          <View style={styles.group}>
            <LanguageRow />
          </View>
        </View>
      </View>
    );
  }
  return <MyProfile />;
}

function MyProfile() {
  const insets = useSafeAreaInsets();
  const { session, isPro, logout, setActiveRole } = useAuth();
  const { t } = useI18n();
  const [switching, setSwitching] = useState(false);
  const [error, setError] = useState(null);
  const { user, companies, proProfile } = session;
  const isProMode = user.activeRole === 'pro';

  async function toggleMode(value) {
    setSwitching(true);
    setError(null);
    try {
      await setActiveRole(value ? 'pro' : 'customer');
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSwitching(false);
    }
  }

  function confirmLogout() {
    if (Platform.OS === 'web') {
      if (globalThis.confirm?.(`${t('LOG_OUT')}? ${t('LOG_OUT_ALL_DEVICES')}`)) logout();
      return;
    }
    Alert.alert(t('LOG_OUT'), t('LOG_OUT_ALL_DEVICES'), [
      { text: t('CANCEL'), style: 'cancel' },
      { text: t('LOG_OUT'), style: 'destructive', onPress: logout },
    ]);
  }

  return (
    <ScrollView style={styles.screen} contentContainerStyle={{ paddingBottom: spacing.xxxl }}>
      <FocusStatusBar style="light" />

      <View style={[styles.hero, { paddingTop: insets.top + spacing.xl }]}>
        <Avatar name={user.name} url={user.avatarUrl} size={72} />
        <View style={{ gap: 2 }}>
          <AppText variant="h1" onDark>
            {user.name}
          </AppText>
          <AppText variant="small" onDark muted>
            {user.email}
          </AppText>
        </View>
        {proProfile ? <Rating avg={proProfile.stats.ratingAvg} count={proProfile.stats.ratingCount} onDark /> : null}
      </View>

      <View style={styles.body}>
        <ErrorBanner message={error} />

        <View style={styles.group}>
          <MenuRow
            icon="briefcase-outline"
            title={isProMode ? t('MY_ASSIGNMENTS') : t('MY_JOBS')}
            onPress={() => router.push('/my-jobs')}
          />
          {isPro ? (
            <MenuRow icon="document-text-outline" title={t('MY_OFFERS')} onPress={() => router.push('/my-offers')} />
          ) : null}
          {!isProMode ? <MenuRow icon="add-circle-outline" title={t('POST_JOB')} onPress={() => router.push('/new-job')} /> : null}
          {isPro ? (
            <View style={styles.menuRow}>
              <Ionicons name="construct-outline" size={22} color={colors.slate} />
              <View style={{ flex: 1 }}>
                <AppText variant="bodyStrong">{t('PRO_MODE')}</AppText>
                <AppText variant="small" muted>
                  {isProMode ? t('PRO_MODE_ON') : t('PRO_MODE_OFF')}
                </AppText>
              </View>
              <Switch
                value={isProMode}
                onValueChange={toggleMode}
                disabled={switching}
                trackColor={{ true: colors.slate, false: colors.line }}
                thumbColor={isProMode ? colors.hivis : colors.paper}
                ios_backgroundColor={colors.line}
              />
            </View>
          ) : null}
        </View>

        {companies.length ? (
          <View style={styles.group}>
            {companies.map((c) => (
              <View key={c._id} style={styles.menuRow}>
                <Avatar name={c.name} url={c.logoUrl} size={40} dark />
                <View style={{ flex: 1 }}>
                  <AppText variant="bodyStrong">{c.name}</AppText>
                  <AppText variant="small" muted>
                    {t(COMPANY_ROLE[c.role])}
                    {c.orgNumber ? `, ${t('ORG_NUMBER_SHORT', { n: c.orgNumber })}` : ''}
                  </AppText>
                </View>
              </View>
            ))}
          </View>
        ) : null}

        {proProfile ? (
          <View style={[styles.group, styles.stats]}>
            <Stat value={String(proProfile.stats.completedJobs)} label={t('STAT_COMPLETED_JOBS')} />
            <Stat value={proProfile.hourlyRate ? formatNok(proProfile.hourlyRate) : '–'} label={t('STAT_HOURLY_RATE')} />
            <Stat value={proProfile.availableForMarketplace ? t('YES') : t('NO')} label={t('STAT_VISIBLE')} />
          </View>
        ) : null}

        {!isPro ? (
          <View style={[styles.group, styles.proInvite]}>
            <AppText variant="title">{t('PRO_INVITE_TITLE')}</AppText>
            <AppText variant="small" muted>
              {t('PRO_INVITE_PROFILE_TEXT')}
            </AppText>
          </View>
        ) : null}

        <View style={styles.group}>
          <LanguageRow />
        </View>

        <Button title={t('LOG_OUT')} variant="danger" onPress={confirmLogout} />
      </View>
    </ScrollView>
  );
}

function LanguageRow() {
  const { t, language } = useI18n();
  return (
    <Pressable
      onPress={() => router.push('/language')}
      accessibilityRole="button"
      style={({ pressed }) => [styles.menuRow, styles.lastRow, pressed && { opacity: 0.7 }]}
    >
      <Ionicons name="globe-outline" size={22} color={colors.slate} />
      <AppText variant="bodyStrong" style={{ flex: 1 }}>
        {t('LANGUAGE')}
      </AppText>
      <AppText variant="small" muted>
        {language.flag} {language.name}
      </AppText>
      <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
    </Pressable>
  );
}

function MenuRow({ icon, title, onPress }) {
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      style={({ pressed }) => [styles.menuRow, pressed && { opacity: 0.7 }]}
    >
      <Ionicons name={icon} size={22} color={colors.slate} />
      <AppText variant="bodyStrong" style={{ flex: 1 }}>
        {title}
      </AppText>
      <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
    </Pressable>
  );
}

function Stat({ value, label }) {
  return (
    <View style={styles.stat}>
      <AppText variant="h2">{value}</AppText>
      <AppText variant="caption" muted>
        {label}
      </AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  hero: { backgroundColor: colors.slate, padding: spacing.xl, gap: spacing.md },
  body: { padding: spacing.xl, gap: spacing.lg },
  group: { backgroundColor: colors.paper, borderRadius: radius.lg, paddingHorizontal: spacing.lg },
  menuRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    minHeight: 60,
    paddingVertical: spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.line,
  },
  lastRow: { borderBottomWidth: 0 },
  stats: { flexDirection: 'row', paddingVertical: spacing.lg },
  stat: { flex: 1, gap: 2 },
  proInvite: { paddingVertical: spacing.lg, gap: spacing.xs, borderLeftWidth: 4, borderLeftColor: colors.hivis },
});
