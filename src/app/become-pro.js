// /qup-work-app/src/app/become-pro.js
// "Become a pro" in three short steps:
//   1. Your company   (ENK/AS, name, org number, VAT, bank account)
//   2. What you do    (categories, headline, about, hourly rate, on site/remote)
//   3. Where you work (postcode → place, how far you travel; skipped for remote-only)
// Then: company created → pro profile saved and visible → pro mode on → open jobs.
// If a step fails half-way (e.g. offline), "Finish" can be pressed again safely:
// the company is only created once.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton, goBackOr } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { Button } from '@/components/Button';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { AreaFields, CompanyFields, ServiceFields, toOre, validateCompany, validateServices } from '@/components/ProFields';
import { SignInPrompt } from '@/components/SignInPrompt';
import { colors, fonts, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { api, errorMessage } from '@/lib/api';
import { digitsOnly } from '@/lib/norway';

const STEPS = ['STEP_COMPANY', 'STEP_SERVICES', 'STEP_AREA'];

export default function BecomeProScreen() {
  const insets = useSafeAreaInsets();
  const { user, session, isPro, refreshSession, setActiveRole } = useAuth();
  const { t } = useI18n();
  const [step, setStep] = useState(0);
  const [company, setCompany] = useState({ orgForm: 'ENK', name: user?.name ?? '', orgNumber: '', vatRegistered: false, bankAccount: '' });
  const [services, setServices] = useState({ categories: [], headline: '', bio: '', hourlyRate: '', workType: 'onsite' });
  const [area, setArea] = useState({ postalCode: '', place: null, radiusKm: 25 });
  const [errors, setErrors] = useState({});
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  // Remember the company once it exists, so pressing Finish again doesn't make a second one
  const [companyId, setCompanyId] = useState(null);

  if (!user) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md }]}>
        <View style={{ paddingHorizontal: spacing.xl }}>
          <BackButton />
        </View>
        <SignInPrompt icon="construct-outline" title={t('BECOME_PRO')} text={t('BECOME_PRO_GUEST_TEXT')} />
      </View>
    );
  }

  // Already a pro (e.g. tapped an old link): nothing to set up
  if (isPro && !companyId) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl, gap: spacing.lg }]}>
        <BackButton />
        <AppText variant="h1">{t('ALREADY_A_PRO')}</AppText>
        <AppText variant="body" muted>
          {t('ALREADY_A_PRO_TEXT')}
        </AppText>
        <Button title={t('EDIT_PRO_PROFILE')} variant="dark" onPress={() => router.replace('/edit-pro')} />
      </View>
    );
  }

  const remoteOnly = services.workType === 'remote';
  const last = step === STEPS.length - 1;

  function next() {
    const errs = step === 0 ? validateCompany(company) : step === 1 ? validateServices(services) : {};
    setErrors(errs);
    if (Object.keys(errs).length) return;
    setError(null);
    if (!last) setStep(step + 1);
    else finish();
  }

  async function finish() {
    setSaving(true);
    setError(null);
    try {
      let id = companyId ?? session?.companies?.find((c) => c.role === 'owner')?._id;
      if (!id) {
        const res = await api('/companies', {
          method: 'POST',
          body: {
            name: company.name.trim(),
            orgForm: company.orgForm,
            orgNumber: digitsOnly(company.orgNumber) || undefined,
            vatRegistered: company.vatRegistered,
            email: user.email,
            phone: user.phone || undefined,
            invoiceSettings: digitsOnly(company.bankAccount) ? { bankAccount: digitsOnly(company.bankAccount) } : undefined,
          },
        });
        id = res.company._id;
      }
      setCompanyId(id);

      const serviceArea =
        !remoteOnly && area.place
          ? {
              ...(area.place.location ? { location: area.place.location } : {}),
              radiusKm: area.radiusKm,
              municipalities: [area.place.municipality ?? area.place.city].filter(Boolean),
            }
          : { radiusKm: area.radiusKm };

      await api('/pros/me', {
        method: 'PUT',
        body: {
          company: id,
          categories: services.categories,
          headline: services.headline.trim(),
          bio: services.bio.trim() || undefined,
          hourlyRate: toOre(services.hourlyRate),
          workType: services.workType,
          serviceArea,
          availableForMarketplace: true,
        },
      });

      await refreshSession();
      await setActiveRole('pro');
      router.replace('/jobs');
    } catch (err) {
      setError(errorMessage(err));
      setSaving(false);
    }
  }

  return (
    <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <FocusStatusBar style="dark" />
      <ScrollView contentContainerStyle={[styles.content, { paddingTop: insets.top + spacing.md }]} keyboardShouldPersistTaps="handled">
        <BackButton icon={step === 0 ? 'close' : 'arrow-back'} onPress={() => (step === 0 ? goBackOr('/profile') : setStep(step - 1))} />

        {/* Progress: three numbered stubs, like the steps on a contract */}
        <View style={styles.progress} accessibilityRole="progressbar" accessibilityValue={{ min: 1, max: STEPS.length, now: step + 1 }}>
          {STEPS.map((key, i) => (
            <View key={key} style={styles.progressItem}>
              <View style={[styles.progressNo, i < step && styles.progressDone, i === step && styles.progressNow]}>
                {i < step ? (
                  <Ionicons name="checkmark" size={14} color={colors.paper} />
                ) : (
                  <AppText style={styles.progressText} color={i === step ? colors.slate : colors.textMuted}>
                    {i + 1}
                  </AppText>
                )}
              </View>
              <AppText variant="caption" muted={i !== step} numberOfLines={1} style={{ flexShrink: 1 }}>
                {t(key)}
              </AppText>
            </View>
          ))}
        </View>

        <View style={{ gap: spacing.xs }}>
          <AppText variant="h1" accessibilityRole="header">
            {step === 0 ? t('BECOME_PRO_COMPANY_TITLE') : step === 1 ? t('BECOME_PRO_SERVICES_TITLE') : t('BECOME_PRO_AREA_TITLE')}
          </AppText>
          <AppText variant="body" muted>
            {step === 0 ? t('BECOME_PRO_COMPANY_TEXT') : step === 1 ? t('BECOME_PRO_SERVICES_TEXT') : remoteOnly ? t('BECOME_PRO_AREA_REMOTE') : t('BECOME_PRO_AREA_TEXT')}
          </AppText>
        </View>

        <ErrorBanner message={error} />

        {step === 0 ? <CompanyFields value={company} onChange={setCompany} errors={errors} /> : null}
        {step === 1 ? <ServiceFields value={services} onChange={setServices} errors={errors} /> : null}
        {step === 2 && !remoteOnly ? <AreaFields value={area} onChange={setArea} /> : null}
        {step === 2 ? (
          <View style={styles.summary}>
            <Ionicons name="eye-outline" size={18} color={colors.pine} />
            <AppText variant="small" style={{ flex: 1 }}>
              {t('BECOME_PRO_VISIBLE_NOTE')}
            </AppText>
          </View>
        ) : null}
      </ScrollView>

      <BottomBar>
        <Button
          title={last ? t('FINISH_AND_FIND_JOBS') : t('NEXT')}
          icon={last ? 'checkmark' : 'arrow-forward'}
          loading={saving}
          onPress={next}
        />
      </BottomBar>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xl, paddingBottom: spacing.xxxl },
  progress: { flexDirection: 'row', gap: spacing.md },
  progressItem: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 6 },
  progressNo: {
    width: 26,
    height: 26,
    borderRadius: 5,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1.5,
    borderColor: colors.line,
    backgroundColor: colors.paper,
  },
  progressNow: { backgroundColor: colors.hivis, borderColor: colors.hivis },
  progressDone: { backgroundColor: colors.pine, borderColor: colors.pine },
  progressText: { fontFamily: fonts.heavy, fontSize: 13, lineHeight: 16 },
  summary: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, padding: spacing.md, borderRadius: radius.md, backgroundColor: colors.pineSoft },
});
