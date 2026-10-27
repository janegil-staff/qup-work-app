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
import { URGENCY } from '@/lib/format';

const URGENCY_OPTIONS = Object.entries(URGENCY).map(([value, label]) => ({ value, label }));
const WORK_TYPES = [
  { value: 'onsite', label: 'På stedet' },
  { value: 'remote', label: 'Kan gjøres digitalt' },
];

const toOre = (text) => {
  const n = Number(String(text).replace(/\s/g, '').replace(',', '.'));
  return text && Number.isFinite(n) && n > 0 ? Math.round(n * 100) : undefined;
};

export default function NewJobScreen() {
  const insets = useSafeAreaInsets();
  const { user } = useAuth();
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
        <SignInPrompt icon="add-circle-outline" title="Legg ut en jobb" text="Logg inn for å legge ut jobben og få tilbud." />
      </View>
    );
  }

  const subs = category ? childrenOf(category) : [];

  async function submit() {
    if (title.trim().length < 5) return setError('Gi jobben en tittel på minst 5 tegn.');
    if (workType === 'onsite' && !city.trim()) return setError('Skriv hvor jobben skal gjøres.');
    const min = toOre(budgetMin);
    const max = toOre(budgetMax);
    if (min && max && min > max) return setError('Budsjett «fra» må være lavere enn «til».');

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
            Legg ut en jobb
          </AppText>
          <AppText variant="body" muted>
            Jo mer konkret du er, jo bedre tilbud får du.
          </AppText>
        </View>

        <TextField label="Hva skal gjøres?" value={title} onChangeText={setTitle} placeholder="Bytte sikringsskap i enebolig" />
        <TextField
          label="Beskrivelse"
          value={description}
          onChangeText={setDescription}
          multiline
          placeholder="Størrelse, materialer, tilgang, når det passer…"
        />

        <ChoiceChips
          label="Kategori"
          options={roots.map((c) => ({ value: c._id, label: c.name, deselectable: true }))}
          value={category}
          onChange={(v) => {
            setCategory(v);
            setSubcategory(null);
          }}
        />
        {subs.length ? (
          <ChoiceChips
            label="Hva slags jobb?"
            options={subs.map((c) => ({ value: c._id, label: c.name, deselectable: true }))}
            value={subcategory}
            onChange={setSubcategory}
          />
        ) : null}

        <ChoiceChips label="Hvor" options={WORK_TYPES} value={workType} onChange={setWorkType} />
        {workType === 'onsite' ? (
          <View style={{ gap: spacing.lg }}>
            <View style={styles.row}>
              <View style={{ width: 120 }}>
                <TextField label="Postnr." value={postalCode} onChangeText={setPostalCode} keyboardType="number-pad" maxLength={4} placeholder="5003" />
              </View>
              <View style={{ flex: 1 }}>
                <TextField label="Sted" value={city} onChangeText={setCity} placeholder="Bergen" autoComplete="postal-address-locality" />
              </View>
            </View>
            <TextField
              label="Gateadresse"
              value={line1}
              onChangeText={setLine1}
              placeholder="Storgata 1"
              hint="Vises bare for fagpersonen du velger."
            />
          </View>
        ) : null}

        <View style={styles.row}>
          <View style={{ flex: 1 }}>
            <TextField label="Budsjett fra (kr)" value={budgetMin} onChangeText={setBudgetMin} keyboardType="number-pad" placeholder="5 000" />
          </View>
          <View style={{ flex: 1 }}>
            <TextField label="til (kr)" value={budgetMax} onChangeText={setBudgetMax} keyboardType="number-pad" placeholder="15 000" />
          </View>
        </View>

        <ChoiceChips label="Når" options={URGENCY_OPTIONS} value={urgency} onChange={setUrgency} />

        <ErrorBanner message={error} />
        <Button title="Legg ut jobben" onPress={submit} loading={saving} />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xl, paddingBottom: spacing.xxxl },
  row: { flexDirection: 'row', gap: spacing.md },
});
