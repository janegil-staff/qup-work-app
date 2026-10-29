// /qup-work-app/src/app/edit-pro.js
// Edit your public pro profile: what you do, where, your rate, and whether
// customers can find you. Same fields as step 2 and 3 of "Become a pro".
import { router } from 'expo-router';
import { useEffect, useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, Switch, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton, goBackOr } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { Button } from '@/components/Button';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { AreaFields, ServiceFields, toOre, validateServices } from '@/components/ProFields';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { api, ApiError, errorMessage } from '@/lib/api';

const kroner = (ore) => (ore ? String(ore / 100).replace('.', ',') : '');

export default function EditProScreen() {
  const insets = useSafeAreaInsets();
  const { user, refreshSession } = useAuth();
  const { t } = useI18n();
  const [loaded, setLoaded] = useState(false);
  const [missing, setMissing] = useState(false);
  const [services, setServices] = useState(null);
  const [area, setArea] = useState(null);
  const [visible, setVisible] = useState(true);
  const [errors, setErrors] = useState({});
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    if (!user) return;
    api('/pros/me')
      .then(({ profile: p }) => {
        setServices({
          categories: (p.categories ?? []).map((c) => c._id ?? c),
          headline: p.headline ?? '',
          bio: p.bio ?? '',
          hourlyRate: kroner(p.hourlyRate),
          workType: p.workType ?? 'onsite',
        });
        // The postcode isn't stored; show the saved place until a new postcode is typed
        const place = p.serviceArea?.municipalities?.[0] ? { city: p.serviceArea.municipalities[0], location: p.serviceArea.location } : null;
        setArea({ postalCode: '', place, radiusKm: p.serviceArea?.radiusKm ?? 25 });
        setVisible(Boolean(p.availableForMarketplace));
      })
      .catch((err) => {
        if (err instanceof ApiError && err.status === 404) setMissing(true);
        else setError(errorMessage(err));
      })
      .finally(() => setLoaded(true));
  }, [user]);

  if (!loaded) return <Loading />;
  if (missing) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl }]}>
        <BackButton />
        <EmptyState icon="construct-outline" title={t('NO_PRO_PROFILE')} text={t('NO_PRO_PROFILE_TEXT')} actionTitle={t('BECOME_PRO')} onAction={() => router.replace('/become-pro')} />
      </View>
    );
  }
  if (!services) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl, gap: spacing.lg }]}>
        <BackButton />
        <ErrorBanner message={error} />
      </View>
    );
  }

  async function save() {
    const errs = validateServices(services);
    setErrors(errs);
    if (Object.keys(errs).length) return;
    setSaving(true);
    setError(null);
    setSaved(false);
    try {
      const remoteOnly = services.workType === 'remote';
      const serviceArea = { radiusKm: area.radiusKm };
      if (!remoteOnly && area.place) {
        if (area.place.location) serviceArea.location = area.place.location;
        serviceArea.municipalities = [area.place.municipality ?? area.place.city].filter(Boolean);
      }
      await api('/pros/me', {
        method: 'PUT',
        body: {
          categories: services.categories,
          headline: services.headline.trim(),
          bio: services.bio.trim(),
          hourlyRate: toOre(services.hourlyRate) ?? null,
          workType: services.workType,
          serviceArea,
          availableForMarketplace: visible,
        },
      });
      await refreshSession();
      setSaved(true);
      setTimeout(() => goBackOr('/profile'), 500);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <FocusStatusBar style="dark" />
      <ScrollView contentContainerStyle={[styles.content, { paddingTop: insets.top + spacing.md }]} keyboardShouldPersistTaps="handled">
        <BackButton />
        <AppText variant="h1" accessibilityRole="header">
          {t('EDIT_PRO_PROFILE')}
        </AppText>
        <ErrorBanner message={error} />

        <View style={styles.visible}>
          <View style={{ flex: 1, gap: 2 }}>
            <AppText variant="bodyStrong">{t('STAT_VISIBLE')}</AppText>
            <AppText variant="small" muted>
              {visible ? t('VISIBLE_ON_TEXT') : t('VISIBLE_OFF_TEXT')}
            </AppText>
          </View>
          <Switch
            value={visible}
            onValueChange={setVisible}
            trackColor={{ true: colors.slate, false: colors.line }}
            thumbColor={visible ? colors.hivis : colors.paper}
            ios_backgroundColor={colors.line}
          />
        </View>

        <ServiceFields value={services} onChange={setServices} errors={errors} />
        {services.workType !== 'remote' ? (
          <>
            <AppText variant="title">{t('SERVICE_AREA')}</AppText>
            <AreaFields value={area} onChange={setArea} />
          </>
        ) : null}
      </ScrollView>
      <BottomBar>
        <Button title={saved ? t('SAVED') : t('SAVE_CHANGES')} icon="checkmark" loading={saving} onPress={save} />
      </BottomBar>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xl, paddingBottom: spacing.xxxl },
  visible: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, padding: spacing.lg, borderRadius: radius.lg, backgroundColor: colors.paper },
});
