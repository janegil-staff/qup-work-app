// /qup-work-app/src/app/company/[id].js
// Company settings (owner/admin): logo, details, and what goes on invoices
// (bank account, payment terms, footer text). Workers only see the details.
import { useEffect, useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, View } from 'react-native';
import { useLocalSearchParams } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton, goBackOr } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { Button } from '@/components/Button';
import { ChoiceChips } from '@/components/ChoiceChips';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { ImagePickerButton } from '@/components/ImagePickerButton';
import { Loading } from '@/components/Loading';
import { CompanyFields, validateCompany } from '@/components/ProFields';
import { TextField } from '@/components/TextField';
import { colors, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { api, errorMessage } from '@/lib/api';
import { digitsOnly, formatBankAccount, formatOrgNumber } from '@/lib/norway';

const TERMS = [10, 14, 20, 30];
const KNOWN_FORMS = ['ENK', 'AS'];

export default function CompanyScreen() {
  const { id } = useLocalSearchParams();
  const insets = useSafeAreaInsets();
  const { refreshSession } = useAuth();
  const { t } = useI18n();
  const [loadError, setLoadError] = useState(null);
  const [role, setRole] = useState(null);
  const [details, setDetails] = useState(null);
  const [logoUrl, setLogoUrl] = useState(null);
  const [contact, setContact] = useState({ email: '', phone: '' });
  const [terms, setTerms] = useState(14);
  const [footer, setFooter] = useState('');
  const [errors, setErrors] = useState({});
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    api(`/companies/${id}`)
      .then(({ company: c, myRole }) => {
        setRole(myRole);
        setDetails({
          orgForm: KNOWN_FORMS.includes(c.orgForm) ? c.orgForm : 'other',
          originalForm: c.orgForm,
          name: c.name ?? '',
          orgNumber: c.orgNumber ? formatOrgNumber(c.orgNumber) : '',
          vatRegistered: Boolean(c.vatRegistered),
          bankAccount: c.invoiceSettings?.bankAccount ? formatBankAccount(c.invoiceSettings.bankAccount) : '',
        });
        setLogoUrl(c.logoUrl ?? null);
        setContact({ email: c.email ?? '', phone: c.phone ?? '' });
        setTerms(c.invoiceSettings?.paymentTermsDays ?? 14);
        setFooter(c.invoiceSettings?.footerText ?? '');
      })
      .catch((err) => setLoadError(errorMessage(err)));
  }, [id]);

  if (loadError) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl }]}>
        <BackButton />
        <EmptyState icon="business-outline" title={t('COMPANY_NOT_FOUND')} text={loadError} />
      </View>
    );
  }
  if (!details) return <Loading />;

  const canEdit = role === 'owner' || role === 'admin';

  async function save() {
    const errs = validateCompany(details);
    setErrors(errs);
    if (Object.keys(errs).length) return;
    setSaving(true);
    setError(null);
    setSaved(false);
    try {
      await api(`/companies/${id}`, {
        method: 'PATCH',
        body: {
          name: details.name.trim(),
          // "Other" covers ANS/DA/NUF too; keep what's saved unless it was changed here
          orgForm: details.orgForm === 'other' && details.originalForm && !KNOWN_FORMS.includes(details.originalForm) ? details.originalForm : details.orgForm,
          orgNumber: digitsOnly(details.orgNumber) || null,
          vatRegistered: details.vatRegistered,
          logoUrl,
          email: contact.email.trim() || undefined,
          phone: contact.phone.trim() || undefined,
          invoiceSettings: {
            bankAccount: digitsOnly(details.bankAccount) || undefined,
            paymentTermsDays: terms,
            footerText: footer.trim(),
          },
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
          {t('COMPANY_SETTINGS')}
        </AppText>
        {!canEdit ? (
          <AppText variant="small" muted>
            {t('COMPANY_READ_ONLY')}
          </AppText>
        ) : null}
        <ErrorBanner message={error} />

        {canEdit ? (
          <ImagePickerButton name={details.name} url={logoUrl} purpose="avatar" onChange={setLogoUrl} dark />
        ) : null}

        <View pointerEvents={canEdit ? 'auto' : 'none'} style={[styles.group, !canEdit && { opacity: 0.6 }]}>
          <CompanyFields value={details} onChange={setDetails} errors={errors} />
          <TextField label={t('EMAIL')} value={contact.email} onChangeText={(email) => setContact({ ...contact, email })} keyboardType="email-address" autoCapitalize="none" placeholder={t('EMAIL_PLACEHOLDER')} />
          <TextField label={t('PHONE')} value={contact.phone} onChangeText={(phone) => setContact({ ...contact, phone })} keyboardType="phone-pad" placeholder="912 34 567" />
        </View>

        {canEdit ? (
          <View style={styles.group}>
            <AppText variant="title">{t('INVOICE_SETTINGS')}</AppText>
            <ChoiceChips label={t('PAYMENT_DUE')} options={TERMS.map((d) => ({ value: d, label: t('DUE_IN_DAYS', { n: d }) }))} value={terms} onChange={setTerms} />
            <TextField label={t('INVOICE_FOOTER')} value={footer} onChangeText={setFooter} multiline maxLength={500} placeholder={t('INVOICE_FOOTER_PLACEHOLDER')} />
          </View>
        ) : null}
      </ScrollView>
      {canEdit ? (
        <BottomBar>
          <Button title={saved ? t('SAVED') : t('SAVE_CHANGES')} icon="checkmark" loading={saving} onPress={save} />
        </BottomBar>
      ) : null}
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xl, paddingBottom: spacing.xxxl },
  group: { gap: spacing.xl },
});
