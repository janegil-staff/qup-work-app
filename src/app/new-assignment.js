// /qup-work-app/src/app/new-assignment.js
// Pro: register work for one of my own clients and agree the terms in one go,
// skipping the marketplace and offers. Creates a direct job + its contract.
//   /new-assignment               → pick a client first
//   /new-assignment?client=<id>   → for that client
//   /new-assignment?job=<id>      → a direct job that has no contract yet
// Steps are optional: without any, the whole job is one step.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { BackButton } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { Button } from '@/components/Button';
import { ChoiceChips } from '@/components/ChoiceChips';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { toOre } from '@/components/ProFields';
import { SearchBar } from '@/components/SearchBar';
import { SignInPrompt } from '@/components/SignInPrompt';
import { TextField } from '@/components/TextField';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { api, errorMessage } from '@/lib/api';
import { formatDate, formatNok } from '@/lib/format';
import { dayToIso, parseDay } from '@/lib/time';
import { useDebounced, withQuery } from '@/lib/usePaged';

const PRICE_TYPES = [
  { value: 'fixed', label: 'PRICE_FIXED' },
  { value: 'hourly', label: 'PRICE_HOURLY' },
  { value: 'estimate', label: 'PRICE_ESTIMATE' },
];

export default function NewAssignmentScreen() {
  const { client: clientId, job: jobId } = useLocalSearchParams();
  const insets = useSafeAreaInsets();
  const { user, isPro } = useAuth();
  const { t } = useI18n();
  const [start, setStart] = useState(null); // { client, job? }
  const [loadError, setLoadError] = useState(null);

  useEffect(() => {
    if (!user || !isPro) return;
    setStart(null);
    setLoadError(null);
    if (jobId) {
      api(`/jobs/${jobId}`)
        .then((res) => {
          if (res.job.source !== 'direct' || res.side !== 'pro') throw new Error(t('JOB_NOT_YOURS'));
          if (res.job.contract) throw new Error(t('JOB_HAS_CONTRACT'));
          setStart({ client: res.job.client, job: res.job });
        })
        .catch((err) => setLoadError(err.status !== undefined ? errorMessage(err) : err.message));
    } else if (clientId) {
      api(`/clients/${clientId}`)
        .then((res) => setStart({ client: res.client }))
        .catch((err) => setLoadError(errorMessage(err)));
    }
  }, [user, isPro, clientId, jobId, t]);

  const back = (
    <View style={{ paddingHorizontal: spacing.xl }}>
      <BackButton />
    </View>
  );

  if (!user || !isPro) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md }]}>
        {back}
        <SignInPrompt icon="construct-outline" title={t('NEW_ASSIGNMENT')} text={t('CLIENTS_PRO_ONLY')} />
      </View>
    );
  }
  if (loadError) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md }]}>
        {back}
        <EmptyState icon="alert-circle-outline" title={t('NEW_ASSIGNMENT')} text={loadError} />
      </View>
    );
  }
  if (!clientId && !jobId) return <ClientPicker />;
  if (!start) return <Loading />;
  return <AssignmentForm key={start.job?._id ?? start.client._id} client={start.client} job={start.job} />;
}

// Step 1 when no client was given: search my clients, or add a new one
function ClientPicker() {
  const insets = useSafeAreaInsets();
  const { t } = useI18n();
  const [query, setQuery] = useState('');
  const q = useDebounced(query.trim());
  const [clients, setClients] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    let alive = true;
    api(withQuery('/clients', { q, limit: 50 }))
      .then((res) => alive && setClients(res.data))
      .catch((err) => alive && setError(errorMessage(err)));
    return () => {
      alive = false;
    };
  }, [q]);

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="dark" />
      <ScrollView contentContainerStyle={[styles.content, { paddingTop: insets.top + spacing.md }]} keyboardShouldPersistTaps="handled">
        <BackButton />
        <View style={{ gap: spacing.xs }}>
          <AppText variant="h1" accessibilityRole="header">
            {t('NEW_ASSIGNMENT')}
          </AppText>
          <AppText variant="body" muted>
            {t('PICK_CLIENT_INTRO')}
          </AppText>
        </View>
        <SearchBar value={query} onChangeText={setQuery} placeholder={t('SEARCH_CLIENTS')} />
        <ErrorBanner message={error} />
        {clients === null && !error ? <Loading /> : null}
        <View style={{ gap: spacing.sm }}>
          {(clients ?? []).map((c) => (
            <Pressable
              key={c._id}
              onPress={() => router.replace({ pathname: '/new-assignment', params: { client: c._id } })}
              accessibilityRole="button"
              style={({ pressed }) => [styles.pickRow, pressed && { opacity: 0.8 }]}
            >
              <Avatar name={c.name} size={40} dark={c.type === 'business'} />
              <View style={{ flex: 1 }}>
                <AppText variant="bodyStrong" numberOfLines={1}>
                  {c.name}
                </AppText>
                {c.address?.city ? (
                  <AppText variant="small" muted>
                    {c.address.city}
                  </AppText>
                ) : null}
              </View>
              <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
            </Pressable>
          ))}
          {clients?.length === 0 ? (
            <AppText variant="small" muted>
              {q ? t('NO_CLIENTS_MATCH') : t('NO_CLIENTS_TEXT')}
            </AppText>
          ) : null}
        </View>
      </ScrollView>
      <BottomBar>
        <Button
          title={t('NEW_CLIENT')}
          icon="person-add-outline"
          variant="dark"
          onPress={() => router.push({ pathname: '/client-form', params: { then: 'assignment' } })}
        />
      </BottomBar>
    </View>
  );
}

let stepKey = 0;
const newStep = () => ({ key: ++stepKey, title: '', amount: '' });

function AssignmentForm({ client, job }) {
  const insets = useSafeAreaInsets();
  const { t } = useI18n();
  const [title, setTitle] = useState(job?.title ?? '');
  const [description, setDescription] = useState(job?.description ?? '');
  const [priceType, setPriceType] = useState('fixed');
  const [amount, setAmount] = useState('');
  const [startText, setStartText] = useState('');
  const [endText, setEndText] = useState('');
  const [steps, setSteps] = useState([]);
  const [errors, setErrors] = useState({});
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);

  const hourly = priceType === 'hourly';
  const price = toOre(amount);
  const startDate = parseDay(startText);
  const endDate = parseDay(endText);
  const usedSteps = steps.filter((s) => s.title.trim() || s.amount.trim());
  const stepsSum = usedSteps.reduce((sum, s) => sum + (toOre(s.amount) ?? 0), 0);
  const rest = price != null ? price - stepsSum : null;

  const setStep = (key, patch) => setSteps((list) => list.map((s) => (s.key === key ? { ...s, ...patch } : s)));
  const removeStep = (key) => setSteps((list) => list.filter((s) => s.key !== key));

  // The first time steps are added, start with two so it's clear what they're for
  function addStep() {
    setSteps((list) => (list.length ? [...list, newStep()] : [newStep(), newStep()]));
  }

  async function submit() {
    const errs = {};
    if (title.trim().length < 5) errs.title = t('JOB_TITLE_TOO_SHORT');
    if (!price) errs.amount = t('OFFER_AMOUNT_REQUIRED');
    if (startText.trim() && !startDate) errs.start = t('DATE_INVALID');
    if (endText.trim() && !endDate) errs.end = t('DATE_INVALID');
    if (startDate && endDate && endDate < startDate) errs.end = t('END_BEFORE_START');
    if (usedSteps.some((s) => s.title.trim().length < 2)) errs.steps = t('STEP_TITLE_REQUIRED');
    else if (!hourly && usedSteps.length && usedSteps.some((s) => !toOre(s.amount))) errs.steps = t('STEP_AMOUNT_REQUIRED');
    else if (!hourly && usedSteps.length && price && stepsSum !== price) {
      errs.steps = t('STEPS_MUST_ADD_UP', { total: formatNok(price) });
    }
    setErrors(errs);
    if (Object.keys(errs).length) return;

    setSaving(true);
    setError(null);
    let createdJobId = null;
    try {
      let targetJob = job;
      if (!targetJob) {
        const res = await api('/jobs', {
          method: 'POST',
          body: { client: client._id, title: title.trim(), description: description.trim() || undefined, workType: 'onsite' },
        });
        targetJob = res.job;
        createdJobId = res.job._id;
      }
      const { contract } = await api('/contracts', {
        method: 'POST',
        body: {
          job: targetJob._id,
          title: title.trim(),
          description: description.trim() || undefined,
          priceType,
          ...(hourly ? { hourlyRate: price } : { totalAmount: price }),
          startDate: startDate ? dayToIso(startDate) : undefined,
          endDate: endDate ? dayToIso(endDate) : undefined,
          milestones: usedSteps.map((s) => ({ title: s.title.trim(), ...(hourly ? {} : { amount: toOre(s.amount) }) })),
        },
      });
      router.replace({ pathname: '/contract/[id]', params: { id: contract._id } });
    } catch (err) {
      // Don't leave a half-made job behind if the contract failed
      if (createdJobId) api(`/jobs/${createdJobId}`, { method: 'DELETE' }).catch(() => {});
      setError(errorMessage(err));
      setSaving(false);
    }
  }

  return (
    <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <FocusStatusBar style="dark" />
      <ScrollView contentContainerStyle={[styles.content, { paddingTop: insets.top + spacing.md }]} keyboardShouldPersistTaps="handled">
        <BackButton />
        <View style={{ gap: spacing.xs }}>
          <AppText variant="h1" accessibilityRole="header">
            {t('NEW_ASSIGNMENT')}
          </AppText>
          <AppText variant="body" muted>
            {t('NEW_ASSIGNMENT_INTRO')}
          </AppText>
        </View>

        <View style={styles.clientCard}>
          <Avatar name={client?.name} size={40} />
          <View style={{ flex: 1 }}>
            <AppText variant="caption" onDark muted>
              {t('CLIENT')}
            </AppText>
            <AppText variant="bodyStrong" onDark numberOfLines={1}>
              {client?.name ?? t('UNKNOWN')}
            </AppText>
          </View>
        </View>

        <ErrorBanner message={error} />

        <TextField label={t('JOB_TITLE_LABEL')} value={title} onChangeText={setTitle} placeholder={t('JOB_TITLE_PLACEHOLDER')} maxLength={150} error={errors.title} />
        <TextField label={t('DESCRIPTION')} value={description} onChangeText={setDescription} multiline placeholder={t('ASSIGNMENT_DESCRIPTION_PLACEHOLDER')} maxLength={10000} />

        <ChoiceChips label={t('PRICE_TYPE')} options={PRICE_TYPES.map((o) => ({ ...o, label: t(o.label) }))} value={priceType} onChange={setPriceType} />
        <TextField
          label={hourly ? t('PRICE_PER_HOUR_LABEL') : t('PRICE_LABEL')}
          value={amount}
          onChangeText={setAmount}
          keyboardType="decimal-pad"
          placeholder={hourly ? '950' : '12 500'}
          error={errors.amount}
        />

        <View style={styles.row}>
          <View style={{ flex: 1 }}>
            <TextField
              label={t('START_DATE')}
              value={startText}
              onChangeText={setStartText}
              keyboardType="numbers-and-punctuation"
              placeholder={t('DATE_PLACEHOLDER')}
              error={errors.start}
              hint={startDate ? formatDate(startDate.toISOString()) : undefined}
            />
          </View>
          <View style={{ flex: 1 }}>
            <TextField
              label={t('END_DATE')}
              value={endText}
              onChangeText={setEndText}
              keyboardType="numbers-and-punctuation"
              placeholder={t('DATE_PLACEHOLDER')}
              error={errors.end}
              hint={endDate ? formatDate(endDate.toISOString()) : undefined}
            />
          </View>
        </View>

        <View style={{ gap: spacing.md }}>
          <View>
            <AppText variant="title">{t('STEPS_TITLE')}</AppText>
            <AppText variant="small" muted>
              {steps.length ? (hourly ? t('STEPS_HOURLY_HINT') : t('STEPS_SPLIT_HINT')) : t('STEPS_OPTIONAL_HINT')}
            </AppText>
          </View>
          {steps.map((s, i) => (
            <View key={s.key} style={styles.stepRow}>
              <View style={styles.stepNo}>
                <AppText variant="smallStrong">{i + 1}</AppText>
              </View>
              <View style={{ flex: 1, gap: spacing.sm }}>
                <TextField
                  label={t('STEP_TITLE')}
                  value={s.title}
                  onChangeText={(v) => setStep(s.key, { title: v })}
                  placeholder={t('STEP_TITLE_PLACEHOLDER')}
                  maxLength={150}
                />
                {!hourly ? (
                  <TextField label={t('STEP_AMOUNT')} value={s.amount} onChangeText={(v) => setStep(s.key, { amount: v })} keyboardType="decimal-pad" placeholder="5 000" />
                ) : null}
              </View>
              <Pressable onPress={() => removeStep(s.key)} hitSlop={10} accessibilityRole="button" accessibilityLabel={t('REMOVE_STEP')} style={styles.removeStep}>
                <Ionicons name="close" size={20} color={colors.textMuted} />
              </Pressable>
            </View>
          ))}
          {!hourly && usedSteps.length && price ? (
            <AppText variant="smallStrong" color={rest === 0 ? colors.pine : colors.amber}>
              {rest === 0 ? t('STEPS_ADD_UP') : t('STEPS_REST', { rest: formatNok(rest) })}
            </AppText>
          ) : null}
          {errors.steps ? (
            <AppText variant="small" color={colors.danger}>
              {errors.steps}
            </AppText>
          ) : null}
          <Button title={t('ADD_STEP')} icon="add" variant="outline" small onPress={addStep} style={{ alignSelf: 'flex-start' }} />
        </View>
      </ScrollView>
      <BottomBar>
        <Button title={t('CREATE_CONTRACT')} icon="checkmark" loading={saving} onPress={submit} />
      </BottomBar>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xl, paddingBottom: spacing.xxxl },
  row: { flexDirection: 'row', gap: spacing.md },
  clientCard: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, padding: spacing.lg, borderRadius: radius.ticket, backgroundColor: colors.slate },
  pickRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, padding: spacing.md, borderRadius: radius.ticket, backgroundColor: colors.paper },
  stepRow: { flexDirection: 'row', gap: spacing.md, padding: spacing.md, borderRadius: radius.ticket, backgroundColor: colors.paper },
  stepNo: {
    width: 28,
    height: 28,
    borderRadius: 6,
    borderWidth: 1.5,
    borderColor: colors.line,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 26,
  },
  removeStep: { width: 28, height: 28, alignItems: 'center', justifyContent: 'center', marginTop: 26 },
});
