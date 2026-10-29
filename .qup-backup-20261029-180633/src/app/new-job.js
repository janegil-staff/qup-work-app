// /qup-work-app/src/app/new-job.js
// Post a job to the marketplace: create it, publish it, then open it.
// With ?id= it edits an existing job instead (while it's a draft or still open).
import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton, goBackOr } from '@/components/BackButton';
import { Button } from '@/components/Button';
import { ChoiceChips } from '@/components/ChoiceChips';
import { ErrorBanner } from '@/components/ErrorBanner';
import { EmptyState } from '@/components/EmptyState';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { SignInPrompt } from '@/components/SignInPrompt';
import { TextField } from '@/components/TextField';
import { colors, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { api, ApiError, errorMessage } from '@/lib/api';
import { useCategories } from '@/lib/categories';
import { useI18n } from '@/i18n';
import { categoryName, oreInputText, URGENCY } from '@/lib/format';

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
  const { id } = useLocalSearchParams();
  const insets = useSafeAreaInsets();
  const { user } = useAuth();
  const { t } = useI18n();

  if (!user) {
    return (
      <View style={[styles.flex, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl }]}>
        <BackButton />
        <SignInPrompt icon="add-circle-outline" title={t('POST_JOB')} text={t('POST_JOB_GUEST_TEXT')} />
      </View>
    );
  }
  return id ? <EditJobLoader key={id} jobId={id} /> : <JobForm />;
}

// Loads the job first, so the form starts filled in
function EditJobLoader({ jobId }) {
  const insets = useSafeAreaInsets();
  const { t } = useI18n();
  const [job, setJob] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    api(`/jobs/${jobId}`)
      .then((res) => {
        const owner = (res.job.source === 'direct' && res.side === 'pro') || (res.job.source === 'marketplace' && res.side === 'customer');
        if (!owner) throw new Error(t('JOB_NOT_YOURS'));
        if (!['draft', 'open'].includes(res.job.status)) throw new Error(t('JOB_CANNOT_EDIT'));
        setJob(res.job);
      })
      .catch((err) => setError(err instanceof ApiError ? errorMessage(err) : err.message));
  }, [jobId, t]);

  if (error) {
    return (
      <View style={[styles.flex, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl }]}>
        <BackButton />
        <EmptyState icon="clipboard-outline" title={t('JOB_NOT_FOUND')} text={error} />
      </View>
    );
  }
  if (!job) return <Loading />;
  return <JobForm job={job} />;
}

function JobForm({ job }) {
  const insets = useSafeAreaInsets();
  const { t } = useI18n();
  const { all, roots, childrenOf } = useCategories();
  const editing = Boolean(job);

  const [title, setTitle] = useState(job?.title ?? '');
  const [description, setDescription] = useState(job?.description ?? '');
  const [category, setCategory] = useState(job?.category?._id ?? null);
  const [subcategory, setSubcategory] = useState(null);
  const [workType, setWorkType] = useState(job?.workType ?? 'onsite');
  const [postalCode, setPostalCode] = useState(job?.address?.postalCode ?? '');
  const [city, setCity] = useState(job?.address?.city ?? '');
  const [line1, setLine1] = useState(job?.address?.line1 ?? '');
  const [budgetMin, setBudgetMin] = useState(oreInputText(job?.budget?.min));
  const [budgetMax, setBudgetMax] = useState(oreInputText(job?.budget?.max));
  const [urgency, setUrgency] = useState(job?.timing?.urgency ?? 'flexible');
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);

  // A saved subcategory is shown as its main category + the sub, once categories are loaded
  const savedCategory = job?.category?._id;
  useEffect(() => {
    if (!savedCategory || !all.length) return;
    const found = all.find((c) => c._id === savedCategory);
    if (found?.parent) {
      setCategory(found.parent);
      setSubcategory(found._id);
    }
  }, [savedCategory, all]);

  const subs = category ? childrenOf(category) : [];

  async function submit() {
    if (title.trim().length < 5) return setError(t('JOB_TITLE_TOO_SHORT'));
    if (workType === 'onsite' && !city.trim()) return setError(t('JOB_CITY_REQUIRED'));
    const min = toOre(budgetMin);
    const max = toOre(budgetMax);
    if (min && max && min > max) return setError(t('BUDGET_MIN_OVER_MAX'));

    setError(null);
    setSaving(true);
    const body = {
      title: title.trim(),
      description: description.trim() || undefined,
      category: subcategory ?? category ?? undefined,
      workType,
      address:
        workType === 'onsite'
          ? { line1: line1.trim() || undefined, postalCode: postalCode.trim() || undefined, city: city.trim() }
          : undefined,
      budget: min || max ? { min, max } : undefined,
      timing: { ...job?.timing, urgency },
    };
    try {
      if (editing) {
        // Emptied fields are cleared, not left as they were
        await api(`/jobs/${job._id}`, {
          method: 'PATCH',
          body: {
            ...body,
            description: description.trim(),
            category: subcategory ?? category ?? null,
            budget: { min: min ?? null, max: max ?? null },
          },
        });
        goBackOr(`/job/${job._id}`);
        return;
      }
      const { job: created } = await api('/jobs', { method: 'POST', body });
      await api(`/jobs/${created._id}/publish`, { method: 'POST' });
      router.replace(`/job/${created._id}`);
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
            {editing ? t('EDIT_JOB') : t('POST_JOB')}
          </AppText>
          <AppText variant="body" muted>
            {editing ? (job.offerCount ? t('EDIT_JOB_WITH_OFFERS', { n: job.offerCount }) : t('EDIT_JOB_INTRO')) : t('POST_JOB_INTRO')}
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
        <Button title={editing ? t('SAVE_CHANGES') : t('PUBLISH_JOB')} icon={editing ? 'checkmark' : undefined} onPress={submit} loading={saving} />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xl, paddingBottom: spacing.xxxl },
  row: { flexDirection: 'row', gap: spacing.md },
});
