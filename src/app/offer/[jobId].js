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
import { useI18n } from '@/i18n';
import { formatNok } from '@/lib/format';

const PRICE_TYPES = [
  { value: 'fixed', label: 'PRICE_FIXED' },
  { value: 'hourly', label: 'PRICE_HOURLY' },
  { value: 'estimate', label: 'PRICE_ESTIMATE' },
];

// "12 500" / "12500,50" → øre
const toOre = (text) => Math.round(Number(String(text).replace(/\s/g, '').replace(',', '.')) * 100);

export default function OfferScreen() {
  const { jobId, title } = useLocalSearchParams();
  const insets = useSafeAreaInsets();
  const { t } = useI18n();
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
      setError(t('OFFER_AMOUNT_REQUIRED'));
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
        err instanceof ApiError && err.status === 409 ? t('OFFER_ALREADY_SENT') : errorMessage(err)
      );
      setSending(false);
    }
  }

  return (
    <KeyboardAvoidingView style={styles.flex} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView
        contentContainerStyle={[styles.content, { paddingTop: insets.top + spacing.lg }]}
        keyboardShouldPersistTaps="handled"
      >
        <BackButton icon="close" />

        <View style={{ gap: spacing.xs }}>
          <AppText variant="h1" accessibilityRole="header">
            {t('MAKE_OFFER')}
          </AppText>
          {title ? (
            <AppText variant="body" muted numberOfLines={2}>
              {title}
            </AppText>
          ) : null}
        </View>

        <ErrorBanner message={error} />

        <ChoiceChips label={t('PRICE_TYPE')} options={PRICE_TYPES.map((o) => ({ ...o, label: t(o.label) }))} value={priceType} onChange={setPriceType} />

        <TextField
          label={priceType === 'hourly' ? t('PRICE_PER_HOUR_LABEL') : t('PRICE_LABEL')}
          value={amount}
          onChangeText={setAmount}
          keyboardType="decimal-pad"
          placeholder={priceType === 'hourly' ? '950' : '12 500'}
        />

        {priceType === 'hourly' ? (
          <TextField
            label={t('ESTIMATED_HOURS')}
            value={hours}
            onChangeText={setHours}
            keyboardType="decimal-pad"
            placeholder="8"
            hint={estimate ? t('ESTIMATE_TOTAL', { total: formatNok(estimate) }) : t('ESTIMATED_HOURS_HINT')}
          />
        ) : null}

        <TextField
          label={t('MESSAGE_TO_CUSTOMER')}
          value={message}
          onChangeText={setMessage}
          multiline
          placeholder={t('MESSAGE_TO_CUSTOMER_PLACEHOLDER')}
        />

        <Button title={t('SEND_OFFER')} onPress={submit} loading={sending} disabled={!validAmount} />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xl, paddingBottom: spacing.xxxl },
});
