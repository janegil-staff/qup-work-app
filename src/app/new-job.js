// /qup-work-app/src/app/new-job.js
// Post a job to the marketplace: create it, publish it, then open it.
import { router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton } from '@/components/BackButton';
import { Button } from '@/components/Button';
import { ChoiceChips } from '@/components/ChoiceChips';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { SignInPrompt } from '@/components/SignInPrompt';
import { TextField } from '@/components/TextField';
import { colors, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { api, errorMessage } from '@/lib/api';
import { useCategories } from '@/lib/categories';
import { useI18n } from '@/i18n';
import { categoryName, URGENCY } from '@/lib/format';

const URGENCY_OPTIONS = Object.entries(URGENCY).map(([value, label]) => ({ value, label }));
const WORK_TYPES = [
  { value: 'onsite', label: 'WORK_ONSITE' },
  { value: 'remote', label: 'WORK_REMOTE' },
];

const toOre = (text) => {
  const n = Number(String(text).replace(/\s/g, '').replace(',', '.'));
  return text && Number.isFinite(n) && n > 0 ? Math.round(n * 100) : undefined;
};

export default function NewJobScreen() {
  const insets = useSafeAreaInsets();
  const { user } = useAuth();
  const { t } = useI18n();
  const { roots, childrenOf } = useCategories();

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState(null);
  const [subcategory, setSubcategory] = useState(null);
  const [workType, setWorkType] = useState('onsite');
  const [postalCode, setPostalCode] = useState('');
  const [city, setCity] = useState('');
  const [line1, setLine1] = useState('');
  const [budgetMin, setBudgetMin] = useState('');
  const [budgetMax, setBudgetMax] = useState('');
  const [urgency, setUrgency] = useState('flexible');
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);

  if (!user) {
    return (
      <View style={[styles.flex, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl }]}>
        <BackButton />
        <SignInPrompt icon="add-circle-outline" title={t('POST_JOB')} text={t('POST_JOB_GUEST_TEXT')} />
      </View>
    );
  }

  const subs = category ? childrenOf(category) : [];

  async function submit() {
    if (title.trim().length < 5) return setError(t('JOB_TITLE_TOO_SHORT'));
    if (workType === 'onsite' && !city.trim()) return setError(t('JOB_CITY_REQUIRED'));
    const min = toOre(budgetMin);
    const max = toOre(budgetMax);
    if (min && max && min > max) return setError(t('BUDGET_MIN_OVER_MAX'));

    setError(null);
    setSaving(true);
    try {
      const { job } = await api('/jobs', {
        method: 'POST',
        body: {
          title: title.trim(),
          description: description.trim() || undefined,
          category: subcategory ?? category ?? undefined,
          workType,
          address:
            workType === 'onsite'
              ? { line1: line1.trim() || undefined, postalCode: postalCode.trim() || undefined, city: city.trim() }
              : undefined,
          budget: min || max ? { min, max } : undefined,
          timing: { urgency },
        },
      });
      await api(`/jobs/${job._id}/publish`, { method: 'POST' });
      router.replace(`/job/${job._id}`);
    } catch (err) {
      setError(errorMessage(err));
      setSaving(false);
    }
  }

  return (
    <KeyboardAvoidingView style={styles.flex} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <FocusStatusBar style="dark" />
      <ScrollView
        contentContainerStyle={[styles.content, { paddingTop: insets.top + spacing.md }]}
        keyboardShouldPersistTaps="handled"
      >
        <BackButton />
        <View style={{ gap: spacing.xs }}>
          <AppText variant="h1" accessibilityRole="header">
            {t('POST_JOB')}
          </AppText>
          <AppText variant="body" muted>
            {t('POST_JOB_INTRO')}
          </AppText>
        </View>

        <TextField label={t('JOB_TITLE_LABEL')} value={title} onChangeText={setTitle} placeholder={t('JOB_TITLE_PLACEHOLDER')} />
        <TextField
          label={t('DESCRIPTION')}
          value={description}
          onChangeText={setDescription}
          multiline
          placeholder={t('JOB_DESCRIPTION_PLACEHOLDER')}
        />

        <ChoiceChips
          label={t('CATEGORY')}
          options={roots.map((c) => ({ value: c._id, label: categoryName(c), deselectable: true }))}
          value={category}
          onChange={(v) => {
            setCategory(v);
            setSubcategory(null);
          }}
        />
        {subs.length ? (
          <ChoiceChips
            label={t('JOB_TYPE')}
            options={subs.map((c) => ({ value: c._id, label: categoryName(c), deselectable: true }))}
            value={subcategory}
            onChange={setSubcategory}
          />
        ) : null}

        <ChoiceChips label={t('WHERE')} options={WORK_TYPES.map((o) => ({ ...o, label: t(o.label) }))} value={workType} onChange={setWorkType} />
        {workType === 'onsite' ? (
          <View style={{ gap: spacing.lg }}>
            <View style={styles.row}>
              <View style={{ width: 120 }}>
                <TextField label={t('POSTAL_CODE')} value={postalCode} onChangeText={setPostalCode} keyboardType="number-pad" maxLength={4} placeholder="5003" />
              </View>
              <View style={{ flex: 1 }}>
                <TextField label={t('CITY')} value={city} onChangeText={setCity} placeholder={t('CITY_PLACEHOLDER')} autoComplete="postal-address-locality" />
              </View>
            </View>
            <TextField
              label={t('STREET_ADDRESS')}
              value={line1}
              onChangeText={setLine1}
              placeholder={t('STREET_ADDRESS_PLACEHOLDER')}
              hint={t('STREET_ADDRESS_HINT')}
            />
          </View>
        ) : null}

        <View style={styles.row}>
          <View style={{ flex: 1 }}>
            <TextField label={t('BUDGET_FROM_LABEL')} value={budgetMin} onChangeText={setBudgetMin} keyboardType="number-pad" placeholder="5 000" />
          </View>
          <View style={{ flex: 1 }}>
            <TextField label={t('BUDGET_TO_LABEL')} value={budgetMax} onChangeText={setBudgetMax} keyboardType="number-pad" placeholder="15 000" />
          </View>
        </View>

        <ChoiceChips label={t('FACT_WHEN')} options={URGENCY_OPTIONS.map((o) => ({ ...o, label: t(o.label) }))} value={urgency} onChange={setUrgency} />

        <ErrorBanner message={error} />
        <Button title={t('PUBLISH_JOB')} onPress={submit} loading={saving} />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xl, paddingBottom: spacing.xxxl },
  row: { flexDirection: 'row', gap: spacing.md },
});
