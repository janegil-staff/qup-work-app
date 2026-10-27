// /qup-work-app/src/app/offer/[jobId].js
// Modal where a pro sends an offer on a job.
import { useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton, goBackOr } from '@/components/BackButton';
import { Button } from '@/components/Button';
import { ChoiceChips } from '@/components/ChoiceChips';
import { ErrorBanner } from '@/components/ErrorBanner';
import { TextField } from '@/components/TextField';
import { colors, spacing } from '@/constants/theme';
import { api, ApiError, errorMessage } from '@/lib/api';
import { formatNok } from '@/lib/format';

const PRICE_TYPES = [
  { value: 'fixed', label: 'Fastpris' },
  { value: 'hourly', label: 'Timepris' },
  { value: 'estimate', label: 'Overslag' },
];

// "12 500" / "12500,50" → øre
const toOre = (text) => Math.round(Number(String(text).replace(/\s/g, '').replace(',', '.')) * 100);

export default function OfferScreen() {
  const { jobId, title } = useLocalSearchParams();
  const insets = useSafeAreaInsets();
  const [priceType, setPriceType] = useState('fixed');
  const [amount, setAmount] = useState('');
  const [hours, setHours] = useState('');
  const [message, setMessage] = useState('');
  const [error, setError] = useState(null);
  const [sending, setSending] = useState(false);

  const ore = toOre(amount);
  const validAmount = Number.isFinite(ore) && ore > 0;
  const hourCount = Number(String(hours).replace(',', '.'));
  const estimate = priceType === 'hourly' && validAmount && hourCount > 0 ? ore * hourCount : null;

  async function submit() {
    if (!validAmount) {
      setError('Skriv inn et beløp i kroner.');
      return;
    }
    setError(null);
    setSending(true);
    try {
      await api(`/jobs/${jobId}/offers`, {
        method: 'POST',
        body: {
          priceType,
          amount: ore,
          estimatedHours: priceType === 'hourly' && hourCount > 0 ? hourCount : undefined,
          message: message.trim() || undefined,
        },
      });
      goBackOr(`/job/${jobId}`);
    } catch (err) {
      setError(
        err instanceof ApiError && err.status === 409 ? 'Du har allerede sendt tilbud på denne jobben.' : errorMessage(err)
      );
      setSending(false);
    }
  }

  return (
    <KeyboardAvoidingView style={styles.flex} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView
        contentContainerStyle={[styles.content, { paddingTop: Platform.OS === 'ios' ? spacing.lg : insets.top + spacing.md }]}
        keyboardShouldPersistTaps="handled"
      >
        <BackButton icon="close" label="Lukk" />

        <View style={{ gap: spacing.xs }}>
          <AppText variant="h1" accessibilityRole="header">
            Gi tilbud
          </AppText>
          {title ? (
            <AppText variant="body" muted numberOfLines={2}>
              {title}
            </AppText>
          ) : null}
        </View>

        <ErrorBanner message={error} />

        <ChoiceChips label="Pristype" options={PRICE_TYPES} value={priceType} onChange={setPriceType} />

        <TextField
          label={priceType === 'hourly' ? 'Pris per time (kr, inkl. mva)' : 'Pris (kr, inkl. mva)'}
          value={amount}
          onChangeText={setAmount}
          keyboardType="decimal-pad"
          placeholder={priceType === 'hourly' ? '950' : '12 500'}
        />

        {priceType === 'hourly' ? (
          <TextField
            label="Anslått antall timer"
            value={hours}
            onChangeText={setHours}
            keyboardType="decimal-pad"
            placeholder="8"
            hint={estimate ? `Omtrent ${formatNok(estimate)} totalt` : 'Valgfritt, hjelper kunden å sammenligne'}
          />
        ) : null}

        <TextField
          label="Melding til kunden"
          value={message}
          onChangeText={setMessage}
          multiline
          placeholder="Hva er inkludert, når kan du starte, har du gjort lignende jobber?"
        />

        <Button title="Send tilbud" onPress={submit} loading={sending} disabled={!validAmount} />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xl, paddingBottom: spacing.xxxl },
});
