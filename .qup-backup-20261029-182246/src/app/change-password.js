// /qup-work-app/src/app/change-password.js
// New password. Other phones and browsers are logged out; this one stays logged in
// (the API hands back fresh tokens, which are saved here).
import { useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton, goBackOr } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { Button } from '@/components/Button';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { SignInPrompt } from '@/components/SignInPrompt';
import { TextField } from '@/components/TextField';
import { colors, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { api, ApiError, errorMessage } from '@/lib/api';
import { tokenStore } from '@/lib/tokenStore';

const MIN_LENGTH = 8;

export default function ChangePasswordScreen() {
  const insets = useSafeAreaInsets();
  const { user } = useAuth();
  const { t } = useI18n();
  const [current, setCurrent] = useState('');
  const [next, setNext] = useState('');
  const [repeat, setRepeat] = useState('');
  const [errors, setErrors] = useState({});
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);
  const [done, setDone] = useState(false);

  if (!user) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md }]}>
        <View style={{ paddingHorizontal: spacing.xl }}>
          <BackButton />
        </View>
        <SignInPrompt icon="key-outline" title={t('CHANGE_PASSWORD')} text={t('PROFILE_GUEST_TEXT')} />
      </View>
    );
  }

  async function save() {
    const errs = {};
    if (!current) errs.current = t('CURRENT_PASSWORD_REQUIRED');
    if (next.length < MIN_LENGTH) errs.next = t('PASSWORD_TOO_SHORT', { n: MIN_LENGTH });
    else if (next === current) errs.next = t('PASSWORD_SAME_AS_OLD');
    if (repeat !== next) errs.repeat = t('PASSWORDS_DONT_MATCH');
    setErrors(errs);
    if (Object.keys(errs).length) return;

    setSaving(true);
    setError(null);
    try {
      const tokens = await api('/auth/me/password', { method: 'POST', body: { currentPassword: current, newPassword: next } });
      await tokenStore.set(tokens.accessToken, tokens.refreshToken);
      setDone(true);
      setTimeout(() => goBackOr('/profile'), 900);
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) setErrors({ current: t('CURRENT_PASSWORD_WRONG') });
      else setError(errorMessage(err));
    } finally {
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
            {t('CHANGE_PASSWORD')}
          </AppText>
          <AppText variant="body" muted>
            {t('CHANGE_PASSWORD_INTRO')}
          </AppText>
        </View>
        <ErrorBanner message={error} />
        <TextField
          label={t('CURRENT_PASSWORD')}
          value={current}
          onChangeText={setCurrent}
          secureTextEntry
          autoCapitalize="none"
          autoComplete="current-password"
          textContentType="password"
          error={errors.current}
        />
        <TextField
          label={t('NEW_PASSWORD')}
          value={next}
          onChangeText={setNext}
          secureTextEntry
          autoCapitalize="none"
          autoComplete="new-password"
          textContentType="newPassword"
          error={errors.next}
          hint={t('PASSWORD_TOO_SHORT', { n: MIN_LENGTH })}
        />
        <TextField
          label={t('REPEAT_PASSWORD')}
          value={repeat}
          onChangeText={setRepeat}
          secureTextEntry
          autoCapitalize="none"
          autoComplete="new-password"
          textContentType="newPassword"
          error={errors.repeat}
        />
      </ScrollView>
      <BottomBar>
        <Button title={done ? t('PASSWORD_CHANGED') : t('CHANGE_PASSWORD')} icon="key-outline" loading={saving} disabled={done} onPress={save} />
      </BottomBar>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xl, paddingBottom: spacing.xxxl },
});
