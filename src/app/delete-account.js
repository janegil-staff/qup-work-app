// /qup-work-app/src/app/delete-account.js
// Delete my account (required by the App Store and Google Play).
// Says plainly what goes and what stays, then asks for the password.
// The API refuses while there are ongoing contracts, or colleagues in a company I own.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { Button } from '@/components/Button';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { SignInPrompt } from '@/components/SignInPrompt';
import { TextField } from '@/components/TextField';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { ApiError, errorMessage } from '@/lib/api';
import { confirm } from '@/lib/confirm';

export default function DeleteAccountScreen() {
  const insets = useSafeAreaInsets();
  const { user, deleteAccount } = useAuth();
  const { t } = useI18n();
  const [password, setPassword] = useState('');
  const [error, setError] = useState(null);
  const [passwordError, setPasswordError] = useState(null);
  const [busy, setBusy] = useState(false);

  if (!user) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md }]}>
        <View style={{ paddingHorizontal: spacing.xl }}>
          <BackButton />
        </View>
        <SignInPrompt icon="person-outline" title={t('DELETE_ACCOUNT')} text={t('PROFILE_GUEST_TEXT')} />
      </View>
    );
  }

  async function remove() {
    const ok = await confirm({
      title: t('DELETE_ACCOUNT_CONFIRM_TITLE'),
      message: t('DELETE_ACCOUNT_CONFIRM_TEXT'),
      confirmText: t('DELETE_ACCOUNT'),
      destructive: true,
    });
    if (!ok) return;
    setBusy(true);
    setError(null);
    setPasswordError(null);
    try {
      await deleteAccount(password);
      router.replace('/');
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) setPasswordError(t('CURRENT_PASSWORD_WRONG'));
      else if (err instanceof ApiError && err.details?.reason === 'active_contracts') setError(t('DELETE_BLOCKED_CONTRACTS'));
      else if (err instanceof ApiError && err.details?.reason === 'company_members') setError(t('DELETE_BLOCKED_COMPANY'));
      else setError(errorMessage(err));
      setBusy(false);
    }
  }

  const goes = ['DELETE_GOES_PROFILE', 'DELETE_GOES_PRO', 'DELETE_GOES_JOBS', 'DELETE_GOES_LOGIN'];
  const stays = ['DELETE_STAYS_CONTRACTS', 'DELETE_STAYS_INVOICES'];

  return (
    <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <FocusStatusBar style="dark" />
      <ScrollView contentContainerStyle={[styles.content, { paddingTop: insets.top + spacing.md }]} keyboardShouldPersistTaps="handled">
        <BackButton />
        <View style={{ gap: spacing.xs }}>
          <AppText variant="h1" accessibilityRole="header">
            {t('DELETE_ACCOUNT')}
          </AppText>
          <AppText variant="body" muted>
            {t('DELETE_ACCOUNT_INTRO', { email: user.email })}
          </AppText>
        </View>

        <View style={styles.card}>
          <AppText variant="caption" muted style={styles.kicker}>
            {t('DELETE_WHAT_GOES')}
          </AppText>
          {goes.map((k) => (
            <Row key={k} icon="close-circle" color={colors.danger} text={t(k)} />
          ))}
        </View>
        <View style={styles.card}>
          <AppText variant="caption" muted style={styles.kicker}>
            {t('DELETE_WHAT_STAYS')}
          </AppText>
          {stays.map((k) => (
            <Row key={k} icon="document-lock-outline" color={colors.textMuted} text={t(k)} />
          ))}
        </View>

        <ErrorBanner message={error} />
        <TextField
          label={t('CURRENT_PASSWORD')}
          value={password}
          onChangeText={setPassword}
          secureTextEntry
          autoCapitalize="none"
          autoComplete="current-password"
          textContentType="password"
          error={passwordError}
          hint={t('DELETE_PASSWORD_HINT')}
        />
      </ScrollView>
      <BottomBar>
        <Button title={t('DELETE_ACCOUNT')} icon="trash-outline" variant="danger" loading={busy} disabled={!password} onPress={remove} />
      </BottomBar>
    </KeyboardAvoidingView>
  );
}

function Row({ icon, color, text }) {
  return (
    <View style={styles.row}>
      <Ionicons name={icon} size={18} color={color} style={{ marginTop: 2 }} />
      <AppText variant="small" style={{ flex: 1 }}>
        {text}
      </AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xl, paddingBottom: spacing.xxxl },
  card: { backgroundColor: colors.paper, borderRadius: radius.lg, padding: spacing.lg, gap: spacing.md },
  kicker: { textTransform: 'uppercase', letterSpacing: 1.2 },
  row: { flexDirection: 'row', gap: spacing.sm },
});
