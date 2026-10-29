// /qup-work-app/src/app/(auth)/forgot-password.js
// Forgot password, in two steps on one screen:
//   1. email → the API emails a 6-digit code (it never says whether the email has an account)
//   2. code + new password → logged in straight away; the (auth) layout then closes the modal
import { router, useLocalSearchParams } from 'expo-router';
import { useRef, useState } from 'react';
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton } from '@/components/BackButton';
import { Button } from '@/components/Button';
import { ErrorBanner } from '@/components/ErrorBanner';
import { TextField } from '@/components/TextField';
import { colors, fonts, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { currentLocale, useI18n } from '@/i18n';
import { api, ApiError, errorMessage } from '@/lib/api';

const MIN_LENGTH = 8;
const EMAIL = /^\S+@\S+\.\S+$/;

export default function ForgotPasswordScreen() {
  const params = useLocalSearchParams();
  const insets = useSafeAreaInsets();
  const { signInWithTokens } = useAuth();
  const { t } = useI18n();
  const [step, setStep] = useState('email'); // 'email' | 'code'
  const [email, setEmail] = useState(typeof params.email === 'string' ? params.email : '');
  const [code, setCode] = useState('');
  const [password, setPassword] = useState('');
  const [errors, setErrors] = useState({});
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);
  const [resent, setResent] = useState(false);
  const passwordRef = useRef(null);

  async function sendCode({ again = false } = {}) {
    if (!EMAIL.test(email.trim())) {
      setErrors({ email: t('EMAIL_INVALID') });
      return;
    }
    setErrors({});
    setError(null);
    setBusy(true);
    try {
      await api('/auth/forgot-password', { method: 'POST', body: { email: email.trim(), lang: currentLocale() }, auth: false });
      setStep('code');
      setResent(again);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function reset() {
    const errs = {};
    if (code.replace(/\D/g, '').length !== 6) errs.code = t('RESET_CODE_INVALID');
    if (password.length < MIN_LENGTH) errs.password = t('PASSWORD_TOO_SHORT');
    setErrors(errs);
    if (Object.keys(errs).length) return;

    setError(null);
    setBusy(true);
    try {
      const data = await api('/auth/reset-password', {
        method: 'POST',
        body: { email: email.trim(), code: code.replace(/\D/g, ''), password },
        auth: false,
      });
      await signInWithTokens(data); // logged in → the modal closes by itself
    } catch (err) {
      if (err instanceof ApiError && err.details?.code) setErrors({ code: t('RESET_CODE_WRONG') });
      else setError(errorMessage(err));
      setBusy(false);
    }
  }

  return (
    <KeyboardAvoidingView style={styles.flex} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView contentContainerStyle={[styles.content, { paddingTop: insets.top + spacing.lg }]} keyboardShouldPersistTaps="handled">
        <BackButton onPress={() => (step === 'code' ? setStep('email') : router.back())} />

        <View style={styles.header}>
          <AppText variant="display" accessibilityRole="header">
            {t('FORGOT_PASSWORD_TITLE')}
          </AppText>
          <AppText variant="body" muted>
            {step === 'email' ? t('FORGOT_PASSWORD_INTRO') : t('RESET_CODE_SENT', { email: email.trim() })}
          </AppText>
        </View>

        <View style={styles.form}>
          <ErrorBanner message={error} />
          {step === 'email' ? (
            <>
              <TextField
                label={t('EMAIL')}
                value={email}
                onChangeText={setEmail}
                placeholder={t('EMAIL_PLACEHOLDER')}
                autoCapitalize="none"
                autoComplete="email"
                keyboardType="email-address"
                textContentType="emailAddress"
                returnKeyType="send"
                onSubmitEditing={() => sendCode()}
                error={errors.email}
                autoFocus={!email}
              />
              <Button title={t('SEND_CODE')} icon="mail-outline" variant="dark" loading={busy} onPress={() => sendCode()} />
            </>
          ) : (
            <>
              <TextField
                label={t('RESET_CODE')}
                value={code}
                onChangeText={(v) => setCode(v.replace(/\D/g, '').slice(0, 6))}
                placeholder="123456"
                keyboardType="number-pad"
                autoComplete="one-time-code"
                textContentType="oneTimeCode"
                maxLength={6}
                style={styles.code}
                returnKeyType="next"
                onSubmitEditing={() => passwordRef.current?.focus()}
                error={errors.code}
                autoFocus
              />
              <TextField
                ref={passwordRef}
                label={t('NEW_PASSWORD')}
                value={password}
                onChangeText={setPassword}
                secureTextEntry
                autoCapitalize="none"
                autoComplete="new-password"
                textContentType="newPassword"
                returnKeyType="go"
                onSubmitEditing={reset}
                error={errors.password}
                hint={t('PASSWORD_TOO_SHORT')}
              />
              <Button title={t('SAVE_NEW_PASSWORD')} icon="key-outline" variant="dark" loading={busy} onPress={reset} />
              <Pressable onPress={() => sendCode({ again: true })} disabled={busy} hitSlop={8} accessibilityRole="button" style={{ alignSelf: 'center' }}>
                <AppText variant="smallStrong" color={colors.info}>
                  {resent ? t('RESET_CODE_RESENT') : t('RESET_CODE_AGAIN')}
                </AppText>
              </Pressable>
              <AppText variant="small" muted center>
                {t('RESET_CODE_SPAM_HINT')}
              </AppText>
            </>
          )}
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xxl, flexGrow: 1 },
  header: { gap: spacing.sm },
  form: { gap: spacing.lg },
  code: { fontFamily: fonts.heavy, fontSize: 26, letterSpacing: 10, textAlign: 'center' },
});
