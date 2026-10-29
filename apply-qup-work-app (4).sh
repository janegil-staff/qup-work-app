#!/usr/bin/env bash
# Qup Work app: milestones, edit/cancel jobs, clients + direct contracts, password, payments, team, push, invoice PDF + email, job alerts, forgot password, delete account
# Run from anywhere:   bash apply-qup-work-app.sh /path/to/qup-work-app
# (or from inside the project folder with no argument)
#
# Every file it replaces is copied to .qup-backup-<time>/ in the project first,
# so you can undo by copying them back. Running it twice is safe.
set -euo pipefail

ROOT="${1:-$PWD}"
cd "$ROOT"
if ! grep -q '"name": "qup-work-app"' package.json 2>/dev/null; then
  echo "❌ $ROOT doesn't look like qup-work-app (no package.json with that name)." >&2
  echo "   Usage: bash apply-qup-work-app.sh /path/to/qup-work-app" >&2
  exit 1
fi

BACKUP=".qup-backup-$(date +%Y%m%d-%H%M%S)"
CHANGED=0

write_file() {
  local path="$1"
  if [ -f "$path" ]; then
    mkdir -p "$BACKUP/$(dirname "$path")"
    cp "$path" "$BACKUP/$path"
  fi
  mkdir -p "$(dirname "$path")"
  cat > "$path"
  CHANGED=$((CHANGED + 1))
  echo "  ✏️  $path"
}

echo "Updating qup-work-app in $ROOT"

# ---- src/app/(auth)/forgot-password.js
write_file 'src/app/(auth)/forgot-password.js' <<'QUP_EOF_0'
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
QUP_EOF_0

# ---- src/app/(auth)/login.js
write_file 'src/app/(auth)/login.js' <<'QUP_EOF_1'
// /qup-work-app/src/app/(auth)/login.js
import { router } from 'expo-router';
import { useRef, useState } from 'react';
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton, goBackOr } from '@/components/BackButton';
import { Button } from '@/components/Button';
import { ErrorBanner } from '@/components/ErrorBanner';
import { TextField } from '@/components/TextField';
import { colors, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { errorMessage } from '@/lib/api';

export default function LoginScreen() {
  const { login } = useAuth();
  const { t } = useI18n();
  const insets = useSafeAreaInsets();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);
  const passwordRef = useRef(null);

  async function onSubmit() {
    if (!email || !password) {
      setError(t('LOGIN_FILL_FIELDS'));
      return;
    }
    setError(null);
    setLoading(true);
    try {
      await login(email, password);
      // The (auth) layout closes the modal when the user is set
    } catch (err) {
      setError(errorMessage(err));
      setLoading(false);
    }
  }

  return (
    <KeyboardAvoidingView style={styles.flex} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView
        contentContainerStyle={[styles.content, { paddingTop: insets.top + spacing.lg }]}
        keyboardShouldPersistTaps="handled"
      >
        <BackButton icon="close" onPress={() => goBackOr('/')} />

        <View style={styles.header}>
          <AppText variant="display" accessibilityRole="header">
            {t('LOG_IN')}
          </AppText>
          <AppText variant="body" muted>
            {t('LOGIN_INTRO')}
          </AppText>
        </View>

        <View style={styles.form}>
          <ErrorBanner message={error} />
          <TextField
            label={t('EMAIL')}
            value={email}
            onChangeText={setEmail}
            placeholder={t('EMAIL_PLACEHOLDER')}
            autoCapitalize="none"
            autoComplete="email"
            keyboardType="email-address"
            textContentType="emailAddress"
            returnKeyType="next"
            onSubmitEditing={() => passwordRef.current?.focus()}
          />
          <TextField
            ref={passwordRef}
            label={t('PASSWORD')}
            value={password}
            onChangeText={setPassword}
            secureTextEntry
            autoComplete="current-password"
            textContentType="password"
            returnKeyType="go"
            onSubmitEditing={onSubmit}
          />
          <Button title={t('LOG_IN')} variant="dark" onPress={onSubmit} loading={loading} />
          <Pressable
            onPress={() => router.push({ pathname: '/forgot-password', params: email ? { email } : {} })}
            hitSlop={8}
            accessibilityRole="link"
            style={{ alignSelf: 'center' }}
          >
            <AppText variant="smallStrong" color={colors.info}>
              {t('FORGOT_PASSWORD')}
            </AppText>
          </Pressable>
        </View>

        <Pressable onPress={() => router.replace('/register')} style={styles.switch} accessibilityRole="link">
          <AppText variant="body" muted>
            {t('NEW_HERE')}
          </AppText>
          <AppText variant="bodyStrong" style={styles.switchLink}>
            {t('CREATE_ACCOUNT')}
          </AppText>
        </Pressable>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xxl, flexGrow: 1 },
  header: { gap: spacing.sm },
  form: { gap: spacing.lg },
  switch: { flexDirection: 'row', justifyContent: 'center', gap: 6, paddingVertical: spacing.sm },
  switchLink: { borderBottomWidth: 2, borderBottomColor: colors.hivis },
});
QUP_EOF_1

# ---- src/app/(tabs)/profile.js
write_file 'src/app/(tabs)/profile.js' <<'QUP_EOF_2'
// /qup-work-app/src/app/(tabs)/profile.js
import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { useState } from 'react';
import { Alert, Platform, Pressable, ScrollView, StyleSheet, Switch, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { Button } from '@/components/Button';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Rating } from '@/components/Rating';
import { ScreenHeader } from '@/components/ScreenHeader';
import { SignInPrompt } from '@/components/SignInPrompt';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { errorMessage } from '@/lib/api';
import { useI18n } from '@/i18n';
import { formatNok } from '@/lib/format';

const COMPANY_ROLE = { owner: 'ROLE_OWNER', admin: 'ROLE_ADMIN', worker: 'ROLE_WORKER' };

export default function ProfileScreen() {
  const { session } = useAuth();
  const { t } = useI18n();

  if (!session) {
    return (
      <View style={styles.screen}>
        <FocusStatusBar style="dark" />
        <ScreenHeader title={t('TAB_PROFILE')} />
        <SignInPrompt icon="person-outline" title={t('PROFILE_GUEST_TITLE')} text={t('PROFILE_GUEST_TEXT')} />
        <View style={{ padding: spacing.xl }}>
          <View style={styles.group}>
            <LanguageRow />
          </View>
        </View>
      </View>
    );
  }
  return <MyProfile />;
}

function MyProfile() {
  const insets = useSafeAreaInsets();
  const { session, isPro, logout, setActiveRole } = useAuth();
  const { t } = useI18n();
  const [switching, setSwitching] = useState(false);
  const [error, setError] = useState(null);
  const { user, companies, proProfile } = session;
  const isProMode = user.activeRole === 'pro';

  async function toggleMode(value) {
    setSwitching(true);
    setError(null);
    try {
      await setActiveRole(value ? 'pro' : 'customer');
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSwitching(false);
    }
  }

  function confirmLogout() {
    if (Platform.OS === 'web') {
      if (globalThis.confirm?.(`${t('LOG_OUT')}? ${t('LOG_OUT_ALL_DEVICES')}`)) logout();
      return;
    }
    Alert.alert(t('LOG_OUT'), t('LOG_OUT_ALL_DEVICES'), [
      { text: t('CANCEL'), style: 'cancel' },
      { text: t('LOG_OUT'), style: 'destructive', onPress: logout },
    ]);
  }

  return (
    <ScrollView style={styles.screen} contentContainerStyle={{ paddingBottom: spacing.xxxl }}>
      <FocusStatusBar style="light" />

      <View style={[styles.hero, { paddingTop: insets.top + spacing.xl }]}>
        <Pressable onPress={() => router.push('/account')} accessibilityRole="button" accessibilityLabel={t('MY_DETAILS')}>
          <Avatar name={user.name} url={user.avatarUrl} size={72} />
        </Pressable>
        <View style={{ gap: 2 }}>
          <AppText variant="h1" onDark>
            {user.name}
          </AppText>
          <AppText variant="small" onDark muted>
            {user.email}
          </AppText>
        </View>
        {proProfile ? <Rating avg={proProfile.stats.ratingAvg} count={proProfile.stats.ratingCount} onDark /> : null}
      </View>

      <View style={styles.body}>
        <ErrorBanner message={error} />

        <View style={styles.group}>
          <MenuRow
            icon="briefcase-outline"
            title={isProMode ? t('MY_ASSIGNMENTS') : t('MY_JOBS')}
            onPress={() => router.push('/my-jobs')}
          />
          {isPro ? (
            <MenuRow icon="document-text-outline" title={t('MY_OFFERS')} onPress={() => router.push('/my-offers')} />
          ) : null}
          {isPro ? <MenuRow icon="people-outline" title={t('CLIENTS')} onPress={() => router.push('/clients')} /> : null}
          <MenuRow
            icon="receipt-outline"
            title={isProMode ? t('INVOICES') : t('MY_INVOICES')}
            onPress={() => router.push('/invoices')}
          />
          {isPro ? (
            <MenuRow
              icon="id-card-outline"
              title={t('MY_PUBLIC_PROFILE')}
              onPress={() => router.push({ pathname: '/pro/[id]', params: { id: user._id } })}
            />
          ) : null}
          {isPro ? <MenuRow icon="create-outline" title={t('EDIT_PRO_PROFILE')} onPress={() => router.push('/edit-pro')} /> : null}
          <MenuRow icon="person-outline" title={t('MY_DETAILS')} onPress={() => router.push('/account')} />
          <MenuRow icon="key-outline" title={t('CHANGE_PASSWORD')} onPress={() => router.push('/change-password')} />
          <MenuRow icon="card-outline" title={t('PAYMENTS')} onPress={() => router.push('/payments')} />
          {!isProMode ? <MenuRow icon="add-circle-outline" title={t('POST_JOB')} onPress={() => router.push('/new-job')} /> : null}
          {isPro ? (
            <View style={styles.menuRow}>
              <Ionicons name="construct-outline" size={22} color={colors.slate} />
              <View style={{ flex: 1 }}>
                <AppText variant="bodyStrong">{t('PRO_MODE')}</AppText>
                <AppText variant="small" muted>
                  {isProMode ? t('PRO_MODE_ON') : t('PRO_MODE_OFF')}
                </AppText>
              </View>
              <Switch
                value={isProMode}
                onValueChange={toggleMode}
                disabled={switching}
                trackColor={{ true: colors.slate, false: colors.line }}
                thumbColor={isProMode ? colors.hivis : colors.paper}
                ios_backgroundColor={colors.line}
              />
            </View>
          ) : null}
        </View>

        {companies.length ? (
          <View style={styles.group}>
            {companies.map((c, i) => (
              <Pressable
                key={c._id}
                onPress={() => router.push({ pathname: '/company/[id]', params: { id: c._id } })}
                accessibilityRole="button"
                style={({ pressed }) => [styles.menuRow, i === companies.length - 1 && styles.lastRow, pressed && { opacity: 0.7 }]}
              >
                <Avatar name={c.name} url={c.logoUrl} size={40} dark />
                <View style={{ flex: 1 }}>
                  <AppText variant="bodyStrong">{c.name}</AppText>
                  <AppText variant="small" muted>
                    {t(COMPANY_ROLE[c.role])}
                    {c.orgNumber ? `, ${t('ORG_NUMBER_SHORT', { n: c.orgNumber })}` : ''}
                  </AppText>
                </View>
                <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
              </Pressable>
            ))}
          </View>
        ) : null}

        {proProfile ? (
          <View style={[styles.group, styles.stats]}>
            <Stat value={String(proProfile.stats.completedJobs)} label={t('STAT_COMPLETED_JOBS')} />
            <Stat value={proProfile.hourlyRate ? formatNok(proProfile.hourlyRate) : '–'} label={t('STAT_HOURLY_RATE')} />
            <Stat value={proProfile.availableForMarketplace ? t('YES') : t('NO')} label={t('STAT_VISIBLE')} />
          </View>
        ) : null}

        {!isPro ? (
          <View style={[styles.group, styles.proInvite]}>
            <AppText variant="title">{t('PRO_INVITE_TITLE')}</AppText>
            <AppText variant="small" muted>
              {t('BECOME_PRO_PROFILE_TEXT')}
            </AppText>
            <Button
              title={t('BECOME_PRO')}
              icon="construct-outline"
              small
              onPress={() => router.push('/become-pro')}
              style={{ alignSelf: 'flex-start', marginTop: spacing.sm }}
            />
          </View>
        ) : null}

        <View style={styles.group}>
          <LanguageRow />
        </View>

        <Button title={t('LOG_OUT')} variant="danger" onPress={confirmLogout} />
      </View>
    </ScrollView>
  );
}

function LanguageRow() {
  const { t, language } = useI18n();
  return (
    <Pressable
      onPress={() => router.push('/language')}
      accessibilityRole="button"
      style={({ pressed }) => [styles.menuRow, styles.lastRow, pressed && { opacity: 0.7 }]}
    >
      <Ionicons name="globe-outline" size={22} color={colors.slate} />
      <AppText variant="bodyStrong" style={{ flex: 1 }}>
        {t('LANGUAGE')}
      </AppText>
      <AppText variant="small" muted>
        {language.flag} {language.name}
      </AppText>
      <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
    </Pressable>
  );
}

function MenuRow({ icon, title, onPress }) {
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      style={({ pressed }) => [styles.menuRow, pressed && { opacity: 0.7 }]}
    >
      <Ionicons name={icon} size={22} color={colors.slate} />
      <AppText variant="bodyStrong" style={{ flex: 1 }}>
        {title}
      </AppText>
      <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
    </Pressable>
  );
}

function Stat({ value, label }) {
  return (
    <View style={styles.stat}>
      <AppText variant="h2">{value}</AppText>
      <AppText variant="caption" muted>
        {label}
      </AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  hero: { backgroundColor: colors.slate, padding: spacing.xl, gap: spacing.md },
  body: { padding: spacing.xl, gap: spacing.lg },
  group: { backgroundColor: colors.paper, borderRadius: radius.lg, paddingHorizontal: spacing.lg },
  menuRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    minHeight: 60,
    paddingVertical: spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.line,
  },
  lastRow: { borderBottomWidth: 0 },
  stats: { flexDirection: 'row', paddingVertical: spacing.lg },
  stat: { flex: 1, gap: 2 },
  proInvite: { paddingVertical: spacing.lg, gap: spacing.xs, borderLeftWidth: 4, borderLeftColor: colors.hivis },
});
QUP_EOF_2

# ---- src/app/_layout.js
write_file 'src/app/_layout.js' <<'QUP_EOF_3'
// /qup-work-app/src/app/_layout.js
// Root of the app. Browsing is open to everyone; login/register open as a modal
// on top of whatever you were looking at, and close again when you're logged in.
import {
  Archivo_400Regular,
  Archivo_500Medium,
  Archivo_600SemiBold,
  Archivo_700Bold,
  Archivo_800ExtraBold,
  useFonts,
} from '@expo-google-fonts/archivo';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { Loading } from '@/components/Loading';
import { PushHandler } from '@/components/PushHandler';
import { colors } from '@/constants/theme';
import { AuthProvider, useAuth } from '@/context/AuthContext';
import { TimerProvider } from '@/context/TimerContext';
import { UnreadProvider } from '@/context/UnreadContext';
import { I18nProvider, useI18n } from '@/i18n';

// The tabs are always the bottom of the stack. Even if the app opens on /login
// (Expo restores the last screen while developing), Utforsk is underneath and
// login is just a sheet you can close.
export const unstable_settings = { anchor: '(tabs)' };

function RootNavigator({ fontsReady }) {
  const { isLoading } = useAuth();
  const { ready: languageReady } = useI18n();
  // Wait for the saved language too, so the app never flashes in English first
  if (!fontsReady || isLoading || !languageReady) return <Loading dark />;

  return (
    <>
      <PushHandler />
      <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: colors.concrete } }}>
        <Stack.Screen name="(tabs)" />
        <Stack.Screen name="job/[id]" />
        <Stack.Screen name="pro/[id]" />
        <Stack.Screen name="my-jobs" />
        <Stack.Screen name="my-offers" />
        <Stack.Screen name="notifications" />
        <Stack.Screen name="invoices" />
        <Stack.Screen name="invoice/[id]" />
        <Stack.Screen name="become-pro" />
        <Stack.Screen name="edit-pro" />
        <Stack.Screen name="account" />
        <Stack.Screen name="company/[id]" />
        <Stack.Screen name="new-job" />
        <Stack.Screen name="language" />
        <Stack.Screen name="conversation/[id]" />
        <Stack.Screen name="contract/[id]" />
        <Stack.Screen name="clients" />
        <Stack.Screen name="client/[id]" />
        <Stack.Screen name="client-form" />
        <Stack.Screen name="new-assignment" />
        <Stack.Screen name="change-password" />
        <Stack.Screen name="payments" />
        <Stack.Screen name="team/[id]" />
        <Stack.Screen name="delete-account" />
        <Stack.Screen name="offer/[jobId]" options={{ presentation: 'modal' }} />
        <Stack.Screen name="(auth)" options={{ presentation: 'modal' }} />
      </Stack>
    </>
  );
}

export default function RootLayout() {
  const [fontsLoaded, fontError] = useFonts({
    Archivo_400Regular,
    Archivo_500Medium,
    Archivo_600SemiBold,
    Archivo_700Bold,
    Archivo_800ExtraBold,
  });

  return (
    <I18nProvider>
      <AuthProvider>
        <UnreadProvider>
          <TimerProvider>
            <StatusBar style="dark" />
            {/* If the fonts fail to load, carry on with the system font rather than hang */}
            <RootNavigator fontsReady={fontsLoaded || Boolean(fontError)} />
          </TimerProvider>
        </UnreadProvider>
      </AuthProvider>
    </I18nProvider>
  );
}
QUP_EOF_3

# ---- src/app/account.js
write_file 'src/app/account.js' <<'QUP_EOF_4'
// /qup-work-app/src/app/account.js
// My details: profile photo, name and phone. (Email and password are separate.)
import { router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton, goBackOr } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { Button } from '@/components/Button';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { ImagePickerButton } from '@/components/ImagePickerButton';
import { SignInPrompt } from '@/components/SignInPrompt';
import { TextField } from '@/components/TextField';
import { colors, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { api, errorMessage } from '@/lib/api';

export default function AccountScreen() {
  const insets = useSafeAreaInsets();
  const { user } = useAuth();
  const { t } = useI18n();

  if (!user) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md }]}>
        <View style={{ paddingHorizontal: spacing.xl }}>
          <BackButton />
        </View>
        <SignInPrompt icon="person-outline" title={t('MY_DETAILS')} text={t('PROFILE_GUEST_TEXT')} />
      </View>
    );
  }
  return <AccountForm key={user._id} />;
}

function AccountForm() {
  const insets = useSafeAreaInsets();
  const { user, refreshSession } = useAuth();
  const { t } = useI18n();
  const [name, setName] = useState(user.name ?? '');
  const [phone, setPhone] = useState(user.phone ?? '');
  const [avatarUrl, setAvatarUrl] = useState(user.avatarUrl ?? null);
  const [error, setError] = useState(null);
  const [nameError, setNameError] = useState(null);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  async function save() {
    if (name.trim().length < 2) {
      setNameError(t('NAME_REQUIRED'));
      return;
    }
    setNameError(null);
    setSaving(true);
    setError(null);
    setSaved(false);
    try {
      await api('/auth/me', { method: 'PATCH', body: { name: name.trim(), phone: phone.trim(), avatarUrl } });
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
          {t('MY_DETAILS')}
        </AppText>
        <ErrorBanner message={error} />
        <ImagePickerButton name={name || user.name} url={avatarUrl} purpose="avatar" onChange={setAvatarUrl} />
        <TextField label={t('NAME')} value={name} onChangeText={setName} placeholder={t('NAME_PLACEHOLDER')} maxLength={100} error={nameError} autoComplete="name" />
        <TextField label={t('PHONE')} value={phone} onChangeText={setPhone} keyboardType="phone-pad" placeholder="912 34 567" autoComplete="tel" hint={t('PHONE_HINT')} />
        <TextField label={t('EMAIL')} value={user.email} editable={false} hint={t('EMAIL_CANNOT_CHANGE')} />
        <Button
          title={t('DELETE_ACCOUNT')}
          icon="trash-outline"
          variant="danger"
          small
          onPress={() => router.push('/delete-account')}
          style={{ alignSelf: 'flex-start', marginTop: spacing.lg }}
        />
      </ScrollView>
      <BottomBar>
        <Button title={saved ? t('SAVED') : t('SAVE_CHANGES')} icon="checkmark" loading={saving} onPress={save} />
      </BottomBar>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xl, paddingBottom: spacing.xxxl },
});
QUP_EOF_4

# ---- src/app/change-password.js
write_file 'src/app/change-password.js' <<'QUP_EOF_5'
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
QUP_EOF_5

# ---- src/app/client-form.js
write_file 'src/app/client-form.js' <<'QUP_EOF_6'
// /qup-work-app/src/app/client-form.js
// Add a client to my register, or change one (?id=). Private person or business.
// The postcode fills in the town, and the client's address becomes the default
// work address on jobs for them.
import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton, goBackOr } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { Button } from '@/components/Button';
import { ChoiceChips } from '@/components/ChoiceChips';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { TextField } from '@/components/TextField';
import { colors, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { api, ApiError, errorMessage } from '@/lib/api';
import { digitsOnly, formatOrgNumber, isValidOrgNumber } from '@/lib/norway';

export default function ClientFormScreen() {
  const { id, then } = useLocalSearchParams();
  const insets = useSafeAreaInsets();
  const { t } = useI18n();
  const [client, setClient] = useState(id ? null : {});
  const [loadError, setLoadError] = useState(null);

  useEffect(() => {
    if (!id) return;
    api(`/clients/${id}`)
      .then((res) => setClient(res.client))
      .catch((err) => setLoadError(errorMessage(err)));
  }, [id]);

  if (loadError) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl }]}>
        <BackButton />
        <EmptyState icon="person-outline" title={t('CLIENT_NOT_FOUND')} text={loadError} />
      </View>
    );
  }
  if (!client) return <Loading />;
  return <ClientForm client={id ? client : null} then={then} />;
}

const EMAIL = /^\S+@\S+\.\S+$/;

function ClientForm({ client, then }) {
  const insets = useSafeAreaInsets();
  const { t } = useI18n();
  const editing = Boolean(client);
  const [type, setType] = useState(client?.type ?? 'private');
  const [name, setName] = useState(client?.name ?? '');
  const [contactPerson, setContactPerson] = useState(client?.contactPerson ?? '');
  const [orgNumber, setOrgNumber] = useState(client?.orgNumber ? formatOrgNumber(client.orgNumber) : '');
  const [email, setEmail] = useState(client?.email ?? '');
  const [phone, setPhone] = useState(client?.phone ?? '');
  const [line1, setLine1] = useState(client?.address?.line1 ?? '');
  const [postalCode, setPostalCode] = useState(client?.address?.postalCode ?? '');
  const [city, setCity] = useState(client?.address?.city ?? '');
  const [place, setPlace] = useState(null); // from the postcode lookup
  const [notes, setNotes] = useState(client?.notes ?? '');
  const [errors, setErrors] = useState({});
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);
  const firstCode = useRef(client?.address?.postalCode ?? '');

  // Postcode → town (and a map position for "near me"), without overwriting what was typed
  useEffect(() => {
    if (!/^\d{4}$/.test(postalCode) || postalCode === firstCode.current) return undefined;
    let alive = true;
    api(`/geo/postcode/${postalCode}`, { auth: false })
      .then((res) => {
        if (!alive) return;
        setPlace(res.place);
        if (res.place?.city) setCity(res.place.city);
      })
      .catch(() => alive && setPlace(null));
    return () => {
      alive = false;
    };
  }, [postalCode]);

  async function save() {
    const errs = {};
    if (name.trim().length < 2) errs.name = t('NAME_REQUIRED');
    if (email.trim() && !EMAIL.test(email.trim())) errs.email = t('EMAIL_INVALID');
    if (type === 'business' && orgNumber.trim() && !isValidOrgNumber(orgNumber)) errs.orgNumber = t('ORG_NUMBER_INVALID');
    if (postalCode.trim() && !/^\d{4}$/.test(postalCode.trim())) errs.postalCode = t('POSTCODE_FORMAT');
    setErrors(errs);
    if (Object.keys(errs).length) return;

    const business = type === 'business';
    const hasAddress = line1.trim() || postalCode.trim() || city.trim();
    const body = {
      type,
      name: name.trim(),
      contactPerson: business ? contactPerson.trim() : '',
      orgNumber: business && orgNumber.trim() ? digitsOnly(orgNumber) : undefined,
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      address: hasAddress
        ? {
            line1: line1.trim() || undefined,
            postalCode: postalCode.trim() || undefined,
            city: city.trim() || undefined,
            municipality: place?.municipality ?? client?.address?.municipality,
          }
        : undefined,
      ...(place?.location ? { location: place.location } : {}),
      notes: notes.trim(),
    };

    setSaving(true);
    setError(null);
    try {
      if (editing) {
        await api(`/clients/${client._id}`, { method: 'PATCH', body: body.orgNumber ? body : { ...body, orgNumber: null } });
        goBackOr(`/client/${client._id}`);
      } else {
        const res = await api('/clients', { method: 'POST', body });
        // Started from "New assignment": go straight on with the new client picked
        if (then === 'assignment') router.replace({ pathname: '/new-assignment', params: { client: res.client._id } });
        else router.replace({ pathname: '/client/[id]', params: { id: res.client._id } });
      }
    } catch (err) {
      setError(err instanceof ApiError && err.details?.orgNumber ? t('ORG_NUMBER_INVALID') : errorMessage(err));
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
            {editing ? t('EDIT_CLIENT') : t('NEW_CLIENT')}
          </AppText>
          <AppText variant="body" muted>
            {t('CLIENT_FORM_INTRO')}
          </AppText>
        </View>
        <ErrorBanner message={error} />

        <ChoiceChips
          label={t('CLIENT_TYPE')}
          options={[
            { value: 'private', label: t('CLIENT_PRIVATE') },
            { value: 'business', label: t('CLIENT_BUSINESS') },
          ]}
          value={type}
          onChange={setType}
        />
        <TextField
          label={type === 'business' ? t('COMPANY_NAME') : t('NAME')}
          value={name}
          onChangeText={setName}
          placeholder={type === 'business' ? t('CLIENT_COMPANY_PLACEHOLDER') : t('NAME_PLACEHOLDER')}
          maxLength={120}
          error={errors.name}
        />
        {type === 'business' ? (
          <>
            <TextField label={t('CONTACT_PERSON')} value={contactPerson} onChangeText={setContactPerson} placeholder={t('NAME_PLACEHOLDER')} maxLength={100} />
            <TextField
              label={t('ORG_NUMBER')}
              value={orgNumber}
              onChangeText={(v) => setOrgNumber(formatOrgNumber(v))}
              keyboardType="number-pad"
              placeholder="923 609 016"
              maxLength={11}
              error={errors.orgNumber}
            />
          </>
        ) : null}
        <TextField label={t('PHONE')} value={phone} onChangeText={setPhone} keyboardType="phone-pad" placeholder="912 34 567" autoComplete="tel" />
        <TextField
          label={t('EMAIL')}
          value={email}
          onChangeText={setEmail}
          keyboardType="email-address"
          autoCapitalize="none"
          placeholder={t('EMAIL_PLACEHOLDER')}
          error={errors.email}
          hint={t('CLIENT_EMAIL_HINT')}
        />

        <View style={{ gap: spacing.lg }}>
          <TextField label={t('STREET_ADDRESS')} value={line1} onChangeText={setLine1} placeholder={t('STREET_ADDRESS_PLACEHOLDER')} />
          <View style={styles.row}>
            <View style={{ width: 120 }}>
              <TextField label={t('POSTAL_CODE')} value={postalCode} onChangeText={setPostalCode} keyboardType="number-pad" maxLength={4} placeholder="5003" error={errors.postalCode} />
            </View>
            <View style={{ flex: 1 }}>
              <TextField label={t('CITY')} value={city} onChangeText={setCity} placeholder={t('CITY_PLACEHOLDER')} />
            </View>
          </View>
        </View>

        <TextField
          label={t('NOTES')}
          value={notes}
          onChangeText={setNotes}
          multiline
          maxLength={5000}
          placeholder={t('CLIENT_NOTES_PLACEHOLDER')}
          hint={t('CLIENT_NOTES_HINT')}
        />
      </ScrollView>
      <BottomBar>
        <Button title={editing ? t('SAVE_CHANGES') : t('SAVE_CLIENT')} icon="checkmark" loading={saving} onPress={save} />
      </BottomBar>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xl, paddingBottom: spacing.xxxl },
  row: { flexDirection: 'row', gap: spacing.md },
});
QUP_EOF_6

# ---- src/app/client/[id].js
write_file 'src/app/client/[id].js' <<'QUP_EOF_7'
// /qup-work-app/src/app/client/[id].js
// One client from my register: contact details, notes, and the jobs I've done for them.
// From here: start a new assignment, edit, or archive (delete if there are no jobs yet).
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { useCallback, useRef, useState } from 'react';
import { Linking, Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { BackButton, goBackOr } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { Button } from '@/components/Button';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { StatusBadge } from '@/components/StatusBadge';
import { colors, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { api, errorMessage } from '@/lib/api';
import { confirm } from '@/lib/confirm';
import { formatDate } from '@/lib/format';
import { formatOrgNumber } from '@/lib/norway';

export default function ClientScreen() {
  const { id } = useLocalSearchParams();
  const insets = useSafeAreaInsets();
  const { t } = useI18n();
  const [data, setData] = useState(null);
  const [loadError, setLoadError] = useState(null);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(null);
  const alive = useRef(true);

  const load = useCallback(async () => {
    try {
      const res = await api(`/clients/${id}`);
      if (!alive.current) return;
      setData(res);
      setLoadError(null);
    } catch (err) {
      if (alive.current) setLoadError(errorMessage(err));
    }
  }, [id]);

  useFocusEffect(
    useCallback(() => {
      alive.current = true;
      load();
      return () => {
        alive.current = false;
      };
    }, [load])
  );

  if (loadError && !data) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl }]}>
        <BackButton />
        <EmptyState icon="person-outline" title={t('CLIENT_NOT_FOUND')} text={loadError} actionTitle={t('TRY_AGAIN')} onAction={load} />
      </View>
    );
  }
  if (!data) return <Loading dark />;

  const { client, jobs } = data;
  const address = [client.address?.line1, [client.address?.postalCode, client.address?.city].filter(Boolean).join(' ')].filter(Boolean).join(', ');
  const rows = [
    client.contactPerson && { icon: 'person-outline', label: t('CONTACT_PERSON'), value: client.contactPerson },
    client.phone && { icon: 'call-outline', label: t('PHONE'), value: client.phone, link: `tel:${client.phone.replace(/\s/g, '')}` },
    client.email && { icon: 'mail-outline', label: t('EMAIL'), value: client.email, link: `mailto:${client.email}` },
    address && { icon: 'location-outline', label: t('FACT_ADDRESS'), value: address },
    client.orgNumber && { icon: 'business-outline', label: t('ORG_NUMBER'), value: formatOrgNumber(client.orgNumber) },
  ].filter(Boolean);

  async function act(key, fn) {
    setBusy(key);
    setError(null);
    try {
      await fn();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(null);
    }
  }

  // The API archives a client with jobs and deletes one without
  async function removeOrArchive() {
    const hasJobs = jobs.length > 0;
    const ok = await confirm(
      hasJobs
        ? { title: t('ARCHIVE_CLIENT_TITLE'), message: t('ARCHIVE_CLIENT_TEXT'), confirmText: t('ARCHIVE') }
        : { title: t('DELETE_CLIENT_TITLE'), message: t('DELETE_CLIENT_TEXT', { name: client.name }), confirmText: t('DELETE_ACTION'), destructive: true }
    );
    if (!ok) return;
    act('remove', async () => {
      const res = await api(`/clients/${client._id}`, { method: 'DELETE' });
      if (res?.archived) await load();
      else goBackOr('/clients');
    });
  }

  const restore = () =>
    act('restore', async () => {
      await api(`/clients/${client._id}`, { method: 'PATCH', body: { archived: false } });
      await load();
    });

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="light" />
      <ScrollView contentContainerStyle={{ paddingBottom: spacing.xxl }}>
        <View style={[styles.hero, { paddingTop: insets.top + spacing.md }]}>
          <View style={styles.heroTop}>
            <BackButton onDark />
            <Button
              title={t('EDIT')}
              icon="create-outline"
              variant="outlineOnDark"
              small
              onPress={() => router.push({ pathname: '/client-form', params: { id: client._id } })}
            />
          </View>
          <View style={styles.identity}>
            <Avatar name={client.name} size={64} />
            <View style={{ flex: 1, gap: 2 }}>
              <AppText variant="caption" onDark muted style={styles.kicker}>
                {client.type === 'business' ? t('CLIENT_BUSINESS') : t('CLIENT_PRIVATE')}
              </AppText>
              <AppText variant="h1" onDark accessibilityRole="header">
                {client.name}
              </AppText>
            </View>
          </View>
          {client.archived ? (
            <View style={styles.archived}>
              <Ionicons name="archive-outline" size={16} color={colors.slate} />
              <AppText variant="smallStrong" color={colors.slate}>
                {t('CLIENT_IS_ARCHIVED')}
              </AppText>
            </View>
          ) : null}
        </View>

        <View style={styles.card}>
          {rows.length ? (
            rows.map((r, i) => (
              <Pressable
                key={r.label}
                disabled={!r.link}
                onPress={() => r.link && Linking.openURL(r.link)}
                accessibilityRole={r.link ? 'link' : undefined}
                style={[styles.detail, i === rows.length - 1 && { borderBottomWidth: 0 }]}
              >
                <Ionicons name={r.icon} size={18} color={colors.textMuted} />
                <View style={{ flex: 1 }}>
                  <AppText variant="caption" muted>
                    {r.label}
                  </AppText>
                  <AppText variant="bodyStrong" color={r.link ? colors.info : undefined}>
                    {r.value}
                  </AppText>
                </View>
              </Pressable>
            ))
          ) : (
            <AppText variant="small" muted style={{ paddingVertical: spacing.lg }}>
              {t('CLIENT_NO_DETAILS')}
            </AppText>
          )}
        </View>

        {client.notes ? (
          <View style={styles.section}>
            <AppText variant="title">{t('NOTES')}</AppText>
            <View style={styles.notes}>
              <AppText variant="body">{client.notes}</AppText>
            </View>
          </View>
        ) : null}

        <View style={styles.section}>
          <ErrorBanner message={error} />
          <AppText variant="title">{t('CLIENT_JOBS')}</AppText>
          {jobs.length ? (
            jobs.map((job) => (
              <Pressable
                key={job._id}
                onPress={() =>
                  job.contract
                    ? router.push({ pathname: '/contract/[id]', params: { id: job.contract } })
                    : router.push({ pathname: '/job/[id]', params: { id: job._id } })
                }
                accessibilityRole="button"
                style={({ pressed }) => [styles.jobRow, pressed && { opacity: 0.8 }]}
              >
                <View style={{ flex: 1, gap: 4 }}>
                  <AppText variant="bodyStrong" numberOfLines={2}>
                    {job.title}
                  </AppText>
                  <AppText variant="caption" muted>
                    {formatDate(job.createdAt)}
                  </AppText>
                </View>
                <StatusBadge status={job.status} />
              </Pressable>
            ))
          ) : (
            <View style={styles.noJobs}>
              <Ionicons name="clipboard-outline" size={20} color={colors.textMuted} />
              <AppText variant="small" muted style={{ flex: 1 }}>
                {t('CLIENT_NO_JOBS')}
              </AppText>
            </View>
          )}
        </View>

        <View style={styles.section}>
          {client.archived ? (
            <Button title={t('RESTORE_CLIENT')} icon="arrow-undo-outline" variant="outline" small loading={busy === 'restore'} onPress={restore} style={{ alignSelf: 'flex-start' }} />
          ) : (
            <Button
              title={jobs.length ? t('ARCHIVE_CLIENT') : t('DELETE_CLIENT')}
              icon={jobs.length ? 'archive-outline' : 'trash-outline'}
              variant="danger"
              small
              loading={busy === 'remove'}
              onPress={removeOrArchive}
              style={{ alignSelf: 'flex-start' }}
            />
          )}
        </View>
      </ScrollView>

      {!client.archived ? (
        <BottomBar>
          <Button
            title={t('NEW_ASSIGNMENT')}
            icon="add-circle-outline"
            onPress={() => router.push({ pathname: '/new-assignment', params: { client: client._id } })}
          />
        </BottomBar>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  hero: { backgroundColor: colors.slate, paddingHorizontal: spacing.xl, paddingBottom: spacing.xxxl + spacing.lg, gap: spacing.lg },
  heroTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  identity: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  kicker: { textTransform: 'uppercase', letterSpacing: 1.2 },
  archived: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    alignSelf: 'flex-start',
    backgroundColor: colors.hivis,
    borderRadius: radius.pill,
    paddingHorizontal: spacing.md,
    paddingVertical: 4,
  },
  card: { marginTop: -spacing.xxxl, marginHorizontal: spacing.xl, backgroundColor: colors.paper, borderRadius: radius.ticket, paddingHorizontal: spacing.lg },
  detail: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    paddingVertical: spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.line,
  },
  section: { marginTop: spacing.xl, marginHorizontal: spacing.xl, gap: spacing.md, maxWidth: 640 },
  notes: { backgroundColor: colors.paper, borderRadius: radius.ticket, padding: spacing.lg, borderLeftWidth: 4, borderLeftColor: colors.hivis },
  jobRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.lg,
    borderRadius: radius.ticket,
    backgroundColor: colors.paper,
  },
  noJobs: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.lg,
    borderRadius: radius.ticket,
    borderWidth: 1.5,
    borderStyle: 'dashed',
    borderColor: colors.line,
  },
});
QUP_EOF_7

# ---- src/app/clients.js
write_file 'src/app/clients.js' <<'QUP_EOF_8'
// /qup-work-app/src/app/clients.js
// Pro: my own client register, for work that doesn't come through the marketplace.
// Shared with everyone in the company. Archived clients are kept for old jobs and invoices.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useRef, useState } from 'react';
import { FlatList, Pressable, StyleSheet, View } from 'react-native';
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
import { SearchBar } from '@/components/SearchBar';
import { SignInPrompt } from '@/components/SignInPrompt';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { useDebounced, usePaged, withQuery } from '@/lib/usePaged';

export default function ClientsScreen() {
  const insets = useSafeAreaInsets();
  const { user, isPro } = useAuth();
  const { t } = useI18n();

  if (!user || !isPro) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md }]}>
        <View style={{ paddingHorizontal: spacing.xl }}>
          <BackButton />
        </View>
        <SignInPrompt icon="people-outline" title={t('CLIENTS')} text={t('CLIENTS_PRO_ONLY')} />
      </View>
    );
  }
  return <ClientList />;
}

function ClientList() {
  const insets = useSafeAreaInsets();
  const { t } = useI18n();
  const [query, setQuery] = useState('');
  const [archived, setArchived] = useState(false);
  const q = useDebounced(query.trim());
  const list = usePaged(withQuery('/clients', { q, archived: archived ? 'true' : undefined }), { limit: 30 });

  // Back from adding or editing a client (the ref keeps the current search)
  const reload = useRef(list.reload);
  reload.current = list.reload;
  const firstFocus = useRef(true);
  useFocusEffect(
    useCallback(() => {
      if (firstFocus.current) firstFocus.current = false;
      else reload.current();
    }, [])
  );

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="dark" />
      <View style={[styles.header, { paddingTop: insets.top + spacing.md }]}>
        <BackButton />
        <AppText variant="h1" accessibilityRole="header">
          {t('CLIENTS')}
        </AppText>
        <SearchBar value={query} onChangeText={setQuery} placeholder={t('SEARCH_CLIENTS')} />
        <ChoiceChips
          options={[
            { value: false, label: t('CLIENTS_ACTIVE') },
            { value: true, label: t('CLIENTS_ARCHIVED') },
          ]}
          value={archived}
          onChange={setArchived}
        />
      </View>

      {list.status === 'loading' ? (
        <Loading />
      ) : (
        <FlatList
          data={list.items}
          keyExtractor={(c) => c._id}
          renderItem={({ item }) => <ClientRow client={item} />}
          contentContainerStyle={styles.list}
          ItemSeparatorComponent={() => <View style={{ height: spacing.sm }} />}
          onEndReached={list.loadMore}
          refreshing={list.refreshing}
          onRefresh={list.refresh}
          keyboardShouldPersistTaps="handled"
          ListHeaderComponent={list.error ? <ErrorBanner message={list.error} onRetry={list.reload} style={{ marginBottom: spacing.md }} /> : null}
          ListEmptyComponent={
            list.error ? null : q ? (
              <EmptyState icon="search-outline" title={t('NO_RESULTS')} text={t('NO_CLIENTS_MATCH')} />
            ) : archived ? (
              <EmptyState icon="archive-outline" title={t('NO_ARCHIVED_CLIENTS')} text={t('NO_ARCHIVED_CLIENTS_TEXT')} />
            ) : (
              <EmptyState icon="people-outline" title={t('NO_CLIENTS')} text={t('NO_CLIENTS_TEXT')} />
            )
          }
        />
      )}

      <BottomBar>
        <Button title={t('NEW_CLIENT')} icon="person-add-outline" onPress={() => router.push('/client-form')} />
      </BottomBar>
    </View>
  );
}

function ClientRow({ client }) {
  const { t } = useI18n();
  const line = [client.address?.city, client.phone ?? client.email].filter(Boolean).join(' · ');
  return (
    <Pressable
      onPress={() => router.push({ pathname: '/client/[id]', params: { id: client._id } })}
      accessibilityRole="button"
      style={({ pressed }) => [styles.row, pressed && { opacity: 0.8 }]}
    >
      <Avatar name={client.name} size={44} dark={client.type === 'business'} />
      <View style={{ flex: 1, gap: 2 }}>
        <AppText variant="bodyStrong" numberOfLines={1}>
          {client.name}
        </AppText>
        <AppText variant="small" muted numberOfLines={1}>
          {client.type === 'business' ? (client.contactPerson ? t('CONTACT_NAME', { name: client.contactPerson }) : t('CLIENT_BUSINESS')) : line || t('CLIENT_PRIVATE')}
        </AppText>
      </View>
      <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  header: { paddingHorizontal: spacing.xl, gap: spacing.md, paddingBottom: spacing.md },
  list: { padding: spacing.xl, paddingTop: spacing.sm, flexGrow: 1 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.md,
    paddingRight: spacing.lg,
    borderRadius: radius.ticket,
    backgroundColor: colors.paper,
  },
});
QUP_EOF_8

# ---- src/app/company/[id].js
write_file 'src/app/company/[id].js' <<'QUP_EOF_9'
// /qup-work-app/src/app/company/[id].js
// Company settings (owner/admin): logo, details, and what goes on invoices
// (bank account, payment terms, footer text). Workers only see the details.
import { useEffect, useState } from 'react';
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, View } from 'react-native';
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useLocalSearchParams } from 'expo-router';
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
import { colors, radius, spacing } from '@/constants/theme';
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

        <Pressable
          onPress={() => router.push({ pathname: '/team/[id]', params: { id } })}
          accessibilityRole="button"
          style={({ pressed }) => [styles.teamRow, pressed && { opacity: 0.7 }]}
        >
          <Ionicons name="people-outline" size={22} color={colors.slate} />
          <View style={{ flex: 1 }}>
            <AppText variant="bodyStrong">{t('TEAM')}</AppText>
            <AppText variant="small" muted>
              {t('TEAM_ROW_HINT')}
            </AppText>
          </View>
          <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
        </Pressable>

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
  teamRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    minHeight: 64,
    paddingHorizontal: spacing.lg,
    borderRadius: radius.lg,
    backgroundColor: colors.paper,
  },
});
QUP_EOF_9

# ---- src/app/contract/[id].js
write_file 'src/app/contract/[id].js' <<'QUP_EOF_10'
// /qup-work-app/src/app/contract/[id].js
// The work after an offer is accepted. Both sides see the same page:
//   pro      → start a step, mark it as done (with photos and a note)
//   customer → approve a step or ask for changes, then complete the job and leave a review
// Steps go: pending → in progress → waiting for approval → approved (or back via "changes").
// The pro adds, changes and deletes steps here. For their own clients (no app account) the
// customer signs on the pro's phone instead of approving in the app, and the pro completes.
// Hours (timer + entries) are in components/HoursSection.js, invoices in InvoicesSection.js.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { useCallback, useRef, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { BackButton } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { Button } from '@/components/Button';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { HoursSection } from '@/components/HoursSection';
import { InvoicesSection } from '@/components/InvoicesSection';
import { MilestoneSheet } from '@/components/MilestoneSheet';
import { Loading } from '@/components/Loading';
import { Perforation } from '@/components/Perforation';
import { PhotoPicker } from '@/components/PhotoPicker';
import { PhotoStrip } from '@/components/PhotoStrip';
import { Sheet } from '@/components/Sheet';
import { SignatureSheet } from '@/components/SignatureSheet';
import { SignInPrompt } from '@/components/SignInPrompt';
import { StarInput } from '@/components/StarInput';
import { StatusBadge } from '@/components/StatusBadge';
import { TextField } from '@/components/TextField';
import { colors, fonts, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { api, errorMessage } from '@/lib/api';
import { openChat } from '@/lib/chat';
import { confirm } from '@/lib/confirm';
import { formatDate, formatMinutes, formatNok } from '@/lib/format';
import { useI18n } from '@/i18n';

export default function ContractScreen() {
  const { id } = useLocalSearchParams();
  const { user } = useAuth();
  const { t } = useI18n();
  const insets = useSafeAreaInsets();

  if (!user) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md }]}>
        <View style={{ paddingHorizontal: spacing.xl }}>
          <BackButton />
        </View>
        <SignInPrompt icon="document-text-outline" title={t('CONTRACT')} text={t('CONTRACT_GUEST_TEXT')} />
      </View>
    );
  }
  return <ContractView key={id} contractId={id} />;
}

function ContractView({ contractId }) {
  const { t } = useI18n();
  const insets = useSafeAreaInsets();
  const [data, setData] = useState(null);
  const [loadError, setLoadError] = useState(null);
  const [actionError, setActionError] = useState(null);
  const [busy, setBusy] = useState(null); // `${milestoneId}:${action}` | 'complete' | 'chat'
  // { type: 'submit' | 'changes' | 'sign', milestone } | { type: 'step', milestone?: m } | { type: 'review' | 'cancel' }
  const [sheet, setSheet] = useState(null);
  const alive = useRef(true);

  const load = useCallback(async () => {
    try {
      const res = await api(`/contracts/${contractId}`);
      if (!alive.current) return;
      setData(res);
      setLoadError(null);
    } catch (err) {
      if (alive.current) setLoadError(errorMessage(err));
    }
  }, [contractId]);

  useFocusEffect(
    useCallback(() => {
      alive.current = true;
      load();
      return () => {
        alive.current = false;
      };
    }, [load])
  );

  if (loadError && !data) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md }]}>
        <View style={{ paddingHorizontal: spacing.xl }}>
          <BackButton />
        </View>
        <EmptyState icon="document-text-outline" title={t('CONTRACT_NOT_FOUND')} text={loadError} actionTitle={t('TRY_AGAIN')} onAction={load} />
      </View>
    );
  }
  if (!data) return <Loading dark />;

  const { contract, side, milestones, hours, myReview } = data;
  const isPro = side === 'pro';
  const active = contract.status === 'active';
  const completed = contract.status === 'completed';
  const steps = milestones.filter((m) => m.status !== 'cancelled');
  const approved = steps.filter((m) => m.status === 'approved').length;
  const allApproved = steps.length > 0 && approved === steps.length;
  const waitingForCustomer = steps.filter((m) => m.status === 'submitted').length;
  // A pro's own client without an app account: they sign on site, and the pro completes the job
  const clientContract = !contract.customer;
  const hourly = contract.priceType === 'hourly';
  const stepsTotal = steps.reduce((sum, m) => sum + (m.amount ?? 0), 0);
  const totalMismatch = !hourly && contract.totalAmount != null && steps.length > 0 && stepsTotal !== contract.totalAmount;

  // The other side of the deal
  const other = isPro
    ? { user: contract.customer, name: contract.customer?.name ?? contract.client?.name, avatarUrl: contract.customer?.avatarUrl, role: t('CUSTOMER') }
    : { user: contract.pro, name: contract.company?.name ?? contract.pro?.name, avatarUrl: contract.company?.logoUrl ?? contract.pro?.avatarUrl, role: t('PRO') };
  // Only the main pro reviews the customer, and only customers with an account can be reviewed
  const canReview = completed && !myReview && (isPro ? Boolean(contract.customer) : true);

  async function run(key, fn) {
    setBusy(key);
    setActionError(null);
    try {
      await fn();
      await load();
      return true;
    } catch (err) {
      setActionError(errorMessage(err));
      return false;
    } finally {
      setBusy(null);
    }
  }

  const ms = (m, action) => `/contracts/${contract._id}/milestones/${m._id}/${action}`;

  const start = (m) => run(`${m._id}:start`, () => api(ms(m, 'start'), { method: 'POST' }));

  async function approve(m) {
    const ok = await confirm({
      title: t('APPROVE_STEP_TITLE'),
      message: t('APPROVE_STEP_TEXT', { title: m.title }),
      confirmText: t('APPROVE'),
    });
    if (ok) run(`${m._id}:approve`, () => api(ms(m, 'approve'), { method: 'POST', body: {} }));
  }

  const msBase = `/contracts/${contract._id}/milestones`;
  const saveStep = (m, body) =>
    m
      ? run(`${m._id}:edit`, () => api(`${msBase}/${m._id}`, { method: 'PATCH', body }))
      : run('add-step', () => api(msBase, { method: 'POST', body }));

  async function deleteStep(m) {
    const ok = await confirm({ title: t('DELETE_STEP_TITLE'), message: t('DELETE_STEP_TEXT', { title: m.title }), confirmText: t('DELETE_ACTION'), destructive: true });
    return ok ? run(`${m._id}:delete`, () => api(`${msBase}/${m._id}`, { method: 'DELETE' })) : false;
  }

  async function complete() {
    const ok = await confirm({
      title: t('COMPLETE_JOB_TITLE'),
      message: clientContract ? t('COMPLETE_CLIENT_JOB_TEXT') : t('COMPLETE_JOB_TEXT'),
      confirmText: t('COMPLETE_JOB'),
    });
    if (!ok) return;
    const done = await run('complete', () => api(`/contracts/${contract._id}/complete`, { method: 'POST' }));
    if (done) setSheet({ type: 'review' }); // the natural next thing to do
  }

  async function message() {
    if (!other.user?._id) return;
    setBusy('chat');
    setActionError(null);
    try {
      await openChat({ participant: other.user._id, job: contract.job?._id });
    } catch (err) {
      setActionError(errorMessage(err));
    } finally {
      setBusy(null);
    }
  }

  const price =
    contract.priceType === 'hourly'
      ? { main: t('PRICE_PER_HOUR', { price: formatNok(contract.hourlyRate) }), sub: t('PRICE_HOURLY') }
      : { main: formatNok(contract.totalAmount), sub: t(contract.priceType === 'estimate' ? 'PRICE_ESTIMATE' : 'PRICE_FIXED') };

  const facts = [
    contract.startDate && { icon: 'play-outline', label: t('FACT_START'), value: formatDate(contract.startDate) },
    contract.endDate && { icon: 'flag-outline', label: t('FACT_END'), value: formatDate(contract.endDate) },
    (contract.priceType === 'hourly' || hours.minutes > 0) && {
      icon: 'time-outline',
      label: t('FACT_HOURS_LOGGED'),
      value: formatMinutes(hours.minutes),
    },
    {
      icon: contract.paymentMethod === 'escrow' ? 'shield-checkmark-outline' : 'receipt-outline',
      label: t('FACT_PAYMENT'),
      value: contract.paymentMethod === 'escrow' ? t('PAYMENT_ESCROW') : t('PAYMENT_INVOICE'),
    },
  ].filter(Boolean);

  // What the bottom bar offers right now
  let bottom = null;
  if (active && (!isPro || clientContract) && allApproved) {
    bottom = <Button title={t('COMPLETE_JOB')} icon="checkmark-done" loading={busy === 'complete'} onPress={complete} />;
  } else if (active && !isPro && waitingForCustomer) {
    bottom = (
      <AppText variant="smallStrong" center color={colors.info}>
        {t('STEPS_WAITING_FOR_YOU', { n: waitingForCustomer })}
      </AppText>
    );
  } else if (active && isPro && allApproved && contract.customer) {
    bottom = (
      <AppText variant="small" muted center>
        {t('WAITING_FOR_CUSTOMER_TO_COMPLETE')}
      </AppText>
    );
  } else if (canReview) {
    bottom = <Button title={t('RATE_NAME', { name: other.name ?? '' })} icon="star" onPress={() => setSheet({ type: 'review' })} />;
  }

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="light" />
      <ScrollView contentContainerStyle={{ paddingBottom: spacing.xxl }}>
        <View style={[styles.hero, { paddingTop: insets.top + spacing.md }]}>
          <View style={styles.heroTop}>
            <BackButton onDark />
            <StatusBadge status={contract.status} kind="contract" />
          </View>
          <View style={{ gap: 4 }}>
            <AppText variant="caption" onDark muted style={styles.kicker}>
              {t('CONTRACT')}
            </AppText>
            <AppText variant="h1" onDark accessibilityRole="header">
              {contract.title}
            </AppText>
          </View>
          <View style={styles.party}>
            <Avatar name={other.name} url={other.avatarUrl} size={44} />
            <View style={{ flex: 1 }}>
              <AppText variant="caption" onDark muted>
                {other.role}
              </AppText>
              <AppText variant="bodyStrong" onDark numberOfLines={1}>
                {other.name ?? t('UNKNOWN')}
              </AppText>
            </View>
            {other.user?._id ? (
              <Button title={t('MESSAGE')} icon="chatbubble-outline" variant="outlineOnDark" small loading={busy === 'chat'} onPress={message} />
            ) : null}
          </View>
        </View>

        <View style={styles.ticket}>
          <View style={styles.ticketTop}>
            <View style={{ flex: 1, gap: 2 }}>
              <AppText variant="caption" muted>
                {t('AGREED_PRICE')}
              </AppText>
              <AppText variant="h2">{price.main}</AppText>
              <AppText variant="caption" muted>
                {price.sub}
              </AppText>
            </View>
          </View>
          <Perforation notchColor={colors.concrete} />
          <View style={styles.facts}>
            {facts.map((f) => (
              <View key={f.label} style={styles.fact}>
                <Ionicons name={f.icon} size={18} color={colors.textMuted} />
                <AppText variant="small" muted style={{ width: 118 }}>
                  {f.label}
                </AppText>
                <AppText variant="smallStrong" style={{ flex: 1, textAlign: 'right' }}>
                  {f.value}
                </AppText>
              </View>
            ))}
            {steps.length ? (
              <View style={{ gap: 6, marginTop: spacing.xs }}>
                <View style={styles.progressTrack} accessibilityRole="progressbar" accessibilityValue={{ min: 0, max: steps.length, now: approved }}>
                  <View style={[styles.progressFill, { width: `${(approved / steps.length) * 100}%` }]} />
                </View>
                <AppText variant="caption" muted>
                  {t('STEPS_APPROVED', { done: approved, total: steps.length })}
                </AppText>
              </View>
            ) : null}
          </View>
        </View>

        {completed ? (
          <View style={[styles.section, styles.doneBanner]}>
            <Ionicons name="checkmark-circle" size={22} color={colors.pine} />
            <AppText variant="bodyStrong" color={colors.pine} style={{ flex: 1 }}>
              {t('JOB_COMPLETED_ON', { date: formatDate(contract.completedAt) })}
            </AppText>
          </View>
        ) : null}

        <View style={styles.section}>
          <ErrorBanner message={actionError} />
        </View>

        {/* On hourly jobs the hours come first; otherwise they're extra detail under the steps */}
        {contract.priceType === 'hourly' ? <HoursSection contract={contract} side={side} onChanged={load} /> : null}

        <View style={styles.section}>
          <AppText variant="title">{t('STEPS_TITLE')}</AppText>
          {totalMismatch ? (
            <AppText variant="small" color={colors.amber}>
              {t('STEPS_TOTAL_MISMATCH', { steps: formatNok(stepsTotal), total: formatNok(contract.totalAmount) })}
            </AppText>
          ) : null}
          <View>
            {milestones.map((m, i) => (
              <MilestoneRow
                key={m._id}
                milestone={m}
                number={i + 1}
                last={i === milestones.length - 1}
                hourly={contract.priceType === 'hourly'}
                side={side}
                active={active}
                busy={busy}
                onStart={() => start(m)}
                onSubmit={() => setSheet({ type: 'submit', milestone: m })}
                onApprove={() => approve(m)}
                onChanges={() => setSheet({ type: 'changes', milestone: m })}
                onEdit={() => setSheet({ type: 'step', milestone: m })}
                onSign={clientContract ? () => setSheet({ type: 'sign', milestone: m }) : null}
              />
            ))}
          </View>
          {active && isPro ? (
            <Button title={t('ADD_STEP')} icon="add" variant="outline" small onPress={() => setSheet({ type: 'step' })} style={{ alignSelf: 'flex-start' }} />
          ) : null}
        </View>

        {contract.priceType !== 'hourly' ? <HoursSection contract={contract} side={side} onChanged={load} /> : null}

        <InvoicesSection contract={contract} side={side} hours={hours} onChanged={load} />

        {completed && myReview ? (
          <View style={[styles.section, styles.reviewCard]}>
            <AppText variant="caption" muted>
              {t('YOUR_REVIEW')}
            </AppText>
            <View style={{ flexDirection: 'row', gap: 2 }} accessibilityLabel={t('RATING_OUT_OF_5', { n: myReview.rating })}>
              {[1, 2, 3, 4, 5].map((n) => (
                <Ionicons key={n} name={n <= myReview.rating ? 'star' : 'star-outline'} size={18} color={colors.hivisDeep} />
              ))}
            </View>
            {myReview.comment ? <AppText variant="body">{myReview.comment}</AppText> : null}
          </View>
        ) : null}

        {contract.status === 'cancelled' ? (
          <View style={[styles.section, styles.cancelledBanner]}>
            <AppText variant="bodyStrong" color={colors.danger}>
              {t('CONTRACT_CANCELLED_ON', { date: formatDate(contract.cancelledAt) })}
            </AppText>
            {contract.cancelReason ? (
              <AppText variant="small" muted>
                {contract.cancelReason}
              </AppText>
            ) : null}
          </View>
        ) : null}

        {active ? (
          <View style={styles.section}>
            <Button title={t('CANCEL_CONTRACT')} icon="close-circle-outline" variant="danger" small onPress={() => setSheet({ type: 'cancel' })} style={{ alignSelf: 'flex-start' }} />
          </View>
        ) : null}
      </ScrollView>

      {bottom ? <BottomBar>{bottom}</BottomBar> : null}

      <SubmitSheet
        milestone={sheet?.type === 'submit' ? sheet.milestone : null}
        onClose={() => setSheet(null)}
        onSend={(body) => run(`${sheet.milestone._id}:submit`, () => api(ms(sheet.milestone, 'submit'), { method: 'POST', body }))}
      />
      <ChangesSheet
        milestone={sheet?.type === 'changes' ? sheet.milestone : null}
        onClose={() => setSheet(null)}
        onSend={(feedback) =>
          run(`${sheet.milestone._id}:changes`, () => api(ms(sheet.milestone, 'request-changes'), { method: 'POST', body: { feedback } }))
        }
      />
      <MilestoneSheet
        visible={sheet?.type === 'step'}
        milestone={sheet?.type === 'step' ? (sheet.milestone ?? null) : null}
        hourly={hourly}
        onClose={() => setSheet(null)}
        onSave={(body) => saveStep(sheet?.milestone, body)}
        onDelete={() => deleteStep(sheet.milestone)}
      />
      <SignatureSheet
        milestone={sheet?.type === 'sign' ? sheet.milestone : null}
        onClose={() => setSheet(null)}
        onSign={(signature) => run(`${sheet.milestone._id}:approve`, () => api(ms(sheet.milestone, 'approve'), { method: 'POST', body: { signature } }))}
      />
      <CancelSheet
        visible={sheet?.type === 'cancel'}
        title={contract.title}
        onClose={() => setSheet(null)}
        onSend={(reason) => run('cancel', () => api(`/contracts/${contract._id}/cancel`, { method: 'POST', body: { reason } }))}
      />
      <ReviewSheet
        visible={sheet?.type === 'review' && canReview}
        name={other.name}
        onClose={() => setSheet(null)}
        onSend={(body) => run('review', () => api('/reviews', { method: 'POST', body: { ...body, contract: contract._id } }))}
      />
    </View>
  );
}

// One step on the timeline: number (or a tick), title, status, what was delivered, and the buttons
function MilestoneRow({ milestone: m, number, last, hourly, side, active, busy, onStart, onSubmit, onApprove, onChanges, onEdit, onSign }) {
  const { t } = useI18n();
  const done = m.status === 'approved';
  const isBusy = (action) => busy === `${m._id}:${action}`;
  const anyBusy = Boolean(busy);
  const editable = active && side === 'pro' && ['pending', 'in_progress', 'changes_requested'].includes(m.status);

  let actions = null;
  if (active && side === 'pro') {
    if (m.status === 'pending') {
      actions = (
        <>
          <Button title={t('START')} icon="play" variant="dark" small loading={isBusy('start')} disabled={anyBusy} onPress={onStart} style={{ flexGrow: 1 }} />
          <Button title={t('MARK_AS_DONE')} variant="outline" small disabled={anyBusy} onPress={onSubmit} style={{ flexGrow: 1 }} />
        </>
      );
    } else if (m.status === 'in_progress' || m.status === 'changes_requested') {
      actions = <Button title={t('MARK_AS_DONE')} icon="checkmark" small disabled={anyBusy} onPress={onSubmit} style={{ flexGrow: 1 }} />;
    } else if (m.status === 'submitted' && !onSign) {
      actions = (
        <AppText variant="small" muted>
          {t('WAITING_FOR_APPROVAL')}
        </AppText>
      );
    }
    // The client signs on the pro's phone once the step is done
    if (onSign && m.status !== 'approved' && m.status !== 'cancelled') {
      actions = (
        <>
          {actions}
          <Button title={t('SIGN_ON_SITE')} icon="create-outline" variant="dark" small disabled={anyBusy} onPress={onSign} style={{ flexGrow: 1 }} />
        </>
      );
    }
  } else if (active && side === 'customer') {
    if (m.status === 'submitted') {
      actions = (
        <>
          <Button title={t('APPROVE')} icon="checkmark" small loading={isBusy('approve')} disabled={anyBusy} onPress={onApprove} style={{ flexGrow: 1 }} />
          <Button title={t('ASK_FOR_CHANGES')} variant="outline" small disabled={anyBusy} onPress={onChanges} style={{ flexGrow: 1 }} />
        </>
      );
    } else if (m.status === 'in_progress' || m.status === 'changes_requested') {
      actions = (
        <AppText variant="small" muted>
          {t('PRO_IS_WORKING')}
        </AppText>
      );
    }
  }

  return (
    <View style={styles.step}>
      {/* The rail: a numbered stub, joined to the next one by a line */}
      <View style={styles.rail}>
        <View style={[styles.stepNo, done && styles.stepNoDone, m.status === 'submitted' && styles.stepNoWaiting]}>
          {done ? (
            <Ionicons name="checkmark" size={18} color={colors.paper} />
          ) : (
            <AppText style={styles.stepNoText} color={m.status === 'submitted' ? colors.slate : colors.text}>
              {number}
            </AppText>
          )}
        </View>
        {!last ? <View style={[styles.railLine, done && { backgroundColor: colors.pine }]} /> : null}
      </View>

      <View style={[styles.stepCard, last && { marginBottom: 0 }]}>
        <View style={styles.stepHead}>
          <AppText variant="title" style={{ flex: 1 }}>
            {m.title}
          </AppText>
          {!hourly && m.amount != null ? <AppText variant="smallStrong">{formatNok(m.amount)}</AppText> : null}
          {editable ? (
            <Pressable onPress={onEdit} hitSlop={10} accessibilityRole="button" accessibilityLabel={t('EDIT_STEP')} style={styles.editStep}>
              <Ionicons name="create-outline" size={18} color={colors.textMuted} />
            </Pressable>
          ) : null}
        </View>
        <View style={styles.stepMeta}>
          <StatusBadge status={m.status} kind="milestone" />
          {m.dueDate && !done ? (
            <AppText variant="caption" muted>
              {t('DUE_DATE', { date: formatDate(m.dueDate) })}
            </AppText>
          ) : null}
          {done && m.approvedAt ? (
            <AppText variant="caption" muted>
              {t('APPROVED_ON', { date: formatDate(m.approvedAt) })}
            </AppText>
          ) : null}
        </View>

        {m.description ? (
          <AppText variant="small" muted>
            {m.description}
          </AppText>
        ) : null}

        {m.status === 'changes_requested' && m.feedback ? (
          <View style={[styles.note, styles.noteChanges]}>
            <AppText variant="caption" color={colors.danger}>
              {t('CHANGES_REQUESTED_LABEL')}
            </AppText>
            <AppText variant="small">{m.feedback}</AppText>
          </View>
        ) : null}

        {m.submissionNote && ['submitted', 'approved', 'changes_requested'].includes(m.status) ? (
          <View style={styles.note}>
            <AppText variant="caption" muted>
              {t('NOTE_FROM_PRO')}
            </AppText>
            <AppText variant="small">{m.submissionNote}</AppText>
          </View>
        ) : null}

        {done && m.feedback ? (
          <View style={styles.note}>
            <AppText variant="caption" muted>
              {t('COMMENT_FROM_CUSTOMER')}
            </AppText>
            <AppText variant="small">{m.feedback}</AppText>
          </View>
        ) : null}

        {m.customerSignature?.name ? (
          <AppText variant="caption" muted>
            {t('SIGNED_BY', { name: m.customerSignature.name })}
          </AppText>
        ) : null}

        <PhotoStrip attachments={m.attachments} />

        {actions ? <View style={styles.stepActions}>{actions}</View> : null}
      </View>
    </View>
  );
}

// Pro: "Mark as done" with an optional note and photos
function SubmitSheet({ milestone, onClose, onSend }) {
  const { t } = useI18n();
  const [note, setNote] = useState('');
  const [photos, setPhotos] = useState([]);
  const [uploading, setUploading] = useState(false);
  const [sending, setSending] = useState(false);
  const [sheetKey, setSheetKey] = useState(0); // fresh picker each time it opens

  function close() {
    setNote('');
    setPhotos([]);
    setSheetKey((k) => k + 1);
    onClose();
  }

  async function send() {
    setSending(true);
    const ok = await onSend({ submissionNote: note.trim() || undefined, attachments: photos });
    setSending(false);
    if (ok) close();
  }

  return (
    <Sheet visible={Boolean(milestone)} onClose={close} title={t('MARK_AS_DONE')} subtitle={milestone?.title}>
      <AppText variant="small" muted>
        {t('SUBMIT_STEP_INTRO')}
      </AppText>
      <PhotoPicker key={sheetKey} tag="after" label={t('PHOTOS_OF_WORK')} onChange={setPhotos} onBusyChange={setUploading} />
      <TextField
        label={t('NOTE_TO_CUSTOMER')}
        value={note}
        onChangeText={setNote}
        multiline
        placeholder={t('NOTE_TO_CUSTOMER_PLACEHOLDER')}
        maxLength={3000}
      />
      <Button
        title={uploading ? t('UPLOADING_PHOTOS') : t('SEND_FOR_APPROVAL')}
        icon="send"
        loading={sending}
        disabled={uploading}
        onPress={send}
      />
    </Sheet>
  );
}

// Customer: "Ask for changes" needs a few words on what's missing
function ChangesSheet({ milestone, onClose, onSend }) {
  const { t } = useI18n();
  const [feedback, setFeedback] = useState('');
  const [sending, setSending] = useState(false);

  function close() {
    setFeedback('');
    onClose();
  }

  async function send() {
    setSending(true);
    const ok = await onSend(feedback.trim());
    setSending(false);
    if (ok) close();
  }

  return (
    <Sheet visible={Boolean(milestone)} onClose={close} title={t('ASK_FOR_CHANGES')} subtitle={milestone?.title}>
      <TextField
        label={t('WHAT_SHOULD_CHANGE')}
        value={feedback}
        onChangeText={setFeedback}
        multiline
        placeholder={t('WHAT_SHOULD_CHANGE_PLACEHOLDER')}
        maxLength={3000}
        autoFocus
      />
      <Button title={t('SEND_TO_PRO')} icon="send" loading={sending} disabled={feedback.trim().length < 3} onPress={send} />
    </Sheet>
  );
}

// Either side can call the job off while it's running. The reason is optional but shown to both.
function CancelSheet({ visible, title, onClose, onSend }) {
  const { t } = useI18n();
  const [reason, setReason] = useState('');
  const [sending, setSending] = useState(false);

  function close() {
    setReason('');
    onClose();
  }

  async function send() {
    setSending(true);
    const ok = await onSend(reason.trim() || undefined);
    setSending(false);
    if (ok) close();
  }

  return (
    <Sheet visible={visible} onClose={close} title={t('CANCEL_CONTRACT')} subtitle={title}>
      <AppText variant="small" muted>
        {t('CANCEL_CONTRACT_INTRO')}
      </AppText>
      <TextField label={t('CANCEL_REASON')} value={reason} onChangeText={setReason} multiline placeholder={t('CANCEL_REASON_PLACEHOLDER')} maxLength={1000} />
      <Button title={t('CANCEL_CONTRACT')} variant="danger" icon="close-circle-outline" loading={sending} onPress={send} />
    </Sheet>
  );
}

// Stars and a few words, once the job is completed
function ReviewSheet({ visible, name, onClose, onSend }) {
  const { t } = useI18n();
  const [rating, setRating] = useState(0);
  const [comment, setComment] = useState('');
  const [sending, setSending] = useState(false);

  async function send() {
    setSending(true);
    const ok = await onSend({ rating, comment: comment.trim() || undefined });
    setSending(false);
    if (ok) onClose();
  }

  return (
    <Sheet visible={visible} onClose={onClose} title={t('RATE_NAME', { name: name ?? '' })} subtitle={t('REVIEW_INTRO')}>
      <StarInput value={rating} onChange={setRating} />
      <TextField
        label={t('REVIEW_COMMENT')}
        value={comment}
        onChangeText={setComment}
        multiline
        placeholder={t('REVIEW_COMMENT_PLACEHOLDER')}
        maxLength={3000}
      />
      <Button title={t('PUBLISH_REVIEW')} icon="star" loading={sending} disabled={!rating} onPress={send} />
    </Sheet>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  hero: {
    backgroundColor: colors.slate,
    paddingHorizontal: spacing.xl,
    paddingBottom: spacing.xxxl + spacing.lg,
    gap: spacing.lg,
  },
  heroTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  kicker: { textTransform: 'uppercase', letterSpacing: 1.2 },
  party: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    paddingTop: spacing.md,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: colors.slateLine,
  },
  ticket: { marginTop: -spacing.xxxl, marginHorizontal: spacing.xl, backgroundColor: colors.paper, borderRadius: radius.ticket },
  ticketTop: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, padding: spacing.lg },
  facts: { padding: spacing.lg, paddingTop: spacing.sm, gap: spacing.md },
  fact: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  progressTrack: { height: 8, borderRadius: 4, backgroundColor: colors.concrete, overflow: 'hidden' },
  progressFill: { height: '100%', borderRadius: 4, backgroundColor: colors.pine },
  section: { marginTop: spacing.xl, marginHorizontal: spacing.xl, gap: spacing.md, maxWidth: 640 },
  doneBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    padding: spacing.lg,
    borderRadius: radius.ticket,
    backgroundColor: colors.pineSoft,
  },
  step: { flexDirection: 'row', gap: spacing.md },
  rail: { alignItems: 'center', width: 34 },
  stepNo: {
    width: 34,
    height: 34,
    borderRadius: 6,
    backgroundColor: colors.paper,
    borderWidth: 1.5,
    borderColor: colors.line,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stepNoDone: { backgroundColor: colors.pine, borderColor: colors.pine },
  stepNoWaiting: { backgroundColor: colors.hivis, borderColor: colors.hivis },
  stepNoText: { fontFamily: fonts.heavy, fontSize: 15, lineHeight: 18 },
  railLine: { flex: 1, width: 2, backgroundColor: colors.line, marginVertical: 4 },
  stepCard: {
    flex: 1,
    backgroundColor: colors.paper,
    borderRadius: radius.ticket,
    padding: spacing.lg,
    gap: spacing.sm,
    marginBottom: spacing.md,
  },
  stepHead: { flexDirection: 'row', alignItems: 'flex-start', gap: spacing.sm },
  stepMeta: { flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap', gap: spacing.sm },
  note: { borderLeftWidth: 3, borderLeftColor: colors.line, paddingLeft: spacing.md, gap: 2 },
  noteChanges: { borderLeftColor: colors.danger },
  stepActions: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginTop: spacing.xs },
  editStep: { width: 28, height: 28, alignItems: 'center', justifyContent: 'center', marginTop: -2 },
  cancelledBanner: { padding: spacing.lg, borderRadius: radius.ticket, backgroundColor: colors.dangerSoft, gap: 4 },
  reviewCard: { backgroundColor: colors.paper, borderRadius: radius.ticket, padding: spacing.lg, gap: spacing.sm },
});
QUP_EOF_10

# ---- src/app/delete-account.js
write_file 'src/app/delete-account.js' <<'QUP_EOF_11'
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
QUP_EOF_11

# ---- src/app/edit-pro.js
write_file 'src/app/edit-pro.js' <<'QUP_EOF_12'
// /qup-work-app/src/app/edit-pro.js
// Edit your public pro profile: what you do, where, your rate, and whether
// customers can find you. Same fields as step 2 and 3 of "Become a pro".
import { router } from 'expo-router';
import { useEffect, useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, Switch, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton, goBackOr } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { Button } from '@/components/Button';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { AreaFields, ServiceFields, toOre, validateServices } from '@/components/ProFields';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { api, ApiError, errorMessage } from '@/lib/api';

const kroner = (ore) => (ore ? String(ore / 100).replace('.', ',') : '');

export default function EditProScreen() {
  const insets = useSafeAreaInsets();
  const { user, refreshSession } = useAuth();
  const { t } = useI18n();
  const [loaded, setLoaded] = useState(false);
  const [missing, setMissing] = useState(false);
  const [services, setServices] = useState(null);
  const [area, setArea] = useState(null);
  const [visible, setVisible] = useState(true);
  const [alerts, setAlerts] = useState(true);
  const [errors, setErrors] = useState({});
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    if (!user) return;
    api('/pros/me')
      .then(({ profile: p }) => {
        setServices({
          categories: (p.categories ?? []).map((c) => c._id ?? c),
          headline: p.headline ?? '',
          bio: p.bio ?? '',
          hourlyRate: kroner(p.hourlyRate),
          workType: p.workType ?? 'onsite',
        });
        // The postcode isn't stored; show the saved place until a new postcode is typed
        const place = p.serviceArea?.municipalities?.[0] ? { city: p.serviceArea.municipalities[0], location: p.serviceArea.location } : null;
        setArea({ postalCode: '', place, radiusKm: p.serviceArea?.radiusKm ?? 25 });
        setVisible(Boolean(p.availableForMarketplace));
        setAlerts(p.notifyNewJobs !== false);
      })
      .catch((err) => {
        if (err instanceof ApiError && err.status === 404) setMissing(true);
        else setError(errorMessage(err));
      })
      .finally(() => setLoaded(true));
  }, [user]);

  if (!loaded) return <Loading />;
  if (missing) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl }]}>
        <BackButton />
        <EmptyState icon="construct-outline" title={t('NO_PRO_PROFILE')} text={t('NO_PRO_PROFILE_TEXT')} actionTitle={t('BECOME_PRO')} onAction={() => router.replace('/become-pro')} />
      </View>
    );
  }
  if (!services) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl, gap: spacing.lg }]}>
        <BackButton />
        <ErrorBanner message={error} />
      </View>
    );
  }

  async function save() {
    const errs = validateServices(services);
    setErrors(errs);
    if (Object.keys(errs).length) return;
    setSaving(true);
    setError(null);
    setSaved(false);
    try {
      const remoteOnly = services.workType === 'remote';
      const serviceArea = { radiusKm: area.radiusKm };
      if (!remoteOnly && area.place) {
        if (area.place.location) serviceArea.location = area.place.location;
        serviceArea.municipalities = [area.place.municipality ?? area.place.city].filter(Boolean);
      }
      await api('/pros/me', {
        method: 'PUT',
        body: {
          categories: services.categories,
          headline: services.headline.trim(),
          bio: services.bio.trim(),
          hourlyRate: toOre(services.hourlyRate) ?? null,
          workType: services.workType,
          serviceArea,
          availableForMarketplace: visible,
          notifyNewJobs: alerts,
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
          {t('EDIT_PRO_PROFILE')}
        </AppText>
        <ErrorBanner message={error} />

        <View style={styles.visible}>
          <View style={{ flex: 1, gap: 2 }}>
            <AppText variant="bodyStrong">{t('STAT_VISIBLE')}</AppText>
            <AppText variant="small" muted>
              {visible ? t('VISIBLE_ON_TEXT') : t('VISIBLE_OFF_TEXT')}
            </AppText>
          </View>
          <Switch
            value={visible}
            onValueChange={setVisible}
            trackColor={{ true: colors.slate, false: colors.line }}
            thumbColor={visible ? colors.hivis : colors.paper}
            ios_backgroundColor={colors.line}
          />
        </View>

        <View style={styles.visible}>
          <View style={{ flex: 1, gap: 2 }}>
            <AppText variant="bodyStrong">{t('JOB_ALERTS')}</AppText>
            <AppText variant="small" muted>
              {!visible ? t('JOB_ALERTS_NEEDS_VISIBLE') : alerts ? t('JOB_ALERTS_ON_TEXT') : t('JOB_ALERTS_OFF_TEXT')}
            </AppText>
          </View>
          <Switch
            value={alerts && visible}
            onValueChange={setAlerts}
            disabled={!visible}
            trackColor={{ true: colors.slate, false: colors.line }}
            thumbColor={alerts && visible ? colors.hivis : colors.paper}
            ios_backgroundColor={colors.line}
          />
        </View>
        <ServiceFields value={services} onChange={setServices} errors={errors} />
        {services.workType !== 'remote' ? (
          <>
            <AppText variant="title">{t('SERVICE_AREA')}</AppText>
            <AreaFields value={area} onChange={setArea} />
          </>
        ) : null}
      </ScrollView>
      <BottomBar>
        <Button title={saved ? t('SAVED') : t('SAVE_CHANGES')} icon="checkmark" loading={saving} onPress={save} />
      </BottomBar>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xl, paddingBottom: spacing.xxxl },
  visible: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, padding: spacing.lg, borderRadius: radius.lg, backgroundColor: colors.paper },
});
QUP_EOF_12

# ---- src/app/invoice/[id].js
write_file 'src/app/invoice/[id].js' <<'QUP_EOF_13'
// /qup-work-app/src/app/invoice/[id].js
// One invoice, laid out like the paper version: from, to, lines, totals and how to pay.
//   company (owner/admin) → draft: edit, send, delete · sent: mark as paid
//   customer              → reads it, with the account number and KID to pay
// Sending gives the invoice its number and KID; after that it can't be changed.
// Sending also emails the PDF to the recipient (if there's an email address). Both sides can
// open the PDF, and the company can email it again, e.g. to a corrected address.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Linking, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton, goBackOr } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { ChoiceChips } from '@/components/ChoiceChips';
import { Button } from '@/components/Button';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { InvoiceEditor } from '@/components/InvoiceEditor';
import { Loading } from '@/components/Loading';
import { Perforation } from '@/components/Perforation';
import { Sheet } from '@/components/Sheet';
import { SignInPrompt } from '@/components/SignInPrompt';
import { StatusBadge } from '@/components/StatusBadge';
import { TextField } from '@/components/TextField';
import { colors, fonts, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { currentLocale, useI18n } from '@/i18n';
import { api, API_URL, errorMessage } from '@/lib/api';
import { confirm } from '@/lib/confirm';
import { formatDate, formatNok, formatNumber, invoiceStatus, UNITS } from '@/lib/format';

// 12345678903 → "1234.56.78903" (how Norwegian account numbers are written)
// The PDF and email are Norwegian, or English when the app is in another language
const defaultInvoiceLang = () => (/^(nb|nn|no)\b/i.test(currentLocale()) ? 'nb' : 'en');

const formatAccount = (n) => {
  const d = String(n ?? '').replace(/\D/g, '');
  return d.length === 11 ? `${d.slice(0, 4)}.${d.slice(4, 6)}.${d.slice(6)}` : n;
};

export default function InvoiceScreen() {
  const { id } = useLocalSearchParams();
  const { user } = useAuth();
  const { t } = useI18n();
  const insets = useSafeAreaInsets();

  if (!user) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md }]}>
        <View style={{ paddingHorizontal: spacing.xl }}>
          <BackButton />
        </View>
        <SignInPrompt icon="receipt-outline" title={t('INVOICE')} text={t('INVOICES_GUEST_TEXT')} />
      </View>
    );
  }
  return <InvoiceView key={id} invoiceId={id} />;
}

function InvoiceView({ invoiceId }) {
  const { t } = useI18n();
  const insets = useSafeAreaInsets();
  const [data, setData] = useState(null);
  const [loadError, setLoadError] = useState(null);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(null); // 'send' | 'paid' | 'delete'
  const [editing, setEditing] = useState(false);
  const [emailing, setEmailing] = useState(false);
  const [emailNotice, setEmailNotice] = useState(null); // { tone, text } after sending
  const alive = useRef(true);

  const load = useCallback(async () => {
    try {
      const res = await api(`/invoices/${invoiceId}`);
      if (!alive.current) return;
      setData(res);
      setLoadError(null);
    } catch (err) {
      if (alive.current) setLoadError(errorMessage(err));
    }
  }, [invoiceId]);

  useFocusEffect(
    useCallback(() => {
      alive.current = true;
      load();
      return () => {
        alive.current = false;
      };
    }, [load])
  );

  if (loadError && !data) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md }]}>
        <View style={{ paddingHorizontal: spacing.xl }}>
          <BackButton />
        </View>
        <EmptyState icon="receipt-outline" title={t('INVOICE_NOT_FOUND')} text={loadError} actionTitle={t('TRY_AGAIN')} onAction={load} />
      </View>
    );
  }
  if (!data) return <Loading dark />;

  const { invoice, role } = data;
  const isCompany = role === 'company';
  const status = invoiceStatus(invoice);
  const draft = invoice.status === 'draft';
  const company = invoice.company ?? {};
  const bank = company.invoiceSettings?.bankAccount;
  const vatRegistered = company.vatRegistered !== false;

  async function run(key, fn) {
    setBusy(key);
    setError(null);
    try {
      await fn();
      return true;
    } catch (err) {
      setError(errorMessage(err));
      return false;
    } finally {
      setBusy(null);
    }
  }

  // What happened to the email, in words
  function describeEmail(email) {
    if (email?.sent) return { tone: 'ok', text: t('INVOICE_EMAILED_TO', { email: email.to }) };
    if (email?.error === 'no_email') return { tone: 'warn', text: t('INVOICE_NO_EMAIL') };
    if (email?.saved) return { tone: 'warn', text: t('INVOICE_EMAIL_NOT_SET_UP') };
    return { tone: 'error', text: t('INVOICE_EMAIL_FAILED', { error: email?.error ?? '' }) };
  }

  async function send() {
    const to = invoice.billTo?.email;
    const ok = await confirm({
      title: t('SEND_INVOICE_TITLE'),
      message: [
        t('SEND_INVOICE_TEXT', { name: invoice.billTo?.name ?? '', total: formatNok(invoice.total) }),
        to ? t('SEND_INVOICE_EMAIL_TO', { email: to }) : t('SEND_INVOICE_NO_EMAIL'),
      ].join('\n\n'),
      confirmText: t('SEND_INVOICE'),
    });
    if (!ok) return;
    let result = null;
    const sent = await run('send', async () => {
      result = await api(`/invoices/${invoice._id}/send`, { method: 'POST', body: { lang: defaultInvoiceLang() } });
    });
    if (sent) {
      setEmailNotice(describeEmail(result?.email));
      load();
    }
  }

  // The browser can't send our login header, so the API gives a short-lived link
  const openPdf = () =>
    run('pdf', async () => {
      const { path } = await api(`/invoices/${invoice._id}/pdf-link`, { method: 'POST', body: { lang: defaultInvoiceLang() } });
      await Linking.openURL(API_URL + path);
    });

  async function markPaid() {
    const ok = await confirm({ title: t('MARK_PAID_TITLE'), message: t('MARK_PAID_TEXT', { total: formatNok(invoice.total) }), confirmText: t('MARK_PAID') });
    if (ok && (await run('paid', () => api(`/invoices/${invoice._id}/mark-paid`, { method: 'POST', body: {} })))) load();
  }

  async function remove() {
    const ok = await confirm({ title: t('DELETE_DRAFT_TITLE'), message: t('DELETE_DRAFT_TEXT'), confirmText: t('DELETE_ACTION'), destructive: true });
    if (ok && (await run('delete', () => api(`/invoices/${invoice._id}`, { method: 'DELETE' })))) {
      goBackOr(invoice.contract?._id ? `/contract/${invoice.contract._id}` : '/invoices');
    }
  }

  let bottom = null;
  if (isCompany && draft) {
    bottom = (
      <>
        <Button title={t('SEND_INVOICE')} icon="send" loading={busy === 'send'} disabled={Boolean(busy)} onPress={send} />
        <View style={styles.bottomRow}>
          <Button title={t('EDIT_INVOICE')} icon="create-outline" variant="outline" small disabled={Boolean(busy)} onPress={() => setEditing(true)} style={{ flexGrow: 1 }} />
          <Button title={t('DELETE_ACTION')} variant="danger" small loading={busy === 'delete'} disabled={Boolean(busy)} onPress={remove} style={{ flexGrow: 1 }} />
        </View>
      </>
    );
  } else if (isCompany && ['sent', 'overdue'].includes(invoice.status)) {
    bottom = (
      <>
        <Button title={t('MARK_PAID')} icon="checkmark-done" variant="dark" loading={busy === 'paid'} onPress={markPaid} />
        <Button title={t('EMAIL_INVOICE')} icon="mail-outline" variant="outline" small disabled={Boolean(busy)} onPress={() => setEmailing(true)} />
      </>
    );
  }

  const sub =
    status === 'paid'
      ? t('PAID_ON', { date: formatDate(invoice.paidAt) })
      : draft
        ? t('DRAFT_NOT_SENT')
        : t('DUE_DATE', { date: formatDate(invoice.dueDate) });

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="light" />
      <ScrollView contentContainerStyle={{ paddingBottom: spacing.xxl }}>
        <View style={[styles.hero, { paddingTop: insets.top + spacing.md }]}>
          <View style={styles.heroTop}>
            <BackButton onDark />
            <StatusBadge status={status} kind="invoice" />
          </View>
          <View style={{ gap: 4 }}>
            <AppText variant="caption" onDark muted style={styles.kicker}>
              {invoice.number ? t('INVOICE_NUMBER', { n: invoice.number }) : t('INVOICE_DRAFT')}
            </AppText>
            <AppText variant="display" onDark>
              {formatNok(invoice.total)}
            </AppText>
            <AppText variant="small" onDark muted={status !== 'overdue'} color={status === 'overdue' ? colors.hivis : undefined}>
              {sub}
            </AppText>
          </View>
          <View style={styles.heroActions}>
            <Button title={draft ? t('PREVIEW_PDF') : t('OPEN_PDF')} icon="document-outline" variant="outlineOnDark" small loading={busy === 'pdf'} onPress={openPdf} />
            {invoice.contract?._id ? (
              <Button
                title={invoice.contract.title}
                icon="document-text-outline"
                variant="outlineOnDark"
                small
                onPress={() => router.push({ pathname: '/contract/[id]', params: { id: invoice.contract._id } })}
                style={{ flexShrink: 1 }}
              />
            ) : null}
          </View>
          {emailNotice ? (
            <View style={[styles.notice, styles[`notice_${emailNotice.tone}`]]}>
              <Ionicons
                name={emailNotice.tone === 'ok' ? 'mail' : 'alert-circle'}
                size={20}
                color={emailNotice.tone === 'ok' ? colors.pine : emailNotice.tone === 'warn' ? colors.amber : colors.danger}
              />
              <AppText variant="small" style={{ flex: 1 }}>
                {emailNotice.text}
              </AppText>
            </View>
          ) : null}
        </View>

        <View style={styles.paper}>
          {/* From / to */}
          <View style={styles.parties}>
            <Party label={t('INVOICE_FROM')} name={company.name} lines={[company.orgNumber && t('ORG_NUMBER_SHORT', { n: company.orgNumber }), company.email, company.phone]} />
            <Party
              label={t('INVOICE_TO')}
              name={invoice.billTo?.name}
              lines={[
                invoice.billTo?.orgNumber && t('ORG_NUMBER_SHORT', { n: invoice.billTo.orgNumber }),
                invoice.billTo?.address?.line1,
                [invoice.billTo?.address?.postalCode, invoice.billTo?.address?.city].filter(Boolean).join(' '),
                invoice.billTo?.email,
              ]}
            />
          </View>

          <View style={styles.meta}>
            {isCompany && !draft ? (
              <Meta
                label={t('EMAILED')}
                value={invoice.emailedAt ? t('EMAILED_ON', { email: invoice.emailedTo, date: formatDate(invoice.emailedAt) }) : t('NOT_EMAILED')}
              />
            ) : null}
            <Meta label={t('INVOICE_DATE')} value={formatDate(invoice.issueDate)} />
            <Meta label={t('DUE')} value={formatDate(invoice.dueDate)} />
            {invoice.kid ? <Meta label={t('KID')} value={invoice.kid} mono /> : null}
          </View>

          <Perforation notchColor={colors.concrete} />

          {/* Lines */}
          <View style={styles.lines}>
            {invoice.lines.map((l) => (
              <View key={l._id} style={styles.line}>
                <View style={{ flex: 1, gap: 2 }}>
                  <AppText variant="smallStrong">{l.description}</AppText>
                  <AppText variant="caption" muted>
                    {formatNumber(l.quantity)} {t(UNITS[l.unit] ?? 'UNIT_STK')} × {formatNok(l.unitPrice)}
                    {vatRegistered ? ` · ${t('VAT')} ${l.vatRate} %` : ''}
                  </AppText>
                </View>
                <AppText variant="smallStrong">{formatNok(l.amount)}</AppText>
              </View>
            ))}
          </View>

          <View style={styles.totals}>
            <Total label={t('SUBTOTAL')} value={formatNok(invoice.subtotal)} />
            {vatRegistered ? <Total label={t('VAT')} value={formatNok(invoice.vatTotal)} /> : <Total label={t('NOT_VAT_REGISTERED')} value="" />}
            <View style={styles.grandTotal}>
              <AppText variant="title" style={{ flex: 1 }}>
                {t('TOTAL_TO_PAY')}
              </AppText>
              <AppText variant="h2">{formatNok(invoice.total)}</AppText>
            </View>
          </View>

          {/* How to pay */}
          {!draft && status !== 'paid' && (bank || invoice.kid) ? (
            <View style={styles.pay}>
              <AppText variant="caption" muted style={styles.kicker}>
                {t('HOW_TO_PAY')}
              </AppText>
              {bank ? <Meta label={t('ACCOUNT_NUMBER')} value={formatAccount(bank)} mono /> : null}
              {invoice.kid ? <Meta label={t('KID')} value={invoice.kid} mono /> : null}
              <Meta label={t('AMOUNT')} value={formatNok(invoice.total)} />
              <Meta label={t('DUE')} value={formatDate(invoice.dueDate)} />
            </View>
          ) : null}
          {isCompany && draft && !bank ? (
            <View style={[styles.pay, { backgroundColor: colors.amberSoft }]}>
              <AppText variant="small" color={colors.amber}>
                {t('NO_BANK_ACCOUNT_WARNING')}
              </AppText>
            </View>
          ) : null}

          {invoice.notes ? (
            <View style={styles.notes}>
              <AppText variant="small">{invoice.notes}</AppText>
            </View>
          ) : null}
          {company.invoiceSettings?.footerText ? (
            <AppText variant="caption" muted style={{ padding: spacing.lg, paddingTop: 0 }}>
              {company.invoiceSettings.footerText}
            </AppText>
          ) : null}
        </View>

        {status === 'paid' ? (
          <View style={styles.paidStamp} accessibilityLabel={t('INVOICE_STATUS_PAID')}>
            <Ionicons name="checkmark-circle" size={22} color={colors.pine} />
            <AppText variant="bodyStrong" color={colors.pine}>
              {t('PAID_ON', { date: formatDate(invoice.paidAt) })}
            </AppText>
          </View>
        ) : null}

        <View style={{ marginHorizontal: spacing.xl, marginTop: spacing.md }}>
          <ErrorBanner message={error} />
        </View>
      </ScrollView>

      {bottom ? <BottomBar>{bottom}</BottomBar> : null}

      {isCompany && !draft ? (
        <EmailSheet
          visible={emailing}
          invoice={invoice}
          onClose={() => setEmailing(false)}
          onSend={async (body) => {
            const res = await api(`/invoices/${invoice._id}/email`, { method: 'POST', body });
            setEmailNotice(describeEmail(res.email));
            await load();
          }}
        />
      ) : null}

      {isCompany && draft ? <InvoiceEditor invoice={invoice} visible={editing} onClose={() => setEditing(false)} onSaved={load} /> : null}
    </View>
  );
}

// Email the PDF (again), to the saved address or a new one, in Norwegian or English
function EmailSheet({ visible, invoice, onClose, onSend }) {
  const { t } = useI18n();
  const [to, setTo] = useState('');
  const [lang, setLang] = useState('nb');
  const [error, setError] = useState(null);
  const [sending, setSending] = useState(false);

  useEffect(() => {
    if (!visible) return;
    setTo(invoice.emailedTo ?? invoice.billTo?.email ?? '');
    setLang(defaultInvoiceLang());
    setError(null);
  }, [visible, invoice]);

  async function send() {
    setSending(true);
    setError(null);
    try {
      await onSend({ to: to.trim(), lang });
      onClose();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSending(false);
    }
  }

  return (
    <Sheet visible={visible} onClose={onClose} title={t('EMAIL_INVOICE')} subtitle={t('INVOICE_NUMBER', { n: invoice.number })}>
      <TextField
        label={t('EMAIL')}
        value={to}
        onChangeText={setTo}
        keyboardType="email-address"
        autoCapitalize="none"
        autoCorrect={false}
        placeholder={t('EMAIL_PLACEHOLDER')}
      />
      <ChoiceChips
        label={t('INVOICE_LANGUAGE')}
        options={[
          { value: 'nb', label: 'Norsk' },
          { value: 'en', label: 'English' },
        ]}
        value={lang}
        onChange={setLang}
      />
      <ErrorBanner message={error} />
      <Button title={t('EMAIL_INVOICE')} icon="send" loading={sending} disabled={!/^\S+@\S+\.\S+$/.test(to.trim())} onPress={send} />
    </Sheet>
  );
}

function Party({ label, name, lines }) {
  return (
    <View style={{ flex: 1, gap: 2 }}>
      <AppText variant="caption" muted style={styles.kicker}>
        {label}
      </AppText>
      <AppText variant="bodyStrong">{name ?? '–'}</AppText>
      {lines.filter(Boolean).map((l) => (
        <AppText key={l} variant="caption" muted>
          {l}
        </AppText>
      ))}
    </View>
  );
}

function Meta({ label, value, mono }) {
  return (
    <View style={styles.metaRow}>
      <AppText variant="small" muted style={{ flex: 1 }}>
        {label}
      </AppText>
      <AppText variant="smallStrong" selectable style={mono && { fontFamily: fonts.bold, letterSpacing: 0.8 }}>
        {value}
      </AppText>
    </View>
  );
}

function Total({ label, value }) {
  return (
    <View style={styles.metaRow}>
      <AppText variant="small" muted style={{ flex: 1 }}>
        {label}
      </AppText>
      <AppText variant="smallStrong">{value}</AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  hero: { backgroundColor: colors.slate, paddingHorizontal: spacing.xl, paddingBottom: spacing.xxxl + spacing.lg, gap: spacing.lg },
  heroTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  kicker: { textTransform: 'uppercase', letterSpacing: 1.2 },
  paper: { marginTop: -spacing.xxxl, marginHorizontal: spacing.xl, backgroundColor: colors.paper, borderRadius: radius.ticket, maxWidth: 640 },
  parties: { flexDirection: 'row', gap: spacing.lg, padding: spacing.lg },
  meta: { paddingHorizontal: spacing.lg, paddingBottom: spacing.md, gap: 6 },
  metaRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  lines: { paddingHorizontal: spacing.lg },
  line: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: spacing.md,
    paddingVertical: spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.line,
  },
  totals: { padding: spacing.lg, gap: 6 },
  grandTotal: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    marginTop: spacing.sm,
    paddingTop: spacing.md,
    borderTopWidth: 2,
    borderTopColor: colors.slate,
  },
  pay: { margin: spacing.lg, marginTop: 0, padding: spacing.lg, gap: 6, borderRadius: radius.md, backgroundColor: colors.hivisSoft },
  notes: { marginHorizontal: spacing.lg, marginBottom: spacing.lg, paddingLeft: spacing.md, borderLeftWidth: 3, borderLeftColor: colors.line },
  paidStamp: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    marginHorizontal: spacing.xl,
    marginTop: spacing.lg,
    padding: spacing.lg,
    borderRadius: radius.ticket,
    backgroundColor: colors.pineSoft,
  },
  bottomRow: { flexDirection: 'row', gap: spacing.sm },
  heroActions: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  notice: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    padding: spacing.md,
    borderRadius: radius.ticket,
  },
  notice_ok: { backgroundColor: colors.pineSoft },
  notice_warn: { backgroundColor: colors.amberSoft },
  notice_error: { backgroundColor: colors.dangerSoft },
});
QUP_EOF_13

# ---- src/app/job/[id].js
write_file 'src/app/job/[id].js' <<'QUP_EOF_14'
// /qup-work-app/src/app/job/[id].js
// One job as a big work-order ticket. Public for open jobs; acting on it needs an account.
// The customer sees the offers here and picks one; a pro sees their own offer.
// The owner (the customer, or the pro on a job for their own client) can edit, cancel
// or delete it until someone is hired.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { useCallback, useRef, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { BackButton, goBackOr } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { Button } from '@/components/Button';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { OfferCard } from '@/components/OfferCard';
import { Perforation } from '@/components/Perforation';
import { StatusBadge } from '@/components/StatusBadge';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { api, errorMessage } from '@/lib/api';
import { openChat } from '@/lib/chat';
import { confirm } from '@/lib/confirm';
import { useI18n } from '@/i18n';
import { budgetText, categoryIcon, categoryName, formatDate, offerPrice, placeText, timeAgo, URGENCY } from '@/lib/format';

export default function JobScreen() {
  const { id } = useLocalSearchParams();
  const insets = useSafeAreaInsets();
  const { user, isPro } = useAuth();
  const { t } = useI18n();
  const [data, setData] = useState(null);
  const [offers, setOffers] = useState([]);
  const [error, setError] = useState(null);
  const alive = useRef(true);

  // The job, plus its offers when I may see them (all of them as the customer, my own as a pro)
  const load = useCallback(async () => {
    try {
      const res = await api(`/jobs/${id}`);
      const showOffers = res.side === 'customer' || (res.side === 'viewer' && res.myOffer);
      const list = showOffers ? (await api(`/jobs/${id}/offers`)).offers : [];
      if (!alive.current) return;
      setData(res);
      setOffers(list);
      setError(null);
    } catch (err) {
      if (alive.current) setError(errorMessage(err));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id, user?._id]);

  // Reload when coming back from the offer form, a chat or login
  useFocusEffect(
    useCallback(() => {
      alive.current = true;
      load();
      return () => {
        alive.current = false;
      };
    }, [load])
  );

  if (error && !data) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl }]}>
        <BackButton />
        <EmptyState icon="clipboard-outline" title={t('JOB_NOT_FOUND')} text={error} />
      </View>
    );
  }
  if (!data) return <Loading dark />;

  const { job, side, myOffer } = data;
  const direct = job.source === 'direct';
  const isOwner = (job.source === 'marketplace' && side === 'customer') || (direct && side === 'pro');
  const myOfferFull = myOffer ? offers.find((o) => o._id === myOffer._id) : null;
  const facts = [
    job.timing?.urgency && { icon: 'calendar-outline', label: t('FACT_WHEN'), value: t(URGENCY[job.timing.urgency]) },
    job.timing?.preferredStart && { icon: 'play-outline', label: t('FACT_PREFERRED_START'), value: formatDate(job.timing.preferredStart) },
    {
      icon: job.workType === 'remote' ? 'globe-outline' : 'location-outline',
      label: job.workType === 'remote' ? t('FACT_WORKPLACE') : t('FACT_PLACE'),
      value: job.workType === 'remote' ? t('REMOTE_WORK') : [job.address?.postalCode, placeText(job)].filter(Boolean).join(' '),
    },
    job.address?.line1 && { icon: 'home-outline', label: t('FACT_ADDRESS'), value: job.address.line1 },
    !direct && { icon: 'document-text-outline', label: t('FACT_OFFERS'), value: job.offerCount ? t('OFFERS_RECEIVED', { n: job.offerCount }) : t('NONE_YET') },
  ].filter(Boolean);

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="light" />
      <ScrollView contentContainerStyle={{ paddingBottom: spacing.xxl }}>
        <View style={[styles.hero, { paddingTop: insets.top + spacing.md }]}>
          <BackButton onDark />
          {job.category ? (
            <View style={styles.category}>
              <View style={styles.categoryIcon}>
                <Ionicons name={categoryIcon(job.category.icon)} size={15} color={colors.slate} />
              </View>
              <AppText variant="smallStrong" onDark muted>
                {categoryName(job.category)}
              </AppText>
            </View>
          ) : null}
          <AppText variant="h1" onDark accessibilityRole="header">
            {job.title}
          </AppText>
          <AppText variant="small" onDark muted>
            {direct ? t('CREATED_AGO', { time: timeAgo(job.createdAt) }) : t('POSTED_AGO', { time: timeAgo(job.publishedAt ?? job.createdAt) })}
          </AppText>
        </View>

        {/* The ticket */}
        <View style={styles.ticket}>
          <View style={styles.ticketTop}>
            <View style={{ flex: 1, gap: 2 }}>
              <AppText variant="caption" muted>
                {t('BUDGET')}
              </AppText>
              <AppText variant="h2">{budgetText(job.budget)}</AppText>
            </View>
            <StatusBadge status={job.status} />
          </View>

          <Perforation notchColor={colors.concrete} />

          <View style={styles.facts}>
            {facts.map((f) => (
              <View key={f.label} style={styles.fact}>
                <Ionicons name={f.icon} size={18} color={colors.textMuted} />
                <AppText variant="small" muted style={styles.factLabel}>
                  {f.label}
                </AppText>
                <AppText variant="smallStrong" style={{ flex: 1, textAlign: 'right' }}>
                  {f.value}
                </AppText>
              </View>
            ))}
          </View>
        </View>

        {job.contract && (side === 'customer' || side === 'pro') ? <ContractLink job={job} side={side} /> : null}

        {isOwner ? <OwnerTools job={job} onChanged={load} /> : null}

        {job.description ? (
          <View style={styles.section}>
            <AppText variant="title">{t('DESCRIPTION')}</AppText>
            <AppText variant="body">{job.description}</AppText>
          </View>
        ) : null}

        {direct && job.client ? (
          <Pressable
            onPress={() => router.push({ pathname: '/client/[id]', params: { id: job.client._id } })}
            accessibilityRole="button"
            style={({ pressed }) => [styles.section, styles.person, pressed && { opacity: 0.7 }]}
          >
            <Avatar name={job.client.name} size={44} dark />
            <View style={{ flex: 1 }}>
              <AppText variant="caption" muted>
                {t('CLIENT')}
              </AppText>
              <AppText variant="bodyStrong">{job.client.name}</AppText>
              {job.client.phone ? (
                <AppText variant="small" muted>
                  {job.client.phone}
                </AppText>
              ) : null}
            </View>
            <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
          </Pressable>
        ) : null}

        {job.customer ? (
          <View style={[styles.section, styles.person]}>
            <Avatar name={job.customer.name} url={job.customer.avatarUrl} size={44} dark />
            <View>
              <AppText variant="caption" muted>
                {t('POSTED_BY')}
              </AppText>
              <AppText variant="bodyStrong">{job.customer.name}</AppText>
            </View>
          </View>
        ) : null}

        {side === 'customer' && job.status !== 'draft' ? <CustomerOffers job={job} offers={offers} onChanged={load} /> : null}
        {myOfferFull && myOfferFull.status !== 'withdrawn' ? <MyOffer offer={myOfferFull} onChanged={load} /> : null}

        {side === 'guest' || side === 'viewer' ? (
          <AppText variant="small" muted style={styles.privacy}>
            {t('ADDRESS_PRIVACY_NOTE')}
          </AppText>
        ) : null}
      </ScrollView>

      <JobActions job={job} side={side} myOffer={myOffer} offers={offers} isPro={isPro} />
    </View>
  );
}

// Edit / cancel / delete / publish, for whoever owns the job, until someone is hired
function OwnerTools({ job, onChanged }) {
  const { t } = useI18n();
  const [busy, setBusy] = useState(null);
  const [error, setError] = useState(null);
  if (job.contract || !['draft', 'open'].includes(job.status)) return null;
  const draft = job.status === 'draft';

  async function act(key, ask, fn) {
    if (ask && !(await confirm(ask))) return;
    setBusy(key);
    setError(null);
    try {
      await fn();
      if (key === 'delete') goBackOr('/my-jobs');
      else await onChanged();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(null);
    }
  }

  const cancel = () =>
    act(
      'cancel',
      {
        title: t('CANCEL_JOB_TITLE'),
        message: job.offerCount ? t('CANCEL_JOB_WITH_OFFERS_TEXT', { n: job.offerCount }) : t('CANCEL_JOB_TEXT'),
        confirmText: t('CANCEL_JOB'),
        destructive: true,
      },
      () => api(`/jobs/${job._id}/cancel`, { method: 'POST' })
    );
  const remove = () =>
    act(
      'delete',
      { title: t('DELETE_JOB_TITLE'), message: t('DELETE_JOB_TEXT'), confirmText: t('DELETE_ACTION'), destructive: true },
      () => api(`/jobs/${job._id}`, { method: 'DELETE' })
    );
  const publish = () => act('publish', null, () => api(`/jobs/${job._id}/publish`, { method: 'POST' }));

  return (
    <View style={styles.section}>
      <ErrorBanner message={error} />
      {draft && job.source === 'marketplace' ? (
        <View style={styles.draftNote}>
          <Ionicons name="eye-off-outline" size={18} color={colors.textMuted} />
          <AppText variant="small" muted style={{ flex: 1 }}>
            {t('DRAFT_NOT_VISIBLE')}
          </AppText>
        </View>
      ) : null}
      <View style={styles.ownerRow}>
        {draft && job.source === 'marketplace' ? (
          <Button title={t('PUBLISH_JOB')} icon="megaphone-outline" small loading={busy === 'publish'} disabled={Boolean(busy)} onPress={publish} style={{ flexGrow: 1 }} />
        ) : null}
        <Button
          title={t('EDIT_JOB')}
          icon="create-outline"
          variant="outline"
          small
          disabled={Boolean(busy)}
          onPress={() => router.push({ pathname: '/new-job', params: { id: job._id } })}
          style={{ flexGrow: 1 }}
        />
        {draft ? (
          <Button title={t('DELETE_ACTION')} icon="trash-outline" variant="danger" small loading={busy === 'delete'} disabled={Boolean(busy)} onPress={remove} style={{ flexGrow: 1 }} />
        ) : (
          <Button title={t('CANCEL_JOB')} icon="close-circle-outline" variant="danger" small loading={busy === 'cancel'} disabled={Boolean(busy)} onPress={cancel} style={{ flexGrow: 1 }} />
        )}
      </View>
    </View>
  );
}

// Once someone is hired, the work happens on the contract page
function ContractLink({ job, side }) {
  const { t } = useI18n();
  const id = job.contract?._id ?? job.contract;
  const done = job.status === 'completed';
  return (
    <Pressable
      onPress={() => router.push({ pathname: '/contract/[id]', params: { id } })}
      accessibilityRole="button"
      style={({ pressed }) => [styles.section, styles.contractLink, pressed && { opacity: 0.85 }]}
    >
      <View style={styles.contractIcon}>
        <Ionicons name={done ? 'checkmark-done' : 'construct'} size={22} color={colors.slate} />
      </View>
      <View style={{ flex: 1, gap: 2 }}>
        <AppText variant="title" onDark>
          {done ? t('SEE_THE_CONTRACT') : t('FOLLOW_THE_WORK')}
        </AppText>
        <AppText variant="small" onDark muted>
          {done ? t('CONTRACT_LINK_DONE') : side === 'pro' ? t('CONTRACT_LINK_PRO') : t('CONTRACT_LINK_CUSTOMER')}
        </AppText>
      </View>
      <Ionicons name="chevron-forward" size={20} color={colors.hivis} />
    </Pressable>
  );
}

// "Message <name>" about this job. Opens (or creates) the conversation.
function MessageButton({ person, jobId, variant = 'outline', small }) {
  const { t } = useI18n();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  if (!person?._id) return null;

  async function open() {
    setBusy(true);
    setError(null);
    try {
      await openChat({ participant: person._id, job: jobId });
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <ErrorBanner message={error} />
      <Button
        title={small ? t('MESSAGE') : t('MESSAGE_CUSTOMER', { name: person.name })}
        icon="chatbubble-outline"
        variant={variant}
        small={small}
        loading={busy}
        onPress={open}
        style={small ? { flexGrow: 1 } : undefined}
      />
    </>
  );
}

// Accepted first, then the ones waiting for an answer, then the rest. Withdrawn ones are hidden.
const OFFER_ORDER = { accepted: 0, pending: 1, rejected: 2, expired: 3 };
const sortOffers = (offers) =>
  offers
    .filter((o) => o.status !== 'withdrawn')
    .sort((a, b) => (OFFER_ORDER[a.status] ?? 9) - (OFFER_ORDER[b.status] ?? 9) || new Date(b.createdAt) - new Date(a.createdAt));

// The customer compares the offers and accepts or declines them
function CustomerOffers({ job, offers, onChanged }) {
  const { t } = useI18n();
  const [busy, setBusy] = useState(null); // `${offerId}:accept` | `${offerId}:reject`
  const [error, setError] = useState(null);
  const list = sortOffers(offers);
  const canChoose = job.status === 'open' && !job.contract;

  async function act(offer, action) {
    const name = offer.company?.name ?? offer.pro?.name ?? '';
    const ok = await confirm(
      action === 'accept'
        ? {
            title: t('ACCEPT_OFFER_TITLE'),
            message: t('ACCEPT_OFFER_TEXT', { name, price: offerPrice(offer).main }),
            confirmText: t('ACCEPT'),
          }
        : {
            title: t('DECLINE_OFFER_TITLE'),
            message: t('DECLINE_OFFER_TEXT', { name }),
            confirmText: t('DECLINE'),
            destructive: true,
          }
    );
    if (!ok) return;
    setBusy(`${offer._id}:${action}`);
    setError(null);
    try {
      await api(`/offers/${offer._id}/${action === 'accept' ? 'accept' : 'reject'}`, { method: 'POST' });
      await onChanged();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(null);
    }
  }

  return (
    <View style={[styles.section, { gap: spacing.md }]}>
      <View style={styles.sectionHead}>
        <AppText variant="title" style={{ flex: 1 }}>
          {t('OFFERS_TITLE')}
        </AppText>
        {list.length ? (
          <AppText variant="smallStrong" muted>
            {list.length}
          </AppText>
        ) : null}
      </View>

      {canChoose && list.some((o) => o.status === 'pending') ? (
        <AppText variant="small" muted>
          {t('OFFERS_COMPARE_HINT')}
        </AppText>
      ) : null}
      <ErrorBanner message={error} />

      {list.length ? (
        list.map((offer) => (
          <OfferCard key={offer._id} offer={offer}>
            {offer.status === 'pending' && canChoose ? (
              <>
                <Button
                  title={t('ACCEPT')}
                  icon="checkmark"
                  small
                  loading={busy === `${offer._id}:accept`}
                  disabled={Boolean(busy)}
                  onPress={() => act(offer, 'accept')}
                  style={{ flexGrow: 1 }}
                />
                <Button
                  title={t('DECLINE')}
                  variant="outline"
                  small
                  loading={busy === `${offer._id}:reject`}
                  disabled={Boolean(busy)}
                  onPress={() => act(offer, 'reject')}
                  style={{ flexGrow: 1 }}
                />
                <MessageButton person={offer.pro} jobId={job._id} variant="dark" small />
              </>
            ) : offer.status === 'accepted' ? (
              <MessageButton person={offer.pro} jobId={job._id} variant="dark" small />
            ) : null}
          </OfferCard>
        ))
      ) : (
        <View style={styles.noOffers}>
          <Ionicons name="hourglass-outline" size={20} color={colors.textMuted} />
          <AppText variant="small" muted style={{ flex: 1 }}>
            {t('CUSTOMER_WAITING_FOR_OFFERS')}
          </AppText>
        </View>
      )}
    </View>
  );
}

// The pro's own offer on someone else's job, with "Withdraw" while it's waiting
function MyOffer({ offer, onChanged }) {
  const { t } = useI18n();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  async function withdraw() {
    const ok = await confirm({
      title: t('WITHDRAW_OFFER_TITLE'),
      message: t('WITHDRAW_OFFER_TEXT'),
      confirmText: t('WITHDRAW'),
      destructive: true,
    });
    if (!ok) return;
    setBusy(true);
    setError(null);
    try {
      await api(`/offers/${offer._id}/withdraw`, { method: 'POST' });
      await onChanged();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <View style={styles.section}>
      <ErrorBanner message={error} />
      <OfferCard offer={offer} mine>
        {offer.status === 'pending' ? (
          <Button title={t('WITHDRAW_OFFER')} variant="danger" small loading={busy} onPress={withdraw} style={{ flexGrow: 1 }} />
        ) : null}
      </OfferCard>
    </View>
  );
}

// What the bar at the bottom shows depends on who's looking
function JobActions({ job, side, myOffer, offers, isPro }) {
  const { t } = useI18n();
  if (side === 'guest') {
    return (
      <BottomBar>
        <Button title={t('LOG_IN_TO_OFFER')} variant="dark" onPress={() => router.push('/login')} />
      </BottomBar>
    );
  }

  if (side === 'viewer') {
    // A withdrawn offer can be replaced by a new one
    if (myOffer && myOffer.status !== 'withdrawn') {
      return (
        <BottomBar>
          {myOffer.status === 'pending' ? (
            <View style={styles.note}>
              <Ionicons name="checkmark-circle" size={20} color={colors.pine} />
              <AppText variant="bodyStrong" color={colors.pine}>
                {t('OFFER_SENT_WAITING')}
              </AppText>
            </View>
          ) : null}
          <MessageButton person={job.customer} jobId={job._id} />
        </BottomBar>
      );
    }
    if (!isPro) {
      return (
        <BottomBar>
          <AppText variant="small" muted center>
            {t('ONLY_PROS_CAN_OFFER')}
          </AppText>
        </BottomBar>
      );
    }
    if (job.status !== 'open') return null;
    return (
      <BottomBar>
        <Button
          title={myOffer ? t('MAKE_NEW_OFFER') : t('MAKE_OFFER')}
          icon="document-text-outline"
          onPress={() => router.push({ pathname: '/offer/[jobId]', params: { jobId: job._id, title: job.title } })}
        />
      </BottomBar>
    );
  }

  // The pro doing the job. On their own client's job they set up the contract themselves.
  if (side === 'pro') {
    if (job.source === 'direct') {
      if (job.contract || ['completed', 'cancelled'].includes(job.status)) return null;
      return (
        <BottomBar>
          <Button
            title={t('CREATE_CONTRACT')}
            icon="document-text-outline"
            onPress={() => router.push({ pathname: '/new-assignment', params: { job: job._id } })}
          />
        </BottomBar>
      );
    }
    return (
      <BottomBar>
        <MessageButton person={job.customer} jobId={job._id} variant="dark" />
      </BottomBar>
    );
  }

  if (side === 'customer') {
    // Once someone is hired, the chat with them is one tap away
    if (job.pro) {
      return (
        <BottomBar>
          <MessageButton person={job.pro} jobId={job._id} variant="dark" />
        </BottomBar>
      );
    }
    if (job.status !== 'open') return null; // drafts are published from the page itself
    const waiting = offers.filter((o) => o.status === 'pending').length;
    return (
      <BottomBar>
        <AppText variant="small" muted center>
          {waiting ? t('CUSTOMER_CHOOSE_OFFER', { n: waiting }) : t('CUSTOMER_WAITING_FOR_OFFERS')}
        </AppText>
      </BottomBar>
    );
  }

  return null;
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  hero: {
    backgroundColor: colors.slate,
    paddingHorizontal: spacing.xl,
    paddingBottom: spacing.xxxl + spacing.lg, // room for the ticket to overlap
    gap: spacing.md,
  },
  category: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginTop: spacing.sm },
  categoryIcon: {
    width: 24,
    height: 24,
    borderRadius: 5,
    backgroundColor: colors.hivis,
    alignItems: 'center',
    justifyContent: 'center',
  },
  ticket: {
    marginTop: -spacing.xxxl,
    marginHorizontal: spacing.xl,
    backgroundColor: colors.paper,
    borderRadius: radius.ticket,
  },
  ticketTop: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, padding: spacing.lg },
  facts: { padding: spacing.lg, paddingTop: spacing.sm, gap: spacing.md },
  fact: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  factLabel: { width: 118 },
  section: { marginTop: spacing.xxl, marginHorizontal: spacing.xl, gap: spacing.sm, maxWidth: 640 },
  sectionHead: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  contractLink: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.lg,
    borderRadius: radius.ticket,
    backgroundColor: colors.slate,
  },
  contractIcon: {
    width: 42,
    height: 42,
    borderRadius: 8,
    backgroundColor: colors.hivis,
    alignItems: 'center',
    justifyContent: 'center',
  },
  noOffers: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.lg,
    borderRadius: radius.ticket,
    borderWidth: 1.5,
    borderStyle: 'dashed',
    borderColor: colors.line,
  },
  person: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  ownerRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  draftNote: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  privacy: { marginTop: spacing.xl, marginHorizontal: spacing.xl },
  note: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: spacing.sm, minHeight: 44 },
});
QUP_EOF_14

# ---- src/app/new-assignment.js
write_file 'src/app/new-assignment.js' <<'QUP_EOF_15'
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
QUP_EOF_15

# ---- src/app/new-job.js
write_file 'src/app/new-job.js' <<'QUP_EOF_16'
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
    if (!category && job?.source !== 'direct') return setError(t('JOB_CATEGORY_REQUIRED')); // pros are alerted by category
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
QUP_EOF_16

# ---- src/app/payments.js
write_file 'src/app/payments.js' <<'QUP_EOF_17'
// /qup-work-app/src/app/payments.js
// Money paid through the app: what I've paid as a customer and what I've been paid as a pro.
// (Payments in the app come with escrow; jobs paid by invoice are under Invoices.)
import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { FlatList, Pressable, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton } from '@/components/BackButton';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { SignInPrompt } from '@/components/SignInPrompt';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { formatDate, formatNok } from '@/lib/format';
import { usePaged } from '@/lib/usePaged';

// Payment status → label key + colours
const STATUS = {
  pending: { label: 'PAYMENT_STATUS_PENDING', color: colors.amber, bg: colors.amberSoft },
  held: { label: 'PAYMENT_STATUS_HELD', color: colors.info, bg: colors.infoSoft },
  released: { label: 'PAYMENT_STATUS_RELEASED', color: colors.pine, bg: colors.pineSoft },
  refunded: { label: 'PAYMENT_STATUS_REFUNDED', color: colors.textMuted, bg: colors.line },
  failed: { label: 'PAYMENT_STATUS_FAILED', color: colors.danger, bg: colors.dangerSoft },
  cancelled: { label: 'STATUS_CANCELLED', color: colors.textMuted, bg: colors.line },
};

export default function PaymentsScreen() {
  const insets = useSafeAreaInsets();
  const { user } = useAuth();
  const { t } = useI18n();
  const list = usePaged('/payments', { enabled: Boolean(user) });

  const header = (
    <View style={[styles.header, { paddingTop: insets.top + spacing.md }]}>
      <BackButton />
      <AppText variant="h1" accessibilityRole="header">
        {t('PAYMENTS')}
      </AppText>
    </View>
  );

  if (!user) {
    return (
      <View style={styles.screen}>
        {header}
        <SignInPrompt icon="card-outline" title={t('PAYMENTS')} text={t('PROFILE_GUEST_TEXT')} />
      </View>
    );
  }

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="dark" />
      {header}
      {list.status === 'loading' ? (
        <Loading />
      ) : (
        <FlatList
          data={list.items}
          keyExtractor={(p) => p._id}
          renderItem={({ item }) => <PaymentRow payment={item} me={user._id} />}
          contentContainerStyle={styles.list}
          ItemSeparatorComponent={() => <View style={{ height: spacing.sm }} />}
          onEndReached={list.loadMore}
          refreshing={list.refreshing}
          onRefresh={list.refresh}
          ListHeaderComponent={list.error ? <ErrorBanner message={list.error} onRetry={list.reload} style={{ marginBottom: spacing.md }} /> : null}
          ListEmptyComponent={
            list.error ? null : (
              <EmptyState
                icon="card-outline"
                title={t('NO_PAYMENTS')}
                text={t('NO_PAYMENTS_TEXT')}
                actionTitle={t('INVOICES')}
                onAction={() => router.push('/invoices')}
              />
            )
          }
        />
      )}
    </View>
  );
}

function PaymentRow({ payment: p, me }) {
  const { t } = useI18n();
  const incoming = String(p.payee?._id ?? p.payee) === String(me);
  const s = STATUS[p.status] ?? STATUS.pending;
  const contractId = p.contract?._id ?? p.contract;
  return (
    <Pressable
      disabled={!contractId}
      onPress={() => router.push({ pathname: '/contract/[id]', params: { id: contractId } })}
      accessibilityRole="button"
      style={({ pressed }) => [styles.row, pressed && { opacity: 0.8 }]}
    >
      <View style={[styles.icon, { backgroundColor: incoming ? colors.pineSoft : colors.concrete }]}>
        <Ionicons name={incoming ? 'arrow-down' : 'arrow-up'} size={18} color={incoming ? colors.pine : colors.slate} />
      </View>
      <View style={{ flex: 1, gap: 2 }}>
        <AppText variant="bodyStrong" numberOfLines={1}>
          {p.milestone?.title ?? p.contract?.title ?? t('PAYMENT')}
        </AppText>
        <AppText variant="caption" muted numberOfLines={1}>
          {[p.milestone?.title ? p.contract?.title : null, formatDate(p.releasedAt ?? p.heldAt ?? p.createdAt)].filter(Boolean).join(' · ')}
        </AppText>
        <View style={[styles.badge, { backgroundColor: s.bg }]}>
          <AppText variant="caption" color={s.color}>
            {t(s.label)}
          </AppText>
        </View>
      </View>
      <View style={{ alignItems: 'flex-end', gap: 2 }}>
        <AppText variant="price" color={incoming ? colors.pine : colors.text}>
          {incoming ? '+' : '−'}
          {formatNok(incoming ? p.payoutAmount ?? p.amount : p.amount)}
        </AppText>
        {incoming && p.platformFee ? (
          <AppText variant="caption" muted>
            {t('PLATFORM_FEE', { fee: formatNok(p.platformFee) })}
          </AppText>
        ) : null}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  header: { paddingHorizontal: spacing.xl, gap: spacing.md, paddingBottom: spacing.md },
  list: { padding: spacing.xl, paddingTop: spacing.sm, flexGrow: 1 },
  row: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, padding: spacing.lg, borderRadius: radius.ticket, backgroundColor: colors.paper },
  icon: { width: 36, height: 36, borderRadius: 8, alignItems: 'center', justifyContent: 'center' },
  badge: { alignSelf: 'flex-start', borderRadius: radius.pill, paddingHorizontal: 8, paddingVertical: 2, marginTop: 2 },
});
QUP_EOF_17

# ---- src/app/team/[id].js
write_file 'src/app/team/[id].js' <<'QUP_EOF_18'
// /qup-work-app/src/app/team/[id].js
// The people in a company. Owner and admins add colleagues by the email they signed up
// with, and change or remove them. Only the owner handles admins. Anyone can leave.
//   owner  → everything
//   admin  → add/remove workers
//   worker → may see the team, and leave
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useLocalSearchParams } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';
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
import { Sheet } from '@/components/Sheet';
import { TextField } from '@/components/TextField';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { api, ApiError, errorMessage } from '@/lib/api';
import { confirm } from '@/lib/confirm';

const ROLE_LABEL = { owner: 'ROLE_OWNER', admin: 'ROLE_ADMIN', worker: 'ROLE_WORKER' };
const ROLE_ORDER = { owner: 0, admin: 1, worker: 2 };

export default function TeamScreen() {
  const { id } = useLocalSearchParams();
  const insets = useSafeAreaInsets();
  const { user, refreshSession } = useAuth();
  const { t } = useI18n();
  const [company, setCompany] = useState(null);
  const [myRole, setMyRole] = useState(null);
  const [loadError, setLoadError] = useState(null);
  const [error, setError] = useState(null);
  const [sheet, setSheet] = useState(null); // { type: 'add' } | { type: 'member', member }

  const load = useCallback(async () => {
    try {
      const res = await api(`/companies/${id}`);
      setCompany(res.company);
      setMyRole(res.myRole);
      setLoadError(null);
    } catch (err) {
      setLoadError(errorMessage(err));
    }
  }, [id]);

  useEffect(() => {
    load();
  }, [load]);

  if (loadError && !company) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl }]}>
        <BackButton />
        <EmptyState icon="people-outline" title={t('COMPANY_NOT_FOUND')} text={loadError} />
      </View>
    );
  }
  if (!company || !user) return <Loading />;

  const canManage = myRole === 'owner' || myRole === 'admin';
  const members = [...company.members].sort((a, b) => ROLE_ORDER[a.role] - ROLE_ORDER[b.role] || (a.user?.name ?? '').localeCompare(b.user?.name ?? ''));
  const isMe = (m) => String(m.user?._id ?? m.user) === String(user._id);
  // Admins can only be changed by the owner; nobody changes the owner
  const canEdit = (m) => canManage && !isMe(m) && m.role !== 'owner' && (myRole === 'owner' || m.role === 'worker');

  async function leave() {
    const ok = await confirm({
      title: t('LEAVE_COMPANY_TITLE'),
      message: t('LEAVE_COMPANY_TEXT', { name: company.name }),
      confirmText: t('LEAVE_COMPANY'),
      destructive: true,
    });
    if (!ok) return;
    setError(null);
    try {
      await api(`/companies/${company._id}/members/${user._id}`, { method: 'DELETE' });
      await refreshSession();
      router.replace('/profile');
    } catch (err) {
      setError(errorMessage(err));
    }
  }

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="dark" />
      <ScrollView contentContainerStyle={[styles.content, { paddingTop: insets.top + spacing.md }]}>
        <BackButton />
        <View style={{ gap: spacing.xs }}>
          <AppText variant="h1" accessibilityRole="header">
            {t('TEAM')}
          </AppText>
          <AppText variant="body" muted>
            {company.name}
          </AppText>
        </View>
        <ErrorBanner message={error} />

        <View style={styles.group}>
          {members.map((m, i) => (
            <Pressable
              key={String(m.user?._id ?? m.user)}
              disabled={!canEdit(m)}
              onPress={() => setSheet({ type: 'member', member: m })}
              accessibilityRole={canEdit(m) ? 'button' : undefined}
              style={({ pressed }) => [styles.member, i === members.length - 1 && { borderBottomWidth: 0 }, pressed && { opacity: 0.7 }]}
            >
              <Avatar name={m.user?.name} url={m.user?.avatarUrl} size={44} />
              <View style={{ flex: 1, gap: 2 }}>
                <AppText variant="bodyStrong" numberOfLines={1}>
                  {m.user?.name ?? t('UNKNOWN')}
                  {isMe(m) ? ` (${t('YOU')})` : ''}
                </AppText>
                <AppText variant="small" muted numberOfLines={1}>
                  {m.user?.email}
                </AppText>
              </View>
              <View style={[styles.role, m.role === 'owner' && styles.roleOwner]}>
                <AppText variant="caption" color={m.role === 'owner' ? colors.slate : colors.textMuted}>
                  {t(ROLE_LABEL[m.role])}
                </AppText>
              </View>
              {canEdit(m) ? <Ionicons name="chevron-forward" size={18} color={colors.textMuted} /> : null}
            </Pressable>
          ))}
        </View>

        <AppText variant="small" muted>
          {canManage ? t('TEAM_MANAGE_HINT') : t('TEAM_WORKER_HINT')}
        </AppText>

        {myRole !== 'owner' ? (
          <Button title={t('LEAVE_COMPANY')} icon="exit-outline" variant="danger" small onPress={leave} style={{ alignSelf: 'flex-start' }} />
        ) : null}
      </ScrollView>

      {canManage ? (
        <BottomBar>
          <Button title={t('ADD_MEMBER')} icon="person-add-outline" onPress={() => setSheet({ type: 'add' })} />
        </BottomBar>
      ) : null}

      <AddMemberSheet
        visible={sheet?.type === 'add'}
        canAddAdmin={myRole === 'owner'}
        onClose={() => setSheet(null)}
        onAdd={async (body) => {
          const res = await api(`/companies/${company._id}/members`, { method: 'POST', body });
          setCompany(res.company);
        }}
      />
      <MemberSheet
        member={sheet?.type === 'member' ? sheet.member : null}
        canSetAdmin={myRole === 'owner'}
        onClose={() => setSheet(null)}
        onRole={async (role) => {
          const res = await api(`/companies/${company._id}/members/${sheet.member.user._id}`, { method: 'PATCH', body: { role } });
          setCompany(res.company);
        }}
        onRemove={async () => {
          await api(`/companies/${company._id}/members/${sheet.member.user._id}`, { method: 'DELETE' });
          await load();
        }}
      />
    </View>
  );
}

function AddMemberSheet({ visible, canAddAdmin, onClose, onAdd }) {
  const { t } = useI18n();
  const [email, setEmail] = useState('');
  const [role, setRole] = useState('worker');
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);

  function close() {
    setEmail('');
    setRole('worker');
    setError(null);
    onClose();
  }

  async function add() {
    setSaving(true);
    setError(null);
    try {
      await onAdd({ email: email.trim().toLowerCase(), role });
      close();
    } catch (err) {
      if (err instanceof ApiError && err.status === 404) setError(t('MEMBER_NOT_FOUND'));
      else if (err instanceof ApiError && err.status === 409) setError(t('MEMBER_ALREADY'));
      else setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Sheet visible={visible} onClose={close} title={t('ADD_MEMBER')} subtitle={t('ADD_MEMBER_INTRO')}>
      <TextField
        label={t('EMAIL')}
        value={email}
        onChangeText={setEmail}
        keyboardType="email-address"
        autoCapitalize="none"
        autoCorrect={false}
        placeholder={t('EMAIL_PLACEHOLDER')}
        autoFocus
      />
      {canAddAdmin ? (
        <ChoiceChips
          label={t('ROLE')}
          options={[
            { value: 'worker', label: t('ROLE_WORKER') },
            { value: 'admin', label: t('ROLE_ADMIN') },
          ]}
          value={role}
          onChange={setRole}
        />
      ) : null}
      <AppText variant="small" muted>
        {role === 'admin' ? t('ROLE_ADMIN_HINT') : t('ROLE_WORKER_HINT')}
      </AppText>
      <ErrorBanner message={error} />
      <Button title={t('ADD_MEMBER')} icon="person-add-outline" loading={saving} disabled={!/^\S+@\S+\.\S+$/.test(email.trim())} onPress={add} />
    </Sheet>
  );
}

function MemberSheet({ member, canSetAdmin, onClose, onRole, onRemove }) {
  const { t } = useI18n();
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(null);

  async function run(key, fn) {
    setBusy(key);
    setError(null);
    try {
      await fn();
      onClose();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(null);
    }
  }

  async function remove() {
    const ok = await confirm({
      title: t('REMOVE_MEMBER_TITLE'),
      message: t('REMOVE_MEMBER_TEXT', { name: member.user?.name ?? '' }),
      confirmText: t('REMOVE'),
      destructive: true,
    });
    if (ok) run('remove', onRemove);
  }

  return (
    <Sheet visible={Boolean(member)} onClose={onClose} title={member?.user?.name ?? ''} subtitle={member?.user?.email}>
      {canSetAdmin && member ? (
        <ChoiceChips
          label={t('ROLE')}
          options={[
            { value: 'worker', label: t('ROLE_WORKER') },
            { value: 'admin', label: t('ROLE_ADMIN') },
          ]}
          value={member.role}
          onChange={(role) => role !== member.role && run('role', () => onRole(role))}
        />
      ) : null}
      <ErrorBanner message={error} />
      <Button title={t('REMOVE_FROM_COMPANY')} icon="person-remove-outline" variant="danger" loading={busy === 'remove'} disabled={Boolean(busy)} onPress={remove} />
    </Sheet>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xl, paddingBottom: spacing.xxxl },
  group: { backgroundColor: colors.paper, borderRadius: radius.lg, paddingHorizontal: spacing.lg },
  member: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    minHeight: 68,
    paddingVertical: spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.line,
  },
  role: { borderRadius: radius.pill, paddingHorizontal: 10, paddingVertical: 4, backgroundColor: colors.concrete },
  roleOwner: { backgroundColor: colors.hivis },
});
QUP_EOF_18

# ---- src/components/MilestoneSheet.js
write_file 'src/components/MilestoneSheet.js' <<'QUP_EOF_19'
// /qup-work-app/src/components/MilestoneSheet.js
// Pro: add a step to a contract, or change / delete one that isn't done yet.
//   <MilestoneSheet visible milestone={m | null} hourly={false} onSave={(body) => ...} onDelete={() => ...} onClose />
// onSave/onDelete return true when it worked, so the sheet knows to close.
import { useEffect, useState } from 'react';
import { View } from 'react-native';
import { AppText } from '@/components/AppText';
import { Button } from '@/components/Button';
import { toOre } from '@/components/ProFields';
import { Sheet } from '@/components/Sheet';
import { TextField } from '@/components/TextField';
import { spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { formatDate, oreInputText } from '@/lib/format';
import { dayInputText, dayToIso, parseDay } from '@/lib/time';

export function MilestoneSheet({ visible, milestone, hourly, onSave, onDelete, onClose }) {
  const { t } = useI18n();
  const editing = Boolean(milestone);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [amount, setAmount] = useState('');
  const [due, setDue] = useState('');
  const [errors, setErrors] = useState({});
  const [busy, setBusy] = useState(null); // 'save' | 'delete'

  // Fill the form each time it opens
  useEffect(() => {
    if (!visible) return;
    setTitle(milestone?.title ?? '');
    setDescription(milestone?.description ?? '');
    setAmount(oreInputText(milestone?.amount));
    setDue(dayInputText(milestone?.dueDate));
    setErrors({});
    setBusy(null);
  }, [visible, milestone]);

  const dueDate = parseDay(due);

  async function save() {
    const errs = {};
    if (title.trim().length < 2) errs.title = t('STEP_TITLE_REQUIRED');
    if (!hourly && amount.trim() && !toOre(amount)) errs.amount = t('AMOUNT_INVALID');
    if (due.trim() && !dueDate) errs.due = t('DATE_INVALID');
    setErrors(errs);
    if (Object.keys(errs).length) return;

    setBusy('save');
    const ok = await onSave({
      title: title.trim(),
      description: description.trim(),
      // null clears the amount / date when the field was emptied
      ...(hourly ? {} : { amount: toOre(amount) ?? null }),
      dueDate: dueDate ? dayToIso(dueDate) : null,
    });
    setBusy(null);
    if (ok) onClose();
  }

  async function remove() {
    setBusy('delete');
    const ok = await onDelete();
    setBusy(null);
    if (ok) onClose();
  }

  const canDelete = editing && milestone.status === 'pending';

  return (
    <Sheet
      visible={visible}
      onClose={onClose}
      title={editing ? t('EDIT_STEP') : t('ADD_STEP')}
      subtitle={editing ? milestone.title : t('ADD_STEP_INTRO')}
    >
      <TextField label={t('STEP_TITLE')} value={title} onChangeText={setTitle} placeholder={t('STEP_TITLE_PLACEHOLDER')} maxLength={150} error={errors.title} />
      <TextField
        label={t('DESCRIPTION')}
        value={description}
        onChangeText={setDescription}
        multiline
        placeholder={t('STEP_DESCRIPTION_PLACEHOLDER')}
        maxLength={3000}
      />
      <View style={{ flexDirection: 'row', gap: spacing.md }}>
        {!hourly ? (
          <View style={{ flex: 1 }}>
            <TextField label={t('STEP_AMOUNT')} value={amount} onChangeText={setAmount} keyboardType="decimal-pad" placeholder="5 000" error={errors.amount} />
          </View>
        ) : null}
        <View style={{ flex: 1 }}>
          <TextField
            label={t('STEP_DUE')}
            value={due}
            onChangeText={setDue}
            keyboardType="numbers-and-punctuation"
            placeholder={t('DATE_PLACEHOLDER')}
            error={errors.due}
            hint={dueDate ? formatDate(dueDate.toISOString()) : undefined}
          />
        </View>
      </View>
      {editing && milestone.status !== 'pending' ? (
        <AppText variant="small" muted>
          {t('STEP_STARTED_NO_DELETE')}
        </AppText>
      ) : null}
      <Button title={editing ? t('SAVE_CHANGES') : t('ADD_STEP')} icon={editing ? 'checkmark' : 'add'} loading={busy === 'save'} disabled={Boolean(busy)} onPress={save} />
      {canDelete ? (
        <Button title={t('DELETE_STEP')} icon="trash-outline" variant="danger" loading={busy === 'delete'} disabled={Boolean(busy)} onPress={remove} />
      ) : null}
    </Sheet>
  );
}
QUP_EOF_19

# ---- src/components/PushHandler.js
write_file 'src/components/PushHandler.js' <<'QUP_EOF_20'
// /qup-work-app/src/components/PushHandler.js
// Lives once in the root layout. While someone is logged in it:
//   - registers the phone for push (again when the language changes, so the text matches)
//   - opens the right screen when a push is tapped, also when it started the app
//   - refreshes the badges when a push arrives while the app is open
import * as Notifications from 'expo-notifications';
import { router } from 'expo-router';
import { useEffect, useRef } from 'react';
import { useAuth } from '@/context/AuthContext';
import { useUnread } from '@/context/UnreadContext';
import { useI18n } from '@/i18n';
import { api } from '@/lib/api';
import { describeNotification } from '@/lib/notifications';
import { forgetPushToken, pushSupported, registerForPush } from '@/lib/push';

export function PushHandler() {
  const { user } = useAuth();
  const { language } = useI18n();
  const { refreshUnread } = useUnread();
  const userId = user?._id;
  const handled = useRef(new Set()); // notification ids already opened
  const refresh = useRef(refreshUnread);
  refresh.current = refreshUnread;

  useEffect(() => {
    if (!userId) {
      forgetPushToken();
      return;
    }
    registerForPush(language.code);
  }, [userId, language.code]);

  useEffect(() => {
    if (!userId || !pushSupported()) return undefined;

    function open(response) {
      const request = response?.notification?.request;
      if (!request || handled.current.has(request.identifier)) return;
      handled.current.add(request.identifier);
      const data = request.content.data ?? {};
      if (data.notificationId) api(`/notifications/${data.notificationId}/read`, { method: 'POST' }).catch(() => {});
      const { target } = describeNotification({ type: data.type, data, title: request.content.title, body: request.content.body });
      router.push(target ?? '/notifications');
      refresh.current();
    }

    // Tapped while the app was closed
    Notifications.getLastNotificationResponseAsync()
      .then(open)
      .catch(() => {});

    const tapped = Notifications.addNotificationResponseReceivedListener(open);
    const received = Notifications.addNotificationReceivedListener(() => refresh.current());
    return () => {
      tapped.remove();
      received.remove();
    };
  }, [userId]);

  return null;
}
QUP_EOF_20

# ---- src/components/SignatureSheet.js
write_file 'src/components/SignatureSheet.js' <<'QUP_EOF_21'
// /qup-work-app/src/components/SignatureSheet.js
// For customers without the app: they approve a step by signing on the pro's phone, on site.
//   <SignatureSheet milestone={m} onClose onSign={({ name, imageUrl }) => ...} />
// The drawing is saved as a small SVG on Cloudinary; the API stores it with the step.
import { useRef, useState } from 'react';
import { PanResponder, StyleSheet, View } from 'react-native';
import Svg, { Path } from 'react-native-svg';
import { AppText } from '@/components/AppText';
import { Button } from '@/components/Button';
import { Sheet } from '@/components/Sheet';
import { TextField } from '@/components/TextField';
import { colors, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { errorMessage } from '@/lib/api';
import { uploadDataUri } from '@/lib/upload';

const PAD_HEIGHT = 180;

// btoa for plain ASCII (the SVG is only numbers and letters), without relying on a global
const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
function toBase64(text) {
  let out = '';
  for (let i = 0; i < text.length; i += 3) {
    const [a, b, c] = [text.charCodeAt(i), text.charCodeAt(i + 1), text.charCodeAt(i + 2)];
    const n = (a << 16) | ((b || 0) << 8) | (c || 0);
    out += B64[(n >> 18) & 63] + B64[(n >> 12) & 63] + (Number.isNaN(b) ? '=' : B64[(n >> 6) & 63]) + (Number.isNaN(c) ? '=' : B64[n & 63]);
  }
  return out;
}

const round = (n) => Math.round(n * 10) / 10;

export function SignatureSheet({ milestone, onClose, onSign }) {
  const { t } = useI18n();
  const [name, setName] = useState('');
  const [strokes, setStrokes] = useState([]); // ["M1 2 L3 4 ...", ...]
  const [width, setWidth] = useState(0);
  const [error, setError] = useState(null);
  const [sending, setSending] = useState(false);
  const current = useRef('');

  const pan = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onStartShouldSetPanResponderCapture: () => true,
      onMoveShouldSetPanResponderCapture: () => true,
      onPanResponderTerminationRequest: () => false, // don't let the sheet scroll while signing
      onPanResponderGrant: (e) => {
        const { locationX: x, locationY: y } = e.nativeEvent;
        current.current = `M${round(x)} ${round(y)}`;
        setStrokes((s) => [...s, current.current]);
      },
      onPanResponderMove: (e) => {
        const { locationX: x, locationY: y } = e.nativeEvent;
        current.current += ` L${round(x)} ${round(y)}`;
        const path = current.current;
        setStrokes((s) => [...s.slice(0, -1), path]);
      },
    })
  ).current;

  function close() {
    setName('');
    setStrokes([]);
    setError(null);
    onClose();
  }

  const signed = strokes.some((s) => s.includes('L'));

  async function send() {
    setSending(true);
    setError(null);
    try {
      const svg =
        `<svg xmlns="http://www.w3.org/2000/svg" width="${Math.round(width)}" height="${PAD_HEIGHT}" viewBox="0 0 ${Math.round(width)} ${PAD_HEIGHT}">` +
        `<rect width="100%" height="100%" fill="#ffffff"/>` +
        strokes.map((d) => `<path d="${d}" fill="none" stroke="#1D2A2E" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>`).join('') +
        '</svg>';
      const imageUrl = await uploadDataUri(`data:image/svg+xml;base64,${toBase64(svg)}`, { purpose: 'signature' });
      const ok = await onSign({ name: name.trim(), imageUrl });
      if (ok) close();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSending(false);
    }
  }

  return (
    <Sheet visible={Boolean(milestone)} onClose={close} title={t('SIGN_ON_SITE')} subtitle={milestone?.title}>
      <AppText variant="small" muted>
        {t('SIGN_ON_SITE_INTRO')}
      </AppText>
      <TextField label={t('CUSTOMER_NAME')} value={name} onChangeText={setName} placeholder={t('NAME_PLACEHOLDER')} maxLength={100} autoComplete="name" />

      <View style={{ gap: 6 }}>
        <View style={styles.padHead}>
          <AppText variant="smallStrong" style={{ flex: 1 }}>
            {t('SIGNATURE')}
          </AppText>
          {strokes.length ? (
            <AppText variant="smallStrong" color={colors.info} onPress={() => setStrokes([])} accessibilityRole="button">
              {t('CLEAR')}
            </AppText>
          ) : null}
        </View>
        <View style={styles.pad} onLayout={(e) => setWidth(e.nativeEvent.layout.width)} {...pan.panHandlers}>
          <Svg width="100%" height={PAD_HEIGHT} pointerEvents="none">
            {strokes.map((d, i) => (
              <Path key={i} d={d} fill="none" stroke={colors.slate} strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" />
            ))}
          </Svg>
          {!strokes.length ? (
            <AppText variant="small" muted style={styles.padHint} pointerEvents="none">
              {t('SIGN_HERE')}
            </AppText>
          ) : null}
          <View style={styles.baseline} pointerEvents="none" />
        </View>
      </View>

      {error ? (
        <AppText variant="small" color={colors.danger}>
          {error}
        </AppText>
      ) : null}
      <Button
        title={t('APPROVE_WITH_SIGNATURE')}
        icon="create-outline"
        loading={sending}
        disabled={!signed || name.trim().length < 2}
        onPress={send}
      />
    </Sheet>
  );
}

const styles = StyleSheet.create({
  padHead: { flexDirection: 'row', alignItems: 'center' },
  pad: {
    height: PAD_HEIGHT,
    borderRadius: radius.md,
    borderWidth: 1.5,
    borderColor: colors.line,
    backgroundColor: colors.paper,
    overflow: 'hidden',
  },
  padHint: { position: 'absolute', top: spacing.md, left: spacing.lg },
  baseline: {
    position: 'absolute',
    left: spacing.lg,
    right: spacing.lg,
    bottom: 40,
    borderBottomWidth: 1,
    borderStyle: 'dashed',
    borderColor: colors.line,
  },
});
QUP_EOF_21

# ---- src/context/AuthContext.js
write_file 'src/context/AuthContext.js' <<'QUP_EOF_22'
// /qup-work-app/src/context/AuthContext.js
// Holds the logged-in user for the whole app.
//   const { user, login, logout } = useAuth();
//
// useAuth() gives you:
//   session        { user, companies, proProfile } from GET /auth/me, or null
//   user           session.user, or null when logged out
//   isLoading      true while we check for a saved login on app start
//   isPro          the user has the pro role
//   login(email, password), register(name, email, password), logout()
//   refreshSession()   reload /auth/me (e.g. after creating a company)
//   setActiveRole('customer' | 'pro')
//   signInWithTokens({ accessToken, refreshToken })   after resetting a password
//   deleteAccount(password)   deletes the account and logs out
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { api, ApiError, setOnSessionExpired } from '@/lib/api';
import { tokenStore } from '@/lib/tokenStore';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null);
  const [isLoading, setIsLoading] = useState(true);

  const refreshSession = useCallback(async () => {
    const data = await api('/auth/me');
    setSession(data);
  }, []);

  // On app start: if we have a saved login, load the user
  useEffect(() => {
    setOnSessionExpired(() => setSession(null));

    (async () => {
      try {
        if (await tokenStore.getRefresh()) await refreshSession();
      } catch (err) {
        if (err instanceof ApiError && err.status === 401) await tokenStore.clear();
        // Offline (status 0): the user sees the login screen, tokens are kept for next start
      } finally {
        setIsLoading(false);
      }
    })();

    return () => setOnSessionExpired(null);
  }, [refreshSession]);

  const startSession = useCallback(
    async (data) => {
      await tokenStore.set(data.accessToken, data.refreshToken);
      await refreshSession();
    },
    [refreshSession]
  );

  const login = useCallback(
    async (email, password) => {
      const data = await api('/auth/login', {
        method: 'POST',
        body: { email: email.trim(), password },
        auth: false,
      });
      await startSession(data);
    },
    [startSession]
  );

  const register = useCallback(
    async (name, email, password) => {
      const data = await api('/auth/register', {
        method: 'POST',
        body: { name: name.trim(), email: email.trim(), password },
        auth: false,
      });
      await startSession(data);
    },
    [startSession]
  );

  const logout = useCallback(async () => {
    try {
      await api('/auth/logout', { method: 'POST' });
    } catch {
      // Even if the server can't be reached, log out locally
    }
    await tokenStore.clear();
    setSession(null);
  }, []);

  const deleteAccount = useCallback(async (password) => {
    await api('/auth/me', { method: 'DELETE', body: { password } });
    await tokenStore.clear();
    setSession(null);
  }, []);

  const setActiveRole = useCallback(
    async (role) => {
      await api('/auth/me', { method: 'PATCH', body: { activeRole: role } });
      await refreshSession();
    },
    [refreshSession]
  );

  const value = useMemo(
    () => ({
      session,
      user: session?.user ?? null,
      isLoading,
      isPro: session?.user.roles.includes('pro') ?? false,
      login,
      register,
      logout,
      refreshSession,
      setActiveRole,
      signInWithTokens: startSession,
      deleteAccount,
    }),
    [session, isLoading, login, register, logout, refreshSession, setActiveRole, startSession, deleteAccount]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside <AuthProvider>');
  return ctx;
}
QUP_EOF_22

# ---- src/lib/format.js
write_file 'src/lib/format.js' <<'QUP_EOF_23'
// /qup-work-app/src/lib/format.js
// Formatting helpers. Text comes from the translation files via translate(),
// so they follow the chosen language.
import Ionicons from '@expo/vector-icons/Ionicons';
import { colors } from '@/constants/theme';
import { currentLocale, hasTranslation, translate as t } from '@/i18n';

// 125000 øre → "1 250 kr"   (the marketplace is in NOK; shows øre only when there are any)
export function formatNok(ore) {
  if (ore == null) return '';
  const negative = ore < 0;
  const abs = Math.abs(Math.round(ore));
  const kroner = Math.floor(abs / 100);
  const rest = abs % 100;
  const withSpaces = String(kroner).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  const decimals = rest ? `,${String(rest).padStart(2, '0')}` : '';
  return `${negative ? '−' : ''}${withSpaces}${decimals} kr`;
}

// Budget on a job: "5 000–10 000 kr", "Up to 8 000 kr", "From 2 000 kr" or "Price by agreement"
export function budgetText(budget) {
  const min = budget?.min;
  const max = budget?.max;
  if (min != null && max != null) {
    return t('BUDGET_RANGE', { min: formatNok(min).replace(' kr', ''), max: formatNok(max) });
  }
  if (max != null) return t('BUDGET_UP_TO', { max: formatNok(max) });
  if (min != null) return t('BUDGET_FROM', { min: formatNok(min) });
  return t('BUDGET_NEGOTIABLE');
}

export function placeText(job) {
  if (job.workType === 'remote') return t('REMOTE_WORK');
  return job.address?.city ?? job.address?.municipality ?? t('PLACE_NOT_GIVEN');
}

// "27 Oct" / "27. okt." in the chosen language; adds the year when it isn't this year
export function formatDate(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  const sameYear = d.getFullYear() === new Date().getFullYear();
  try {
    return new Intl.DateTimeFormat(currentLocale(), {
      day: 'numeric',
      month: 'short',
      ...(sameYear ? {} : { year: 'numeric' }),
    }).format(d);
  } catch {
    return d.toISOString().slice(0, 10);
  }
}

// "now", "5 min ago", "3 h ago", "yesterday", then a date
export function timeAgo(iso) {
  if (!iso) return '';
  const diffMin = Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
  if (diffMin < 1) return t('TIME_NOW');
  if (diffMin < 60) return t('TIME_MINUTES_AGO', { n: diffMin });
  const hours = Math.floor(diffMin / 60);
  if (hours < 24) return t('TIME_HOURS_AGO', { n: hours });
  if (hours < 48) return t('TIME_YESTERDAY');
  return formatDate(iso);
}

// "14:05" (or "2:05 PM") in the chosen language
export function formatTime(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  try {
    return new Intl.DateTimeFormat(currentLocale(), { hour: 'numeric', minute: '2-digit' }).format(d);
  } catch {
    return d.toTimeString().slice(0, 5);
  }
}

export const isSameDay = (a, b) => new Date(a).toDateString() === new Date(b).toDateString();

// Divider between days in a chat: "Today", "Yesterday", "Monday" (this week), then a date
export function dayLabel(iso) {
  const d = new Date(iso);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const day = new Date(d);
  day.setHours(0, 0, 0, 0);
  const daysAgo = Math.round((today - day) / 86400000);
  if (daysAgo === 0) return t('TODAY');
  if (daysAgo === 1) return t('YESTERDAY');
  if (daysAgo > 1 && daysAgo < 7) {
    try {
      return new Intl.DateTimeFormat(currentLocale(), { weekday: 'long' }).format(d);
    } catch {
      return formatDate(iso);
    }
  }
  return formatDate(iso);
}

// Translation keys; look them up with t() when rendering
export const URGENCY = {
  asap: 'URGENCY_ASAP',
  within_week: 'URGENCY_WITHIN_WEEK',
  within_month: 'URGENCY_WITHIN_MONTH',
  flexible: 'URGENCY_FLEXIBLE',
};

export const JOB_STATUS = {
  draft: { label: 'STATUS_DRAFT', color: colors.textMuted, bg: colors.line },
  open: { label: 'STATUS_OPEN', color: colors.pine, bg: colors.pineSoft },
  assigned: { label: 'STATUS_ASSIGNED', color: colors.info, bg: colors.infoSoft },
  in_progress: { label: 'STATUS_IN_PROGRESS', color: colors.amber, bg: colors.amberSoft },
  completed: { label: 'STATUS_COMPLETED', color: colors.pine, bg: colors.pineSoft },
  cancelled: { label: 'STATUS_CANCELLED', color: colors.danger, bg: colors.dangerSoft },
};

export const OFFER_STATUS = {
  pending: { label: 'OFFER_STATUS_PENDING', color: colors.amber, bg: colors.amberSoft },
  accepted: { label: 'OFFER_STATUS_ACCEPTED', color: colors.pine, bg: colors.pineSoft },
  rejected: { label: 'OFFER_STATUS_REJECTED', color: colors.danger, bg: colors.dangerSoft },
  withdrawn: { label: 'OFFER_STATUS_WITHDRAWN', color: colors.textMuted, bg: colors.line },
  expired: { label: 'OFFER_STATUS_EXPIRED', color: colors.textMuted, bg: colors.line },
};

export const CONTRACT_STATUS = {
  active: { label: 'CONTRACT_STATUS_ACTIVE', color: colors.info, bg: colors.infoSoft },
  completed: { label: 'STATUS_COMPLETED', color: colors.pine, bg: colors.pineSoft },
  cancelled: { label: 'STATUS_CANCELLED', color: colors.danger, bg: colors.dangerSoft },
  disputed: { label: 'CONTRACT_STATUS_DISPUTED', color: colors.danger, bg: colors.dangerSoft },
};

export const MILESTONE_STATUS = {
  pending: { label: 'MILESTONE_STATUS_PENDING', color: colors.textMuted, bg: colors.line },
  in_progress: { label: 'STATUS_IN_PROGRESS', color: colors.amber, bg: colors.amberSoft },
  submitted: { label: 'MILESTONE_STATUS_SUBMITTED', color: colors.info, bg: colors.infoSoft },
  changes_requested: { label: 'MILESTONE_STATUS_CHANGES', color: colors.danger, bg: colors.dangerSoft },
  approved: { label: 'MILESTONE_STATUS_APPROVED', color: colors.pine, bg: colors.pineSoft },
  cancelled: { label: 'STATUS_CANCELLED', color: colors.textMuted, bg: colors.line },
};

export const INVOICE_STATUS = {
  draft: { label: 'INVOICE_STATUS_DRAFT', color: colors.textMuted, bg: colors.line },
  sent: { label: 'INVOICE_STATUS_SENT', color: colors.info, bg: colors.infoSoft },
  overdue: { label: 'INVOICE_STATUS_OVERDUE', color: colors.danger, bg: colors.dangerSoft },
  paid: { label: 'INVOICE_STATUS_PAID', color: colors.pine, bg: colors.pineSoft },
  cancelled: { label: 'STATUS_CANCELLED', color: colors.textMuted, bg: colors.line },
  credited: { label: 'INVOICE_STATUS_CREDITED', color: colors.textMuted, bg: colors.line },
};

// "Overdue" isn't stored; a sent invoice past its due date is overdue
export const invoiceStatus = (invoice) =>
  invoice.isOverdue || (invoice.status === 'sent' && invoice.dueDate && new Date(invoice.dueDate) < new Date())
    ? 'overdue'
    : invoice.status;

// Units the API accepts on invoice lines → translation keys
export const UNITS = { stk: 'UNIT_STK', timer: 'UNIT_TIMER', m: 'UNIT_M', m2: 'UNIT_M2', km: 'UNIT_KM', pakke: 'UNIT_PAKKE' };

// 2.5 → "2,5" in Norwegian, "2.5" in English
export function formatNumber(n, maxDecimals = 2) {
  try {
    return new Intl.NumberFormat(currentLocale(), { maximumFractionDigits: maxDecimals }).format(n);
  } catch {
    return String(n);
  }
}

// 200 → "3 h 20 min", 45 → "45 min"
export function formatMinutes(minutes) {
  const m = Math.max(0, Math.round(minutes ?? 0));
  const h = Math.floor(m / 60);
  const rest = m % 60;
  if (!h) return t('DURATION_MIN', { m: rest });
  if (!rest) return t('DURATION_H', { h });
  return t('DURATION_H_MIN', { h, m: rest });
}

// Price on an offer, as a big line and a small one underneath:
//   fixed    → "8 000 kr"      / "Fixed price"
//   hourly   → "950 kr/h"      / "About 7 600 kr in total" (or "Hourly rate")
//   estimate → "12 000 kr"     / "Estimate"
export function offerPrice(offer) {
  if (offer.priceType === 'hourly') {
    const total = offer.estimatedTotal ?? (offer.estimatedHours ? offer.amount * offer.estimatedHours : null);
    return {
      main: t('PRICE_PER_HOUR', { price: formatNok(offer.amount) }),
      sub: total ? t('ESTIMATE_TOTAL', { total: formatNok(total) }) : t('PRICE_HOURLY'),
    };
  }
  return { main: formatNok(offer.amount), sub: t(offer.priceType === 'estimate' ? 'PRICE_ESTIMATE' : 'PRICE_FIXED') };
}

// Categories come from the API in Norwegian. The app translates the ones it knows by slug
// (CAT_ELEKTRIKER, CAT_RORLEGGER_BAD, ...) and shows the API name for anything new.
export function categoryName(category) {
  if (!category) return '';
  if (category.slug) {
    const key = `CAT_${category.slug.toUpperCase().replace(/-/g, '_')}`;
    if (hasTranslation(key)) return t(key);
  }
  return category.name;
}

// Category icons from the API → valid Ionicons names (with a safe fallback)
const ICON_ALIASES = {
  truck: 'car',
  palette: 'color-palette',
  code: 'code-slash',
  apps: 'apps',
};

export function categoryIcon(name) {
  const base = ICON_ALIASES[name] ?? name ?? 'construct';
  const outline = `${base}-outline`;
  if (Ionicons.glyphMap[outline]) return outline;
  if (Ionicons.glyphMap[base]) return base;
  return 'construct-outline';
}

// 1250050 øre → "12500,50" for putting an amount back into a text field ("" when empty)
export function oreInputText(ore) {
  if (ore == null) return '';
  const kroner = Math.floor(Math.abs(ore) / 100);
  const rest = Math.abs(ore) % 100;
  return `${ore < 0 ? '-' : ''}${kroner}${rest ? `,${String(rest).padStart(2, '0')}` : ''}`;
}
QUP_EOF_23

# ---- src/lib/notifications.js
write_file 'src/lib/notifications.js' <<'QUP_EOF_24'
// /qup-work-app/src/lib/notifications.js
// Turns a notification from the API into what the app shows: text in the chosen
// language, an icon, and where tapping it should go.
//
// The API also sends a Norwegian title/body. We only use those for notifications
// that don't carry the details we need (older ones, or types we don't know yet).
import { colors } from '@/constants/theme';
import { translate as t } from '@/i18n';

const job = (d) => d.jobTitle;
const to = (pathname, id) => (id ? { pathname, params: { id: String(id) } } : null);

// type → icon, colours, text builder (returns null when details are missing) and target
const KINDS = {
  new_offer: {
    icon: 'document-text',
    color: colors.slate,
    bg: colors.hivis,
    text: (d) => job(d) && d.actorName && { title: t('NOTIF_NEW_OFFER'), body: t('NOTIF_NEW_OFFER_BODY', { name: d.actorName, job: job(d) }) },
    target: (d) => to('/job/[id]', d.jobId),
  },
  offer_accepted: {
    icon: 'trophy',
    color: colors.pine,
    bg: colors.pineSoft,
    text: (d) => job(d) && { title: t('NOTIF_OFFER_ACCEPTED'), body: t('NOTIF_OFFER_ACCEPTED_BODY', { job: job(d) }) },
    target: (d) => to('/contract/[id]', d.contractId) ?? to('/job/[id]', d.jobId),
  },
  offer_rejected: {
    icon: 'close-circle',
    color: colors.textMuted,
    bg: colors.line,
    text: (d) =>
      job(d) && {
        title:
          d.reason === 'other_chosen'
            ? t('NOTIF_OFFER_OTHER_CHOSEN')
            : d.reason === 'job_cancelled'
              ? t('NOTIF_JOB_WITHDRAWN')
              : t('NOTIF_OFFER_DECLINED'),
        body: t('NOTIF_JOB_BODY', { job: job(d) }),
      },
    target: () => ({ pathname: '/my-offers' }),
  },
  milestone_submitted: {
    icon: 'checkmark-circle',
    color: colors.info,
    bg: colors.infoSoft,
    text: (d) =>
      job(d) && d.stepTitle && { title: t('NOTIF_STEP_SUBMITTED'), body: t('NOTIF_STEP_SUBMITTED_BODY', { name: d.actorName ?? '', step: d.stepTitle, job: job(d) }) },
    target: (d) => to('/contract/[id]', d.contractId),
  },
  milestone_approved: {
    icon: 'checkmark-done-circle',
    color: colors.pine,
    bg: colors.pineSoft,
    text: (d) => job(d) && d.stepTitle && { title: t('NOTIF_STEP_APPROVED'), body: t('NOTIF_STEP_BODY', { step: d.stepTitle, job: job(d) }) },
    target: (d) => to('/contract/[id]', d.contractId),
  },
  changes_requested: {
    icon: 'construct',
    color: colors.danger,
    bg: colors.dangerSoft,
    text: (d) => job(d) && d.stepTitle && { title: t('NOTIF_CHANGES_REQUESTED'), body: t('NOTIF_STEP_BODY', { step: d.stepTitle, job: job(d) }) },
    target: (d) => to('/contract/[id]', d.contractId),
  },
  contract_completed: {
    icon: 'ribbon',
    color: colors.pine,
    bg: colors.pineSoft,
    text: (d) => job(d) && { title: t('NOTIF_JOB_COMPLETED'), body: t('NOTIF_JOB_BODY', { job: job(d) }) },
    target: (d) => to('/contract/[id]', d.contractId),
  },
  contract_cancelled: {
    icon: 'ban',
    color: colors.danger,
    bg: colors.dangerSoft,
    text: (d) => job(d) && { title: t('NOTIF_JOB_CANCELLED'), body: t('NOTIF_JOB_BODY', { job: job(d) }) },
    target: (d) => to('/contract/[id]', d.contractId),
  },
  invoice_received: {
    icon: 'receipt',
    color: colors.amber,
    bg: colors.amberSoft,
    text: (d) =>
      d.invoiceNumber && { title: t('NOTIF_INVOICE'), body: t('NOTIF_INVOICE_BODY', { number: d.invoiceNumber, name: d.actorName ?? '' }) },
    target: (d) => to('/invoice/[id]', d.invoiceId) ?? to('/contract/[id]', d.contractId),
  },
  new_review: {
    icon: 'star',
    color: colors.hivisDeep,
    bg: colors.hivisSoft,
    text: (d) =>
      job(d) && d.rating && { title: t('NOTIF_REVIEW'), body: t('NOTIF_REVIEW_BODY', { name: d.actorName ?? '', rating: d.rating, job: job(d) }) },
    target: (d) => to('/contract/[id]', d.contractId),
  },
  new_job_nearby: {
    icon: 'megaphone',
    color: colors.slate,
    bg: colors.hivis,
    text: (d) =>
      job(d) && {
        title: d.invited ? t('NOTIF_JOB_INVITED') : d.remote ? t('NOTIF_NEW_JOB_REMOTE') : t('NOTIF_NEW_JOB_NEARBY'),
        body: d.place ? t('NOTIF_JOB_IN_PLACE', { job: job(d), place: d.place }) : t('NOTIF_JOB_BODY', { job: job(d) }),
      },
    target: (d) => to('/job/[id]', d.jobId),
  },
  new_message: {
    icon: 'chatbubble',
    color: colors.slate,
    bg: colors.concrete,
    text: (d) => d.actorName && { title: d.actorName, body: d.preview ?? t('ATTACHMENT') },
    target: (d) => to('/conversation/[id]', d.conversationId),
  },
};

const FALLBACK = { icon: 'notifications', color: colors.slate, bg: colors.concrete, text: () => null, target: () => null };

export function describeNotification(n) {
  const kind = KINDS[n.type] ?? FALLBACK;
  const data = n.data ?? {};
  const text = kind.text(data) || { title: n.title, body: n.body };
  return { ...text, icon: kind.icon, color: kind.color, bg: kind.bg, target: kind.target(data) };
}
QUP_EOF_24

# ---- src/lib/push.js
write_file 'src/lib/push.js' <<'QUP_EOF_25'
// /qup-work-app/src/lib/push.js
// Push notifications through Expo. The API sends a push for every in-app notification
// (see qup-work-api/src/utils/push.js); this file gets the phone's token to the API.
//
// Needs a development build or a store build with an EAS project id in app.json
// (extra.eas.projectId, set by `eas init`). In Expo Go, on the web and on simulators it
// quietly does nothing, and the in-app notifications work as before.
import Constants from 'expo-constants';
import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';
import { api } from '@/lib/api';

// Show notifications while the app is open too (the bell badge updates as well)
try {
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowBanner: true,
      shouldShowList: true,
      shouldPlaySound: false,
      shouldSetBadge: false,
    }),
  });
} catch {
  // Not available on this platform (web)
}

const projectId = () => Constants.expoConfig?.extra?.eas?.projectId ?? Constants.easConfig?.projectId;

export const pushSupported = () => Platform.OS !== 'web' && Boolean(projectId());

let lastSent = null; // `${token}|${locale}`, so we don't send the same thing again

// Asks for permission (the first time), then registers the token with the API.
// Returns the token, or null when push isn't possible or was declined.
export async function registerForPush(locale) {
  if (!pushSupported()) return null;
  try {
    if (Platform.OS === 'android') {
      await Notifications.setNotificationChannelAsync('default', {
        name: 'Qup Work',
        importance: Notifications.AndroidImportance.HIGH,
      });
    }
    let { status } = await Notifications.getPermissionsAsync();
    if (status !== 'granted') ({ status } = await Notifications.requestPermissionsAsync());
    if (status !== 'granted') return null;

    const { data: token } = await Notifications.getExpoPushTokenAsync({ projectId: projectId() });
    const key = `${token}|${locale}`;
    if (key !== lastSent) {
      await api('/auth/me/push-tokens', { method: 'POST', body: { token, platform: Platform.OS, locale } });
      lastSent = key;
    }
    return token;
  } catch (err) {
    // Simulator, Expo Go, no network: push is a bonus, never a blocker
    if (__DEV__) console.log('push registration skipped:', err?.message);
    return null;
  }
}

// After logout the API drops all tokens itself; this just forgets what we sent
export function forgetPushToken() {
  lastSent = null;
}
QUP_EOF_25

# ---- src/lib/time.js
write_file 'src/lib/time.js' <<'QUP_EOF_26'
// /qup-work-app/src/lib/time.js
// Small helpers for typing in hours by hand.

// "8" → 480, "08:30" → 510, "8.30" → 510, "0830" → 510, "17" → 1020. Invalid → null
export function parseClock(text) {
  const s = String(text ?? '').trim().replace(/\s/g, '');
  if (!s) return null;
  let h;
  let m = 0;
  const parts = s.split(/[:.,]/);
  if (parts.length === 2) {
    h = Number(parts[0]);
    m = Number(parts[1].padEnd(2, '0'));
  } else if (/^\d{3,4}$/.test(s)) {
    h = Number(s.slice(0, -2));
    m = Number(s.slice(-2));
  } else if (/^\d{1,2}$/.test(s)) {
    h = Number(s);
  } else {
    return null;
  }
  if (!Number.isInteger(h) || !Number.isInteger(m) || h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

// 510 → "08:30"
export const clockText = (minutes) =>
  `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`;

// A Date at local midnight
export function startOfDay(date = new Date()) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

// Local day + minutes after midnight → Date
export function atMinutes(day, minutes) {
  const d = startOfDay(day);
  d.setMinutes(minutes);
  return d;
}

// Minutes after local midnight for a date
export const minutesOfDay = (date) => {
  const d = new Date(date);
  return d.getHours() * 60 + d.getMinutes();
};

// The last `count` days, newest first (local midnights)
export function recentDays(count = 7) {
  const today = startOfDay();
  return Array.from({ length: count }, (_, i) => {
    const d = new Date(today);
    d.setDate(d.getDate() - i);
    return d;
  });
}

// Typing a date by hand: "27.10", "27.10.2026", "27/10/26" or "2026-10-27" → Date at local midnight.
// No year means this year. Invalid → null
export function parseDay(text) {
  const s = String(text ?? '').trim();
  if (!s) return null;
  let d;
  let m;
  let y;
  const iso = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
  const local = s.match(/^(\d{1,2})[./-](\d{1,2})(?:[./-](\d{2}|\d{4}))?\.?$/);
  if (iso) [, y, m, d] = iso.map(Number);
  else if (local) {
    d = Number(local[1]);
    m = Number(local[2]);
    y = local[3] ? Number(local[3]) : new Date().getFullYear();
    if (y < 100) y += 2000;
  } else return null;
  const date = new Date(y, m - 1, d);
  if (date.getFullYear() !== y || date.getMonth() !== m - 1 || date.getDate() !== d) return null;
  return date;
}

// Date → "27.10.2026" for putting back in a text field
export function dayInputText(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  return `${String(d.getDate()).padStart(2, '0')}.${String(d.getMonth() + 1).padStart(2, '0')}.${d.getFullYear()}`;
}

// A day as an ISO string at noon UTC-ish local, so it never slips to the day before in another time zone
export function dayToIso(date) {
  const d = new Date(date);
  d.setHours(12, 0, 0, 0);
  return d.toISOString();
}
QUP_EOF_26

# ---- src/lib/upload.js
write_file 'src/lib/upload.js' <<'QUP_EOF_27'
// /qup-work-app/src/lib/upload.js
// Photos go straight from the phone to Cloudinary. The API only hands out a short-lived
// signature (POST /uploads/signature), so the Cloudinary secret never touches the app.
//
//   const asset = (await ImagePicker.launchCameraAsync()).assets[0];
//   const attachment = await uploadPhoto(asset, { purpose: 'milestone', tag: 'after' });
//   → { url, key, kind: 'image', tag, mimeType, size, name }   ready to send to the API
import { Platform } from 'react-native';
import { translate as t } from '@/i18n';
import { api, ApiError } from '@/lib/api';

export async function uploadPhoto(asset, { purpose = 'milestone', tag = 'other' } = {}) {
  const sig = await api('/uploads/signature', { method: 'POST', body: { purpose } });

  const form = new FormData();
  if (Platform.OS === 'web') {
    // The web picker gives a real File; fall back to fetching the blob URL
    form.append('file', asset.file ?? (await (await fetch(asset.uri)).blob()));
  } else {
    form.append('file', {
      uri: asset.uri,
      name: asset.fileName ?? `photo-${Date.now()}.jpg`,
      type: asset.mimeType ?? 'image/jpeg',
    });
  }
  form.append('api_key', sig.apiKey);
  form.append('timestamp', String(sig.timestamp));
  form.append('folder', sig.folder);
  form.append('signature', sig.signature);

  let res;
  try {
    res = await fetch(sig.uploadUrl, { method: 'POST', body: form });
  } catch {
    throw new ApiError(t('ERROR_OFFLINE'), 0);
  }
  const data = await res.json().catch(() => null);
  if (!res.ok || !data?.secure_url) {
    throw new ApiError(t('UPLOAD_FAILED'), res.status, data?.error?.message ? { cloudinary: data.error.message } : undefined);
  }

  return {
    url: data.secure_url,
    key: data.public_id,
    kind: data.resource_type === 'image' ? 'image' : 'document',
    tag,
    name: asset.fileName ?? undefined,
    mimeType: asset.mimeType ?? undefined,
    size: data.bytes,
  };
}

// A smaller, faster version of a Cloudinary photo for thumbnails:
//   thumbUrl(url, 240) → .../upload/c_fill,w_240,h_240,q_auto,f_auto/...
// Other URLs are returned unchanged.
export function thumbUrl(url, size = 240) {
  if (!url?.includes('res.cloudinary.com') || !url.includes('/upload/')) return url;
  const px = Math.round(size * 2); // sharp on high-density screens
  return url.replace('/upload/', `/upload/c_fill,w_${px},h_${px},q_auto,f_auto/`);
}

// A large version for the full-screen viewer (keeps the shape, caps the size)
export function largeUrl(url) {
  if (!url?.includes('res.cloudinary.com') || !url.includes('/upload/')) return url;
  return url.replace('/upload/', '/upload/c_limit,w_1600,h_1600,q_auto,f_auto/');
}

// Uploads something made in the app (a drawn signature) as a data URI:
//   await uploadDataUri(`data:image/svg+xml;base64,${b64}`, { purpose: 'signature' })  → url
export async function uploadDataUri(dataUri, { purpose = 'signature' } = {}) {
  const sig = await api('/uploads/signature', { method: 'POST', body: { purpose } });
  const form = new FormData();
  form.append('file', dataUri);
  form.append('api_key', sig.apiKey);
  form.append('timestamp', String(sig.timestamp));
  form.append('folder', sig.folder);
  form.append('signature', sig.signature);

  let res;
  try {
    res = await fetch(sig.uploadUrl, { method: 'POST', body: form });
  } catch {
    throw new ApiError(t('ERROR_OFFLINE'), 0);
  }
  const data = await res.json().catch(() => null);
  if (!res.ok || !data?.secure_url) {
    throw new ApiError(t('UPLOAD_FAILED'), res.status, data?.error?.message ? { cloudinary: data.error.message } : undefined);
  }
  return data.secure_url;
}
QUP_EOF_27

# ---- New texts in all 35 languages (added to the end of each file; keys that exist are left alone)
echo "  🌍 adding translations"
mkdir -p "$BACKUP/src/locales" && cp src/locales/*.json "$BACKUP/src/locales/"
cat > "$BACKUP/new-texts.json" <<'QUP_LOCALES_EOF'
{"en-US": {"EDIT": "Edit", "REMOVE": "Remove", "CLEAR": "Clear", "ARCHIVE": "Archive", "NOTES": "Notes", "YOU": "you", "DATE_PLACEHOLDER": "dd.mm.yyyy", "DATE_INVALID": "Write the date as dd.mm.yyyy.", "AMOUNT_INVALID": "Write an amount in NOK, e.g. 5000.", "EMAIL_INVALID": "That email address doesn't look right.", "POSTCODE_FORMAT": "A postcode has 4 digits.", "CLIENT": "Client", "CLIENTS": "Clients", "CLIENTS_PRO_ONLY": "Your own client register is for pros. Log in with a pro account to use it.", "SEARCH_CLIENTS": "Search clients", "CLIENTS_ACTIVE": "Active", "CLIENTS_ARCHIVED": "Archived", "NO_CLIENTS": "No clients yet", "NO_CLIENTS_TEXT": "Add the customers you work for outside the marketplace, and keep jobs, hours and invoices for them in one place.", "NO_CLIENTS_MATCH": "No clients match your search.", "NO_ARCHIVED_CLIENTS": "Nothing archived", "NO_ARCHIVED_CLIENTS_TEXT": "Clients you archive end up here, with their old jobs and invoices.", "NEW_CLIENT": "New client", "EDIT_CLIENT": "Edit client", "SAVE_CLIENT": "Save client", "CLIENT_FORM_INTRO": "Only you and your company can see this. The address is used as the work address on new jobs.", "CLIENT_TYPE": "Type of client", "CLIENT_PRIVATE": "Private person", "CLIENT_BUSINESS": "Business", "CLIENT_COMPANY_PLACEHOLDER": "E.g. Bergen Eiendom AS", "CONTACT_PERSON": "Contact person", "CONTACT_NAME": "Contact: {name}", "CLIENT_EMAIL_HINT": "Invoices can be sent here.", "CLIENT_NOTES_PLACEHOLDER": "Gate code, parking, the dog's name…", "CLIENT_NOTES_HINT": "Only for you and your colleagues, never shown to the client.", "CLIENT_NOT_FOUND": "Client not found", "CLIENT_IS_ARCHIVED": "Archived", "CLIENT_NO_DETAILS": "No contact details yet. Tap Edit to add them.", "CLIENT_JOBS": "Jobs", "CLIENT_NO_JOBS": "No jobs for this client yet.", "ARCHIVE_CLIENT": "Archive client", "ARCHIVE_CLIENT_TITLE": "Archive this client?", "ARCHIVE_CLIENT_TEXT": "The client has jobs, so they're kept with their jobs and invoices. You can restore them later.", "RESTORE_CLIENT": "Restore client", "DELETE_CLIENT": "Delete client", "DELETE_CLIENT_TITLE": "Delete this client?", "DELETE_CLIENT_TEXT": "{name} is removed from your register.", "NEW_ASSIGNMENT": "New assignment", "NEW_ASSIGNMENT_INTRO": "Register work for your own client and agree the price. You can add steps, log hours and invoice from the contract.", "PICK_CLIENT_INTRO": "Who is the work for?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "What's agreed, materials, anything the client should know", "START_DATE": "Start date", "END_DATE": "End date", "END_BEFORE_START": "The end date is before the start date.", "STEPS_OPTIONAL_HINT": "Optional. Without steps the whole job is one step.", "STEPS_SPLIT_HINT": "Each step is approved separately. The amounts must add up to the price.", "STEPS_HOURLY_HINT": "Each step is approved separately. The hours are logged on the contract.", "STEP_TITLE": "Step", "STEP_TITLE_PLACEHOLDER": "E.g. Demolition and drainage", "STEP_TITLE_REQUIRED": "Give each step a name.", "STEP_AMOUNT": "Amount (NOK)", "STEP_AMOUNT_REQUIRED": "Give each step an amount.", "STEP_DUE": "Due date", "STEP_DESCRIPTION_PLACEHOLDER": "What's included in this step", "STEPS_MUST_ADD_UP": "The steps must add up to {total}.", "STEPS_ADD_UP": "The steps add up to the price ✓", "STEPS_REST": "Left to split: {rest}", "STEPS_TOTAL_MISMATCH": "The steps add up to {steps}, the agreed price is {total}.", "REMOVE_STEP": "Remove step", "ADD_STEP": "Add step", "ADD_STEP_INTRO": "The customer approves each step when it's done.", "EDIT_STEP": "Edit step", "DELETE_STEP": "Delete step", "DELETE_STEP_TITLE": "Delete this step?", "DELETE_STEP_TEXT": "“{title}” is removed from the contract.", "STEP_STARTED_NO_DELETE": "This step has started, so it can be changed but not deleted.", "CREATE_CONTRACT": "Create contract", "JOB_HAS_CONTRACT": "This job already has a contract.", "JOB_NOT_YOURS": "Only the one who created the job can change it.", "JOB_CANNOT_EDIT": "Someone is already hired, so the job can't be changed any more.", "EDIT_JOB": "Edit job", "EDIT_JOB_INTRO": "Pros see the changes straight away.", "EDIT_JOB_WITH_OFFERS": "Offers received: {n}. Tell the pros about big changes in the chat, so their offers still fit.", "CREATED_AGO": "Created {time}", "DRAFT_NOT_VISIBLE": "This is a draft. Pros can't see it until you publish it.", "CANCEL_JOB": "Cancel job", "CANCEL_JOB_TITLE": "Cancel this job?", "CANCEL_JOB_TEXT": "The job is taken down and can't be reopened.", "CANCEL_JOB_WITH_OFFERS_TEXT": "The job is taken down, and the pros who sent offers ({n}) are told it was cancelled.", "DELETE_JOB_TITLE": "Delete the draft?", "DELETE_JOB_TEXT": "The draft is deleted for good.", "CANCEL_CONTRACT": "Cancel the contract", "CANCEL_CONTRACT_INTRO": "The work stops here. Approved steps and invoices are kept, and the other side is told.", "CANCEL_REASON": "Why? (optional)", "CANCEL_REASON_PLACEHOLDER": "A few words both of you can see later", "CONTRACT_CANCELLED_ON": "Cancelled {date}", "COMPLETE_CLIENT_JOB_TEXT": "All steps are signed off. The job is marked as completed.", "SIGN_ON_SITE": "Customer signs", "SIGN_ON_SITE_INTRO": "Let the customer check the work and sign with a finger on the screen. This approves the step.", "CUSTOMER_NAME": "Customer's name", "SIGNATURE": "Signature", "SIGN_HERE": "Sign here", "APPROVE_WITH_SIGNATURE": "Approve with signature", "CHANGE_PASSWORD": "Change password", "CHANGE_PASSWORD_INTRO": "You stay logged in here. Your other phones and browsers are logged out.", "CURRENT_PASSWORD": "Current password", "CURRENT_PASSWORD_REQUIRED": "Enter your current password.", "CURRENT_PASSWORD_WRONG": "That's not your current password.", "NEW_PASSWORD": "New password", "REPEAT_PASSWORD": "Repeat new password", "PASSWORDS_DONT_MATCH": "The passwords don't match.", "PASSWORD_SAME_AS_OLD": "Choose a password you haven't used here.", "PASSWORD_CHANGED": "Password changed", "PAYMENTS": "Payments", "PAYMENT": "Payment", "NO_PAYMENTS": "No payments yet", "NO_PAYMENTS_TEXT": "Payments made through the app show up here. Jobs paid by invoice are under Invoices.", "PAYMENT_STATUS_PENDING": "Waiting", "PAYMENT_STATUS_HELD": "Held safely", "PAYMENT_STATUS_RELEASED": "Paid out", "PAYMENT_STATUS_REFUNDED": "Refunded", "PAYMENT_STATUS_FAILED": "Failed", "PLATFORM_FEE": "Fee {fee}", "TEAM": "Team", "TEAM_ROW_HINT": "The people working in the company", "TEAM_MANAGE_HINT": "Colleagues need a Qup Work account first. Tap someone to change or remove them.", "TEAM_WORKER_HINT": "The owner and admins add and remove colleagues.", "ADD_MEMBER": "Add colleague", "ADD_MEMBER_INTRO": "Use the email they signed up to Qup Work with.", "MEMBER_NOT_FOUND": "Nobody has signed up with that email yet. Ask them to create an account first.", "MEMBER_ALREADY": "That person is already in the company.", "ROLE": "Role", "ROLE_ADMIN_HINT": "Admins can change the company details and invoice settings, and add colleagues.", "ROLE_WORKER_HINT": "Workers see the company's jobs, log hours and do the work.", "REMOVE_FROM_COMPANY": "Remove from company", "REMOVE_MEMBER_TITLE": "Remove from the company?", "REMOVE_MEMBER_TEXT": "{name} no longer sees the company's jobs and clients.", "LEAVE_COMPANY": "Leave the company", "LEAVE_COMPANY_TITLE": "Leave the company?", "LEAVE_COMPANY_TEXT": "You no longer see {name}'s jobs and clients.", "NOTIF_JOB_WITHDRAWN": "The customer cancelled the job", "INVOICE_EMAILED_TO": "The PDF was emailed to {email}.", "INVOICE_NO_EMAIL": "Sent, but not emailed: the client has no email address. Open the PDF and share it yourself, or use Email invoice.", "INVOICE_EMAIL_NOT_SET_UP": "Sent, but not emailed: email isn't set up on the server yet (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Sent, but the email failed: {error}", "SEND_INVOICE_EMAIL_TO": "The PDF is emailed to {email}.", "SEND_INVOICE_NO_EMAIL": "There's no email address, so it won't be emailed. You can share the PDF yourself.", "EMAIL_INVOICE": "Email invoice", "PREVIEW_PDF": "Preview PDF", "OPEN_PDF": "Open PDF", "EMAILED": "Emailed", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Not emailed", "INVOICE_LANGUAGE": "Language on the invoice", "NOTIF_NEW_JOB_NEARBY": "New job near you", "NOTIF_NEW_JOB_REMOTE": "New remote job", "NOTIF_JOB_INVITED": "You were invited to a job", "NOTIF_JOB_IN_PLACE": "“{job}” in {place}", "JOB_ALERTS": "New job alerts", "JOB_ALERTS_ON_TEXT": "You get a notification when a job in your categories is posted in your area.", "JOB_ALERTS_OFF_TEXT": "You won't be notified about new jobs, but you can still browse them in the app.", "JOB_ALERTS_NEEDS_VISIBLE": "Turn on visibility first. Only pros customers can find get job alerts.", "FORGOT_PASSWORD": "Forgot your password?", "FORGOT_PASSWORD_TITLE": "New password", "FORGOT_PASSWORD_INTRO": "Enter the email you signed up with, and we'll send you a code.", "SEND_CODE": "Send code", "RESET_CODE_SENT": "If {email} has an account, a 6-digit code is on its way. Enter it below with a new password.", "RESET_CODE": "Code from the email", "RESET_CODE_INVALID": "The code has 6 digits.", "RESET_CODE_WRONG": "The code is wrong or has expired. Ask for a new one.", "SAVE_NEW_PASSWORD": "Save and log in", "RESET_CODE_AGAIN": "Send a new code", "RESET_CODE_RESENT": "New code sent", "RESET_CODE_SPAM_HINT": "No email after a few minutes? Check your spam folder.", "DELETE_ACCOUNT": "Delete account", "DELETE_ACCOUNT_INTRO": "This deletes the account for {email}. It can't be undone.", "DELETE_WHAT_GOES": "Deleted", "DELETE_GOES_PROFILE": "Your name, photo, phone and email", "DELETE_GOES_PRO": "Your pro profile, so customers can't find you any more", "DELETE_GOES_JOBS": "Open jobs you've posted, and offers nobody has answered", "DELETE_GOES_LOGIN": "Your login, on all devices", "DELETE_WHAT_STAYS": "Kept, without your name", "DELETE_STAYS_CONTRACTS": "Finished contracts, messages and reviews, so the other side still has them", "DELETE_STAYS_INVOICES": "Invoices, which Norwegian bookkeeping rules require to be kept for 5 years", "DELETE_PASSWORD_HINT": "To make sure it's you.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Delete your account?", "DELETE_ACCOUNT_CONFIRM_TEXT": "You're logged out and can't log in with this account again.", "DELETE_BLOCKED_CONTRACTS": "You have ongoing contracts. Complete or cancel them first, so the other side isn't left waiting.", "DELETE_BLOCKED_COMPANY": "You own a company with other members. Remove them under Team first.", "JOB_CATEGORY_REQUIRED": "Choose a category, so the right pros hear about the job."}, "sr-RS": {"EDIT": "Izmeni", "REMOVE": "Ukloni", "CLEAR": "Obriši", "ARCHIVE": "Arhiviraj", "NOTES": "Beleške", "YOU": "ti", "DATE_PLACEHOLDER": "dd.mm.gggg", "DATE_INVALID": "Napiši datum u obliku dd.mm.gggg.", "AMOUNT_INVALID": "Napiši iznos u NOK, npr. 5000.", "EMAIL_INVALID": "Ta imejl adresa ne izgleda ispravno.", "POSTCODE_FORMAT": "Poštanski broj ima 4 cifre.", "CLIENT": "Klijent", "CLIENTS": "Klijenti", "CLIENTS_PRO_ONLY": "Sopstveni registar klijenata je za majstore. Prijavi se nalogom majstora da bi ga koristio.", "SEARCH_CLIENTS": "Traži klijente", "CLIENTS_ACTIVE": "Aktivni", "CLIENTS_ARCHIVED": "Arhivirani", "NO_CLIENTS": "Još nema klijenata", "NO_CLIENTS_TEXT": "Dodaj klijente za koje radiš van platforme i drži njihove poslove, sate i račune na jednom mestu.", "NO_CLIENTS_MATCH": "Nijedan klijent ne odgovara pretrazi.", "NO_ARCHIVED_CLIENTS": "Ništa nije arhivirano", "NO_ARCHIVED_CLIENTS_TEXT": "Klijenti koje arhiviraš završavaju ovde, sa starim poslovima i računima.", "NEW_CLIENT": "Novi klijent", "EDIT_CLIENT": "Izmeni klijenta", "SAVE_CLIENT": "Sačuvaj klijenta", "CLIENT_FORM_INTRO": "Ovo vidite samo ti i tvoja firma. Adresa se koristi kao mesto rada na novim poslovima.", "CLIENT_TYPE": "Vrsta klijenta", "CLIENT_PRIVATE": "Fizičko lice", "CLIENT_BUSINESS": "Firma", "CLIENT_COMPANY_PLACEHOLDER": "Npr. Bergen Eiendom AS", "CONTACT_PERSON": "Kontakt osoba", "CONTACT_NAME": "Kontakt: {name}", "CLIENT_EMAIL_HINT": "Računi mogu da se šalju ovde.", "CLIENT_NOTES_PLACEHOLDER": "Šifra za kapiju, parking, kako se zove pas…", "CLIENT_NOTES_HINT": "Samo za tebe i tvoje kolege, klijentu se nikad ne prikazuje.", "CLIENT_NOT_FOUND": "Klijent nije pronađen", "CLIENT_IS_ARCHIVED": "Arhiviran", "CLIENT_NO_DETAILS": "Još nema kontakt podataka. Dodirni Izmeni da ih dodaš.", "CLIENT_JOBS": "Poslovi", "CLIENT_NO_JOBS": "Još nema poslova za ovog klijenta.", "ARCHIVE_CLIENT": "Arhiviraj klijenta", "ARCHIVE_CLIENT_TITLE": "Arhivirati ovog klijenta?", "ARCHIVE_CLIENT_TEXT": "Klijent ima poslove, pa se čuva zajedno sa poslovima i računima. Možeš ga kasnije vratiti.", "RESTORE_CLIENT": "Vrati klijenta", "DELETE_CLIENT": "Obriši klijenta", "DELETE_CLIENT_TITLE": "Obrisati ovog klijenta?", "DELETE_CLIENT_TEXT": "{name} se uklanja iz tvog registra.", "NEW_ASSIGNMENT": "Novi posao", "NEW_ASSIGNMENT_INTRO": "Upiši posao za svog klijenta i dogovori cenu. Na ugovoru možeš da dodaš korake, upisuješ sate i izdaješ račune.", "PICK_CLIENT_INTRO": "Za koga je posao?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Šta je dogovoreno, materijal, sve što klijent treba da zna", "START_DATE": "Datum početka", "END_DATE": "Datum završetka", "END_BEFORE_START": "Datum završetka je pre datuma početka.", "STEPS_OPTIONAL_HINT": "Opciono. Bez koraka je ceo posao jedan korak.", "STEPS_SPLIT_HINT": "Svaki korak se odobrava posebno. Iznosi moraju zajedno da daju cenu.", "STEPS_HOURLY_HINT": "Svaki korak se odobrava posebno. Sati se upisuju na ugovor.", "STEP_TITLE": "Korak", "STEP_TITLE_PLACEHOLDER": "Npr. Rušenje i odvod", "STEP_TITLE_REQUIRED": "Daj ime svakom koraku.", "STEP_AMOUNT": "Iznos (NOK)", "STEP_AMOUNT_REQUIRED": "Daj iznos svakom koraku.", "STEP_DUE": "Rok", "STEP_DESCRIPTION_PLACEHOLDER": "Šta obuhvata ovaj korak", "STEPS_MUST_ADD_UP": "Koraci zajedno moraju da daju {total}.", "STEPS_ADD_UP": "Koraci zajedno daju cenu ✓", "STEPS_REST": "Ostalo za raspodelu: {rest}", "STEPS_TOTAL_MISMATCH": "Koraci zajedno daju {steps}, dogovorena cena je {total}.", "REMOVE_STEP": "Ukloni korak", "ADD_STEP": "Dodaj korak", "ADD_STEP_INTRO": "Klijent odobrava svaki korak kad je gotov.", "EDIT_STEP": "Izmeni korak", "DELETE_STEP": "Obriši korak", "DELETE_STEP_TITLE": "Obrisati ovaj korak?", "DELETE_STEP_TEXT": "„{title}” se uklanja sa ugovora.", "STEP_STARTED_NO_DELETE": "Ovaj korak je počeo, pa može da se menja, ali ne i da se obriše.", "CREATE_CONTRACT": "Napravi ugovor", "JOB_HAS_CONTRACT": "Ovaj posao već ima ugovor.", "JOB_NOT_YOURS": "Samo onaj ko je napravio posao može da ga menja.", "JOB_CANNOT_EDIT": "Neko je već angažovan, pa posao više ne može da se menja.", "EDIT_JOB": "Izmeni posao", "EDIT_JOB_INTRO": "Stručnjaci odmah vide izmene.", "EDIT_JOB_WITH_OFFERS": "Primljene ponude: {n}. Javi stručnjacima u četu za veće izmene, da bi im ponude i dalje odgovarale.", "CREATED_AGO": "Napravljeno {time}", "DRAFT_NOT_VISIBLE": "Ovo je nacrt. Stručnjaci ga ne vide dok ga ne objaviš.", "CANCEL_JOB": "Otkaži posao", "CANCEL_JOB_TITLE": "Otkazati ovaj posao?", "CANCEL_JOB_TEXT": "Posao se uklanja i ne može ponovo da se otvori.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Posao se uklanja, a stručnjaci koji su poslali ponude ({n}) dobijaju obaveštenje da je otkazan.", "DELETE_JOB_TITLE": "Obrisati nacrt?", "DELETE_JOB_TEXT": "Nacrt se trajno briše.", "CANCEL_CONTRACT": "Otkaži ugovor", "CANCEL_CONTRACT_INTRO": "Rad se ovde zaustavlja. Odobreni koraci i računi ostaju, a druga strana dobija obaveštenje.", "CANCEL_REASON": "Zašto? (opciono)", "CANCEL_REASON_PLACEHOLDER": "Par reči koje ćete oboje moći kasnije da vidite", "CONTRACT_CANCELLED_ON": "Otkazano {date}", "COMPLETE_CLIENT_JOB_TEXT": "Svi koraci su potpisani. Posao se označava kao završen.", "SIGN_ON_SITE": "Klijent potpisuje", "SIGN_ON_SITE_INTRO": "Neka klijent pregleda rad i potpiše se prstom na ekranu. Time se korak odobrava.", "CUSTOMER_NAME": "Ime klijenta", "SIGNATURE": "Potpis", "SIGN_HERE": "Potpišite ovde", "APPROVE_WITH_SIGNATURE": "Odobri potpisom", "CHANGE_PASSWORD": "Promeni lozinku", "CHANGE_PASSWORD_INTRO": "Ovde ostaješ prijavljen. Na ostalim telefonima i pregledačima bićeš odjavljen.", "CURRENT_PASSWORD": "Trenutna lozinka", "CURRENT_PASSWORD_REQUIRED": "Unesi trenutnu lozinku.", "CURRENT_PASSWORD_WRONG": "To nije tvoja trenutna lozinka.", "NEW_PASSWORD": "Nova lozinka", "REPEAT_PASSWORD": "Ponovi novu lozinku", "PASSWORDS_DONT_MATCH": "Lozinke se ne poklapaju.", "PASSWORD_SAME_AS_OLD": "Izaberi lozinku koju ovde još nisi koristio.", "PASSWORD_CHANGED": "Lozinka je promenjena", "PAYMENTS": "Plaćanja", "PAYMENT": "Plaćanje", "NO_PAYMENTS": "Još nema plaćanja", "NO_PAYMENTS_TEXT": "Ovde se prikazuju plaćanja preko aplikacije. Poslove plaćene računom naći ćeš pod Računi.", "PAYMENT_STATUS_PENDING": "Na čekanju", "PAYMENT_STATUS_HELD": "Bezbedno zadržano", "PAYMENT_STATUS_RELEASED": "Isplaćeno", "PAYMENT_STATUS_REFUNDED": "Vraćeno", "PAYMENT_STATUS_FAILED": "Neuspešno", "PLATFORM_FEE": "Naknada {fee}", "TEAM": "Tim", "TEAM_ROW_HINT": "Ljudi koji rade u firmi", "TEAM_MANAGE_HINT": "Kolege prvo moraju da imaju Qup Work nalog. Dodirni nekog da ga izmeniš ili ukloniš.", "TEAM_WORKER_HINT": "Vlasnik i administratori dodaju i uklanjaju kolege.", "ADD_MEMBER": "Dodaj kolegu", "ADD_MEMBER_INTRO": "Koristi imejl sa kojim se registrovao na Qup Work.", "MEMBER_NOT_FOUND": "Niko se još nije registrovao sa tim imejlom. Zamoli ga da prvo napravi nalog.", "MEMBER_ALREADY": "Ta osoba je već u firmi.", "ROLE": "Uloga", "ROLE_ADMIN_HINT": "Administratori mogu da menjaju podatke firme i podešavanja računa i da dodaju kolege.", "ROLE_WORKER_HINT": "Zaposleni vide poslove firme, upisuju sate i rade posao.", "REMOVE_FROM_COMPANY": "Ukloni iz firme", "REMOVE_MEMBER_TITLE": "Ukloniti iz firme?", "REMOVE_MEMBER_TEXT": "{name} više ne vidi poslove i klijente firme.", "LEAVE_COMPANY": "Napusti firmu", "LEAVE_COMPANY_TITLE": "Napustiti firmu?", "LEAVE_COMPANY_TEXT": "Više ne vidiš poslove i klijente firme {name}.", "NOTIF_JOB_WITHDRAWN": "Klijent je otkazao posao", "INVOICE_EMAILED_TO": "{email} je primio račun kao PDF.", "INVOICE_NO_EMAIL": "Poslato, ali ne imejlom: kupac nema imejl adresu. Otvori PDF i podeli ga sam ili koristi Pošalji imejlom.", "INVOICE_EMAIL_NOT_SET_UP": "Poslato, ali ne imejlom: imejl još nije podešen na serveru (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Poslato, ali imejl nije uspeo: {error}", "SEND_INVOICE_EMAIL_TO": "PDF se šalje imejlom na {email}.", "SEND_INVOICE_NO_EMAIL": "Nema imejl adrese, pa se neće poslati imejlom. PDF možeš podeliti sam.", "EMAIL_INVOICE": "Pošalji imejlom", "PREVIEW_PDF": "Pregled PDF-a", "OPEN_PDF": "Otvori PDF", "EMAILED": "Poslato imejlom", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Nije poslato imejlom", "INVOICE_LANGUAGE": "Jezik računa", "NOTIF_NEW_JOB_NEARBY": "Novi posao u tvojoj blizini", "NOTIF_NEW_JOB_REMOTE": "Novi posao na daljinu", "NOTIF_JOB_INVITED": "Pozvan si na posao", "NOTIF_JOB_IN_PLACE": "„{job}” – {place}", "JOB_ALERTS": "Obaveštenja o novim poslovima", "JOB_ALERTS_ON_TEXT": "Dobiješ obaveštenje kad se u tvom području objavi posao iz tvojih kategorija.", "JOB_ALERTS_OFF_TEXT": "Nećeš dobijati obaveštenja o novim poslovima, ali ih i dalje vidiš u aplikaciji.", "JOB_ALERTS_NEEDS_VISIBLE": "Prvo uključi vidljivost. Obaveštenja dobijaju samo majstori koje kupci mogu da pronađu.", "FORGOT_PASSWORD": "Zaboravljena lozinka?", "FORGOT_PASSWORD_TITLE": "Nova lozinka", "FORGOT_PASSWORD_INTRO": "Unesi imejl kojim si se registrovao i poslaćemo ti kod.", "SEND_CODE": "Pošalji kod", "RESET_CODE_SENT": "Ako {email} ima nalog, šestocifreni kod je na putu. Unesi ga ispod zajedno sa novom lozinkom.", "RESET_CODE": "Kod iz imejla", "RESET_CODE_INVALID": "Kod ima 6 cifara.", "RESET_CODE_WRONG": "Kod je pogrešan ili je istekao. Zatraži novi.", "SAVE_NEW_PASSWORD": "Sačuvaj i prijavi se", "RESET_CODE_AGAIN": "Pošalji novi kod", "RESET_CODE_RESENT": "Novi kod je poslat", "RESET_CODE_SPAM_HINT": "Nema imejla posle nekoliko minuta? Proveri folder za neželjenu poštu.", "DELETE_ACCOUNT": "Obriši nalog", "DELETE_ACCOUNT_INTRO": "Ovim se briše nalog za {email}. Ovo se ne može poništiti.", "DELETE_WHAT_GOES": "Briše se", "DELETE_GOES_PROFILE": "Tvoje ime, fotografija, telefon i imejl", "DELETE_GOES_PRO": "Tvoj profil majstora, tako da te klijenti više ne mogu naći", "DELETE_GOES_JOBS": "Otvoreni poslovi koje si objavio i ponude na koje niko nije odgovorio", "DELETE_GOES_LOGIN": "Tvoja prijava, na svim uređajima", "DELETE_WHAT_STAYS": "Čuva se, bez tvog imena", "DELETE_STAYS_CONTRACTS": "Završeni ugovori, poruke i recenzije, da bi ih druga strana i dalje imala", "DELETE_STAYS_INVOICES": "Računi, koje prema norveškim računovodstvenim pravilima treba čuvati 5 godina", "DELETE_PASSWORD_HINT": "Da bismo bili sigurni da si to ti.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Obrisati nalog?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Bićeš odjavljen i više nećeš moći da se prijaviš sa ovim nalogom.", "DELETE_BLOCKED_CONTRACTS": "Imaš ugovore u toku. Prvo ih završi ili otkaži, da druga strana ne bi ostala da čeka.", "DELETE_BLOCKED_COMPANY": "Vlasnik si firme sa drugim članovima. Prvo ih ukloni u odeljku Tim.", "JOB_CATEGORY_REQUIRED": "Izaberi kategoriju, da bi pravi majstori saznali za posao."}, "nb-NO": {"EDIT": "Endre", "REMOVE": "Fjern", "CLEAR": "Tøm", "ARCHIVE": "Arkiver", "NOTES": "Notater", "YOU": "deg", "DATE_PLACEHOLDER": "dd.mm.åååå", "DATE_INVALID": "Skriv datoen som dd.mm.åååå.", "AMOUNT_INVALID": "Skriv et beløp i kroner, f.eks. 5000.", "EMAIL_INVALID": "E-postadressen ser ikke riktig ut.", "POSTCODE_FORMAT": "Et postnummer har 4 siffer.", "CLIENT": "Kunde", "CLIENTS": "Kunder", "CLIENTS_PRO_ONLY": "Kunderegisteret er for fagfolk. Logg inn med en fagperson-konto for å bruke det.", "SEARCH_CLIENTS": "Søk i kunder", "CLIENTS_ACTIVE": "Aktive", "CLIENTS_ARCHIVED": "Arkiverte", "NO_CLIENTS": "Ingen kunder ennå", "NO_CLIENTS_TEXT": "Legg inn kundene du jobber for utenom markedsplassen, og ha oppdrag, timer og fakturaer for dem samlet på ett sted.", "NO_CLIENTS_MATCH": "Ingen kunder passer søket.", "NO_ARCHIVED_CLIENTS": "Ingenting arkivert", "NO_ARCHIVED_CLIENTS_TEXT": "Kunder du arkiverer havner her, med gamle oppdrag og fakturaer.", "NEW_CLIENT": "Ny kunde", "EDIT_CLIENT": "Endre kunde", "SAVE_CLIENT": "Lagre kunde", "CLIENT_FORM_INTRO": "Bare du og firmaet ditt ser dette. Adressen brukes som arbeidssted på nye oppdrag.", "CLIENT_TYPE": "Type kunde", "CLIENT_PRIVATE": "Privatperson", "CLIENT_BUSINESS": "Bedrift", "CLIENT_COMPANY_PLACEHOLDER": "F.eks. Bergen Eiendom AS", "CONTACT_PERSON": "Kontaktperson", "CONTACT_NAME": "Kontakt: {name}", "CLIENT_EMAIL_HINT": "Fakturaer kan sendes hit.", "CLIENT_NOTES_PLACEHOLDER": "Portkode, parkering, hva hunden heter …", "CLIENT_NOTES_HINT": "Bare for deg og kollegene dine, vises aldri for kunden.", "CLIENT_NOT_FOUND": "Fant ikke kunden", "CLIENT_IS_ARCHIVED": "Arkivert", "CLIENT_NO_DETAILS": "Ingen kontaktinfo ennå. Trykk på Endre for å legge den inn.", "CLIENT_JOBS": "Oppdrag", "CLIENT_NO_JOBS": "Ingen oppdrag for denne kunden ennå.", "ARCHIVE_CLIENT": "Arkiver kunde", "ARCHIVE_CLIENT_TITLE": "Arkivere kunden?", "ARCHIVE_CLIENT_TEXT": "Kunden har oppdrag, så den beholdes sammen med oppdrag og fakturaer. Du kan hente den tilbake senere.", "RESTORE_CLIENT": "Hent tilbake kunde", "DELETE_CLIENT": "Slett kunde", "DELETE_CLIENT_TITLE": "Slette kunden?", "DELETE_CLIENT_TEXT": "{name} fjernes fra kunderegisteret ditt.", "NEW_ASSIGNMENT": "Nytt oppdrag", "NEW_ASSIGNMENT_INTRO": "Registrer arbeid for din egen kunde og avtal prisen. Steg, timer og faktura legger du inn på kontrakten.", "PICK_CLIENT_INTRO": "Hvem er jobben for?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Hva som er avtalt, materialer, det kunden bør vite", "START_DATE": "Startdato", "END_DATE": "Sluttdato", "END_BEFORE_START": "Sluttdatoen er før startdatoen.", "STEPS_OPTIONAL_HINT": "Valgfritt. Uten steg er hele jobben ett steg.", "STEPS_SPLIT_HINT": "Hvert steg godkjennes for seg. Beløpene må gå opp i prisen.", "STEPS_HOURLY_HINT": "Hvert steg godkjennes for seg. Timene føres på kontrakten.", "STEP_TITLE": "Steg", "STEP_TITLE_PLACEHOLDER": "F.eks. Riving og sluk", "STEP_TITLE_REQUIRED": "Gi hvert steg et navn.", "STEP_AMOUNT": "Beløp (kr)", "STEP_AMOUNT_REQUIRED": "Gi hvert steg et beløp.", "STEP_DUE": "Frist", "STEP_DESCRIPTION_PLACEHOLDER": "Hva som inngår i dette steget", "STEPS_MUST_ADD_UP": "Stegene må gå opp i {total}.", "STEPS_ADD_UP": "Stegene går opp i prisen ✓", "STEPS_REST": "Igjen å fordele: {rest}", "STEPS_TOTAL_MISMATCH": "Stegene utgjør {steps}, avtalt pris er {total}.", "REMOVE_STEP": "Fjern steg", "ADD_STEP": "Legg til steg", "ADD_STEP_INTRO": "Kunden godkjenner hvert steg når det er ferdig.", "EDIT_STEP": "Endre steg", "DELETE_STEP": "Slett steg", "DELETE_STEP_TITLE": "Slette steget?", "DELETE_STEP_TEXT": "«{title}» fjernes fra kontrakten.", "STEP_STARTED_NO_DELETE": "Steget er påbegynt, så det kan endres, men ikke slettes.", "CREATE_CONTRACT": "Opprett kontrakt", "JOB_HAS_CONTRACT": "Dette oppdraget har allerede en kontrakt.", "JOB_NOT_YOURS": "Bare den som laget oppdraget kan endre det.", "JOB_CANNOT_EDIT": "Noen er allerede ansatt, så oppdraget kan ikke endres lenger.", "EDIT_JOB": "Endre oppdrag", "EDIT_JOB_INTRO": "Fagfolk ser endringene med en gang.", "EDIT_JOB_WITH_OFFERS": "Mottatte tilbud: {n}. Si fra i chatten om store endringer, så tilbudene fortsatt passer.", "CREATED_AGO": "Opprettet {time}", "DRAFT_NOT_VISIBLE": "Dette er et utkast. Fagfolk ser det ikke før du publiserer.", "CANCEL_JOB": "Avlys oppdrag", "CANCEL_JOB_TITLE": "Avlyse oppdraget?", "CANCEL_JOB_TEXT": "Oppdraget tas ned og kan ikke åpnes igjen.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Oppdraget tas ned, og fagfolkene som har sendt tilbud ({n}), får beskjed om at det er avlyst.", "DELETE_JOB_TITLE": "Slette utkastet?", "DELETE_JOB_TEXT": "Utkastet slettes for godt.", "CANCEL_CONTRACT": "Avbryt kontrakten", "CANCEL_CONTRACT_INTRO": "Arbeidet stopper her. Godkjente steg og fakturaer beholdes, og den andre parten får beskjed.", "CANCEL_REASON": "Hvorfor? (valgfritt)", "CANCEL_REASON_PLACEHOLDER": "Noen ord dere begge kan se senere", "CONTRACT_CANCELLED_ON": "Avbrutt {date}", "COMPLETE_CLIENT_JOB_TEXT": "Alle stegene er signert. Oppdraget blir markert som fullført.", "SIGN_ON_SITE": "Kunden signerer", "SIGN_ON_SITE_INTRO": "La kunden se over arbeidet og signere med fingeren på skjermen. Det godkjenner steget.", "CUSTOMER_NAME": "Kundens navn", "SIGNATURE": "Signatur", "SIGN_HERE": "Signer her", "APPROVE_WITH_SIGNATURE": "Godkjenn med signatur", "CHANGE_PASSWORD": "Bytt passord", "CHANGE_PASSWORD_INTRO": "Du forblir innlogget her. Andre telefoner og nettlesere blir logget ut.", "CURRENT_PASSWORD": "Nåværende passord", "CURRENT_PASSWORD_REQUIRED": "Skriv inn det nåværende passordet ditt.", "CURRENT_PASSWORD_WRONG": "Det er ikke det nåværende passordet ditt.", "NEW_PASSWORD": "Nytt passord", "REPEAT_PASSWORD": "Gjenta nytt passord", "PASSWORDS_DONT_MATCH": "Passordene er ikke like.", "PASSWORD_SAME_AS_OLD": "Velg et passord du ikke har brukt her.", "PASSWORD_CHANGED": "Passordet er byttet", "PAYMENTS": "Betalinger", "PAYMENT": "Betaling", "NO_PAYMENTS": "Ingen betalinger ennå", "NO_PAYMENTS_TEXT": "Betalinger gjennom appen dukker opp her. Oppdrag som betales med faktura finner du under Fakturaer.", "PAYMENT_STATUS_PENDING": "Venter", "PAYMENT_STATUS_HELD": "Holdt trygt", "PAYMENT_STATUS_RELEASED": "Utbetalt", "PAYMENT_STATUS_REFUNDED": "Refundert", "PAYMENT_STATUS_FAILED": "Feilet", "PLATFORM_FEE": "Gebyr {fee}", "TEAM": "Team", "TEAM_ROW_HINT": "Folkene som jobber i firmaet", "TEAM_MANAGE_HINT": "Kolleger må ha en Qup Work-konto først. Trykk på noen for å endre eller fjerne dem.", "TEAM_WORKER_HINT": "Eieren og administratorene legger til og fjerner kolleger.", "ADD_MEMBER": "Legg til kollega", "ADD_MEMBER_INTRO": "Bruk e-posten de registrerte seg i Qup Work med.", "MEMBER_NOT_FOUND": "Ingen har registrert seg med den e-posten ennå. Be dem lage en konto først.", "MEMBER_ALREADY": "Den personen er allerede i firmaet.", "ROLE": "Rolle", "ROLE_ADMIN_HINT": "Administratorer kan endre firmaopplysninger og fakturaoppsett, og legge til kolleger.", "ROLE_WORKER_HINT": "Ansatte ser firmaets oppdrag, fører timer og gjør jobben.", "REMOVE_FROM_COMPANY": "Fjern fra firmaet", "REMOVE_MEMBER_TITLE": "Fjerne fra firmaet?", "REMOVE_MEMBER_TEXT": "{name} ser ikke lenger firmaets oppdrag og kunder.", "LEAVE_COMPANY": "Forlat firmaet", "LEAVE_COMPANY_TITLE": "Forlate firmaet?", "LEAVE_COMPANY_TEXT": "Du ser ikke lenger oppdragene og kundene til {name}.", "NOTIF_JOB_WITHDRAWN": "Kunden avlyste oppdraget", "INVOICE_EMAILED_TO": "PDF-en er sendt på e-post til {email}.", "INVOICE_NO_EMAIL": "Sendt, men ikke på e-post: kunden har ingen e-postadresse. Åpne PDF-en og del den selv, eller bruk Send på e-post.", "INVOICE_EMAIL_NOT_SET_UP": "Sendt, men ikke på e-post: e-post er ikke satt opp på serveren ennå (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Sendt, men e-posten feilet: {error}", "SEND_INVOICE_EMAIL_TO": "PDF-en sendes på e-post til {email}.", "SEND_INVOICE_NO_EMAIL": "Det finnes ingen e-postadresse, så den sendes ikke på e-post. Du kan dele PDF-en selv.", "EMAIL_INVOICE": "Send på e-post", "PREVIEW_PDF": "Forhåndsvis PDF", "OPEN_PDF": "Åpne PDF", "EMAILED": "Sendt på e-post", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Ikke sendt på e-post", "INVOICE_LANGUAGE": "Språk på fakturaen", "NOTIF_NEW_JOB_NEARBY": "Nytt oppdrag i nærheten", "NOTIF_NEW_JOB_REMOTE": "Nytt fjernoppdrag", "NOTIF_JOB_INVITED": "Du er invitert til et oppdrag", "NOTIF_JOB_IN_PLACE": "«{job}» i {place}", "JOB_ALERTS": "Varsel om nye oppdrag", "JOB_ALERTS_ON_TEXT": "Du får varsel når et oppdrag i dine kategorier legges ut i området ditt.", "JOB_ALERTS_OFF_TEXT": "Du får ikke varsel om nye oppdrag, men du kan fortsatt se dem i appen.", "JOB_ALERTS_NEEDS_VISIBLE": "Slå på synlighet først. Bare fagfolk kundene kan finne, får varsel om oppdrag.", "FORGOT_PASSWORD": "Glemt passordet?", "FORGOT_PASSWORD_TITLE": "Nytt passord", "FORGOT_PASSWORD_INTRO": "Skriv inn e-posten du registrerte deg med, så sender vi deg en kode.", "SEND_CODE": "Send kode", "RESET_CODE_SENT": "Hvis {email} har en konto, er en 6-sifret kode på vei. Skriv den inn under sammen med et nytt passord.", "RESET_CODE": "Kode fra e-posten", "RESET_CODE_INVALID": "Koden har 6 siffer.", "RESET_CODE_WRONG": "Koden er feil eller har gått ut. Be om en ny.", "SAVE_NEW_PASSWORD": "Lagre og logg inn", "RESET_CODE_AGAIN": "Send ny kode", "RESET_CODE_RESENT": "Ny kode er sendt", "RESET_CODE_SPAM_HINT": "Ingen e-post etter noen minutter? Sjekk søppelposten.", "DELETE_ACCOUNT": "Slett konto", "DELETE_ACCOUNT_INTRO": "Dette sletter kontoen for {email}. Det kan ikke angres.", "DELETE_WHAT_GOES": "Slettes", "DELETE_GOES_PROFILE": "Navn, bilde, telefon og e-post", "DELETE_GOES_PRO": "Fagprofilen din, så kunder ikke finner deg lenger", "DELETE_GOES_JOBS": "Åpne oppdrag du har lagt ut, og tilbud ingen har svart på", "DELETE_GOES_LOGIN": "Innloggingen din, på alle enheter", "DELETE_WHAT_STAYS": "Beholdes, uten navnet ditt", "DELETE_STAYS_CONTRACTS": "Avsluttede kontrakter, meldinger og vurderinger, så den andre parten fortsatt har dem", "DELETE_STAYS_INVOICES": "Fakturaer, som bokføringsreglene krever at oppbevares i 5 år", "DELETE_PASSWORD_HINT": "For å være sikre på at det er deg.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Slette kontoen?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Du blir logget ut og kan ikke logge inn med denne kontoen igjen.", "DELETE_BLOCKED_CONTRACTS": "Du har pågående kontrakter. Fullfør eller avbryt dem først, så den andre parten ikke blir stående og vente.", "DELETE_BLOCKED_COMPANY": "Du eier et firma med andre medlemmer. Fjern dem under Team først.", "JOB_CATEGORY_REQUIRED": "Velg en kategori, så de rette fagfolkene får høre om oppdraget."}, "is-IS": {"EDIT": "Breyta", "REMOVE": "Fjarlægja", "CLEAR": "Hreinsa", "ARCHIVE": "Setja í safn", "NOTES": "Athugasemdir", "YOU": "þú", "DATE_PLACEHOLDER": "dd.mm.áááá", "DATE_INVALID": "Skrifaðu dagsetninguna sem dd.mm.áááá.", "AMOUNT_INVALID": "Skrifaðu upphæð í NOK, t.d. 5000.", "EMAIL_INVALID": "Þetta netfang lítur ekki rétt út.", "POSTCODE_FORMAT": "Póstnúmer er 4 tölustafir.", "CLIENT": "Viðskiptavinur", "CLIENTS": "Viðskiptavinir", "CLIENTS_PRO_ONLY": "Eigin viðskiptavinaskrá er fyrir fagfólk. Skráðu þig inn með fagaðilaaðgangi til að nota hana.", "SEARCH_CLIENTS": "Leita að viðskiptavinum", "CLIENTS_ACTIVE": "Virkir", "CLIENTS_ARCHIVED": "Í safni", "NO_CLIENTS": "Engir viðskiptavinir enn", "NO_CLIENTS_TEXT": "Bættu við viðskiptavinum sem þú vinnur fyrir utan markaðstorgsins og haltu verkum, tímum og reikningum þeirra á einum stað.", "NO_CLIENTS_MATCH": "Enginn viðskiptavinur passar við leitina.", "NO_ARCHIVED_CLIENTS": "Ekkert í safni", "NO_ARCHIVED_CLIENTS_TEXT": "Viðskiptavinir sem þú setur í safn lenda hér, ásamt eldri verkum og reikningum.", "NEW_CLIENT": "Nýr viðskiptavinur", "EDIT_CLIENT": "Breyta viðskiptavini", "SAVE_CLIENT": "Vista viðskiptavin", "CLIENT_FORM_INTRO": "Aðeins þú og fyrirtækið þitt sjáið þetta. Heimilisfangið er notað sem verkstaður í nýjum verkum.", "CLIENT_TYPE": "Tegund viðskiptavinar", "CLIENT_PRIVATE": "Einstaklingur", "CLIENT_BUSINESS": "Fyrirtæki", "CLIENT_COMPANY_PLACEHOLDER": "T.d. Bergen Eiendom AS", "CONTACT_PERSON": "Tengiliður", "CONTACT_NAME": "Tengiliður: {name}", "CLIENT_EMAIL_HINT": "Hægt er að senda reikninga hingað.", "CLIENT_NOTES_PLACEHOLDER": "Hliðkóði, bílastæði, nafn hundsins …", "CLIENT_NOTES_HINT": "Aðeins fyrir þig og samstarfsfólk þitt, aldrei sýnt viðskiptavininum.", "CLIENT_NOT_FOUND": "Viðskiptavinur fannst ekki", "CLIENT_IS_ARCHIVED": "Í safni", "CLIENT_NO_DETAILS": "Engar samskiptaupplýsingar enn. Ýttu á Breyta til að bæta þeim við.", "CLIENT_JOBS": "Verk", "CLIENT_NO_JOBS": "Engin verk fyrir þennan viðskiptavin enn.", "ARCHIVE_CLIENT": "Setja viðskiptavin í safn", "ARCHIVE_CLIENT_TITLE": "Setja þennan viðskiptavin í safn?", "ARCHIVE_CLIENT_TEXT": "Viðskiptavinurinn á verk, svo hann er geymdur ásamt verkum sínum og reikningum. Þú getur endurheimt hann síðar.", "RESTORE_CLIENT": "Endurheimta viðskiptavin", "DELETE_CLIENT": "Eyða viðskiptavini", "DELETE_CLIENT_TITLE": "Eyða þessum viðskiptavini?", "DELETE_CLIENT_TEXT": "{name} verður fjarlægður úr skránni þinni.", "NEW_ASSIGNMENT": "Nýtt verkefni", "NEW_ASSIGNMENT_INTRO": "Skráðu verk fyrir eigin viðskiptavin og semjið um verðið. Í samningnum geturðu bætt við áföngum, skráð tíma og gert reikning.", "PICK_CLIENT_INTRO": "Fyrir hvern er verkið?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Hvað var samið um, efni, allt sem viðskiptavinurinn ætti að vita", "START_DATE": "Upphafsdagur", "END_DATE": "Lokadagur", "END_BEFORE_START": "Lokadagurinn er á undan upphafsdeginum.", "STEPS_OPTIONAL_HINT": "Valfrjálst. Án áfanga er allt verkið einn áfangi.", "STEPS_SPLIT_HINT": "Hver áfangi er samþykktur sérstaklega. Upphæðirnar verða samanlagt að passa við verðið.", "STEPS_HOURLY_HINT": "Hver áfangi er samþykktur sérstaklega. Tímarnir eru skráðir á samninginn.", "STEP_TITLE": "Áfangi", "STEP_TITLE_PLACEHOLDER": "T.d. Niðurrif og frárennsli", "STEP_TITLE_REQUIRED": "Gefðu hverjum áfanga nafn.", "STEP_AMOUNT": "Upphæð (NOK)", "STEP_AMOUNT_REQUIRED": "Gefðu hverjum áfanga upphæð.", "STEP_DUE": "Skiladagur", "STEP_DESCRIPTION_PLACEHOLDER": "Hvað er innifalið í þessum áfanga", "STEPS_MUST_ADD_UP": "Áfangarnir verða samanlagt að vera {total}.", "STEPS_ADD_UP": "Áfangarnir passa við verðið ✓", "STEPS_REST": "Eftir að skipta: {rest}", "STEPS_TOTAL_MISMATCH": "Áfangarnir eru samanlagt {steps}, umsamið verð er {total}.", "REMOVE_STEP": "Fjarlægja áfanga", "ADD_STEP": "Bæta við áfanga", "ADD_STEP_INTRO": "Viðskiptavinurinn samþykkir hvern áfanga þegar honum er lokið.", "EDIT_STEP": "Breyta áfanga", "DELETE_STEP": "Eyða áfanga", "DELETE_STEP_TITLE": "Eyða þessum áfanga?", "DELETE_STEP_TEXT": "„{title}“ er fjarlægður af samningnum.", "STEP_STARTED_NO_DELETE": "Þessi áfangi er hafinn, svo hægt er að breyta honum en ekki eyða.", "CREATE_CONTRACT": "Búa til samning", "JOB_HAS_CONTRACT": "Þetta verk er þegar með samning.", "JOB_NOT_YOURS": "Aðeins sá sem stofnaði verkið getur breytt því.", "JOB_CANNOT_EDIT": "Einhver hefur þegar verið ráðinn, svo ekki er lengur hægt að breyta verkinu.", "EDIT_JOB": "Breyta verki", "EDIT_JOB_INTRO": "Fagfólk sér breytingarnar strax.", "EDIT_JOB_WITH_OFFERS": "Tilboð móttekin: {n}. Segðu fagfólkinu frá stórum breytingum í spjallinu, svo tilboðin þeirra passi enn.", "CREATED_AGO": "Stofnað {time}", "DRAFT_NOT_VISIBLE": "Þetta eru drög. Fagfólk sér þau ekki fyrr en þú birtir þau.", "CANCEL_JOB": "Aflýsa verki", "CANCEL_JOB_TITLE": "Aflýsa þessu verki?", "CANCEL_JOB_TEXT": "Verkið er tekið niður og ekki er hægt að opna það aftur.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Verkið er tekið niður og fagfólkið sem sendi tilboð ({n}) fær að vita að því hafi verið aflýst.", "DELETE_JOB_TITLE": "Eyða drögunum?", "DELETE_JOB_TEXT": "Drögunum er eytt varanlega.", "CANCEL_CONTRACT": "Rifta samningnum", "CANCEL_CONTRACT_INTRO": "Vinnan stöðvast hér. Samþykktir áfangar og reikningar halda sér og hinn aðilinn fær að vita af því.", "CANCEL_REASON": "Hvers vegna? (valfrjálst)", "CANCEL_REASON_PLACEHOLDER": "Nokkur orð sem þið sjáið bæði síðar", "CONTRACT_CANCELLED_ON": "Rift {date}", "COMPLETE_CLIENT_JOB_TEXT": "Allir áfangar eru samþykktir. Verkið er merkt sem lokið.", "SIGN_ON_SITE": "Viðskiptavinur undirritar", "SIGN_ON_SITE_INTRO": "Leyfðu viðskiptavininum að skoða verkið og skrifa undir með fingri á skjáinn. Þetta samþykkir áfangann.", "CUSTOMER_NAME": "Nafn viðskiptavinar", "SIGNATURE": "Undirskrift", "SIGN_HERE": "Skrifaðu undir hér", "APPROVE_WITH_SIGNATURE": "Samþykkja með undirskrift", "CHANGE_PASSWORD": "Breyta lykilorði", "CHANGE_PASSWORD_INTRO": "Innskráningin hér helst. Aðrir símar og vafrar þínir eru skráðir út.", "CURRENT_PASSWORD": "Núverandi lykilorð", "CURRENT_PASSWORD_REQUIRED": "Sláðu inn núverandi lykilorð.", "CURRENT_PASSWORD_WRONG": "Þetta er ekki núverandi lykilorðið þitt.", "NEW_PASSWORD": "Nýtt lykilorð", "REPEAT_PASSWORD": "Endurtaktu nýja lykilorðið", "PASSWORDS_DONT_MATCH": "Lykilorðin passa ekki saman.", "PASSWORD_SAME_AS_OLD": "Veldu lykilorð sem þú hefur ekki notað hér.", "PASSWORD_CHANGED": "Lykilorði breytt", "PAYMENTS": "Greiðslur", "PAYMENT": "Greiðsla", "NO_PAYMENTS": "Engar greiðslur enn", "NO_PAYMENTS_TEXT": "Greiðslur í gegnum appið birtast hér. Verk sem greidd eru með reikningi eru undir Reikningar.", "PAYMENT_STATUS_PENDING": "Í bið", "PAYMENT_STATUS_HELD": "Í öruggri geymslu", "PAYMENT_STATUS_RELEASED": "Greitt út", "PAYMENT_STATUS_REFUNDED": "Endurgreitt", "PAYMENT_STATUS_FAILED": "Mistókst", "PLATFORM_FEE": "Gjald {fee}", "TEAM": "Teymi", "TEAM_ROW_HINT": "Fólkið sem vinnur hjá fyrirtækinu", "TEAM_MANAGE_HINT": "Samstarfsfólk þarf fyrst Qup Work-aðgang. Ýttu á einhvern til að breyta eða fjarlægja.", "TEAM_WORKER_HINT": "Eigandinn og stjórnendur bæta við og fjarlægja samstarfsfólk.", "ADD_MEMBER": "Bæta við samstarfsmanni", "ADD_MEMBER_INTRO": "Notaðu netfangið sem viðkomandi skráði sig með í Qup Work.", "MEMBER_NOT_FOUND": "Enginn hefur enn skráð sig með þessu netfangi. Biddu viðkomandi að stofna aðgang fyrst.", "MEMBER_ALREADY": "Viðkomandi er þegar í fyrirtækinu.", "ROLE": "Hlutverk", "ROLE_ADMIN_HINT": "Stjórnendur geta breytt upplýsingum fyrirtækisins og reikningsstillingum og bætt við samstarfsfólki.", "ROLE_WORKER_HINT": "Starfsmenn sjá verk fyrirtækisins, skrá tíma og vinna verkin.", "REMOVE_FROM_COMPANY": "Fjarlægja úr fyrirtækinu", "REMOVE_MEMBER_TITLE": "Fjarlægja úr fyrirtækinu?", "REMOVE_MEMBER_TEXT": "{name} sér ekki lengur verk og viðskiptavini fyrirtækisins.", "LEAVE_COMPANY": "Yfirgefa fyrirtækið", "LEAVE_COMPANY_TITLE": "Yfirgefa fyrirtækið?", "LEAVE_COMPANY_TEXT": "Þú sérð ekki lengur verk og viðskiptavini {name}.", "NOTIF_JOB_WITHDRAWN": "Viðskiptavinurinn aflýsti verkinu", "INVOICE_EMAILED_TO": "{email} hefur fengið reikninginn sem PDF.", "INVOICE_NO_EMAIL": "Sent, en ekki í tölvupósti: viðskiptavinurinn er ekki með netfang. Opnaðu PDF-skjalið og deildu því sjálf/ur, eða notaðu Senda í tölvupósti.", "INVOICE_EMAIL_NOT_SET_UP": "Sent, en ekki í tölvupósti: tölvupóstur hefur ekki verið settur upp á þjóninum (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Sent, en tölvupósturinn mistókst: {error}", "SEND_INVOICE_EMAIL_TO": "PDF-skjalið er sent í tölvupósti á {email}.", "SEND_INVOICE_NO_EMAIL": "Ekkert netfang er skráð, svo það verður ekki sent í tölvupósti. Þú getur deilt PDF-skjalinu sjálf/ur.", "EMAIL_INVOICE": "Senda í tölvupósti", "PREVIEW_PDF": "Forskoða PDF", "OPEN_PDF": "Opna PDF", "EMAILED": "Sent í tölvupósti", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Ekki sent í tölvupósti", "INVOICE_LANGUAGE": "Tungumál reiknings", "NOTIF_NEW_JOB_NEARBY": "Nýtt verk nálægt þér", "NOTIF_NEW_JOB_REMOTE": "Nýtt fjarverk", "NOTIF_JOB_INVITED": "Þér var boðið í verk", "NOTIF_JOB_IN_PLACE": "„{job}“ í {place}", "JOB_ALERTS": "Tilkynningar um ný verk", "JOB_ALERTS_ON_TEXT": "Þú færð tilkynningu þegar verk í þínum flokkum er birt á þínu svæði.", "JOB_ALERTS_OFF_TEXT": "Þú færð ekki tilkynningar um ný verk, en þú getur samt skoðað þau í appinu.", "JOB_ALERTS_NEEDS_VISIBLE": "Kveiktu fyrst á sýnileika. Aðeins fagfólk sem viðskiptavinir geta fundið fær tilkynningar um verk.", "FORGOT_PASSWORD": "Gleymdirðu lykilorðinu?", "FORGOT_PASSWORD_TITLE": "Nýtt lykilorð", "FORGOT_PASSWORD_INTRO": "Sláðu inn netfangið sem þú skráðir þig með og við sendum þér kóða.", "SEND_CODE": "Senda kóða", "RESET_CODE_SENT": "Ef {email} er með aðgang er 6 stafa kóði á leiðinni. Sláðu hann inn hér fyrir neðan ásamt nýju lykilorði.", "RESET_CODE": "Kóði úr tölvupóstinum", "RESET_CODE_INVALID": "Kóðinn er 6 tölustafir.", "RESET_CODE_WRONG": "Kóðinn er rangur eða útrunninn. Biddu um nýjan.", "SAVE_NEW_PASSWORD": "Vista og skrá inn", "RESET_CODE_AGAIN": "Senda nýjan kóða", "RESET_CODE_RESENT": "Nýr kóði sendur", "RESET_CODE_SPAM_HINT": "Enginn tölvupóstur eftir nokkrar mínútur? Athugaðu ruslpóstmöppuna.", "DELETE_ACCOUNT": "Eyða aðgangi", "DELETE_ACCOUNT_INTRO": "Þetta eyðir aðganginum fyrir {email}. Það er ekki hægt að afturkalla.", "DELETE_WHAT_GOES": "Eytt", "DELETE_GOES_PROFILE": "Nafnið þitt, mynd, sími og netfang", "DELETE_GOES_PRO": "Fagprófíllinn þinn, svo viðskiptavinir finna þig ekki lengur", "DELETE_GOES_JOBS": "Opin verk sem þú hefur birt og tilboð sem enginn hefur svarað", "DELETE_GOES_LOGIN": "Innskráningin þín, á öllum tækjum", "DELETE_WHAT_STAYS": "Varðveitt, án nafnsins þíns", "DELETE_STAYS_CONTRACTS": "Samningar sem er lokið, skilaboð og umsagnir, svo hinn aðilinn hafi þau áfram", "DELETE_STAYS_INVOICES": "Reikningar, sem norskar bókhaldsreglur krefjast að séu geymdir í 5 ár", "DELETE_PASSWORD_HINT": "Til að tryggja að þetta sért þú.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Eyða aðganginum þínum?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Þetta skráir þig út og þú getur ekki skráð þig inn með þessum aðgangi aftur.", "DELETE_BLOCKED_CONTRACTS": "Þú ert með samninga í gangi. Ljúktu þeim eða hættu við þá fyrst, svo hinn aðilinn sitji ekki og bíði.", "DELETE_BLOCKED_COMPANY": "Þú átt fyrirtæki með öðrum meðlimum. Fjarlægðu þá fyrst undir Teymi.", "JOB_CATEGORY_REQUIRED": "Veldu flokk svo rétta fagfólkið frétti af verkinu."}, "bg-BG": {"EDIT": "Редактирай", "REMOVE": "Премахни", "CLEAR": "Изчисти", "ARCHIVE": "Архивирай", "NOTES": "Бележки", "YOU": "ти", "DATE_PLACEHOLDER": "дд.мм.гггг", "DATE_INVALID": "Въведи датата като дд.мм.гггг.", "AMOUNT_INVALID": "Въведи сума в NOK, напр. 5000.", "EMAIL_INVALID": "Този имейл адрес не изглежда правилен.", "POSTCODE_FORMAT": "Пощенският код има 4 цифри.", "CLIENT": "Клиент", "CLIENTS": "Клиенти", "CLIENTS_PRO_ONLY": "Собственият регистър на клиенти е за майстори. Влез с профил на майстор, за да го използваш.", "SEARCH_CLIENTS": "Търси клиенти", "CLIENTS_ACTIVE": "Активни", "CLIENTS_ARCHIVED": "Архивирани", "NO_CLIENTS": "Все още няма клиенти", "NO_CLIENTS_TEXT": "Добави клиентите, за които работиш извън платформата, и дръж поръчките, часовете и фактурите им на едно място.", "NO_CLIENTS_MATCH": "Няма клиенти, които отговарят на търсенето.", "NO_ARCHIVED_CLIENTS": "Няма архивирани", "NO_ARCHIVED_CLIENTS_TEXT": "Клиентите, които архивираш, се озовават тук заедно със старите си поръчки и фактури.", "NEW_CLIENT": "Нов клиент", "EDIT_CLIENT": "Редактирай клиента", "SAVE_CLIENT": "Запази клиента", "CLIENT_FORM_INTRO": "Само ти и фирмата ти виждате това. Адресът се използва като място на работа при нови поръчки.", "CLIENT_TYPE": "Вид клиент", "CLIENT_PRIVATE": "Физическо лице", "CLIENT_BUSINESS": "Фирма", "CLIENT_COMPANY_PLACEHOLDER": "Напр. Bergen Eiendom AS", "CONTACT_PERSON": "Лице за контакт", "CONTACT_NAME": "Контакт: {name}", "CLIENT_EMAIL_HINT": "Фактурите могат да се изпращат тук.", "CLIENT_NOTES_PLACEHOLDER": "Код на портата, паркиране, името на кучето…", "CLIENT_NOTES_HINT": "Само за теб и колегите ти, никога не се показва на клиента.", "CLIENT_NOT_FOUND": "Клиентът не е намерен", "CLIENT_IS_ARCHIVED": "Архивиран", "CLIENT_NO_DETAILS": "Все още няма данни за контакт. Докосни „Редактирай“, за да ги добавиш.", "CLIENT_JOBS": "Поръчки", "CLIENT_NO_JOBS": "Все още няма поръчки за този клиент.", "ARCHIVE_CLIENT": "Архивирай клиента", "ARCHIVE_CLIENT_TITLE": "Да архивираш ли този клиент?", "ARCHIVE_CLIENT_TEXT": "Клиентът има поръчки, затова се запазва заедно с поръчките и фактурите си. Можеш да го възстановиш по-късно.", "RESTORE_CLIENT": "Възстанови клиента", "DELETE_CLIENT": "Изтрий клиента", "DELETE_CLIENT_TITLE": "Да изтриеш ли този клиент?", "DELETE_CLIENT_TEXT": "{name} се премахва от регистъра ти.", "NEW_ASSIGNMENT": "Нова поръчка", "NEW_ASSIGNMENT_INTRO": "Въведи работа за свой клиент и договорете цената. От договора можеш да добавяш етапи, да отчиташ часове и да фактурираш.", "PICK_CLIENT_INTRO": "За кого е работата?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Какво е договорено, материали, всичко, което клиентът трябва да знае", "START_DATE": "Начална дата", "END_DATE": "Крайна дата", "END_BEFORE_START": "Крайната дата е преди началната.", "STEPS_OPTIONAL_HINT": "По желание. Без етапи цялата поръчка е един етап.", "STEPS_SPLIT_HINT": "Всеки етап се одобрява отделно. Сумите трябва да дават общо цената.", "STEPS_HOURLY_HINT": "Всеки етап се одобрява отделно. Часовете се отчитат в договора.", "STEP_TITLE": "Етап", "STEP_TITLE_PLACEHOLDER": "Напр. Събаряне и отводняване", "STEP_TITLE_REQUIRED": "Дай име на всеки етап.", "STEP_AMOUNT": "Сума (NOK)", "STEP_AMOUNT_REQUIRED": "Въведи сума за всеки етап.", "STEP_DUE": "Срок", "STEP_DESCRIPTION_PLACEHOLDER": "Какво включва този етап", "STEPS_MUST_ADD_UP": "Етапите трябва да дават общо {total}.", "STEPS_ADD_UP": "Етапите дават общо цената ✓", "STEPS_REST": "Остава за разпределяне: {rest}", "STEPS_TOTAL_MISMATCH": "Етапите дават общо {steps}, а договорената цена е {total}.", "REMOVE_STEP": "Премахни етапа", "ADD_STEP": "Добави етап", "ADD_STEP_INTRO": "Клиентът одобрява всеки етап, когато е готов.", "EDIT_STEP": "Редактирай етапа", "DELETE_STEP": "Изтрий етапа", "DELETE_STEP_TITLE": "Да изтриеш ли този етап?", "DELETE_STEP_TEXT": "„{title}“ се премахва от договора.", "STEP_STARTED_NO_DELETE": "Този етап е започнат, затова може да се променя, но не и да се изтрие.", "CREATE_CONTRACT": "Създай договор", "JOB_HAS_CONTRACT": "Тази поръчка вече има договор.", "JOB_NOT_YOURS": "Само този, който е създал поръчката, може да я променя.", "JOB_CANNOT_EDIT": "Вече е нает някой, затова поръчката не може да се променя повече.", "EDIT_JOB": "Редактирай поръчката", "EDIT_JOB_INTRO": "Специалистите виждат промените веднага.", "EDIT_JOB_WITH_OFFERS": "Получени оферти: {n}. Кажи на специалистите за големи промени в чата, за да са офертите им още актуални.", "CREATED_AGO": "Създадена {time}", "DRAFT_NOT_VISIBLE": "Това е чернова. Специалистите не я виждат, докато не я публикуваш.", "CANCEL_JOB": "Отмени поръчката", "CANCEL_JOB_TITLE": "Да отмениш ли тази поръчка?", "CANCEL_JOB_TEXT": "Поръчката се сваля и не може да се отвори отново.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Поръчката се сваля, а специалистите, изпратили оферти ({n}), получават известие, че е отменена.", "DELETE_JOB_TITLE": "Да изтриеш ли черновата?", "DELETE_JOB_TEXT": "Черновата се изтрива завинаги.", "CANCEL_CONTRACT": "Прекрати договора", "CANCEL_CONTRACT_INTRO": "Работата спира дотук. Одобрените етапи и фактурите се запазват, а другата страна получава известие.", "CANCEL_REASON": "Защо? (по желание)", "CANCEL_REASON_PLACEHOLDER": "Няколко думи, които и двамата ще виждате после", "CONTRACT_CANCELLED_ON": "Прекратен на {date}", "COMPLETE_CLIENT_JOB_TEXT": "Всички етапи са одобрени. Поръчката се отбелязва като приключена.", "SIGN_ON_SITE": "Клиентът подписва", "SIGN_ON_SITE_INTRO": "Нека клиентът провери работата и се подпише с пръст на екрана. Така етапът се одобрява.", "CUSTOMER_NAME": "Име на клиента", "SIGNATURE": "Подпис", "SIGN_HERE": "Подпиши тук", "APPROVE_WITH_SIGNATURE": "Одобри с подпис", "CHANGE_PASSWORD": "Смени паролата", "CHANGE_PASSWORD_INTRO": "Тук оставаш влязъл. От другите си телефони и браузъри излизаш.", "CURRENT_PASSWORD": "Текуща парола", "CURRENT_PASSWORD_REQUIRED": "Въведи текущата си парола.", "CURRENT_PASSWORD_WRONG": "Това не е текущата ти парола.", "NEW_PASSWORD": "Нова парола", "REPEAT_PASSWORD": "Повтори новата парола", "PASSWORDS_DONT_MATCH": "Паролите не съвпадат.", "PASSWORD_SAME_AS_OLD": "Избери парола, която не си използвал тук.", "PASSWORD_CHANGED": "Паролата е сменена", "PAYMENTS": "Плащания", "PAYMENT": "Плащане", "NO_PAYMENTS": "Все още няма плащания", "NO_PAYMENTS_TEXT": "Тук се показват плащанията през приложението. Поръчките, платени с фактура, са във „Фактури“.", "PAYMENT_STATUS_PENDING": "Чака", "PAYMENT_STATUS_HELD": "Пази се сигурно", "PAYMENT_STATUS_RELEASED": "Изплатено", "PAYMENT_STATUS_REFUNDED": "Възстановено", "PAYMENT_STATUS_FAILED": "Неуспешно", "PLATFORM_FEE": "Такса {fee}", "TEAM": "Екип", "TEAM_ROW_HINT": "Хората, които работят във фирмата", "TEAM_MANAGE_HINT": "Колегите първо трябва да имат профил в Qup Work. Докосни някого, за да го промениш или премахнеш.", "TEAM_WORKER_HINT": "Собственикът и администраторите добавят и премахват колеги.", "ADD_MEMBER": "Добави колега", "ADD_MEMBER_INTRO": "Използвай имейла, с който човекът се е регистрирал в Qup Work.", "MEMBER_NOT_FOUND": "Все още никой не се е регистрирал с този имейл. Помоли човека първо да си създаде профил.", "MEMBER_ALREADY": "Този човек вече е във фирмата.", "ROLE": "Роля", "ROLE_ADMIN_HINT": "Администраторите могат да променят данните на фирмата и настройките на фактурите, както и да добавят колеги.", "ROLE_WORKER_HINT": "Служителите виждат поръчките на фирмата, отчитат часове и вършат работата.", "REMOVE_FROM_COMPANY": "Премахни от фирмата", "REMOVE_MEMBER_TITLE": "Да премахнеш ли от фирмата?", "REMOVE_MEMBER_TEXT": "{name} вече няма да вижда поръчките и клиентите на фирмата.", "LEAVE_COMPANY": "Напусни фирмата", "LEAVE_COMPANY_TITLE": "Да напуснеш ли фирмата?", "LEAVE_COMPANY_TEXT": "Вече няма да виждаш поръчките и клиентите на {name}.", "NOTIF_JOB_WITHDRAWN": "Клиентът отмени поръчката", "INVOICE_EMAILED_TO": "{email} получи фактурата като PDF.", "INVOICE_NO_EMAIL": "Изпратена, но не по имейл: клиентът няма имейл адрес. Отвори PDF файла и го сподели сам или използвай Изпрати по имейл.", "INVOICE_EMAIL_NOT_SET_UP": "Изпратена, но не по имейл: имейлът още не е настроен на сървъра (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Изпратена, но имейлът не успя: {error}", "SEND_INVOICE_EMAIL_TO": "PDF файлът се изпраща по имейл до {email}.", "SEND_INVOICE_NO_EMAIL": "Няма имейл адрес, затова няма да бъде изпратена по имейл. Можеш сам да споделиш PDF файла.", "EMAIL_INVOICE": "Изпрати по имейл", "PREVIEW_PDF": "Преглед на PDF", "OPEN_PDF": "Отвори PDF", "EMAILED": "Изпратена по имейл", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Не е изпратена по имейл", "INVOICE_LANGUAGE": "Език на фактурата", "NOTIF_NEW_JOB_NEARBY": "Нова поръчка близо до теб", "NOTIF_NEW_JOB_REMOTE": "Нова дистанционна поръчка", "NOTIF_JOB_INVITED": "Покани те за поръчка", "NOTIF_JOB_IN_PLACE": "„{job}“ – {place}", "JOB_ALERTS": "Известия за нови поръчки", "JOB_ALERTS_ON_TEXT": "Получаваш известие, когато в района ти се публикува поръчка от твоите категории.", "JOB_ALERTS_OFF_TEXT": "Няма да получаваш известия за нови поръчки, но все още ги виждаш в приложението.", "JOB_ALERTS_NEEDS_VISIBLE": "Първо включи видимостта. Известия получават само майстори, които клиентите могат да намерят.", "FORGOT_PASSWORD": "Забрави паролата си?", "FORGOT_PASSWORD_TITLE": "Нова парола", "FORGOT_PASSWORD_INTRO": "Въведи имейла, с който си се регистрирал, и ще ти изпратим код.", "SEND_CODE": "Изпрати код", "RESET_CODE_SENT": "Ако {email} има профил, 6-цифрен код е на път. Въведи го по-долу заедно с нова парола.", "RESET_CODE": "Код от имейла", "RESET_CODE_INVALID": "Кодът има 6 цифри.", "RESET_CODE_WRONG": "Кодът е грешен или е изтекъл. Поискай нов.", "SAVE_NEW_PASSWORD": "Запази и влез", "RESET_CODE_AGAIN": "Изпрати нов код", "RESET_CODE_RESENT": "Изпратен е нов код", "RESET_CODE_SPAM_HINT": "Няма имейл след няколко минути? Провери папката за спам.", "DELETE_ACCOUNT": "Изтрий профила", "DELETE_ACCOUNT_INTRO": "Това изтрива профила на {email}. Действието е необратимо.", "DELETE_WHAT_GOES": "Изтрива се", "DELETE_GOES_PROFILE": "Името, снимката, телефонът и имейлът ти", "DELETE_GOES_PRO": "Профилът ти на майстор, така че клиентите вече няма да могат да те намерят", "DELETE_GOES_JOBS": "Отворените поръчки, които си публикувал, и офертите, на които никой не е отговорил", "DELETE_GOES_LOGIN": "Данните ти за вход, на всички устройства", "DELETE_WHAT_STAYS": "Запазва се, без името ти", "DELETE_STAYS_CONTRACTS": "Приключените договори, съобщения и отзиви, за да ги има и другата страна", "DELETE_STAYS_INVOICES": "Фактурите, които норвежките счетоводни правила изискват да се пазят 5 години", "DELETE_PASSWORD_HINT": "За да сме сигурни, че си ти.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Да изтрием ли профила ти?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Ще излезеш от профила си и няма да можеш да влезеш с него отново.", "DELETE_BLOCKED_CONTRACTS": "Имаш текущи договори. Първо ги завърши или откажи, за да не чака другата страна.", "DELETE_BLOCKED_COMPANY": "Притежаваш фирма с други членове. Първо ги премахни от Екип.", "JOB_CATEGORY_REQUIRED": "Избери категория, за да научат за поръчката подходящите майстори."}, "el-GR": {"EDIT": "Επεξεργασία", "REMOVE": "Αφαίρεση", "CLEAR": "Εκκαθάριση", "ARCHIVE": "Αρχειοθέτηση", "NOTES": "Σημειώσεις", "YOU": "εσύ", "DATE_PLACEHOLDER": "ηη/μμ/εεεε", "DATE_INVALID": "Γράψε την ημερομηνία ως ηη/μμ/εεεε.", "AMOUNT_INVALID": "Γράψε ένα ποσό σε NOK, π.χ. 5000.", "EMAIL_INVALID": "Αυτή η διεύθυνση email δεν φαίνεται σωστή.", "POSTCODE_FORMAT": "Ο ταχυδρομικός κώδικας έχει 4 ψηφία.", "CLIENT": "Πελάτης", "CLIENTS": "Πελάτες", "CLIENTS_PRO_ONLY": "Το δικό σου πελατολόγιο είναι για επαγγελματίες. Συνδέσου με λογαριασμό επαγγελματία για να το χρησιμοποιήσεις.", "SEARCH_CLIENTS": "Αναζήτηση πελατών", "CLIENTS_ACTIVE": "Ενεργοί", "CLIENTS_ARCHIVED": "Αρχειοθετημένοι", "NO_CLIENTS": "Δεν υπάρχουν ακόμη πελάτες", "NO_CLIENTS_TEXT": "Πρόσθεσε τους πελάτες για τους οποίους δουλεύεις εκτός πλατφόρμας και κράτα εργασίες, ώρες και τιμολόγια σε ένα σημείο.", "NO_CLIENTS_MATCH": "Κανένας πελάτης δεν ταιριάζει με την αναζήτησή σου.", "NO_ARCHIVED_CLIENTS": "Τίποτα αρχειοθετημένο", "NO_ARCHIVED_CLIENTS_TEXT": "Οι πελάτες που αρχειοθετείς καταλήγουν εδώ, μαζί με τις παλιές εργασίες και τα τιμολόγιά τους.", "NEW_CLIENT": "Νέος πελάτης", "EDIT_CLIENT": "Επεξεργασία πελάτη", "SAVE_CLIENT": "Αποθήκευση πελάτη", "CLIENT_FORM_INTRO": "Αυτό το βλέπεις μόνο εσύ και η εταιρεία σου. Η διεύθυνση χρησιμοποιείται ως τόπος εργασίας στις νέες εργασίες.", "CLIENT_TYPE": "Τύπος πελάτη", "CLIENT_PRIVATE": "Ιδιώτης", "CLIENT_BUSINESS": "Επιχείρηση", "CLIENT_COMPANY_PLACEHOLDER": "Π.χ. Bergen Eiendom AS", "CONTACT_PERSON": "Υπεύθυνος επικοινωνίας", "CONTACT_NAME": "Επαφή: {name}", "CLIENT_EMAIL_HINT": "Τα τιμολόγια μπορούν να σταλούν εδώ.", "CLIENT_NOTES_PLACEHOLDER": "Κωδικός πόρτας, στάθμευση, το όνομα του σκύλου…", "CLIENT_NOTES_HINT": "Μόνο για σένα και τους συναδέλφους σου, δεν εμφανίζεται ποτέ στον πελάτη.", "CLIENT_NOT_FOUND": "Ο πελάτης δεν βρέθηκε", "CLIENT_IS_ARCHIVED": "Αρχειοθετημένος", "CLIENT_NO_DETAILS": "Δεν υπάρχουν ακόμη στοιχεία επικοινωνίας. Πάτησε Επεξεργασία για να τα προσθέσεις.", "CLIENT_JOBS": "Εργασίες", "CLIENT_NO_JOBS": "Δεν υπάρχουν ακόμη εργασίες για αυτόν τον πελάτη.", "ARCHIVE_CLIENT": "Αρχειοθέτηση πελάτη", "ARCHIVE_CLIENT_TITLE": "Αρχειοθέτηση αυτού του πελάτη;", "ARCHIVE_CLIENT_TEXT": "Ο πελάτης έχει εργασίες, οπότε διατηρείται μαζί με τις εργασίες και τα τιμολόγιά του. Μπορείς να τον επαναφέρεις αργότερα.", "RESTORE_CLIENT": "Επαναφορά πελάτη", "DELETE_CLIENT": "Διαγραφή πελάτη", "DELETE_CLIENT_TITLE": "Διαγραφή αυτού του πελάτη;", "DELETE_CLIENT_TEXT": "Ο/Η {name} αφαιρείται από το πελατολόγιό σου.", "NEW_ASSIGNMENT": "Νέα εργασία", "NEW_ASSIGNMENT_INTRO": "Κατάγραψε δουλειά για δικό σου πελάτη και συμφώνησε την τιμή. Από το συμβόλαιο μπορείς να προσθέσεις βήματα, να καταγράψεις ώρες και να τιμολογήσεις.", "PICK_CLIENT_INTRO": "Για ποιον είναι η δουλειά;", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Τι συμφωνήθηκε, υλικά, ό,τι πρέπει να ξέρει ο πελάτης", "START_DATE": "Ημερομηνία έναρξης", "END_DATE": "Ημερομηνία λήξης", "END_BEFORE_START": "Η ημερομηνία λήξης είναι πριν από την ημερομηνία έναρξης.", "STEPS_OPTIONAL_HINT": "Προαιρετικό. Χωρίς βήματα, όλη η εργασία είναι ένα βήμα.", "STEPS_SPLIT_HINT": "Κάθε βήμα εγκρίνεται χωριστά. Τα ποσά πρέπει να αθροίζουν την τιμή.", "STEPS_HOURLY_HINT": "Κάθε βήμα εγκρίνεται χωριστά. Οι ώρες καταγράφονται στο συμβόλαιο.", "STEP_TITLE": "Βήμα", "STEP_TITLE_PLACEHOLDER": "Π.χ. Καθαιρέσεις και αποχέτευση", "STEP_TITLE_REQUIRED": "Δώσε όνομα σε κάθε βήμα.", "STEP_AMOUNT": "Ποσό (NOK)", "STEP_AMOUNT_REQUIRED": "Δώσε ποσό σε κάθε βήμα.", "STEP_DUE": "Προθεσμία", "STEP_DESCRIPTION_PLACEHOLDER": "Τι περιλαμβάνει αυτό το βήμα", "STEPS_MUST_ADD_UP": "Τα βήματα πρέπει να αθροίζουν {total}.", "STEPS_ADD_UP": "Τα βήματα αθροίζουν την τιμή ✓", "STEPS_REST": "Απομένει να μοιραστεί: {rest}", "STEPS_TOTAL_MISMATCH": "Τα βήματα αθροίζουν {steps}, η συμφωνημένη τιμή είναι {total}.", "REMOVE_STEP": "Αφαίρεση βήματος", "ADD_STEP": "Προσθήκη βήματος", "ADD_STEP_INTRO": "Ο πελάτης εγκρίνει κάθε βήμα όταν ολοκληρωθεί.", "EDIT_STEP": "Επεξεργασία βήματος", "DELETE_STEP": "Διαγραφή βήματος", "DELETE_STEP_TITLE": "Διαγραφή αυτού του βήματος;", "DELETE_STEP_TEXT": "Το «{title}» αφαιρείται από το συμβόλαιο.", "STEP_STARTED_NO_DELETE": "Αυτό το βήμα έχει ξεκινήσει, οπότε μπορεί να αλλάξει αλλά όχι να διαγραφεί.", "CREATE_CONTRACT": "Δημιουργία συμβολαίου", "JOB_HAS_CONTRACT": "Αυτή η εργασία έχει ήδη συμβόλαιο.", "JOB_NOT_YOURS": "Μόνο όποιος δημιούργησε την εργασία μπορεί να την αλλάξει.", "JOB_CANNOT_EDIT": "Έχει ήδη προσληφθεί κάποιος, οπότε η εργασία δεν μπορεί πια να αλλάξει.", "EDIT_JOB": "Επεξεργασία εργασίας", "EDIT_JOB_INTRO": "Οι επαγγελματίες βλέπουν τις αλλαγές αμέσως.", "EDIT_JOB_WITH_OFFERS": "Ληφθείσες προσφορές: {n}. Ενημέρωσε τους επαγγελματίες στη συνομιλία για μεγάλες αλλαγές, ώστε οι προσφορές τους να ισχύουν ακόμα.", "CREATED_AGO": "Δημιουργήθηκε {time}", "DRAFT_NOT_VISIBLE": "Αυτό είναι πρόχειρο. Οι επαγγελματίες δεν το βλέπουν μέχρι να το δημοσιεύσεις.", "CANCEL_JOB": "Ακύρωση εργασίας", "CANCEL_JOB_TITLE": "Ακύρωση αυτής της εργασίας;", "CANCEL_JOB_TEXT": "Η εργασία αποσύρεται και δεν μπορεί να ανοίξει ξανά.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Η εργασία αποσύρεται και οι επαγγελματίες που έστειλαν προσφορές ({n}) ενημερώνονται ότι ακυρώθηκε.", "DELETE_JOB_TITLE": "Διαγραφή του πρόχειρου;", "DELETE_JOB_TEXT": "Το πρόχειρο διαγράφεται οριστικά.", "CANCEL_CONTRACT": "Ακύρωση του συμβολαίου", "CANCEL_CONTRACT_INTRO": "Η δουλειά σταματά εδώ. Τα εγκεκριμένα βήματα και τα τιμολόγια διατηρούνται και η άλλη πλευρά ενημερώνεται.", "CANCEL_REASON": "Γιατί; (προαιρετικό)", "CANCEL_REASON_PLACEHOLDER": "Λίγα λόγια που θα βλέπετε και οι δύο αργότερα", "CONTRACT_CANCELLED_ON": "Ακυρώθηκε στις {date}", "COMPLETE_CLIENT_JOB_TEXT": "Όλα τα βήματα έχουν εγκριθεί. Η εργασία σημειώνεται ως ολοκληρωμένη.", "SIGN_ON_SITE": "Υπογραφή πελάτη", "SIGN_ON_SITE_INTRO": "Άφησε τον πελάτη να ελέγξει τη δουλειά και να υπογράψει με το δάχτυλο στην οθόνη. Έτσι εγκρίνεται το βήμα.", "CUSTOMER_NAME": "Όνομα πελάτη", "SIGNATURE": "Υπογραφή", "SIGN_HERE": "Υπόγραψε εδώ", "APPROVE_WITH_SIGNATURE": "Έγκριση με υπογραφή", "CHANGE_PASSWORD": "Αλλαγή κωδικού πρόσβασης", "CHANGE_PASSWORD_INTRO": "Εδώ παραμένεις συνδεδεμένος. Στα άλλα τηλέφωνα και προγράμματα περιήγησης αποσυνδέεσαι.", "CURRENT_PASSWORD": "Τρέχων κωδικός πρόσβασης", "CURRENT_PASSWORD_REQUIRED": "Γράψε τον τρέχοντα κωδικό πρόσβασης.", "CURRENT_PASSWORD_WRONG": "Αυτός δεν είναι ο τρέχων κωδικός σου.", "NEW_PASSWORD": "Νέος κωδικός πρόσβασης", "REPEAT_PASSWORD": "Επανάληψη νέου κωδικού", "PASSWORDS_DONT_MATCH": "Οι κωδικοί δεν ταιριάζουν.", "PASSWORD_SAME_AS_OLD": "Διάλεξε έναν κωδικό που δεν έχεις χρησιμοποιήσει εδώ.", "PASSWORD_CHANGED": "Ο κωδικός άλλαξε", "PAYMENTS": "Πληρωμές", "PAYMENT": "Πληρωμή", "NO_PAYMENTS": "Δεν υπάρχουν ακόμη πληρωμές", "NO_PAYMENTS_TEXT": "Οι πληρωμές μέσω της εφαρμογής εμφανίζονται εδώ. Οι εργασίες που πληρώνονται με τιμολόγιο βρίσκονται στα Τιμολόγια.", "PAYMENT_STATUS_PENDING": "Σε αναμονή", "PAYMENT_STATUS_HELD": "Σε ασφαλή φύλαξη", "PAYMENT_STATUS_RELEASED": "Εκταμιεύτηκε", "PAYMENT_STATUS_REFUNDED": "Επιστράφηκε", "PAYMENT_STATUS_FAILED": "Απέτυχε", "PLATFORM_FEE": "Χρέωση {fee}", "TEAM": "Ομάδα", "TEAM_ROW_HINT": "Οι άνθρωποι που δουλεύουν στην εταιρεία", "TEAM_MANAGE_HINT": "Οι συνάδελφοι χρειάζονται πρώτα λογαριασμό Qup Work. Πάτησε σε κάποιον για να τον αλλάξεις ή να τον αφαιρέσεις.", "TEAM_WORKER_HINT": "Ο ιδιοκτήτης και οι διαχειριστές προσθέτουν και αφαιρούν συναδέλφους.", "ADD_MEMBER": "Προσθήκη συναδέλφου", "ADD_MEMBER_INTRO": "Χρησιμοποίησε το email με το οποίο έχει εγγραφεί στο Qup Work.", "MEMBER_NOT_FOUND": "Δεν έχει εγγραφεί ακόμη κανείς με αυτό το email. Ζήτησέ του να δημιουργήσει πρώτα λογαριασμό.", "MEMBER_ALREADY": "Αυτό το άτομο είναι ήδη στην εταιρεία.", "ROLE": "Ρόλος", "ROLE_ADMIN_HINT": "Οι διαχειριστές μπορούν να αλλάζουν τα στοιχεία της εταιρείας και τις ρυθμίσεις τιμολογίων, και να προσθέτουν συναδέλφους.", "ROLE_WORKER_HINT": "Οι υπάλληλοι βλέπουν τις εργασίες της εταιρείας, καταγράφουν ώρες και κάνουν τη δουλειά.", "REMOVE_FROM_COMPANY": "Αφαίρεση από την εταιρεία", "REMOVE_MEMBER_TITLE": "Αφαίρεση από την εταιρεία;", "REMOVE_MEMBER_TEXT": "Ο/Η {name} δεν βλέπει πλέον τις εργασίες και τους πελάτες της εταιρείας.", "LEAVE_COMPANY": "Αποχώρηση από την εταιρεία", "LEAVE_COMPANY_TITLE": "Αποχώρηση από την εταιρεία;", "LEAVE_COMPANY_TEXT": "Δεν θα βλέπεις πλέον τις εργασίες και τους πελάτες της εταιρείας {name}.", "NOTIF_JOB_WITHDRAWN": "Ο πελάτης ακύρωσε την εργασία", "INVOICE_EMAILED_TO": "Ο/Η {email} έλαβε το τιμολόγιο σε PDF.", "INVOICE_NO_EMAIL": "Στάλθηκε, αλλά όχι με email: ο πελάτης δεν έχει διεύθυνση email. Άνοιξε το PDF και μοιράσου το μόνος σου ή χρησιμοποίησε Αποστολή με email.", "INVOICE_EMAIL_NOT_SET_UP": "Στάλθηκε, αλλά όχι με email: το email δεν έχει ρυθμιστεί ακόμη στον διακομιστή (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Στάλθηκε, αλλά το email απέτυχε: {error}", "SEND_INVOICE_EMAIL_TO": "Το PDF αποστέλλεται με email στο {email}.", "SEND_INVOICE_NO_EMAIL": "Δεν υπάρχει διεύθυνση email, οπότε δεν θα σταλεί με email. Μπορείς να μοιραστείς το PDF μόνος σου.", "EMAIL_INVOICE": "Αποστολή με email", "PREVIEW_PDF": "Προεπισκόπηση PDF", "OPEN_PDF": "Άνοιγμα PDF", "EMAILED": "Στάλθηκε με email", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Δεν στάλθηκε με email", "INVOICE_LANGUAGE": "Γλώσσα τιμολογίου", "NOTIF_NEW_JOB_NEARBY": "Νέα εργασία κοντά σου", "NOTIF_NEW_JOB_REMOTE": "Νέα εργασία εξ αποστάσεως", "NOTIF_JOB_INVITED": "Σε προσκάλεσαν σε μια εργασία", "NOTIF_JOB_IN_PLACE": "«{job}» – {place}", "JOB_ALERTS": "Ειδοποιήσεις για νέες εργασίες", "JOB_ALERTS_ON_TEXT": "Λαμβάνεις ειδοποίηση όταν δημοσιεύεται εργασία στις κατηγορίες σου στην περιοχή σου.", "JOB_ALERTS_OFF_TEXT": "Δεν θα ειδοποιείσαι για νέες εργασίες, αλλά θα τις βλέπεις ακόμα στην εφαρμογή.", "JOB_ALERTS_NEEDS_VISIBLE": "Ενεργοποίησε πρώτα την ορατότητα. Ειδοποιήσεις παίρνουν μόνο επαγγελματίες που μπορούν να βρουν οι πελάτες.", "FORGOT_PASSWORD": "Ξέχασες τον κωδικό πρόσβασης;", "FORGOT_PASSWORD_TITLE": "Νέος κωδικός πρόσβασης", "FORGOT_PASSWORD_INTRO": "Γράψε το email με το οποίο εγγράφηκες και θα σου στείλουμε έναν κωδικό.", "SEND_CODE": "Αποστολή κωδικού", "RESET_CODE_SENT": "Αν το {email} έχει λογαριασμό, ένας 6ψήφιος κωδικός είναι καθ’ οδόν. Γράψε τον παρακάτω μαζί με νέο κωδικό πρόσβασης.", "RESET_CODE": "Κωδικός από το email", "RESET_CODE_INVALID": "Ο κωδικός έχει 6 ψηφία.", "RESET_CODE_WRONG": "Ο κωδικός είναι λάθος ή έχει λήξει. Ζήτα νέο.", "SAVE_NEW_PASSWORD": "Αποθήκευση και σύνδεση", "RESET_CODE_AGAIN": "Αποστολή νέου κωδικού", "RESET_CODE_RESENT": "Στάλθηκε νέος κωδικός", "RESET_CODE_SPAM_HINT": "Δεν ήρθε email μετά από λίγα λεπτά; Έλεγξε τον φάκελο ανεπιθύμητων.", "DELETE_ACCOUNT": "Διαγραφή λογαριασμού", "DELETE_ACCOUNT_INTRO": "Αυτό διαγράφει τον λογαριασμό για το {email}. Δεν μπορεί να αναιρεθεί.", "DELETE_WHAT_GOES": "Διαγράφονται", "DELETE_GOES_PROFILE": "Το όνομα, η φωτογραφία, το τηλέφωνο και το email σου", "DELETE_GOES_PRO": "Το προφίλ επαγγελματία σου, ώστε οι πελάτες να μη σε βρίσκουν πια", "DELETE_GOES_JOBS": "Οι ανοιχτές εργασίες που δημοσίευσες και οι προσφορές που δεν απάντησε κανείς", "DELETE_GOES_LOGIN": "Η σύνδεσή σου, σε όλες τις συσκευές", "DELETE_WHAT_STAYS": "Διατηρούνται, χωρίς το όνομά σου", "DELETE_STAYS_CONTRACTS": "Τα ολοκληρωμένα συμβόλαια, μηνύματα και κριτικές, ώστε να τα έχει ακόμα η άλλη πλευρά", "DELETE_STAYS_INVOICES": "Τα τιμολόγια, που οι νορβηγικοί λογιστικοί κανόνες απαιτούν να φυλάσσονται για 5 χρόνια", "DELETE_PASSWORD_HINT": "Για να βεβαιωθούμε ότι είσαι εσύ.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Διαγραφή του λογαριασμού σου;", "DELETE_ACCOUNT_CONFIRM_TEXT": "Θα αποσυνδεθείς και δεν θα μπορείς να συνδεθείς ξανά με αυτόν τον λογαριασμό.", "DELETE_BLOCKED_CONTRACTS": "Έχεις συμβόλαια σε εξέλιξη. Ολοκλήρωσέ τα ή ακύρωσέ τα πρώτα, για να μην περιμένει η άλλη πλευρά.", "DELETE_BLOCKED_COMPANY": "Έχεις εταιρεία με άλλα μέλη. Αφαίρεσέ τα πρώτα από την Ομάδα.", "JOB_CATEGORY_REQUIRED": "Διάλεξε κατηγορία, ώστε να μάθουν για την εργασία οι κατάλληλοι επαγγελματίες."}, "ar-SA": {"EDIT": "تعديل", "REMOVE": "إزالة", "CLEAR": "مسح", "ARCHIVE": "أرشفة", "NOTES": "ملاحظات", "YOU": "أنت", "DATE_PLACEHOLDER": "يي/شش/سسسس", "DATE_INVALID": "اكتب التاريخ بالصيغة يي/شش/سسسس.", "AMOUNT_INVALID": "اكتب مبلغًا بالكرونة النرويجية (NOK)، مثل 5000.", "EMAIL_INVALID": "يبدو أن عنوان البريد الإلكتروني غير صحيح.", "POSTCODE_FORMAT": "يتكوّن الرمز البريدي من 4 أرقام.", "CLIENT": "العميل", "CLIENTS": "العملاء", "CLIENTS_PRO_ONLY": "سجل العملاء الخاص بك مخصّص للمحترفين. سجّل الدخول بحساب محترف لاستخدامه.", "SEARCH_CLIENTS": "ابحث في العملاء", "CLIENTS_ACTIVE": "نشطون", "CLIENTS_ARCHIVED": "مؤرشفون", "NO_CLIENTS": "لا يوجد عملاء بعد", "NO_CLIENTS_TEXT": "أضف العملاء الذين تعمل لهم خارج المنصة، واحتفظ بمهامهم وساعاتهم وفواتيرهم في مكان واحد.", "NO_CLIENTS_MATCH": "لا يوجد عملاء يطابقون بحثك.", "NO_ARCHIVED_CLIENTS": "لا شيء مؤرشف", "NO_ARCHIVED_CLIENTS_TEXT": "العملاء الذين تؤرشفهم ينتقلون إلى هنا، مع مهامهم وفواتيرهم القديمة.", "NEW_CLIENT": "عميل جديد", "EDIT_CLIENT": "تعديل العميل", "SAVE_CLIENT": "حفظ العميل", "CLIENT_FORM_INTRO": "لا يرى هذا إلا أنت وشركتك. يُستخدم العنوان كمكان للعمل في المهام الجديدة.", "CLIENT_TYPE": "نوع العميل", "CLIENT_PRIVATE": "فرد", "CLIENT_BUSINESS": "شركة", "CLIENT_COMPANY_PLACEHOLDER": "مثل Bergen Eiendom AS", "CONTACT_PERSON": "جهة الاتصال", "CONTACT_NAME": "جهة الاتصال: {name}", "CLIENT_EMAIL_HINT": "يمكن إرسال الفواتير إلى هنا.", "CLIENT_NOTES_PLACEHOLDER": "رمز البوابة، الموقف، اسم الكلب…", "CLIENT_NOTES_HINT": "لك ولزملائك فقط، ولا تظهر للعميل أبدًا.", "CLIENT_NOT_FOUND": "لم يتم العثور على العميل", "CLIENT_IS_ARCHIVED": "مؤرشف", "CLIENT_NO_DETAILS": "لا توجد بيانات اتصال بعد. اضغط على «تعديل» لإضافتها.", "CLIENT_JOBS": "المهام", "CLIENT_NO_JOBS": "لا توجد مهام لهذا العميل بعد.", "ARCHIVE_CLIENT": "أرشفة العميل", "ARCHIVE_CLIENT_TITLE": "أرشفة هذا العميل؟", "ARCHIVE_CLIENT_TEXT": "لدى العميل مهام، لذا يُحتفظ به مع مهامه وفواتيره. يمكنك استعادته لاحقًا.", "RESTORE_CLIENT": "استعادة العميل", "DELETE_CLIENT": "حذف العميل", "DELETE_CLIENT_TITLE": "حذف هذا العميل؟", "DELETE_CLIENT_TEXT": "ستتم إزالة {name} من سجل عملائك.", "NEW_ASSIGNMENT": "عمل جديد", "NEW_ASSIGNMENT_INTRO": "سجّل عملًا لعميلك الخاص واتفق على السعر. يمكنك إضافة مراحل وتسجيل الساعات وإصدار الفواتير من العقد.", "PICK_CLIENT_INTRO": "لمن هذا العمل؟", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "ما تم الاتفاق عليه، المواد، وأي شيء يجب أن يعرفه العميل", "START_DATE": "تاريخ البدء", "END_DATE": "تاريخ الانتهاء", "END_BEFORE_START": "تاريخ الانتهاء يسبق تاريخ البدء.", "STEPS_OPTIONAL_HINT": "اختياري. بدون مراحل تكون المهمة كلها مرحلة واحدة.", "STEPS_SPLIT_HINT": "تُعتمد كل مرحلة على حدة. يجب أن يساوي مجموع المبالغ السعر.", "STEPS_HOURLY_HINT": "تُعتمد كل مرحلة على حدة. تُسجَّل الساعات على العقد.", "STEP_TITLE": "المرحلة", "STEP_TITLE_PLACEHOLDER": "مثل الهدم والتصريف", "STEP_TITLE_REQUIRED": "أعطِ كل مرحلة اسمًا.", "STEP_AMOUNT": "المبلغ (NOK)", "STEP_AMOUNT_REQUIRED": "أعطِ كل مرحلة مبلغًا.", "STEP_DUE": "الموعد النهائي", "STEP_DESCRIPTION_PLACEHOLDER": "ما الذي تشمله هذه المرحلة", "STEPS_MUST_ADD_UP": "يجب أن يساوي مجموع المراحل {total}.", "STEPS_ADD_UP": "مجموع المراحل يساوي السعر ✓", "STEPS_REST": "المتبقي للتوزيع: {rest}", "STEPS_TOTAL_MISMATCH": "مجموع المراحل {steps}، والسعر المتفق عليه {total}.", "REMOVE_STEP": "إزالة المرحلة", "ADD_STEP": "إضافة مرحلة", "ADD_STEP_INTRO": "يعتمد العميل كل مرحلة عند إنجازها.", "EDIT_STEP": "تعديل المرحلة", "DELETE_STEP": "حذف المرحلة", "DELETE_STEP_TITLE": "حذف هذه المرحلة؟", "DELETE_STEP_TEXT": "ستتم إزالة «{title}» من العقد.", "STEP_STARTED_NO_DELETE": "بدأت هذه المرحلة، لذا يمكن تعديلها لكن لا يمكن حذفها.", "CREATE_CONTRACT": "إنشاء عقد", "JOB_HAS_CONTRACT": "لهذه المهمة عقد بالفعل.", "JOB_NOT_YOURS": "لا يمكن تعديل المهمة إلا لمن أنشأها.", "JOB_CANNOT_EDIT": "تم تكليف شخص بالفعل، لذا لم يعد بالإمكان تعديل المهمة.", "EDIT_JOB": "تعديل المهمة", "EDIT_JOB_INTRO": "يرى المحترفون التغييرات فورًا.", "EDIT_JOB_WITH_OFFERS": "العروض المستلمة: {n}. أخبر المحترفين بالتغييرات الكبيرة في المحادثة حتى تظل عروضهم مناسبة.", "CREATED_AGO": "أُنشئت {time}", "DRAFT_NOT_VISIBLE": "هذه مسودة. لا يراها المحترفون حتى تنشرها.", "CANCEL_JOB": "إلغاء المهمة", "CANCEL_JOB_TITLE": "إلغاء هذه المهمة؟", "CANCEL_JOB_TEXT": "ستُزال المهمة ولا يمكن إعادة فتحها.", "CANCEL_JOB_WITH_OFFERS_TEXT": "ستُزال المهمة، وسيتم إبلاغ المحترفين الذين أرسلوا عروضًا ({n}) بإلغائها.", "DELETE_JOB_TITLE": "حذف المسودة؟", "DELETE_JOB_TEXT": "ستُحذف المسودة نهائيًا.", "CANCEL_CONTRACT": "إلغاء العقد", "CANCEL_CONTRACT_INTRO": "يتوقف العمل هنا. يُحتفظ بالمراحل المعتمدة والفواتير، ويتم إبلاغ الطرف الآخر.", "CANCEL_REASON": "لماذا؟ (اختياري)", "CANCEL_REASON_PLACEHOLDER": "بضع كلمات يمكن لكليكما رؤيتها لاحقًا", "CONTRACT_CANCELLED_ON": "أُلغي في {date}", "COMPLETE_CLIENT_JOB_TEXT": "تم اعتماد جميع المراحل. ستُعلَّم المهمة كمكتملة.", "SIGN_ON_SITE": "توقيع العميل", "SIGN_ON_SITE_INTRO": "دع العميل يتحقق من العمل ويوقّع بإصبعه على الشاشة. هذا يعتمد المرحلة.", "CUSTOMER_NAME": "اسم العميل", "SIGNATURE": "التوقيع", "SIGN_HERE": "وقّع هنا", "APPROVE_WITH_SIGNATURE": "اعتماد بالتوقيع", "CHANGE_PASSWORD": "تغيير كلمة المرور", "CHANGE_PASSWORD_INTRO": "ستبقى مسجّل الدخول هنا. سيتم تسجيل خروجك من هواتفك ومتصفحاتك الأخرى.", "CURRENT_PASSWORD": "كلمة المرور الحالية", "CURRENT_PASSWORD_REQUIRED": "أدخل كلمة المرور الحالية.", "CURRENT_PASSWORD_WRONG": "هذه ليست كلمة المرور الحالية.", "NEW_PASSWORD": "كلمة المرور الجديدة", "REPEAT_PASSWORD": "كرّر كلمة المرور الجديدة", "PASSWORDS_DONT_MATCH": "كلمتا المرور غير متطابقتين.", "PASSWORD_SAME_AS_OLD": "اختر كلمة مرور لم تستخدمها هنا من قبل.", "PASSWORD_CHANGED": "تم تغيير كلمة المرور", "PAYMENTS": "المدفوعات", "PAYMENT": "الدفعة", "NO_PAYMENTS": "لا توجد مدفوعات بعد", "NO_PAYMENTS_TEXT": "تظهر هنا المدفوعات التي تتم عبر التطبيق. المهام المدفوعة بفاتورة تجدها في «الفواتير».", "PAYMENT_STATUS_PENDING": "قيد الانتظار", "PAYMENT_STATUS_HELD": "محفوظة بأمان", "PAYMENT_STATUS_RELEASED": "تم صرفها", "PAYMENT_STATUS_REFUNDED": "مستردة", "PAYMENT_STATUS_FAILED": "فشلت", "PLATFORM_FEE": "الرسوم {fee}", "TEAM": "الفريق", "TEAM_ROW_HINT": "الأشخاص الذين يعملون في الشركة", "TEAM_MANAGE_HINT": "يحتاج الزملاء أولًا إلى حساب في Qup Work. اضغط على أي شخص لتعديله أو إزالته.", "TEAM_WORKER_HINT": "المالك والمسؤولون هم من يضيفون الزملاء ويزيلونهم.", "ADD_MEMBER": "إضافة زميل", "ADD_MEMBER_INTRO": "استخدم البريد الإلكتروني الذي سجّل به في Qup Work.", "MEMBER_NOT_FOUND": "لم يسجّل أحد بهذا البريد الإلكتروني بعد. اطلب منه إنشاء حساب أولًا.", "MEMBER_ALREADY": "هذا الشخص موجود في الشركة بالفعل.", "ROLE": "الدور", "ROLE_ADMIN_HINT": "يمكن للمسؤولين تغيير بيانات الشركة وإعدادات الفواتير وإضافة زملاء.", "ROLE_WORKER_HINT": "يرى الموظفون مهام الشركة ويسجّلون الساعات وينفّذون العمل.", "REMOVE_FROM_COMPANY": "إزالة من الشركة", "REMOVE_MEMBER_TITLE": "إزالة من الشركة؟", "REMOVE_MEMBER_TEXT": "لن يرى {name} مهام الشركة وعملاءها بعد الآن.", "LEAVE_COMPANY": "مغادرة الشركة", "LEAVE_COMPANY_TITLE": "مغادرة الشركة؟", "LEAVE_COMPANY_TEXT": "لن ترى مهام {name} وعملاءها بعد الآن.", "NOTIF_JOB_WITHDRAWN": "ألغى العميل المهمة", "INVOICE_EMAILED_TO": "تلقى {email} الفاتورة بصيغة PDF.", "INVOICE_NO_EMAIL": "أُرسلت، لكن ليس بالبريد الإلكتروني: لا يملك العميل عنوان بريد إلكتروني. افتح ملف PDF وشاركه بنفسك، أو استخدم إرسال بالبريد الإلكتروني.", "INVOICE_EMAIL_NOT_SET_UP": "أُرسلت، لكن ليس بالبريد الإلكتروني: لم يُضبط البريد الإلكتروني على الخادم بعد (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "أُرسلت، لكن فشل البريد الإلكتروني: {error}", "SEND_INVOICE_EMAIL_TO": "يُرسل ملف PDF بالبريد الإلكتروني إلى {email}.", "SEND_INVOICE_NO_EMAIL": "لا يوجد عنوان بريد إلكتروني، لذا لن تُرسل بالبريد. يمكنك مشاركة ملف PDF بنفسك.", "EMAIL_INVOICE": "إرسال بالبريد الإلكتروني", "PREVIEW_PDF": "معاينة PDF", "OPEN_PDF": "فتح PDF", "EMAILED": "أُرسلت بالبريد الإلكتروني", "EMAILED_ON": "{email}، {date}", "NOT_EMAILED": "لم تُرسل بالبريد الإلكتروني", "INVOICE_LANGUAGE": "لغة الفاتورة", "NOTIF_NEW_JOB_NEARBY": "عمل جديد بالقرب منك", "NOTIF_NEW_JOB_REMOTE": "عمل جديد عن بُعد", "NOTIF_JOB_INVITED": "تمت دعوتك إلى عمل", "NOTIF_JOB_IN_PLACE": "«{job}» في {place}", "JOB_ALERTS": "تنبيهات الأعمال الجديدة", "JOB_ALERTS_ON_TEXT": "تصلك إشعارات عند نشر عمل في فئاتك ضمن منطقتك.", "JOB_ALERTS_OFF_TEXT": "لن تصلك إشعارات عن الأعمال الجديدة، لكن يمكنك تصفحها في التطبيق.", "JOB_ALERTS_NEEDS_VISIBLE": "فعّل الظهور أولًا. لا يتلقى التنبيهات إلا المحترفون الذين يمكن للعملاء العثور عليهم.", "FORGOT_PASSWORD": "هل نسيت كلمة المرور؟", "FORGOT_PASSWORD_TITLE": "كلمة مرور جديدة", "FORGOT_PASSWORD_INTRO": "أدخل البريد الإلكتروني الذي سجّلت به، وسنرسل إليك رمزًا.", "SEND_CODE": "إرسال الرمز", "RESET_CODE_SENT": "إذا كان لدى {email} حساب، فإن رمزًا مكوّنًا من 6 أرقام في طريقه إليك. أدخله أدناه مع كلمة مرور جديدة.", "RESET_CODE": "الرمز من البريد الإلكتروني", "RESET_CODE_INVALID": "يتكوّن الرمز من 6 أرقام.", "RESET_CODE_WRONG": "الرمز غير صحيح أو انتهت صلاحيته. اطلب رمزًا جديدًا.", "SAVE_NEW_PASSWORD": "حفظ وتسجيل الدخول", "RESET_CODE_AGAIN": "إرسال رمز جديد", "RESET_CODE_RESENT": "تم إرسال رمز جديد", "RESET_CODE_SPAM_HINT": "لم يصلك بريد بعد بضع دقائق؟ تحقّق من مجلد الرسائل غير المرغوب فيها.", "DELETE_ACCOUNT": "حذف الحساب", "DELETE_ACCOUNT_INTRO": "سيؤدي هذا إلى حذف حساب {email}. لا يمكن التراجع عن ذلك.", "DELETE_WHAT_GOES": "ما سيُحذف", "DELETE_GOES_PROFILE": "اسمك وصورتك وهاتفك وبريدك الإلكتروني", "DELETE_GOES_PRO": "ملف المحترف الخاص بك، فلن يتمكن العملاء من إيجادك بعد الآن", "DELETE_GOES_JOBS": "المهام المفتوحة التي نشرتها، والعروض التي لم يردّ عليها أحد", "DELETE_GOES_LOGIN": "تسجيل دخولك، على جميع الأجهزة", "DELETE_WHAT_STAYS": "ما سيُحتفظ به، دون اسمك", "DELETE_STAYS_CONTRACTS": "العقود المنتهية والرسائل والتقييمات، ليبقى الطرف الآخر محتفظًا بها", "DELETE_STAYS_INVOICES": "الفواتير، التي تُلزم قواعد المحاسبة النرويجية بالاحتفاظ بها لمدة 5 سنوات", "DELETE_PASSWORD_HINT": "للتأكد من أنك أنت.", "DELETE_ACCOUNT_CONFIRM_TITLE": "حذف حسابك؟", "DELETE_ACCOUNT_CONFIRM_TEXT": "سيتم تسجيل خروجك ولن تتمكن من تسجيل الدخول بهذا الحساب مرة أخرى.", "DELETE_BLOCKED_CONTRACTS": "لديك عقود جارية. أكملها أو ألغِها أولًا، حتى لا يبقى الطرف الآخر منتظرًا.", "DELETE_BLOCKED_COMPANY": "أنت تملك شركة فيها أعضاء آخرون. أزلهم أولًا من «الفريق».", "JOB_CATEGORY_REQUIRED": "اختر فئة، ليعلم المحترفون المناسبون بالمهمة."}, "hr-HR": {"EDIT": "Uredi", "REMOVE": "Ukloni", "CLEAR": "Očisti", "ARCHIVE": "Arhiviraj", "NOTES": "Bilješke", "YOU": "ti", "DATE_PLACEHOLDER": "dd.mm.gggg", "DATE_INVALID": "Upiši datum u obliku dd.mm.gggg.", "AMOUNT_INVALID": "Upiši iznos u NOK, npr. 5000.", "EMAIL_INVALID": "Ta adresa e-pošte ne izgleda ispravno.", "POSTCODE_FORMAT": "Poštanski broj ima 4 znamenke.", "CLIENT": "Klijent", "CLIENTS": "Klijenti", "CLIENTS_PRO_ONLY": "Vlastiti registar klijenata namijenjen je majstorima. Prijavi se majstorskim računom da bi ga koristio.", "SEARCH_CLIENTS": "Traži klijente", "CLIENTS_ACTIVE": "Aktivni", "CLIENTS_ARCHIVED": "Arhivirani", "NO_CLIENTS": "Još nema klijenata", "NO_CLIENTS_TEXT": "Dodaj klijente za koje radiš izvan platforme i drži njihove poslove, sate i račune na jednom mjestu.", "NO_CLIENTS_MATCH": "Nijedan klijent ne odgovara pretrazi.", "NO_ARCHIVED_CLIENTS": "Ništa nije arhivirano", "NO_ARCHIVED_CLIENTS_TEXT": "Klijenti koje arhiviraš završavaju ovdje, zajedno sa starim poslovima i računima.", "NEW_CLIENT": "Novi klijent", "EDIT_CLIENT": "Uredi klijenta", "SAVE_CLIENT": "Spremi klijenta", "CLIENT_FORM_INTRO": "Ovo vidite samo ti i tvoja tvrtka. Adresa se koristi kao adresa izvođenja radova na novim poslovima.", "CLIENT_TYPE": "Vrsta klijenta", "CLIENT_PRIVATE": "Privatna osoba", "CLIENT_BUSINESS": "Tvrtka", "CLIENT_COMPANY_PLACEHOLDER": "Npr. Bergen Eiendom AS", "CONTACT_PERSON": "Kontakt osoba", "CONTACT_NAME": "Kontakt: {name}", "CLIENT_EMAIL_HINT": "Računi se mogu slati ovamo.", "CLIENT_NOTES_PLACEHOLDER": "Kod za ulaz, parkiranje, ime psa…", "CLIENT_NOTES_HINT": "Samo za tebe i tvoje kolege, nikad se ne prikazuje klijentu.", "CLIENT_NOT_FOUND": "Klijent nije pronađen", "CLIENT_IS_ARCHIVED": "Arhiviran", "CLIENT_NO_DETAILS": "Još nema kontaktnih podataka. Dodirni Uredi da ih dodaš.", "CLIENT_JOBS": "Poslovi", "CLIENT_NO_JOBS": "Za ovog klijenta još nema poslova.", "ARCHIVE_CLIENT": "Arhiviraj klijenta", "ARCHIVE_CLIENT_TITLE": "Arhivirati ovog klijenta?", "ARCHIVE_CLIENT_TEXT": "Klijent ima poslove, pa se čuva zajedno s poslovima i računima. Kasnije ga možeš vratiti.", "RESTORE_CLIENT": "Vrati klijenta", "DELETE_CLIENT": "Izbriši klijenta", "DELETE_CLIENT_TITLE": "Izbrisati ovog klijenta?", "DELETE_CLIENT_TEXT": "{name} se uklanja iz tvog registra.", "NEW_ASSIGNMENT": "Novi posao", "NEW_ASSIGNMENT_INTRO": "Upiši posao za svog klijenta i dogovorite cijenu. Na ugovoru možeš dodavati korake, upisivati sate i izdavati račune.", "PICK_CLIENT_INTRO": "Za koga je posao?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Što je dogovoreno, materijali, sve što klijent treba znati", "START_DATE": "Datum početka", "END_DATE": "Datum završetka", "END_BEFORE_START": "Datum završetka je prije datuma početka.", "STEPS_OPTIONAL_HINT": "Neobavezno. Bez koraka je cijeli posao jedan korak.", "STEPS_SPLIT_HINT": "Svaki se korak odobrava zasebno. Iznosi zajedno moraju činiti cijenu.", "STEPS_HOURLY_HINT": "Svaki se korak odobrava zasebno. Sati se upisuju na ugovor.", "STEP_TITLE": "Korak", "STEP_TITLE_PLACEHOLDER": "Npr. Rušenje i odvodnja", "STEP_TITLE_REQUIRED": "Daj svakom koraku naziv.", "STEP_AMOUNT": "Iznos (NOK)", "STEP_AMOUNT_REQUIRED": "Upiši iznos za svaki korak.", "STEP_DUE": "Rok", "STEP_DESCRIPTION_PLACEHOLDER": "Što uključuje ovaj korak", "STEPS_MUST_ADD_UP": "Koraci zajedno moraju iznositi {total}.", "STEPS_ADD_UP": "Koraci zajedno odgovaraju cijeni ✓", "STEPS_REST": "Preostalo za raspodjelu: {rest}", "STEPS_TOTAL_MISMATCH": "Koraci zajedno iznose {steps}, a dogovorena cijena je {total}.", "REMOVE_STEP": "Ukloni korak", "ADD_STEP": "Dodaj korak", "ADD_STEP_INTRO": "Klijent odobrava svaki korak kad je gotov.", "EDIT_STEP": "Uredi korak", "DELETE_STEP": "Izbriši korak", "DELETE_STEP_TITLE": "Izbrisati ovaj korak?", "DELETE_STEP_TEXT": "„{title}” se uklanja s ugovora.", "STEP_STARTED_NO_DELETE": "Ovaj je korak započeo, pa se može mijenjati, ali ne i izbrisati.", "CREATE_CONTRACT": "Izradi ugovor", "JOB_HAS_CONTRACT": "Ovaj posao već ima ugovor.", "JOB_NOT_YOURS": "Posao može mijenjati samo onaj tko ga je izradio.", "JOB_CANNOT_EDIT": "Netko je već angažiran, pa se posao više ne može mijenjati.", "EDIT_JOB": "Uredi posao", "EDIT_JOB_INTRO": "Majstori odmah vide promjene.", "EDIT_JOB_WITH_OFFERS": "Primljene ponude: {n}. O većim promjenama obavijesti majstore u chatu, da im ponude i dalje odgovaraju.", "CREATED_AGO": "Izrađeno {time}", "DRAFT_NOT_VISIBLE": "Ovo je nacrt. Majstori ga ne vide dok ga ne objaviš.", "CANCEL_JOB": "Otkaži posao", "CANCEL_JOB_TITLE": "Otkazati ovaj posao?", "CANCEL_JOB_TEXT": "Posao se uklanja i ne može se ponovno otvoriti.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Posao se uklanja, a majstori koji su poslali ponude ({n}) dobivaju obavijest da je otkazan.", "DELETE_JOB_TITLE": "Izbrisati nacrt?", "DELETE_JOB_TEXT": "Nacrt se trajno briše.", "CANCEL_CONTRACT": "Otkaži ugovor", "CANCEL_CONTRACT_INTRO": "Rad ovdje prestaje. Odobreni koraci i računi se čuvaju, a druga strana dobiva obavijest.", "CANCEL_REASON": "Zašto? (neobavezno)", "CANCEL_REASON_PLACEHOLDER": "Nekoliko riječi koje ćete oboje kasnije vidjeti", "CONTRACT_CANCELLED_ON": "Otkazano {date}", "COMPLETE_CLIENT_JOB_TEXT": "Svi su koraci potpisani. Posao se označava kao završen.", "SIGN_ON_SITE": "Klijent potpisuje", "SIGN_ON_SITE_INTRO": "Neka klijent pregleda rad i potpiše se prstom na zaslonu. Time se odobrava korak.", "CUSTOMER_NAME": "Ime klijenta", "SIGNATURE": "Potpis", "SIGN_HERE": "Potpiši ovdje", "APPROVE_WITH_SIGNATURE": "Odobri potpisom", "CHANGE_PASSWORD": "Promijeni lozinku", "CHANGE_PASSWORD_INTRO": "Ovdje ostaješ prijavljen. Na ostalim telefonima i preglednicima bit ćeš odjavljen.", "CURRENT_PASSWORD": "Trenutna lozinka", "CURRENT_PASSWORD_REQUIRED": "Upiši trenutnu lozinku.", "CURRENT_PASSWORD_WRONG": "To nije tvoja trenutna lozinka.", "NEW_PASSWORD": "Nova lozinka", "REPEAT_PASSWORD": "Ponovi novu lozinku", "PASSWORDS_DONT_MATCH": "Lozinke se ne podudaraju.", "PASSWORD_SAME_AS_OLD": "Odaberi lozinku koju ovdje još nisi koristio.", "PASSWORD_CHANGED": "Lozinka je promijenjena", "PAYMENTS": "Plaćanja", "PAYMENT": "Plaćanje", "NO_PAYMENTS": "Još nema plaćanja", "NO_PAYMENTS_TEXT": "Ovdje se prikazuju plaćanja obavljena kroz aplikaciju. Poslovi plaćeni računom nalaze se pod Računi.", "PAYMENT_STATUS_PENDING": "Na čekanju", "PAYMENT_STATUS_HELD": "Sigurno zadržano", "PAYMENT_STATUS_RELEASED": "Isplaćeno", "PAYMENT_STATUS_REFUNDED": "Vraćeno", "PAYMENT_STATUS_FAILED": "Neuspjelo", "PLATFORM_FEE": "Naknada {fee}", "TEAM": "Tim", "TEAM_ROW_HINT": "Ljudi koji rade u tvrtki", "TEAM_MANAGE_HINT": "Kolege najprije trebaju Qup Work račun. Dodirni nekoga da ga promijeniš ili ukloniš.", "TEAM_WORKER_HINT": "Vlasnik i administratori dodaju i uklanjaju kolege.", "ADD_MEMBER": "Dodaj kolegu", "ADD_MEMBER_INTRO": "Upotrijebi e-poštu s kojom se kolega registrirao na Qup Work.", "MEMBER_NOT_FOUND": "Još se nitko nije registrirao s tom e-poštom. Zamoli osobu da najprije izradi račun.", "MEMBER_ALREADY": "Ta je osoba već u tvrtki.", "ROLE": "Uloga", "ROLE_ADMIN_HINT": "Administratori mogu mijenjati podatke o tvrtki i postavke računa te dodavati kolege.", "ROLE_WORKER_HINT": "Zaposlenici vide poslove tvrtke, upisuju sate i obavljaju posao.", "REMOVE_FROM_COMPANY": "Ukloni iz tvrtke", "REMOVE_MEMBER_TITLE": "Ukloniti iz tvrtke?", "REMOVE_MEMBER_TEXT": "{name} više ne vidi poslove i klijente tvrtke.", "LEAVE_COMPANY": "Napusti tvrtku", "LEAVE_COMPANY_TITLE": "Napustiti tvrtku?", "LEAVE_COMPANY_TEXT": "Više ne vidiš poslove i klijente tvrtke {name}.", "NOTIF_JOB_WITHDRAWN": "Klijent je otkazao posao", "INVOICE_EMAILED_TO": "{email} je primio račun kao PDF.", "INVOICE_NO_EMAIL": "Poslano, ali ne e-poštom: kupac nema adresu e-pošte. Otvori PDF i podijeli ga sam ili koristi Pošalji e-poštom.", "INVOICE_EMAIL_NOT_SET_UP": "Poslano, ali ne e-poštom: e-pošta još nije postavljena na poslužitelju (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Poslano, ali e-pošta nije uspjela: {error}", "SEND_INVOICE_EMAIL_TO": "PDF se šalje e-poštom na {email}.", "SEND_INVOICE_NO_EMAIL": "Nema adrese e-pošte, pa se neće poslati e-poštom. PDF možeš podijeliti sam.", "EMAIL_INVOICE": "Pošalji e-poštom", "PREVIEW_PDF": "Pregled PDF-a", "OPEN_PDF": "Otvori PDF", "EMAILED": "Poslano e-poštom", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Nije poslano e-poštom", "INVOICE_LANGUAGE": "Jezik računa", "NOTIF_NEW_JOB_NEARBY": "Novi posao u tvojoj blizini", "NOTIF_NEW_JOB_REMOTE": "Novi posao na daljinu", "NOTIF_JOB_INVITED": "Pozvan si na posao", "NOTIF_JOB_IN_PLACE": "„{job}” – {place}", "JOB_ALERTS": "Obavijesti o novim poslovima", "JOB_ALERTS_ON_TEXT": "Dobiješ obavijest kad se u tvom području objavi posao iz tvojih kategorija.", "JOB_ALERTS_OFF_TEXT": "Nećeš dobivati obavijesti o novim poslovima, ali ih i dalje vidiš u aplikaciji.", "JOB_ALERTS_NEEDS_VISIBLE": "Prvo uključi vidljivost. Obavijesti dobivaju samo majstori koje kupci mogu pronaći.", "FORGOT_PASSWORD": "Zaboravljena lozinka?", "FORGOT_PASSWORD_TITLE": "Nova lozinka", "FORGOT_PASSWORD_INTRO": "Unesi adresu e-pošte s kojom si se registrirao i poslat ćemo ti kod.", "SEND_CODE": "Pošalji kod", "RESET_CODE_SENT": "Ako {email} ima račun, 6-znamenkasti kod je na putu. Unesi ga ispod zajedno s novom lozinkom.", "RESET_CODE": "Kod iz e-pošte", "RESET_CODE_INVALID": "Kod ima 6 znamenki.", "RESET_CODE_WRONG": "Kod je pogrešan ili je istekao. Zatraži novi.", "SAVE_NEW_PASSWORD": "Spremi i prijavi se", "RESET_CODE_AGAIN": "Pošalji novi kod", "RESET_CODE_RESENT": "Novi kod je poslan", "RESET_CODE_SPAM_HINT": "Nema e-pošte ni nakon nekoliko minuta? Provjeri mapu neželjene pošte.", "DELETE_ACCOUNT": "Izbriši račun", "DELETE_ACCOUNT_INTRO": "Time se briše račun za {email}. To se ne može poništiti.", "DELETE_WHAT_GOES": "Briše se", "DELETE_GOES_PROFILE": "Tvoje ime, fotografija, telefon i e-pošta", "DELETE_GOES_PRO": "Tvoj profil majstora, pa te klijenti više ne mogu pronaći", "DELETE_GOES_JOBS": "Otvoreni poslovi koje si objavio i ponude na koje nitko nije odgovorio", "DELETE_GOES_LOGIN": "Tvoja prijava, na svim uređajima", "DELETE_WHAT_STAYS": "Ostaje, bez tvog imena", "DELETE_STAYS_CONTRACTS": "Završeni ugovori, poruke i recenzije, da ih druga strana i dalje ima", "DELETE_STAYS_INVOICES": "Računi, koje norveški računovodstveni propisi nalažu čuvati 5 godina", "DELETE_PASSWORD_HINT": "Da budemo sigurni da si to ti.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Izbrisati račun?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Bit ćeš odjavljen i više se nećeš moći prijaviti ovim računom.", "DELETE_BLOCKED_CONTRACTS": "Imaš ugovore u tijeku. Najprije ih završi ili otkaži, da druga strana ne bi čekala.", "DELETE_BLOCKED_COMPANY": "Vlasnik si tvrtke s drugim članovima. Najprije ih ukloni u odjeljku Tim.", "JOB_CATEGORY_REQUIRED": "Odaberi kategoriju, da pravi majstori saznaju za posao."}, "sl-SI": {"EDIT": "Uredi", "REMOVE": "Odstrani", "CLEAR": "Počisti", "ARCHIVE": "Arhiviraj", "NOTES": "Opombe", "YOU": "ti", "DATE_PLACEHOLDER": "dd.mm.llll", "DATE_INVALID": "Datum napiši kot dd.mm.llll.", "AMOUNT_INVALID": "Napiši znesek v NOK, npr. 5000.", "EMAIL_INVALID": "Ta e-poštni naslov ni videti pravilen.", "POSTCODE_FORMAT": "Poštna številka ima 4 števke.", "CLIENT": "Stranka", "CLIENTS": "Stranke", "CLIENTS_PRO_ONLY": "Lastni register strank je namenjen mojstrom. Prijavi se z računom mojstra, da ga lahko uporabljaš.", "SEARCH_CLIENTS": "Išči stranke", "CLIENTS_ACTIVE": "Aktivne", "CLIENTS_ARCHIVED": "Arhivirane", "NO_CLIENTS": "Še ni strank", "NO_CLIENTS_TEXT": "Dodaj stranke, za katere delaš zunaj tržnice, in imej njihova dela, ure in račune na enem mestu.", "NO_CLIENTS_MATCH": "Iskanju ne ustreza nobena stranka.", "NO_ARCHIVED_CLIENTS": "Nič arhiviranega", "NO_ARCHIVED_CLIENTS_TEXT": "Stranke, ki jih arhiviraš, se znajdejo tukaj, skupaj s starimi deli in računi.", "NEW_CLIENT": "Nova stranka", "EDIT_CLIENT": "Uredi stranko", "SAVE_CLIENT": "Shrani stranko", "CLIENT_FORM_INTRO": "To vidiš samo ti in tvoje podjetje. Naslov se uporabi kot kraj dela pri novih delih.", "CLIENT_TYPE": "Vrsta stranke", "CLIENT_PRIVATE": "Fizična oseba", "CLIENT_BUSINESS": "Podjetje", "CLIENT_COMPANY_PLACEHOLDER": "Npr. Bergen Eiendom AS", "CONTACT_PERSON": "Kontaktna oseba", "CONTACT_NAME": "Kontakt: {name}", "CLIENT_EMAIL_HINT": "Sem se lahko pošiljajo računi.", "CLIENT_NOTES_PLACEHOLDER": "Koda za vrata, parkiranje, ime psa…", "CLIENT_NOTES_HINT": "Samo zate in tvoje sodelavce, stranki se nikoli ne prikaže.", "CLIENT_NOT_FOUND": "Stranke ni mogoče najti", "CLIENT_IS_ARCHIVED": "Arhivirana", "CLIENT_NO_DETAILS": "Še ni kontaktnih podatkov. Tapni Uredi, da jih dodaš.", "CLIENT_JOBS": "Dela", "CLIENT_NO_JOBS": "Za to stranko še ni del.", "ARCHIVE_CLIENT": "Arhiviraj stranko", "ARCHIVE_CLIENT_TITLE": "Arhiviraš to stranko?", "ARCHIVE_CLIENT_TEXT": "Stranka ima dela, zato se ohrani skupaj z deli in računi. Pozneje jo lahko obnoviš.", "RESTORE_CLIENT": "Obnovi stranko", "DELETE_CLIENT": "Izbriši stranko", "DELETE_CLIENT_TITLE": "Izbrišeš to stranko?", "DELETE_CLIENT_TEXT": "{name} se odstrani iz tvojega registra.", "NEW_ASSIGNMENT": "Novo naročilo", "NEW_ASSIGNMENT_INTRO": "Vpiši delo za svojo stranko in se dogovori za ceno. Na pogodbi lahko dodaš korake, vpisuješ ure in izstaviš račun.", "PICK_CLIENT_INTRO": "Za koga je delo?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Kaj je dogovorjeno, material, kar mora stranka vedeti", "START_DATE": "Datum začetka", "END_DATE": "Datum konca", "END_BEFORE_START": "Datum konca je pred datumom začetka.", "STEPS_OPTIONAL_HINT": "Neobvezno. Brez korakov je celotno delo en korak.", "STEPS_SPLIT_HINT": "Vsak korak se odobri posebej. Zneski se morajo sešteti v ceno.", "STEPS_HOURLY_HINT": "Vsak korak se odobri posebej. Ure se vpisujejo na pogodbo.", "STEP_TITLE": "Korak", "STEP_TITLE_PLACEHOLDER": "Npr. Rušenje in odtok", "STEP_TITLE_REQUIRED": "Vsakemu koraku daj ime.", "STEP_AMOUNT": "Znesek (NOK)", "STEP_AMOUNT_REQUIRED": "Vsakemu koraku določi znesek.", "STEP_DUE": "Rok", "STEP_DESCRIPTION_PLACEHOLDER": "Kaj vključuje ta korak", "STEPS_MUST_ADD_UP": "Koraki se morajo sešteti v {total}.", "STEPS_ADD_UP": "Koraki se seštejejo v ceno ✓", "STEPS_REST": "Še za razdelitev: {rest}", "STEPS_TOTAL_MISMATCH": "Koraki znašajo {steps}, dogovorjena cena je {total}.", "REMOVE_STEP": "Odstrani korak", "ADD_STEP": "Dodaj korak", "ADD_STEP_INTRO": "Stranka odobri vsak korak, ko je končan.", "EDIT_STEP": "Uredi korak", "DELETE_STEP": "Izbriši korak", "DELETE_STEP_TITLE": "Izbrišeš ta korak?", "DELETE_STEP_TEXT": "»{title}« se odstrani s pogodbe.", "STEP_STARTED_NO_DELETE": "Ta korak se je že začel, zato ga je mogoče spremeniti, ne pa izbrisati.", "CREATE_CONTRACT": "Ustvari pogodbo", "JOB_HAS_CONTRACT": "To delo že ima pogodbo.", "JOB_NOT_YOURS": "Delo lahko spremeni samo tisti, ki ga je ustvaril.", "JOB_CANNOT_EDIT": "Nekdo je že najet, zato dela ni več mogoče spreminjati.", "EDIT_JOB": "Uredi delo", "EDIT_JOB_INTRO": "Mojstri spremembe vidijo takoj.", "EDIT_JOB_WITH_OFFERS": "Prejete ponudbe: {n}. O večjih spremembah obvesti mojstre v klepetu, da bodo njihove ponudbe še ustrezale.", "CREATED_AGO": "Ustvarjeno {time}", "DRAFT_NOT_VISIBLE": "To je osnutek. Mojstri ga ne vidijo, dokler ga ne objaviš.", "CANCEL_JOB": "Prekliči delo", "CANCEL_JOB_TITLE": "Prekličeš to delo?", "CANCEL_JOB_TEXT": "Delo se umakne in ga ni mogoče znova odpreti.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Delo se umakne, mojstri, ki so poslali ponudbe ({n}), pa dobijo obvestilo, da je preklicano.", "DELETE_JOB_TITLE": "Izbrišeš osnutek?", "DELETE_JOB_TEXT": "Osnutek se trajno izbriše.", "CANCEL_CONTRACT": "Prekliči pogodbo", "CANCEL_CONTRACT_INTRO": "Delo se tu ustavi. Odobreni koraki in računi ostanejo, druga stran pa dobi obvestilo.", "CANCEL_REASON": "Zakaj? (neobvezno)", "CANCEL_REASON_PLACEHOLDER": "Nekaj besed, ki jih bosta pozneje lahko videla oba", "CONTRACT_CANCELLED_ON": "Preklicano {date}", "COMPLETE_CLIENT_JOB_TEXT": "Vsi koraki so podpisani. Delo bo označeno kot zaključeno.", "SIGN_ON_SITE": "Stranka podpiše", "SIGN_ON_SITE_INTRO": "Naj stranka pregleda delo in se s prstom podpiše na zaslon. S tem je korak odobren.", "CUSTOMER_NAME": "Ime stranke", "SIGNATURE": "Podpis", "SIGN_HERE": "Podpišite se tukaj", "APPROVE_WITH_SIGNATURE": "Odobri s podpisom", "CHANGE_PASSWORD": "Spremeni geslo", "CHANGE_PASSWORD_INTRO": "Tukaj ostaneš prijavljen. Na drugih telefonih in brskalnikih boš odjavljen.", "CURRENT_PASSWORD": "Trenutno geslo", "CURRENT_PASSWORD_REQUIRED": "Vnesi trenutno geslo.", "CURRENT_PASSWORD_WRONG": "To ni tvoje trenutno geslo.", "NEW_PASSWORD": "Novo geslo", "REPEAT_PASSWORD": "Ponovi novo geslo", "PASSWORDS_DONT_MATCH": "Gesli se ne ujemata.", "PASSWORD_SAME_AS_OLD": "Izberi geslo, ki ga tukaj še nisi uporabil.", "PASSWORD_CHANGED": "Geslo je spremenjeno", "PAYMENTS": "Plačila", "PAYMENT": "Plačilo", "NO_PAYMENTS": "Še ni plačil", "NO_PAYMENTS_TEXT": "Tukaj se prikažejo plačila prek aplikacije. Dela, plačana z računom, najdeš pod Računi.", "PAYMENT_STATUS_PENDING": "Čaka", "PAYMENT_STATUS_HELD": "Varno zadržano", "PAYMENT_STATUS_RELEASED": "Izplačano", "PAYMENT_STATUS_REFUNDED": "Vrnjeno", "PAYMENT_STATUS_FAILED": "Ni uspelo", "PLATFORM_FEE": "Provizija {fee}", "TEAM": "Ekipa", "TEAM_ROW_HINT": "Ljudje, ki delajo v podjetju", "TEAM_MANAGE_HINT": "Sodelavci najprej potrebujejo račun Qup Work. Tapni nekoga, da ga spremeniš ali odstraniš.", "TEAM_WORKER_HINT": "Sodelavce dodajajo in odstranjujejo lastnik in skrbniki.", "ADD_MEMBER": "Dodaj sodelavca", "ADD_MEMBER_INTRO": "Uporabi e-poštni naslov, s katerim se je registriral v Qup Work.", "MEMBER_NOT_FOUND": "S tem e-poštnim naslovom se še nihče ni registriral. Prosi ga, naj najprej ustvari račun.", "MEMBER_ALREADY": "Ta oseba je že v podjetju.", "ROLE": "Vloga", "ROLE_ADMIN_HINT": "Skrbniki lahko spreminjajo podatke podjetja in nastavitve računov ter dodajajo sodelavce.", "ROLE_WORKER_HINT": "Zaposleni vidijo dela podjetja, vpisujejo ure in opravljajo delo.", "REMOVE_FROM_COMPANY": "Odstrani iz podjetja", "REMOVE_MEMBER_TITLE": "Odstraniš iz podjetja?", "REMOVE_MEMBER_TEXT": "{name} ne vidi več del in strank podjetja.", "LEAVE_COMPANY": "Zapusti podjetje", "LEAVE_COMPANY_TITLE": "Zapustiš podjetje?", "LEAVE_COMPANY_TEXT": "Ne vidiš več del in strank podjetja {name}.", "NOTIF_JOB_WITHDRAWN": "Stranka je preklicala delo", "INVOICE_EMAILED_TO": "{email} je prejel račun kot PDF.", "INVOICE_NO_EMAIL": "Poslano, a ne po e-pošti: stranka nima e-poštnega naslova. Odpri PDF in ga deli sam ali uporabi Pošlji po e-pošti.", "INVOICE_EMAIL_NOT_SET_UP": "Poslano, a ne po e-pošti: e-pošta na strežniku še ni nastavljena (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Poslano, a e-pošta ni uspela: {error}", "SEND_INVOICE_EMAIL_TO": "PDF se pošlje po e-pošti na {email}.", "SEND_INVOICE_NO_EMAIL": "E-poštnega naslova ni, zato ne bo poslan po e-pošti. PDF lahko deliš sam.", "EMAIL_INVOICE": "Pošlji po e-pošti", "PREVIEW_PDF": "Predogled PDF", "OPEN_PDF": "Odpri PDF", "EMAILED": "Poslano po e-pošti", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Ni poslano po e-pošti", "INVOICE_LANGUAGE": "Jezik računa", "NOTIF_NEW_JOB_NEARBY": "Novo delo v tvoji bližini", "NOTIF_NEW_JOB_REMOTE": "Novo delo na daljavo", "NOTIF_JOB_INVITED": "Povabljen si bil k delu", "NOTIF_JOB_IN_PLACE": "»{job}« – {place}", "JOB_ALERTS": "Obvestila o novih delih", "JOB_ALERTS_ON_TEXT": "Obvestilo dobiš, ko je v tvoji okolici objavljeno delo iz tvojih kategorij.", "JOB_ALERTS_OFF_TEXT": "Obvestil o novih delih ne boš dobil, a jih še vedno vidiš v aplikaciji.", "JOB_ALERTS_NEEDS_VISIBLE": "Najprej vklopi vidnost. Obvestila dobijo le mojstri, ki jih stranke lahko najdejo.", "FORGOT_PASSWORD": "Pozabljeno geslo?", "FORGOT_PASSWORD_TITLE": "Novo geslo", "FORGOT_PASSWORD_INTRO": "Vnesi e-pošto, s katero si se registriral, in poslali ti bomo kodo.", "SEND_CODE": "Pošlji kodo", "RESET_CODE_SENT": "Če ima {email} račun, je 6-mestna koda na poti. Vnesi jo spodaj skupaj z novim geslom.", "RESET_CODE": "Koda iz e-pošte", "RESET_CODE_INVALID": "Koda ima 6 števk.", "RESET_CODE_WRONG": "Koda je napačna ali je potekla. Zahtevaj novo.", "SAVE_NEW_PASSWORD": "Shrani in se prijavi", "RESET_CODE_AGAIN": "Pošlji novo kodo", "RESET_CODE_RESENT": "Nova koda je poslana", "RESET_CODE_SPAM_HINT": "Po nekaj minutah še ni e-pošte? Preveri mapo z neželeno pošto.", "DELETE_ACCOUNT": "Izbriši račun", "DELETE_ACCOUNT_INTRO": "S tem se izbriše račun za {email}. Tega ni mogoče razveljaviti.", "DELETE_WHAT_GOES": "Izbriše se", "DELETE_GOES_PROFILE": "Tvoje ime, fotografija, telefon in e-pošta", "DELETE_GOES_PRO": "Tvoj profil mojstra, tako da te stranke ne bodo več našle", "DELETE_GOES_JOBS": "Odprta dela, ki si jih objavil, in ponudbe, na katere ni nihče odgovoril", "DELETE_GOES_LOGIN": "Tvoja prijava na vseh napravah", "DELETE_WHAT_STAYS": "Ohrani se, brez tvojega imena", "DELETE_STAYS_CONTRACTS": "Zaključene pogodbe, sporočila in ocene, da jih ima druga stran še vedno", "DELETE_STAYS_INVOICES": "Računi, ki jih je treba po norveških računovodskih pravilih hraniti 5 let", "DELETE_PASSWORD_HINT": "Da se prepričamo, da si res ti.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Želiš izbrisati račun?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Odjavljen boš in s tem računom se ne boš mogel več prijaviti.", "DELETE_BLOCKED_CONTRACTS": "Imaš pogodbe v teku. Najprej jih zaključi ali prekliči, da druga stran ne bo čakala.", "DELETE_BLOCKED_COMPANY": "Si lastnik podjetja z drugimi člani. Najprej jih odstrani v razdelku Ekipa.", "JOB_CATEGORY_REQUIRED": "Izberi kategorijo, da bodo za delo izvedeli pravi mojstri."}, "lt-LT": {"EDIT": "Redaguoti", "REMOVE": "Pašalinti", "CLEAR": "Išvalyti", "ARCHIVE": "Archyvuoti", "NOTES": "Pastabos", "YOU": "jūs", "DATE_PLACEHOLDER": "dd.mm.mmmm", "DATE_INVALID": "Įrašykite datą formatu dd.mm.mmmm.", "AMOUNT_INVALID": "Įrašykite sumą NOK, pvz., 5000.", "EMAIL_INVALID": "Šis el. pašto adresas neatrodo teisingas.", "POSTCODE_FORMAT": "Pašto kodą sudaro 4 skaitmenys.", "CLIENT": "Klientas", "CLIENTS": "Klientai", "CLIENTS_PRO_ONLY": "Klientų registras skirtas meistrams. Norėdami juo naudotis, prisijunkite su meistro paskyra.", "SEARCH_CLIENTS": "Ieškoti klientų", "CLIENTS_ACTIVE": "Aktyvūs", "CLIENTS_ARCHIVED": "Archyvuoti", "NO_CLIENTS": "Klientų dar nėra", "NO_CLIENTS_TEXT": "Pridėkite klientus, kuriems dirbate ne per platformą, ir laikykite jų darbus, valandas bei sąskaitas vienoje vietoje.", "NO_CLIENTS_MATCH": "Paieškos neatitinka nė vienas klientas.", "NO_ARCHIVED_CLIENTS": "Archyvas tuščias", "NO_ARCHIVED_CLIENTS_TEXT": "Čia atsiduria archyvuoti klientai su savo senais darbais ir sąskaitomis.", "NEW_CLIENT": "Naujas klientas", "EDIT_CLIENT": "Redaguoti klientą", "SAVE_CLIENT": "Išsaugoti klientą", "CLIENT_FORM_INTRO": "Tai matote tik jūs ir jūsų įmonė. Adresas naudojamas kaip darbo adresas naujuose darbuose.", "CLIENT_TYPE": "Kliento tipas", "CLIENT_PRIVATE": "Privatus asmuo", "CLIENT_BUSINESS": "Įmonė", "CLIENT_COMPANY_PLACEHOLDER": "Pvz., Bergen Eiendom AS", "CONTACT_PERSON": "Kontaktinis asmuo", "CONTACT_NAME": "Kontaktinis asmuo: {name}", "CLIENT_EMAIL_HINT": "Čia galima siųsti sąskaitas.", "CLIENT_NOTES_PLACEHOLDER": "Vartų kodas, parkavimas, šuns vardas…", "CLIENT_NOTES_HINT": "Tik jums ir jūsų kolegoms, klientui niekada nerodoma.", "CLIENT_NOT_FOUND": "Klientas nerastas", "CLIENT_IS_ARCHIVED": "Archyvuotas", "CLIENT_NO_DETAILS": "Kontaktinių duomenų dar nėra. Bakstelėkite Redaguoti, kad juos pridėtumėte.", "CLIENT_JOBS": "Darbai", "CLIENT_NO_JOBS": "Šiam klientui darbų dar nėra.", "ARCHIVE_CLIENT": "Archyvuoti klientą", "ARCHIVE_CLIENT_TITLE": "Archyvuoti šį klientą?", "ARCHIVE_CLIENT_TEXT": "Klientas turi darbų, todėl jis išsaugomas kartu su darbais ir sąskaitomis. Vėliau galėsite jį atkurti.", "RESTORE_CLIENT": "Atkurti klientą", "DELETE_CLIENT": "Ištrinti klientą", "DELETE_CLIENT_TITLE": "Ištrinti šį klientą?", "DELETE_CLIENT_TEXT": "{name} pašalinamas iš jūsų registro.", "NEW_ASSIGNMENT": "Naujas užsakymas", "NEW_ASSIGNMENT_INTRO": "Užregistruokite darbą savo klientui ir susitarkite dėl kainos. Iš sutarties galėsite pridėti etapų, registruoti valandas ir išrašyti sąskaitas.", "PICK_CLIENT_INTRO": "Kam skirtas darbas?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Dėl ko susitarta, medžiagos, viskas, ką klientas turėtų žinoti", "START_DATE": "Pradžios data", "END_DATE": "Pabaigos data", "END_BEFORE_START": "Pabaigos data yra ankstesnė už pradžios datą.", "STEPS_OPTIONAL_HINT": "Neprivaloma. Be etapų visas darbas yra vienas etapas.", "STEPS_SPLIT_HINT": "Kiekvienas etapas tvirtinamas atskirai. Sumų suma turi atitikti kainą.", "STEPS_HOURLY_HINT": "Kiekvienas etapas tvirtinamas atskirai. Valandos registruojamos sutartyje.", "STEP_TITLE": "Etapas", "STEP_TITLE_PLACEHOLDER": "Pvz., Griovimas ir drenažas", "STEP_TITLE_REQUIRED": "Kiekvienam etapui suteikite pavadinimą.", "STEP_AMOUNT": "Suma (NOK)", "STEP_AMOUNT_REQUIRED": "Kiekvienam etapui nurodykite sumą.", "STEP_DUE": "Terminas", "STEP_DESCRIPTION_PLACEHOLDER": "Kas įeina į šį etapą", "STEPS_MUST_ADD_UP": "Etapų suma turi būti {total}.", "STEPS_ADD_UP": "Etapų suma atitinka kainą ✓", "STEPS_REST": "Liko paskirstyti: {rest}", "STEPS_TOTAL_MISMATCH": "Etapų suma yra {steps}, o sutarta kaina – {total}.", "REMOVE_STEP": "Pašalinti etapą", "ADD_STEP": "Pridėti etapą", "ADD_STEP_INTRO": "Klientas patvirtina kiekvieną etapą, kai jis atliktas.", "EDIT_STEP": "Redaguoti etapą", "DELETE_STEP": "Ištrinti etapą", "DELETE_STEP_TITLE": "Ištrinti šį etapą?", "DELETE_STEP_TEXT": "„{title}“ pašalinamas iš sutarties.", "STEP_STARTED_NO_DELETE": "Šis etapas jau pradėtas, todėl jį galima keisti, bet ne ištrinti.", "CREATE_CONTRACT": "Sukurti sutartį", "JOB_HAS_CONTRACT": "Šis darbas jau turi sutartį.", "JOB_NOT_YOURS": "Darbą gali keisti tik tas, kas jį sukūrė.", "JOB_CANNOT_EDIT": "Kažkas jau pasamdytas, todėl darbo nebegalima keisti.", "EDIT_JOB": "Redaguoti darbą", "EDIT_JOB_INTRO": "Meistrai pakeitimus mato iš karto.", "EDIT_JOB_WITH_OFFERS": "Gauta pasiūlymų: {n}. Apie didelius pakeitimus praneškite meistrams pokalbyje, kad jų pasiūlymai vis dar tiktų.", "CREATED_AGO": "Sukurta {time}", "DRAFT_NOT_VISIBLE": "Tai juodraštis. Meistrai jo nematys, kol jo nepaskelbsite.", "CANCEL_JOB": "Atšaukti darbą", "CANCEL_JOB_TITLE": "Atšaukti šį darbą?", "CANCEL_JOB_TEXT": "Darbas pašalinamas ir jo nebegalima vėl atidaryti.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Darbas pašalinamas, o pasiūlymus atsiuntę meistrai ({n}) informuojami, kad jis atšauktas.", "DELETE_JOB_TITLE": "Ištrinti juodraštį?", "DELETE_JOB_TEXT": "Juodraštis ištrinamas visam laikui.", "CANCEL_CONTRACT": "Atšaukti sutartį", "CANCEL_CONTRACT_INTRO": "Darbas čia sustoja. Patvirtinti etapai ir sąskaitos išlieka, o kita šalis informuojama.", "CANCEL_REASON": "Kodėl? (neprivaloma)", "CANCEL_REASON_PLACEHOLDER": "Keli žodžiai, kuriuos vėliau matysite abu", "CONTRACT_CANCELLED_ON": "Atšaukta {date}", "COMPLETE_CLIENT_JOB_TEXT": "Visi etapai pasirašyti. Darbas pažymimas kaip užbaigtas.", "SIGN_ON_SITE": "Kliento parašas", "SIGN_ON_SITE_INTRO": "Leiskite klientui patikrinti darbą ir pasirašyti pirštu ekrane. Taip etapas patvirtinamas.", "CUSTOMER_NAME": "Kliento vardas", "SIGNATURE": "Parašas", "SIGN_HERE": "Pasirašykite čia", "APPROVE_WITH_SIGNATURE": "Patvirtinti parašu", "CHANGE_PASSWORD": "Keisti slaptažodį", "CHANGE_PASSWORD_INTRO": "Čia liksite prisijungę. Kituose telefonuose ir naršyklėse būsite atjungti.", "CURRENT_PASSWORD": "Dabartinis slaptažodis", "CURRENT_PASSWORD_REQUIRED": "Įveskite dabartinį slaptažodį.", "CURRENT_PASSWORD_WRONG": "Tai ne jūsų dabartinis slaptažodis.", "NEW_PASSWORD": "Naujas slaptažodis", "REPEAT_PASSWORD": "Pakartokite naują slaptažodį", "PASSWORDS_DONT_MATCH": "Slaptažodžiai nesutampa.", "PASSWORD_SAME_AS_OLD": "Pasirinkite slaptažodį, kurio čia dar nenaudojote.", "PASSWORD_CHANGED": "Slaptažodis pakeistas", "PAYMENTS": "Mokėjimai", "PAYMENT": "Mokėjimas", "NO_PAYMENTS": "Mokėjimų dar nėra", "NO_PAYMENTS_TEXT": "Čia rodomi mokėjimai per programėlę. Darbai, apmokėti pagal sąskaitą, yra skiltyje Sąskaitos.", "PAYMENT_STATUS_PENDING": "Laukiama", "PAYMENT_STATUS_HELD": "Saugiai laikoma", "PAYMENT_STATUS_RELEASED": "Išmokėta", "PAYMENT_STATUS_REFUNDED": "Grąžinta", "PAYMENT_STATUS_FAILED": "Nepavyko", "PLATFORM_FEE": "Mokestis {fee}", "TEAM": "Komanda", "TEAM_ROW_HINT": "Įmonėje dirbantys žmonės", "TEAM_MANAGE_HINT": "Kolegoms pirmiausia reikia Qup Work paskyros. Bakstelėkite asmenį, kad jį pakeistumėte ar pašalintumėte.", "TEAM_WORKER_HINT": "Kolegas prideda ir šalina savininkas bei administratoriai.", "ADD_MEMBER": "Pridėti kolegą", "ADD_MEMBER_INTRO": "Naudokite el. paštą, kuriuo jis užsiregistravo Qup Work.", "MEMBER_NOT_FOUND": "Šiuo el. paštu dar niekas neužsiregistravo. Paprašykite pirmiausia susikurti paskyrą.", "MEMBER_ALREADY": "Šis asmuo jau yra įmonėje.", "ROLE": "Vaidmuo", "ROLE_ADMIN_HINT": "Administratoriai gali keisti įmonės duomenis ir sąskaitų nustatymus bei pridėti kolegų.", "ROLE_WORKER_HINT": "Darbuotojai mato įmonės darbus, registruoja valandas ir atlieka darbą.", "REMOVE_FROM_COMPANY": "Pašalinti iš įmonės", "REMOVE_MEMBER_TITLE": "Pašalinti iš įmonės?", "REMOVE_MEMBER_TEXT": "{name} nebematys įmonės darbų ir klientų.", "LEAVE_COMPANY": "Palikti įmonę", "LEAVE_COMPANY_TITLE": "Palikti įmonę?", "LEAVE_COMPANY_TEXT": "Nebematysite įmonės {name} darbų ir klientų.", "NOTIF_JOB_WITHDRAWN": "Klientas atšaukė darbą", "INVOICE_EMAILED_TO": "{email} gavo sąskaitą PDF formatu.", "INVOICE_NO_EMAIL": "Išsiųsta, bet ne el. paštu: klientas neturi el. pašto adreso. Atidaryk PDF ir pasidalyk juo pats arba naudok Siųsti el. paštu.", "INVOICE_EMAIL_NOT_SET_UP": "Išsiųsta, bet ne el. paštu: el. paštas serveryje dar nenustatytas (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Išsiųsta, bet el. laiškas nepavyko: {error}", "SEND_INVOICE_EMAIL_TO": "PDF siunčiamas el. paštu adresu {email}.", "SEND_INVOICE_NO_EMAIL": "El. pašto adreso nėra, todėl el. paštu nebus siunčiama. PDF gali pasidalyti pats.", "EMAIL_INVOICE": "Siųsti el. paštu", "PREVIEW_PDF": "PDF peržiūra", "OPEN_PDF": "Atidaryti PDF", "EMAILED": "Išsiųsta el. paštu", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Neišsiųsta el. paštu", "INVOICE_LANGUAGE": "Sąskaitos kalba", "NOTIF_NEW_JOB_NEARBY": "Naujas darbas netoli tavęs", "NOTIF_NEW_JOB_REMOTE": "Naujas nuotolinis darbas", "NOTIF_JOB_INVITED": "Tave pakvietė į darbą", "NOTIF_JOB_IN_PLACE": "„{job}“ – {place}", "JOB_ALERTS": "Pranešimai apie naujus darbus", "JOB_ALERTS_ON_TEXT": "Gauni pranešimą, kai tavo apylinkėse paskelbiamas darbas iš tavo kategorijų.", "JOB_ALERTS_OFF_TEXT": "Negausi pranešimų apie naujus darbus, bet vis tiek matysi juos programėlėje.", "JOB_ALERTS_NEEDS_VISIBLE": "Pirmiausia įjunk matomumą. Pranešimus gauna tik meistrai, kuriuos klientai gali rasti.", "FORGOT_PASSWORD": "Pamiršote slaptažodį?", "FORGOT_PASSWORD_TITLE": "Naujas slaptažodis", "FORGOT_PASSWORD_INTRO": "Įveskite el. paštą, kuriuo registravotės, ir atsiųsime jums kodą.", "SEND_CODE": "Siųsti kodą", "RESET_CODE_SENT": "Jei {email} turi paskyrą, 6 skaitmenų kodas jau pakeliui. Įveskite jį žemiau kartu su nauju slaptažodžiu.", "RESET_CODE": "Kodas iš el. laiško", "RESET_CODE_INVALID": "Kodą sudaro 6 skaitmenys.", "RESET_CODE_WRONG": "Kodas neteisingas arba nebegalioja. Paprašykite naujo.", "SAVE_NEW_PASSWORD": "Išsaugoti ir prisijungti", "RESET_CODE_AGAIN": "Siųsti naują kodą", "RESET_CODE_RESENT": "Naujas kodas išsiųstas", "RESET_CODE_SPAM_HINT": "Po kelių minučių vis dar nėra laiško? Patikrinkite šlamšto aplanką.", "DELETE_ACCOUNT": "Ištrinti paskyrą", "DELETE_ACCOUNT_INTRO": "Bus ištrinta {email} paskyra. Šio veiksmo atšaukti negalima.", "DELETE_WHAT_GOES": "Ištrinama", "DELETE_GOES_PROFILE": "Jūsų vardas, nuotrauka, telefonas ir el. paštas", "DELETE_GOES_PRO": "Jūsų meistro profilis, kad klientai jūsų nebegalėtų rasti", "DELETE_GOES_JOBS": "Jūsų paskelbti atviri darbai ir pasiūlymai, į kuriuos niekas neatsakė", "DELETE_GOES_LOGIN": "Jūsų prisijungimas visuose įrenginiuose", "DELETE_WHAT_STAYS": "Išsaugoma, be jūsų vardo", "DELETE_STAYS_CONTRACTS": "Užbaigtos sutartys, žinutės ir atsiliepimai, kad kita šalis juos vis dar turėtų", "DELETE_STAYS_INVOICES": "Sąskaitos, kurias pagal Norvegijos buhalterinės apskaitos taisykles privaloma saugoti 5 metus", "DELETE_PASSWORD_HINT": "Kad įsitikintume, jog tai jūs.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Ištrinti paskyrą?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Būsite atjungti ir nebegalėsite prisijungti su šia paskyra.", "DELETE_BLOCKED_CONTRACTS": "Turite vykdomų sutarčių. Pirmiausia jas užbaikite arba atšaukite, kad kita šalis neliktų laukti.", "DELETE_BLOCKED_COMPANY": "Jums priklauso įmonė, kurioje yra kitų narių. Pirmiausia pašalinkite juos skiltyje Komanda.", "JOB_CATEGORY_REQUIRED": "Pasirinkite kategoriją, kad apie darbą sužinotų tinkami meistrai."}, "nl-NL": {"EDIT": "Bewerken", "REMOVE": "Verwijderen", "CLEAR": "Wissen", "ARCHIVE": "Archiveren", "NOTES": "Notities", "YOU": "jij", "DATE_PLACEHOLDER": "dd-mm-jjjj", "DATE_INVALID": "Schrijf de datum als dd-mm-jjjj.", "AMOUNT_INVALID": "Vul een bedrag in NOK in, bijv. 5000.", "EMAIL_INVALID": "Dat e-mailadres lijkt niet te kloppen.", "POSTCODE_FORMAT": "Een postcode heeft 4 cijfers.", "CLIENT": "Klant", "CLIENTS": "Klanten", "CLIENTS_PRO_ONLY": "Je eigen klantenregister is voor vakmensen. Log in met een vakmanaccount om het te gebruiken.", "SEARCH_CLIENTS": "Klanten zoeken", "CLIENTS_ACTIVE": "Actief", "CLIENTS_ARCHIVED": "Gearchiveerd", "NO_CLIENTS": "Nog geen klanten", "NO_CLIENTS_TEXT": "Voeg de klanten toe voor wie je buiten het platform werkt, en houd klussen, uren en facturen voor hen op één plek bij.", "NO_CLIENTS_MATCH": "Geen klanten gevonden voor je zoekopdracht.", "NO_ARCHIVED_CLIENTS": "Niets gearchiveerd", "NO_ARCHIVED_CLIENTS_TEXT": "Klanten die je archiveert komen hier terecht, met hun oude klussen en facturen.", "NEW_CLIENT": "Nieuwe klant", "EDIT_CLIENT": "Klant bewerken", "SAVE_CLIENT": "Klant opslaan", "CLIENT_FORM_INTRO": "Alleen jij en je bedrijf kunnen dit zien. Het adres wordt gebruikt als werkadres bij nieuwe klussen.", "CLIENT_TYPE": "Soort klant", "CLIENT_PRIVATE": "Particulier", "CLIENT_BUSINESS": "Bedrijf", "CLIENT_COMPANY_PLACEHOLDER": "Bijv. Bergen Eiendom AS", "CONTACT_PERSON": "Contactpersoon", "CONTACT_NAME": "Contactpersoon: {name}", "CLIENT_EMAIL_HINT": "Facturen kunnen hierheen worden gestuurd.", "CLIENT_NOTES_PLACEHOLDER": "Poortcode, parkeren, de naam van de hond…", "CLIENT_NOTES_HINT": "Alleen voor jou en je collega’s, nooit zichtbaar voor de klant.", "CLIENT_NOT_FOUND": "Klant niet gevonden", "CLIENT_IS_ARCHIVED": "Gearchiveerd", "CLIENT_NO_DETAILS": "Nog geen contactgegevens. Tik op Bewerken om ze toe te voegen.", "CLIENT_JOBS": "Klussen", "CLIENT_NO_JOBS": "Nog geen klussen voor deze klant.", "ARCHIVE_CLIENT": "Klant archiveren", "ARCHIVE_CLIENT_TITLE": "Deze klant archiveren?", "ARCHIVE_CLIENT_TEXT": "De klant heeft klussen, dus hij wordt bewaard met zijn klussen en facturen. Je kunt hem later terugzetten.", "RESTORE_CLIENT": "Klant terugzetten", "DELETE_CLIENT": "Klant verwijderen", "DELETE_CLIENT_TITLE": "Deze klant verwijderen?", "DELETE_CLIENT_TEXT": "{name} wordt uit je register verwijderd.", "NEW_ASSIGNMENT": "Nieuwe opdracht", "NEW_ASSIGNMENT_INTRO": "Registreer werk voor je eigen klant en spreek de prijs af. Vanuit de overeenkomst kun je stappen toevoegen, uren registreren en factureren.", "PICK_CLIENT_INTRO": "Voor wie is het werk?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Wat er is afgesproken, materialen, alles wat de klant moet weten", "START_DATE": "Startdatum", "END_DATE": "Einddatum", "END_BEFORE_START": "De einddatum ligt vóór de startdatum.", "STEPS_OPTIONAL_HINT": "Optioneel. Zonder stappen is de hele klus één stap.", "STEPS_SPLIT_HINT": "Elke stap wordt apart goedgekeurd. De bedragen moeten samen de prijs vormen.", "STEPS_HOURLY_HINT": "Elke stap wordt apart goedgekeurd. De uren worden op de overeenkomst geregistreerd.", "STEP_TITLE": "Stap", "STEP_TITLE_PLACEHOLDER": "Bijv. Sloopwerk en afvoer", "STEP_TITLE_REQUIRED": "Geef elke stap een naam.", "STEP_AMOUNT": "Bedrag (NOK)", "STEP_AMOUNT_REQUIRED": "Geef elke stap een bedrag.", "STEP_DUE": "Deadline", "STEP_DESCRIPTION_PLACEHOLDER": "Wat er bij deze stap hoort", "STEPS_MUST_ADD_UP": "De stappen moeten samen {total} zijn.", "STEPS_ADD_UP": "De stappen komen samen uit op de prijs ✓", "STEPS_REST": "Nog te verdelen: {rest}", "STEPS_TOTAL_MISMATCH": "De stappen zijn samen {steps}, de afgesproken prijs is {total}.", "REMOVE_STEP": "Stap verwijderen", "ADD_STEP": "Stap toevoegen", "ADD_STEP_INTRO": "De klant keurt elke stap goed als die klaar is.", "EDIT_STEP": "Stap bewerken", "DELETE_STEP": "Stap verwijderen", "DELETE_STEP_TITLE": "Deze stap verwijderen?", "DELETE_STEP_TEXT": "“{title}” wordt van de overeenkomst verwijderd.", "STEP_STARTED_NO_DELETE": "Deze stap is al begonnen, dus je kunt hem wijzigen maar niet verwijderen.", "CREATE_CONTRACT": "Overeenkomst maken", "JOB_HAS_CONTRACT": "Deze klus heeft al een overeenkomst.", "JOB_NOT_YOURS": "Alleen degene die de klus heeft gemaakt, kan hem wijzigen.", "JOB_CANNOT_EDIT": "Er is al iemand ingehuurd, dus de klus kan niet meer worden gewijzigd.", "EDIT_JOB": "Klus bewerken", "EDIT_JOB_INTRO": "Vakmensen zien de wijzigingen meteen.", "EDIT_JOB_WITH_OFFERS": "Ontvangen offertes: {n}. Laat grote wijzigingen in de chat aan de vakmensen weten, zodat hun offertes nog kloppen.", "CREATED_AGO": "Gemaakt {time}", "DRAFT_NOT_VISIBLE": "Dit is een concept. Vakmensen zien het pas als je het publiceert.", "CANCEL_JOB": "Klus annuleren", "CANCEL_JOB_TITLE": "Deze klus annuleren?", "CANCEL_JOB_TEXT": "De klus wordt offline gehaald en kan niet opnieuw worden geopend.", "CANCEL_JOB_WITH_OFFERS_TEXT": "De klus wordt offline gehaald en de vakmensen die een offerte stuurden ({n}) horen dat hij is geannuleerd.", "DELETE_JOB_TITLE": "Het concept verwijderen?", "DELETE_JOB_TEXT": "Het concept wordt definitief verwijderd.", "CANCEL_CONTRACT": "De overeenkomst annuleren", "CANCEL_CONTRACT_INTRO": "Het werk stopt hier. Goedgekeurde stappen en facturen blijven bewaard, en de andere partij krijgt bericht.", "CANCEL_REASON": "Waarom? (optioneel)", "CANCEL_REASON_PLACEHOLDER": "Een paar woorden die jullie later allebei kunnen zien", "CONTRACT_CANCELLED_ON": "Geannuleerd op {date}", "COMPLETE_CLIENT_JOB_TEXT": "Alle stappen zijn afgetekend. De klus wordt als afgerond gemarkeerd.", "SIGN_ON_SITE": "Klant tekent", "SIGN_ON_SITE_INTRO": "Laat de klant het werk controleren en met een vinger op het scherm tekenen. Daarmee wordt de stap goedgekeurd.", "CUSTOMER_NAME": "Naam van de klant", "SIGNATURE": "Handtekening", "SIGN_HERE": "Hier tekenen", "APPROVE_WITH_SIGNATURE": "Goedkeuren met handtekening", "CHANGE_PASSWORD": "Wachtwoord wijzigen", "CHANGE_PASSWORD_INTRO": "Hier blijf je ingelogd. Op je andere telefoons en browsers word je uitgelogd.", "CURRENT_PASSWORD": "Huidig wachtwoord", "CURRENT_PASSWORD_REQUIRED": "Vul je huidige wachtwoord in.", "CURRENT_PASSWORD_WRONG": "Dat is niet je huidige wachtwoord.", "NEW_PASSWORD": "Nieuw wachtwoord", "REPEAT_PASSWORD": "Herhaal nieuw wachtwoord", "PASSWORDS_DONT_MATCH": "De wachtwoorden komen niet overeen.", "PASSWORD_SAME_AS_OLD": "Kies een wachtwoord dat je hier nog niet hebt gebruikt.", "PASSWORD_CHANGED": "Wachtwoord gewijzigd", "PAYMENTS": "Betalingen", "PAYMENT": "Betaling", "NO_PAYMENTS": "Nog geen betalingen", "NO_PAYMENTS_TEXT": "Betalingen via de app verschijnen hier. Klussen die per factuur zijn betaald, staan onder Facturen.", "PAYMENT_STATUS_PENDING": "In afwachting", "PAYMENT_STATUS_HELD": "Veilig vastgehouden", "PAYMENT_STATUS_RELEASED": "Uitbetaald", "PAYMENT_STATUS_REFUNDED": "Terugbetaald", "PAYMENT_STATUS_FAILED": "Mislukt", "PLATFORM_FEE": "Servicekosten {fee}", "TEAM": "Team", "TEAM_ROW_HINT": "De mensen die in het bedrijf werken", "TEAM_MANAGE_HINT": "Collega’s hebben eerst een Qup Work-account nodig. Tik op iemand om diegene te wijzigen of te verwijderen.", "TEAM_WORKER_HINT": "De eigenaar en beheerders voegen collega’s toe en verwijderen ze.", "ADD_MEMBER": "Collega toevoegen", "ADD_MEMBER_INTRO": "Gebruik het e-mailadres waarmee diegene zich bij Qup Work heeft aangemeld.", "MEMBER_NOT_FOUND": "Nog niemand heeft zich met dat e-mailadres aangemeld. Vraag diegene eerst een account aan te maken.", "MEMBER_ALREADY": "Die persoon zit al in het bedrijf.", "ROLE": "Rol", "ROLE_ADMIN_HINT": "Beheerders kunnen de bedrijfsgegevens en factuurinstellingen wijzigen, en collega’s toevoegen.", "ROLE_WORKER_HINT": "Medewerkers zien de klussen van het bedrijf, registreren uren en doen het werk.", "REMOVE_FROM_COMPANY": "Uit bedrijf verwijderen", "REMOVE_MEMBER_TITLE": "Uit het bedrijf verwijderen?", "REMOVE_MEMBER_TEXT": "{name} ziet de klussen en klanten van het bedrijf niet meer.", "LEAVE_COMPANY": "Het bedrijf verlaten", "LEAVE_COMPANY_TITLE": "Het bedrijf verlaten?", "LEAVE_COMPANY_TEXT": "Je ziet de klussen en klanten van {name} niet meer.", "NOTIF_JOB_WITHDRAWN": "De klant heeft de klus geannuleerd", "INVOICE_EMAILED_TO": "{email} heeft de factuur als pdf ontvangen.", "INVOICE_NO_EMAIL": "Verzonden, maar niet gemaild: de klant heeft geen e-mailadres. Open de pdf en deel hem zelf, of gebruik Per e-mail versturen.", "INVOICE_EMAIL_NOT_SET_UP": "Verzonden, maar niet gemaild: e-mail is nog niet ingesteld op de server (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Verzonden, maar de e-mail is mislukt: {error}", "SEND_INVOICE_EMAIL_TO": "De pdf wordt gemaild naar {email}.", "SEND_INVOICE_NO_EMAIL": "Er is geen e-mailadres, dus hij wordt niet gemaild. Je kunt de pdf zelf delen.", "EMAIL_INVOICE": "Per e-mail versturen", "PREVIEW_PDF": "Pdf bekijken", "OPEN_PDF": "Pdf openen", "EMAILED": "Gemaild", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Niet gemaild", "INVOICE_LANGUAGE": "Taal van de factuur", "NOTIF_NEW_JOB_NEARBY": "Nieuwe klus bij jou in de buurt", "NOTIF_NEW_JOB_REMOTE": "Nieuwe klus op afstand", "NOTIF_JOB_INVITED": "Je bent uitgenodigd voor een klus", "NOTIF_JOB_IN_PLACE": "‘{job}’ in {place}", "JOB_ALERTS": "Meldingen over nieuwe klussen", "JOB_ALERTS_ON_TEXT": "Je krijgt een melding als er in jouw omgeving een klus in jouw categorieën wordt geplaatst.", "JOB_ALERTS_OFF_TEXT": "Je krijgt geen meldingen over nieuwe klussen, maar je kunt ze nog steeds in de app bekijken.", "JOB_ALERTS_NEEDS_VISIBLE": "Zet eerst zichtbaarheid aan. Alleen vakmensen die klanten kunnen vinden, krijgen klusmeldingen.", "FORGOT_PASSWORD": "Wachtwoord vergeten?", "FORGOT_PASSWORD_TITLE": "Nieuw wachtwoord", "FORGOT_PASSWORD_INTRO": "Vul het e-mailadres in waarmee je je hebt aangemeld, dan sturen we je een code.", "SEND_CODE": "Code versturen", "RESET_CODE_SENT": "Als {email} een account heeft, is er een 6-cijferige code onderweg. Vul die hieronder in met een nieuw wachtwoord.", "RESET_CODE": "Code uit de e-mail", "RESET_CODE_INVALID": "De code heeft 6 cijfers.", "RESET_CODE_WRONG": "De code is onjuist of verlopen. Vraag een nieuwe aan.", "SAVE_NEW_PASSWORD": "Opslaan en inloggen", "RESET_CODE_AGAIN": "Nieuwe code versturen", "RESET_CODE_RESENT": "Nieuwe code verstuurd", "RESET_CODE_SPAM_HINT": "Na een paar minuten nog geen e-mail? Kijk in je spammap.", "DELETE_ACCOUNT": "Account verwijderen", "DELETE_ACCOUNT_INTRO": "Hiermee verwijder je het account van {email}. Dit kan niet ongedaan worden gemaakt.", "DELETE_WHAT_GOES": "Wordt verwijderd", "DELETE_GOES_PROFILE": "Je naam, foto, telefoonnummer en e-mail", "DELETE_GOES_PRO": "Je vakmanprofiel, zodat klanten je niet meer kunnen vinden", "DELETE_GOES_JOBS": "Openstaande klussen die je hebt geplaatst, en offertes waar niemand op heeft gereageerd", "DELETE_GOES_LOGIN": "Je inloggegevens, op alle apparaten", "DELETE_WHAT_STAYS": "Blijft bewaard, zonder je naam", "DELETE_STAYS_CONTRACTS": "Afgeronde overeenkomsten, berichten en reviews, zodat de andere partij ze nog heeft", "DELETE_STAYS_INVOICES": "Facturen, die volgens de Noorse boekhoudregels 5 jaar bewaard moeten worden", "DELETE_PASSWORD_HINT": "Om zeker te weten dat jij het bent.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Je account verwijderen?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Je wordt uitgelogd en kunt met dit account niet meer inloggen.", "DELETE_BLOCKED_CONTRACTS": "Je hebt lopende overeenkomsten. Rond ze eerst af of annuleer ze, zodat de andere partij niet blijft wachten.", "DELETE_BLOCKED_COMPANY": "Je bent eigenaar van een bedrijf met andere leden. Verwijder ze eerst onder Team.", "JOB_CATEGORY_REQUIRED": "Kies een categorie, zodat de juiste vakmensen van de klus horen."}, "ja-JP": {"EDIT": "編集", "REMOVE": "削除", "CLEAR": "クリア", "ARCHIVE": "アーカイブ", "NOTES": "メモ", "YOU": "あなた", "DATE_PLACEHOLDER": "日日/月月/年年年年", "DATE_INVALID": "日付は日日/月月/年年年年の形式で入力してください。", "AMOUNT_INVALID": "金額をNOKで入力してください（例：5000）。", "EMAIL_INVALID": "メールアドレスが正しくないようです。", "POSTCODE_FORMAT": "郵便番号は4桁です。", "CLIENT": "顧客", "CLIENTS": "顧客", "CLIENTS_PRO_ONLY": "顧客リストはプロ向けの機能です。利用するにはプロのアカウントでログインしてください。", "SEARCH_CLIENTS": "顧客を検索", "CLIENTS_ACTIVE": "有効", "CLIENTS_ARCHIVED": "アーカイブ済み", "NO_CLIENTS": "まだ顧客がいません", "NO_CLIENTS_TEXT": "マーケットプレイス以外で仕事をしているお客様を追加して、案件・作業時間・請求書をまとめて管理しましょう。", "NO_CLIENTS_MATCH": "検索に一致する顧客はいません。", "NO_ARCHIVED_CLIENTS": "アーカイブはありません", "NO_ARCHIVED_CLIENTS_TEXT": "アーカイブした顧客は、過去の案件や請求書と一緒にここに表示されます。", "NEW_CLIENT": "新しい顧客", "EDIT_CLIENT": "顧客を編集", "SAVE_CLIENT": "顧客を保存", "CLIENT_FORM_INTRO": "この情報はあなたとあなたの会社だけが見られます。住所は新しい案件の作業場所として使われます。", "CLIENT_TYPE": "顧客の種類", "CLIENT_PRIVATE": "個人", "CLIENT_BUSINESS": "法人", "CLIENT_COMPANY_PLACEHOLDER": "例：Bergen Eiendom AS", "CONTACT_PERSON": "担当者", "CONTACT_NAME": "担当者：{name}", "CLIENT_EMAIL_HINT": "請求書をここに送れます。", "CLIENT_NOTES_PLACEHOLDER": "門の暗証番号、駐車場所、犬の名前…", "CLIENT_NOTES_HINT": "あなたと同僚だけが見られます。顧客には表示されません。", "CLIENT_NOT_FOUND": "顧客が見つかりません", "CLIENT_IS_ARCHIVED": "アーカイブ済み", "CLIENT_NO_DETAILS": "連絡先がまだありません。「編集」をタップして追加してください。", "CLIENT_JOBS": "案件", "CLIENT_NO_JOBS": "この顧客の案件はまだありません。", "ARCHIVE_CLIENT": "顧客をアーカイブ", "ARCHIVE_CLIENT_TITLE": "この顧客をアーカイブしますか？", "ARCHIVE_CLIENT_TEXT": "この顧客には案件があるため、案件や請求書と一緒に保管されます。あとで元に戻せます。", "RESTORE_CLIENT": "顧客を元に戻す", "DELETE_CLIENT": "顧客を削除", "DELETE_CLIENT_TITLE": "この顧客を削除しますか？", "DELETE_CLIENT_TEXT": "{name}さんが顧客リストから削除されます。", "NEW_ASSIGNMENT": "新しい案件", "NEW_ASSIGNMENT_INTRO": "自分の顧客の仕事を登録して、料金を決めましょう。契約からステップの追加、作業時間の記録、請求ができます。", "PICK_CLIENT_INTRO": "誰のための仕事ですか？", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "合意した内容、材料、顧客に知っておいてほしいこと", "START_DATE": "開始日", "END_DATE": "終了日", "END_BEFORE_START": "終了日が開始日より前になっています。", "STEPS_OPTIONAL_HINT": "任意です。ステップがない場合は、仕事全体が1つのステップになります。", "STEPS_SPLIT_HINT": "各ステップは個別に承認されます。金額の合計は料金と一致する必要があります。", "STEPS_HOURLY_HINT": "各ステップは個別に承認されます。作業時間は契約に記録されます。", "STEP_TITLE": "ステップ", "STEP_TITLE_PLACEHOLDER": "例：解体と排水工事", "STEP_TITLE_REQUIRED": "各ステップに名前を付けてください。", "STEP_AMOUNT": "金額（NOK）", "STEP_AMOUNT_REQUIRED": "各ステップに金額を入力してください。", "STEP_DUE": "期日", "STEP_DESCRIPTION_PLACEHOLDER": "このステップに含まれる内容", "STEPS_MUST_ADD_UP": "ステップの合計は{total}にする必要があります。", "STEPS_ADD_UP": "ステップの合計が料金と一致しています ✓", "STEPS_REST": "未配分：{rest}", "STEPS_TOTAL_MISMATCH": "ステップの合計は{steps}ですが、合意した料金は{total}です。", "REMOVE_STEP": "ステップを削除", "ADD_STEP": "ステップを追加", "ADD_STEP_INTRO": "お客様は各ステップが終わるたびに承認します。", "EDIT_STEP": "ステップを編集", "DELETE_STEP": "ステップを削除", "DELETE_STEP_TITLE": "このステップを削除しますか？", "DELETE_STEP_TEXT": "「{title}」が契約から削除されます。", "STEP_STARTED_NO_DELETE": "このステップは開始済みのため、変更はできますが削除はできません。", "CREATE_CONTRACT": "契約を作成", "JOB_HAS_CONTRACT": "この依頼にはすでに契約があります。", "JOB_NOT_YOURS": "依頼を変更できるのは作成した人だけです。", "JOB_CANNOT_EDIT": "すでにプロが決まっているため、依頼は変更できません。", "EDIT_JOB": "依頼を編集", "EDIT_JOB_INTRO": "変更内容はすぐにプロに表示されます。", "EDIT_JOB_WITH_OFFERS": "届いた見積もり：{n}件。大きな変更はチャットでプロに伝えて、見積もりが内容に合うようにしましょう。", "CREATED_AGO": "{time}に作成", "DRAFT_NOT_VISIBLE": "これは下書きです。公開するまでプロには表示されません。", "CANCEL_JOB": "依頼をキャンセル", "CANCEL_JOB_TITLE": "この依頼をキャンセルしますか？", "CANCEL_JOB_TEXT": "依頼は取り下げられ、再開することはできません。", "CANCEL_JOB_WITH_OFFERS_TEXT": "依頼は取り下げられ、見積もりを送ったプロ（{n}人）にキャンセルが通知されます。", "DELETE_JOB_TITLE": "下書きを削除しますか？", "DELETE_JOB_TEXT": "下書きは完全に削除されます。", "CANCEL_CONTRACT": "契約をキャンセル", "CANCEL_CONTRACT_INTRO": "作業はここで終了します。承認済みのステップと請求書は残り、相手側に通知されます。", "CANCEL_REASON": "理由（任意）", "CANCEL_REASON_PLACEHOLDER": "あとでお互いに見られる短いひと言", "CONTRACT_CANCELLED_ON": "{date}にキャンセル", "COMPLETE_CLIENT_JOB_TEXT": "すべてのステップに署名済みです。案件は完了としてマークされます。", "SIGN_ON_SITE": "お客様の署名", "SIGN_ON_SITE_INTRO": "お客様に作業を確認してもらい、画面に指で署名してもらいます。これでステップが承認されます。", "CUSTOMER_NAME": "お客様の名前", "SIGNATURE": "署名", "SIGN_HERE": "ここに署名", "APPROVE_WITH_SIGNATURE": "署名して承認", "CHANGE_PASSWORD": "パスワードを変更", "CHANGE_PASSWORD_INTRO": "この端末ではログインしたままです。ほかのスマートフォンやブラウザからはログアウトされます。", "CURRENT_PASSWORD": "現在のパスワード", "CURRENT_PASSWORD_REQUIRED": "現在のパスワードを入力してください。", "CURRENT_PASSWORD_WRONG": "現在のパスワードが正しくありません。", "NEW_PASSWORD": "新しいパスワード", "REPEAT_PASSWORD": "新しいパスワード（確認）", "PASSWORDS_DONT_MATCH": "パスワードが一致しません。", "PASSWORD_SAME_AS_OLD": "ここで使ったことのないパスワードを選んでください。", "PASSWORD_CHANGED": "パスワードを変更しました", "PAYMENTS": "支払い", "PAYMENT": "支払い", "NO_PAYMENTS": "まだ支払いはありません", "NO_PAYMENTS_TEXT": "アプリで行った支払いがここに表示されます。請求書で支払った依頼は「請求書」にあります。", "PAYMENT_STATUS_PENDING": "保留中", "PAYMENT_STATUS_HELD": "安全に預かり中", "PAYMENT_STATUS_RELEASED": "支払い済み", "PAYMENT_STATUS_REFUNDED": "返金済み", "PAYMENT_STATUS_FAILED": "失敗", "PLATFORM_FEE": "手数料 {fee}", "TEAM": "チーム", "TEAM_ROW_HINT": "会社で働いているメンバー", "TEAM_MANAGE_HINT": "同僚には先にQup Workのアカウントが必要です。メンバーをタップすると変更や削除ができます。", "TEAM_WORKER_HINT": "同僚の追加と削除はオーナーと管理者が行います。", "ADD_MEMBER": "同僚を追加", "ADD_MEMBER_INTRO": "相手がQup Workに登録したメールアドレスを使ってください。", "MEMBER_NOT_FOUND": "そのメールアドレスで登録した人はまだいません。先にアカウントを作成してもらってください。", "MEMBER_ALREADY": "その人はすでに会社のメンバーです。", "ROLE": "役割", "ROLE_ADMIN_HINT": "管理者は会社情報や請求書の設定を変更したり、同僚を追加したりできます。", "ROLE_WORKER_HINT": "スタッフは会社の案件を確認し、作業時間を記録して作業を行います。", "REMOVE_FROM_COMPANY": "会社から削除", "REMOVE_MEMBER_TITLE": "会社から削除しますか？", "REMOVE_MEMBER_TEXT": "{name}さんは会社の案件や顧客を見られなくなります。", "LEAVE_COMPANY": "会社を退出", "LEAVE_COMPANY_TITLE": "会社を退出しますか？", "LEAVE_COMPANY_TEXT": "{name}の案件や顧客が見られなくなります。", "NOTIF_JOB_WITHDRAWN": "依頼者が依頼をキャンセルしました", "INVOICE_EMAILED_TO": "{email} に請求書のPDFが届きました。", "INVOICE_NO_EMAIL": "送信しましたが、メールでは送っていません：お客様のメールアドレスがありません。PDFを開いてご自身で共有するか、「メールで送信」を使ってください。", "INVOICE_EMAIL_NOT_SET_UP": "送信しましたが、メールでは送っていません：サーバーでメールがまだ設定されていません（RESEND_API_KEY）。", "INVOICE_EMAIL_FAILED": "送信しましたが、メールに失敗しました：{error}", "SEND_INVOICE_EMAIL_TO": "PDFは {email} にメールで送られます。", "SEND_INVOICE_NO_EMAIL": "メールアドレスがないため、メールでは送られません。PDFはご自身で共有できます。", "EMAIL_INVOICE": "メールで送信", "PREVIEW_PDF": "PDFをプレビュー", "OPEN_PDF": "PDFを開く", "EMAILED": "メール送信済み", "EMAILED_ON": "{email}、{date}", "NOT_EMAILED": "メール未送信", "INVOICE_LANGUAGE": "請求書の言語", "NOTIF_NEW_JOB_NEARBY": "近くで新しい仕事", "NOTIF_NEW_JOB_REMOTE": "新しいリモートの仕事", "NOTIF_JOB_INVITED": "仕事に招待されました", "NOTIF_JOB_IN_PLACE": "「{job}」（{place}）", "JOB_ALERTS": "新しい仕事の通知", "JOB_ALERTS_ON_TEXT": "あなたの地域であなたのカテゴリーの仕事が掲載されると通知が届きます。", "JOB_ALERTS_OFF_TEXT": "新しい仕事の通知は届きませんが、アプリで引き続き見ることができます。", "JOB_ALERTS_NEEDS_VISIBLE": "まず公開をオンにしてください。お客様が見つけられるプロだけが仕事の通知を受け取ります。", "FORGOT_PASSWORD": "パスワードをお忘れですか？", "FORGOT_PASSWORD_TITLE": "新しいパスワード", "FORGOT_PASSWORD_INTRO": "登録したメールアドレスを入力してください。コードをお送りします。", "SEND_CODE": "コードを送信", "RESET_CODE_SENT": "{email} のアカウントがある場合、6桁のコードをお送りしました。新しいパスワードと一緒に下に入力してください。", "RESET_CODE": "メールに記載されたコード", "RESET_CODE_INVALID": "コードは6桁です。", "RESET_CODE_WRONG": "コードが間違っているか、有効期限が切れています。新しいコードをリクエストしてください。", "SAVE_NEW_PASSWORD": "保存してログイン", "RESET_CODE_AGAIN": "新しいコードを送信", "RESET_CODE_RESENT": "新しいコードを送信しました", "RESET_CODE_SPAM_HINT": "数分たってもメールが届かない場合は、迷惑メールフォルダを確認してください。", "DELETE_ACCOUNT": "アカウントを削除", "DELETE_ACCOUNT_INTRO": "{email} のアカウントを削除します。この操作は取り消せません。", "DELETE_WHAT_GOES": "削除されるもの", "DELETE_GOES_PROFILE": "名前、写真、電話番号、メールアドレス", "DELETE_GOES_PRO": "プロのプロフィール（お客様から見つけられなくなります）", "DELETE_GOES_JOBS": "投稿した募集中の依頼と、まだ返答のない見積もり", "DELETE_GOES_LOGIN": "すべての端末でのログイン", "DELETE_WHAT_STAYS": "名前を除いて保存されるもの", "DELETE_STAYS_CONTRACTS": "完了した契約、メッセージ、口コミ（相手側が引き続き確認できるように）", "DELETE_STAYS_INVOICES": "請求書（ノルウェーの帳簿規則により5年間の保存が義務付けられています）", "DELETE_PASSWORD_HINT": "ご本人確認のためです。", "DELETE_ACCOUNT_CONFIRM_TITLE": "アカウントを削除しますか？", "DELETE_ACCOUNT_CONFIRM_TEXT": "ログアウトされ、このアカウントで再びログインすることはできなくなります。", "DELETE_BLOCKED_CONTRACTS": "進行中の契約があります。相手側を待たせないよう、先に完了またはキャンセルしてください。", "DELETE_BLOCKED_COMPANY": "ほかのメンバーがいる会社を所有しています。先に「チーム」でメンバーを削除してください。", "JOB_CATEGORY_REQUIRED": "カテゴリを選んでください。適切なプロに依頼が届くようになります。"}, "et-EE": {"EDIT": "Muuda", "REMOVE": "Eemalda", "CLEAR": "Tühjenda", "ARCHIVE": "Arhiveeri", "NOTES": "Märkmed", "YOU": "sina", "DATE_PLACEHOLDER": "pp.kk.aaaa", "DATE_INVALID": "Kirjuta kuupäev kujul pp.kk.aaaa.", "AMOUNT_INVALID": "Kirjuta summa NOK-des, nt 5000.", "EMAIL_INVALID": "See e-posti aadress ei tundu õige.", "POSTCODE_FORMAT": "Postiindeksis on 4 numbrit.", "CLIENT": "Klient", "CLIENTS": "Kliendid", "CLIENTS_PRO_ONLY": "Oma kliendiregister on meistritele. Selle kasutamiseks logi sisse meistrikontoga.", "SEARCH_CLIENTS": "Otsi kliente", "CLIENTS_ACTIVE": "Aktiivsed", "CLIENTS_ARCHIVED": "Arhiveeritud", "NO_CLIENTS": "Kliente veel pole", "NO_CLIENTS_TEXT": "Lisa kliendid, kellele töötad väljaspool platvormi, ja hoia nende tööd, tunnid ja arved ühes kohas.", "NO_CLIENTS_MATCH": "Otsingule ei vasta ükski klient.", "NO_ARCHIVED_CLIENTS": "Arhiivis pole midagi", "NO_ARCHIVED_CLIENTS_TEXT": "Arhiveeritud kliendid jõuavad siia koos oma varasemate tööde ja arvetega.", "NEW_CLIENT": "Uus klient", "EDIT_CLIENT": "Muuda klienti", "SAVE_CLIENT": "Salvesta klient", "CLIENT_FORM_INTRO": "Seda näed ainult sina ja sinu ettevõte. Aadressi kasutatakse uute tööde tööaadressina.", "CLIENT_TYPE": "Kliendi tüüp", "CLIENT_PRIVATE": "Eraisik", "CLIENT_BUSINESS": "Ettevõte", "CLIENT_COMPANY_PLACEHOLDER": "Nt Bergen Eiendom AS", "CONTACT_PERSON": "Kontaktisik", "CONTACT_NAME": "Kontakt: {name}", "CLIENT_EMAIL_HINT": "Arveid saab saata siia.", "CLIENT_NOTES_PLACEHOLDER": "Värava kood, parkimine, koera nimi…", "CLIENT_NOTES_HINT": "Ainult sulle ja sinu kolleegidele, kliendile ei näidata seda kunagi.", "CLIENT_NOT_FOUND": "Klienti ei leitud", "CLIENT_IS_ARCHIVED": "Arhiveeritud", "CLIENT_NO_DETAILS": "Kontaktandmeid veel pole. Lisamiseks puuduta „Muuda“.", "CLIENT_JOBS": "Tööd", "CLIENT_NO_JOBS": "Sellel kliendil pole veel töid.", "ARCHIVE_CLIENT": "Arhiveeri klient", "ARCHIVE_CLIENT_TITLE": "Kas arhiveerid selle kliendi?", "ARCHIVE_CLIENT_TEXT": "Kliendil on töid, seega säilitatakse ta koos tööde ja arvetega. Hiljem saad ta taastada.", "RESTORE_CLIENT": "Taasta klient", "DELETE_CLIENT": "Kustuta klient", "DELETE_CLIENT_TITLE": "Kas kustutad selle kliendi?", "DELETE_CLIENT_TEXT": "{name} eemaldatakse sinu registrist.", "NEW_ASSIGNMENT": "Uus tööots", "NEW_ASSIGNMENT_INTRO": "Registreeri töö oma kliendile ja leppige hind kokku. Lepingus saad lisada etappe, sisestada tunde ja arveid koostada.", "PICK_CLIENT_INTRO": "Kellele töö tehakse?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Mis on kokku lepitud, materjalid, kõik, mida klient peaks teadma", "START_DATE": "Alguskuupäev", "END_DATE": "Lõppkuupäev", "END_BEFORE_START": "Lõppkuupäev on enne alguskuupäeva.", "STEPS_OPTIONAL_HINT": "Valikuline. Ilma etappideta on kogu töö üks etapp.", "STEPS_SPLIT_HINT": "Iga etapp kinnitatakse eraldi. Summad peavad kokku andma hinna.", "STEPS_HOURLY_HINT": "Iga etapp kinnitatakse eraldi. Tunnid sisestatakse lepingule.", "STEP_TITLE": "Etapp", "STEP_TITLE_PLACEHOLDER": "Nt lammutus ja drenaaž", "STEP_TITLE_REQUIRED": "Anna igale etapile nimi.", "STEP_AMOUNT": "Summa (NOK)", "STEP_AMOUNT_REQUIRED": "Anna igale etapile summa.", "STEP_DUE": "Tähtaeg", "STEP_DESCRIPTION_PLACEHOLDER": "Mis sellesse etappi kuulub", "STEPS_MUST_ADD_UP": "Etapid peavad kokku andma {total}.", "STEPS_ADD_UP": "Etapid annavad kokku hinna ✓", "STEPS_REST": "Jagada jäänud: {rest}", "STEPS_TOTAL_MISMATCH": "Etapid annavad kokku {steps}, kokkulepitud hind on {total}.", "REMOVE_STEP": "Eemalda etapp", "ADD_STEP": "Lisa etapp", "ADD_STEP_INTRO": "Klient kinnitab iga etapi, kui see on valmis.", "EDIT_STEP": "Muuda etappi", "DELETE_STEP": "Kustuta etapp", "DELETE_STEP_TITLE": "Kas kustutad selle etapi?", "DELETE_STEP_TEXT": "„{title}“ eemaldatakse lepingust.", "STEP_STARTED_NO_DELETE": "See etapp on alanud, seega saab seda muuta, aga mitte kustutada.", "CREATE_CONTRACT": "Loo leping", "JOB_HAS_CONTRACT": "Sellel tööl on juba leping.", "JOB_NOT_YOURS": "Tööd saab muuta ainult selle looja.", "JOB_CANNOT_EDIT": "Keegi on juba palgatud, seega tööd enam muuta ei saa.", "EDIT_JOB": "Muuda tööd", "EDIT_JOB_INTRO": "Meistrid näevad muudatusi kohe.", "EDIT_JOB_WITH_OFFERS": "Saadud pakkumisi: {n}. Anna suurtest muudatustest meistritele vestluses teada, et nende pakkumised ikka sobiksid.", "CREATED_AGO": "Loodud {time}", "DRAFT_NOT_VISIBLE": "See on mustand. Meistrid ei näe seda enne, kui selle avaldad.", "CANCEL_JOB": "Tühista töö", "CANCEL_JOB_TITLE": "Kas tühistad selle töö?", "CANCEL_JOB_TEXT": "Töö võetakse maha ja seda ei saa uuesti avada.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Töö võetakse maha ja pakkumise saatnud meistritele ({n}) teatatakse, et see tühistati.", "DELETE_JOB_TITLE": "Kas kustutad mustandi?", "DELETE_JOB_TEXT": "Mustand kustutatakse jäädavalt.", "CANCEL_CONTRACT": "Tühista leping", "CANCEL_CONTRACT_INTRO": "Töö lõpeb siin. Kinnitatud etapid ja arved säilivad ning teisele poolele antakse teada.", "CANCEL_REASON": "Miks? (valikuline)", "CANCEL_REASON_PLACEHOLDER": "Paar sõna, mida te mõlemad hiljem näete", "CONTRACT_CANCELLED_ON": "Tühistatud {date}", "COMPLETE_CLIENT_JOB_TEXT": "Kõik etapid on kinnitatud. Töö märgitakse lõpetatuks.", "SIGN_ON_SITE": "Klient allkirjastab", "SIGN_ON_SITE_INTRO": "Lase kliendil töö üle vaadata ja sõrmega ekraanile allkiri anda. Sellega kinnitatakse etapp.", "CUSTOMER_NAME": "Kliendi nimi", "SIGNATURE": "Allkiri", "SIGN_HERE": "Allkirjasta siin", "APPROVE_WITH_SIGNATURE": "Kinnita allkirjaga", "CHANGE_PASSWORD": "Muuda parooli", "CHANGE_PASSWORD_INTRO": "Siin jääd sisselogituks. Sinu teistest telefonidest ja brauseritest logitakse välja.", "CURRENT_PASSWORD": "Praegune parool", "CURRENT_PASSWORD_REQUIRED": "Sisesta oma praegune parool.", "CURRENT_PASSWORD_WRONG": "See pole sinu praegune parool.", "NEW_PASSWORD": "Uus parool", "REPEAT_PASSWORD": "Korda uut parooli", "PASSWORDS_DONT_MATCH": "Paroolid ei kattu.", "PASSWORD_SAME_AS_OLD": "Vali parool, mida sa pole siin varem kasutanud.", "PASSWORD_CHANGED": "Parool muudetud", "PAYMENTS": "Maksed", "PAYMENT": "Makse", "NO_PAYMENTS": "Makseid veel pole", "NO_PAYMENTS_TEXT": "Äpi kaudu tehtud maksed ilmuvad siia. Arvega makstud tööd on jaotises Arved.", "PAYMENT_STATUS_PENDING": "Ootel", "PAYMENT_STATUS_HELD": "Turvaliselt hoiul", "PAYMENT_STATUS_RELEASED": "Välja makstud", "PAYMENT_STATUS_REFUNDED": "Tagastatud", "PAYMENT_STATUS_FAILED": "Ebaõnnestus", "PLATFORM_FEE": "Tasu {fee}", "TEAM": "Meeskond", "TEAM_ROW_HINT": "Ettevõttes töötavad inimesed", "TEAM_MANAGE_HINT": "Kolleegidel peab esmalt olema Qup Worki konto. Muutmiseks või eemaldamiseks puuduta inimest.", "TEAM_WORKER_HINT": "Kolleege lisavad ja eemaldavad omanik ja administraatorid.", "ADD_MEMBER": "Lisa kolleeg", "ADD_MEMBER_INTRO": "Kasuta e-posti, millega ta Qup Worki registreerus.", "MEMBER_NOT_FOUND": "Selle e-postiga pole veel keegi registreerunud. Palu tal esmalt konto luua.", "MEMBER_ALREADY": "See inimene on juba ettevõttes.", "ROLE": "Roll", "ROLE_ADMIN_HINT": "Administraatorid saavad muuta ettevõtte andmeid ja arveseadeid ning lisada kolleege.", "ROLE_WORKER_HINT": "Töötajad näevad ettevõtte töid, sisestavad tunde ja teevad tööd.", "REMOVE_FROM_COMPANY": "Eemalda ettevõttest", "REMOVE_MEMBER_TITLE": "Kas eemaldad ettevõttest?", "REMOVE_MEMBER_TEXT": "{name} ei näe enam ettevõtte töid ja kliente.", "LEAVE_COMPANY": "Lahku ettevõttest", "LEAVE_COMPANY_TITLE": "Kas lahkud ettevõttest?", "LEAVE_COMPANY_TEXT": "Sa ei näe enam ettevõtte {name} töid ja kliente.", "NOTIF_JOB_WITHDRAWN": "Klient tühistas töö", "INVOICE_EMAILED_TO": "{email} sai arve PDF-ina.", "INVOICE_NO_EMAIL": "Saadetud, aga mitte e-postiga: kliendil pole e-posti aadressi. Ava PDF ja jaga seda ise või kasuta nuppu Saada e-postiga.", "INVOICE_EMAIL_NOT_SET_UP": "Saadetud, aga mitte e-postiga: e-post pole serveris veel seadistatud (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Saadetud, aga e-kiri ebaõnnestus: {error}", "SEND_INVOICE_EMAIL_TO": "PDF saadetakse e-postiga aadressile {email}.", "SEND_INVOICE_NO_EMAIL": "E-posti aadressi pole, seega e-postiga ei saadeta. PDF-i saad ise jagada.", "EMAIL_INVOICE": "Saada e-postiga", "PREVIEW_PDF": "PDF-i eelvaade", "OPEN_PDF": "Ava PDF", "EMAILED": "Saadetud e-postiga", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "E-postiga saatmata", "INVOICE_LANGUAGE": "Arve keel", "NOTIF_NEW_JOB_NEARBY": "Uus töö sinu lähedal", "NOTIF_NEW_JOB_REMOTE": "Uus kaugtöö", "NOTIF_JOB_INVITED": "Sind kutsuti tööle", "NOTIF_JOB_IN_PLACE": "„{job}“ – {place}", "JOB_ALERTS": "Teavitused uutest töödest", "JOB_ALERTS_ON_TEXT": "Saad teavituse, kui sinu piirkonnas avaldatakse töö sinu kategooriates.", "JOB_ALERTS_OFF_TEXT": "Uutest töödest sind ei teavitata, kuid näed neid endiselt rakenduses.", "JOB_ALERTS_NEEDS_VISIBLE": "Lülita kõigepealt nähtavus sisse. Teavitusi saavad ainult meistrid, keda kliendid leiavad.", "FORGOT_PASSWORD": "Unustasid parooli?", "FORGOT_PASSWORD_TITLE": "Uus parool", "FORGOT_PASSWORD_INTRO": "Sisesta e-posti aadress, millega registreerusid, ja me saadame sulle koodi.", "SEND_CODE": "Saada kood", "RESET_CODE_SENT": "Kui aadressiga {email} on konto olemas, on 6-kohaline kood teel. Sisesta see allpool koos uue parooliga.", "RESET_CODE": "Kood e-kirjast", "RESET_CODE_INVALID": "Koodis on 6 numbrit.", "RESET_CODE_WRONG": "Kood on vale või aegunud. Küsi uus.", "SAVE_NEW_PASSWORD": "Salvesta ja logi sisse", "RESET_CODE_AGAIN": "Saada uus kood", "RESET_CODE_RESENT": "Uus kood saadetud", "RESET_CODE_SPAM_HINT": "Paari minuti pärast pole e-kirja? Vaata rämpspostikausta.", "DELETE_ACCOUNT": "Kustuta konto", "DELETE_ACCOUNT_INTRO": "See kustutab aadressi {email} konto. Seda ei saa tagasi võtta.", "DELETE_WHAT_GOES": "Kustutatakse", "DELETE_GOES_PROFILE": "Sinu nimi, foto, telefon ja e-post", "DELETE_GOES_PRO": "Sinu meistri profiil, nii et kliendid ei leia sind enam", "DELETE_GOES_JOBS": "Sinu lisatud avatud tööd ja pakkumised, millele keegi pole vastanud", "DELETE_GOES_LOGIN": "Sinu sisselogimine kõigis seadmetes", "DELETE_WHAT_STAYS": "Säilitatakse, ilma sinu nimeta", "DELETE_STAYS_CONTRACTS": "Lõpetatud lepingud, sõnumid ja arvustused, et need jääksid teisele poolele alles", "DELETE_STAYS_INVOICES": "Arved, mida Norra raamatupidamisreeglid nõuavad säilitada 5 aastat", "DELETE_PASSWORD_HINT": "Et olla kindel, et see oled sina.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Kas kustutada konto?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Sind logitakse välja ja sa ei saa selle kontoga enam sisse logida.", "DELETE_BLOCKED_CONTRACTS": "Sul on pooleliolevaid lepinguid. Vii need enne lõpuni või tühista, et teine pool ei peaks ootama.", "DELETE_BLOCKED_COMPANY": "Sulle kuulub ettevõte, millel on teisi liikmeid. Eemalda nad enne jaotises Meeskond.", "JOB_CATEGORY_REQUIRED": "Vali kategooria, et õiged meistrid tööst kuuleksid."}, "fr-FR": {"EDIT": "Modifier", "REMOVE": "Retirer", "CLEAR": "Effacer", "ARCHIVE": "Archiver", "NOTES": "Notes", "YOU": "vous", "DATE_PLACEHOLDER": "jj/mm/aaaa", "DATE_INVALID": "Saisissez la date au format jj/mm/aaaa.", "AMOUNT_INVALID": "Saisissez un montant en NOK, par ex. 5000.", "EMAIL_INVALID": "Cette adresse e-mail ne semble pas correcte.", "POSTCODE_FORMAT": "Un code postal comporte 4 chiffres.", "CLIENT": "Client", "CLIENTS": "Clients", "CLIENTS_PRO_ONLY": "Le fichier clients est réservé aux pros. Connectez-vous avec un compte pro pour l’utiliser.", "SEARCH_CLIENTS": "Rechercher des clients", "CLIENTS_ACTIVE": "Actifs", "CLIENTS_ARCHIVED": "Archivés", "NO_CLIENTS": "Aucun client pour l’instant", "NO_CLIENTS_TEXT": "Ajoutez les clients pour qui vous travaillez en dehors de la plateforme, et gardez leurs missions, heures et factures au même endroit.", "NO_CLIENTS_MATCH": "Aucun client ne correspond à votre recherche.", "NO_ARCHIVED_CLIENTS": "Rien d’archivé", "NO_ARCHIVED_CLIENTS_TEXT": "Les clients que vous archivez arrivent ici, avec leurs anciennes missions et factures.", "NEW_CLIENT": "Nouveau client", "EDIT_CLIENT": "Modifier le client", "SAVE_CLIENT": "Enregistrer le client", "CLIENT_FORM_INTRO": "Seuls vous et votre entreprise pouvez voir ces informations. L’adresse sert d’adresse d’intervention pour les nouvelles missions.", "CLIENT_TYPE": "Type de client", "CLIENT_PRIVATE": "Particulier", "CLIENT_BUSINESS": "Entreprise", "CLIENT_COMPANY_PLACEHOLDER": "Par ex. Bergen Eiendom AS", "CONTACT_PERSON": "Personne à contacter", "CONTACT_NAME": "Contact : {name}", "CLIENT_EMAIL_HINT": "Les factures peuvent être envoyées ici.", "CLIENT_NOTES_PLACEHOLDER": "Code du portail, stationnement, le nom du chien…", "CLIENT_NOTES_HINT": "Réservé à vous et à vos collègues, jamais visible par le client.", "CLIENT_NOT_FOUND": "Client introuvable", "CLIENT_IS_ARCHIVED": "Archivé", "CLIENT_NO_DETAILS": "Pas encore de coordonnées. Touchez Modifier pour les ajouter.", "CLIENT_JOBS": "Missions", "CLIENT_NO_JOBS": "Aucune mission pour ce client pour l’instant.", "ARCHIVE_CLIENT": "Archiver le client", "ARCHIVE_CLIENT_TITLE": "Archiver ce client ?", "ARCHIVE_CLIENT_TEXT": "Ce client a des missions, il est donc conservé avec ses missions et factures. Vous pourrez le restaurer plus tard.", "RESTORE_CLIENT": "Restaurer le client", "DELETE_CLIENT": "Supprimer le client", "DELETE_CLIENT_TITLE": "Supprimer ce client ?", "DELETE_CLIENT_TEXT": "{name} est retiré de votre fichier.", "NEW_ASSIGNMENT": "Nouvelle intervention", "NEW_ASSIGNMENT_INTRO": "Enregistrez un travail pour votre propre client et convenez du prix. Depuis le contrat, vous pourrez ajouter des étapes, saisir des heures et facturer.", "PICK_CLIENT_INTRO": "Pour qui est ce travail ?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Ce qui est convenu, les matériaux, ce que le client doit savoir", "START_DATE": "Date de début", "END_DATE": "Date de fin", "END_BEFORE_START": "La date de fin est antérieure à la date de début.", "STEPS_OPTIONAL_HINT": "Facultatif. Sans étapes, toute la mission forme une seule étape.", "STEPS_SPLIT_HINT": "Chaque étape est validée séparément. La somme des montants doit correspondre au prix.", "STEPS_HOURLY_HINT": "Chaque étape est validée séparément. Les heures sont saisies sur le contrat.", "STEP_TITLE": "Étape", "STEP_TITLE_PLACEHOLDER": "Par ex. Démolition et évacuation", "STEP_TITLE_REQUIRED": "Donnez un nom à chaque étape.", "STEP_AMOUNT": "Montant (NOK)", "STEP_AMOUNT_REQUIRED": "Indiquez un montant pour chaque étape.", "STEP_DUE": "Échéance", "STEP_DESCRIPTION_PLACEHOLDER": "Ce que comprend cette étape", "STEPS_MUST_ADD_UP": "La somme des étapes doit faire {total}.", "STEPS_ADD_UP": "La somme des étapes correspond au prix ✓", "STEPS_REST": "Reste à répartir : {rest}", "STEPS_TOTAL_MISMATCH": "La somme des étapes fait {steps}, le prix convenu est de {total}.", "REMOVE_STEP": "Retirer l’étape", "ADD_STEP": "Ajouter une étape", "ADD_STEP_INTRO": "Le client valide chaque étape une fois terminée.", "EDIT_STEP": "Modifier l’étape", "DELETE_STEP": "Supprimer l’étape", "DELETE_STEP_TITLE": "Supprimer cette étape ?", "DELETE_STEP_TEXT": "« {title} » est retirée du contrat.", "STEP_STARTED_NO_DELETE": "Cette étape a commencé : elle peut être modifiée, mais pas supprimée.", "CREATE_CONTRACT": "Créer le contrat", "JOB_HAS_CONTRACT": "Cette mission a déjà un contrat.", "JOB_NOT_YOURS": "Seule la personne qui a créé la mission peut la modifier.", "JOB_CANNOT_EDIT": "Quelqu’un a déjà été engagé, la mission ne peut donc plus être modifiée.", "EDIT_JOB": "Modifier la mission", "EDIT_JOB_INTRO": "Les pros voient les modifications immédiatement.", "EDIT_JOB_WITH_OFFERS": "Devis reçus : {n}. Prévenez les pros des changements importants dans le chat, pour que leurs devis restent valables.", "CREATED_AGO": "Créée {time}", "DRAFT_NOT_VISIBLE": "Ceci est un brouillon. Les pros ne le verront qu’une fois publié.", "CANCEL_JOB": "Annuler la mission", "CANCEL_JOB_TITLE": "Annuler cette mission ?", "CANCEL_JOB_TEXT": "La mission est retirée et ne peut pas être rouverte.", "CANCEL_JOB_WITH_OFFERS_TEXT": "La mission est retirée, et les pros qui ont envoyé un devis ({n}) sont informés de l’annulation.", "DELETE_JOB_TITLE": "Supprimer le brouillon ?", "DELETE_JOB_TEXT": "Le brouillon est supprimé définitivement.", "CANCEL_CONTRACT": "Annuler le contrat", "CANCEL_CONTRACT_INTRO": "Les travaux s’arrêtent ici. Les étapes validées et les factures sont conservées, et l’autre partie est prévenue.", "CANCEL_REASON": "Pourquoi ? (facultatif)", "CANCEL_REASON_PLACEHOLDER": "Quelques mots que vous pourrez tous les deux revoir plus tard", "CONTRACT_CANCELLED_ON": "Annulé le {date}", "COMPLETE_CLIENT_JOB_TEXT": "Toutes les étapes sont validées. La mission est marquée comme terminée.", "SIGN_ON_SITE": "Signature du client", "SIGN_ON_SITE_INTRO": "Laissez le client vérifier le travail et signer du doigt sur l’écran. Cela valide l’étape.", "CUSTOMER_NAME": "Nom du client", "SIGNATURE": "Signature", "SIGN_HERE": "Signez ici", "APPROVE_WITH_SIGNATURE": "Valider avec signature", "CHANGE_PASSWORD": "Changer le mot de passe", "CHANGE_PASSWORD_INTRO": "Vous restez connecté ici. Vos autres téléphones et navigateurs sont déconnectés.", "CURRENT_PASSWORD": "Mot de passe actuel", "CURRENT_PASSWORD_REQUIRED": "Saisissez votre mot de passe actuel.", "CURRENT_PASSWORD_WRONG": "Ce n’est pas votre mot de passe actuel.", "NEW_PASSWORD": "Nouveau mot de passe", "REPEAT_PASSWORD": "Confirmez le nouveau mot de passe", "PASSWORDS_DONT_MATCH": "Les mots de passe ne correspondent pas.", "PASSWORD_SAME_AS_OLD": "Choisissez un mot de passe que vous n’avez pas encore utilisé ici.", "PASSWORD_CHANGED": "Mot de passe modifié", "PAYMENTS": "Paiements", "PAYMENT": "Paiement", "NO_PAYMENTS": "Aucun paiement pour l’instant", "NO_PAYMENTS_TEXT": "Les paiements effectués via l’app apparaissent ici. Les missions payées par facture se trouvent dans Factures.", "PAYMENT_STATUS_PENDING": "En attente", "PAYMENT_STATUS_HELD": "Sécurisé", "PAYMENT_STATUS_RELEASED": "Versé", "PAYMENT_STATUS_REFUNDED": "Remboursé", "PAYMENT_STATUS_FAILED": "Échoué", "PLATFORM_FEE": "Frais {fee}", "TEAM": "Équipe", "TEAM_ROW_HINT": "Les personnes qui travaillent dans l’entreprise", "TEAM_MANAGE_HINT": "Vos collègues doivent d’abord avoir un compte Qup Work. Touchez une personne pour la modifier ou la retirer.", "TEAM_WORKER_HINT": "Le propriétaire et les administrateurs ajoutent et retirent les collègues.", "ADD_MEMBER": "Ajouter un collègue", "ADD_MEMBER_INTRO": "Utilisez l’e-mail avec lequel la personne s’est inscrite sur Qup Work.", "MEMBER_NOT_FOUND": "Personne ne s’est encore inscrit avec cet e-mail. Demandez-lui de créer d’abord un compte.", "MEMBER_ALREADY": "Cette personne fait déjà partie de l’entreprise.", "ROLE": "Rôle", "ROLE_ADMIN_HINT": "Les administrateurs peuvent modifier les informations de l’entreprise et les paramètres de facturation, et ajouter des collègues.", "ROLE_WORKER_HINT": "Les employés voient les missions de l’entreprise, saisissent leurs heures et réalisent le travail.", "REMOVE_FROM_COMPANY": "Retirer de l’entreprise", "REMOVE_MEMBER_TITLE": "Retirer de l’entreprise ?", "REMOVE_MEMBER_TEXT": "{name} ne verra plus les missions et les clients de l’entreprise.", "LEAVE_COMPANY": "Quitter l’entreprise", "LEAVE_COMPANY_TITLE": "Quitter l’entreprise ?", "LEAVE_COMPANY_TEXT": "Vous ne verrez plus les missions et les clients de {name}.", "NOTIF_JOB_WITHDRAWN": "Le client a annulé la mission", "INVOICE_EMAILED_TO": "{email} a reçu la facture en PDF.", "INVOICE_NO_EMAIL": "Envoyée, mais pas par e-mail : le client n'a pas d'adresse e-mail. Ouvrez le PDF et partagez-le vous-même, ou utilisez Envoyer par e-mail.", "INVOICE_EMAIL_NOT_SET_UP": "Envoyée, mais pas par e-mail : l'e-mail n'est pas encore configuré sur le serveur (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Envoyée, mais l'e-mail a échoué : {error}", "SEND_INVOICE_EMAIL_TO": "Le PDF est envoyé par e-mail à {email}.", "SEND_INVOICE_NO_EMAIL": "Il n'y a pas d'adresse e-mail, elle ne sera donc pas envoyée par e-mail. Vous pouvez partager le PDF vous-même.", "EMAIL_INVOICE": "Envoyer par e-mail", "PREVIEW_PDF": "Aperçu du PDF", "OPEN_PDF": "Ouvrir le PDF", "EMAILED": "Envoyée par e-mail", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Pas envoyée par e-mail", "INVOICE_LANGUAGE": "Langue de la facture", "NOTIF_NEW_JOB_NEARBY": "Nouvelle mission près de chez vous", "NOTIF_NEW_JOB_REMOTE": "Nouvelle mission à distance", "NOTIF_JOB_INVITED": "Vous êtes invité à une mission", "NOTIF_JOB_IN_PLACE": "« {job} » à {place}", "JOB_ALERTS": "Alertes nouvelles missions", "JOB_ALERTS_ON_TEXT": "Vous recevez une notification quand une mission de vos catégories est publiée dans votre zone.", "JOB_ALERTS_OFF_TEXT": "Vous ne serez pas averti des nouvelles missions, mais vous pouvez toujours les consulter dans l'app.", "JOB_ALERTS_NEEDS_VISIBLE": "Activez d'abord la visibilité. Seuls les pros que les clients peuvent trouver reçoivent les alertes.", "FORGOT_PASSWORD": "Mot de passe oublié ?", "FORGOT_PASSWORD_TITLE": "Nouveau mot de passe", "FORGOT_PASSWORD_INTRO": "Saisissez l’e-mail utilisé lors de votre inscription, et nous vous enverrons un code.", "SEND_CODE": "Envoyer le code", "RESET_CODE_SENT": "Si {email} a un compte, un code à 6 chiffres est en route. Saisissez-le ci-dessous avec un nouveau mot de passe.", "RESET_CODE": "Code reçu par e-mail", "RESET_CODE_INVALID": "Le code comporte 6 chiffres.", "RESET_CODE_WRONG": "Le code est incorrect ou a expiré. Demandez-en un nouveau.", "SAVE_NEW_PASSWORD": "Enregistrer et se connecter", "RESET_CODE_AGAIN": "Envoyer un nouveau code", "RESET_CODE_RESENT": "Nouveau code envoyé", "RESET_CODE_SPAM_HINT": "Pas d’e-mail après quelques minutes ? Vérifiez vos spams.", "DELETE_ACCOUNT": "Supprimer le compte", "DELETE_ACCOUNT_INTRO": "Cela supprime le compte associé à {email}. Cette action est irréversible.", "DELETE_WHAT_GOES": "Supprimé", "DELETE_GOES_PROFILE": "Votre nom, photo, téléphone et e-mail", "DELETE_GOES_PRO": "Votre profil pro, pour que les clients ne puissent plus vous trouver", "DELETE_GOES_JOBS": "Les missions ouvertes que vous avez publiées et les devis restés sans réponse", "DELETE_GOES_LOGIN": "Votre connexion, sur tous les appareils", "DELETE_WHAT_STAYS": "Conservé, sans votre nom", "DELETE_STAYS_CONTRACTS": "Les contrats terminés, messages et avis, pour que l’autre partie les garde", "DELETE_STAYS_INVOICES": "Les factures, que les règles comptables norvégiennes imposent de conserver 5 ans", "DELETE_PASSWORD_HINT": "Pour vérifier que c’est bien vous.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Supprimer votre compte ?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Vous serez déconnecté et ne pourrez plus vous connecter avec ce compte.", "DELETE_BLOCKED_CONTRACTS": "Vous avez des contrats en cours. Terminez-les ou annulez-les d’abord, pour que l’autre partie ne reste pas dans l’attente.", "DELETE_BLOCKED_COMPANY": "Vous possédez une entreprise avec d’autres membres. Retirez-les d’abord dans Équipe.", "JOB_CATEGORY_REQUIRED": "Choisissez une catégorie, pour que les bons pros soient informés de la mission."}, "hu-HU": {"EDIT": "Szerkesztés", "REMOVE": "Eltávolítás", "CLEAR": "Kiürítés", "ARCHIVE": "Archiválás", "NOTES": "Jegyzetek", "YOU": "te", "DATE_PLACEHOLDER": "nn.hh.éééé", "DATE_INVALID": "A dátumot nn.hh.éééé formában írd be.", "AMOUNT_INVALID": "Adj meg egy összeget NOK-ban, pl. 5000.", "EMAIL_INVALID": "Ez az e-mail-cím nem tűnik helyesnek.", "POSTCODE_FORMAT": "Az irányítószám 4 számjegyből áll.", "CLIENT": "Ügyfél", "CLIENTS": "Ügyfelek", "CLIENTS_PRO_ONLY": "A saját ügyfélnyilvántartás szakembereknek szól. A használatához jelentkezz be szakemberfiókkal.", "SEARCH_CLIENTS": "Ügyfelek keresése", "CLIENTS_ACTIVE": "Aktív", "CLIENTS_ARCHIVED": "Archivált", "NO_CLIENTS": "Még nincsenek ügyfeleid", "NO_CLIENTS_TEXT": "Add hozzá azokat az ügyfeleket, akiknek a platformon kívül dolgozol, és tartsd egy helyen a munkáikat, óráikat és számláikat.", "NO_CLIENTS_MATCH": "Egy ügyfél sem felel meg a keresésnek.", "NO_ARCHIVED_CLIENTS": "Nincs semmi archiválva", "NO_ARCHIVED_CLIENTS_TEXT": "Az archivált ügyfelek ide kerülnek a korábbi munkáikkal és számláikkal együtt.", "NEW_CLIENT": "Új ügyfél", "EDIT_CLIENT": "Ügyfél szerkesztése", "SAVE_CLIENT": "Ügyfél mentése", "CLIENT_FORM_INTRO": "Ezt csak te és a céged látjátok. A címet az új munkáknál munkavégzési címként használjuk.", "CLIENT_TYPE": "Ügyfél típusa", "CLIENT_PRIVATE": "Magánszemély", "CLIENT_BUSINESS": "Cég", "CLIENT_COMPANY_PLACEHOLDER": "Pl. Bergen Eiendom AS", "CONTACT_PERSON": "Kapcsolattartó", "CONTACT_NAME": "Kapcsolattartó: {name}", "CLIENT_EMAIL_HINT": "Ide lehet számlákat küldeni.", "CLIENT_NOTES_PLACEHOLDER": "Kapukód, parkolás, a kutya neve…", "CLIENT_NOTES_HINT": "Csak neked és a kollégáidnak, az ügyfél soha nem látja.", "CLIENT_NOT_FOUND": "Az ügyfél nem található", "CLIENT_IS_ARCHIVED": "Archivált", "CLIENT_NO_DETAILS": "Még nincsenek elérhetőségek. A hozzáadásukhoz koppints a Szerkesztés gombra.", "CLIENT_JOBS": "Munkák", "CLIENT_NO_JOBS": "Ennek az ügyfélnek még nincs munkája.", "ARCHIVE_CLIENT": "Ügyfél archiválása", "ARCHIVE_CLIENT_TITLE": "Archiválod ezt az ügyfelet?", "ARCHIVE_CLIENT_TEXT": "Az ügyfélnek vannak munkái, ezért megmarad a munkáival és számláival együtt. Később visszaállíthatod.", "RESTORE_CLIENT": "Ügyfél visszaállítása", "DELETE_CLIENT": "Ügyfél törlése", "DELETE_CLIENT_TITLE": "Törlöd ezt az ügyfelet?", "DELETE_CLIENT_TEXT": "{name} törlődik a nyilvántartásodból.", "NEW_ASSIGNMENT": "Új vállalás", "NEW_ASSIGNMENT_INTRO": "Rögzíts munkát a saját ügyfelednek, és egyezzetek meg az árban. A szerződésben lépéseket adhatsz hozzá, órákat rögzíthetsz és számlázhatsz.", "PICK_CLIENT_INTRO": "Kinek szól a munka?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "A megállapodás, anyagok, minden, amit az ügyfélnek tudnia kell", "START_DATE": "Kezdő dátum", "END_DATE": "Befejező dátum", "END_BEFORE_START": "A befejező dátum korábbi, mint a kezdő dátum.", "STEPS_OPTIONAL_HINT": "Nem kötelező. Lépések nélkül az egész munka egy lépés.", "STEPS_SPLIT_HINT": "Minden lépést külön kell jóváhagyni. Az összegeknek együtt ki kell adniuk az árat.", "STEPS_HOURLY_HINT": "Minden lépést külön kell jóváhagyni. Az órákat a szerződésen rögzíted.", "STEP_TITLE": "Lépés", "STEP_TITLE_PLACEHOLDER": "Pl. Bontás és vízelvezetés", "STEP_TITLE_REQUIRED": "Adj nevet minden lépésnek.", "STEP_AMOUNT": "Összeg (NOK)", "STEP_AMOUNT_REQUIRED": "Adj meg összeget minden lépéshez.", "STEP_DUE": "Határidő", "STEP_DESCRIPTION_PLACEHOLDER": "Mit tartalmaz ez a lépés", "STEPS_MUST_ADD_UP": "A lépéseknek együtt {total} összeget kell kiadniuk.", "STEPS_ADD_UP": "A lépések együtt kiadják az árat ✓", "STEPS_REST": "Még felosztandó: {rest}", "STEPS_TOTAL_MISMATCH": "A lépések együtt {steps}, a megbeszélt ár {total}.", "REMOVE_STEP": "Lépés eltávolítása", "ADD_STEP": "Lépés hozzáadása", "ADD_STEP_INTRO": "Az ügyfél minden lépést jóváhagy, amikor elkészül.", "EDIT_STEP": "Lépés szerkesztése", "DELETE_STEP": "Lépés törlése", "DELETE_STEP_TITLE": "Törlöd ezt a lépést?", "DELETE_STEP_TEXT": "A(z) „{title}” lekerül a szerződésről.", "STEP_STARTED_NO_DELETE": "Ez a lépés már elkezdődött, így módosítható, de nem törölhető.", "CREATE_CONTRACT": "Szerződés létrehozása", "JOB_HAS_CONTRACT": "Ehhez a munkához már van szerződés.", "JOB_NOT_YOURS": "A munkát csak az módosíthatja, aki létrehozta.", "JOB_CANNOT_EDIT": "Már megbíztak valakit, így a munka nem módosítható többé.", "EDIT_JOB": "Munka szerkesztése", "EDIT_JOB_INTRO": "A szakemberek azonnal látják a módosításokat.", "EDIT_JOB_WITH_OFFERS": "Beérkezett ajánlatok: {n}. A nagyobb változásokról szólj a szakembereknek a chatben, hogy az ajánlataik továbbra is megfeleljenek.", "CREATED_AGO": "Létrehozva: {time}", "DRAFT_NOT_VISIBLE": "Ez egy piszkozat. A szakemberek csak akkor látják, ha közzéteszed.", "CANCEL_JOB": "Munka lemondása", "CANCEL_JOB_TITLE": "Lemondod ezt a munkát?", "CANCEL_JOB_TEXT": "A munka lekerül, és nem nyitható meg újra.", "CANCEL_JOB_WITH_OFFERS_TEXT": "A munka lekerül, és az ajánlatot küldő szakemberek ({n}) értesítést kapnak a lemondásról.", "DELETE_JOB_TITLE": "Törlöd a piszkozatot?", "DELETE_JOB_TEXT": "A piszkozat véglegesen törlődik.", "CANCEL_CONTRACT": "Szerződés felbontása", "CANCEL_CONTRACT_INTRO": "A munka itt leáll. A jóváhagyott lépések és a számlák megmaradnak, a másik fél pedig értesítést kap.", "CANCEL_REASON": "Miért? (nem kötelező)", "CANCEL_REASON_PLACEHOLDER": "Néhány szó, amelyet később mindketten láttok", "CONTRACT_CANCELLED_ON": "Felbontva: {date}", "COMPLETE_CLIENT_JOB_TEXT": "Minden lépés alá van írva. A munka lezártként lesz megjelölve.", "SIGN_ON_SITE": "Az ügyfél aláír", "SIGN_ON_SITE_INTRO": "Hadd ellenőrizze az ügyfél a munkát, és írja alá az ujjával a képernyőn. Ezzel jóváhagyja a lépést.", "CUSTOMER_NAME": "Ügyfél neve", "SIGNATURE": "Aláírás", "SIGN_HERE": "Írd alá itt", "APPROVE_WITH_SIGNATURE": "Jóváhagyás aláírással", "CHANGE_PASSWORD": "Jelszó módosítása", "CHANGE_PASSWORD_INTRO": "Itt bejelentkezve maradsz. A többi telefonodon és böngésződben kijelentkeztetünk.", "CURRENT_PASSWORD": "Jelenlegi jelszó", "CURRENT_PASSWORD_REQUIRED": "Add meg a jelenlegi jelszavadat.", "CURRENT_PASSWORD_WRONG": "Ez nem a jelenlegi jelszavad.", "NEW_PASSWORD": "Új jelszó", "REPEAT_PASSWORD": "Új jelszó még egyszer", "PASSWORDS_DONT_MATCH": "A jelszavak nem egyeznek.", "PASSWORD_SAME_AS_OLD": "Olyan jelszót válassz, amelyet itt még nem használtál.", "PASSWORD_CHANGED": "Jelszó módosítva", "PAYMENTS": "Fizetések", "PAYMENT": "Fizetés", "NO_PAYMENTS": "Még nincsenek fizetések", "NO_PAYMENTS_TEXT": "Az appon keresztüli fizetések itt jelennek meg. A számlával fizetett munkák a Számlák alatt vannak.", "PAYMENT_STATUS_PENDING": "Függőben", "PAYMENT_STATUS_HELD": "Biztonságban letétben", "PAYMENT_STATUS_RELEASED": "Kifizetve", "PAYMENT_STATUS_REFUNDED": "Visszatérítve", "PAYMENT_STATUS_FAILED": "Sikertelen", "PLATFORM_FEE": "Díj: {fee}", "TEAM": "Csapat", "TEAM_ROW_HINT": "A cégnél dolgozó emberek", "TEAM_MANAGE_HINT": "A kollégáknak először Qup Work-fiók kell. Koppints valakire a módosításhoz vagy eltávolításhoz.", "TEAM_WORKER_HINT": "Kollégákat a tulajdonos és az adminisztrátorok adhatnak hozzá és távolíthatnak el.", "ADD_MEMBER": "Kolléga hozzáadása", "ADD_MEMBER_INTRO": "Azt az e-mail-címet használd, amellyel a Qup Workre regisztrált.", "MEMBER_NOT_FOUND": "Ezzel az e-mail-címmel még senki nem regisztrált. Kérd meg, hogy előbb hozzon létre fiókot.", "MEMBER_ALREADY": "Ez a személy már a cégnél van.", "ROLE": "Szerepkör", "ROLE_ADMIN_HINT": "Az adminisztrátorok módosíthatják a cégadatokat és a számlázási beállításokat, és kollégákat adhatnak hozzá.", "ROLE_WORKER_HINT": "Az alkalmazottak látják a cég munkáit, órákat rögzítenek és elvégzik a munkát.", "REMOVE_FROM_COMPANY": "Eltávolítás a cégből", "REMOVE_MEMBER_TITLE": "Eltávolítod a cégből?", "REMOVE_MEMBER_TEXT": "{name} többé nem látja a cég munkáit és ügyfeleit.", "LEAVE_COMPANY": "Kilépés a cégből", "LEAVE_COMPANY_TITLE": "Kilépsz a cégből?", "LEAVE_COMPANY_TEXT": "Többé nem látod a(z) {name} munkáit és ügyfeleit.", "NOTIF_JOB_WITHDRAWN": "Az ügyfél lemondta a munkát", "INVOICE_EMAILED_TO": "{email} megkapta a számlát PDF-ben.", "INVOICE_NO_EMAIL": "Elküldve, de nem e-mailben: az ügyfélnek nincs e-mail-címe. Nyisd meg a PDF-et és oszd meg magad, vagy használd a Küldés e-mailben gombot.", "INVOICE_EMAIL_NOT_SET_UP": "Elküldve, de nem e-mailben: az e-mail még nincs beállítva a szerveren (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Elküldve, de az e-mail nem sikerült: {error}", "SEND_INVOICE_EMAIL_TO": "A PDF-et e-mailben küldjük ide: {email}.", "SEND_INVOICE_NO_EMAIL": "Nincs e-mail-cím, ezért nem megy ki e-mailben. A PDF-et megoszthatod magad.", "EMAIL_INVOICE": "Küldés e-mailben", "PREVIEW_PDF": "PDF előnézet", "OPEN_PDF": "PDF megnyitása", "EMAILED": "E-mailben elküldve", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Nincs e-mailben elküldve", "INVOICE_LANGUAGE": "A számla nyelve", "NOTIF_NEW_JOB_NEARBY": "Új munka a közeledben", "NOTIF_NEW_JOB_REMOTE": "Új távmunka", "NOTIF_JOB_INVITED": "Meghívtak egy munkára", "NOTIF_JOB_IN_PLACE": "„{job}” – {place}", "JOB_ALERTS": "Értesítés új munkákról", "JOB_ALERTS_ON_TEXT": "Értesítést kapsz, ha a környékeden munka jelenik meg a kategóriáidban.", "JOB_ALERTS_OFF_TEXT": "Nem kapsz értesítést új munkákról, de az appban továbbra is látod őket.", "JOB_ALERTS_NEEDS_VISIBLE": "Előbb kapcsold be a láthatóságot. Csak az ügyfelek által megtalálható szakemberek kapnak értesítést.", "FORGOT_PASSWORD": "Elfelejtetted a jelszavad?", "FORGOT_PASSWORD_TITLE": "Új jelszó", "FORGOT_PASSWORD_INTRO": "Add meg az e-mail-címet, amellyel regisztráltál, és küldünk egy kódot.", "SEND_CODE": "Kód küldése", "RESET_CODE_SENT": "Ha a(z) {email} címhez tartozik fiók, egy 6 számjegyű kód már úton van. Írd be lent egy új jelszóval együtt.", "RESET_CODE": "Kód az e-mailből", "RESET_CODE_INVALID": "A kód 6 számjegyből áll.", "RESET_CODE_WRONG": "A kód hibás vagy lejárt. Kérj újat.", "SAVE_NEW_PASSWORD": "Mentés és bejelentkezés", "RESET_CODE_AGAIN": "Új kód küldése", "RESET_CODE_RESENT": "Új kódot küldtünk", "RESET_CODE_SPAM_HINT": "Pár perc után sincs e-mail? Nézd meg a spam mappát.", "DELETE_ACCOUNT": "Fiók törlése", "DELETE_ACCOUNT_INTRO": "Ez törli a(z) {email} címhez tartozó fiókot. Nem vonható vissza.", "DELETE_WHAT_GOES": "Törlődik", "DELETE_GOES_PROFILE": "A neved, fotód, telefonszámod és e-mail-címed", "DELETE_GOES_PRO": "A szakemberprofilod, így az ügyfelek többé nem találnak meg", "DELETE_GOES_JOBS": "Az általad feladott nyitott munkák és a megválaszolatlan ajánlatok", "DELETE_GOES_LOGIN": "A bejelentkezésed, minden eszközön", "DELETE_WHAT_STAYS": "Megmarad, a neved nélkül", "DELETE_STAYS_CONTRACTS": "A lezárt szerződések, üzenetek és értékelések, hogy a másik félnél megmaradjanak", "DELETE_STAYS_INVOICES": "A számlák, amelyeket a norvég könyvviteli szabályok szerint 5 évig meg kell őrizni", "DELETE_PASSWORD_HINT": "Hogy biztosak legyünk benne, hogy te vagy az.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Törlöd a fiókodat?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Kijelentkeztetünk, és ezzel a fiókkal többé nem tudsz bejelentkezni.", "DELETE_BLOCKED_CONTRACTS": "Folyamatban lévő szerződéseid vannak. Előbb zárd le vagy mondd le őket, hogy a másik fél ne maradjon várakozásban.", "DELETE_BLOCKED_COMPANY": "Olyan céged van, amelynek más tagjai is vannak. Előbb távolítsd el őket a Csapat menüpontban.", "JOB_CATEGORY_REQUIRED": "Válassz kategóriát, hogy a megfelelő szakemberek értesüljenek a munkáról."}, "da-DK": {"EDIT": "Rediger", "REMOVE": "Fjern", "CLEAR": "Ryd", "ARCHIVE": "Arkivér", "NOTES": "Noter", "YOU": "dig", "DATE_PLACEHOLDER": "dd.mm.åååå", "DATE_INVALID": "Skriv datoen som dd.mm.åååå.", "AMOUNT_INVALID": "Skriv et beløb i NOK, f.eks. 5000.", "EMAIL_INVALID": "Den e-mailadresse ser ikke rigtig ud.", "POSTCODE_FORMAT": "Et postnummer har 4 cifre.", "CLIENT": "Kunde", "CLIENTS": "Kunder", "CLIENTS_PRO_ONLY": "Dit eget kunderegister er for fagfolk. Log ind med en fagpersonkonto for at bruge det.", "SEARCH_CLIENTS": "Søg i kunder", "CLIENTS_ACTIVE": "Aktive", "CLIENTS_ARCHIVED": "Arkiverede", "NO_CLIENTS": "Ingen kunder endnu", "NO_CLIENTS_TEXT": "Tilføj de kunder, du arbejder for uden for markedspladsen, og saml opgaver, timer og fakturaer for dem ét sted.", "NO_CLIENTS_MATCH": "Ingen kunder matcher din søgning.", "NO_ARCHIVED_CLIENTS": "Intet arkiveret", "NO_ARCHIVED_CLIENTS_TEXT": "Kunder, du arkiverer, havner her med deres gamle opgaver og fakturaer.", "NEW_CLIENT": "Ny kunde", "EDIT_CLIENT": "Rediger kunde", "SAVE_CLIENT": "Gem kunde", "CLIENT_FORM_INTRO": "Kun du og din virksomhed kan se dette. Adressen bruges som arbejdssted på nye opgaver.", "CLIENT_TYPE": "Type kunde", "CLIENT_PRIVATE": "Privatperson", "CLIENT_BUSINESS": "Virksomhed", "CLIENT_COMPANY_PLACEHOLDER": "F.eks. Bergen Eiendom AS", "CONTACT_PERSON": "Kontaktperson", "CONTACT_NAME": "Kontakt: {name}", "CLIENT_EMAIL_HINT": "Fakturaer kan sendes hertil.", "CLIENT_NOTES_PLACEHOLDER": "Portkode, parkering, hvad hunden hedder …", "CLIENT_NOTES_HINT": "Kun for dig og dine kolleger, vises aldrig for kunden.", "CLIENT_NOT_FOUND": "Kunden blev ikke fundet", "CLIENT_IS_ARCHIVED": "Arkiveret", "CLIENT_NO_DETAILS": "Ingen kontaktoplysninger endnu. Tryk på Rediger for at tilføje dem.", "CLIENT_JOBS": "Opgaver", "CLIENT_NO_JOBS": "Ingen opgaver for denne kunde endnu.", "ARCHIVE_CLIENT": "Arkivér kunde", "ARCHIVE_CLIENT_TITLE": "Arkivere kunden?", "ARCHIVE_CLIENT_TEXT": "Kunden har opgaver, så den gemmes sammen med opgaver og fakturaer. Du kan gendanne den senere.", "RESTORE_CLIENT": "Gendan kunde", "DELETE_CLIENT": "Slet kunde", "DELETE_CLIENT_TITLE": "Slette kunden?", "DELETE_CLIENT_TEXT": "{name} fjernes fra dit kunderegister.", "NEW_ASSIGNMENT": "Nyt job", "NEW_ASSIGNMENT_INTRO": "Registrer arbejde for din egen kunde, og aftal prisen. Du kan tilføje trin, registrere timer og fakturere fra aftalen.", "PICK_CLIENT_INTRO": "Hvem er arbejdet for?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Hvad der er aftalt, materialer, det kunden bør vide", "START_DATE": "Startdato", "END_DATE": "Slutdato", "END_BEFORE_START": "Slutdatoen ligger før startdatoen.", "STEPS_OPTIONAL_HINT": "Valgfrit. Uden trin er hele opgaven ét trin.", "STEPS_SPLIT_HINT": "Hvert trin godkendes for sig. Beløbene skal tilsammen give prisen.", "STEPS_HOURLY_HINT": "Hvert trin godkendes for sig. Timerne registreres på aftalen.", "STEP_TITLE": "Trin", "STEP_TITLE_PLACEHOLDER": "F.eks. Nedrivning og afløb", "STEP_TITLE_REQUIRED": "Giv hvert trin et navn.", "STEP_AMOUNT": "Beløb (NOK)", "STEP_AMOUNT_REQUIRED": "Giv hvert trin et beløb.", "STEP_DUE": "Frist", "STEP_DESCRIPTION_PLACEHOLDER": "Hvad der indgår i dette trin", "STEPS_MUST_ADD_UP": "Trinene skal tilsammen give {total}.", "STEPS_ADD_UP": "Trinene giver tilsammen prisen ✓", "STEPS_REST": "Tilbage at fordele: {rest}", "STEPS_TOTAL_MISMATCH": "Trinene giver {steps}, den aftalte pris er {total}.", "REMOVE_STEP": "Fjern trin", "ADD_STEP": "Tilføj trin", "ADD_STEP_INTRO": "Kunden godkender hvert trin, når det er færdigt.", "EDIT_STEP": "Rediger trin", "DELETE_STEP": "Slet trin", "DELETE_STEP_TITLE": "Slette dette trin?", "DELETE_STEP_TEXT": "“{title}” fjernes fra aftalen.", "STEP_STARTED_NO_DELETE": "Dette trin er startet, så det kan ændres, men ikke slettes.", "CREATE_CONTRACT": "Opret aftale", "JOB_HAS_CONTRACT": "Denne opgave har allerede en aftale.", "JOB_NOT_YOURS": "Kun den, der har oprettet opgaven, kan ændre den.", "JOB_CANNOT_EDIT": "Der er allerede hyret nogen, så opgaven kan ikke længere ændres.", "EDIT_JOB": "Rediger opgave", "EDIT_JOB_INTRO": "Fagfolk ser ændringerne med det samme.", "EDIT_JOB_WITH_OFFERS": "Modtagne tilbud: {n}. Fortæl fagfolkene om store ændringer i chatten, så deres tilbud stadig passer.", "CREATED_AGO": "Oprettet {time}", "DRAFT_NOT_VISIBLE": "Dette er en kladde. Fagfolk kan ikke se den, før du offentliggør den.", "CANCEL_JOB": "Annuller opgave", "CANCEL_JOB_TITLE": "Annullere opgaven?", "CANCEL_JOB_TEXT": "Opgaven tages ned og kan ikke genåbnes.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Opgaven tages ned, og de fagfolk, der har sendt tilbud ({n}), får besked om, at den er annulleret.", "DELETE_JOB_TITLE": "Slette kladden?", "DELETE_JOB_TEXT": "Kladden slettes for altid.", "CANCEL_CONTRACT": "Annuller aftalen", "CANCEL_CONTRACT_INTRO": "Arbejdet stopper her. Godkendte trin og fakturaer bevares, og den anden part får besked.", "CANCEL_REASON": "Hvorfor? (valgfrit)", "CANCEL_REASON_PLACEHOLDER": "Et par ord, som I begge kan se senere", "CONTRACT_CANCELLED_ON": "Annulleret {date}", "COMPLETE_CLIENT_JOB_TEXT": "Alle trin er godkendt. Opgaven markeres som afsluttet.", "SIGN_ON_SITE": "Kunden skriver under", "SIGN_ON_SITE_INTRO": "Lad kunden tjekke arbejdet og skrive under med en finger på skærmen. Det godkender trinnet.", "CUSTOMER_NAME": "Kundens navn", "SIGNATURE": "Underskrift", "SIGN_HERE": "Skriv under her", "APPROVE_WITH_SIGNATURE": "Godkend med underskrift", "CHANGE_PASSWORD": "Skift adgangskode", "CHANGE_PASSWORD_INTRO": "Du forbliver logget ind her. Dine andre telefoner og browsere bliver logget ud.", "CURRENT_PASSWORD": "Nuværende adgangskode", "CURRENT_PASSWORD_REQUIRED": "Skriv din nuværende adgangskode.", "CURRENT_PASSWORD_WRONG": "Det er ikke din nuværende adgangskode.", "NEW_PASSWORD": "Ny adgangskode", "REPEAT_PASSWORD": "Gentag ny adgangskode", "PASSWORDS_DONT_MATCH": "Adgangskoderne er ikke ens.", "PASSWORD_SAME_AS_OLD": "Vælg en adgangskode, du ikke har brugt her før.", "PASSWORD_CHANGED": "Adgangskoden er skiftet", "PAYMENTS": "Betalinger", "PAYMENT": "Betaling", "NO_PAYMENTS": "Ingen betalinger endnu", "NO_PAYMENTS_TEXT": "Betalinger via appen vises her. Opgaver, der betales med faktura, finder du under Fakturaer.", "PAYMENT_STATUS_PENDING": "Afventer", "PAYMENT_STATUS_HELD": "Opbevares sikkert", "PAYMENT_STATUS_RELEASED": "Udbetalt", "PAYMENT_STATUS_REFUNDED": "Refunderet", "PAYMENT_STATUS_FAILED": "Mislykkedes", "PLATFORM_FEE": "Gebyr {fee}", "TEAM": "Team", "TEAM_ROW_HINT": "Dem, der arbejder i virksomheden", "TEAM_MANAGE_HINT": "Kolleger skal først have en Qup Work-konto. Tryk på en person for at ændre eller fjerne vedkommende.", "TEAM_WORKER_HINT": "Ejeren og administratorerne tilføjer og fjerner kolleger.", "ADD_MEMBER": "Tilføj kollega", "ADD_MEMBER_INTRO": "Brug den e-mail, personen har tilmeldt sig Qup Work med.", "MEMBER_NOT_FOUND": "Ingen har tilmeldt sig med den e-mail endnu. Bed personen om at oprette en konto først.", "MEMBER_ALREADY": "Den person er allerede i virksomheden.", "ROLE": "Rolle", "ROLE_ADMIN_HINT": "Administratorer kan ændre virksomhedens oplysninger og fakturaindstillinger og tilføje kolleger.", "ROLE_WORKER_HINT": "Medarbejdere ser virksomhedens opgaver, registrerer timer og udfører arbejdet.", "REMOVE_FROM_COMPANY": "Fjern fra virksomheden", "REMOVE_MEMBER_TITLE": "Fjerne fra virksomheden?", "REMOVE_MEMBER_TEXT": "{name} kan ikke længere se virksomhedens opgaver og kunder.", "LEAVE_COMPANY": "Forlad virksomheden", "LEAVE_COMPANY_TITLE": "Forlade virksomheden?", "LEAVE_COMPANY_TEXT": "Du kan ikke længere se opgaver og kunder hos {name}.", "NOTIF_JOB_WITHDRAWN": "Kunden har annulleret opgaven", "INVOICE_EMAILED_TO": "{email} har fået fakturaen som PDF.", "INVOICE_NO_EMAIL": "Sendt, men ikke på e-mail: kunden har ingen e-mailadresse. Åbn PDF'en og del den selv, eller brug Send på e-mail.", "INVOICE_EMAIL_NOT_SET_UP": "Sendt, men ikke på e-mail: e-mail er ikke sat op på serveren endnu (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Sendt, men e-mailen fejlede: {error}", "SEND_INVOICE_EMAIL_TO": "PDF'en sendes på e-mail til {email}.", "SEND_INVOICE_NO_EMAIL": "Der er ingen e-mailadresse, så den sendes ikke på e-mail. Du kan dele PDF'en selv.", "EMAIL_INVOICE": "Send på e-mail", "PREVIEW_PDF": "Forhåndsvis PDF", "OPEN_PDF": "Åbn PDF", "EMAILED": "Sendt på e-mail", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Ikke sendt på e-mail", "INVOICE_LANGUAGE": "Sprog på fakturaen", "NOTIF_NEW_JOB_NEARBY": "Ny opgave i nærheden", "NOTIF_NEW_JOB_REMOTE": "Ny fjernopgave", "NOTIF_JOB_INVITED": "Du er inviteret til en opgave", "NOTIF_JOB_IN_PLACE": "»{job}« i {place}", "JOB_ALERTS": "Besked om nye opgaver", "JOB_ALERTS_ON_TEXT": "Du får besked, når en opgave i dine kategorier bliver slået op i dit område.", "JOB_ALERTS_OFF_TEXT": "Du får ikke besked om nye opgaver, men du kan stadig se dem i appen.", "JOB_ALERTS_NEEDS_VISIBLE": "Slå synlighed til først. Kun fagfolk, som kunderne kan finde, får besked om opgaver.", "FORGOT_PASSWORD": "Glemt din adgangskode?", "FORGOT_PASSWORD_TITLE": "Ny adgangskode", "FORGOT_PASSWORD_INTRO": "Skriv den e-mail, du oprettede dig med, så sender vi dig en kode.", "SEND_CODE": "Send kode", "RESET_CODE_SENT": "Hvis {email} har en konto, er en 6-cifret kode på vej. Skriv den nedenfor sammen med en ny adgangskode.", "RESET_CODE": "Kode fra e-mailen", "RESET_CODE_INVALID": "Koden har 6 cifre.", "RESET_CODE_WRONG": "Koden er forkert eller udløbet. Bed om en ny.", "SAVE_NEW_PASSWORD": "Gem og log ind", "RESET_CODE_AGAIN": "Send en ny kode", "RESET_CODE_RESENT": "Ny kode sendt", "RESET_CODE_SPAM_HINT": "Ingen e-mail efter et par minutter? Tjek din spammappe.", "DELETE_ACCOUNT": "Slet konto", "DELETE_ACCOUNT_INTRO": "Dette sletter kontoen for {email}. Det kan ikke fortrydes.", "DELETE_WHAT_GOES": "Slettes", "DELETE_GOES_PROFILE": "Dit navn, billede, telefon og e-mail", "DELETE_GOES_PRO": "Din fagprofil, så kunderne ikke længere kan finde dig", "DELETE_GOES_JOBS": "Åbne opgaver, du har slået op, og tilbud, ingen har svaret på", "DELETE_GOES_LOGIN": "Dit login, på alle enheder", "DELETE_WHAT_STAYS": "Gemmes, uden dit navn", "DELETE_STAYS_CONTRACTS": "Afsluttede aftaler, beskeder og anmeldelser, så den anden part stadig har dem", "DELETE_STAYS_INVOICES": "Fakturaer, som de norske bogføringsregler kræver bliver opbevaret i 5 år", "DELETE_PASSWORD_HINT": "For at sikre, at det er dig.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Vil du slette din konto?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Du bliver logget ud og kan ikke logge ind med denne konto igen.", "DELETE_BLOCKED_CONTRACTS": "Du har igangværende aftaler. Gør dem færdige eller annuller dem først, så den anden part ikke står og venter.", "DELETE_BLOCKED_COMPANY": "Du ejer en virksomhed med andre medlemmer. Fjern dem under Team først.", "JOB_CATEGORY_REQUIRED": "Vælg en kategori, så de rette fagfolk hører om opgaven."}, "ca-ES": {"EDIT": "Edita", "REMOVE": "Treu", "CLEAR": "Esborra", "ARCHIVE": "Arxiva", "NOTES": "Notes", "YOU": "tu", "DATE_PLACEHOLDER": "dd/mm/aaaa", "DATE_INVALID": "Escriu la data com a dd/mm/aaaa.", "AMOUNT_INVALID": "Escriu un import en NOK, p. ex. 5000.", "EMAIL_INVALID": "Aquesta adreça de correu no sembla correcta.", "POSTCODE_FORMAT": "Un codi postal té 4 xifres.", "CLIENT": "Client", "CLIENTS": "Clients", "CLIENTS_PRO_ONLY": "El registre de clients propi és per a professionals. Inicia la sessió amb un compte professional per fer-lo servir.", "SEARCH_CLIENTS": "Cerca clients", "CLIENTS_ACTIVE": "Actius", "CLIENTS_ARCHIVED": "Arxivats", "NO_CLIENTS": "Encara no hi ha clients", "NO_CLIENTS_TEXT": "Afegeix els clients per als quals treballes fora del mercat i tingues les feines, les hores i les factures en un sol lloc.", "NO_CLIENTS_MATCH": "Cap client no coincideix amb la cerca.", "NO_ARCHIVED_CLIENTS": "No hi ha res arxivat", "NO_ARCHIVED_CLIENTS_TEXT": "Els clients que arxivis aniran a parar aquí, amb les seves feines i factures antigues.", "NEW_CLIENT": "Client nou", "EDIT_CLIENT": "Edita el client", "SAVE_CLIENT": "Desa el client", "CLIENT_FORM_INTRO": "Només ho veieu tu i la teva empresa. L’adreça s’utilitza com a lloc de treball a les feines noves.", "CLIENT_TYPE": "Tipus de client", "CLIENT_PRIVATE": "Particular", "CLIENT_BUSINESS": "Empresa", "CLIENT_COMPANY_PLACEHOLDER": "P. ex. Bergen Eiendom AS", "CONTACT_PERSON": "Persona de contacte", "CONTACT_NAME": "Contacte: {name}", "CLIENT_EMAIL_HINT": "Les factures es poden enviar aquí.", "CLIENT_NOTES_PLACEHOLDER": "Codi de la porta, aparcament, el nom del gos…", "CLIENT_NOTES_HINT": "Només per a tu i els teus companys, el client no ho veu mai.", "CLIENT_NOT_FOUND": "No s’ha trobat el client", "CLIENT_IS_ARCHIVED": "Arxivat", "CLIENT_NO_DETAILS": "Encara no hi ha dades de contacte. Toca Edita per afegir-les.", "CLIENT_JOBS": "Feines", "CLIENT_NO_JOBS": "Encara no hi ha feines per a aquest client.", "ARCHIVE_CLIENT": "Arxiva el client", "ARCHIVE_CLIENT_TITLE": "Vols arxivar aquest client?", "ARCHIVE_CLIENT_TEXT": "El client té feines, així que es conserva amb les seves feines i factures. El pots restaurar més endavant.", "RESTORE_CLIENT": "Restaura el client", "DELETE_CLIENT": "Suprimeix el client", "DELETE_CLIENT_TITLE": "Vols suprimir aquest client?", "DELETE_CLIENT_TEXT": "{name} se suprimeix del teu registre.", "NEW_ASSIGNMENT": "Encàrrec nou", "NEW_ASSIGNMENT_INTRO": "Registra feina per a un client teu i acordeu el preu. Des del contracte pots afegir passos, registrar hores i facturar.", "PICK_CLIENT_INTRO": "Per a qui és la feina?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Què s’ha acordat, materials, qualsevol cosa que el client hagi de saber", "START_DATE": "Data d’inici", "END_DATE": "Data de finalització", "END_BEFORE_START": "La data de finalització és anterior a la d’inici.", "STEPS_OPTIONAL_HINT": "Opcional. Sense passos, tota la feina és un sol pas.", "STEPS_SPLIT_HINT": "Cada pas s’aprova per separat. Els imports han de sumar el preu.", "STEPS_HOURLY_HINT": "Cada pas s’aprova per separat. Les hores es registren al contracte.", "STEP_TITLE": "Pas", "STEP_TITLE_PLACEHOLDER": "P. ex. Enderroc i desguàs", "STEP_TITLE_REQUIRED": "Posa un nom a cada pas.", "STEP_AMOUNT": "Import (NOK)", "STEP_AMOUNT_REQUIRED": "Posa un import a cada pas.", "STEP_DUE": "Data límit", "STEP_DESCRIPTION_PLACEHOLDER": "Què inclou aquest pas", "STEPS_MUST_ADD_UP": "Els passos han de sumar {total}.", "STEPS_ADD_UP": "Els passos sumen el preu ✓", "STEPS_REST": "Queda per repartir: {rest}", "STEPS_TOTAL_MISMATCH": "Els passos sumen {steps} i el preu acordat és {total}.", "REMOVE_STEP": "Treu el pas", "ADD_STEP": "Afegeix un pas", "ADD_STEP_INTRO": "El client aprova cada pas quan està fet.", "EDIT_STEP": "Edita el pas", "DELETE_STEP": "Suprimeix el pas", "DELETE_STEP_TITLE": "Vols suprimir aquest pas?", "DELETE_STEP_TEXT": "«{title}» se suprimeix del contracte.", "STEP_STARTED_NO_DELETE": "Aquest pas ja ha començat, així que es pot canviar però no suprimir.", "CREATE_CONTRACT": "Crea el contracte", "JOB_HAS_CONTRACT": "Aquesta feina ja té un contracte.", "JOB_NOT_YOURS": "Només qui ha creat la feina la pot canviar.", "JOB_CANNOT_EDIT": "Ja s’ha contractat algú, així que la feina ja no es pot canviar.", "EDIT_JOB": "Edita la feina", "EDIT_JOB_INTRO": "Els professionals veuen els canvis de seguida.", "EDIT_JOB_WITH_OFFERS": "Pressupostos rebuts: {n}. Explica els canvis importants als professionals pel xat, perquè els seus pressupostos encara encaixin.", "CREATED_AGO": "Creada {time}", "DRAFT_NOT_VISIBLE": "Això és un esborrany. Els professionals no el veuran fins que el publiquis.", "CANCEL_JOB": "Cancel·la la feina", "CANCEL_JOB_TITLE": "Vols cancel·lar aquesta feina?", "CANCEL_JOB_TEXT": "La feina es retira i no es pot tornar a obrir.", "CANCEL_JOB_WITH_OFFERS_TEXT": "La feina es retira i els professionals que han enviat pressupostos ({n}) reben un avís que s’ha cancel·lat.", "DELETE_JOB_TITLE": "Vols suprimir l’esborrany?", "DELETE_JOB_TEXT": "L’esborrany se suprimeix definitivament.", "CANCEL_CONTRACT": "Cancel·la el contracte", "CANCEL_CONTRACT_INTRO": "La feina s’atura aquí. Els passos aprovats i les factures es conserven, i l’altra part rep un avís.", "CANCEL_REASON": "Per què? (opcional)", "CANCEL_REASON_PLACEHOLDER": "Unes quantes paraules que tots dos podreu veure després", "CONTRACT_CANCELLED_ON": "Cancel·lat el {date}", "COMPLETE_CLIENT_JOB_TEXT": "Tots els passos estan aprovats. La feina es marca com a finalitzada.", "SIGN_ON_SITE": "Signatura del client", "SIGN_ON_SITE_INTRO": "Deixa que el client revisi la feina i signi amb el dit a la pantalla. Així s’aprova el pas.", "CUSTOMER_NAME": "Nom del client", "SIGNATURE": "Signatura", "SIGN_HERE": "Signa aquí", "APPROVE_WITH_SIGNATURE": "Aprova amb signatura", "CHANGE_PASSWORD": "Canvia la contrasenya", "CHANGE_PASSWORD_INTRO": "Aquí continuaràs amb la sessió iniciada. Als altres mòbils i navegadors es tancarà la sessió.", "CURRENT_PASSWORD": "Contrasenya actual", "CURRENT_PASSWORD_REQUIRED": "Introdueix la contrasenya actual.", "CURRENT_PASSWORD_WRONG": "Aquesta no és la teva contrasenya actual.", "NEW_PASSWORD": "Contrasenya nova", "REPEAT_PASSWORD": "Repeteix la contrasenya nova", "PASSWORDS_DONT_MATCH": "Les contrasenyes no coincideixen.", "PASSWORD_SAME_AS_OLD": "Tria una contrasenya que no hagis fet servir aquí.", "PASSWORD_CHANGED": "S’ha canviat la contrasenya", "PAYMENTS": "Pagaments", "PAYMENT": "Pagament", "NO_PAYMENTS": "Encara no hi ha pagaments", "NO_PAYMENTS_TEXT": "Aquí apareixen els pagaments fets a través de l’app. Les feines pagades amb factura són a Factures.", "PAYMENT_STATUS_PENDING": "Pendent", "PAYMENT_STATUS_HELD": "En dipòsit segur", "PAYMENT_STATUS_RELEASED": "Pagat", "PAYMENT_STATUS_REFUNDED": "Reemborsat", "PAYMENT_STATUS_FAILED": "Ha fallat", "PLATFORM_FEE": "Comissió {fee}", "TEAM": "Equip", "TEAM_ROW_HINT": "Les persones que treballen a l’empresa", "TEAM_MANAGE_HINT": "Els companys necessiten primer un compte de Qup Work. Toca algú per canviar-lo o treure’l.", "TEAM_WORKER_HINT": "El propietari i els administradors afegeixen i treuen companys.", "ADD_MEMBER": "Afegeix un company", "ADD_MEMBER_INTRO": "Fes servir el correu amb què es va registrar a Qup Work.", "MEMBER_NOT_FOUND": "Encara no s’ha registrat ningú amb aquest correu. Demana-li que primer es creï un compte.", "MEMBER_ALREADY": "Aquesta persona ja és a l’empresa.", "ROLE": "Rol", "ROLE_ADMIN_HINT": "Els administradors poden canviar les dades de l’empresa i la configuració de les factures, i afegir companys.", "ROLE_WORKER_HINT": "Els treballadors veuen les feines de l’empresa, registren hores i fan la feina.", "REMOVE_FROM_COMPANY": "Treu de l’empresa", "REMOVE_MEMBER_TITLE": "Vols treure’l de l’empresa?", "REMOVE_MEMBER_TEXT": "{name} ja no veurà les feines ni els clients de l’empresa.", "LEAVE_COMPANY": "Surt de l’empresa", "LEAVE_COMPANY_TITLE": "Vols sortir de l’empresa?", "LEAVE_COMPANY_TEXT": "Ja no veuràs les feines ni els clients de {name}.", "NOTIF_JOB_WITHDRAWN": "El client ha cancel·lat la feina", "INVOICE_EMAILED_TO": "{email} ha rebut la factura en PDF.", "INVOICE_NO_EMAIL": "Enviada, però no per correu: el client no té adreça electrònica. Obre el PDF i comparteix-lo tu, o fes servir Envia per correu.", "INVOICE_EMAIL_NOT_SET_UP": "Enviada, però no per correu: el correu encara no està configurat al servidor (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Enviada, però el correu ha fallat: {error}", "SEND_INVOICE_EMAIL_TO": "El PDF s'envia per correu a {email}.", "SEND_INVOICE_NO_EMAIL": "No hi ha adreça electrònica, així que no s'enviarà per correu. Pots compartir el PDF tu mateix.", "EMAIL_INVOICE": "Envia per correu", "PREVIEW_PDF": "Previsualitza el PDF", "OPEN_PDF": "Obre el PDF", "EMAILED": "Enviada per correu", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "No enviada per correu", "INVOICE_LANGUAGE": "Idioma de la factura", "NOTIF_NEW_JOB_NEARBY": "Nova feina a prop teu", "NOTIF_NEW_JOB_REMOTE": "Nova feina en remot", "NOTIF_JOB_INVITED": "T'han convidat a una feina", "NOTIF_JOB_IN_PLACE": "«{job}» a {place}", "JOB_ALERTS": "Avisos de feines noves", "JOB_ALERTS_ON_TEXT": "Reps un avís quan es publica una feina de les teves categories a la teva zona.", "JOB_ALERTS_OFF_TEXT": "No rebràs avisos de feines noves, però les pots continuar veient a l'app.", "JOB_ALERTS_NEEDS_VISIBLE": "Activa primer la visibilitat. Només els professionals que els clients poden trobar reben avisos.", "FORGOT_PASSWORD": "Has oblidat la contrasenya?", "FORGOT_PASSWORD_TITLE": "Contrasenya nova", "FORGOT_PASSWORD_INTRO": "Introdueix el correu amb què et vas registrar i t’enviarem un codi.", "SEND_CODE": "Envia el codi", "RESET_CODE_SENT": "Si {email} té un compte, t’arribarà un codi de 6 xifres. Introdueix-lo a continuació amb una contrasenya nova.", "RESET_CODE": "Codi del correu", "RESET_CODE_INVALID": "El codi té 6 xifres.", "RESET_CODE_WRONG": "El codi és incorrecte o ha caducat. Demana’n un de nou.", "SAVE_NEW_PASSWORD": "Desa i inicia la sessió", "RESET_CODE_AGAIN": "Envia un codi nou", "RESET_CODE_RESENT": "S’ha enviat un codi nou", "RESET_CODE_SPAM_HINT": "No t’ha arribat cap correu al cap d’uns minuts? Revisa la carpeta de correu brossa.", "DELETE_ACCOUNT": "Suprimeix el compte", "DELETE_ACCOUNT_INTRO": "Això suprimeix el compte de {email}. No es pot desfer.", "DELETE_WHAT_GOES": "S’elimina", "DELETE_GOES_PROFILE": "El teu nom, la foto, el telèfon i el correu", "DELETE_GOES_PRO": "El teu perfil professional, perquè els clients ja no et puguin trobar", "DELETE_GOES_JOBS": "Les feines obertes que has publicat i les ofertes que ningú no ha respost", "DELETE_GOES_LOGIN": "L’inici de sessió, a tots els dispositius", "DELETE_WHAT_STAYS": "Es conserva, sense el teu nom", "DELETE_STAYS_CONTRACTS": "Els contractes acabats, els missatges i les valoracions, perquè l’altra part els continuï tenint", "DELETE_STAYS_INVOICES": "Les factures, que la normativa comptable noruega obliga a conservar 5 anys", "DELETE_PASSWORD_HINT": "Per assegurar-nos que ets tu.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Vols suprimir el compte?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Es tancarà la sessió i no podràs tornar a iniciar la sessió amb aquest compte.", "DELETE_BLOCKED_CONTRACTS": "Tens contractes en curs. Completa’ls o cancel·la’ls primer, perquè l’altra part no es quedi esperant.", "DELETE_BLOCKED_COMPANY": "Ets propietari d’una empresa amb altres membres. Primer elimina’ls a Equip.", "JOB_CATEGORY_REQUIRED": "Tria una categoria perquè els professionals adequats sàpiguen de la feina."}, "ru-RU": {"EDIT": "Изменить", "REMOVE": "Убрать", "CLEAR": "Очистить", "ARCHIVE": "В архив", "NOTES": "Заметки", "YOU": "вы", "DATE_PLACEHOLDER": "дд.мм.гггг", "DATE_INVALID": "Введите дату в формате дд.мм.гггг.", "AMOUNT_INVALID": "Введите сумму в NOK, напр. 5000.", "EMAIL_INVALID": "Похоже, адрес эл. почты указан неверно.", "POSTCODE_FORMAT": "Почтовый индекс состоит из 4 цифр.", "CLIENT": "Клиент", "CLIENTS": "Клиенты", "CLIENTS_PRO_ONLY": "Собственная база клиентов доступна специалистам. Войдите с аккаунтом специалиста, чтобы ею пользоваться.", "SEARCH_CLIENTS": "Поиск клиентов", "CLIENTS_ACTIVE": "Активные", "CLIENTS_ARCHIVED": "В архиве", "NO_CLIENTS": "Клиентов пока нет", "NO_CLIENTS_TEXT": "Добавьте клиентов, с которыми вы работаете вне площадки, и держите их заказы, часы и счета в одном месте.", "NO_CLIENTS_MATCH": "По вашему запросу клиентов не найдено.", "NO_ARCHIVED_CLIENTS": "Архив пуст", "NO_ARCHIVED_CLIENTS_TEXT": "Сюда попадают клиенты, которых вы отправили в архив, вместе с их прошлыми заказами и счетами.", "NEW_CLIENT": "Новый клиент", "EDIT_CLIENT": "Изменить клиента", "SAVE_CLIENT": "Сохранить клиента", "CLIENT_FORM_INTRO": "Это видите только вы и ваша компания. Адрес используется как место работ в новых заказах.", "CLIENT_TYPE": "Тип клиента", "CLIENT_PRIVATE": "Частное лицо", "CLIENT_BUSINESS": "Компания", "CLIENT_COMPANY_PLACEHOLDER": "Напр. Bergen Eiendom AS", "CONTACT_PERSON": "Контактное лицо", "CONTACT_NAME": "Контакт: {name}", "CLIENT_EMAIL_HINT": "Сюда можно отправлять счета.", "CLIENT_NOTES_PLACEHOLDER": "Код ворот, парковка, кличка собаки…", "CLIENT_NOTES_HINT": "Только для вас и ваших коллег, клиент это никогда не увидит.", "CLIENT_NOT_FOUND": "Клиент не найден", "CLIENT_IS_ARCHIVED": "В архиве", "CLIENT_NO_DETAILS": "Контактных данных пока нет. Нажмите «Изменить», чтобы их добавить.", "CLIENT_JOBS": "Заказы", "CLIENT_NO_JOBS": "У этого клиента пока нет заказов.", "ARCHIVE_CLIENT": "Отправить клиента в архив", "ARCHIVE_CLIENT_TITLE": "Отправить клиента в архив?", "ARCHIVE_CLIENT_TEXT": "У клиента есть заказы, поэтому он сохранится вместе с заказами и счетами. Позже его можно восстановить.", "RESTORE_CLIENT": "Восстановить клиента", "DELETE_CLIENT": "Удалить клиента", "DELETE_CLIENT_TITLE": "Удалить этого клиента?", "DELETE_CLIENT_TEXT": "{name} будет удалён из вашей базы клиентов.", "NEW_ASSIGNMENT": "Новое задание", "NEW_ASSIGNMENT_INTRO": "Оформите работу для своего клиента и согласуйте цену. Этапы, часы и счета можно добавить в договоре.", "PICK_CLIENT_INTRO": "Для кого эта работа?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Что согласовано, материалы, что нужно знать клиенту", "START_DATE": "Дата начала", "END_DATE": "Дата окончания", "END_BEFORE_START": "Дата окончания раньше даты начала.", "STEPS_OPTIONAL_HINT": "Необязательно. Без этапов вся работа считается одним этапом.", "STEPS_SPLIT_HINT": "Каждый этап принимается отдельно. Сумма этапов должна совпадать с ценой.", "STEPS_HOURLY_HINT": "Каждый этап принимается отдельно. Часы учитываются в договоре.", "STEP_TITLE": "Этап", "STEP_TITLE_PLACEHOLDER": "Напр. Демонтаж и водосток", "STEP_TITLE_REQUIRED": "Дайте название каждому этапу.", "STEP_AMOUNT": "Сумма (NOK)", "STEP_AMOUNT_REQUIRED": "Укажите сумму для каждого этапа.", "STEP_DUE": "Срок", "STEP_DESCRIPTION_PLACEHOLDER": "Что входит в этот этап", "STEPS_MUST_ADD_UP": "Сумма этапов должна составлять {total}.", "STEPS_ADD_UP": "Сумма этапов совпадает с ценой ✓", "STEPS_REST": "Осталось распределить: {rest}", "STEPS_TOTAL_MISMATCH": "Сумма этапов — {steps}, согласованная цена — {total}.", "REMOVE_STEP": "Убрать этап", "ADD_STEP": "Добавить этап", "ADD_STEP_INTRO": "Заказчик принимает каждый этап, когда он готов.", "EDIT_STEP": "Изменить этап", "DELETE_STEP": "Удалить этап", "DELETE_STEP_TITLE": "Удалить этот этап?", "DELETE_STEP_TEXT": "«{title}» будет удалён из договора.", "STEP_STARTED_NO_DELETE": "Этот этап уже начат, поэтому его можно изменить, но нельзя удалить.", "CREATE_CONTRACT": "Создать договор", "JOB_HAS_CONTRACT": "У этого заказа уже есть договор.", "JOB_NOT_YOURS": "Изменять заказ может только тот, кто его создал.", "JOB_CANNOT_EDIT": "Исполнитель уже выбран, поэтому заказ больше нельзя изменить.", "EDIT_JOB": "Изменить заказ", "EDIT_JOB_INTRO": "Специалисты сразу увидят изменения.", "EDIT_JOB_WITH_OFFERS": "Получено предложений: {n}. Расскажите специалистам о крупных изменениях в чате, чтобы их предложения оставались актуальными.", "CREATED_AGO": "Создано {time}", "DRAFT_NOT_VISIBLE": "Это черновик. Специалисты не увидят его, пока вы его не опубликуете.", "CANCEL_JOB": "Отменить заказ", "CANCEL_JOB_TITLE": "Отменить этот заказ?", "CANCEL_JOB_TEXT": "Заказ будет снят и не может быть открыт снова.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Заказ будет снят, а специалисты, отправившие предложения ({n}), узнают, что он отменён.", "DELETE_JOB_TITLE": "Удалить черновик?", "DELETE_JOB_TEXT": "Черновик будет удалён навсегда.", "CANCEL_CONTRACT": "Расторгнуть договор", "CANCEL_CONTRACT_INTRO": "Работа на этом останавливается. Принятые этапы и счета сохраняются, а другая сторона получит уведомление.", "CANCEL_REASON": "Почему? (необязательно)", "CANCEL_REASON_PLACEHOLDER": "Пара слов, которые вы оба сможете увидеть позже", "CONTRACT_CANCELLED_ON": "Расторгнут {date}", "COMPLETE_CLIENT_JOB_TEXT": "Все этапы подписаны. Заказ будет отмечен как завершённый.", "SIGN_ON_SITE": "Подпись заказчика", "SIGN_ON_SITE_INTRO": "Дайте заказчику проверить работу и расписаться пальцем на экране. Так этап будет принят.", "CUSTOMER_NAME": "Имя заказчика", "SIGNATURE": "Подпись", "SIGN_HERE": "Распишитесь здесь", "APPROVE_WITH_SIGNATURE": "Принять с подписью", "CHANGE_PASSWORD": "Сменить пароль", "CHANGE_PASSWORD_INTRO": "Здесь вы останетесь в аккаунте. На других телефонах и в браузерах произойдёт выход.", "CURRENT_PASSWORD": "Текущий пароль", "CURRENT_PASSWORD_REQUIRED": "Введите текущий пароль.", "CURRENT_PASSWORD_WRONG": "Это не ваш текущий пароль.", "NEW_PASSWORD": "Новый пароль", "REPEAT_PASSWORD": "Повторите новый пароль", "PASSWORDS_DONT_MATCH": "Пароли не совпадают.", "PASSWORD_SAME_AS_OLD": "Выберите пароль, который вы здесь ещё не использовали.", "PASSWORD_CHANGED": "Пароль изменён", "PAYMENTS": "Платежи", "PAYMENT": "Платёж", "NO_PAYMENTS": "Платежей пока нет", "NO_PAYMENTS_TEXT": "Здесь появляются платежи через приложение. Заказы, оплаченные по счёту, находятся в разделе «Счета».", "PAYMENT_STATUS_PENDING": "Ожидает", "PAYMENT_STATUS_HELD": "Надёжно удерживается", "PAYMENT_STATUS_RELEASED": "Выплачено", "PAYMENT_STATUS_REFUNDED": "Возвращено", "PAYMENT_STATUS_FAILED": "Не удалось", "PLATFORM_FEE": "Комиссия {fee}", "TEAM": "Команда", "TEAM_ROW_HINT": "Люди, которые работают в компании", "TEAM_MANAGE_HINT": "Сначала коллегам нужен аккаунт Qup Work. Нажмите на человека, чтобы изменить его роль или удалить.", "TEAM_WORKER_HINT": "Коллег добавляют и удаляют владелец и администраторы.", "ADD_MEMBER": "Добавить коллегу", "ADD_MEMBER_INTRO": "Укажите эл. почту, с которой коллега зарегистрировался в Qup Work.", "MEMBER_NOT_FOUND": "С этой эл. почтой ещё никто не зарегистрировался. Попросите коллегу сначала создать аккаунт.", "MEMBER_ALREADY": "Этот человек уже в компании.", "ROLE": "Роль", "ROLE_ADMIN_HINT": "Администраторы могут менять данные компании и настройки счетов, а также добавлять коллег.", "ROLE_WORKER_HINT": "Сотрудники видят заказы компании, учитывают часы и выполняют работу.", "REMOVE_FROM_COMPANY": "Удалить из компании", "REMOVE_MEMBER_TITLE": "Удалить из компании?", "REMOVE_MEMBER_TEXT": "{name} больше не будет видеть заказы и клиентов компании.", "LEAVE_COMPANY": "Покинуть компанию", "LEAVE_COMPANY_TITLE": "Покинуть компанию?", "LEAVE_COMPANY_TEXT": "Вы больше не будете видеть заказы и клиентов {name}.", "NOTIF_JOB_WITHDRAWN": "Заказчик отменил заказ", "INVOICE_EMAILED_TO": "{email} получил счёт в PDF.", "INVOICE_NO_EMAIL": "Отправлен, но не по почте: у клиента нет адреса электронной почты. Откройте PDF и поделитесь им сами или используйте Отправить по почте.", "INVOICE_EMAIL_NOT_SET_UP": "Отправлен, но не по почте: почта ещё не настроена на сервере (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Отправлен, но письмо не ушло: {error}", "SEND_INVOICE_EMAIL_TO": "PDF будет отправлен по почте на {email}.", "SEND_INVOICE_NO_EMAIL": "Адреса электронной почты нет, поэтому письмо не отправится. Вы можете поделиться PDF сами.", "EMAIL_INVOICE": "Отправить по почте", "PREVIEW_PDF": "Просмотр PDF", "OPEN_PDF": "Открыть PDF", "EMAILED": "Отправлен по почте", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Не отправлен по почте", "INVOICE_LANGUAGE": "Язык счёта", "NOTIF_NEW_JOB_NEARBY": "Новый заказ рядом с вами", "NOTIF_NEW_JOB_REMOTE": "Новый удалённый заказ", "NOTIF_JOB_INVITED": "Вас пригласили на заказ", "NOTIF_JOB_IN_PLACE": "«{job}» — {place}", "JOB_ALERTS": "Уведомления о новых заказах", "JOB_ALERTS_ON_TEXT": "Вы получите уведомление, когда в вашем районе появится заказ из ваших категорий.", "JOB_ALERTS_OFF_TEXT": "Уведомлений о новых заказах не будет, но вы по-прежнему увидите их в приложении.", "JOB_ALERTS_NEEDS_VISIBLE": "Сначала включите видимость. Уведомления получают только мастера, которых могут найти клиенты.", "FORGOT_PASSWORD": "Забыли пароль?", "FORGOT_PASSWORD_TITLE": "Новый пароль", "FORGOT_PASSWORD_INTRO": "Введите эл. почту, указанную при регистрации, и мы отправим вам код.", "SEND_CODE": "Отправить код", "RESET_CODE_SENT": "Если для {email} есть аккаунт, 6-значный код уже в пути. Введите его ниже вместе с новым паролем.", "RESET_CODE": "Код из письма", "RESET_CODE_INVALID": "Код состоит из 6 цифр.", "RESET_CODE_WRONG": "Код неверный или устарел. Запросите новый.", "SAVE_NEW_PASSWORD": "Сохранить и войти", "RESET_CODE_AGAIN": "Отправить новый код", "RESET_CODE_RESENT": "Новый код отправлен", "RESET_CODE_SPAM_HINT": "Письмо не пришло через несколько минут? Проверьте папку «Спам».", "DELETE_ACCOUNT": "Удалить аккаунт", "DELETE_ACCOUNT_INTRO": "Аккаунт {email} будет удалён. Это действие нельзя отменить.", "DELETE_WHAT_GOES": "Будет удалено", "DELETE_GOES_PROFILE": "Ваше имя, фото, телефон и эл. почта", "DELETE_GOES_PRO": "Ваш профиль специалиста — клиенты больше не смогут вас найти", "DELETE_GOES_JOBS": "Открытые заказы, которые вы опубликовали, и предложения, на которые никто не ответил", "DELETE_GOES_LOGIN": "Ваш вход на всех устройствах", "DELETE_WHAT_STAYS": "Сохранится, но без вашего имени", "DELETE_STAYS_CONTRACTS": "Завершённые договоры, сообщения и отзывы — чтобы они остались у другой стороны", "DELETE_STAYS_INVOICES": "Счета, которые по норвежским правилам бухгалтерского учёта нужно хранить 5 лет", "DELETE_PASSWORD_HINT": "Чтобы убедиться, что это вы.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Удалить аккаунт?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Вы выйдете из аккаунта и больше не сможете в него войти.", "DELETE_BLOCKED_CONTRACTS": "У вас есть текущие договоры. Сначала завершите или расторгните их, чтобы другой стороне не пришлось ждать.", "DELETE_BLOCKED_COMPANY": "Вы владеете компанией, в которой есть другие участники. Сначала удалите их в разделе «Команда».", "JOB_CATEGORY_REQUIRED": "Выберите категорию, чтобы о заказе узнали подходящие специалисты."}, "sk-SK": {"EDIT": "Upraviť", "REMOVE": "Odstrániť", "CLEAR": "Vymazať", "ARCHIVE": "Archivovať", "NOTES": "Poznámky", "YOU": "ty", "DATE_PLACEHOLDER": "dd.mm.rrrr", "DATE_INVALID": "Napíš dátum v tvare dd.mm.rrrr.", "AMOUNT_INVALID": "Napíš sumu v NOK, napr. 5000.", "EMAIL_INVALID": "Táto e-mailová adresa nevyzerá správne.", "POSTCODE_FORMAT": "PSČ má 4 číslice.", "CLIENT": "Klient", "CLIENTS": "Klienti", "CLIENTS_PRO_ONLY": "Vlastný register klientov je pre remeselníkov. Ak ho chceš používať, prihlás sa s účtom remeselníka.", "SEARCH_CLIENTS": "Hľadať klientov", "CLIENTS_ACTIVE": "Aktívni", "CLIENTS_ARCHIVED": "Archivovaní", "NO_CLIENTS": "Zatiaľ žiadni klienti", "NO_CLIENTS_TEXT": "Pridaj zákazníkov, pre ktorých pracuješ mimo platformy, a maj ich zákazky, hodiny a faktúry na jednom mieste.", "NO_CLIENTS_MATCH": "Vyhľadávaniu nezodpovedajú žiadni klienti.", "NO_ARCHIVED_CLIENTS": "Nič archivované", "NO_ARCHIVED_CLIENTS_TEXT": "Klienti, ktorých archivuješ, skončia tu aj so starými zákazkami a faktúrami.", "NEW_CLIENT": "Nový klient", "EDIT_CLIENT": "Upraviť klienta", "SAVE_CLIENT": "Uložiť klienta", "CLIENT_FORM_INTRO": "Vidíš to len ty a tvoja firma. Adresa sa použije ako miesto práce pri nových zákazkách.", "CLIENT_TYPE": "Typ klienta", "CLIENT_PRIVATE": "Súkromná osoba", "CLIENT_BUSINESS": "Firma", "CLIENT_COMPANY_PLACEHOLDER": "Napr. Bergen Eiendom AS", "CONTACT_PERSON": "Kontaktná osoba", "CONTACT_NAME": "Kontakt: {name}", "CLIENT_EMAIL_HINT": "Sem je možné posielať faktúry.", "CLIENT_NOTES_PLACEHOLDER": "Kód od brány, parkovanie, meno psa…", "CLIENT_NOTES_HINT": "Len pre teba a tvojich kolegov, klientovi sa nikdy nezobrazí.", "CLIENT_NOT_FOUND": "Klient sa nenašiel", "CLIENT_IS_ARCHIVED": "Archivovaný", "CLIENT_NO_DETAILS": "Zatiaľ žiadne kontaktné údaje. Ťukni na Upraviť a pridaj ich.", "CLIENT_JOBS": "Zákazky", "CLIENT_NO_JOBS": "Pre tohto klienta zatiaľ nie sú žiadne zákazky.", "ARCHIVE_CLIENT": "Archivovať klienta", "ARCHIVE_CLIENT_TITLE": "Archivovať tohto klienta?", "ARCHIVE_CLIENT_TEXT": "Klient má zákazky, takže sa zachová spolu so zákazkami a faktúrami. Neskôr ho môžeš obnoviť.", "RESTORE_CLIENT": "Obnoviť klienta", "DELETE_CLIENT": "Vymazať klienta", "DELETE_CLIENT_TITLE": "Vymazať tohto klienta?", "DELETE_CLIENT_TEXT": "{name} sa odstráni z tvojho registra.", "NEW_ASSIGNMENT": "Nová zákazka", "NEW_ASSIGNMENT_INTRO": "Zaeviduj prácu pre vlastného klienta a dohodni cenu. V zmluve môžeš pridať kroky, zapisovať hodiny a fakturovať.", "PICK_CLIENT_INTRO": "Pre koho je práca?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Čo je dohodnuté, materiál, čo by mal klient vedieť", "START_DATE": "Dátum začatia", "END_DATE": "Dátum ukončenia", "END_BEFORE_START": "Dátum ukončenia je pred dátumom začatia.", "STEPS_OPTIONAL_HINT": "Nepovinné. Bez krokov je celá zákazka jeden krok.", "STEPS_SPLIT_HINT": "Každý krok sa schvaľuje samostatne. Sumy musia dať dokopy cenu.", "STEPS_HOURLY_HINT": "Každý krok sa schvaľuje samostatne. Hodiny sa zapisujú do zmluvy.", "STEP_TITLE": "Krok", "STEP_TITLE_PLACEHOLDER": "Napr. Búracie práce a odtok", "STEP_TITLE_REQUIRED": "Daj každému kroku názov.", "STEP_AMOUNT": "Suma (NOK)", "STEP_AMOUNT_REQUIRED": "Zadaj sumu pre každý krok.", "STEP_DUE": "Termín", "STEP_DESCRIPTION_PLACEHOLDER": "Čo zahŕňa tento krok", "STEPS_MUST_ADD_UP": "Kroky musia dať dokopy {total}.", "STEPS_ADD_UP": "Kroky dávajú dokopy cenu ✓", "STEPS_REST": "Zostáva rozdeliť: {rest}", "STEPS_TOTAL_MISMATCH": "Kroky dávajú dokopy {steps}, dohodnutá cena je {total}.", "REMOVE_STEP": "Odstrániť krok", "ADD_STEP": "Pridať krok", "ADD_STEP_INTRO": "Zákazník schváli každý krok, keď je hotový.", "EDIT_STEP": "Upraviť krok", "DELETE_STEP": "Vymazať krok", "DELETE_STEP_TITLE": "Vymazať tento krok?", "DELETE_STEP_TEXT": "„{title}“ sa odstráni zo zmluvy.", "STEP_STARTED_NO_DELETE": "Tento krok sa už začal, takže ho možno upraviť, ale nie vymazať.", "CREATE_CONTRACT": "Vytvoriť zmluvu", "JOB_HAS_CONTRACT": "Táto zákazka už má zmluvu.", "JOB_NOT_YOURS": "Zákazku môže meniť len ten, kto ju vytvoril.", "JOB_CANNOT_EDIT": "Niekto už je najatý, takže zákazku už nemožno meniť.", "EDIT_JOB": "Upraviť zákazku", "EDIT_JOB_INTRO": "Odborníci uvidia zmeny hneď.", "EDIT_JOB_WITH_OFFERS": "Prijaté ponuky: {n}. O veľkých zmenách daj odborníkom vedieť v chate, aby ich ponuky stále sedeli.", "CREATED_AGO": "Vytvorené {time}", "DRAFT_NOT_VISIBLE": "Toto je koncept. Odborníci ho neuvidia, kým ho nezverejníš.", "CANCEL_JOB": "Zrušiť zákazku", "CANCEL_JOB_TITLE": "Zrušiť túto zákazku?", "CANCEL_JOB_TEXT": "Zákazka sa stiahne a nedá sa znova otvoriť.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Zákazka sa stiahne a odborníci, ktorí poslali ponuky ({n}), dostanú správu, že bola zrušená.", "DELETE_JOB_TITLE": "Vymazať koncept?", "DELETE_JOB_TEXT": "Koncept sa natrvalo vymaže.", "CANCEL_CONTRACT": "Zrušiť zmluvu", "CANCEL_CONTRACT_INTRO": "Práca sa tu zastaví. Schválené kroky a faktúry zostanú a druhá strana dostane správu.", "CANCEL_REASON": "Prečo? (nepovinné)", "CANCEL_REASON_PLACEHOLDER": "Pár slov, ktoré neskôr uvidíte obaja", "CONTRACT_CANCELLED_ON": "Zrušené {date}", "COMPLETE_CLIENT_JOB_TEXT": "Všetky kroky sú podpísané. Zákazka sa označí ako dokončená.", "SIGN_ON_SITE": "Zákazník podpíše", "SIGN_ON_SITE_INTRO": "Nechaj zákazníka skontrolovať prácu a podpísať sa prstom na obrazovke. Tým sa krok schváli.", "CUSTOMER_NAME": "Meno zákazníka", "SIGNATURE": "Podpis", "SIGN_HERE": "Podpíšte sa tu", "APPROVE_WITH_SIGNATURE": "Schváliť podpisom", "CHANGE_PASSWORD": "Zmeniť heslo", "CHANGE_PASSWORD_INTRO": "Tu zostaneš prihlásený. Na ostatných telefónoch a v prehliadačoch ťa odhlásime.", "CURRENT_PASSWORD": "Súčasné heslo", "CURRENT_PASSWORD_REQUIRED": "Zadaj svoje súčasné heslo.", "CURRENT_PASSWORD_WRONG": "To nie je tvoje súčasné heslo.", "NEW_PASSWORD": "Nové heslo", "REPEAT_PASSWORD": "Zopakuj nové heslo", "PASSWORDS_DONT_MATCH": "Heslá sa nezhodujú.", "PASSWORD_SAME_AS_OLD": "Vyber si heslo, ktoré si tu ešte nepoužil.", "PASSWORD_CHANGED": "Heslo bolo zmenené", "PAYMENTS": "Platby", "PAYMENT": "Platba", "NO_PAYMENTS": "Zatiaľ žiadne platby", "NO_PAYMENTS_TEXT": "Tu sa zobrazia platby cez aplikáciu. Zákazky platené faktúrou nájdeš vo Faktúrach.", "PAYMENT_STATUS_PENDING": "Čaká sa", "PAYMENT_STATUS_HELD": "Bezpečne držané", "PAYMENT_STATUS_RELEASED": "Vyplatené", "PAYMENT_STATUS_REFUNDED": "Vrátené", "PAYMENT_STATUS_FAILED": "Zlyhalo", "PLATFORM_FEE": "Poplatok {fee}", "TEAM": "Tím", "TEAM_ROW_HINT": "Ľudia, ktorí pracujú vo firme", "TEAM_MANAGE_HINT": "Kolegovia najprv potrebujú účet Qup Work. Ťukni na niekoho, ak ho chceš upraviť alebo odstrániť.", "TEAM_WORKER_HINT": "Kolegov pridáva a odstraňuje vlastník a administrátori.", "ADD_MEMBER": "Pridať kolegu", "ADD_MEMBER_INTRO": "Použi e-mail, s ktorým sa zaregistroval v Qup Work.", "MEMBER_NOT_FOUND": "S týmto e-mailom sa ešte nikto nezaregistroval. Popros ho, aby si najprv vytvoril účet.", "MEMBER_ALREADY": "Táto osoba už vo firme je.", "ROLE": "Rola", "ROLE_ADMIN_HINT": "Administrátori môžu meniť údaje firmy a nastavenia faktúr a pridávať kolegov.", "ROLE_WORKER_HINT": "Zamestnanci vidia zákazky firmy, zapisujú hodiny a robia prácu.", "REMOVE_FROM_COMPANY": "Odstrániť z firmy", "REMOVE_MEMBER_TITLE": "Odstrániť z firmy?", "REMOVE_MEMBER_TEXT": "{name} už neuvidí zákazky a klientov firmy.", "LEAVE_COMPANY": "Odísť z firmy", "LEAVE_COMPANY_TITLE": "Odísť z firmy?", "LEAVE_COMPANY_TEXT": "Už neuvidíš zákazky a klientov firmy {name}.", "NOTIF_JOB_WITHDRAWN": "Zákazník zrušil zákazku", "INVOICE_EMAILED_TO": "{email} dostal faktúru ako PDF.", "INVOICE_NO_EMAIL": "Odoslané, ale nie e-mailom: zákazník nemá e-mailovú adresu. Otvorte PDF a zdieľajte ho sami, alebo použite Poslať e-mailom.", "INVOICE_EMAIL_NOT_SET_UP": "Odoslané, ale nie e-mailom: e-mail ešte nie je na serveri nastavený (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Odoslané, ale e-mail zlyhal: {error}", "SEND_INVOICE_EMAIL_TO": "PDF sa pošle e-mailom na {email}.", "SEND_INVOICE_NO_EMAIL": "Chýba e-mailová adresa, takže sa nepošle e-mailom. PDF môžete zdieľať sami.", "EMAIL_INVOICE": "Poslať e-mailom", "PREVIEW_PDF": "Náhľad PDF", "OPEN_PDF": "Otvoriť PDF", "EMAILED": "Poslané e-mailom", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Neposlané e-mailom", "INVOICE_LANGUAGE": "Jazyk faktúry", "NOTIF_NEW_JOB_NEARBY": "Nová zákazka vo vašom okolí", "NOTIF_NEW_JOB_REMOTE": "Nová zákazka na diaľku", "NOTIF_JOB_INVITED": "Boli ste pozvaní k zákazke", "NOTIF_JOB_IN_PLACE": "„{job}“ – {place}", "JOB_ALERTS": "Upozornenia na nové zákazky", "JOB_ALERTS_ON_TEXT": "Dostanete upozornenie, keď sa vo vašom okolí objaví zákazka z vašich kategórií.", "JOB_ALERTS_OFF_TEXT": "Upozornenia na nové zákazky nedostanete, ale v aplikácii ich stále uvidíte.", "JOB_ALERTS_NEEDS_VISIBLE": "Najprv zapnite viditeľnosť. Upozornenia dostávajú iba odborníci, ktorých zákazníci nájdu.", "FORGOT_PASSWORD": "Zabudnuté heslo?", "FORGOT_PASSWORD_TITLE": "Nové heslo", "FORGOT_PASSWORD_INTRO": "Zadaj e-mail, s ktorým si sa zaregistroval, a pošleme ti kód.", "SEND_CODE": "Poslať kód", "RESET_CODE_SENT": "Ak má {email} účet, 6-miestny kód je na ceste. Zadaj ho nižšie spolu s novým heslom.", "RESET_CODE": "Kód z e-mailu", "RESET_CODE_INVALID": "Kód má 6 číslic.", "RESET_CODE_WRONG": "Kód je nesprávny alebo jeho platnosť vypršala. Požiadaj o nový.", "SAVE_NEW_PASSWORD": "Uložiť a prihlásiť sa", "RESET_CODE_AGAIN": "Poslať nový kód", "RESET_CODE_RESENT": "Nový kód bol odoslaný", "RESET_CODE_SPAM_HINT": "Žiadny e-mail ani po pár minútach? Pozri si priečinok so spamom.", "DELETE_ACCOUNT": "Vymazať účet", "DELETE_ACCOUNT_INTRO": "Týmto sa vymaže účet pre {email}. Nedá sa to vrátiť späť.", "DELETE_WHAT_GOES": "Vymaže sa", "DELETE_GOES_PROFILE": "Tvoje meno, fotka, telefón a e-mail", "DELETE_GOES_PRO": "Tvoj profil remeselníka, takže ťa zákazníci už nenájdu", "DELETE_GOES_JOBS": "Otvorené zákazky, ktoré si zverejnil, a ponuky, na ktoré nikto neodpovedal", "DELETE_GOES_LOGIN": "Tvoje prihlásenie na všetkých zariadeniach", "DELETE_WHAT_STAYS": "Zostane, bez tvojho mena", "DELETE_STAYS_CONTRACTS": "Dokončené zmluvy, správy a hodnotenia, aby ich druhá strana stále mala", "DELETE_STAYS_INVOICES": "Faktúry, ktoré podľa nórskych účtovných pravidiel treba uchovávať 5 rokov", "DELETE_PASSWORD_HINT": "Aby sme si boli istí, že si to ty.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Vymazať účet?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Budeš odhlásený a s týmto účtom sa už neprihlásiš.", "DELETE_BLOCKED_CONTRACTS": "Máš prebiehajúce zmluvy. Najprv ich dokonči alebo zruš, aby druhá strana nemusela čakať.", "DELETE_BLOCKED_COMPANY": "Vlastníš firmu s ďalšími členmi. Najprv ich odstráň v sekcii Tím.", "JOB_CATEGORY_REQUIRED": "Vyber kategóriu, aby sa o zákazke dozvedeli tí správni remeselníci."}, "he-IL": {"EDIT": "עריכה", "REMOVE": "הסרה", "CLEAR": "ניקוי", "ARCHIVE": "העברה לארכיון", "NOTES": "הערות", "YOU": "את/ה", "DATE_PLACEHOLDER": "יי/חח/שששש", "DATE_INVALID": "כתבו את התאריך בפורמט יי/חח/שששש.", "AMOUNT_INVALID": "כתבו סכום ב־NOK, למשל 5000.", "EMAIL_INVALID": "כתובת האימייל הזו לא נראית תקינה.", "POSTCODE_FORMAT": "מיקוד כולל 4 ספרות.", "CLIENT": "לקוח", "CLIENTS": "לקוחות", "CLIENTS_PRO_ONLY": "מאגר הלקוחות האישי מיועד לבעלי מקצוע. התחברו עם חשבון בעל מקצוע כדי להשתמש בו.", "SEARCH_CLIENTS": "חיפוש לקוחות", "CLIENTS_ACTIVE": "פעילים", "CLIENTS_ARCHIVED": "בארכיון", "NO_CLIENTS": "עדיין אין לקוחות", "NO_CLIENTS_TEXT": "הוסיפו את הלקוחות שאתם עובדים עבורם מחוץ לפלטפורמה, ושמרו את העבודות, השעות והחשבוניות שלהם במקום אחד.", "NO_CLIENTS_MATCH": "אין לקוחות שתואמים לחיפוש.", "NO_ARCHIVED_CLIENTS": "אין שום דבר בארכיון", "NO_ARCHIVED_CLIENTS_TEXT": "לקוחות שתעבירו לארכיון יופיעו כאן, עם העבודות והחשבוניות הקודמות שלהם.", "NEW_CLIENT": "לקוח חדש", "EDIT_CLIENT": "עריכת לקוח", "SAVE_CLIENT": "שמירת לקוח", "CLIENT_FORM_INTRO": "רק אתם והעסק שלכם יכולים לראות את זה. הכתובת משמשת ככתובת העבודה בעבודות חדשות.", "CLIENT_TYPE": "סוג לקוח", "CLIENT_PRIVATE": "אדם פרטי", "CLIENT_BUSINESS": "עסק", "CLIENT_COMPANY_PLACEHOLDER": "למשל Bergen Eiendom AS", "CONTACT_PERSON": "איש קשר", "CONTACT_NAME": "איש קשר: {name}", "CLIENT_EMAIL_HINT": "אפשר לשלוח לכאן חשבוניות.", "CLIENT_NOTES_PLACEHOLDER": "קוד לשער, חניה, השם של הכלב…", "CLIENT_NOTES_HINT": "רק בשבילכם ובשביל העמיתים שלכם, אף פעם לא מוצג ללקוח.", "CLIENT_NOT_FOUND": "הלקוח לא נמצא", "CLIENT_IS_ARCHIVED": "בארכיון", "CLIENT_NO_DETAILS": "עדיין אין פרטי קשר. הקישו על „עריכה” כדי להוסיף אותם.", "CLIENT_JOBS": "עבודות", "CLIENT_NO_JOBS": "עדיין אין עבודות ללקוח הזה.", "ARCHIVE_CLIENT": "העברת הלקוח לארכיון", "ARCHIVE_CLIENT_TITLE": "להעביר את הלקוח לארכיון?", "ARCHIVE_CLIENT_TEXT": "ללקוח יש עבודות, ולכן הוא נשמר יחד עם העבודות והחשבוניות שלו. אפשר לשחזר אותו בהמשך.", "RESTORE_CLIENT": "שחזור לקוח", "DELETE_CLIENT": "מחיקת לקוח", "DELETE_CLIENT_TITLE": "למחוק את הלקוח הזה?", "DELETE_CLIENT_TEXT": "{name} יוסר מהמאגר שלכם.", "NEW_ASSIGNMENT": "משימה חדשה", "NEW_ASSIGNMENT_INTRO": "רשמו עבודה עבור לקוח משלכם וסכמו על המחיר. מתוך החוזה אפשר להוסיף שלבים, לרשום שעות ולהוציא חשבונית.", "PICK_CLIENT_INTRO": "בשביל מי העבודה?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "מה סוכם, חומרים, כל מה שהלקוח צריך לדעת", "START_DATE": "תאריך התחלה", "END_DATE": "תאריך סיום", "END_BEFORE_START": "תאריך הסיום מוקדם מתאריך ההתחלה.", "STEPS_OPTIONAL_HINT": "לא חובה. בלי שלבים, כל העבודה היא שלב אחד.", "STEPS_SPLIT_HINT": "כל שלב מאושר בנפרד. סכום השלבים צריך להיות שווה למחיר.", "STEPS_HOURLY_HINT": "כל שלב מאושר בנפרד. השעות נרשמות בחוזה.", "STEP_TITLE": "שלב", "STEP_TITLE_PLACEHOLDER": "למשל פירוק וניקוז", "STEP_TITLE_REQUIRED": "תנו שם לכל שלב.", "STEP_AMOUNT": "סכום (NOK)", "STEP_AMOUNT_REQUIRED": "הזינו סכום לכל שלב.", "STEP_DUE": "תאריך יעד", "STEP_DESCRIPTION_PLACEHOLDER": "מה כלול בשלב הזה", "STEPS_MUST_ADD_UP": "סכום השלבים צריך להיות {total}.", "STEPS_ADD_UP": "סכום השלבים שווה למחיר ✓", "STEPS_REST": "נותר לחלוקה: {rest}", "STEPS_TOTAL_MISMATCH": "סכום השלבים הוא {steps}, והמחיר המוסכם הוא {total}.", "REMOVE_STEP": "הסרת שלב", "ADD_STEP": "הוספת שלב", "ADD_STEP_INTRO": "הלקוח מאשר כל שלב כשהוא מסתיים.", "EDIT_STEP": "עריכת שלב", "DELETE_STEP": "מחיקת שלב", "DELETE_STEP_TITLE": "למחוק את השלב הזה?", "DELETE_STEP_TEXT": "„{title}” יוסר מהחוזה.", "STEP_STARTED_NO_DELETE": "השלב הזה כבר התחיל, אז אפשר לשנות אותו אבל לא למחוק.", "CREATE_CONTRACT": "יצירת חוזה", "JOB_HAS_CONTRACT": "לעבודה הזו כבר יש חוזה.", "JOB_NOT_YOURS": "רק מי שיצר את העבודה יכול לשנות אותה.", "JOB_CANNOT_EDIT": "מישהו כבר נשכר, ולכן אי אפשר לשנות יותר את העבודה.", "EDIT_JOB": "עריכת עבודה", "EDIT_JOB_INTRO": "בעלי המקצוע רואים את השינויים מיד.", "EDIT_JOB_WITH_OFFERS": "התקבלו הצעות: {n}. ספרו לבעלי המקצוע בצ׳אט על שינויים גדולים, כדי שההצעות שלהם עדיין יתאימו.", "CREATED_AGO": "נוצרה {time}", "DRAFT_NOT_VISIBLE": "זו טיוטה. בעלי מקצוע לא יראו אותה עד שתפרסמו אותה.", "CANCEL_JOB": "ביטול העבודה", "CANCEL_JOB_TITLE": "לבטל את העבודה הזו?", "CANCEL_JOB_TEXT": "העבודה תוסר ולא ניתן יהיה לפתוח אותה מחדש.", "CANCEL_JOB_WITH_OFFERS_TEXT": "העבודה תוסר, ובעלי המקצוע ששלחו הצעות ({n}) יקבלו הודעה שהיא בוטלה.", "DELETE_JOB_TITLE": "למחוק את הטיוטה?", "DELETE_JOB_TEXT": "הטיוטה תימחק לצמיתות.", "CANCEL_CONTRACT": "ביטול החוזה", "CANCEL_CONTRACT_INTRO": "העבודה נעצרת כאן. שלבים שאושרו וחשבוניות נשמרים, והצד השני מקבל הודעה.", "CANCEL_REASON": "למה? (לא חובה)", "CANCEL_REASON_PLACEHOLDER": "כמה מילים ששניכם תוכלו לראות אחר כך", "CONTRACT_CANCELLED_ON": "בוטל ב־{date}", "COMPLETE_CLIENT_JOB_TEXT": "כל השלבים אושרו. העבודה מסומנת כהושלמה.", "SIGN_ON_SITE": "חתימת הלקוח", "SIGN_ON_SITE_INTRO": "תנו ללקוח לבדוק את העבודה ולחתום באצבע על המסך. כך השלב מאושר.", "CUSTOMER_NAME": "שם הלקוח", "SIGNATURE": "חתימה", "SIGN_HERE": "חתמו כאן", "APPROVE_WITH_SIGNATURE": "אישור עם חתימה", "CHANGE_PASSWORD": "שינוי סיסמה", "CHANGE_PASSWORD_INTRO": "כאן תישארו מחוברים. בטלפונים ובדפדפנים האחרים שלכם תתבצע התנתקות.", "CURRENT_PASSWORD": "הסיסמה הנוכחית", "CURRENT_PASSWORD_REQUIRED": "הזינו את הסיסמה הנוכחית.", "CURRENT_PASSWORD_WRONG": "זו לא הסיסמה הנוכחית שלכם.", "NEW_PASSWORD": "סיסמה חדשה", "REPEAT_PASSWORD": "הזינו שוב את הסיסמה החדשה", "PASSWORDS_DONT_MATCH": "הסיסמאות לא תואמות.", "PASSWORD_SAME_AS_OLD": "בחרו סיסמה שעוד לא השתמשתם בה כאן.", "PASSWORD_CHANGED": "הסיסמה שונתה", "PAYMENTS": "תשלומים", "PAYMENT": "תשלום", "NO_PAYMENTS": "עדיין אין תשלומים", "NO_PAYMENTS_TEXT": "תשלומים שבוצעו דרך האפליקציה מופיעים כאן. עבודות ששולמו בחשבונית נמצאות תחת „חשבוניות”.", "PAYMENT_STATUS_PENDING": "ממתין", "PAYMENT_STATUS_HELD": "מוחזק בבטחה", "PAYMENT_STATUS_RELEASED": "שולם", "PAYMENT_STATUS_REFUNDED": "הוחזר", "PAYMENT_STATUS_FAILED": "נכשל", "PLATFORM_FEE": "עמלה {fee}", "TEAM": "צוות", "TEAM_ROW_HINT": "האנשים שעובדים בעסק", "TEAM_MANAGE_HINT": "לעמיתים צריך להיות קודם חשבון Qup Work. הקישו על מישהו כדי לשנות או להסיר אותו.", "TEAM_WORKER_HINT": "הבעלים והמנהלים מוסיפים ומסירים עמיתים.", "ADD_MEMBER": "הוספת עמית", "ADD_MEMBER_INTRO": "השתמשו באימייל שאיתו הם נרשמו ל־Qup Work.", "MEMBER_NOT_FOUND": "עדיין אף אחד לא נרשם עם האימייל הזה. בקשו מהם ליצור חשבון קודם.", "MEMBER_ALREADY": "האדם הזה כבר נמצא בעסק.", "ROLE": "תפקיד", "ROLE_ADMIN_HINT": "מנהלים יכולים לשנות את פרטי העסק ואת הגדרות החשבוניות, ולהוסיף עמיתים.", "ROLE_WORKER_HINT": "עובדים רואים את העבודות של העסק, רושמים שעות ומבצעים את העבודה.", "REMOVE_FROM_COMPANY": "הסרה מהעסק", "REMOVE_MEMBER_TITLE": "להסיר מהעסק?", "REMOVE_MEMBER_TEXT": "{name} כבר לא יראה את העבודות והלקוחות של העסק.", "LEAVE_COMPANY": "עזיבת העסק", "LEAVE_COMPANY_TITLE": "לעזוב את העסק?", "LEAVE_COMPANY_TEXT": "לא תראו יותר את העבודות והלקוחות של {name}.", "NOTIF_JOB_WITHDRAWN": "הלקוח ביטל את העבודה", "INVOICE_EMAILED_TO": "{email} קיבל/ה את החשבונית כ-PDF.", "INVOICE_NO_EMAIL": "נשלחה, אבל לא במייל: ללקוח אין כתובת מייל. פתח/י את ה-PDF ושתף/י אותו בעצמך, או השתמש/י בשליחה במייל.", "INVOICE_EMAIL_NOT_SET_UP": "נשלחה, אבל לא במייל: המייל עדיין לא הוגדר בשרת (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "נשלחה, אבל המייל נכשל: {error}", "SEND_INVOICE_EMAIL_TO": "ה-PDF נשלח במייל אל {email}.", "SEND_INVOICE_NO_EMAIL": "אין כתובת מייל, ולכן היא לא תישלח במייל. אפשר לשתף את ה-PDF בעצמך.", "EMAIL_INVOICE": "שליחה במייל", "PREVIEW_PDF": "תצוגה מקדימה של PDF", "OPEN_PDF": "פתיחת PDF", "EMAILED": "נשלחה במייל", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "לא נשלחה במייל", "INVOICE_LANGUAGE": "שפת החשבונית", "NOTIF_NEW_JOB_NEARBY": "עבודה חדשה באזור שלך", "NOTIF_NEW_JOB_REMOTE": "עבודה חדשה מרחוק", "NOTIF_JOB_INVITED": "הוזמנת לעבודה", "NOTIF_JOB_IN_PLACE": "„{job}” ב{place}", "JOB_ALERTS": "התראות על עבודות חדשות", "JOB_ALERTS_ON_TEXT": "תקבל/י התראה כשעבודה בקטגוריות שלך מתפרסמת באזור שלך.", "JOB_ALERTS_OFF_TEXT": "לא תקבל/י התראות על עבודות חדשות, אבל עדיין אפשר לראות אותן באפליקציה.", "JOB_ALERTS_NEEDS_VISIBLE": "קודם הפעל/י נראות. רק בעלי מקצוע שלקוחות יכולים למצוא מקבלים התראות.", "FORGOT_PASSWORD": "שכחתם את הסיסמה?", "FORGOT_PASSWORD_TITLE": "סיסמה חדשה", "FORGOT_PASSWORD_INTRO": "הזינו את האימייל שאיתו נרשמתם, ונשלח לכם קוד.", "SEND_CODE": "שליחת קוד", "RESET_CODE_SENT": "אם ל-{email} יש חשבון, קוד בן 6 ספרות כבר בדרך. הזינו אותו למטה יחד עם סיסמה חדשה.", "RESET_CODE": "הקוד מהאימייל", "RESET_CODE_INVALID": "הקוד כולל 6 ספרות.", "RESET_CODE_WRONG": "הקוד שגוי או שפג תוקפו. בקשו קוד חדש.", "SAVE_NEW_PASSWORD": "שמירה והתחברות", "RESET_CODE_AGAIN": "שליחת קוד חדש", "RESET_CODE_RESENT": "נשלח קוד חדש", "RESET_CODE_SPAM_HINT": "לא הגיע אימייל אחרי כמה דקות? בדקו בתיקיית הספאם.", "DELETE_ACCOUNT": "מחיקת החשבון", "DELETE_ACCOUNT_INTRO": "פעולה זו מוחקת את החשבון של {email}. אי אפשר לבטל אותה.", "DELETE_WHAT_GOES": "יימחק", "DELETE_GOES_PROFILE": "השם, התמונה, הטלפון והאימייל שלכם", "DELETE_GOES_PRO": "פרופיל בעל המקצוע שלכם, כך שלקוחות לא ימצאו אתכם יותר", "DELETE_GOES_JOBS": "עבודות פתוחות שפרסמתם, והצעות שאף אחד לא ענה עליהן", "DELETE_GOES_LOGIN": "ההתחברות שלכם, בכל המכשירים", "DELETE_WHAT_STAYS": "יישמר, בלי השם שלכם", "DELETE_STAYS_CONTRACTS": "חוזים שהסתיימו, הודעות וביקורות, כדי שיישארו אצל הצד השני", "DELETE_STAYS_INVOICES": "חשבוניות, שכללי הנהלת החשבונות בנורווגיה מחייבים לשמור במשך 5 שנים", "DELETE_PASSWORD_HINT": "כדי לוודא שזה אתם.", "DELETE_ACCOUNT_CONFIRM_TITLE": "למחוק את החשבון?", "DELETE_ACCOUNT_CONFIRM_TEXT": "תתבצע התנתקות ולא תהיה אפשרות להתחבר שוב עם החשבון הזה.", "DELETE_BLOCKED_CONTRACTS": "יש לכם חוזים פעילים. השלימו או בטלו אותם קודם, כדי שהצד השני לא יישאר בהמתנה.", "DELETE_BLOCKED_COMPANY": "אתם הבעלים של עסק עם חברים נוספים. הסירו אותם קודם במסך צוות.", "JOB_CATEGORY_REQUIRED": "בחרו קטגוריה, כדי שבעלי המקצוע המתאימים ישמעו על העבודה."}, "tr-TR": {"EDIT": "Düzenle", "REMOVE": "Kaldır", "CLEAR": "Temizle", "ARCHIVE": "Arşivle", "NOTES": "Notlar", "YOU": "siz", "DATE_PLACEHOLDER": "gg.aa.yyyy", "DATE_INVALID": "Tarihi gg.aa.yyyy biçiminde yazın.", "AMOUNT_INVALID": "NOK cinsinden bir tutar yazın, örn. 5000.", "EMAIL_INVALID": "Bu e-posta adresi doğru görünmüyor.", "POSTCODE_FORMAT": "Posta kodu 4 haneden oluşur.", "CLIENT": "Müşteri", "CLIENTS": "Müşteriler", "CLIENTS_PRO_ONLY": "Kendi müşteri kaydınız ustalar içindir. Kullanmak için usta hesabıyla giriş yapın.", "SEARCH_CLIENTS": "Müşteri ara", "CLIENTS_ACTIVE": "Aktif", "CLIENTS_ARCHIVED": "Arşivlenmiş", "NO_CLIENTS": "Henüz müşteri yok", "NO_CLIENTS_TEXT": "Platform dışında çalıştığınız müşterileri ekleyin; onların işlerini, saatlerini ve faturalarını tek bir yerde tutun.", "NO_CLIENTS_MATCH": "Aramanızla eşleşen müşteri yok.", "NO_ARCHIVED_CLIENTS": "Arşivde bir şey yok", "NO_ARCHIVED_CLIENTS_TEXT": "Arşivlediğiniz müşteriler eski işleri ve faturalarıyla birlikte burada görünür.", "NEW_CLIENT": "Yeni müşteri", "EDIT_CLIENT": "Müşteriyi düzenle", "SAVE_CLIENT": "Müşteriyi kaydet", "CLIENT_FORM_INTRO": "Bunu yalnızca siz ve şirketiniz görebilir. Adres, yeni işlerde çalışma adresi olarak kullanılır.", "CLIENT_TYPE": "Müşteri türü", "CLIENT_PRIVATE": "Bireysel", "CLIENT_BUSINESS": "Kurumsal", "CLIENT_COMPANY_PLACEHOLDER": "Örn. Bergen Eiendom AS", "CONTACT_PERSON": "İletişim kişisi", "CONTACT_NAME": "İletişim: {name}", "CLIENT_EMAIL_HINT": "Faturalar buraya gönderilebilir.", "CLIENT_NOTES_PLACEHOLDER": "Kapı kodu, park yeri, köpeğin adı…", "CLIENT_NOTES_HINT": "Yalnızca siz ve çalışma arkadaşlarınız içindir, müşteriye asla gösterilmez.", "CLIENT_NOT_FOUND": "Müşteri bulunamadı", "CLIENT_IS_ARCHIVED": "Arşivlendi", "CLIENT_NO_DETAILS": "Henüz iletişim bilgisi yok. Eklemek için Düzenle'ye dokunun.", "CLIENT_JOBS": "İşler", "CLIENT_NO_JOBS": "Bu müşteri için henüz iş yok.", "ARCHIVE_CLIENT": "Müşteriyi arşivle", "ARCHIVE_CLIENT_TITLE": "Bu müşteri arşivlensin mi?", "ARCHIVE_CLIENT_TEXT": "Müşterinin işleri olduğu için işleri ve faturalarıyla birlikte saklanır. Daha sonra geri yükleyebilirsiniz.", "RESTORE_CLIENT": "Müşteriyi geri yükle", "DELETE_CLIENT": "Müşteriyi sil", "DELETE_CLIENT_TITLE": "Bu müşteri silinsin mi?", "DELETE_CLIENT_TEXT": "{name} kaydınızdan kaldırılır.", "NEW_ASSIGNMENT": "Yeni iş", "NEW_ASSIGNMENT_INTRO": "Kendi müşteriniz için işi kaydedin ve fiyatta anlaşın. Sözleşmeden adım ekleyebilir, saat kaydedebilir ve fatura kesebilirsiniz.", "PICK_CLIENT_INTRO": "İş kimin için?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Neyde anlaşıldı, malzemeler, müşterinin bilmesi gerekenler", "START_DATE": "Başlangıç tarihi", "END_DATE": "Bitiş tarihi", "END_BEFORE_START": "Bitiş tarihi başlangıç tarihinden önce.", "STEPS_OPTIONAL_HINT": "İsteğe bağlı. Adım olmazsa işin tamamı tek bir adımdır.", "STEPS_SPLIT_HINT": "Her adım ayrı ayrı onaylanır. Tutarların toplamı fiyata eşit olmalıdır.", "STEPS_HOURLY_HINT": "Her adım ayrı ayrı onaylanır. Saatler sözleşmeye kaydedilir.", "STEP_TITLE": "Adım", "STEP_TITLE_PLACEHOLDER": "Örn. Söküm ve gider", "STEP_TITLE_REQUIRED": "Her adıma bir ad verin.", "STEP_AMOUNT": "Tutar (NOK)", "STEP_AMOUNT_REQUIRED": "Her adıma bir tutar girin.", "STEP_DUE": "Son tarih", "STEP_DESCRIPTION_PLACEHOLDER": "Bu adıma neler dahil", "STEPS_MUST_ADD_UP": "Adımların toplamı {total} olmalıdır.", "STEPS_ADD_UP": "Adımların toplamı fiyata eşit ✓", "STEPS_REST": "Dağıtılacak kalan: {rest}", "STEPS_TOTAL_MISMATCH": "Adımların toplamı {steps}, anlaşılan fiyat {total}.", "REMOVE_STEP": "Adımı kaldır", "ADD_STEP": "Adım ekle", "ADD_STEP_INTRO": "Müşteri her adımı bittiğinde onaylar.", "EDIT_STEP": "Adımı düzenle", "DELETE_STEP": "Adımı sil", "DELETE_STEP_TITLE": "Bu adım silinsin mi?", "DELETE_STEP_TEXT": "“{title}” sözleşmeden kaldırılır.", "STEP_STARTED_NO_DELETE": "Bu adım başladığı için değiştirilebilir ama silinemez.", "CREATE_CONTRACT": "Sözleşme oluştur", "JOB_HAS_CONTRACT": "Bu işin zaten bir sözleşmesi var.", "JOB_NOT_YOURS": "İşi yalnızca onu oluşturan kişi değiştirebilir.", "JOB_CANNOT_EDIT": "Biri zaten işe alındığı için iş artık değiştirilemez.", "EDIT_JOB": "İşi düzenle", "EDIT_JOB_INTRO": "Uzmanlar değişiklikleri hemen görür.", "EDIT_JOB_WITH_OFFERS": "Alınan teklifler: {n}. Tekliflerin uygun kalması için büyük değişiklikleri uzmanlara sohbetten bildirin.", "CREATED_AGO": "Oluşturulma: {time}", "DRAFT_NOT_VISIBLE": "Bu bir taslak. Siz yayınlayana kadar uzmanlar bunu göremez.", "CANCEL_JOB": "İşi iptal et", "CANCEL_JOB_TITLE": "Bu iş iptal edilsin mi?", "CANCEL_JOB_TEXT": "İş yayından kaldırılır ve yeniden açılamaz.", "CANCEL_JOB_WITH_OFFERS_TEXT": "İş yayından kaldırılır ve teklif gönderen uzmanlara ({n}) iptal edildiği bildirilir.", "DELETE_JOB_TITLE": "Taslak silinsin mi?", "DELETE_JOB_TEXT": "Taslak kalıcı olarak silinir.", "CANCEL_CONTRACT": "Sözleşmeyi iptal et", "CANCEL_CONTRACT_INTRO": "Çalışma burada durur. Onaylanan adımlar ve faturalar saklanır, karşı tarafa bilgi verilir.", "CANCEL_REASON": "Neden? (isteğe bağlı)", "CANCEL_REASON_PLACEHOLDER": "İkinizin de daha sonra görebileceği birkaç kelime", "CONTRACT_CANCELLED_ON": "İptal tarihi: {date}", "COMPLETE_CLIENT_JOB_TEXT": "Tüm adımlar imzalandı. İş tamamlandı olarak işaretlenir.", "SIGN_ON_SITE": "Müşteri imzalar", "SIGN_ON_SITE_INTRO": "Müşterinin işi kontrol etmesine ve ekrana parmağıyla imza atmasına izin verin. Bu, adımı onaylar.", "CUSTOMER_NAME": "Müşterinin adı", "SIGNATURE": "İmza", "SIGN_HERE": "Buraya imzalayın", "APPROVE_WITH_SIGNATURE": "İmzayla onayla", "CHANGE_PASSWORD": "Şifreyi değiştir", "CHANGE_PASSWORD_INTRO": "Burada oturumunuz açık kalır. Diğer telefonlarınızda ve tarayıcılarınızda oturum kapatılır.", "CURRENT_PASSWORD": "Mevcut şifre", "CURRENT_PASSWORD_REQUIRED": "Mevcut şifrenizi girin.", "CURRENT_PASSWORD_WRONG": "Bu, mevcut şifreniz değil.", "NEW_PASSWORD": "Yeni şifre", "REPEAT_PASSWORD": "Yeni şifreyi tekrarlayın", "PASSWORDS_DONT_MATCH": "Şifreler eşleşmiyor.", "PASSWORD_SAME_AS_OLD": "Burada daha önce kullanmadığınız bir şifre seçin.", "PASSWORD_CHANGED": "Şifre değiştirildi", "PAYMENTS": "Ödemeler", "PAYMENT": "Ödeme", "NO_PAYMENTS": "Henüz ödeme yok", "NO_PAYMENTS_TEXT": "Uygulama üzerinden yapılan ödemeler burada görünür. Faturayla ödenen işler Faturalar bölümündedir.", "PAYMENT_STATUS_PENDING": "Bekliyor", "PAYMENT_STATUS_HELD": "Güvende tutuluyor", "PAYMENT_STATUS_RELEASED": "Ödendi", "PAYMENT_STATUS_REFUNDED": "İade edildi", "PAYMENT_STATUS_FAILED": "Başarısız", "PLATFORM_FEE": "Ücret {fee}", "TEAM": "Ekip", "TEAM_ROW_HINT": "Şirkette çalışan kişiler", "TEAM_MANAGE_HINT": "Çalışma arkadaşlarının önce bir Qup Work hesabı olması gerekir. Değiştirmek veya kaldırmak için birine dokunun.", "TEAM_WORKER_HINT": "Çalışma arkadaşlarını sahip ve yöneticiler ekler ve kaldırır.", "ADD_MEMBER": "Çalışma arkadaşı ekle", "ADD_MEMBER_INTRO": "Kişinin Qup Work'e kaydolduğu e-postayı kullanın.", "MEMBER_NOT_FOUND": "Bu e-postayla henüz kimse kaydolmamış. Önce bir hesap oluşturmasını isteyin.", "MEMBER_ALREADY": "Bu kişi zaten şirkette.", "ROLE": "Rol", "ROLE_ADMIN_HINT": "Yöneticiler şirket bilgilerini ve fatura ayarlarını değiştirebilir, çalışma arkadaşı ekleyebilir.", "ROLE_WORKER_HINT": "Çalışanlar şirketin işlerini görür, saat kaydeder ve işi yapar.", "REMOVE_FROM_COMPANY": "Şirketten çıkar", "REMOVE_MEMBER_TITLE": "Şirketten çıkarılsın mı?", "REMOVE_MEMBER_TEXT": "{name} artık şirketin işlerini ve müşterilerini göremez.", "LEAVE_COMPANY": "Şirketten ayrıl", "LEAVE_COMPANY_TITLE": "Şirketten ayrılmak istiyor musunuz?", "LEAVE_COMPANY_TEXT": "Artık {name} şirketinin işlerini ve müşterilerini göremezsiniz.", "NOTIF_JOB_WITHDRAWN": "Müşteri işi iptal etti", "INVOICE_EMAILED_TO": "{email} faturayı PDF olarak aldı.", "INVOICE_NO_EMAIL": "Gönderildi ama e-postayla değil: müşterinin e-posta adresi yok. PDF'i açıp kendin paylaş veya E-postayla gönder'i kullan.", "INVOICE_EMAIL_NOT_SET_UP": "Gönderildi ama e-postayla değil: e-posta sunucuda henüz ayarlanmadı (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Gönderildi ama e-posta başarısız oldu: {error}", "SEND_INVOICE_EMAIL_TO": "PDF, {email} adresine e-postayla gönderilir.", "SEND_INVOICE_NO_EMAIL": "E-posta adresi yok, bu yüzden e-postayla gönderilmeyecek. PDF'i kendin paylaşabilirsin.", "EMAIL_INVOICE": "E-postayla gönder", "PREVIEW_PDF": "PDF önizleme", "OPEN_PDF": "PDF'i aç", "EMAILED": "E-postayla gönderildi", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "E-postayla gönderilmedi", "INVOICE_LANGUAGE": "Fatura dili", "NOTIF_NEW_JOB_NEARBY": "Yakınında yeni iş", "NOTIF_NEW_JOB_REMOTE": "Yeni uzaktan iş", "NOTIF_JOB_INVITED": "Bir işe davet edildin", "NOTIF_JOB_IN_PLACE": "“{job}” – {place}", "JOB_ALERTS": "Yeni iş bildirimleri", "JOB_ALERTS_ON_TEXT": "Bölgende kategorilerinden bir iş yayınlandığında bildirim alırsın.", "JOB_ALERTS_OFF_TEXT": "Yeni işler için bildirim almayacaksın ama onları uygulamada görmeye devam edebilirsin.", "JOB_ALERTS_NEEDS_VISIBLE": "Önce görünürlüğü aç. Yalnızca müşterilerin bulabildiği ustalar iş bildirimi alır.", "FORGOT_PASSWORD": "Şifrenizi mi unuttunuz?", "FORGOT_PASSWORD_TITLE": "Yeni şifre", "FORGOT_PASSWORD_INTRO": "Kaydolurken kullandığınız e-postayı girin, size bir kod gönderelim.", "SEND_CODE": "Kod gönder", "RESET_CODE_SENT": "{email} adresine ait bir hesap varsa 6 haneli bir kod yolda. Kodu yeni bir şifreyle birlikte aşağıya girin.", "RESET_CODE": "E-postadaki kod", "RESET_CODE_INVALID": "Kod 6 hanelidir.", "RESET_CODE_WRONG": "Kod yanlış veya süresi dolmuş. Yeni bir kod isteyin.", "SAVE_NEW_PASSWORD": "Kaydet ve giriş yap", "RESET_CODE_AGAIN": "Yeni kod gönder", "RESET_CODE_RESENT": "Yeni kod gönderildi", "RESET_CODE_SPAM_HINT": "Birkaç dakika sonra hâlâ e-posta gelmedi mi? Spam klasörünüzü kontrol edin.", "DELETE_ACCOUNT": "Hesabı sil", "DELETE_ACCOUNT_INTRO": "Bu işlem {email} hesabını siler. Geri alınamaz.", "DELETE_WHAT_GOES": "Silinecekler", "DELETE_GOES_PROFILE": "Adınız, fotoğrafınız, telefonunuz ve e-postanız", "DELETE_GOES_PRO": "Usta profiliniz; müşteriler sizi artık bulamaz", "DELETE_GOES_JOBS": "Yayınladığınız açık işler ve kimsenin yanıtlamadığı teklifler", "DELETE_GOES_LOGIN": "Tüm cihazlardaki oturumunuz", "DELETE_WHAT_STAYS": "Adınız olmadan saklananlar", "DELETE_STAYS_CONTRACTS": "Tamamlanan sözleşmeler, mesajlar ve yorumlar; karşı taraf bunlara erişmeye devam eder", "DELETE_STAYS_INVOICES": "Norveç muhasebe kuralları gereği 5 yıl saklanması zorunlu olan faturalar", "DELETE_PASSWORD_HINT": "Siz olduğunuzdan emin olmak için.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Hesabınız silinsin mi?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Oturumunuz kapatılır ve bu hesapla bir daha giriş yapamazsınız.", "DELETE_BLOCKED_CONTRACTS": "Devam eden sözleşmeleriniz var. Karşı taraf beklemede kalmasın diye önce bunları tamamlayın veya iptal edin.", "DELETE_BLOCKED_COMPANY": "Başka üyeleri olan bir şirketin sahibisiniz. Önce onları Ekip bölümünden çıkarın.", "JOB_CATEGORY_REQUIRED": "Doğru ustaların işten haberdar olması için bir kategori seçin."}, "cs-CZ": {"EDIT": "Upravit", "REMOVE": "Odebrat", "CLEAR": "Vymazat", "ARCHIVE": "Archivovat", "NOTES": "Poznámky", "YOU": "vy", "DATE_PLACEHOLDER": "dd.mm.rrrr", "DATE_INVALID": "Zadejte datum ve tvaru dd.mm.rrrr.", "AMOUNT_INVALID": "Zadejte částku v NOK, např. 5000.", "EMAIL_INVALID": "Tahle e-mailová adresa nevypadá správně.", "POSTCODE_FORMAT": "PSČ má 4 číslice.", "CLIENT": "Zákazník", "CLIENTS": "Zákazníci", "CLIENTS_PRO_ONLY": "Vlastní adresář zákazníků je pro řemeslníky. Pro jeho použití se přihlaste účtem řemeslníka.", "SEARCH_CLIENTS": "Hledat zákazníky", "CLIENTS_ACTIVE": "Aktivní", "CLIENTS_ARCHIVED": "Archivovaní", "NO_CLIENTS": "Zatím žádní zákazníci", "NO_CLIENTS_TEXT": "Přidejte zákazníky, pro které pracujete mimo tržiště, a mějte zakázky, hodiny i faktury pro ně na jednom místě.", "NO_CLIENTS_MATCH": "Hledání neodpovídá žádný zákazník.", "NO_ARCHIVED_CLIENTS": "Nic archivovaného", "NO_ARCHIVED_CLIENTS_TEXT": "Zákazníci, které archivujete, skončí tady i se starými zakázkami a fakturami.", "NEW_CLIENT": "Nový zákazník", "EDIT_CLIENT": "Upravit zákazníka", "SAVE_CLIENT": "Uložit zákazníka", "CLIENT_FORM_INTRO": "Vidíte to jen vy a vaše firma. Adresa se použije jako místo výkonu u nových zakázek.", "CLIENT_TYPE": "Typ zákazníka", "CLIENT_PRIVATE": "Soukromá osoba", "CLIENT_BUSINESS": "Firma", "CLIENT_COMPANY_PLACEHOLDER": "Např. Bergen Eiendom AS", "CONTACT_PERSON": "Kontaktní osoba", "CONTACT_NAME": "Kontakt: {name}", "CLIENT_EMAIL_HINT": "Sem lze posílat faktury.", "CLIENT_NOTES_PLACEHOLDER": "Kód od brány, parkování, jméno psa…", "CLIENT_NOTES_HINT": "Jen pro vás a vaše kolegy, zákazník to nikdy neuvidí.", "CLIENT_NOT_FOUND": "Zákazník nenalezen", "CLIENT_IS_ARCHIVED": "Archivováno", "CLIENT_NO_DETAILS": "Zatím žádné kontaktní údaje. Doplníte je klepnutím na Upravit.", "CLIENT_JOBS": "Zakázky", "CLIENT_NO_JOBS": "Pro tohoto zákazníka zatím nejsou žádné zakázky.", "ARCHIVE_CLIENT": "Archivovat zákazníka", "ARCHIVE_CLIENT_TITLE": "Archivovat tohoto zákazníka?", "ARCHIVE_CLIENT_TEXT": "Zákazník má zakázky, takže zůstane uložený i s nimi a s fakturami. Později ho můžete obnovit.", "RESTORE_CLIENT": "Obnovit zákazníka", "DELETE_CLIENT": "Smazat zákazníka", "DELETE_CLIENT_TITLE": "Smazat tohoto zákazníka?", "DELETE_CLIENT_TEXT": "{name} bude odebrán z vašeho adresáře.", "NEW_ASSIGNMENT": "Nová zakázka", "NEW_ASSIGNMENT_INTRO": "Zapište práci pro vlastního zákazníka a domluvte cenu. Ve smlouvě pak můžete přidávat kroky, zapisovat hodiny a fakturovat.", "PICK_CLIENT_INTRO": "Pro koho je práce?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Co je domluveno, materiál, cokoli, co by měl zákazník vědět", "START_DATE": "Datum začátku", "END_DATE": "Datum konce", "END_BEFORE_START": "Datum konce je před datem začátku.", "STEPS_OPTIONAL_HINT": "Nepovinné. Bez kroků je celá zakázka jeden krok.", "STEPS_SPLIT_HINT": "Každý krok se schvaluje zvlášť. Částky musí dát dohromady cenu.", "STEPS_HOURLY_HINT": "Každý krok se schvaluje zvlášť. Hodiny se zapisují do smlouvy.", "STEP_TITLE": "Krok", "STEP_TITLE_PLACEHOLDER": "Např. Bourání a odpad", "STEP_TITLE_REQUIRED": "Pojmenujte každý krok.", "STEP_AMOUNT": "Částka (NOK)", "STEP_AMOUNT_REQUIRED": "Zadejte částku u každého kroku.", "STEP_DUE": "Termín", "STEP_DESCRIPTION_PLACEHOLDER": "Co tento krok zahrnuje", "STEPS_MUST_ADD_UP": "Kroky musí dát dohromady {total}.", "STEPS_ADD_UP": "Kroky dávají dohromady cenu ✓", "STEPS_REST": "Zbývá rozdělit: {rest}", "STEPS_TOTAL_MISMATCH": "Kroky dávají {steps}, dohodnutá cena je {total}.", "REMOVE_STEP": "Odebrat krok", "ADD_STEP": "Přidat krok", "ADD_STEP_INTRO": "Zákazník každý krok schválí, až bude hotový.", "EDIT_STEP": "Upravit krok", "DELETE_STEP": "Smazat krok", "DELETE_STEP_TITLE": "Smazat tento krok?", "DELETE_STEP_TEXT": "„{title}“ bude odebrán ze smlouvy.", "STEP_STARTED_NO_DELETE": "Tento krok už začal, takže ho lze upravit, ale ne smazat.", "CREATE_CONTRACT": "Vytvořit smlouvu", "JOB_HAS_CONTRACT": "Tato zakázka už smlouvu má.", "JOB_NOT_YOURS": "Zakázku může změnit jen ten, kdo ji vytvořil.", "JOB_CANNOT_EDIT": "Někdo už byl najat, takže zakázku už nejde změnit.", "EDIT_JOB": "Upravit zakázku", "EDIT_JOB_INTRO": "Odborníci uvidí změny hned.", "EDIT_JOB_WITH_OFFERS": "Přijaté nabídky: {n}. O větších změnách dejte odborníkům vědět v chatu, ať jejich nabídky stále sedí.", "CREATED_AGO": "Vytvořeno {time}", "DRAFT_NOT_VISIBLE": "Toto je koncept. Odborníci ho neuvidí, dokud ho nezveřejníte.", "CANCEL_JOB": "Zrušit zakázku", "CANCEL_JOB_TITLE": "Zrušit tuto zakázku?", "CANCEL_JOB_TEXT": "Zakázka bude stažena a nepůjde znovu otevřít.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Zakázka bude stažena a odborníci, kteří poslali nabídky ({n}), dostanou zprávu, že byla zrušena.", "DELETE_JOB_TITLE": "Smazat koncept?", "DELETE_JOB_TEXT": "Koncept bude trvale smazán.", "CANCEL_CONTRACT": "Zrušit smlouvu", "CANCEL_CONTRACT_INTRO": "Práce tady končí. Schválené kroky a faktury zůstanou a druhá strana dostane zprávu.", "CANCEL_REASON": "Proč? (nepovinné)", "CANCEL_REASON_PLACEHOLDER": "Pár slov, která později uvidíte oba", "CONTRACT_CANCELLED_ON": "Zrušeno {date}", "COMPLETE_CLIENT_JOB_TEXT": "Všechny kroky jsou schválené. Zakázka bude označena jako dokončená.", "SIGN_ON_SITE": "Podpis zákazníka", "SIGN_ON_SITE_INTRO": "Nechte zákazníka práci zkontrolovat a podepsat se prstem na obrazovce. Tím se krok schválí.", "CUSTOMER_NAME": "Jméno zákazníka", "SIGNATURE": "Podpis", "SIGN_HERE": "Podepište se zde", "APPROVE_WITH_SIGNATURE": "Schválit podpisem", "CHANGE_PASSWORD": "Změnit heslo", "CHANGE_PASSWORD_INTRO": "Tady zůstanete přihlášeni. Na ostatních telefonech a v prohlížečích budete odhlášeni.", "CURRENT_PASSWORD": "Současné heslo", "CURRENT_PASSWORD_REQUIRED": "Zadejte své současné heslo.", "CURRENT_PASSWORD_WRONG": "To není vaše současné heslo.", "NEW_PASSWORD": "Nové heslo", "REPEAT_PASSWORD": "Zopakujte nové heslo", "PASSWORDS_DONT_MATCH": "Hesla se neshodují.", "PASSWORD_SAME_AS_OLD": "Zvolte heslo, které jste tu ještě nepoužili.", "PASSWORD_CHANGED": "Heslo změněno", "PAYMENTS": "Platby", "PAYMENT": "Platba", "NO_PAYMENTS": "Zatím žádné platby", "NO_PAYMENTS_TEXT": "Platby provedené přes aplikaci se zobrazí tady. Zakázky placené fakturou najdete v sekci Faktury.", "PAYMENT_STATUS_PENDING": "Čeká", "PAYMENT_STATUS_HELD": "V úschově", "PAYMENT_STATUS_RELEASED": "Vyplaceno", "PAYMENT_STATUS_REFUNDED": "Vráceno", "PAYMENT_STATUS_FAILED": "Nezdařilo se", "PLATFORM_FEE": "Poplatek {fee}", "TEAM": "Tým", "TEAM_ROW_HINT": "Lidé, kteří ve firmě pracují", "TEAM_MANAGE_HINT": "Kolegové musí mít nejdřív účet Qup Work. Klepnutím na někoho ho můžete změnit nebo odebrat.", "TEAM_WORKER_HINT": "Kolegy přidává a odebírá vlastník a administrátoři.", "ADD_MEMBER": "Přidat kolegu", "ADD_MEMBER_INTRO": "Použijte e-mail, se kterým se dotyčný zaregistroval do Qup Work.", "MEMBER_NOT_FOUND": "S tímto e-mailem se zatím nikdo nezaregistroval. Požádejte dotyčného, ať si nejdřív vytvoří účet.", "MEMBER_ALREADY": "Tento člověk už ve firmě je.", "ROLE": "Role", "ROLE_ADMIN_HINT": "Administrátoři mohou měnit údaje firmy a nastavení faktur a přidávat kolegy.", "ROLE_WORKER_HINT": "Zaměstnanci vidí zakázky firmy, zapisují hodiny a dělají práci.", "REMOVE_FROM_COMPANY": "Odebrat z firmy", "REMOVE_MEMBER_TITLE": "Odebrat z firmy?", "REMOVE_MEMBER_TEXT": "{name} už neuvidí zakázky a zákazníky firmy.", "LEAVE_COMPANY": "Opustit firmu", "LEAVE_COMPANY_TITLE": "Opustit firmu?", "LEAVE_COMPANY_TEXT": "Už neuvidíte zakázky a zákazníky firmy {name}.", "NOTIF_JOB_WITHDRAWN": "Zákazník zakázku zrušil", "INVOICE_EMAILED_TO": "{email} dostal fakturu jako PDF.", "INVOICE_NO_EMAIL": "Odesláno, ale ne e-mailem: zákazník nemá e-mailovou adresu. Otevřete PDF a sdílejte ho sami, nebo použijte Poslat e-mailem.", "INVOICE_EMAIL_NOT_SET_UP": "Odesláno, ale ne e-mailem: e-mail zatím není na serveru nastaven (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Odesláno, ale e-mail selhal: {error}", "SEND_INVOICE_EMAIL_TO": "PDF se pošle e-mailem na {email}.", "SEND_INVOICE_NO_EMAIL": "Chybí e-mailová adresa, takže se nepošle e-mailem. PDF můžete sdílet sami.", "EMAIL_INVOICE": "Poslat e-mailem", "PREVIEW_PDF": "Náhled PDF", "OPEN_PDF": "Otevřít PDF", "EMAILED": "Posláno e-mailem", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Neposláno e-mailem", "INVOICE_LANGUAGE": "Jazyk faktury", "NOTIF_NEW_JOB_NEARBY": "Nová zakázka ve vašem okolí", "NOTIF_NEW_JOB_REMOTE": "Nová zakázka na dálku", "NOTIF_JOB_INVITED": "Byli jste pozváni k zakázce", "NOTIF_JOB_IN_PLACE": "„{job}“ – {place}", "JOB_ALERTS": "Upozornění na nové zakázky", "JOB_ALERTS_ON_TEXT": "Dostanete upozornění, když se ve vašem okolí objeví zakázka z vašich kategorií.", "JOB_ALERTS_OFF_TEXT": "Upozornění na nové zakázky nedostanete, ale v aplikaci je pořád uvidíte.", "JOB_ALERTS_NEEDS_VISIBLE": "Nejdřív zapněte viditelnost. Upozornění dostávají jen řemeslníci, které zákazníci najdou.", "FORGOT_PASSWORD": "Zapomněli jste heslo?", "FORGOT_PASSWORD_TITLE": "Nové heslo", "FORGOT_PASSWORD_INTRO": "Zadejte e-mail, se kterým jste se registrovali, a pošleme vám kód.", "SEND_CODE": "Poslat kód", "RESET_CODE_SENT": "Pokud má {email} účet, je na cestě 6místný kód. Zadejte ho níže spolu s novým heslem.", "RESET_CODE": "Kód z e-mailu", "RESET_CODE_INVALID": "Kód má 6 číslic.", "RESET_CODE_WRONG": "Kód je špatný nebo vypršel. Požádejte o nový.", "SAVE_NEW_PASSWORD": "Uložit a přihlásit se", "RESET_CODE_AGAIN": "Poslat nový kód", "RESET_CODE_RESENT": "Nový kód odeslán", "RESET_CODE_SPAM_HINT": "Ani po pár minutách žádný e-mail? Zkontrolujte složku se spamem.", "DELETE_ACCOUNT": "Smazat účet", "DELETE_ACCOUNT_INTRO": "Tím smažete účet pro {email}. Nejde to vrátit zpět.", "DELETE_WHAT_GOES": "Smaže se", "DELETE_GOES_PROFILE": "Vaše jméno, fotka, telefon a e-mail", "DELETE_GOES_PRO": "Váš profil řemeslníka, takže vás zákazníci už nenajdou", "DELETE_GOES_JOBS": "Otevřené zakázky, které jste zadali, a nabídky, na které nikdo neodpověděl", "DELETE_GOES_LOGIN": "Vaše přihlášení na všech zařízeních", "DELETE_WHAT_STAYS": "Zůstane, bez vašeho jména", "DELETE_STAYS_CONTRACTS": "Dokončené smlouvy, zprávy a hodnocení, aby je druhá strana měla dál k dispozici", "DELETE_STAYS_INVOICES": "Faktury, které podle norských účetních předpisů musí být uchovány 5 let", "DELETE_PASSWORD_HINT": "Abychom měli jistotu, že jste to vy.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Smazat účet?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Budete odhlášeni a k tomuto účtu se už nepřihlásíte.", "DELETE_BLOCKED_CONTRACTS": "Máte rozpracované smlouvy. Nejdřív je dokončete nebo zrušte, aby druhá strana nezůstala čekat.", "DELETE_BLOCKED_COMPANY": "Vlastníte firmu s dalšími členy. Nejdřív je odeberte v sekci Tým.", "JOB_CATEGORY_REQUIRED": "Vyberte kategorii, aby se o zakázce dozvěděli ti správní řemeslníci."}, "pl-PL": {"EDIT": "Edytuj", "REMOVE": "Usuń", "CLEAR": "Wyczyść", "ARCHIVE": "Archiwizuj", "NOTES": "Notatki", "YOU": "ty", "DATE_PLACEHOLDER": "dd.mm.rrrr", "DATE_INVALID": "Wpisz datę w formacie dd.mm.rrrr.", "AMOUNT_INVALID": "Wpisz kwotę w NOK, np. 5000.", "EMAIL_INVALID": "Ten adres e-mail nie wygląda na poprawny.", "POSTCODE_FORMAT": "Kod pocztowy ma 4 cyfry.", "CLIENT": "Klient", "CLIENTS": "Klienci", "CLIENTS_PRO_ONLY": "Własny rejestr klientów jest dla fachowców. Zaloguj się na konto fachowca, aby z niego korzystać.", "SEARCH_CLIENTS": "Szukaj klientów", "CLIENTS_ACTIVE": "Aktywni", "CLIENTS_ARCHIVED": "Zarchiwizowani", "NO_CLIENTS": "Nie masz jeszcze klientów", "NO_CLIENTS_TEXT": "Dodaj klientów, dla których pracujesz poza platformą, i trzymaj ich zlecenia, godziny i faktury w jednym miejscu.", "NO_CLIENTS_MATCH": "Żaden klient nie pasuje do wyszukiwania.", "NO_ARCHIVED_CLIENTS": "Archiwum jest puste", "NO_ARCHIVED_CLIENTS_TEXT": "Tutaj trafiają zarchiwizowani klienci razem z ich dawnymi zleceniami i fakturami.", "NEW_CLIENT": "Nowy klient", "EDIT_CLIENT": "Edytuj klienta", "SAVE_CLIENT": "Zapisz klienta", "CLIENT_FORM_INTRO": "Widzisz to tylko ty i twoja firma. Adres jest używany jako adres wykonania nowych zleceń.", "CLIENT_TYPE": "Rodzaj klienta", "CLIENT_PRIVATE": "Osoba prywatna", "CLIENT_BUSINESS": "Firma", "CLIENT_COMPANY_PLACEHOLDER": "Np. Bergen Eiendom AS", "CONTACT_PERSON": "Osoba kontaktowa", "CONTACT_NAME": "Kontakt: {name}", "CLIENT_EMAIL_HINT": "Tu można wysyłać faktury.", "CLIENT_NOTES_PLACEHOLDER": "Kod do bramy, parkowanie, imię psa…", "CLIENT_NOTES_HINT": "Tylko dla ciebie i twoich współpracowników, nigdy niewidoczne dla klienta.", "CLIENT_NOT_FOUND": "Nie znaleziono klienta", "CLIENT_IS_ARCHIVED": "Zarchiwizowany", "CLIENT_NO_DETAILS": "Brak danych kontaktowych. Stuknij Edytuj, aby je dodać.", "CLIENT_JOBS": "Zlecenia", "CLIENT_NO_JOBS": "Ten klient nie ma jeszcze zleceń.", "ARCHIVE_CLIENT": "Archiwizuj klienta", "ARCHIVE_CLIENT_TITLE": "Zarchiwizować tego klienta?", "ARCHIVE_CLIENT_TEXT": "Klient ma zlecenia, więc zostanie zachowany razem z nimi i z fakturami. Możesz go później przywrócić.", "RESTORE_CLIENT": "Przywróć klienta", "DELETE_CLIENT": "Usuń klienta", "DELETE_CLIENT_TITLE": "Usunąć tego klienta?", "DELETE_CLIENT_TEXT": "{name} zostanie usunięty z twojego rejestru.", "NEW_ASSIGNMENT": "Nowa praca", "NEW_ASSIGNMENT_INTRO": "Zarejestruj pracę dla własnego klienta i ustal cenę. W umowie możesz dodawać etapy, rejestrować godziny i wystawiać faktury.", "PICK_CLIENT_INTRO": "Dla kogo jest ta praca?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Co uzgodniono, materiały, wszystko, co klient powinien wiedzieć", "START_DATE": "Data rozpoczęcia", "END_DATE": "Data zakończenia", "END_BEFORE_START": "Data zakończenia jest wcześniejsza niż data rozpoczęcia.", "STEPS_OPTIONAL_HINT": "Opcjonalne. Bez etapów całe zlecenie jest jednym etapem.", "STEPS_SPLIT_HINT": "Każdy etap jest zatwierdzany osobno. Kwoty muszą sumować się do ceny.", "STEPS_HOURLY_HINT": "Każdy etap jest zatwierdzany osobno. Godziny są rejestrowane w umowie.", "STEP_TITLE": "Etap", "STEP_TITLE_PLACEHOLDER": "Np. Rozbiórka i odpływy", "STEP_TITLE_REQUIRED": "Nadaj nazwę każdemu etapowi.", "STEP_AMOUNT": "Kwota (NOK)", "STEP_AMOUNT_REQUIRED": "Podaj kwotę dla każdego etapu.", "STEP_DUE": "Termin", "STEP_DESCRIPTION_PLACEHOLDER": "Co obejmuje ten etap", "STEPS_MUST_ADD_UP": "Etapy muszą sumować się do {total}.", "STEPS_ADD_UP": "Etapy sumują się do ceny ✓", "STEPS_REST": "Do rozdzielenia: {rest}", "STEPS_TOTAL_MISMATCH": "Etapy sumują się do {steps}, a uzgodniona cena to {total}.", "REMOVE_STEP": "Usuń etap", "ADD_STEP": "Dodaj etap", "ADD_STEP_INTRO": "Klient zatwierdza każdy etap po jego ukończeniu.", "EDIT_STEP": "Edytuj etap", "DELETE_STEP": "Usuń etap", "DELETE_STEP_TITLE": "Usunąć ten etap?", "DELETE_STEP_TEXT": "„{title}” zostanie usunięty z umowy.", "STEP_STARTED_NO_DELETE": "Ten etap już się rozpoczął, więc można go zmienić, ale nie usunąć.", "CREATE_CONTRACT": "Utwórz umowę", "JOB_HAS_CONTRACT": "To zlecenie ma już umowę.", "JOB_NOT_YOURS": "Tylko osoba, która utworzyła zlecenie, może je zmienić.", "JOB_CANNOT_EDIT": "Ktoś został już zatrudniony, więc zlecenia nie można już zmieniać.", "EDIT_JOB": "Edytuj zlecenie", "EDIT_JOB_INTRO": "Fachowcy od razu widzą zmiany.", "EDIT_JOB_WITH_OFFERS": "Otrzymane oferty: {n}. O dużych zmianach powiedz fachowcom na czacie, żeby ich oferty nadal pasowały.", "CREATED_AGO": "Utworzono {time}", "DRAFT_NOT_VISIBLE": "To jest szkic. Fachowcy go nie zobaczą, dopóki go nie opublikujesz.", "CANCEL_JOB": "Anuluj zlecenie", "CANCEL_JOB_TITLE": "Anulować to zlecenie?", "CANCEL_JOB_TEXT": "Zlecenie zostanie zdjęte i nie będzie można go ponownie otworzyć.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Zlecenie zostanie zdjęte, a fachowcy, którzy wysłali oferty ({n}), dostaną informację o anulowaniu.", "DELETE_JOB_TITLE": "Usunąć szkic?", "DELETE_JOB_TEXT": "Szkic zostanie usunięty na zawsze.", "CANCEL_CONTRACT": "Anuluj umowę", "CANCEL_CONTRACT_INTRO": "Praca kończy się w tym miejscu. Zatwierdzone etapy i faktury zostają, a druga strona dostaje powiadomienie.", "CANCEL_REASON": "Dlaczego? (opcjonalnie)", "CANCEL_REASON_PLACEHOLDER": "Kilka słów, które oboje zobaczycie później", "CONTRACT_CANCELLED_ON": "Anulowano {date}", "COMPLETE_CLIENT_JOB_TEXT": "Wszystkie etapy są podpisane. Zlecenie zostanie oznaczone jako zakończone.", "SIGN_ON_SITE": "Podpis klienta", "SIGN_ON_SITE_INTRO": "Pozwól klientowi sprawdzić pracę i podpisać się palcem na ekranie. To zatwierdza etap.", "CUSTOMER_NAME": "Imię i nazwisko klienta", "SIGNATURE": "Podpis", "SIGN_HERE": "Podpisz tutaj", "APPROVE_WITH_SIGNATURE": "Zatwierdź podpisem", "CHANGE_PASSWORD": "Zmień hasło", "CHANGE_PASSWORD_INTRO": "Tutaj pozostaniesz zalogowany. Na innych telefonach i w przeglądarkach nastąpi wylogowanie.", "CURRENT_PASSWORD": "Obecne hasło", "CURRENT_PASSWORD_REQUIRED": "Podaj obecne hasło.", "CURRENT_PASSWORD_WRONG": "To nie jest twoje obecne hasło.", "NEW_PASSWORD": "Nowe hasło", "REPEAT_PASSWORD": "Powtórz nowe hasło", "PASSWORDS_DONT_MATCH": "Hasła nie są takie same.", "PASSWORD_SAME_AS_OLD": "Wybierz hasło, którego tu jeszcze nie używałeś.", "PASSWORD_CHANGED": "Hasło zmienione", "PAYMENTS": "Płatności", "PAYMENT": "Płatność", "NO_PAYMENTS": "Brak płatności", "NO_PAYMENTS_TEXT": "Tutaj pojawiają się płatności dokonane w aplikacji. Zlecenia opłacone fakturą znajdziesz w sekcji Faktury.", "PAYMENT_STATUS_PENDING": "Oczekuje", "PAYMENT_STATUS_HELD": "Bezpiecznie zablokowana", "PAYMENT_STATUS_RELEASED": "Wypłacona", "PAYMENT_STATUS_REFUNDED": "Zwrócona", "PAYMENT_STATUS_FAILED": "Nieudana", "PLATFORM_FEE": "Prowizja {fee}", "TEAM": "Zespół", "TEAM_ROW_HINT": "Osoby pracujące w firmie", "TEAM_MANAGE_HINT": "Współpracownicy muszą najpierw mieć konto Qup Work. Stuknij osobę, aby ją zmienić lub usunąć.", "TEAM_WORKER_HINT": "Współpracowników dodają i usuwają właściciel i administratorzy.", "ADD_MEMBER": "Dodaj współpracownika", "ADD_MEMBER_INTRO": "Użyj adresu e-mail, którym ta osoba zarejestrowała się w Qup Work.", "MEMBER_NOT_FOUND": "Nikt jeszcze nie zarejestrował się z tym adresem e-mail. Poproś tę osobę, aby najpierw założyła konto.", "MEMBER_ALREADY": "Ta osoba jest już w firmie.", "ROLE": "Rola", "ROLE_ADMIN_HINT": "Administratorzy mogą zmieniać dane firmy i ustawienia faktur oraz dodawać współpracowników.", "ROLE_WORKER_HINT": "Pracownicy widzą zlecenia firmy, rejestrują godziny i wykonują pracę.", "REMOVE_FROM_COMPANY": "Usuń z firmy", "REMOVE_MEMBER_TITLE": "Usunąć z firmy?", "REMOVE_MEMBER_TEXT": "{name} nie będzie już widzieć zleceń i klientów firmy.", "LEAVE_COMPANY": "Opuść firmę", "LEAVE_COMPANY_TITLE": "Opuścić firmę?", "LEAVE_COMPANY_TEXT": "Nie będziesz już widzieć zleceń i klientów firmy {name}.", "NOTIF_JOB_WITHDRAWN": "Klient anulował zlecenie", "INVOICE_EMAILED_TO": "{email} otrzymał fakturę w PDF.", "INVOICE_NO_EMAIL": "Wysłano, ale nie e-mailem: klient nie ma adresu e-mail. Otwórz PDF i udostępnij go sam albo użyj Wyślij e-mailem.", "INVOICE_EMAIL_NOT_SET_UP": "Wysłano, ale nie e-mailem: e-mail nie jest jeszcze skonfigurowany na serwerze (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Wysłano, ale e-mail się nie powiódł: {error}", "SEND_INVOICE_EMAIL_TO": "PDF zostanie wysłany e-mailem na {email}.", "SEND_INVOICE_NO_EMAIL": "Brak adresu e-mail, więc faktura nie zostanie wysłana e-mailem. Możesz sam udostępnić PDF.", "EMAIL_INVOICE": "Wyślij e-mailem", "PREVIEW_PDF": "Podgląd PDF", "OPEN_PDF": "Otwórz PDF", "EMAILED": "Wysłano e-mailem", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Nie wysłano e-mailem", "INVOICE_LANGUAGE": "Język faktury", "NOTIF_NEW_JOB_NEARBY": "Nowe zlecenie w pobliżu", "NOTIF_NEW_JOB_REMOTE": "Nowe zlecenie zdalne", "NOTIF_JOB_INVITED": "Zaproszono cię do zlecenia", "NOTIF_JOB_IN_PLACE": "„{job}” – {place}", "JOB_ALERTS": "Powiadomienia o nowych zleceniach", "JOB_ALERTS_ON_TEXT": "Dostajesz powiadomienie, gdy w twojej okolicy pojawi się zlecenie z twoich kategorii.", "JOB_ALERTS_OFF_TEXT": "Nie dostaniesz powiadomień o nowych zleceniach, ale nadal zobaczysz je w aplikacji.", "JOB_ALERTS_NEEDS_VISIBLE": "Najpierw włącz widoczność. Powiadomienia dostają tylko fachowcy, których klienci mogą znaleźć.", "FORGOT_PASSWORD": "Nie pamiętasz hasła?", "FORGOT_PASSWORD_TITLE": "Nowe hasło", "FORGOT_PASSWORD_INTRO": "Podaj adres e-mail użyty przy rejestracji, a wyślemy Ci kod.", "SEND_CODE": "Wyślij kod", "RESET_CODE_SENT": "Jeśli {email} ma konto, 6-cyfrowy kod jest już w drodze. Wpisz go poniżej razem z nowym hasłem.", "RESET_CODE": "Kod z e-maila", "RESET_CODE_INVALID": "Kod ma 6 cyfr.", "RESET_CODE_WRONG": "Kod jest nieprawidłowy lub wygasł. Poproś o nowy.", "SAVE_NEW_PASSWORD": "Zapisz i zaloguj się", "RESET_CODE_AGAIN": "Wyślij nowy kod", "RESET_CODE_RESENT": "Wysłano nowy kod", "RESET_CODE_SPAM_HINT": "Brak e-maila po kilku minutach? Sprawdź folder spam.", "DELETE_ACCOUNT": "Usuń konto", "DELETE_ACCOUNT_INTRO": "Spowoduje to usunięcie konta {email}. Tej operacji nie można cofnąć.", "DELETE_WHAT_GOES": "Zostanie usunięte", "DELETE_GOES_PROFILE": "Twoje imię i nazwisko, zdjęcie, telefon i e-mail", "DELETE_GOES_PRO": "Twój profil fachowca, więc klienci nie będą mogli Cię już znaleźć", "DELETE_GOES_JOBS": "Opublikowane przez Ciebie otwarte zlecenia i oferty, na które nikt nie odpowiedział", "DELETE_GOES_LOGIN": "Twoje logowanie na wszystkich urządzeniach", "DELETE_WHAT_STAYS": "Zostanie zachowane, bez Twojego imienia i nazwiska", "DELETE_STAYS_CONTRACTS": "Zakończone umowy, wiadomości i opinie, aby druga strona nadal je miała", "DELETE_STAYS_INVOICES": "Faktury, które zgodnie z norweskimi przepisami księgowymi trzeba przechowywać przez 5 lat", "DELETE_PASSWORD_HINT": "Aby upewnić się, że to Ty.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Usunąć konto?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Nastąpi wylogowanie i nie będzie można już zalogować się na to konto.", "DELETE_BLOCKED_CONTRACTS": "Masz trwające umowy. Najpierw je zakończ lub anuluj, aby druga strona nie musiała czekać.", "DELETE_BLOCKED_COMPANY": "Należy do Ciebie firma, w której są inni członkowie. Najpierw usuń ich w sekcji Zespół.", "JOB_CATEGORY_REQUIRED": "Wybierz kategorię, aby odpowiedni fachowcy dowiedzieli się o zleceniu."}, "mk-MK": {"EDIT": "Уреди", "REMOVE": "Отстрани", "CLEAR": "Исчисти", "ARCHIVE": "Архивирај", "NOTES": "Белешки", "YOU": "ти", "DATE_PLACEHOLDER": "дд.мм.гггг", "DATE_INVALID": "Напиши го датумот како дд.мм.гггг.", "AMOUNT_INVALID": "Напиши износ во NOK, на пр. 5000.", "EMAIL_INVALID": "Таа адреса за е-пошта не изгледа точна.", "POSTCODE_FORMAT": "Поштенскиот број има 4 цифри.", "CLIENT": "Клиент", "CLIENTS": "Клиенти", "CLIENTS_PRO_ONLY": "Регистарот на клиенти е за мајстори. Најави се со мајсторска сметка за да го користиш.", "SEARCH_CLIENTS": "Пребарај клиенти", "CLIENTS_ACTIVE": "Активни", "CLIENTS_ARCHIVED": "Архивирани", "NO_CLIENTS": "Сè уште нема клиенти", "NO_CLIENTS_TEXT": "Додај ги клиентите за кои работиш надвор од платформата и чувај ги работите, часовите и фактурите за нив на едно место.", "NO_CLIENTS_MATCH": "Ниеден клиент не одговара на пребарувањето.", "NO_ARCHIVED_CLIENTS": "Ништо не е архивирано", "NO_ARCHIVED_CLIENTS_TEXT": "Клиентите што ги архивираш завршуваат тука, со нивните стари работи и фактури.", "NEW_CLIENT": "Нов клиент", "EDIT_CLIENT": "Уреди клиент", "SAVE_CLIENT": "Зачувај клиент", "CLIENT_FORM_INTRO": "Ова го гледаш само ти и твојата фирма. Адресата се користи како адреса на работа за нови работи.", "CLIENT_TYPE": "Вид на клиент", "CLIENT_PRIVATE": "Физичко лице", "CLIENT_BUSINESS": "Фирма", "CLIENT_COMPANY_PLACEHOLDER": "На пр. Bergen Eiendom AS", "CONTACT_PERSON": "Лице за контакт", "CONTACT_NAME": "Контакт: {name}", "CLIENT_EMAIL_HINT": "Фактурите може да се испраќаат тука.", "CLIENT_NOTES_PLACEHOLDER": "Шифра за капија, паркинг, името на кучето…", "CLIENT_NOTES_HINT": "Само за тебе и твоите колеги, никогаш не се прикажува на клиентот.", "CLIENT_NOT_FOUND": "Клиентот не е пронајден", "CLIENT_IS_ARCHIVED": "Архивиран", "CLIENT_NO_DETAILS": "Сè уште нема податоци за контакт. Допри Уреди за да ги додадеш.", "CLIENT_JOBS": "Работи", "CLIENT_NO_JOBS": "Сè уште нема работи за овој клиент.", "ARCHIVE_CLIENT": "Архивирај клиент", "ARCHIVE_CLIENT_TITLE": "Да се архивира овој клиент?", "ARCHIVE_CLIENT_TEXT": "Клиентот има работи, па се чува заедно со работите и фактурите. Подоцна можеш да го вратиш.", "RESTORE_CLIENT": "Врати клиент", "DELETE_CLIENT": "Избриши клиент", "DELETE_CLIENT_TITLE": "Да се избрише овој клиент?", "DELETE_CLIENT_TEXT": "{name} се отстранува од твојот регистар.", "NEW_ASSIGNMENT": "Нова нарачка", "NEW_ASSIGNMENT_INTRO": "Внеси работа за свој клиент и договори ја цената. Од договорот можеш да додаваш чекори, да внесуваш часови и да фактурираш.", "PICK_CLIENT_INTRO": "За кого е работата?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Што е договорено, материјали, сè што клиентот треба да знае", "START_DATE": "Датум на почеток", "END_DATE": "Датум на крај", "END_BEFORE_START": "Датумот на крај е пред датумот на почеток.", "STEPS_OPTIONAL_HINT": "Опционално. Без чекори, целата работа е еден чекор.", "STEPS_SPLIT_HINT": "Секој чекор се одобрува посебно. Износите заедно мора да ја дадат цената.", "STEPS_HOURLY_HINT": "Секој чекор се одобрува посебно. Часовите се внесуваат на договорот.", "STEP_TITLE": "Чекор", "STEP_TITLE_PLACEHOLDER": "На пр. Рушење и одводнување", "STEP_TITLE_REQUIRED": "Дај име на секој чекор.", "STEP_AMOUNT": "Износ (NOK)", "STEP_AMOUNT_REQUIRED": "Внеси износ за секој чекор.", "STEP_DUE": "Рок", "STEP_DESCRIPTION_PLACEHOLDER": "Што е вклучено во овој чекор", "STEPS_MUST_ADD_UP": "Чекорите заедно мора да изнесуваат {total}.", "STEPS_ADD_UP": "Чекорите заедно ја даваат цената ✓", "STEPS_REST": "Останува да се распредели: {rest}", "STEPS_TOTAL_MISMATCH": "Чекорите заедно изнесуваат {steps}, а договорената цена е {total}.", "REMOVE_STEP": "Отстрани чекор", "ADD_STEP": "Додај чекор", "ADD_STEP_INTRO": "Клиентот го одобрува секој чекор кога ќе биде завршен.", "EDIT_STEP": "Уреди чекор", "DELETE_STEP": "Избриши чекор", "DELETE_STEP_TITLE": "Да се избрише овој чекор?", "DELETE_STEP_TEXT": "„{title}“ се отстранува од договорот.", "STEP_STARTED_NO_DELETE": "Овој чекор е започнат, па може да се менува, но не и да се брише.", "CREATE_CONTRACT": "Создај договор", "JOB_HAS_CONTRACT": "Оваа работа веќе има договор.", "JOB_NOT_YOURS": "Само тој што ја создал работата може да ја менува.", "JOB_CANNOT_EDIT": "Некој веќе е ангажиран, па работата повеќе не може да се менува.", "EDIT_JOB": "Уреди работа", "EDIT_JOB_INTRO": "Мајсторите ги гледаат промените веднаш.", "EDIT_JOB_WITH_OFFERS": "Примени понуди: {n}. Кажи им на мајсторите за поголемите промени во четот, за нивните понуди сè уште да одговараат.", "CREATED_AGO": "Создадено {time}", "DRAFT_NOT_VISIBLE": "Ова е нацрт. Мајсторите не можат да го видат додека не го објавиш.", "CANCEL_JOB": "Откажи работа", "CANCEL_JOB_TITLE": "Да се откаже оваа работа?", "CANCEL_JOB_TEXT": "Работата се симнува и не може повторно да се отвори.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Работата се симнува, а мајсторите што испратиле понуди ({n}) се известуваат дека е откажана.", "DELETE_JOB_TITLE": "Да се избрише нацртот?", "DELETE_JOB_TEXT": "Нацртот се брише засекогаш.", "CANCEL_CONTRACT": "Откажи го договорот", "CANCEL_CONTRACT_INTRO": "Работата запира тука. Одобрените чекори и фактурите остануваат, а другата страна се известува.", "CANCEL_REASON": "Зошто? (опционално)", "CANCEL_REASON_PLACEHOLDER": "Неколку зборови што подоцна ќе ги гледате двајцата", "CONTRACT_CANCELLED_ON": "Откажано на {date}", "COMPLETE_CLIENT_JOB_TEXT": "Сите чекори се потпишани. Работата се означува како завршена.", "SIGN_ON_SITE": "Клиентот потпишува", "SIGN_ON_SITE_INTRO": "Нека клиентот ја провери работата и нека потпише со прст на екранот. Со тоа чекорот се одобрува.", "CUSTOMER_NAME": "Име на клиентот", "SIGNATURE": "Потпис", "SIGN_HERE": "Потпиши тука", "APPROVE_WITH_SIGNATURE": "Одобри со потпис", "CHANGE_PASSWORD": "Промени лозинка", "CHANGE_PASSWORD_INTRO": "Тука остануваш најавен. Од другите телефони и прелистувачи ќе бидеш одјавен.", "CURRENT_PASSWORD": "Сегашна лозинка", "CURRENT_PASSWORD_REQUIRED": "Внеси ја сегашната лозинка.", "CURRENT_PASSWORD_WRONG": "Тоа не е твојата сегашна лозинка.", "NEW_PASSWORD": "Нова лозинка", "REPEAT_PASSWORD": "Повтори ја новата лозинка", "PASSWORDS_DONT_MATCH": "Лозинките не се совпаѓаат.", "PASSWORD_SAME_AS_OLD": "Избери лозинка што не си ја користел тука.", "PASSWORD_CHANGED": "Лозинката е променета", "PAYMENTS": "Плаќања", "PAYMENT": "Плаќање", "NO_PAYMENTS": "Сè уште нема плаќања", "NO_PAYMENTS_TEXT": "Плаќањата направени преку апликацијата се појавуваат тука. Работите платени со фактура се под Фактури.", "PAYMENT_STATUS_PENDING": "Се чека", "PAYMENT_STATUS_HELD": "Безбедно задржано", "PAYMENT_STATUS_RELEASED": "Исплатено", "PAYMENT_STATUS_REFUNDED": "Вратено", "PAYMENT_STATUS_FAILED": "Неуспешно", "PLATFORM_FEE": "Провизија {fee}", "TEAM": "Тим", "TEAM_ROW_HINT": "Луѓето што работат во фирмата", "TEAM_MANAGE_HINT": "Колегите прво треба да имаат сметка на Qup Work. Допри некого за да го промениш или отстраниш.", "TEAM_WORKER_HINT": "Сопственикот и администраторите додаваат и отстрануваат колеги.", "ADD_MEMBER": "Додај колега", "ADD_MEMBER_INTRO": "Користи ја е-поштата со која колегата се регистрирал на Qup Work.", "MEMBER_NOT_FOUND": "Сè уште никој не се регистрирал со таа е-пошта. Замоли го прво да создаде сметка.", "MEMBER_ALREADY": "Тоа лице веќе е во фирмата.", "ROLE": "Улога", "ROLE_ADMIN_HINT": "Администраторите можат да ги менуваат податоците за фирмата и поставките за фактури, и да додаваат колеги.", "ROLE_WORKER_HINT": "Вработените ги гледаат работите на фирмата, внесуваат часови и ја вршат работата.", "REMOVE_FROM_COMPANY": "Отстрани од фирмата", "REMOVE_MEMBER_TITLE": "Да се отстрани од фирмата?", "REMOVE_MEMBER_TEXT": "{name} повеќе не ги гледа работите и клиентите на фирмата.", "LEAVE_COMPANY": "Напушти ја фирмата", "LEAVE_COMPANY_TITLE": "Да ја напуштиш фирмата?", "LEAVE_COMPANY_TEXT": "Повеќе нема да ги гледаш работите и клиентите на {name}.", "NOTIF_JOB_WITHDRAWN": "Клиентот ја откажа работата", "INVOICE_EMAILED_TO": "{email} ја доби фактурата како PDF.", "INVOICE_NO_EMAIL": "Испратено, но не по е-пошта: купувачот нема адреса за е-пошта. Отвори го PDF-от и сподели го сам или користи Испрати по е-пошта.", "INVOICE_EMAIL_NOT_SET_UP": "Испратено, но не по е-пошта: е-поштата сè уште не е поставена на серверот (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Испратено, но е-поштата не успеа: {error}", "SEND_INVOICE_EMAIL_TO": "PDF-от се испраќа по е-пошта на {email}.", "SEND_INVOICE_NO_EMAIL": "Нема адреса за е-пошта, па нема да се испрати по е-пошта. PDF-от можеш да го споделиш сам.", "EMAIL_INVOICE": "Испрати по е-пошта", "PREVIEW_PDF": "Преглед на PDF", "OPEN_PDF": "Отвори PDF", "EMAILED": "Испратено по е-пошта", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Не е испратено по е-пошта", "INVOICE_LANGUAGE": "Јазик на фактурата", "NOTIF_NEW_JOB_NEARBY": "Нова работа во твоја близина", "NOTIF_NEW_JOB_REMOTE": "Нова работа на далечина", "NOTIF_JOB_INVITED": "Поканет си на работа", "NOTIF_JOB_IN_PLACE": "„{job}“ – {place}", "JOB_ALERTS": "Известувања за нови работи", "JOB_ALERTS_ON_TEXT": "Добиваш известување кога во твојата област ќе се објави работа од твоите категории.", "JOB_ALERTS_OFF_TEXT": "Нема да добиваш известувања за нови работи, но сè уште ги гледаш во апликацијата.", "JOB_ALERTS_NEEDS_VISIBLE": "Прво вклучи видливост. Известувања добиваат само мајсторите што купувачите можат да ги најдат.", "FORGOT_PASSWORD": "Ја заборави лозинката?", "FORGOT_PASSWORD_TITLE": "Нова лозинка", "FORGOT_PASSWORD_INTRO": "Внеси ја е-поштата со која се регистрираше и ќе ти испратиме код.", "SEND_CODE": "Испрати код", "RESET_CODE_SENT": "Ако {email} има сметка, 6-цифрен код е на пат. Внеси го подолу заедно со нова лозинка.", "RESET_CODE": "Код од е-поштата", "RESET_CODE_INVALID": "Кодот има 6 цифри.", "RESET_CODE_WRONG": "Кодот е погрешен или истекол. Побарај нов.", "SAVE_NEW_PASSWORD": "Зачувај и најави се", "RESET_CODE_AGAIN": "Испрати нов код", "RESET_CODE_RESENT": "Испратен е нов код", "RESET_CODE_SPAM_HINT": "Нема е-пошта по неколку минути? Провери ја папката за спам.", "DELETE_ACCOUNT": "Избриши сметка", "DELETE_ACCOUNT_INTRO": "Ова ја брише сметката за {email}. Не може да се врати.", "DELETE_WHAT_GOES": "Се брише", "DELETE_GOES_PROFILE": "Твоето име, фотографија, телефон и е-пошта", "DELETE_GOES_PRO": "Твојот профил на мајстор, така што купувачите повеќе нема да те најдат", "DELETE_GOES_JOBS": "Отворените работи што си ги објавил и понудите на кои никој не одговорил", "DELETE_GOES_LOGIN": "Твојата најава, на сите уреди", "DELETE_WHAT_STAYS": "Се чува, без твоето име", "DELETE_STAYS_CONTRACTS": "Завршените договори, пораките и оценките, за другата страна да ги има и понатаму", "DELETE_STAYS_INVOICES": "Фактурите, кои според норвешките сметководствени правила мора да се чуваат 5 години", "DELETE_PASSWORD_HINT": "За да бидеме сигурни дека си ти.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Да ја избришеш сметката?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Ќе бидеш одјавен и повеќе нема да можеш да се најавиш со оваа сметка.", "DELETE_BLOCKED_CONTRACTS": "Имаш договори во тек. Прво заврши ги или откажи ги, за другата страна да не остане да чека.", "DELETE_BLOCKED_COMPANY": "Поседуваш фирма со други членови. Прво отстрани ги под Тим.", "JOB_CATEGORY_REQUIRED": "Избери категорија, за да дознаат за работата вистинските мајстори."}, "pt-PT": {"EDIT": "Editar", "REMOVE": "Remover", "CLEAR": "Limpar", "ARCHIVE": "Arquivar", "NOTES": "Notas", "YOU": "tu", "DATE_PLACEHOLDER": "dd/mm/aaaa", "DATE_INVALID": "Escreve a data como dd/mm/aaaa.", "AMOUNT_INVALID": "Escreve um valor em NOK, ex. 5000.", "EMAIL_INVALID": "Esse endereço de email não parece estar certo.", "POSTCODE_FORMAT": "Um código postal tem 4 dígitos.", "CLIENT": "Cliente", "CLIENTS": "Clientes", "CLIENTS_PRO_ONLY": "O teu registo de clientes é para profissionais. Inicia sessão com uma conta de profissional para o usares.", "SEARCH_CLIENTS": "Pesquisar clientes", "CLIENTS_ACTIVE": "Ativos", "CLIENTS_ARCHIVED": "Arquivados", "NO_CLIENTS": "Ainda sem clientes", "NO_CLIENTS_TEXT": "Adiciona os clientes para quem trabalhas fora do marketplace e mantém os trabalhos, as horas e as faturas deles num só lugar.", "NO_CLIENTS_MATCH": "Nenhum cliente corresponde à pesquisa.", "NO_ARCHIVED_CLIENTS": "Nada arquivado", "NO_ARCHIVED_CLIENTS_TEXT": "Os clientes que arquivares ficam aqui, com os trabalhos e as faturas antigas.", "NEW_CLIENT": "Novo cliente", "EDIT_CLIENT": "Editar cliente", "SAVE_CLIENT": "Guardar cliente", "CLIENT_FORM_INTRO": "Só tu e a tua empresa podem ver isto. A morada é usada como local de trabalho em novos trabalhos.", "CLIENT_TYPE": "Tipo de cliente", "CLIENT_PRIVATE": "Particular", "CLIENT_BUSINESS": "Empresa", "CLIENT_COMPANY_PLACEHOLDER": "ex. Bergen Eiendom AS", "CONTACT_PERSON": "Pessoa de contacto", "CONTACT_NAME": "Contacto: {name}", "CLIENT_EMAIL_HINT": "As faturas podem ser enviadas para aqui.", "CLIENT_NOTES_PLACEHOLDER": "Código do portão, estacionamento, o nome do cão…", "CLIENT_NOTES_HINT": "Só para ti e para os teus colegas, nunca é mostrado ao cliente.", "CLIENT_NOT_FOUND": "Cliente não encontrado", "CLIENT_IS_ARCHIVED": "Arquivado", "CLIENT_NO_DETAILS": "Ainda sem dados de contacto. Toca em Editar para os adicionar.", "CLIENT_JOBS": "Trabalhos", "CLIENT_NO_JOBS": "Ainda não há trabalhos para este cliente.", "ARCHIVE_CLIENT": "Arquivar cliente", "ARCHIVE_CLIENT_TITLE": "Arquivar este cliente?", "ARCHIVE_CLIENT_TEXT": "O cliente tem trabalhos, por isso é guardado com os trabalhos e as faturas. Podes restaurá-lo mais tarde.", "RESTORE_CLIENT": "Restaurar cliente", "DELETE_CLIENT": "Eliminar cliente", "DELETE_CLIENT_TITLE": "Eliminar este cliente?", "DELETE_CLIENT_TEXT": "{name} é removido do teu registo.", "NEW_ASSIGNMENT": "Novo trabalho", "NEW_ASSIGNMENT_INTRO": "Regista trabalho para o teu próprio cliente e combina o preço. No contrato podes adicionar etapas, registar horas e faturar.", "PICK_CLIENT_INTRO": "Para quem é o trabalho?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "O que foi combinado, materiais, o que o cliente deve saber", "START_DATE": "Data de início", "END_DATE": "Data de fim", "END_BEFORE_START": "A data de fim é anterior à data de início.", "STEPS_OPTIONAL_HINT": "Opcional. Sem etapas, o trabalho inteiro é uma só etapa.", "STEPS_SPLIT_HINT": "Cada etapa é aprovada separadamente. Os valores têm de somar o preço.", "STEPS_HOURLY_HINT": "Cada etapa é aprovada separadamente. As horas são registadas no contrato.", "STEP_TITLE": "Etapa", "STEP_TITLE_PLACEHOLDER": "ex. Demolição e drenagem", "STEP_TITLE_REQUIRED": "Dá um nome a cada etapa.", "STEP_AMOUNT": "Valor (NOK)", "STEP_AMOUNT_REQUIRED": "Dá um valor a cada etapa.", "STEP_DUE": "Prazo", "STEP_DESCRIPTION_PLACEHOLDER": "O que está incluído nesta etapa", "STEPS_MUST_ADD_UP": "As etapas têm de somar {total}.", "STEPS_ADD_UP": "As etapas somam o preço ✓", "STEPS_REST": "Falta distribuir: {rest}", "STEPS_TOTAL_MISMATCH": "As etapas somam {steps}, o preço combinado é {total}.", "REMOVE_STEP": "Remover etapa", "ADD_STEP": "Adicionar etapa", "ADD_STEP_INTRO": "O cliente aprova cada etapa quando estiver concluída.", "EDIT_STEP": "Editar etapa", "DELETE_STEP": "Eliminar etapa", "DELETE_STEP_TITLE": "Eliminar esta etapa?", "DELETE_STEP_TEXT": "«{title}» é removida do contrato.", "STEP_STARTED_NO_DELETE": "Esta etapa já começou, por isso pode ser alterada, mas não eliminada.", "CREATE_CONTRACT": "Criar contrato", "JOB_HAS_CONTRACT": "Este trabalho já tem um contrato.", "JOB_NOT_YOURS": "Só quem criou o trabalho o pode alterar.", "JOB_CANNOT_EDIT": "Já foi contratado alguém, por isso o trabalho já não pode ser alterado.", "EDIT_JOB": "Editar trabalho", "EDIT_JOB_INTRO": "Os profissionais veem as alterações de imediato.", "EDIT_JOB_WITH_OFFERS": "Orçamentos recebidos: {n}. Avisa os profissionais no chat sobre grandes alterações, para que os orçamentos continuem a servir.", "CREATED_AGO": "Criado {time}", "DRAFT_NOT_VISIBLE": "Isto é um rascunho. Os profissionais só o veem quando o publicares.", "CANCEL_JOB": "Cancelar trabalho", "CANCEL_JOB_TITLE": "Cancelar este trabalho?", "CANCEL_JOB_TEXT": "O trabalho é retirado e não pode ser reaberto.", "CANCEL_JOB_WITH_OFFERS_TEXT": "O trabalho é retirado e os profissionais que enviaram orçamentos ({n}) são avisados de que foi cancelado.", "DELETE_JOB_TITLE": "Eliminar o rascunho?", "DELETE_JOB_TEXT": "O rascunho é eliminado definitivamente.", "CANCEL_CONTRACT": "Cancelar o contrato", "CANCEL_CONTRACT_INTRO": "O trabalho para aqui. As etapas aprovadas e as faturas são mantidas, e a outra parte é avisada.", "CANCEL_REASON": "Porquê? (opcional)", "CANCEL_REASON_PLACEHOLDER": "Algumas palavras que ambos podem ver mais tarde", "CONTRACT_CANCELLED_ON": "Cancelado {date}", "COMPLETE_CLIENT_JOB_TEXT": "Todas as etapas estão assinadas. O trabalho é marcado como concluído.", "SIGN_ON_SITE": "O cliente assina", "SIGN_ON_SITE_INTRO": "Deixa o cliente verificar o trabalho e assinar com o dedo no ecrã. Isto aprova a etapa.", "CUSTOMER_NAME": "Nome do cliente", "SIGNATURE": "Assinatura", "SIGN_HERE": "Assina aqui", "APPROVE_WITH_SIGNATURE": "Aprovar com assinatura", "CHANGE_PASSWORD": "Alterar palavra-passe", "CHANGE_PASSWORD_INTRO": "A tua sessão continua iniciada aqui. A sessão é terminada nos teus outros telemóveis e navegadores.", "CURRENT_PASSWORD": "Palavra-passe atual", "CURRENT_PASSWORD_REQUIRED": "Introduz a tua palavra-passe atual.", "CURRENT_PASSWORD_WRONG": "Essa não é a tua palavra-passe atual.", "NEW_PASSWORD": "Nova palavra-passe", "REPEAT_PASSWORD": "Repete a nova palavra-passe", "PASSWORDS_DONT_MATCH": "As palavras-passe não coincidem.", "PASSWORD_SAME_AS_OLD": "Escolhe uma palavra-passe que ainda não tenhas usado aqui.", "PASSWORD_CHANGED": "Palavra-passe alterada", "PAYMENTS": "Pagamentos", "PAYMENT": "Pagamento", "NO_PAYMENTS": "Ainda sem pagamentos", "NO_PAYMENTS_TEXT": "Os pagamentos feitos pela app aparecem aqui. Os trabalhos pagos por fatura estão em Faturas.", "PAYMENT_STATUS_PENDING": "Pendente", "PAYMENT_STATUS_HELD": "Guardado em segurança", "PAYMENT_STATUS_RELEASED": "Pago", "PAYMENT_STATUS_REFUNDED": "Reembolsado", "PAYMENT_STATUS_FAILED": "Falhou", "PLATFORM_FEE": "Taxa {fee}", "TEAM": "Equipa", "TEAM_ROW_HINT": "As pessoas que trabalham na empresa", "TEAM_MANAGE_HINT": "Os colegas precisam primeiro de uma conta Qup Work. Toca em alguém para o alterar ou remover.", "TEAM_WORKER_HINT": "O proprietário e os administradores adicionam e removem colegas.", "ADD_MEMBER": "Adicionar colega", "ADD_MEMBER_INTRO": "Usa o email com que a pessoa se registou no Qup Work.", "MEMBER_NOT_FOUND": "Ainda ninguém se registou com esse email. Pede-lhe que crie uma conta primeiro.", "MEMBER_ALREADY": "Essa pessoa já está na empresa.", "ROLE": "Função", "ROLE_ADMIN_HINT": "Os administradores podem alterar os dados da empresa e as definições de faturação, e adicionar colegas.", "ROLE_WORKER_HINT": "Os funcionários veem os trabalhos da empresa, registam horas e fazem o trabalho.", "REMOVE_FROM_COMPANY": "Remover da empresa", "REMOVE_MEMBER_TITLE": "Remover da empresa?", "REMOVE_MEMBER_TEXT": "{name} deixa de ver os trabalhos e os clientes da empresa.", "LEAVE_COMPANY": "Sair da empresa", "LEAVE_COMPANY_TITLE": "Sair da empresa?", "LEAVE_COMPANY_TEXT": "Deixas de ver os trabalhos e os clientes de {name}.", "NOTIF_JOB_WITHDRAWN": "O cliente cancelou o trabalho", "INVOICE_EMAILED_TO": "{email} recebeu a fatura em PDF.", "INVOICE_NO_EMAIL": "Enviada, mas não por email: o cliente não tem endereço de email. Abra o PDF e partilhe-o, ou use Enviar por email.", "INVOICE_EMAIL_NOT_SET_UP": "Enviada, mas não por email: o email ainda não está configurado no servidor (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Enviada, mas o email falhou: {error}", "SEND_INVOICE_EMAIL_TO": "O PDF é enviado por email para {email}.", "SEND_INVOICE_NO_EMAIL": "Não há endereço de email, por isso não será enviada por email. Pode partilhar o PDF.", "EMAIL_INVOICE": "Enviar por email", "PREVIEW_PDF": "Pré-visualizar PDF", "OPEN_PDF": "Abrir PDF", "EMAILED": "Enviada por email", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Não enviada por email", "INVOICE_LANGUAGE": "Idioma da fatura", "NOTIF_NEW_JOB_NEARBY": "Novo trabalho perto de si", "NOTIF_NEW_JOB_REMOTE": "Novo trabalho remoto", "NOTIF_JOB_INVITED": "Foi convidado para um trabalho", "NOTIF_JOB_IN_PLACE": "«{job}» em {place}", "JOB_ALERTS": "Alertas de novos trabalhos", "JOB_ALERTS_ON_TEXT": "Recebe uma notificação quando um trabalho das suas categorias é publicado na sua zona.", "JOB_ALERTS_OFF_TEXT": "Não será notificado sobre novos trabalhos, mas continua a vê-los na app.", "JOB_ALERTS_NEEDS_VISIBLE": "Ative primeiro a visibilidade. Só os profissionais que os clientes podem encontrar recebem alertas.", "FORGOT_PASSWORD": "Esqueceste-te da palavra-passe?", "FORGOT_PASSWORD_TITLE": "Nova palavra-passe", "FORGOT_PASSWORD_INTRO": "Introduz o email com que te registaste e enviamos-te um código.", "SEND_CODE": "Enviar código", "RESET_CODE_SENT": "Se {email} tiver uma conta, vai a caminho um código de 6 dígitos. Introdu-lo abaixo com uma nova palavra-passe.", "RESET_CODE": "Código do email", "RESET_CODE_INVALID": "O código tem 6 dígitos.", "RESET_CODE_WRONG": "O código está errado ou expirou. Pede um novo.", "SAVE_NEW_PASSWORD": "Guardar e iniciar sessão", "RESET_CODE_AGAIN": "Enviar novo código", "RESET_CODE_RESENT": "Novo código enviado", "RESET_CODE_SPAM_HINT": "Não recebeste o email ao fim de alguns minutos? Verifica a pasta de spam.", "DELETE_ACCOUNT": "Eliminar conta", "DELETE_ACCOUNT_INTRO": "Isto elimina a conta de {email}. Não pode ser anulado.", "DELETE_WHAT_GOES": "É eliminado", "DELETE_GOES_PROFILE": "O teu nome, foto, telefone e email", "DELETE_GOES_PRO": "O teu perfil profissional, para que os clientes deixem de te encontrar", "DELETE_GOES_JOBS": "Trabalhos em aberto que publicaste e propostas a que ninguém respondeu", "DELETE_GOES_LOGIN": "O teu início de sessão, em todos os dispositivos", "DELETE_WHAT_STAYS": "É mantido, sem o teu nome", "DELETE_STAYS_CONTRACTS": "Contratos concluídos, mensagens e avaliações, para que a outra parte continue a tê-los", "DELETE_STAYS_INVOICES": "Faturas, que as regras contabilísticas norueguesas obrigam a guardar durante 5 anos", "DELETE_PASSWORD_HINT": "Para termos a certeza de que és tu.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Eliminar a tua conta?", "DELETE_ACCOUNT_CONFIRM_TEXT": "A tua sessão é terminada e não poderás voltar a iniciar sessão com esta conta.", "DELETE_BLOCKED_CONTRACTS": "Tens contratos em curso. Conclui-os ou cancela-os primeiro, para que a outra parte não fique à espera.", "DELETE_BLOCKED_COMPANY": "És dono de uma empresa com outros membros. Remove-os primeiro em Equipa.", "JOB_CATEGORY_REQUIRED": "Escolhe uma categoria, para que os profissionais certos fiquem a saber do trabalho."}, "ro-RO": {"EDIT": "Editează", "REMOVE": "Elimină", "CLEAR": "Golește", "ARCHIVE": "Arhivează", "NOTES": "Notițe", "YOU": "tu", "DATE_PLACEHOLDER": "zz.ll.aaaa", "DATE_INVALID": "Scrie data sub forma zz.ll.aaaa.", "AMOUNT_INVALID": "Scrie o sumă în NOK, de ex. 5000.", "EMAIL_INVALID": "Adresa de e-mail nu pare corectă.", "POSTCODE_FORMAT": "Un cod poștal are 4 cifre.", "CLIENT": "Client", "CLIENTS": "Clienți", "CLIENTS_PRO_ONLY": "Registrul tău de clienți este pentru meseriași. Autentifică-te cu un cont de meseriaș ca să-l folosești.", "SEARCH_CLIENTS": "Caută clienți", "CLIENTS_ACTIVE": "Activi", "CLIENTS_ARCHIVED": "Arhivați", "NO_CLIENTS": "Niciun client încă", "NO_CLIENTS_TEXT": "Adaugă clienții pentru care lucrezi în afara platformei și ține lucrările, orele și facturile lor într-un singur loc.", "NO_CLIENTS_MATCH": "Niciun client nu se potrivește căutării.", "NO_ARCHIVED_CLIENTS": "Nimic arhivat", "NO_ARCHIVED_CLIENTS_TEXT": "Clienții pe care îi arhivezi ajung aici, cu lucrările și facturile lor vechi.", "NEW_CLIENT": "Client nou", "EDIT_CLIENT": "Editează clientul", "SAVE_CLIENT": "Salvează clientul", "CLIENT_FORM_INTRO": "Doar tu și firma ta vedeți asta. Adresa este folosită ca loc de muncă la lucrările noi.", "CLIENT_TYPE": "Tipul clientului", "CLIENT_PRIVATE": "Persoană fizică", "CLIENT_BUSINESS": "Firmă", "CLIENT_COMPANY_PLACEHOLDER": "De ex. Bergen Eiendom AS", "CONTACT_PERSON": "Persoană de contact", "CONTACT_NAME": "Contact: {name}", "CLIENT_EMAIL_HINT": "Facturile pot fi trimise aici.", "CLIENT_NOTES_PLACEHOLDER": "Codul porții, parcarea, numele câinelui…", "CLIENT_NOTES_HINT": "Doar pentru tine și colegii tăi, nu e afișat niciodată clientului.", "CLIENT_NOT_FOUND": "Clientul nu a fost găsit", "CLIENT_IS_ARCHIVED": "Arhivat", "CLIENT_NO_DETAILS": "Încă nu există date de contact. Atinge Editează ca să le adaugi.", "CLIENT_JOBS": "Lucrări", "CLIENT_NO_JOBS": "Nicio lucrare pentru acest client încă.", "ARCHIVE_CLIENT": "Arhivează clientul", "ARCHIVE_CLIENT_TITLE": "Arhivezi acest client?", "ARCHIVE_CLIENT_TEXT": "Clientul are lucrări, așa că este păstrat împreună cu lucrările și facturile sale. Îl poți restaura mai târziu.", "RESTORE_CLIENT": "Restaurează clientul", "DELETE_CLIENT": "Șterge clientul", "DELETE_CLIENT_TITLE": "Ștergi acest client?", "DELETE_CLIENT_TEXT": "{name} este eliminat din registrul tău.", "NEW_ASSIGNMENT": "Lucrare nouă", "NEW_ASSIGNMENT_INTRO": "Înregistrează o lucrare pentru clientul tău și stabilește prețul. Din contract poți adăuga etape, înregistra ore și emite facturi.", "PICK_CLIENT_INTRO": "Pentru cine este lucrarea?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Ce s-a convenit, materiale, ce ar trebui să știe clientul", "START_DATE": "Data de început", "END_DATE": "Data de sfârșit", "END_BEFORE_START": "Data de sfârșit este înaintea datei de început.", "STEPS_OPTIONAL_HINT": "Opțional. Fără etape, toată lucrarea este o singură etapă.", "STEPS_SPLIT_HINT": "Fiecare etapă se aprobă separat. Sumele trebuie să dea împreună prețul.", "STEPS_HOURLY_HINT": "Fiecare etapă se aprobă separat. Orele se înregistrează în contract.", "STEP_TITLE": "Etapă", "STEP_TITLE_PLACEHOLDER": "De ex. Demolare și scurgere", "STEP_TITLE_REQUIRED": "Dă un nume fiecărei etape.", "STEP_AMOUNT": "Sumă (NOK)", "STEP_AMOUNT_REQUIRED": "Dă o sumă fiecărei etape.", "STEP_DUE": "Termen", "STEP_DESCRIPTION_PLACEHOLDER": "Ce include această etapă", "STEPS_MUST_ADD_UP": "Etapele trebuie să totalizeze {total}.", "STEPS_ADD_UP": "Etapele totalizează prețul ✓", "STEPS_REST": "Rămas de împărțit: {rest}", "STEPS_TOTAL_MISMATCH": "Etapele totalizează {steps}, prețul convenit este {total}.", "REMOVE_STEP": "Elimină etapa", "ADD_STEP": "Adaugă o etapă", "ADD_STEP_INTRO": "Clientul aprobă fiecare etapă când e gata.", "EDIT_STEP": "Editează etapa", "DELETE_STEP": "Șterge etapa", "DELETE_STEP_TITLE": "Ștergi această etapă?", "DELETE_STEP_TEXT": "„{title}” este eliminată din contract.", "STEP_STARTED_NO_DELETE": "Etapa a început, așa că poate fi modificată, dar nu ștearsă.", "CREATE_CONTRACT": "Creează contractul", "JOB_HAS_CONTRACT": "Această lucrare are deja un contract.", "JOB_NOT_YOURS": "Doar cel care a creat lucrarea o poate modifica.", "JOB_CANNOT_EDIT": "Cineva a fost deja angajat, așa că lucrarea nu mai poate fi modificată.", "EDIT_JOB": "Editează lucrarea", "EDIT_JOB_INTRO": "Profesioniștii văd modificările imediat.", "EDIT_JOB_WITH_OFFERS": "Oferte primite: {n}. Spune-le profesioniștilor în chat despre modificările mari, ca ofertele lor să fie în continuare potrivite.", "CREATED_AGO": "Creată {time}", "DRAFT_NOT_VISIBLE": "Aceasta este o ciornă. Profesioniștii nu o văd până nu o publici.", "CANCEL_JOB": "Anulează lucrarea", "CANCEL_JOB_TITLE": "Anulezi această lucrare?", "CANCEL_JOB_TEXT": "Lucrarea este retrasă și nu mai poate fi redeschisă.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Lucrarea este retrasă, iar profesioniștii care au trimis oferte ({n}) sunt anunțați că a fost anulată.", "DELETE_JOB_TITLE": "Ștergi ciorna?", "DELETE_JOB_TEXT": "Ciorna este ștearsă definitiv.", "CANCEL_CONTRACT": "Anulează contractul", "CANCEL_CONTRACT_INTRO": "Lucrul se oprește aici. Etapele aprobate și facturile se păstrează, iar cealaltă parte este anunțată.", "CANCEL_REASON": "De ce? (opțional)", "CANCEL_REASON_PLACEHOLDER": "Câteva cuvinte pe care le puteți vedea amândoi mai târziu", "CONTRACT_CANCELLED_ON": "Anulat {date}", "COMPLETE_CLIENT_JOB_TEXT": "Toate etapele sunt semnate. Lucrarea este marcată ca finalizată.", "SIGN_ON_SITE": "Clientul semnează", "SIGN_ON_SITE_INTRO": "Lasă clientul să verifice lucrarea și să semneze cu degetul pe ecran. Astfel etapa este aprobată.", "CUSTOMER_NAME": "Numele clientului", "SIGNATURE": "Semnătură", "SIGN_HERE": "Semnează aici", "APPROVE_WITH_SIGNATURE": "Aprobă cu semnătură", "CHANGE_PASSWORD": "Schimbă parola", "CHANGE_PASSWORD_INTRO": "Rămâi autentificat aici. Pe celelalte telefoane și browsere vei fi deconectat.", "CURRENT_PASSWORD": "Parola actuală", "CURRENT_PASSWORD_REQUIRED": "Introdu parola actuală.", "CURRENT_PASSWORD_WRONG": "Aceasta nu este parola ta actuală.", "NEW_PASSWORD": "Parolă nouă", "REPEAT_PASSWORD": "Repetă parola nouă", "PASSWORDS_DONT_MATCH": "Parolele nu se potrivesc.", "PASSWORD_SAME_AS_OLD": "Alege o parolă pe care nu ai mai folosit-o aici.", "PASSWORD_CHANGED": "Parola a fost schimbată", "PAYMENTS": "Plăți", "PAYMENT": "Plată", "NO_PAYMENTS": "Nicio plată încă", "NO_PAYMENTS_TEXT": "Plățile făcute prin aplicație apar aici. Lucrările plătite prin factură sunt la Facturi.", "PAYMENT_STATUS_PENDING": "În așteptare", "PAYMENT_STATUS_HELD": "Păstrată în siguranță", "PAYMENT_STATUS_RELEASED": "Plătită", "PAYMENT_STATUS_REFUNDED": "Rambursată", "PAYMENT_STATUS_FAILED": "Eșuată", "PLATFORM_FEE": "Comision {fee}", "TEAM": "Echipă", "TEAM_ROW_HINT": "Oamenii care lucrează în firmă", "TEAM_MANAGE_HINT": "Colegii au nevoie mai întâi de un cont Qup Work. Atinge pe cineva ca să-l modifici sau să-l elimini.", "TEAM_WORKER_HINT": "Proprietarul și administratorii adaugă și elimină colegi.", "ADD_MEMBER": "Adaugă un coleg", "ADD_MEMBER_INTRO": "Folosește adresa de e-mail cu care s-a înregistrat în Qup Work.", "MEMBER_NOT_FOUND": "Nimeni nu s-a înregistrat încă cu acest e-mail. Roagă persoana să-și creeze mai întâi un cont.", "MEMBER_ALREADY": "Persoana aceasta este deja în firmă.", "ROLE": "Rol", "ROLE_ADMIN_HINT": "Administratorii pot modifica datele firmei și setările de facturare și pot adăuga colegi.", "ROLE_WORKER_HINT": "Angajații văd lucrările firmei, înregistrează ore și fac treaba.", "REMOVE_FROM_COMPANY": "Elimină din firmă", "REMOVE_MEMBER_TITLE": "Elimini din firmă?", "REMOVE_MEMBER_TEXT": "{name} nu mai vede lucrările și clienții firmei.", "LEAVE_COMPANY": "Părăsește firma", "LEAVE_COMPANY_TITLE": "Părăsești firma?", "LEAVE_COMPANY_TEXT": "Nu mai vezi lucrările și clienții firmei {name}.", "NOTIF_JOB_WITHDRAWN": "Clientul a anulat lucrarea", "INVOICE_EMAILED_TO": "{email} a primit factura în format PDF.", "INVOICE_NO_EMAIL": "Trimisă, dar nu pe e-mail: clientul nu are adresă de e-mail. Deschide PDF-ul și distribuie-l tu, sau folosește Trimite pe e-mail.", "INVOICE_EMAIL_NOT_SET_UP": "Trimisă, dar nu pe e-mail: e-mailul nu este încă configurat pe server (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Trimisă, dar e-mailul a eșuat: {error}", "SEND_INVOICE_EMAIL_TO": "PDF-ul este trimis pe e-mail la {email}.", "SEND_INVOICE_NO_EMAIL": "Nu există adresă de e-mail, deci nu va fi trimisă pe e-mail. Poți distribui PDF-ul tu.", "EMAIL_INVOICE": "Trimite pe e-mail", "PREVIEW_PDF": "Previzualizează PDF", "OPEN_PDF": "Deschide PDF", "EMAILED": "Trimisă pe e-mail", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Netrimisă pe e-mail", "INVOICE_LANGUAGE": "Limba facturii", "NOTIF_NEW_JOB_NEARBY": "Lucrare nouă lângă tine", "NOTIF_NEW_JOB_REMOTE": "Lucrare nouă la distanță", "NOTIF_JOB_INVITED": "Ai fost invitat la o lucrare", "NOTIF_JOB_IN_PLACE": "„{job}” în {place}", "JOB_ALERTS": "Alerte pentru lucrări noi", "JOB_ALERTS_ON_TEXT": "Primești o notificare când o lucrare din categoriile tale e publicată în zona ta.", "JOB_ALERTS_OFF_TEXT": "Nu vei fi anunțat despre lucrări noi, dar le poți vedea în continuare în aplicație.", "JOB_ALERTS_NEEDS_VISIBLE": "Activează mai întâi vizibilitatea. Doar profesioniștii pe care îi pot găsi clienții primesc alerte.", "FORGOT_PASSWORD": "Ai uitat parola?", "FORGOT_PASSWORD_TITLE": "Parolă nouă", "FORGOT_PASSWORD_INTRO": "Introdu e-mailul cu care te-ai înregistrat și îți trimitem un cod.", "SEND_CODE": "Trimite codul", "RESET_CODE_SENT": "Dacă {email} are un cont, un cod din 6 cifre este pe drum. Introdu-l mai jos împreună cu o parolă nouă.", "RESET_CODE": "Codul din e-mail", "RESET_CODE_INVALID": "Codul are 6 cifre.", "RESET_CODE_WRONG": "Codul este greșit sau a expirat. Cere unul nou.", "SAVE_NEW_PASSWORD": "Salvează și autentifică-te", "RESET_CODE_AGAIN": "Trimite un cod nou", "RESET_CODE_RESENT": "Cod nou trimis", "RESET_CODE_SPAM_HINT": "Niciun e-mail după câteva minute? Verifică folderul de spam.", "DELETE_ACCOUNT": "Șterge contul", "DELETE_ACCOUNT_INTRO": "Se va șterge contul pentru {email}. Acțiunea nu poate fi anulată.", "DELETE_WHAT_GOES": "Se șterg", "DELETE_GOES_PROFILE": "Numele, fotografia, telefonul și e-mailul tău", "DELETE_GOES_PRO": "Profilul tău de meseriaș, astfel încât clienții să nu te mai găsească", "DELETE_GOES_JOBS": "Lucrările deschise pe care le-ai publicat și ofertele la care nu a răspuns nimeni", "DELETE_GOES_LOGIN": "Autentificarea ta, pe toate dispozitivele", "DELETE_WHAT_STAYS": "Se păstrează, fără numele tău", "DELETE_STAYS_CONTRACTS": "Contractele încheiate, mesajele și recenziile, ca cealaltă parte să le aibă în continuare", "DELETE_STAYS_INVOICES": "Facturile, pe care regulile contabile norvegiene impun să fie păstrate 5 ani", "DELETE_PASSWORD_HINT": "Ca să ne asigurăm că ești tu.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Ștergi contul?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Vei fi deconectat și nu te vei mai putea autentifica cu acest cont.", "DELETE_BLOCKED_CONTRACTS": "Ai contracte în desfășurare. Finalizează-le sau anulează-le mai întâi, ca cealaltă parte să nu rămână în așteptare.", "DELETE_BLOCKED_COMPANY": "Deții o firmă cu alți membri. Elimină-i mai întâi din Echipă.", "JOB_CATEGORY_REQUIRED": "Alege o categorie, ca meseriașii potriviți să afle de lucrare."}, "pt-BR": {"EDIT": "Editar", "REMOVE": "Remover", "CLEAR": "Limpar", "ARCHIVE": "Arquivar", "NOTES": "Observações", "YOU": "você", "DATE_PLACEHOLDER": "dd/mm/aaaa", "DATE_INVALID": "Escreva a data como dd/mm/aaaa.", "AMOUNT_INVALID": "Escreva um valor em NOK, por exemplo 5000.", "EMAIL_INVALID": "Esse endereço de e-mail não parece correto.", "POSTCODE_FORMAT": "O código postal tem 4 dígitos.", "CLIENT": "Cliente", "CLIENTS": "Clientes", "CLIENTS_PRO_ONLY": "O cadastro de clientes é para profissionais. Entre com uma conta de profissional para usá-lo.", "SEARCH_CLIENTS": "Buscar clientes", "CLIENTS_ACTIVE": "Ativos", "CLIENTS_ARCHIVED": "Arquivados", "NO_CLIENTS": "Nenhum cliente ainda", "NO_CLIENTS_TEXT": "Adicione os clientes para quem você trabalha fora da plataforma e mantenha serviços, horas e faturas deles em um só lugar.", "NO_CLIENTS_MATCH": "Nenhum cliente corresponde à sua busca.", "NO_ARCHIVED_CLIENTS": "Nada arquivado", "NO_ARCHIVED_CLIENTS_TEXT": "Os clientes que você arquivar ficam aqui, com seus serviços e faturas antigos.", "NEW_CLIENT": "Novo cliente", "EDIT_CLIENT": "Editar cliente", "SAVE_CLIENT": "Salvar cliente", "CLIENT_FORM_INTRO": "Só você e sua empresa podem ver isso. O endereço é usado como local do serviço em novos serviços.", "CLIENT_TYPE": "Tipo de cliente", "CLIENT_PRIVATE": "Pessoa física", "CLIENT_BUSINESS": "Empresa", "CLIENT_COMPANY_PLACEHOLDER": "Ex.: Bergen Eiendom AS", "CONTACT_PERSON": "Pessoa de contato", "CONTACT_NAME": "Contato: {name}", "CLIENT_EMAIL_HINT": "As faturas podem ser enviadas para cá.", "CLIENT_NOTES_PLACEHOLDER": "Código do portão, estacionamento, o nome do cachorro…", "CLIENT_NOTES_HINT": "Só para você e seus colegas, nunca mostrado ao cliente.", "CLIENT_NOT_FOUND": "Cliente não encontrado", "CLIENT_IS_ARCHIVED": "Arquivado", "CLIENT_NO_DETAILS": "Ainda não há dados de contato. Toque em Editar para adicioná-los.", "CLIENT_JOBS": "Serviços", "CLIENT_NO_JOBS": "Nenhum serviço para este cliente ainda.", "ARCHIVE_CLIENT": "Arquivar cliente", "ARCHIVE_CLIENT_TITLE": "Arquivar este cliente?", "ARCHIVE_CLIENT_TEXT": "O cliente tem serviços, então ele é mantido junto com os serviços e as faturas. Você pode restaurá-lo depois.", "RESTORE_CLIENT": "Restaurar cliente", "DELETE_CLIENT": "Excluir cliente", "DELETE_CLIENT_TITLE": "Excluir este cliente?", "DELETE_CLIENT_TEXT": "{name} é removido do seu cadastro.", "NEW_ASSIGNMENT": "Novo trabalho", "NEW_ASSIGNMENT_INTRO": "Registre um trabalho para seu próprio cliente e combine o preço. No contrato você pode adicionar etapas, registrar horas e faturar.", "PICK_CLIENT_INTRO": "Para quem é o trabalho?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "O que foi combinado, materiais, tudo o que o cliente precisa saber", "START_DATE": "Data de início", "END_DATE": "Data de término", "END_BEFORE_START": "A data de término é anterior à data de início.", "STEPS_OPTIONAL_HINT": "Opcional. Sem etapas, o serviço inteiro é uma única etapa.", "STEPS_SPLIT_HINT": "Cada etapa é aprovada separadamente. A soma dos valores tem que dar o preço.", "STEPS_HOURLY_HINT": "Cada etapa é aprovada separadamente. As horas são registradas no contrato.", "STEP_TITLE": "Etapa", "STEP_TITLE_PLACEHOLDER": "Ex.: Demolição e drenagem", "STEP_TITLE_REQUIRED": "Dê um nome a cada etapa.", "STEP_AMOUNT": "Valor (NOK)", "STEP_AMOUNT_REQUIRED": "Informe um valor para cada etapa.", "STEP_DUE": "Prazo", "STEP_DESCRIPTION_PLACEHOLDER": "O que está incluído nesta etapa", "STEPS_MUST_ADD_UP": "A soma das etapas tem que dar {total}.", "STEPS_ADD_UP": "A soma das etapas bate com o preço ✓", "STEPS_REST": "Falta distribuir: {rest}", "STEPS_TOTAL_MISMATCH": "A soma das etapas é {steps}, o preço combinado é {total}.", "REMOVE_STEP": "Remover etapa", "ADD_STEP": "Adicionar etapa", "ADD_STEP_INTRO": "O cliente aprova cada etapa quando ela é concluída.", "EDIT_STEP": "Editar etapa", "DELETE_STEP": "Excluir etapa", "DELETE_STEP_TITLE": "Excluir esta etapa?", "DELETE_STEP_TEXT": "“{title}” é removida do contrato.", "STEP_STARTED_NO_DELETE": "Esta etapa já começou, então pode ser alterada, mas não excluída.", "CREATE_CONTRACT": "Criar contrato", "JOB_HAS_CONTRACT": "Este serviço já tem um contrato.", "JOB_NOT_YOURS": "Só quem criou o serviço pode alterá-lo.", "JOB_CANNOT_EDIT": "Alguém já foi contratado, então o serviço não pode mais ser alterado.", "EDIT_JOB": "Editar serviço", "EDIT_JOB_INTRO": "Os profissionais veem as alterações na hora.", "EDIT_JOB_WITH_OFFERS": "Orçamentos recebidos: {n}. Avise os profissionais sobre mudanças grandes no chat, para que os orçamentos continuem valendo.", "CREATED_AGO": "Criado {time}", "DRAFT_NOT_VISIBLE": "Isto é um rascunho. Os profissionais só vão vê-lo quando você publicar.", "CANCEL_JOB": "Cancelar serviço", "CANCEL_JOB_TITLE": "Cancelar este serviço?", "CANCEL_JOB_TEXT": "O serviço é retirado do ar e não pode ser reaberto.", "CANCEL_JOB_WITH_OFFERS_TEXT": "O serviço é retirado do ar, e os profissionais que enviaram orçamentos ({n}) são avisados do cancelamento.", "DELETE_JOB_TITLE": "Excluir o rascunho?", "DELETE_JOB_TEXT": "O rascunho é excluído para sempre.", "CANCEL_CONTRACT": "Cancelar o contrato", "CANCEL_CONTRACT_INTRO": "O trabalho para aqui. As etapas aprovadas e as faturas são mantidas, e a outra parte é avisada.", "CANCEL_REASON": "Por quê? (opcional)", "CANCEL_REASON_PLACEHOLDER": "Algumas palavras que vocês dois poderão ver depois", "CONTRACT_CANCELLED_ON": "Cancelado em {date}", "COMPLETE_CLIENT_JOB_TEXT": "Todas as etapas foram assinadas. O serviço é marcado como concluído.", "SIGN_ON_SITE": "Assinatura do cliente", "SIGN_ON_SITE_INTRO": "Deixe o cliente conferir o trabalho e assinar com o dedo na tela. Isso aprova a etapa.", "CUSTOMER_NAME": "Nome do cliente", "SIGNATURE": "Assinatura", "SIGN_HERE": "Assine aqui", "APPROVE_WITH_SIGNATURE": "Aprovar com assinatura", "CHANGE_PASSWORD": "Alterar senha", "CHANGE_PASSWORD_INTRO": "Você continua conectado aqui. Seus outros celulares e navegadores serão desconectados.", "CURRENT_PASSWORD": "Senha atual", "CURRENT_PASSWORD_REQUIRED": "Informe sua senha atual.", "CURRENT_PASSWORD_WRONG": "Essa não é sua senha atual.", "NEW_PASSWORD": "Nova senha", "REPEAT_PASSWORD": "Repita a nova senha", "PASSWORDS_DONT_MATCH": "As senhas não coincidem.", "PASSWORD_SAME_AS_OLD": "Escolha uma senha que você ainda não usou aqui.", "PASSWORD_CHANGED": "Senha alterada", "PAYMENTS": "Pagamentos", "PAYMENT": "Pagamento", "NO_PAYMENTS": "Nenhum pagamento ainda", "NO_PAYMENTS_TEXT": "Os pagamentos feitos pelo app aparecem aqui. Serviços pagos por fatura ficam em Faturas.", "PAYMENT_STATUS_PENDING": "Aguardando", "PAYMENT_STATUS_HELD": "Retido com segurança", "PAYMENT_STATUS_RELEASED": "Pago", "PAYMENT_STATUS_REFUNDED": "Reembolsado", "PAYMENT_STATUS_FAILED": "Falhou", "PLATFORM_FEE": "Taxa {fee}", "TEAM": "Equipe", "TEAM_ROW_HINT": "As pessoas que trabalham na empresa", "TEAM_MANAGE_HINT": "Os colegas precisam ter uma conta no Qup Work primeiro. Toque em alguém para alterar ou remover.", "TEAM_WORKER_HINT": "O dono e os administradores adicionam e removem colegas.", "ADD_MEMBER": "Adicionar colega", "ADD_MEMBER_INTRO": "Use o e-mail com que a pessoa se cadastrou no Qup Work.", "MEMBER_NOT_FOUND": "Ninguém se cadastrou com esse e-mail ainda. Peça para a pessoa criar uma conta primeiro.", "MEMBER_ALREADY": "Essa pessoa já está na empresa.", "ROLE": "Função", "ROLE_ADMIN_HINT": "Os administradores podem alterar os dados da empresa e as configurações de fatura, e adicionar colegas.", "ROLE_WORKER_HINT": "Os funcionários veem os serviços da empresa, registram horas e fazem o trabalho.", "REMOVE_FROM_COMPANY": "Remover da empresa", "REMOVE_MEMBER_TITLE": "Remover da empresa?", "REMOVE_MEMBER_TEXT": "{name} deixa de ver os serviços e clientes da empresa.", "LEAVE_COMPANY": "Sair da empresa", "LEAVE_COMPANY_TITLE": "Sair da empresa?", "LEAVE_COMPANY_TEXT": "Você deixa de ver os serviços e clientes de {name}.", "NOTIF_JOB_WITHDRAWN": "O cliente cancelou o serviço", "INVOICE_EMAILED_TO": "{email} recebeu a fatura em PDF.", "INVOICE_NO_EMAIL": "Enviada, mas não por e-mail: o cliente não tem endereço de e-mail. Abra o PDF e compartilhe você mesmo, ou use Enviar por e-mail.", "INVOICE_EMAIL_NOT_SET_UP": "Enviada, mas não por e-mail: o e-mail ainda não está configurado no servidor (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Enviada, mas o e-mail falhou: {error}", "SEND_INVOICE_EMAIL_TO": "O PDF é enviado por e-mail para {email}.", "SEND_INVOICE_NO_EMAIL": "Não há endereço de e-mail, então ela não será enviada por e-mail. Você pode compartilhar o PDF.", "EMAIL_INVOICE": "Enviar por e-mail", "PREVIEW_PDF": "Visualizar PDF", "OPEN_PDF": "Abrir PDF", "EMAILED": "Enviada por e-mail", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Não enviada por e-mail", "INVOICE_LANGUAGE": "Idioma da fatura", "NOTIF_NEW_JOB_NEARBY": "Novo trabalho perto de você", "NOTIF_NEW_JOB_REMOTE": "Novo trabalho remoto", "NOTIF_JOB_INVITED": "Você foi convidado para um trabalho", "NOTIF_JOB_IN_PLACE": "“{job}” em {place}", "JOB_ALERTS": "Alertas de novos trabalhos", "JOB_ALERTS_ON_TEXT": "Você recebe uma notificação quando um trabalho das suas categorias é publicado na sua região.", "JOB_ALERTS_OFF_TEXT": "Você não será avisado sobre novos trabalhos, mas ainda pode vê-los no app.", "JOB_ALERTS_NEEDS_VISIBLE": "Ative a visibilidade primeiro. Só profissionais que os clientes conseguem encontrar recebem alertas.", "FORGOT_PASSWORD": "Esqueceu a senha?", "FORGOT_PASSWORD_TITLE": "Nova senha", "FORGOT_PASSWORD_INTRO": "Digite o e-mail que você usou no cadastro e enviaremos um código.", "SEND_CODE": "Enviar código", "RESET_CODE_SENT": "Se {email} tiver uma conta, um código de 6 dígitos está a caminho. Digite-o abaixo com uma nova senha.", "RESET_CODE": "Código do e-mail", "RESET_CODE_INVALID": "O código tem 6 dígitos.", "RESET_CODE_WRONG": "O código está errado ou expirou. Peça um novo.", "SAVE_NEW_PASSWORD": "Salvar e entrar", "RESET_CODE_AGAIN": "Enviar novo código", "RESET_CODE_RESENT": "Novo código enviado", "RESET_CODE_SPAM_HINT": "Nenhum e-mail depois de alguns minutos? Confira sua pasta de spam.", "DELETE_ACCOUNT": "Excluir conta", "DELETE_ACCOUNT_INTRO": "Isso exclui a conta de {email}. Não é possível desfazer.", "DELETE_WHAT_GOES": "Será excluído", "DELETE_GOES_PROFILE": "Seu nome, foto, telefone e e-mail", "DELETE_GOES_PRO": "Seu perfil profissional, para que os clientes não encontrem mais você", "DELETE_GOES_JOBS": "Serviços abertos que você publicou e propostas que ninguém respondeu", "DELETE_GOES_LOGIN": "Seu login, em todos os dispositivos", "DELETE_WHAT_STAYS": "Será mantido, sem o seu nome", "DELETE_STAYS_CONTRACTS": "Contratos concluídos, mensagens e avaliações, para que a outra parte ainda tenha acesso", "DELETE_STAYS_INVOICES": "Faturas, que as regras contábeis norueguesas exigem que sejam guardadas por 5 anos", "DELETE_PASSWORD_HINT": "Para confirmar que é você.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Excluir sua conta?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Você será desconectado e não poderá mais entrar com esta conta.", "DELETE_BLOCKED_CONTRACTS": "Você tem contratos em andamento. Conclua ou cancele-os primeiro, para que a outra parte não fique esperando.", "DELETE_BLOCKED_COMPANY": "Você é dono de uma empresa com outros membros. Remova-os primeiro em Equipe.", "JOB_CATEGORY_REQUIRED": "Escolha uma categoria para que os profissionais certos fiquem sabendo do serviço."}, "fi-FI": {"EDIT": "Muokkaa", "REMOVE": "Poista", "CLEAR": "Tyhjennä", "ARCHIVE": "Arkistoi", "NOTES": "Muistiinpanot", "YOU": "sinä", "DATE_PLACEHOLDER": "pp.kk.vvvv", "DATE_INVALID": "Kirjoita päivämäärä muodossa pp.kk.vvvv.", "AMOUNT_INVALID": "Kirjoita summa kruunuina (NOK), esim. 5000.", "EMAIL_INVALID": "Sähköpostiosoite ei näytä oikealta.", "POSTCODE_FORMAT": "Postinumerossa on 4 numeroa.", "CLIENT": "Asiakas", "CLIENTS": "Asiakkaat", "CLIENTS_PRO_ONLY": "Oma asiakasrekisteri on ammattilaisille. Kirjaudu sisään ammattilaistilillä käyttääksesi sitä.", "SEARCH_CLIENTS": "Hae asiakkaita", "CLIENTS_ACTIVE": "Aktiiviset", "CLIENTS_ARCHIVED": "Arkistoidut", "NO_CLIENTS": "Ei vielä asiakkaita", "NO_CLIENTS_TEXT": "Lisää asiakkaat, joille teet töitä palvelun ulkopuolella, ja pidä heidän työnsä, tuntinsa ja laskunsa yhdessä paikassa.", "NO_CLIENTS_MATCH": "Yksikään asiakas ei vastaa hakuasi.", "NO_ARCHIVED_CLIENTS": "Ei arkistoituja", "NO_ARCHIVED_CLIENTS_TEXT": "Arkistoimasi asiakkaat päätyvät tänne vanhojen töidensä ja laskujensa kanssa.", "NEW_CLIENT": "Uusi asiakas", "EDIT_CLIENT": "Muokkaa asiakasta", "SAVE_CLIENT": "Tallenna asiakas", "CLIENT_FORM_INTRO": "Vain sinä ja yrityksesi näette tämän. Osoitetta käytetään uusien töiden työkohteen osoitteena.", "CLIENT_TYPE": "Asiakkaan tyyppi", "CLIENT_PRIVATE": "Yksityishenkilö", "CLIENT_BUSINESS": "Yritys", "CLIENT_COMPANY_PLACEHOLDER": "Esim. Bergen Eiendom AS", "CONTACT_PERSON": "Yhteyshenkilö", "CONTACT_NAME": "Yhteyshenkilö: {name}", "CLIENT_EMAIL_HINT": "Laskut voi lähettää tähän osoitteeseen.", "CLIENT_NOTES_PLACEHOLDER": "Portin koodi, pysäköinti, koiran nimi…", "CLIENT_NOTES_HINT": "Vain sinulle ja kollegoillesi, ei koskaan näy asiakkaalle.", "CLIENT_NOT_FOUND": "Asiakasta ei löytynyt", "CLIENT_IS_ARCHIVED": "Arkistoitu", "CLIENT_NO_DETAILS": "Ei vielä yhteystietoja. Lisää ne napauttamalla Muokkaa.", "CLIENT_JOBS": "Työt", "CLIENT_NO_JOBS": "Tällä asiakkaalla ei ole vielä töitä.", "ARCHIVE_CLIENT": "Arkistoi asiakas", "ARCHIVE_CLIENT_TITLE": "Arkistoidaanko asiakas?", "ARCHIVE_CLIENT_TEXT": "Asiakkaalla on töitä, joten se säilytetään töineen ja laskuineen. Voit palauttaa sen myöhemmin.", "RESTORE_CLIENT": "Palauta asiakas", "DELETE_CLIENT": "Poista asiakas", "DELETE_CLIENT_TITLE": "Poistetaanko asiakas?", "DELETE_CLIENT_TEXT": "{name} poistetaan rekisteristäsi.", "NEW_ASSIGNMENT": "Uusi toimeksianto", "NEW_ASSIGNMENT_INTRO": "Kirjaa työ omalle asiakkaallesi ja sopikaa hinnasta. Sopimuksella voit lisätä vaiheita, kirjata tunteja ja laskuttaa.", "PICK_CLIENT_INTRO": "Kenelle työ tehdään?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Mitä on sovittu, materiaalit, kaikki mitä asiakkaan pitäisi tietää", "START_DATE": "Aloituspäivä", "END_DATE": "Päättymispäivä", "END_BEFORE_START": "Päättymispäivä on ennen aloituspäivää.", "STEPS_OPTIONAL_HINT": "Valinnainen. Ilman vaiheita koko työ on yksi vaihe.", "STEPS_SPLIT_HINT": "Jokainen vaihe hyväksytään erikseen. Summien on vastattava yhteensä hintaa.", "STEPS_HOURLY_HINT": "Jokainen vaihe hyväksytään erikseen. Tunnit kirjataan sopimukselle.", "STEP_TITLE": "Vaihe", "STEP_TITLE_PLACEHOLDER": "Esim. Purku ja viemäröinti", "STEP_TITLE_REQUIRED": "Anna jokaiselle vaiheelle nimi.", "STEP_AMOUNT": "Summa (NOK)", "STEP_AMOUNT_REQUIRED": "Anna jokaiselle vaiheelle summa.", "STEP_DUE": "Määräpäivä", "STEP_DESCRIPTION_PLACEHOLDER": "Mitä tähän vaiheeseen sisältyy", "STEPS_MUST_ADD_UP": "Vaiheiden summan on oltava {total}.", "STEPS_ADD_UP": "Vaiheiden summa vastaa hintaa ✓", "STEPS_REST": "Jakamatta: {rest}", "STEPS_TOTAL_MISMATCH": "Vaiheiden summa on {steps}, sovittu hinta on {total}.", "REMOVE_STEP": "Poista vaihe", "ADD_STEP": "Lisää vaihe", "ADD_STEP_INTRO": "Asiakas hyväksyy jokaisen vaiheen, kun se on valmis.", "EDIT_STEP": "Muokkaa vaihetta", "DELETE_STEP": "Poista vaihe", "DELETE_STEP_TITLE": "Poistetaanko vaihe?", "DELETE_STEP_TEXT": "”{title}” poistetaan sopimukselta.", "STEP_STARTED_NO_DELETE": "Tämä vaihe on aloitettu, joten sitä voi muuttaa mutta ei poistaa.", "CREATE_CONTRACT": "Luo sopimus", "JOB_HAS_CONTRACT": "Tällä työllä on jo sopimus.", "JOB_NOT_YOURS": "Vain työn luonut voi muuttaa sitä.", "JOB_CANNOT_EDIT": "Joku on jo palkattu, joten työtä ei voi enää muuttaa.", "EDIT_JOB": "Muokkaa työtä", "EDIT_JOB_INTRO": "Ammattilaiset näkevät muutokset heti.", "EDIT_JOB_WITH_OFFERS": "Saatuja tarjouksia: {n}. Kerro isoista muutoksista ammattilaisille chatissa, jotta heidän tarjouksensa pitävät yhä paikkansa.", "CREATED_AGO": "Luotu {time}", "DRAFT_NOT_VISIBLE": "Tämä on luonnos. Ammattilaiset eivät näe sitä ennen kuin julkaiset sen.", "CANCEL_JOB": "Peru työ", "CANCEL_JOB_TITLE": "Perutaanko työ?", "CANCEL_JOB_TEXT": "Työ poistetaan näkyvistä, eikä sitä voi avata uudelleen.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Työ poistetaan näkyvistä, ja tarjouksen lähettäneille ammattilaisille ({n}) kerrotaan, että se peruttiin.", "DELETE_JOB_TITLE": "Poistetaanko luonnos?", "DELETE_JOB_TEXT": "Luonnos poistetaan pysyvästi.", "CANCEL_CONTRACT": "Peru sopimus", "CANCEL_CONTRACT_INTRO": "Työ päättyy tähän. Hyväksytyt vaiheet ja laskut säilyvät, ja toiselle osapuolelle ilmoitetaan.", "CANCEL_REASON": "Miksi? (valinnainen)", "CANCEL_REASON_PLACEHOLDER": "Muutama sana, jonka näette molemmat myöhemmin", "CONTRACT_CANCELLED_ON": "Peruttu {date}", "COMPLETE_CLIENT_JOB_TEXT": "Kaikki vaiheet on kuitattu. Työ merkitään valmiiksi.", "SIGN_ON_SITE": "Asiakas allekirjoittaa", "SIGN_ON_SITE_INTRO": "Anna asiakkaan tarkistaa työ ja allekirjoittaa sormella näytölle. Tämä hyväksyy vaiheen.", "CUSTOMER_NAME": "Asiakkaan nimi", "SIGNATURE": "Allekirjoitus", "SIGN_HERE": "Allekirjoita tähän", "APPROVE_WITH_SIGNATURE": "Hyväksy allekirjoituksella", "CHANGE_PASSWORD": "Vaihda salasana", "CHANGE_PASSWORD_INTRO": "Pysyt kirjautuneena täällä. Muut puhelimesi ja selaimesi kirjataan ulos.", "CURRENT_PASSWORD": "Nykyinen salasana", "CURRENT_PASSWORD_REQUIRED": "Anna nykyinen salasanasi.", "CURRENT_PASSWORD_WRONG": "Tämä ei ole nykyinen salasanasi.", "NEW_PASSWORD": "Uusi salasana", "REPEAT_PASSWORD": "Toista uusi salasana", "PASSWORDS_DONT_MATCH": "Salasanat eivät täsmää.", "PASSWORD_SAME_AS_OLD": "Valitse salasana, jota et ole käyttänyt täällä.", "PASSWORD_CHANGED": "Salasana vaihdettu", "PAYMENTS": "Maksut", "PAYMENT": "Maksu", "NO_PAYMENTS": "Ei vielä maksuja", "NO_PAYMENTS_TEXT": "Sovelluksen kautta tehdyt maksut näkyvät täällä. Laskulla maksetut työt löytyvät kohdasta Laskut.", "PAYMENT_STATUS_PENDING": "Odottaa", "PAYMENT_STATUS_HELD": "Turvallisesti säilössä", "PAYMENT_STATUS_RELEASED": "Maksettu", "PAYMENT_STATUS_REFUNDED": "Palautettu", "PAYMENT_STATUS_FAILED": "Epäonnistui", "PLATFORM_FEE": "Palvelumaksu {fee}", "TEAM": "Tiimi", "TEAM_ROW_HINT": "Yrityksessä työskentelevät henkilöt", "TEAM_MANAGE_HINT": "Kollegoilla on oltava ensin Qup Work -tili. Napauta henkilöä muuttaaksesi tai poistaaksesi hänet.", "TEAM_WORKER_HINT": "Omistaja ja ylläpitäjät lisäävät ja poistavat kollegoita.", "ADD_MEMBER": "Lisää kollega", "ADD_MEMBER_INTRO": "Käytä sähköpostia, jolla hän rekisteröityi Qup Workiin.", "MEMBER_NOT_FOUND": "Kukaan ei ole vielä rekisteröitynyt tällä sähköpostilla. Pyydä häntä luomaan ensin tili.", "MEMBER_ALREADY": "Henkilö on jo yrityksessä.", "ROLE": "Rooli", "ROLE_ADMIN_HINT": "Ylläpitäjät voivat muuttaa yrityksen tietoja ja laskutusasetuksia sekä lisätä kollegoita.", "ROLE_WORKER_HINT": "Työntekijät näkevät yrityksen työt, kirjaavat tunteja ja tekevät työt.", "REMOVE_FROM_COMPANY": "Poista yrityksestä", "REMOVE_MEMBER_TITLE": "Poistetaanko yrityksestä?", "REMOVE_MEMBER_TEXT": "{name} ei enää näe yrityksen töitä ja asiakkaita.", "LEAVE_COMPANY": "Poistu yrityksestä", "LEAVE_COMPANY_TITLE": "Poistutaanko yrityksestä?", "LEAVE_COMPANY_TEXT": "Et enää näe yrityksen {name} töitä ja asiakkaita.", "NOTIF_JOB_WITHDRAWN": "Asiakas perui työn", "INVOICE_EMAILED_TO": "{email} on saanut laskun PDF-tiedostona.", "INVOICE_NO_EMAIL": "Lähetetty, mutta ei sähköpostilla: asiakkaalla ei ole sähköpostiosoitetta. Avaa PDF ja jaa se itse tai käytä Lähetä sähköpostilla.", "INVOICE_EMAIL_NOT_SET_UP": "Lähetetty, mutta ei sähköpostilla: sähköpostia ei ole vielä määritetty palvelimelle (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Lähetetty, mutta sähköposti epäonnistui: {error}", "SEND_INVOICE_EMAIL_TO": "PDF lähetetään sähköpostilla osoitteeseen {email}.", "SEND_INVOICE_NO_EMAIL": "Sähköpostiosoitetta ei ole, joten laskua ei lähetetä sähköpostilla. Voit jakaa PDF:n itse.", "EMAIL_INVOICE": "Lähetä sähköpostilla", "PREVIEW_PDF": "Esikatsele PDF", "OPEN_PDF": "Avaa PDF", "EMAILED": "Lähetetty sähköpostilla", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Ei lähetetty sähköpostilla", "INVOICE_LANGUAGE": "Laskun kieli", "NOTIF_NEW_JOB_NEARBY": "Uusi työ lähelläsi", "NOTIF_NEW_JOB_REMOTE": "Uusi etätyö", "NOTIF_JOB_INVITED": "Sinut kutsuttiin työhön", "NOTIF_JOB_IN_PLACE": "”{job}”, {place}", "JOB_ALERTS": "Ilmoitukset uusista töistä", "JOB_ALERTS_ON_TEXT": "Saat ilmoituksen, kun alueellasi julkaistaan työ luokissasi.", "JOB_ALERTS_OFF_TEXT": "Et saa ilmoituksia uusista töistä, mutta voit yhä selata niitä sovelluksessa.", "JOB_ALERTS_NEEDS_VISIBLE": "Laita näkyvyys ensin päälle. Vain asiakkaiden löydettävissä olevat ammattilaiset saavat työilmoituksia.", "FORGOT_PASSWORD": "Unohditko salasanan?", "FORGOT_PASSWORD_TITLE": "Uusi salasana", "FORGOT_PASSWORD_INTRO": "Anna sähköpostiosoite, jolla rekisteröidyit, niin lähetämme sinulle koodin.", "SEND_CODE": "Lähetä koodi", "RESET_CODE_SENT": "Jos osoitteella {email} on tili, 6-numeroinen koodi on matkalla. Syötä se alle uuden salasanan kanssa.", "RESET_CODE": "Koodi sähköpostista", "RESET_CODE_INVALID": "Koodissa on 6 numeroa.", "RESET_CODE_WRONG": "Koodi on väärä tai vanhentunut. Pyydä uusi.", "SAVE_NEW_PASSWORD": "Tallenna ja kirjaudu sisään", "RESET_CODE_AGAIN": "Lähetä uusi koodi", "RESET_CODE_RESENT": "Uusi koodi lähetetty", "RESET_CODE_SPAM_HINT": "Eikö sähköpostia ole tullut muutamassa minuutissa? Tarkista roskapostikansio.", "DELETE_ACCOUNT": "Poista tili", "DELETE_ACCOUNT_INTRO": "Tämä poistaa osoitteen {email} tilin. Toimintoa ei voi perua.", "DELETE_WHAT_GOES": "Poistetaan", "DELETE_GOES_PROFILE": "Nimesi, kuvasi, puhelinnumerosi ja sähköpostisi", "DELETE_GOES_PRO": "Ammattilaisprofiilisi, joten asiakkaat eivät enää löydä sinua", "DELETE_GOES_JOBS": "Julkaisemasi avoimet työt ja tarjoukset, joihin kukaan ei ole vastannut", "DELETE_GOES_LOGIN": "Kirjautumisesi kaikilla laitteilla", "DELETE_WHAT_STAYS": "Säilytetään ilman nimeäsi", "DELETE_STAYS_CONTRACTS": "Päättyneet sopimukset, viestit ja arvostelut, jotta ne säilyvät toisella osapuolella", "DELETE_STAYS_INVOICES": "Laskut, jotka Norjan kirjanpitosäännöt edellyttävät säilytettävän 5 vuotta", "DELETE_PASSWORD_HINT": "Jotta voimme varmistaa, että se olet sinä.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Poistetaanko tilisi?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Sinut kirjataan ulos, etkä voi enää kirjautua tällä tilillä.", "DELETE_BLOCKED_CONTRACTS": "Sinulla on käynnissä olevia sopimuksia. Vie ne ensin loppuun tai peru ne, jottei toinen osapuoli jää odottamaan.", "DELETE_BLOCKED_COMPANY": "Omistat yrityksen, jossa on muita jäseniä. Poista heidät ensin Tiimi-näkymässä.", "JOB_CATEGORY_REQUIRED": "Valitse kategoria, jotta oikeat ammattilaiset kuulevat työstä."}, "de-DE": {"EDIT": "Bearbeiten", "REMOVE": "Entfernen", "CLEAR": "Leeren", "ARCHIVE": "Archivieren", "NOTES": "Notizen", "YOU": "du", "DATE_PLACEHOLDER": "TT.MM.JJJJ", "DATE_INVALID": "Gib das Datum als TT.MM.JJJJ ein.", "AMOUNT_INVALID": "Gib einen Betrag in NOK ein, z. B. 5000.", "EMAIL_INVALID": "Die E-Mail-Adresse sieht nicht richtig aus.", "POSTCODE_FORMAT": "Eine Postleitzahl hat 4 Ziffern.", "CLIENT": "Kunde", "CLIENTS": "Kunden", "CLIENTS_PRO_ONLY": "Die eigene Kundenkartei ist für Profis. Melde dich mit einem Profi-Konto an, um sie zu nutzen.", "SEARCH_CLIENTS": "Kunden durchsuchen", "CLIENTS_ACTIVE": "Aktiv", "CLIENTS_ARCHIVED": "Archiviert", "NO_CLIENTS": "Noch keine Kunden", "NO_CLIENTS_TEXT": "Leg die Kunden an, für die du außerhalb des Marktplatzes arbeitest, und hab Aufträge, Stunden und Rechnungen für sie an einem Ort.", "NO_CLIENTS_MATCH": "Keine Kunden passen zu deiner Suche.", "NO_ARCHIVED_CLIENTS": "Nichts archiviert", "NO_ARCHIVED_CLIENTS_TEXT": "Kunden, die du archivierst, landen hier – mit ihren alten Aufträgen und Rechnungen.", "NEW_CLIENT": "Neuer Kunde", "EDIT_CLIENT": "Kunde bearbeiten", "SAVE_CLIENT": "Kunde speichern", "CLIENT_FORM_INTRO": "Nur du und deine Firma sehen das. Die Adresse wird bei neuen Aufträgen als Arbeitsort verwendet.", "CLIENT_TYPE": "Art des Kunden", "CLIENT_PRIVATE": "Privatperson", "CLIENT_BUSINESS": "Unternehmen", "CLIENT_COMPANY_PLACEHOLDER": "Z. B. Bergen Eiendom AS", "CONTACT_PERSON": "Ansprechpartner", "CONTACT_NAME": "Kontakt: {name}", "CLIENT_EMAIL_HINT": "Rechnungen können hierhin gesendet werden.", "CLIENT_NOTES_PLACEHOLDER": "Torcode, Parken, der Name des Hundes …", "CLIENT_NOTES_HINT": "Nur für dich und deine Kollegen, wird dem Kunden nie angezeigt.", "CLIENT_NOT_FOUND": "Kunde nicht gefunden", "CLIENT_IS_ARCHIVED": "Archiviert", "CLIENT_NO_DETAILS": "Noch keine Kontaktdaten. Tippe auf Bearbeiten, um sie hinzuzufügen.", "CLIENT_JOBS": "Aufträge", "CLIENT_NO_JOBS": "Noch keine Aufträge für diesen Kunden.", "ARCHIVE_CLIENT": "Kunde archivieren", "ARCHIVE_CLIENT_TITLE": "Diesen Kunden archivieren?", "ARCHIVE_CLIENT_TEXT": "Der Kunde hat Aufträge und bleibt deshalb mit seinen Aufträgen und Rechnungen erhalten. Du kannst ihn später wiederherstellen.", "RESTORE_CLIENT": "Kunde wiederherstellen", "DELETE_CLIENT": "Kunde löschen", "DELETE_CLIENT_TITLE": "Diesen Kunden löschen?", "DELETE_CLIENT_TEXT": "{name} wird aus deiner Kundenkartei entfernt.", "NEW_ASSIGNMENT": "Neuer Auftrag", "NEW_ASSIGNMENT_INTRO": "Erfasse Arbeit für deinen eigenen Kunden und vereinbare den Preis. Im Vertrag kannst du Schritte hinzufügen, Stunden erfassen und abrechnen.", "PICK_CLIENT_INTRO": "Für wen ist die Arbeit?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Was vereinbart ist, Material, alles, was der Kunde wissen sollte", "START_DATE": "Startdatum", "END_DATE": "Enddatum", "END_BEFORE_START": "Das Enddatum liegt vor dem Startdatum.", "STEPS_OPTIONAL_HINT": "Optional. Ohne Schritte ist der ganze Auftrag ein Schritt.", "STEPS_SPLIT_HINT": "Jeder Schritt wird einzeln freigegeben. Die Beträge müssen zusammen den Preis ergeben.", "STEPS_HOURLY_HINT": "Jeder Schritt wird einzeln freigegeben. Die Stunden werden im Vertrag erfasst.", "STEP_TITLE": "Schritt", "STEP_TITLE_PLACEHOLDER": "Z. B. Abriss und Abfluss", "STEP_TITLE_REQUIRED": "Gib jedem Schritt einen Namen.", "STEP_AMOUNT": "Betrag (NOK)", "STEP_AMOUNT_REQUIRED": "Gib jedem Schritt einen Betrag.", "STEP_DUE": "Fälligkeitsdatum", "STEP_DESCRIPTION_PLACEHOLDER": "Was in diesem Schritt enthalten ist", "STEPS_MUST_ADD_UP": "Die Schritte müssen zusammen {total} ergeben.", "STEPS_ADD_UP": "Die Schritte ergeben den Preis ✓", "STEPS_REST": "Noch aufzuteilen: {rest}", "STEPS_TOTAL_MISMATCH": "Die Schritte ergeben {steps}, der vereinbarte Preis ist {total}.", "REMOVE_STEP": "Schritt entfernen", "ADD_STEP": "Schritt hinzufügen", "ADD_STEP_INTRO": "Der Kunde gibt jeden Schritt frei, wenn er erledigt ist.", "EDIT_STEP": "Schritt bearbeiten", "DELETE_STEP": "Schritt löschen", "DELETE_STEP_TITLE": "Diesen Schritt löschen?", "DELETE_STEP_TEXT": "„{title}“ wird aus dem Vertrag entfernt.", "STEP_STARTED_NO_DELETE": "Dieser Schritt hat schon begonnen. Er kann geändert, aber nicht gelöscht werden.", "CREATE_CONTRACT": "Vertrag erstellen", "JOB_HAS_CONTRACT": "Für diesen Auftrag gibt es schon einen Vertrag.", "JOB_NOT_YOURS": "Nur wer den Auftrag erstellt hat, kann ihn ändern.", "JOB_CANNOT_EDIT": "Es wurde schon jemand beauftragt, deshalb kann der Auftrag nicht mehr geändert werden.", "EDIT_JOB": "Auftrag bearbeiten", "EDIT_JOB_INTRO": "Profis sehen die Änderungen sofort.", "EDIT_JOB_WITH_OFFERS": "Erhaltene Angebote: {n}. Informiere die Profis im Chat über größere Änderungen, damit ihre Angebote noch passen.", "CREATED_AGO": "Erstellt {time}", "DRAFT_NOT_VISIBLE": "Das ist ein Entwurf. Profis sehen ihn erst, wenn du ihn veröffentlichst.", "CANCEL_JOB": "Auftrag stornieren", "CANCEL_JOB_TITLE": "Diesen Auftrag stornieren?", "CANCEL_JOB_TEXT": "Der Auftrag wird entfernt und kann nicht wieder geöffnet werden.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Der Auftrag wird entfernt, und die Profis, die Angebote gesendet haben ({n}), werden über die Stornierung informiert.", "DELETE_JOB_TITLE": "Entwurf löschen?", "DELETE_JOB_TEXT": "Der Entwurf wird endgültig gelöscht.", "CANCEL_CONTRACT": "Vertrag stornieren", "CANCEL_CONTRACT_INTRO": "Die Arbeit endet hier. Freigegebene Schritte und Rechnungen bleiben erhalten, und die andere Seite wird informiert.", "CANCEL_REASON": "Warum? (optional)", "CANCEL_REASON_PLACEHOLDER": "Ein paar Worte, die ihr beide später sehen könnt", "CONTRACT_CANCELLED_ON": "Storniert {date}", "COMPLETE_CLIENT_JOB_TEXT": "Alle Schritte sind freigegeben. Der Auftrag wird als abgeschlossen markiert.", "SIGN_ON_SITE": "Kunde unterschreibt", "SIGN_ON_SITE_INTRO": "Lass den Kunden die Arbeit prüfen und mit dem Finger auf dem Bildschirm unterschreiben. Damit wird der Schritt freigegeben.", "CUSTOMER_NAME": "Name des Kunden", "SIGNATURE": "Unterschrift", "SIGN_HERE": "Hier unterschreiben", "APPROVE_WITH_SIGNATURE": "Mit Unterschrift freigeben", "CHANGE_PASSWORD": "Passwort ändern", "CHANGE_PASSWORD_INTRO": "Hier bleibst du angemeldet. Auf deinen anderen Handys und Browsern wirst du abgemeldet.", "CURRENT_PASSWORD": "Aktuelles Passwort", "CURRENT_PASSWORD_REQUIRED": "Gib dein aktuelles Passwort ein.", "CURRENT_PASSWORD_WRONG": "Das ist nicht dein aktuelles Passwort.", "NEW_PASSWORD": "Neues Passwort", "REPEAT_PASSWORD": "Neues Passwort wiederholen", "PASSWORDS_DONT_MATCH": "Die Passwörter stimmen nicht überein.", "PASSWORD_SAME_AS_OLD": "Wähle ein Passwort, das du hier noch nicht verwendet hast.", "PASSWORD_CHANGED": "Passwort geändert", "PAYMENTS": "Zahlungen", "PAYMENT": "Zahlung", "NO_PAYMENTS": "Noch keine Zahlungen", "NO_PAYMENTS_TEXT": "Zahlungen über die App erscheinen hier. Aufträge, die per Rechnung bezahlt werden, findest du unter Rechnungen.", "PAYMENT_STATUS_PENDING": "Ausstehend", "PAYMENT_STATUS_HELD": "Sicher verwahrt", "PAYMENT_STATUS_RELEASED": "Ausgezahlt", "PAYMENT_STATUS_REFUNDED": "Erstattet", "PAYMENT_STATUS_FAILED": "Fehlgeschlagen", "PLATFORM_FEE": "Gebühr {fee}", "TEAM": "Team", "TEAM_ROW_HINT": "Die Leute, die in der Firma arbeiten", "TEAM_MANAGE_HINT": "Kollegen brauchen zuerst ein Qup Work-Konto. Tippe auf jemanden, um ihn zu ändern oder zu entfernen.", "TEAM_WORKER_HINT": "Inhaber und Administratoren fügen Kollegen hinzu und entfernen sie.", "ADD_MEMBER": "Kollegen hinzufügen", "ADD_MEMBER_INTRO": "Verwende die E-Mail-Adresse, mit der sich die Person bei Qup Work registriert hat.", "MEMBER_NOT_FOUND": "Mit dieser E-Mail-Adresse hat sich noch niemand registriert. Bitte die Person, zuerst ein Konto zu erstellen.", "MEMBER_ALREADY": "Diese Person ist schon in der Firma.", "ROLE": "Rolle", "ROLE_ADMIN_HINT": "Administratoren können die Firmendaten und Rechnungseinstellungen ändern und Kollegen hinzufügen.", "ROLE_WORKER_HINT": "Mitarbeiter sehen die Aufträge der Firma, erfassen Stunden und erledigen die Arbeit.", "REMOVE_FROM_COMPANY": "Aus der Firma entfernen", "REMOVE_MEMBER_TITLE": "Aus der Firma entfernen?", "REMOVE_MEMBER_TEXT": "{name} sieht die Aufträge und Kunden der Firma nicht mehr.", "LEAVE_COMPANY": "Firma verlassen", "LEAVE_COMPANY_TITLE": "Firma verlassen?", "LEAVE_COMPANY_TEXT": "Du siehst die Aufträge und Kunden von {name} nicht mehr.", "NOTIF_JOB_WITHDRAWN": "Der Kunde hat den Auftrag storniert", "INVOICE_EMAILED_TO": "{email} hat die Rechnung als PDF erhalten.", "INVOICE_NO_EMAIL": "Gesendet, aber nicht per E-Mail: Der Kunde hat keine E-Mail-Adresse. Öffne das PDF und teile es selbst, oder nutze Per E-Mail senden.", "INVOICE_EMAIL_NOT_SET_UP": "Gesendet, aber nicht per E-Mail: E-Mail ist auf dem Server noch nicht eingerichtet (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Gesendet, aber die E-Mail ist fehlgeschlagen: {error}", "SEND_INVOICE_EMAIL_TO": "Das PDF wird per E-Mail an {email} gesendet.", "SEND_INVOICE_NO_EMAIL": "Es gibt keine E-Mail-Adresse, daher wird nichts per E-Mail gesendet. Du kannst das PDF selbst teilen.", "EMAIL_INVOICE": "Per E-Mail senden", "PREVIEW_PDF": "PDF-Vorschau", "OPEN_PDF": "PDF öffnen", "EMAILED": "Per E-Mail gesendet", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Nicht per E-Mail gesendet", "INVOICE_LANGUAGE": "Sprache der Rechnung", "NOTIF_NEW_JOB_NEARBY": "Neuer Auftrag in deiner Nähe", "NOTIF_NEW_JOB_REMOTE": "Neuer Remote-Auftrag", "NOTIF_JOB_INVITED": "Du wurdest zu einem Auftrag eingeladen", "NOTIF_JOB_IN_PLACE": "„{job}“ in {place}", "JOB_ALERTS": "Benachrichtigung bei neuen Aufträgen", "JOB_ALERTS_ON_TEXT": "Du wirst benachrichtigt, wenn in deiner Gegend ein Auftrag in deinen Kategorien veröffentlicht wird.", "JOB_ALERTS_OFF_TEXT": "Du wirst nicht über neue Aufträge benachrichtigt, findest sie aber weiterhin in der App.", "JOB_ALERTS_NEEDS_VISIBLE": "Schalte zuerst die Sichtbarkeit ein. Nur Profis, die Kunden finden können, bekommen Auftragshinweise.", "FORGOT_PASSWORD": "Passwort vergessen?", "FORGOT_PASSWORD_TITLE": "Neues Passwort", "FORGOT_PASSWORD_INTRO": "Gib die E-Mail-Adresse ein, mit der du dich registriert hast, und wir schicken dir einen Code.", "SEND_CODE": "Code senden", "RESET_CODE_SENT": "Wenn es für {email} ein Konto gibt, ist ein 6-stelliger Code unterwegs. Gib ihn unten zusammen mit einem neuen Passwort ein.", "RESET_CODE": "Code aus der E-Mail", "RESET_CODE_INVALID": "Der Code hat 6 Ziffern.", "RESET_CODE_WRONG": "Der Code ist falsch oder abgelaufen. Fordere einen neuen an.", "SAVE_NEW_PASSWORD": "Speichern und anmelden", "RESET_CODE_AGAIN": "Neuen Code senden", "RESET_CODE_RESENT": "Neuer Code gesendet", "RESET_CODE_SPAM_HINT": "Nach ein paar Minuten noch keine E-Mail? Sieh in deinem Spam-Ordner nach.", "DELETE_ACCOUNT": "Konto löschen", "DELETE_ACCOUNT_INTRO": "Damit wird das Konto für {email} gelöscht. Das lässt sich nicht rückgängig machen.", "DELETE_WHAT_GOES": "Wird gelöscht", "DELETE_GOES_PROFILE": "Dein Name, Foto, Telefon und deine E-Mail", "DELETE_GOES_PRO": "Dein Profi-Profil, sodass Kunden dich nicht mehr finden", "DELETE_GOES_JOBS": "Offene Aufträge, die du eingestellt hast, und Angebote, auf die niemand geantwortet hat", "DELETE_GOES_LOGIN": "Deine Anmeldung, auf allen Geräten", "DELETE_WHAT_STAYS": "Bleibt erhalten, ohne deinen Namen", "DELETE_STAYS_CONTRACTS": "Abgeschlossene Verträge, Nachrichten und Bewertungen, damit die andere Seite sie weiterhin hat", "DELETE_STAYS_INVOICES": "Rechnungen, die nach norwegischen Buchführungsregeln 5 Jahre aufbewahrt werden müssen", "DELETE_PASSWORD_HINT": "Damit wir sicher sind, dass du es bist.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Dein Konto löschen?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Du wirst abgemeldet und kannst dich mit diesem Konto nicht mehr anmelden.", "DELETE_BLOCKED_CONTRACTS": "Du hast laufende Verträge. Schließe sie zuerst ab oder brich sie ab, damit die andere Seite nicht warten muss.", "DELETE_BLOCKED_COMPANY": "Dir gehört eine Firma mit weiteren Mitgliedern. Entferne sie zuerst unter Team.", "JOB_CATEGORY_REQUIRED": "Wähle eine Kategorie, damit die passenden Profis von dem Auftrag erfahren."}, "uk-UA": {"EDIT": "Змінити", "REMOVE": "Прибрати", "CLEAR": "Очистити", "ARCHIVE": "В архів", "NOTES": "Нотатки", "YOU": "ви", "DATE_PLACEHOLDER": "дд.мм.рррр", "DATE_INVALID": "Введіть дату у форматі дд.мм.рррр.", "AMOUNT_INVALID": "Введіть суму в NOK, напр. 5000.", "EMAIL_INVALID": "Схоже, адресу ел. пошти вказано неправильно.", "POSTCODE_FORMAT": "Поштовий індекс має 4 цифри.", "CLIENT": "Клієнт", "CLIENTS": "Клієнти", "CLIENTS_PRO_ONLY": "Власна база клієнтів доступна фахівцям. Увійдіть з обліковим записом фахівця, щоб нею користуватися.", "SEARCH_CLIENTS": "Пошук клієнтів", "CLIENTS_ACTIVE": "Активні", "CLIENTS_ARCHIVED": "В архіві", "NO_CLIENTS": "Клієнтів поки немає", "NO_CLIENTS_TEXT": "Додайте клієнтів, з якими ви працюєте поза платформою, і тримайте їхні замовлення, години та рахунки в одному місці.", "NO_CLIENTS_MATCH": "За вашим запитом клієнтів не знайдено.", "NO_ARCHIVED_CLIENTS": "Архів порожній", "NO_ARCHIVED_CLIENTS_TEXT": "Сюди потрапляють клієнти, яких ви перенесли в архів, разом з їхніми минулими замовленнями та рахунками.", "NEW_CLIENT": "Новий клієнт", "EDIT_CLIENT": "Змінити клієнта", "SAVE_CLIENT": "Зберегти клієнта", "CLIENT_FORM_INTRO": "Це бачите лише ви та ваша компанія. Адреса використовується як місце робіт у нових замовленнях.", "CLIENT_TYPE": "Тип клієнта", "CLIENT_PRIVATE": "Приватна особа", "CLIENT_BUSINESS": "Компанія", "CLIENT_COMPANY_PLACEHOLDER": "Напр. Bergen Eiendom AS", "CONTACT_PERSON": "Контактна особа", "CONTACT_NAME": "Контакт: {name}", "CLIENT_EMAIL_HINT": "Сюди можна надсилати рахунки.", "CLIENT_NOTES_PLACEHOLDER": "Код воріт, паркування, кличка собаки…", "CLIENT_NOTES_HINT": "Лише для вас і ваших колег, клієнт цього ніколи не побачить.", "CLIENT_NOT_FOUND": "Клієнта не знайдено", "CLIENT_IS_ARCHIVED": "В архіві", "CLIENT_NO_DETAILS": "Контактних даних поки немає. Натисніть «Змінити», щоб їх додати.", "CLIENT_JOBS": "Замовлення", "CLIENT_NO_JOBS": "У цього клієнта поки немає замовлень.", "ARCHIVE_CLIENT": "Перенести клієнта в архів", "ARCHIVE_CLIENT_TITLE": "Перенести клієнта в архів?", "ARCHIVE_CLIENT_TEXT": "У клієнта є замовлення, тому він збережеться разом із замовленнями та рахунками. Пізніше його можна відновити.", "RESTORE_CLIENT": "Відновити клієнта", "DELETE_CLIENT": "Видалити клієнта", "DELETE_CLIENT_TITLE": "Видалити цього клієнта?", "DELETE_CLIENT_TEXT": "{name} буде видалено з вашої бази клієнтів.", "NEW_ASSIGNMENT": "Нове завдання", "NEW_ASSIGNMENT_INTRO": "Оформіть роботу для свого клієнта й узгодьте ціну. Етапи, години та рахунки можна додати в договорі.", "PICK_CLIENT_INTRO": "Для кого ця робота?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Що узгоджено, матеріали, що варто знати клієнтові", "START_DATE": "Дата початку", "END_DATE": "Дата завершення", "END_BEFORE_START": "Дата завершення раніша за дату початку.", "STEPS_OPTIONAL_HINT": "Необов’язково. Без етапів уся робота вважається одним етапом.", "STEPS_SPLIT_HINT": "Кожен етап приймається окремо. Сума етапів має збігатися з ціною.", "STEPS_HOURLY_HINT": "Кожен етап приймається окремо. Години обліковуються в договорі.", "STEP_TITLE": "Етап", "STEP_TITLE_PLACEHOLDER": "Напр. Демонтаж і водовідведення", "STEP_TITLE_REQUIRED": "Дайте назву кожному етапу.", "STEP_AMOUNT": "Сума (NOK)", "STEP_AMOUNT_REQUIRED": "Вкажіть суму для кожного етапу.", "STEP_DUE": "Термін", "STEP_DESCRIPTION_PLACEHOLDER": "Що входить у цей етап", "STEPS_MUST_ADD_UP": "Сума етапів має становити {total}.", "STEPS_ADD_UP": "Сума етапів збігається з ціною ✓", "STEPS_REST": "Залишилося розподілити: {rest}", "STEPS_TOTAL_MISMATCH": "Сума етапів — {steps}, узгоджена ціна — {total}.", "REMOVE_STEP": "Прибрати етап", "ADD_STEP": "Додати етап", "ADD_STEP_INTRO": "Замовник приймає кожен етап, коли його завершено.", "EDIT_STEP": "Змінити етап", "DELETE_STEP": "Видалити етап", "DELETE_STEP_TITLE": "Видалити цей етап?", "DELETE_STEP_TEXT": "«{title}» буде видалено з договору.", "STEP_STARTED_NO_DELETE": "Цей етап уже розпочато, тому його можна змінити, але не можна видалити.", "CREATE_CONTRACT": "Створити договір", "JOB_HAS_CONTRACT": "Це замовлення вже має договір.", "JOB_NOT_YOURS": "Змінювати замовлення може лише той, хто його створив.", "JOB_CANNOT_EDIT": "Виконавця вже обрано, тому замовлення більше не можна змінити.", "EDIT_JOB": "Змінити замовлення", "EDIT_JOB_INTRO": "Фахівці одразу побачать зміни.", "EDIT_JOB_WITH_OFFERS": "Отримано пропозицій: {n}. Розкажіть фахівцям про великі зміни в чаті, щоб їхні пропозиції залишалися актуальними.", "CREATED_AGO": "Створено {time}", "DRAFT_NOT_VISIBLE": "Це чернетка. Фахівці не побачать її, доки ви її не опублікуєте.", "CANCEL_JOB": "Скасувати замовлення", "CANCEL_JOB_TITLE": "Скасувати це замовлення?", "CANCEL_JOB_TEXT": "Замовлення буде знято, і його не можна буде відкрити знову.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Замовлення буде знято, а фахівці, які надіслали пропозиції ({n}), дізнаються, що його скасовано.", "DELETE_JOB_TITLE": "Видалити чернетку?", "DELETE_JOB_TEXT": "Чернетку буде видалено назавжди.", "CANCEL_CONTRACT": "Розірвати договір", "CANCEL_CONTRACT_INTRO": "Робота на цьому зупиняється. Прийняті етапи та рахунки зберігаються, а інша сторона отримає сповіщення.", "CANCEL_REASON": "Чому? (необов’язково)", "CANCEL_REASON_PLACEHOLDER": "Кілька слів, які ви обоє зможете побачити пізніше", "CONTRACT_CANCELLED_ON": "Розірвано {date}", "COMPLETE_CLIENT_JOB_TEXT": "Усі етапи підписано. Замовлення буде позначено як завершене.", "SIGN_ON_SITE": "Підпис замовника", "SIGN_ON_SITE_INTRO": "Дайте замовнику перевірити роботу й розписатися пальцем на екрані. Так етап буде прийнято.", "CUSTOMER_NAME": "Ім’я замовника", "SIGNATURE": "Підпис", "SIGN_HERE": "Розпишіться тут", "APPROVE_WITH_SIGNATURE": "Прийняти з підписом", "CHANGE_PASSWORD": "Змінити пароль", "CHANGE_PASSWORD_INTRO": "Тут ви залишитеся в обліковому записі. На інших телефонах і в браузерах буде виконано вихід.", "CURRENT_PASSWORD": "Поточний пароль", "CURRENT_PASSWORD_REQUIRED": "Введіть поточний пароль.", "CURRENT_PASSWORD_WRONG": "Це не ваш поточний пароль.", "NEW_PASSWORD": "Новий пароль", "REPEAT_PASSWORD": "Повторіть новий пароль", "PASSWORDS_DONT_MATCH": "Паролі не збігаються.", "PASSWORD_SAME_AS_OLD": "Виберіть пароль, який ви тут ще не використовували.", "PASSWORD_CHANGED": "Пароль змінено", "PAYMENTS": "Платежі", "PAYMENT": "Платіж", "NO_PAYMENTS": "Платежів поки немає", "NO_PAYMENTS_TEXT": "Тут з’являються платежі через застосунок. Замовлення, оплачені за рахунком, знаходяться в розділі «Рахунки».", "PAYMENT_STATUS_PENDING": "Очікує", "PAYMENT_STATUS_HELD": "Надійно утримується", "PAYMENT_STATUS_RELEASED": "Виплачено", "PAYMENT_STATUS_REFUNDED": "Повернено", "PAYMENT_STATUS_FAILED": "Не вдалося", "PLATFORM_FEE": "Комісія {fee}", "TEAM": "Команда", "TEAM_ROW_HINT": "Люди, які працюють у компанії", "TEAM_MANAGE_HINT": "Спершу колегам потрібен обліковий запис Qup Work. Натисніть на людину, щоб змінити її роль або видалити.", "TEAM_WORKER_HINT": "Колег додають і видаляють власник та адміністратори.", "ADD_MEMBER": "Додати колегу", "ADD_MEMBER_INTRO": "Вкажіть ел. пошту, з якою колега зареєструвався в Qup Work.", "MEMBER_NOT_FOUND": "З цією ел. поштою ще ніхто не зареєструвався. Попросіть колегу спершу створити обліковий запис.", "MEMBER_ALREADY": "Ця людина вже в компанії.", "ROLE": "Роль", "ROLE_ADMIN_HINT": "Адміністратори можуть змінювати дані компанії та налаштування рахунків, а також додавати колег.", "ROLE_WORKER_HINT": "Працівники бачать замовлення компанії, обліковують години й виконують роботу.", "REMOVE_FROM_COMPANY": "Видалити з компанії", "REMOVE_MEMBER_TITLE": "Видалити з компанії?", "REMOVE_MEMBER_TEXT": "{name} більше не бачитиме замовлення та клієнтів компанії.", "LEAVE_COMPANY": "Залишити компанію", "LEAVE_COMPANY_TITLE": "Залишити компанію?", "LEAVE_COMPANY_TEXT": "Ви більше не бачитимете замовлення та клієнтів {name}.", "NOTIF_JOB_WITHDRAWN": "Замовник скасував замовлення", "INVOICE_EMAILED_TO": "{email} отримав рахунок у PDF.", "INVOICE_NO_EMAIL": "Надіслано, але не поштою: у клієнта немає адреси електронної пошти. Відкрийте PDF і поділіться ним самі або скористайтеся Надіслати поштою.", "INVOICE_EMAIL_NOT_SET_UP": "Надіслано, але не поштою: пошту ще не налаштовано на сервері (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Надіслано, але лист не пішов: {error}", "SEND_INVOICE_EMAIL_TO": "PDF буде надіслано поштою на {email}.", "SEND_INVOICE_NO_EMAIL": "Адреси електронної пошти немає, тож лист не надішлеться. Ви можете поділитися PDF самі.", "EMAIL_INVOICE": "Надіслати поштою", "PREVIEW_PDF": "Перегляд PDF", "OPEN_PDF": "Відкрити PDF", "EMAILED": "Надіслано поштою", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Не надіслано поштою", "INVOICE_LANGUAGE": "Мова рахунку", "NOTIF_NEW_JOB_NEARBY": "Нове замовлення поруч із вами", "NOTIF_NEW_JOB_REMOTE": "Нове віддалене замовлення", "NOTIF_JOB_INVITED": "Вас запросили на замовлення", "NOTIF_JOB_IN_PLACE": "«{job}» — {place}", "JOB_ALERTS": "Сповіщення про нові замовлення", "JOB_ALERTS_ON_TEXT": "Ви отримаєте сповіщення, коли у вашому районі з’явиться замовлення з ваших категорій.", "JOB_ALERTS_OFF_TEXT": "Сповіщень про нові замовлення не буде, але ви й далі бачитимете їх у застосунку.", "JOB_ALERTS_NEEDS_VISIBLE": "Спершу увімкніть видимість. Сповіщення отримують лише майстри, яких можуть знайти клієнти.", "FORGOT_PASSWORD": "Забули пароль?", "FORGOT_PASSWORD_TITLE": "Новий пароль", "FORGOT_PASSWORD_INTRO": "Введіть ел. пошту, яку ви вказали під час реєстрації, і ми надішлемо вам код.", "SEND_CODE": "Надіслати код", "RESET_CODE_SENT": "Якщо для {email} є обліковий запис, 6-значний код уже в дорозі. Введіть його нижче разом із новим паролем.", "RESET_CODE": "Код з листа", "RESET_CODE_INVALID": "Код складається з 6 цифр.", "RESET_CODE_WRONG": "Код неправильний або застарів. Попросіть новий.", "SAVE_NEW_PASSWORD": "Зберегти й увійти", "RESET_CODE_AGAIN": "Надіслати новий код", "RESET_CODE_RESENT": "Новий код надіслано", "RESET_CODE_SPAM_HINT": "Лист не прийшов за кілька хвилин? Перевірте папку «Спам».", "DELETE_ACCOUNT": "Видалити обліковий запис", "DELETE_ACCOUNT_INTRO": "Обліковий запис {email} буде видалено. Цю дію не можна скасувати.", "DELETE_WHAT_GOES": "Буде видалено", "DELETE_GOES_PROFILE": "Ваше ім’я, фото, телефон і ел. пошта", "DELETE_GOES_PRO": "Ваш профіль фахівця — клієнти більше не зможуть вас знайти", "DELETE_GOES_JOBS": "Відкриті замовлення, які ви опублікували, і пропозиції, на які ніхто не відповів", "DELETE_GOES_LOGIN": "Ваш вхід на всіх пристроях", "DELETE_WHAT_STAYS": "Збережеться, але без вашого імені", "DELETE_STAYS_CONTRACTS": "Завершені договори, повідомлення та відгуки — щоб вони залишилися в іншої сторони", "DELETE_STAYS_INVOICES": "Рахунки, які за норвезькими правилами бухгалтерського обліку треба зберігати 5 років", "DELETE_PASSWORD_HINT": "Щоб переконатися, що це ви.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Видалити обліковий запис?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Ви вийдете з облікового запису й більше не зможете в нього увійти.", "DELETE_BLOCKED_CONTRACTS": "У вас є поточні договори. Спершу завершіть або розірвіть їх, щоб іншій стороні не довелося чекати.", "DELETE_BLOCKED_COMPANY": "Ви власник компанії, у якій є інші учасники. Спершу видаліть їх у розділі «Команда».", "JOB_CATEGORY_REQUIRED": "Виберіть категорію, щоб про замовлення дізналися потрібні фахівці."}, "bs-BA": {"EDIT": "Uredi", "REMOVE": "Ukloni", "CLEAR": "Očisti", "ARCHIVE": "Arhiviraj", "NOTES": "Bilješke", "YOU": "ti", "DATE_PLACEHOLDER": "dd.mm.gggg", "DATE_INVALID": "Upiši datum kao dd.mm.gggg.", "AMOUNT_INVALID": "Upiši iznos u NOK, npr. 5000.", "EMAIL_INVALID": "Ta e-mail adresa ne izgleda ispravno.", "POSTCODE_FORMAT": "Poštanski broj ima 4 cifre.", "CLIENT": "Klijent", "CLIENTS": "Klijenti", "CLIENTS_PRO_ONLY": "Vlastiti registar klijenata je za majstore. Prijavi se s računom majstora da ga koristiš.", "SEARCH_CLIENTS": "Pretraži klijente", "CLIENTS_ACTIVE": "Aktivni", "CLIENTS_ARCHIVED": "Arhivirani", "NO_CLIENTS": "Još nema klijenata", "NO_CLIENTS_TEXT": "Dodaj klijente za koje radiš mimo platforme i drži poslove, sate i račune za njih na jednom mjestu.", "NO_CLIENTS_MATCH": "Nijedan klijent ne odgovara pretrazi.", "NO_ARCHIVED_CLIENTS": "Ništa nije arhivirano", "NO_ARCHIVED_CLIENTS_TEXT": "Klijenti koje arhiviraš završe ovdje, sa svojim starim poslovima i računima.", "NEW_CLIENT": "Novi klijent", "EDIT_CLIENT": "Uredi klijenta", "SAVE_CLIENT": "Sačuvaj klijenta", "CLIENT_FORM_INTRO": "Ovo vidiš samo ti i tvoja firma. Adresa se koristi kao mjesto rada na novim poslovima.", "CLIENT_TYPE": "Vrsta klijenta", "CLIENT_PRIVATE": "Fizičko lice", "CLIENT_BUSINESS": "Firma", "CLIENT_COMPANY_PLACEHOLDER": "Npr. Bergen Eiendom AS", "CONTACT_PERSON": "Kontakt osoba", "CONTACT_NAME": "Kontakt: {name}", "CLIENT_EMAIL_HINT": "Računi se mogu slati ovdje.", "CLIENT_NOTES_PLACEHOLDER": "Kod kapije, parking, kako se zove pas…", "CLIENT_NOTES_HINT": "Samo za tebe i tvoje kolege, klijent to nikad ne vidi.", "CLIENT_NOT_FOUND": "Klijent nije pronađen", "CLIENT_IS_ARCHIVED": "Arhiviran", "CLIENT_NO_DETAILS": "Još nema kontakt podataka. Dodirni Uredi da ih dodaš.", "CLIENT_JOBS": "Poslovi", "CLIENT_NO_JOBS": "Još nema poslova za ovog klijenta.", "ARCHIVE_CLIENT": "Arhiviraj klijenta", "ARCHIVE_CLIENT_TITLE": "Arhivirati ovog klijenta?", "ARCHIVE_CLIENT_TEXT": "Klijent ima poslove, pa se čuva zajedno s poslovima i računima. Kasnije ga možeš vratiti.", "RESTORE_CLIENT": "Vrati klijenta", "DELETE_CLIENT": "Izbriši klijenta", "DELETE_CLIENT_TITLE": "Izbrisati ovog klijenta?", "DELETE_CLIENT_TEXT": "{name} se uklanja iz tvog registra.", "NEW_ASSIGNMENT": "Novi posao", "NEW_ASSIGNMENT_INTRO": "Unesi posao za svog klijenta i dogovori cijenu. U ugovoru možeš dodati korake, upisivati sate i izdati račun.", "PICK_CLIENT_INTRO": "Za koga je posao?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Šta je dogovoreno, materijal, sve što klijent treba znati", "START_DATE": "Datum početka", "END_DATE": "Datum završetka", "END_BEFORE_START": "Datum završetka je prije datuma početka.", "STEPS_OPTIONAL_HINT": "Neobavezno. Bez koraka je cijeli posao jedan korak.", "STEPS_SPLIT_HINT": "Svaki korak se odobrava zasebno. Iznosi moraju zajedno dati cijenu.", "STEPS_HOURLY_HINT": "Svaki korak se odobrava zasebno. Sati se upisuju na ugovor.", "STEP_TITLE": "Korak", "STEP_TITLE_PLACEHOLDER": "Npr. Rušenje i odvod", "STEP_TITLE_REQUIRED": "Daj svakom koraku naziv.", "STEP_AMOUNT": "Iznos (NOK)", "STEP_AMOUNT_REQUIRED": "Upiši iznos za svaki korak.", "STEP_DUE": "Rok", "STEP_DESCRIPTION_PLACEHOLDER": "Šta je uključeno u ovaj korak", "STEPS_MUST_ADD_UP": "Koraci zajedno moraju dati {total}.", "STEPS_ADD_UP": "Koraci zajedno daju cijenu ✓", "STEPS_REST": "Preostalo za raspodjelu: {rest}", "STEPS_TOTAL_MISMATCH": "Koraci zajedno daju {steps}, a dogovorena cijena je {total}.", "REMOVE_STEP": "Ukloni korak", "ADD_STEP": "Dodaj korak", "ADD_STEP_INTRO": "Klijent odobrava svaki korak kad je gotov.", "EDIT_STEP": "Uredi korak", "DELETE_STEP": "Izbriši korak", "DELETE_STEP_TITLE": "Izbrisati ovaj korak?", "DELETE_STEP_TEXT": "„{title}” se uklanja iz ugovora.", "STEP_STARTED_NO_DELETE": "Ovaj korak je započet, pa se može mijenjati, ali ne i izbrisati.", "CREATE_CONTRACT": "Napravi ugovor", "JOB_HAS_CONTRACT": "Ovaj posao već ima ugovor.", "JOB_NOT_YOURS": "Samo onaj ko je objavio posao može ga mijenjati.", "JOB_CANNOT_EDIT": "Neko je već angažovan, pa se posao više ne može mijenjati.", "EDIT_JOB": "Uredi posao", "EDIT_JOB_INTRO": "Majstori odmah vide izmjene.", "EDIT_JOB_WITH_OFFERS": "Primljene ponude: {n}. O većim izmjenama obavijesti majstore u chatu, da im ponude i dalje odgovaraju.", "CREATED_AGO": "Napravljeno {time}", "DRAFT_NOT_VISIBLE": "Ovo je nacrt. Majstori ga ne vide dok ga ne objaviš.", "CANCEL_JOB": "Otkaži posao", "CANCEL_JOB_TITLE": "Otkazati ovaj posao?", "CANCEL_JOB_TEXT": "Posao se uklanja i ne može se ponovo otvoriti.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Posao se uklanja, a majstori koji su poslali ponude ({n}) dobijaju obavještenje da je otkazan.", "DELETE_JOB_TITLE": "Izbrisati nacrt?", "DELETE_JOB_TEXT": "Nacrt se trajno briše.", "CANCEL_CONTRACT": "Otkaži ugovor", "CANCEL_CONTRACT_INTRO": "Rad se ovdje zaustavlja. Odobreni koraci i računi ostaju, a druga strana dobija obavještenje.", "CANCEL_REASON": "Zašto? (neobavezno)", "CANCEL_REASON_PLACEHOLDER": "Par riječi koje oboje možete vidjeti kasnije", "CONTRACT_CANCELLED_ON": "Otkazano {date}", "COMPLETE_CLIENT_JOB_TEXT": "Svi koraci su potpisani. Posao se označava kao završen.", "SIGN_ON_SITE": "Klijent potpisuje", "SIGN_ON_SITE_INTRO": "Neka klijent pregleda rad i potpiše se prstom na ekranu. Time se korak odobrava.", "CUSTOMER_NAME": "Ime klijenta", "SIGNATURE": "Potpis", "SIGN_HERE": "Potpiši ovdje", "APPROVE_WITH_SIGNATURE": "Odobri potpisom", "CHANGE_PASSWORD": "Promijeni lozinku", "CHANGE_PASSWORD_INTRO": "Ovdje ostaješ prijavljen. Na ostalim telefonima i preglednicima bićeš odjavljen.", "CURRENT_PASSWORD": "Trenutna lozinka", "CURRENT_PASSWORD_REQUIRED": "Unesi trenutnu lozinku.", "CURRENT_PASSWORD_WRONG": "To nije tvoja trenutna lozinka.", "NEW_PASSWORD": "Nova lozinka", "REPEAT_PASSWORD": "Ponovi novu lozinku", "PASSWORDS_DONT_MATCH": "Lozinke se ne podudaraju.", "PASSWORD_SAME_AS_OLD": "Izaberi lozinku koju ovdje još nisi koristio.", "PASSWORD_CHANGED": "Lozinka promijenjena", "PAYMENTS": "Plaćanja", "PAYMENT": "Plaćanje", "NO_PAYMENTS": "Još nema plaćanja", "NO_PAYMENTS_TEXT": "Ovdje se prikazuju plaćanja kroz aplikaciju. Poslovi plaćeni računom nalaze se pod Računi.", "PAYMENT_STATUS_PENDING": "Na čekanju", "PAYMENT_STATUS_HELD": "Sigurno čuvano", "PAYMENT_STATUS_RELEASED": "Isplaćeno", "PAYMENT_STATUS_REFUNDED": "Vraćeno", "PAYMENT_STATUS_FAILED": "Neuspjelo", "PLATFORM_FEE": "Naknada {fee}", "TEAM": "Tim", "TEAM_ROW_HINT": "Ljudi koji rade u firmi", "TEAM_MANAGE_HINT": "Kolege prvo trebaju Qup Work račun. Dodirni nekoga da ga promijeniš ili ukloniš.", "TEAM_WORKER_HINT": "Vlasnik i administratori dodaju i uklanjaju kolege.", "ADD_MEMBER": "Dodaj kolegu", "ADD_MEMBER_INTRO": "Koristi e-mail s kojim se ta osoba registrovala na Qup Work.", "MEMBER_NOT_FOUND": "Niko se još nije registrovao s tim e-mailom. Zamoli tu osobu da prvo napravi račun.", "MEMBER_ALREADY": "Ta osoba je već u firmi.", "ROLE": "Uloga", "ROLE_ADMIN_HINT": "Administratori mogu mijenjati podatke firme i postavke računa te dodavati kolege.", "ROLE_WORKER_HINT": "Zaposlenici vide poslove firme, upisuju sate i rade posao.", "REMOVE_FROM_COMPANY": "Ukloni iz firme", "REMOVE_MEMBER_TITLE": "Ukloniti iz firme?", "REMOVE_MEMBER_TEXT": "{name} više ne vidi poslove i klijente firme.", "LEAVE_COMPANY": "Napusti firmu", "LEAVE_COMPANY_TITLE": "Napustiti firmu?", "LEAVE_COMPANY_TEXT": "Više ne vidiš poslove i klijente firme {name}.", "NOTIF_JOB_WITHDRAWN": "Klijent je otkazao posao", "INVOICE_EMAILED_TO": "{email} je primio račun kao PDF.", "INVOICE_NO_EMAIL": "Poslano, ali ne e-mailom: kupac nema e-mail adresu. Otvori PDF i podijeli ga sam ili koristi Pošalji e-mailom.", "INVOICE_EMAIL_NOT_SET_UP": "Poslano, ali ne e-mailom: e-mail još nije podešen na serveru (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Poslano, ali e-mail nije uspio: {error}", "SEND_INVOICE_EMAIL_TO": "PDF se šalje e-mailom na {email}.", "SEND_INVOICE_NO_EMAIL": "Nema e-mail adrese, pa se neće poslati e-mailom. PDF možeš podijeliti sam.", "EMAIL_INVOICE": "Pošalji e-mailom", "PREVIEW_PDF": "Pregled PDF-a", "OPEN_PDF": "Otvori PDF", "EMAILED": "Poslano e-mailom", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Nije poslano e-mailom", "INVOICE_LANGUAGE": "Jezik računa", "NOTIF_NEW_JOB_NEARBY": "Novi posao u tvojoj blizini", "NOTIF_NEW_JOB_REMOTE": "Novi posao na daljinu", "NOTIF_JOB_INVITED": "Pozvan si na posao", "NOTIF_JOB_IN_PLACE": "„{job}” – {place}", "JOB_ALERTS": "Obavještenja o novim poslovima", "JOB_ALERTS_ON_TEXT": "Dobiješ obavještenje kad se u tvom području objavi posao iz tvojih kategorija.", "JOB_ALERTS_OFF_TEXT": "Nećeš dobijati obavještenja o novim poslovima, ali ih i dalje vidiš u aplikaciji.", "JOB_ALERTS_NEEDS_VISIBLE": "Prvo uključi vidljivost. Obavještenja dobijaju samo majstori koje kupci mogu pronaći.", "FORGOT_PASSWORD": "Zaboravljena lozinka?", "FORGOT_PASSWORD_TITLE": "Nova lozinka", "FORGOT_PASSWORD_INTRO": "Unesi e-mail adresu s kojom si se registrovao i poslat ćemo ti kod.", "SEND_CODE": "Pošalji kod", "RESET_CODE_SENT": "Ako {email} ima račun, 6-cifreni kod je na putu. Unesi ga ispod zajedno s novom lozinkom.", "RESET_CODE": "Kod iz e-maila", "RESET_CODE_INVALID": "Kod ima 6 cifara.", "RESET_CODE_WRONG": "Kod je pogrešan ili je istekao. Zatraži novi.", "SAVE_NEW_PASSWORD": "Sačuvaj i prijavi se", "RESET_CODE_AGAIN": "Pošalji novi kod", "RESET_CODE_RESENT": "Novi kod je poslan", "RESET_CODE_SPAM_HINT": "Nema e-maila ni nakon nekoliko minuta? Provjeri folder za neželjenu poštu.", "DELETE_ACCOUNT": "Izbriši račun", "DELETE_ACCOUNT_INTRO": "Ovim se briše račun za {email}. To se ne može poništiti.", "DELETE_WHAT_GOES": "Briše se", "DELETE_GOES_PROFILE": "Tvoje ime, fotografija, telefon i e-mail", "DELETE_GOES_PRO": "Tvoj profil majstora, pa te klijenti više ne mogu pronaći", "DELETE_GOES_JOBS": "Otvoreni poslovi koje si objavio i ponude na koje niko nije odgovorio", "DELETE_GOES_LOGIN": "Tvoja prijava, na svim uređajima", "DELETE_WHAT_STAYS": "Ostaje, bez tvog imena", "DELETE_STAYS_CONTRACTS": "Završeni ugovori, poruke i recenzije, da ih druga strana i dalje ima", "DELETE_STAYS_INVOICES": "Računi, koje norveški propisi o knjigovodstvu nalažu čuvati 5 godina", "DELETE_PASSWORD_HINT": "Da budemo sigurni da si to ti.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Izbrisati račun?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Bićeš odjavljen i više se nećeš moći prijaviti ovim računom.", "DELETE_BLOCKED_CONTRACTS": "Imaš ugovore u toku. Prvo ih završi ili otkaži, da druga strana ne bi čekala.", "DELETE_BLOCKED_COMPANY": "Vlasnik si firme s drugim članovima. Prvo ih ukloni u odjeljku Tim.", "JOB_CATEGORY_REQUIRED": "Odaberi kategoriju, da pravi majstori saznaju za posao."}, "lv-LV": {"EDIT": "Rediģēt", "REMOVE": "Noņemt", "CLEAR": "Notīrīt", "ARCHIVE": "Arhivēt", "NOTES": "Piezīmes", "YOU": "tu", "DATE_PLACEHOLDER": "dd.mm.gggg", "DATE_INVALID": "Ieraksti datumu formātā dd.mm.gggg.", "AMOUNT_INVALID": "Ieraksti summu NOK, piem., 5000.", "EMAIL_INVALID": "Šī e-pasta adrese neizskatās pareiza.", "POSTCODE_FORMAT": "Pasta indeksā ir 4 cipari.", "CLIENT": "Klients", "CLIENTS": "Klienti", "CLIENTS_PRO_ONLY": "Klientu reģistrs ir paredzēts meistariem. Lai to izmantotu, piesakies ar meistara kontu.", "SEARCH_CLIENTS": "Meklēt klientus", "CLIENTS_ACTIVE": "Aktīvie", "CLIENTS_ARCHIVED": "Arhivētie", "NO_CLIENTS": "Vēl nav klientu", "NO_CLIENTS_TEXT": "Pievieno klientus, kuriem strādā ārpus platformas, un glabā viņu darbus, stundas un rēķinus vienuviet.", "NO_CLIENTS_MATCH": "Meklējumam neatbilst neviens klients.", "NO_ARCHIVED_CLIENTS": "Arhīvs ir tukšs", "NO_ARCHIVED_CLIENTS_TEXT": "Šeit nonāk arhivētie klienti kopā ar saviem vecajiem darbiem un rēķiniem.", "NEW_CLIENT": "Jauns klients", "EDIT_CLIENT": "Rediģēt klientu", "SAVE_CLIENT": "Saglabāt klientu", "CLIENT_FORM_INTRO": "To redzi tikai tu un tavs uzņēmums. Adrese tiek izmantota kā darba adrese jaunos darbos.", "CLIENT_TYPE": "Klienta veids", "CLIENT_PRIVATE": "Privātpersona", "CLIENT_BUSINESS": "Uzņēmums", "CLIENT_COMPANY_PLACEHOLDER": "Piem., Bergen Eiendom AS", "CONTACT_PERSON": "Kontaktpersona", "CONTACT_NAME": "Kontaktpersona: {name}", "CLIENT_EMAIL_HINT": "Šeit var sūtīt rēķinus.", "CLIENT_NOTES_PLACEHOLDER": "Vārtu kods, stāvvieta, suņa vārds…", "CLIENT_NOTES_HINT": "Tikai tev un taviem kolēģiem, klientam nekad netiek rādīts.", "CLIENT_NOT_FOUND": "Klients nav atrasts", "CLIENT_IS_ARCHIVED": "Arhivēts", "CLIENT_NO_DETAILS": "Vēl nav kontaktinformācijas. Pieskaries Rediģēt, lai to pievienotu.", "CLIENT_JOBS": "Darbi", "CLIENT_NO_JOBS": "Šim klientam vēl nav darbu.", "ARCHIVE_CLIENT": "Arhivēt klientu", "ARCHIVE_CLIENT_TITLE": "Arhivēt šo klientu?", "ARCHIVE_CLIENT_TEXT": "Klientam ir darbi, tāpēc tas tiek saglabāts kopā ar darbiem un rēķiniem. Vēlāk to vari atjaunot.", "RESTORE_CLIENT": "Atjaunot klientu", "DELETE_CLIENT": "Dzēst klientu", "DELETE_CLIENT_TITLE": "Dzēst šo klientu?", "DELETE_CLIENT_TEXT": "{name} tiek noņemts no tava reģistra.", "NEW_ASSIGNMENT": "Jauns pasūtījums", "NEW_ASSIGNMENT_INTRO": "Reģistrē darbu savam klientam un vienojies par cenu. No līguma vari pievienot posmus, uzskaitīt stundas un izrakstīt rēķinus.", "PICK_CLIENT_INTRO": "Kam ir paredzēts darbs?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Par ko norunāts, materiāli, viss, kas klientam jāzina", "START_DATE": "Sākuma datums", "END_DATE": "Beigu datums", "END_BEFORE_START": "Beigu datums ir pirms sākuma datuma.", "STEPS_OPTIONAL_HINT": "Nav obligāti. Bez posmiem viss darbs ir viens posms.", "STEPS_SPLIT_HINT": "Katrs posms tiek apstiprināts atsevišķi. Summām kopā jāsakrīt ar cenu.", "STEPS_HOURLY_HINT": "Katrs posms tiek apstiprināts atsevišķi. Stundas tiek uzskaitītas līgumā.", "STEP_TITLE": "Posms", "STEP_TITLE_PLACEHOLDER": "Piem., Demontāža un drenāža", "STEP_TITLE_REQUIRED": "Piešķir nosaukumu katram posmam.", "STEP_AMOUNT": "Summa (NOK)", "STEP_AMOUNT_REQUIRED": "Norādi summu katram posmam.", "STEP_DUE": "Termiņš", "STEP_DESCRIPTION_PLACEHOLDER": "Kas ietilpst šajā posmā", "STEPS_MUST_ADD_UP": "Posmiem kopā jābūt {total}.", "STEPS_ADD_UP": "Posmi kopā sakrīt ar cenu ✓", "STEPS_REST": "Vēl jāsadala: {rest}", "STEPS_TOTAL_MISMATCH": "Posmi kopā ir {steps}, bet norunātā cena ir {total}.", "REMOVE_STEP": "Noņemt posmu", "ADD_STEP": "Pievienot posmu", "ADD_STEP_INTRO": "Klients apstiprina katru posmu, kad tas ir pabeigts.", "EDIT_STEP": "Rediģēt posmu", "DELETE_STEP": "Dzēst posmu", "DELETE_STEP_TITLE": "Dzēst šo posmu?", "DELETE_STEP_TEXT": "“{title}” tiek noņemts no līguma.", "STEP_STARTED_NO_DELETE": "Šis posms jau ir sākts, tāpēc to var mainīt, bet ne dzēst.", "CREATE_CONTRACT": "Izveidot līgumu", "JOB_HAS_CONTRACT": "Šim darbam jau ir līgums.", "JOB_NOT_YOURS": "Darbu var mainīt tikai tas, kurš to izveidoja.", "JOB_CANNOT_EDIT": "Kāds jau ir nolīgts, tāpēc darbu vairs nevar mainīt.", "EDIT_JOB": "Rediģēt darbu", "EDIT_JOB_INTRO": "Meistari izmaiņas redz uzreiz.", "EDIT_JOB_WITH_OFFERS": "Saņemti piedāvājumi: {n}. Par lielām izmaiņām pastāsti meistariem čatā, lai viņu piedāvājumi joprojām atbilstu.", "CREATED_AGO": "Izveidots {time}", "DRAFT_NOT_VISIBLE": "Šis ir melnraksts. Meistari to neredz, kamēr tu to nepublicē.", "CANCEL_JOB": "Atcelt darbu", "CANCEL_JOB_TITLE": "Atcelt šo darbu?", "CANCEL_JOB_TEXT": "Darbs tiek noņemts, un to vairs nevar atvērt no jauna.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Darbs tiek noņemts, un meistari, kuri nosūtīja piedāvājumus ({n}), saņem ziņu, ka tas ir atcelts.", "DELETE_JOB_TITLE": "Dzēst melnrakstu?", "DELETE_JOB_TEXT": "Melnraksts tiek dzēsts neatgriezeniski.", "CANCEL_CONTRACT": "Atcelt līgumu", "CANCEL_CONTRACT_INTRO": "Darbs šeit apstājas. Apstiprinātie posmi un rēķini paliek, un otra puse saņem paziņojumu.", "CANCEL_REASON": "Kāpēc? (nav obligāti)", "CANCEL_REASON_PLACEHOLDER": "Daži vārdi, ko vēlāk redzēsiet abi", "CONTRACT_CANCELLED_ON": "Atcelts {date}", "COMPLETE_CLIENT_JOB_TEXT": "Visi posmi ir parakstīti. Darbs tiek atzīmēts kā pabeigts.", "SIGN_ON_SITE": "Klienta paraksts", "SIGN_ON_SITE_INTRO": "Ļauj klientam pārbaudīt darbu un parakstīties ar pirkstu uz ekrāna. Tā posms tiek apstiprināts.", "CUSTOMER_NAME": "Klienta vārds", "SIGNATURE": "Paraksts", "SIGN_HERE": "Parakstieties šeit", "APPROVE_WITH_SIGNATURE": "Apstiprināt ar parakstu", "CHANGE_PASSWORD": "Mainīt paroli", "CHANGE_PASSWORD_INTRO": "Šeit tu paliec pieteicies. Citos telefonos un pārlūkos tu tiksi izrakstīts.", "CURRENT_PASSWORD": "Pašreizējā parole", "CURRENT_PASSWORD_REQUIRED": "Ievadi pašreizējo paroli.", "CURRENT_PASSWORD_WRONG": "Tā nav tava pašreizējā parole.", "NEW_PASSWORD": "Jaunā parole", "REPEAT_PASSWORD": "Atkārto jauno paroli", "PASSWORDS_DONT_MATCH": "Paroles nesakrīt.", "PASSWORD_SAME_AS_OLD": "Izvēlies paroli, ko šeit vēl neesi izmantojis.", "PASSWORD_CHANGED": "Parole nomainīta", "PAYMENTS": "Maksājumi", "PAYMENT": "Maksājums", "NO_PAYMENTS": "Vēl nav maksājumu", "NO_PAYMENTS_TEXT": "Šeit parādās maksājumi, kas veikti lietotnē. Darbi, kas apmaksāti ar rēķinu, ir sadaļā Rēķini.", "PAYMENT_STATUS_PENDING": "Gaida", "PAYMENT_STATUS_HELD": "Droši glabājas", "PAYMENT_STATUS_RELEASED": "Izmaksāts", "PAYMENT_STATUS_REFUNDED": "Atmaksāts", "PAYMENT_STATUS_FAILED": "Neizdevās", "PLATFORM_FEE": "Komisija {fee}", "TEAM": "Komanda", "TEAM_ROW_HINT": "Cilvēki, kas strādā uzņēmumā", "TEAM_MANAGE_HINT": "Kolēģiem vispirms vajag Qup Work kontu. Pieskaries kādam, lai to mainītu vai noņemtu.", "TEAM_WORKER_HINT": "Kolēģus pievieno un noņem īpašnieks un administratori.", "ADD_MEMBER": "Pievienot kolēģi", "ADD_MEMBER_INTRO": "Izmanto e-pastu, ar kuru kolēģis reģistrējās Qup Work.", "MEMBER_NOT_FOUND": "Ar šo e-pastu vēl neviens nav reģistrējies. Palūdz vispirms izveidot kontu.", "MEMBER_ALREADY": "Šī persona jau ir uzņēmumā.", "ROLE": "Loma", "ROLE_ADMIN_HINT": "Administratori var mainīt uzņēmuma datus un rēķinu iestatījumus, kā arī pievienot kolēģus.", "ROLE_WORKER_HINT": "Darbinieki redz uzņēmuma darbus, uzskaita stundas un veic darbu.", "REMOVE_FROM_COMPANY": "Noņemt no uzņēmuma", "REMOVE_MEMBER_TITLE": "Noņemt no uzņēmuma?", "REMOVE_MEMBER_TEXT": "{name} vairs neredz uzņēmuma darbus un klientus.", "LEAVE_COMPANY": "Pamest uzņēmumu", "LEAVE_COMPANY_TITLE": "Pamest uzņēmumu?", "LEAVE_COMPANY_TEXT": "Tu vairs neredzēsi uzņēmuma {name} darbus un klientus.", "NOTIF_JOB_WITHDRAWN": "Klients atcēla darbu", "INVOICE_EMAILED_TO": "{email} saņēma rēķinu PDF formātā.", "INVOICE_NO_EMAIL": "Nosūtīts, bet ne e-pastā: klientam nav e-pasta adreses. Atver PDF un kopīgo to pats vai izmanto Sūtīt e-pastā.", "INVOICE_EMAIL_NOT_SET_UP": "Nosūtīts, bet ne e-pastā: e-pasts serverī vēl nav iestatīts (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Nosūtīts, bet e-pasts neizdevās: {error}", "SEND_INVOICE_EMAIL_TO": "PDF tiek nosūtīts e-pastā uz {email}.", "SEND_INVOICE_NO_EMAIL": "Nav e-pasta adreses, tāpēc e-pastā netiks sūtīts. PDF vari kopīgot pats.", "EMAIL_INVOICE": "Sūtīt e-pastā", "PREVIEW_PDF": "PDF priekšskatījums", "OPEN_PDF": "Atvērt PDF", "EMAILED": "Nosūtīts e-pastā", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Nav nosūtīts e-pastā", "INVOICE_LANGUAGE": "Rēķina valoda", "NOTIF_NEW_JOB_NEARBY": "Jauns darbs tavā tuvumā", "NOTIF_NEW_JOB_REMOTE": "Jauns attālinātais darbs", "NOTIF_JOB_INVITED": "Tevi uzaicināja uz darbu", "NOTIF_JOB_IN_PLACE": "“{job}” – {place}", "JOB_ALERTS": "Paziņojumi par jauniem darbiem", "JOB_ALERTS_ON_TEXT": "Tu saņem paziņojumu, kad tavā apkārtnē publicē darbu tavās kategorijās.", "JOB_ALERTS_OFF_TEXT": "Tu nesaņemsi paziņojumus par jauniem darbiem, bet joprojām redzēsi tos lietotnē.", "JOB_ALERTS_NEEDS_VISIBLE": "Vispirms ieslēdz redzamību. Paziņojumus saņem tikai meistari, kurus klienti var atrast.", "FORGOT_PASSWORD": "Aizmirsi paroli?", "FORGOT_PASSWORD_TITLE": "Jaunā parole", "FORGOT_PASSWORD_INTRO": "Ievadi e-pastu, ar kuru reģistrējies, un mēs tev nosūtīsim kodu.", "SEND_CODE": "Sūtīt kodu", "RESET_CODE_SENT": "Ja {email} ir konts, 6 ciparu kods jau ir ceļā. Ievadi to zemāk kopā ar jauno paroli.", "RESET_CODE": "Kods no e-pasta", "RESET_CODE_INVALID": "Kodā ir 6 cipari.", "RESET_CODE_WRONG": "Kods ir nepareizs vai tam beidzies derīgums. Palūdz jaunu.", "SAVE_NEW_PASSWORD": "Saglabāt un pieteikties", "RESET_CODE_AGAIN": "Sūtīt jaunu kodu", "RESET_CODE_RESENT": "Jauns kods nosūtīts", "RESET_CODE_SPAM_HINT": "Pēc dažām minūtēm e-pasts nav pienācis? Pārbaudi surogātpasta mapi.", "DELETE_ACCOUNT": "Dzēst kontu", "DELETE_ACCOUNT_INTRO": "Tiks dzēsts {email} konts. To nevar atsaukt.", "DELETE_WHAT_GOES": "Tiks dzēsts", "DELETE_GOES_PROFILE": "Tavs vārds, foto, tālrunis un e-pasts", "DELETE_GOES_PRO": "Tavs meistara profils, lai klienti tevi vairs nevarētu atrast", "DELETE_GOES_JOBS": "Tevis publicētie atvērtie darbi un piedāvājumi, uz kuriem neviens nav atbildējis", "DELETE_GOES_LOGIN": "Tava pieteikšanās visās ierīcēs", "DELETE_WHAT_STAYS": "Tiks saglabāts, bez tava vārda", "DELETE_STAYS_CONTRACTS": "Pabeigtie līgumi, ziņas un atsauksmes, lai otrai pusei tie joprojām būtu pieejami", "DELETE_STAYS_INVOICES": "Rēķini, kas saskaņā ar Norvēģijas grāmatvedības noteikumiem jāglabā 5 gadus", "DELETE_PASSWORD_HINT": "Lai pārliecinātos, ka tas esi tu.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Dzēst kontu?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Tu tiksi izrakstīts un ar šo kontu vairs nevarēsi pieteikties.", "DELETE_BLOCKED_CONTRACTS": "Tev ir aktīvi līgumi. Vispirms pabeidz vai atcel tos, lai otrai pusei nebūtu jāgaida.", "DELETE_BLOCKED_COMPANY": "Tev pieder uzņēmums ar citiem dalībniekiem. Vispirms noņem viņus sadaļā Komanda.", "JOB_CATEGORY_REQUIRED": "Izvēlies kategoriju, lai par darbu uzzinātu piemērotie meistari."}, "es-ES": {"EDIT": "Editar", "REMOVE": "Quitar", "CLEAR": "Borrar", "ARCHIVE": "Archivar", "NOTES": "Notas", "YOU": "tú", "DATE_PLACEHOLDER": "dd/mm/aaaa", "DATE_INVALID": "Escribe la fecha como dd/mm/aaaa.", "AMOUNT_INVALID": "Escribe un importe en NOK, p. ej. 5000.", "EMAIL_INVALID": "Esa dirección de correo no parece correcta.", "POSTCODE_FORMAT": "El código postal tiene 4 cifras.", "CLIENT": "Cliente", "CLIENTS": "Clientes", "CLIENTS_PRO_ONLY": "Tu propio registro de clientes es para profesionales. Inicia sesión con una cuenta profesional para usarlo.", "SEARCH_CLIENTS": "Buscar clientes", "CLIENTS_ACTIVE": "Activos", "CLIENTS_ARCHIVED": "Archivados", "NO_CLIENTS": "Aún no tienes clientes", "NO_CLIENTS_TEXT": "Añade los clientes para los que trabajas fuera de la plataforma y guarda sus trabajos, horas y facturas en un solo lugar.", "NO_CLIENTS_MATCH": "Ningún cliente coincide con tu búsqueda.", "NO_ARCHIVED_CLIENTS": "Nada archivado", "NO_ARCHIVED_CLIENTS_TEXT": "Los clientes que archives aparecen aquí, con sus trabajos y facturas anteriores.", "NEW_CLIENT": "Nuevo cliente", "EDIT_CLIENT": "Editar cliente", "SAVE_CLIENT": "Guardar cliente", "CLIENT_FORM_INTRO": "Solo tú y tu empresa podéis ver esto. La dirección se usa como dirección de trabajo en los trabajos nuevos.", "CLIENT_TYPE": "Tipo de cliente", "CLIENT_PRIVATE": "Particular", "CLIENT_BUSINESS": "Empresa", "CLIENT_COMPANY_PLACEHOLDER": "P. ej. Bergen Eiendom AS", "CONTACT_PERSON": "Persona de contacto", "CONTACT_NAME": "Contacto: {name}", "CLIENT_EMAIL_HINT": "Las facturas se pueden enviar aquí.", "CLIENT_NOTES_PLACEHOLDER": "Código del portal, aparcamiento, el nombre del perro…", "CLIENT_NOTES_HINT": "Solo para ti y tus compañeros, nunca se muestra al cliente.", "CLIENT_NOT_FOUND": "Cliente no encontrado", "CLIENT_IS_ARCHIVED": "Archivado", "CLIENT_NO_DETAILS": "Aún no hay datos de contacto. Toca Editar para añadirlos.", "CLIENT_JOBS": "Trabajos", "CLIENT_NO_JOBS": "Aún no hay trabajos para este cliente.", "ARCHIVE_CLIENT": "Archivar cliente", "ARCHIVE_CLIENT_TITLE": "¿Archivar este cliente?", "ARCHIVE_CLIENT_TEXT": "El cliente tiene trabajos, así que se conserva junto con sus trabajos y facturas. Puedes restaurarlo más adelante.", "RESTORE_CLIENT": "Restaurar cliente", "DELETE_CLIENT": "Eliminar cliente", "DELETE_CLIENT_TITLE": "¿Eliminar este cliente?", "DELETE_CLIENT_TEXT": "{name} se elimina de tu registro.", "NEW_ASSIGNMENT": "Nuevo encargo", "NEW_ASSIGNMENT_INTRO": "Registra un trabajo para tu propio cliente y acordad el precio. Desde el contrato puedes añadir pasos, registrar horas y facturar.", "PICK_CLIENT_INTRO": "¿Para quién es el trabajo?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Lo acordado, materiales, todo lo que el cliente deba saber", "START_DATE": "Fecha de inicio", "END_DATE": "Fecha de fin", "END_BEFORE_START": "La fecha de fin es anterior a la de inicio.", "STEPS_OPTIONAL_HINT": "Opcional. Sin pasos, todo el trabajo es un solo paso.", "STEPS_SPLIT_HINT": "Cada paso se aprueba por separado. Los importes deben sumar el precio.", "STEPS_HOURLY_HINT": "Cada paso se aprueba por separado. Las horas se registran en el contrato.", "STEP_TITLE": "Paso", "STEP_TITLE_PLACEHOLDER": "P. ej. Demolición y desagüe", "STEP_TITLE_REQUIRED": "Ponle un nombre a cada paso.", "STEP_AMOUNT": "Importe (NOK)", "STEP_AMOUNT_REQUIRED": "Ponle un importe a cada paso.", "STEP_DUE": "Fecha límite", "STEP_DESCRIPTION_PLACEHOLDER": "Qué incluye este paso", "STEPS_MUST_ADD_UP": "Los pasos deben sumar {total}.", "STEPS_ADD_UP": "Los pasos suman el precio ✓", "STEPS_REST": "Queda por repartir: {rest}", "STEPS_TOTAL_MISMATCH": "Los pasos suman {steps} y el precio acordado es {total}.", "REMOVE_STEP": "Quitar paso", "ADD_STEP": "Añadir paso", "ADD_STEP_INTRO": "El cliente aprueba cada paso cuando está hecho.", "EDIT_STEP": "Editar paso", "DELETE_STEP": "Eliminar paso", "DELETE_STEP_TITLE": "¿Eliminar este paso?", "DELETE_STEP_TEXT": "«{title}» se quita del contrato.", "STEP_STARTED_NO_DELETE": "Este paso ya ha empezado, así que se puede cambiar pero no eliminar.", "CREATE_CONTRACT": "Crear contrato", "JOB_HAS_CONTRACT": "Este trabajo ya tiene un contrato.", "JOB_NOT_YOURS": "Solo quien creó el trabajo puede cambiarlo.", "JOB_CANNOT_EDIT": "Ya se ha contratado a alguien, así que el trabajo ya no se puede cambiar.", "EDIT_JOB": "Editar trabajo", "EDIT_JOB_INTRO": "Los profesionales ven los cambios al momento.", "EDIT_JOB_WITH_OFFERS": "Ofertas recibidas: {n}. Cuenta los cambios importantes a los profesionales en el chat, para que sus ofertas sigan encajando.", "CREATED_AGO": "Creado {time}", "DRAFT_NOT_VISIBLE": "Esto es un borrador. Los profesionales no lo verán hasta que lo publiques.", "CANCEL_JOB": "Cancelar trabajo", "CANCEL_JOB_TITLE": "¿Cancelar este trabajo?", "CANCEL_JOB_TEXT": "El trabajo se retira y no se puede volver a abrir.", "CANCEL_JOB_WITH_OFFERS_TEXT": "El trabajo se retira y se avisa a los profesionales que enviaron ofertas ({n}) de que se ha cancelado.", "DELETE_JOB_TITLE": "¿Eliminar el borrador?", "DELETE_JOB_TEXT": "El borrador se elimina para siempre.", "CANCEL_CONTRACT": "Cancelar el contrato", "CANCEL_CONTRACT_INTRO": "El trabajo se detiene aquí. Los pasos aprobados y las facturas se conservan, y se avisa a la otra parte.", "CANCEL_REASON": "¿Por qué? (opcional)", "CANCEL_REASON_PLACEHOLDER": "Unas palabras que ambos podréis ver después", "CONTRACT_CANCELLED_ON": "Cancelado el {date}", "COMPLETE_CLIENT_JOB_TEXT": "Todos los pasos están firmados. El trabajo se marca como finalizado.", "SIGN_ON_SITE": "Firma del cliente", "SIGN_ON_SITE_INTRO": "Deja que el cliente revise el trabajo y firme con el dedo en la pantalla. Así se aprueba el paso.", "CUSTOMER_NAME": "Nombre del cliente", "SIGNATURE": "Firma", "SIGN_HERE": "Firma aquí", "APPROVE_WITH_SIGNATURE": "Aprobar con firma", "CHANGE_PASSWORD": "Cambiar contraseña", "CHANGE_PASSWORD_INTRO": "Sigues con la sesión iniciada aquí. Se cerrará la sesión en tus otros teléfonos y navegadores.", "CURRENT_PASSWORD": "Contraseña actual", "CURRENT_PASSWORD_REQUIRED": "Escribe tu contraseña actual.", "CURRENT_PASSWORD_WRONG": "Esa no es tu contraseña actual.", "NEW_PASSWORD": "Nueva contraseña", "REPEAT_PASSWORD": "Repite la nueva contraseña", "PASSWORDS_DONT_MATCH": "Las contraseñas no coinciden.", "PASSWORD_SAME_AS_OLD": "Elige una contraseña que no hayas usado aquí.", "PASSWORD_CHANGED": "Contraseña cambiada", "PAYMENTS": "Pagos", "PAYMENT": "Pago", "NO_PAYMENTS": "Aún no hay pagos", "NO_PAYMENTS_TEXT": "Los pagos hechos a través de la app aparecen aquí. Los trabajos pagados con factura están en Facturas.", "PAYMENT_STATUS_PENDING": "Pendiente", "PAYMENT_STATUS_HELD": "Retenido de forma segura", "PAYMENT_STATUS_RELEASED": "Pagado", "PAYMENT_STATUS_REFUNDED": "Reembolsado", "PAYMENT_STATUS_FAILED": "Fallido", "PLATFORM_FEE": "Comisión {fee}", "TEAM": "Equipo", "TEAM_ROW_HINT": "Las personas que trabajan en la empresa", "TEAM_MANAGE_HINT": "Tus compañeros necesitan primero una cuenta de Qup Work. Toca a alguien para cambiarlo o quitarlo.", "TEAM_WORKER_HINT": "El propietario y los administradores añaden y quitan compañeros.", "ADD_MEMBER": "Añadir compañero", "ADD_MEMBER_INTRO": "Usa el correo con el que se registró en Qup Work.", "MEMBER_NOT_FOUND": "Nadie se ha registrado todavía con ese correo. Pídele que cree una cuenta primero.", "MEMBER_ALREADY": "Esa persona ya está en la empresa.", "ROLE": "Rol", "ROLE_ADMIN_HINT": "Los administradores pueden cambiar los datos de la empresa y los ajustes de facturación, y añadir compañeros.", "ROLE_WORKER_HINT": "Los empleados ven los trabajos de la empresa, registran horas y hacen el trabajo.", "REMOVE_FROM_COMPANY": "Quitar de la empresa", "REMOVE_MEMBER_TITLE": "¿Quitar de la empresa?", "REMOVE_MEMBER_TEXT": "{name} deja de ver los trabajos y clientes de la empresa.", "LEAVE_COMPANY": "Salir de la empresa", "LEAVE_COMPANY_TITLE": "¿Salir de la empresa?", "LEAVE_COMPANY_TEXT": "Dejas de ver los trabajos y clientes de {name}.", "NOTIF_JOB_WITHDRAWN": "El cliente ha cancelado el trabajo", "INVOICE_EMAILED_TO": "{email} ha recibido la factura en PDF.", "INVOICE_NO_EMAIL": "Enviada, pero no por correo: el cliente no tiene correo electrónico. Abre el PDF y compártelo tú, o usa Enviar por correo.", "INVOICE_EMAIL_NOT_SET_UP": "Enviada, pero no por correo: el correo aún no está configurado en el servidor (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Enviada, pero el correo ha fallado: {error}", "SEND_INVOICE_EMAIL_TO": "El PDF se envía por correo a {email}.", "SEND_INVOICE_NO_EMAIL": "No hay correo electrónico, así que no se enviará por correo. Puedes compartir el PDF tú mismo.", "EMAIL_INVOICE": "Enviar por correo", "PREVIEW_PDF": "Vista previa del PDF", "OPEN_PDF": "Abrir PDF", "EMAILED": "Enviada por correo", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "No enviada por correo", "INVOICE_LANGUAGE": "Idioma de la factura", "NOTIF_NEW_JOB_NEARBY": "Nuevo trabajo cerca de ti", "NOTIF_NEW_JOB_REMOTE": "Nuevo trabajo en remoto", "NOTIF_JOB_INVITED": "Te han invitado a un trabajo", "NOTIF_JOB_IN_PLACE": "«{job}» en {place}", "JOB_ALERTS": "Avisos de trabajos nuevos", "JOB_ALERTS_ON_TEXT": "Recibes un aviso cuando se publica un trabajo de tus categorías en tu zona.", "JOB_ALERTS_OFF_TEXT": "No recibirás avisos de trabajos nuevos, pero puedes seguir viéndolos en la app.", "JOB_ALERTS_NEEDS_VISIBLE": "Activa primero la visibilidad. Solo los profesionales que los clientes pueden encontrar reciben avisos.", "FORGOT_PASSWORD": "¿Has olvidado la contraseña?", "FORGOT_PASSWORD_TITLE": "Nueva contraseña", "FORGOT_PASSWORD_INTRO": "Introduce el correo con el que te registraste y te enviaremos un código.", "SEND_CODE": "Enviar código", "RESET_CODE_SENT": "Si {email} tiene una cuenta, te llegará un código de 6 cifras. Introdúcelo abajo junto con una nueva contraseña.", "RESET_CODE": "Código del correo", "RESET_CODE_INVALID": "El código tiene 6 cifras.", "RESET_CODE_WRONG": "El código es incorrecto o ha caducado. Pide uno nuevo.", "SAVE_NEW_PASSWORD": "Guardar e iniciar sesión", "RESET_CODE_AGAIN": "Enviar un código nuevo", "RESET_CODE_RESENT": "Código nuevo enviado", "RESET_CODE_SPAM_HINT": "¿No te ha llegado el correo en unos minutos? Revisa la carpeta de spam.", "DELETE_ACCOUNT": "Eliminar cuenta", "DELETE_ACCOUNT_INTRO": "Esto elimina la cuenta de {email}. No se puede deshacer.", "DELETE_WHAT_GOES": "Se elimina", "DELETE_GOES_PROFILE": "Tu nombre, foto, teléfono y correo", "DELETE_GOES_PRO": "Tu perfil profesional, así que los clientes ya no podrán encontrarte", "DELETE_GOES_JOBS": "Los trabajos abiertos que has publicado y las ofertas que nadie ha respondido", "DELETE_GOES_LOGIN": "Tu inicio de sesión, en todos los dispositivos", "DELETE_WHAT_STAYS": "Se conserva, sin tu nombre", "DELETE_STAYS_CONTRACTS": "Contratos terminados, mensajes y opiniones, para que la otra parte los siga teniendo", "DELETE_STAYS_INVOICES": "Facturas, que la normativa contable noruega obliga a conservar durante 5 años", "DELETE_PASSWORD_HINT": "Para asegurarnos de que eres tú.", "DELETE_ACCOUNT_CONFIRM_TITLE": "¿Eliminar tu cuenta?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Se cerrará tu sesión y no podrás volver a iniciar sesión con esta cuenta.", "DELETE_BLOCKED_CONTRACTS": "Tienes contratos en curso. Complétalos o cancélalos primero para que la otra parte no se quede esperando.", "DELETE_BLOCKED_COMPANY": "Eres propietario de una empresa con otros miembros. Primero elimínalos en Equipo.", "JOB_CATEGORY_REQUIRED": "Elige una categoría para que los profesionales adecuados se enteren del trabajo."}, "sv-SE": {"EDIT": "Ändra", "REMOVE": "Ta bort", "CLEAR": "Rensa", "ARCHIVE": "Arkivera", "NOTES": "Anteckningar", "YOU": "du", "DATE_PLACEHOLDER": "dd/mm/åååå", "DATE_INVALID": "Skriv datumet som dd/mm/åååå.", "AMOUNT_INVALID": "Skriv ett belopp i NOK, t.ex. 5000.", "EMAIL_INVALID": "E-postadressen ser inte rätt ut.", "POSTCODE_FORMAT": "Ett postnummer har 4 siffror.", "CLIENT": "Kund", "CLIENTS": "Kunder", "CLIENTS_PRO_ONLY": "Ditt eget kundregister är för proffs. Logga in med ett proffskonto för att använda det.", "SEARCH_CLIENTS": "Sök kunder", "CLIENTS_ACTIVE": "Aktiva", "CLIENTS_ARCHIVED": "Arkiverade", "NO_CLIENTS": "Inga kunder än", "NO_CLIENTS_TEXT": "Lägg till kunderna du jobbar för utanför marknadsplatsen och samla deras uppdrag, timmar och fakturor på ett ställe.", "NO_CLIENTS_MATCH": "Inga kunder matchar sökningen.", "NO_ARCHIVED_CLIENTS": "Inget arkiverat", "NO_ARCHIVED_CLIENTS_TEXT": "Kunder du arkiverar hamnar här, med sina gamla uppdrag och fakturor.", "NEW_CLIENT": "Ny kund", "EDIT_CLIENT": "Ändra kund", "SAVE_CLIENT": "Spara kund", "CLIENT_FORM_INTRO": "Bara du och ditt företag ser det här. Adressen används som arbetsplats på nya uppdrag.", "CLIENT_TYPE": "Typ av kund", "CLIENT_PRIVATE": "Privatperson", "CLIENT_BUSINESS": "Företag", "CLIENT_COMPANY_PLACEHOLDER": "T.ex. Bergen Eiendom AS", "CONTACT_PERSON": "Kontaktperson", "CONTACT_NAME": "Kontakt: {name}", "CLIENT_EMAIL_HINT": "Fakturor kan skickas hit.", "CLIENT_NOTES_PLACEHOLDER": "Portkod, parkering, vad hunden heter…", "CLIENT_NOTES_HINT": "Bara för dig och dina kollegor, visas aldrig för kunden.", "CLIENT_NOT_FOUND": "Kunden hittades inte", "CLIENT_IS_ARCHIVED": "Arkiverad", "CLIENT_NO_DETAILS": "Inga kontaktuppgifter än. Tryck på Ändra för att lägga till dem.", "CLIENT_JOBS": "Uppdrag", "CLIENT_NO_JOBS": "Inga uppdrag för den här kunden än.", "ARCHIVE_CLIENT": "Arkivera kund", "ARCHIVE_CLIENT_TITLE": "Arkivera kunden?", "ARCHIVE_CLIENT_TEXT": "Kunden har uppdrag, så den sparas tillsammans med uppdrag och fakturor. Du kan återställa den senare.", "RESTORE_CLIENT": "Återställ kund", "DELETE_CLIENT": "Radera kund", "DELETE_CLIENT_TITLE": "Radera kunden?", "DELETE_CLIENT_TEXT": "{name} tas bort från ditt kundregister.", "NEW_ASSIGNMENT": "Nytt uppdrag", "NEW_ASSIGNMENT_INTRO": "Registrera arbete för din egen kund och kom överens om priset. Steg, timmar och fakturor lägger du in på avtalet.", "PICK_CLIENT_INTRO": "Vem är jobbet för?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Vad som är överenskommet, material, det kunden bör veta", "START_DATE": "Startdatum", "END_DATE": "Slutdatum", "END_BEFORE_START": "Slutdatumet är före startdatumet.", "STEPS_OPTIONAL_HINT": "Valfritt. Utan steg är hela jobbet ett steg.", "STEPS_SPLIT_HINT": "Varje steg godkänns för sig. Beloppen måste gå jämnt ut med priset.", "STEPS_HOURLY_HINT": "Varje steg godkänns för sig. Timmarna förs på avtalet.", "STEP_TITLE": "Steg", "STEP_TITLE_PLACEHOLDER": "T.ex. Rivning och golvbrunn", "STEP_TITLE_REQUIRED": "Ge varje steg ett namn.", "STEP_AMOUNT": "Belopp (NOK)", "STEP_AMOUNT_REQUIRED": "Ge varje steg ett belopp.", "STEP_DUE": "Förfallodatum", "STEP_DESCRIPTION_PLACEHOLDER": "Vad som ingår i det här steget", "STEPS_MUST_ADD_UP": "Stegen måste bli {total} sammanlagt.", "STEPS_ADD_UP": "Stegen går jämnt ut med priset ✓", "STEPS_REST": "Kvar att fördela: {rest}", "STEPS_TOTAL_MISMATCH": "Stegen blir {steps}, det överenskomna priset är {total}.", "REMOVE_STEP": "Ta bort steg", "ADD_STEP": "Lägg till steg", "ADD_STEP_INTRO": "Kunden godkänner varje steg när det är klart.", "EDIT_STEP": "Ändra steg", "DELETE_STEP": "Radera steg", "DELETE_STEP_TITLE": "Radera steget?", "DELETE_STEP_TEXT": "”{title}” tas bort från avtalet.", "STEP_STARTED_NO_DELETE": "Steget är påbörjat, så det kan ändras men inte raderas.", "CREATE_CONTRACT": "Skapa avtal", "JOB_HAS_CONTRACT": "Det här uppdraget har redan ett avtal.", "JOB_NOT_YOURS": "Bara den som skapade uppdraget kan ändra det.", "JOB_CANNOT_EDIT": "Någon är redan anlitad, så uppdraget kan inte ändras längre.", "EDIT_JOB": "Ändra uppdrag", "EDIT_JOB_INTRO": "Proffsen ser ändringarna direkt.", "EDIT_JOB_WITH_OFFERS": "Mottagna offerter: {n}. Berätta för proffsen om stora ändringar i chatten, så att offerterna fortfarande stämmer.", "CREATED_AGO": "Skapat {time}", "DRAFT_NOT_VISIBLE": "Det här är ett utkast. Proffs ser det inte förrän du publicerar det.", "CANCEL_JOB": "Ställ in uppdraget", "CANCEL_JOB_TITLE": "Ställa in uppdraget?", "CANCEL_JOB_TEXT": "Uppdraget tas ner och kan inte öppnas igen.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Uppdraget tas ner och proffsen som har skickat offerter ({n}) får besked om att det är inställt.", "DELETE_JOB_TITLE": "Radera utkastet?", "DELETE_JOB_TEXT": "Utkastet raderas för gott.", "CANCEL_CONTRACT": "Avbryt avtalet", "CANCEL_CONTRACT_INTRO": "Arbetet stoppas här. Godkända steg och fakturor sparas, och den andra parten får besked.", "CANCEL_REASON": "Varför? (valfritt)", "CANCEL_REASON_PLACEHOLDER": "Några ord som ni båda kan se senare", "CONTRACT_CANCELLED_ON": "Avbrutet {date}", "COMPLETE_CLIENT_JOB_TEXT": "Alla steg är signerade. Uppdraget markeras som slutfört.", "SIGN_ON_SITE": "Kunden signerar", "SIGN_ON_SITE_INTRO": "Låt kunden granska arbetet och signera med fingret på skärmen. Det godkänner steget.", "CUSTOMER_NAME": "Kundens namn", "SIGNATURE": "Signatur", "SIGN_HERE": "Signera här", "APPROVE_WITH_SIGNATURE": "Godkänn med signatur", "CHANGE_PASSWORD": "Byt lösenord", "CHANGE_PASSWORD_INTRO": "Du förblir inloggad här. Dina andra telefoner och webbläsare loggas ut.", "CURRENT_PASSWORD": "Nuvarande lösenord", "CURRENT_PASSWORD_REQUIRED": "Ange ditt nuvarande lösenord.", "CURRENT_PASSWORD_WRONG": "Det är inte ditt nuvarande lösenord.", "NEW_PASSWORD": "Nytt lösenord", "REPEAT_PASSWORD": "Upprepa nytt lösenord", "PASSWORDS_DONT_MATCH": "Lösenorden matchar inte.", "PASSWORD_SAME_AS_OLD": "Välj ett lösenord som du inte har använt här.", "PASSWORD_CHANGED": "Lösenordet är bytt", "PAYMENTS": "Betalningar", "PAYMENT": "Betalning", "NO_PAYMENTS": "Inga betalningar än", "NO_PAYMENTS_TEXT": "Betalningar via appen visas här. Uppdrag som betalas med faktura hittar du under Fakturor.", "PAYMENT_STATUS_PENDING": "Väntar", "PAYMENT_STATUS_HELD": "Säkert hållen", "PAYMENT_STATUS_RELEASED": "Utbetald", "PAYMENT_STATUS_REFUNDED": "Återbetald", "PAYMENT_STATUS_FAILED": "Misslyckades", "PLATFORM_FEE": "Avgift {fee}", "TEAM": "Team", "TEAM_ROW_HINT": "Personerna som jobbar i företaget", "TEAM_MANAGE_HINT": "Kollegor behöver ett Qup Work-konto först. Tryck på någon för att ändra eller ta bort dem.", "TEAM_WORKER_HINT": "Ägaren och administratörerna lägger till och tar bort kollegor.", "ADD_MEMBER": "Lägg till kollega", "ADD_MEMBER_INTRO": "Använd e-postadressen som de registrerade sig på Qup Work med.", "MEMBER_NOT_FOUND": "Ingen har registrerat sig med den e-postadressen än. Be dem skapa ett konto först.", "MEMBER_ALREADY": "Den personen finns redan i företaget.", "ROLE": "Roll", "ROLE_ADMIN_HINT": "Administratörer kan ändra företagsuppgifter och fakturainställningar, och lägga till kollegor.", "ROLE_WORKER_HINT": "Anställda ser företagets uppdrag, för timmar och gör jobbet.", "REMOVE_FROM_COMPANY": "Ta bort från företaget", "REMOVE_MEMBER_TITLE": "Ta bort från företaget?", "REMOVE_MEMBER_TEXT": "{name} ser inte längre företagets uppdrag och kunder.", "LEAVE_COMPANY": "Lämna företaget", "LEAVE_COMPANY_TITLE": "Lämna företaget?", "LEAVE_COMPANY_TEXT": "Du ser inte längre uppdragen och kunderna hos {name}.", "NOTIF_JOB_WITHDRAWN": "Kunden ställde in uppdraget", "INVOICE_EMAILED_TO": "{email} har fått fakturan som PDF.", "INVOICE_NO_EMAIL": "Skickad, men inte via e-post: kunden saknar e-postadress. Öppna PDF:en och dela den själv, eller använd Skicka via e-post.", "INVOICE_EMAIL_NOT_SET_UP": "Skickad, men inte via e-post: e-post är inte konfigurerad på servern än (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Skickad, men e-postmeddelandet misslyckades: {error}", "SEND_INVOICE_EMAIL_TO": "PDF:en skickas via e-post till {email}.", "SEND_INVOICE_NO_EMAIL": "Det finns ingen e-postadress, så den skickas inte via e-post. Du kan dela PDF:en själv.", "EMAIL_INVOICE": "Skicka via e-post", "PREVIEW_PDF": "Förhandsgranska PDF", "OPEN_PDF": "Öppna PDF", "EMAILED": "Skickad via e-post", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Inte skickad via e-post", "INVOICE_LANGUAGE": "Språk på fakturan", "NOTIF_NEW_JOB_NEARBY": "Nytt uppdrag nära dig", "NOTIF_NEW_JOB_REMOTE": "Nytt distansuppdrag", "NOTIF_JOB_INVITED": "Du är inbjuden till ett uppdrag", "NOTIF_JOB_IN_PLACE": "”{job}” i {place}", "JOB_ALERTS": "Aviseringar om nya uppdrag", "JOB_ALERTS_ON_TEXT": "Du får en avisering när ett uppdrag i dina kategorier läggs ut i ditt område.", "JOB_ALERTS_OFF_TEXT": "Du aviseras inte om nya uppdrag, men du kan fortfarande se dem i appen.", "JOB_ALERTS_NEEDS_VISIBLE": "Slå på synlighet först. Bara hantverkare som kunder kan hitta får aviseringar om uppdrag.", "FORGOT_PASSWORD": "Glömt lösenordet?", "FORGOT_PASSWORD_TITLE": "Nytt lösenord", "FORGOT_PASSWORD_INTRO": "Ange e-postadressen du registrerade dig med, så skickar vi en kod.", "SEND_CODE": "Skicka kod", "RESET_CODE_SENT": "Om {email} har ett konto är en 6-siffrig kod på väg. Ange den nedan tillsammans med ett nytt lösenord.", "RESET_CODE": "Kod från e-postmeddelandet", "RESET_CODE_INVALID": "Koden har 6 siffror.", "RESET_CODE_WRONG": "Koden är fel eller har gått ut. Be om en ny.", "SAVE_NEW_PASSWORD": "Spara och logga in", "RESET_CODE_AGAIN": "Skicka en ny kod", "RESET_CODE_RESENT": "Ny kod skickad", "RESET_CODE_SPAM_HINT": "Inget e-postmeddelande efter några minuter? Kolla skräpposten.", "DELETE_ACCOUNT": "Radera konto", "DELETE_ACCOUNT_INTRO": "Det här raderar kontot för {email}. Det går inte att ångra.", "DELETE_WHAT_GOES": "Raderas", "DELETE_GOES_PROFILE": "Ditt namn, foto, telefon och e-post", "DELETE_GOES_PRO": "Din hantverkarprofil, så att kunder inte längre hittar dig", "DELETE_GOES_JOBS": "Öppna uppdrag du har lagt upp, och offerter som ingen har svarat på", "DELETE_GOES_LOGIN": "Din inloggning, på alla enheter", "DELETE_WHAT_STAYS": "Sparas, utan ditt namn", "DELETE_STAYS_CONTRACTS": "Avslutade avtal, meddelanden och omdömen, så att den andra parten fortfarande har dem", "DELETE_STAYS_INVOICES": "Fakturor, som enligt norska bokföringsregler måste sparas i 5 år", "DELETE_PASSWORD_HINT": "För att vara säkra på att det är du.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Radera ditt konto?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Du loggas ut och kan inte logga in med det här kontot igen.", "DELETE_BLOCKED_CONTRACTS": "Du har pågående avtal. Slutför eller avbryt dem först, så att den andra parten inte behöver vänta.", "DELETE_BLOCKED_COMPANY": "Du äger ett företag med andra medlemmar. Ta bort dem under Team först.", "JOB_CATEGORY_REQUIRED": "Välj en kategori, så att rätt proffs får höra om uppdraget."}, "it-IT": {"EDIT": "Modifica", "REMOVE": "Rimuovi", "CLEAR": "Cancella", "ARCHIVE": "Archivia", "NOTES": "Note", "YOU": "tu", "DATE_PLACEHOLDER": "gg/mm/aaaa", "DATE_INVALID": "Scrivi la data come gg/mm/aaaa.", "AMOUNT_INVALID": "Scrivi un importo in NOK, ad es. 5000.", "EMAIL_INVALID": "Questo indirizzo email non sembra corretto.", "POSTCODE_FORMAT": "Il CAP ha 4 cifre.", "CLIENT": "Cliente", "CLIENTS": "Clienti", "CLIENTS_PRO_ONLY": "Il registro clienti è per i professionisti. Accedi con un account da professionista per usarlo.", "SEARCH_CLIENTS": "Cerca clienti", "CLIENTS_ACTIVE": "Attivi", "CLIENTS_ARCHIVED": "Archiviati", "NO_CLIENTS": "Ancora nessun cliente", "NO_CLIENTS_TEXT": "Aggiungi i clienti per cui lavori fuori dal marketplace e tieni lavori, ore e fatture in un unico posto.", "NO_CLIENTS_MATCH": "Nessun cliente corrisponde alla ricerca.", "NO_ARCHIVED_CLIENTS": "Niente in archivio", "NO_ARCHIVED_CLIENTS_TEXT": "I clienti che archivi finiscono qui, con i loro vecchi lavori e fatture.", "NEW_CLIENT": "Nuovo cliente", "EDIT_CLIENT": "Modifica cliente", "SAVE_CLIENT": "Salva cliente", "CLIENT_FORM_INTRO": "Solo tu e la tua azienda potete vederlo. L’indirizzo viene usato come indirizzo dei lavori nuovi.", "CLIENT_TYPE": "Tipo di cliente", "CLIENT_PRIVATE": "Privato", "CLIENT_BUSINESS": "Azienda", "CLIENT_COMPANY_PLACEHOLDER": "Ad es. Bergen Eiendom AS", "CONTACT_PERSON": "Referente", "CONTACT_NAME": "Referente: {name}", "CLIENT_EMAIL_HINT": "Le fatture possono essere inviate qui.", "CLIENT_NOTES_PLACEHOLDER": "Codice del cancello, parcheggio, il nome del cane…", "CLIENT_NOTES_HINT": "Solo per te e i tuoi colleghi, mai mostrato al cliente.", "CLIENT_NOT_FOUND": "Cliente non trovato", "CLIENT_IS_ARCHIVED": "Archiviato", "CLIENT_NO_DETAILS": "Ancora nessun recapito. Tocca Modifica per aggiungerli.", "CLIENT_JOBS": "Lavori", "CLIENT_NO_JOBS": "Ancora nessun lavoro per questo cliente.", "ARCHIVE_CLIENT": "Archivia cliente", "ARCHIVE_CLIENT_TITLE": "Archiviare questo cliente?", "ARCHIVE_CLIENT_TEXT": "Il cliente ha dei lavori, quindi viene conservato insieme a lavori e fatture. Puoi ripristinarlo più tardi.", "RESTORE_CLIENT": "Ripristina cliente", "DELETE_CLIENT": "Elimina cliente", "DELETE_CLIENT_TITLE": "Eliminare questo cliente?", "DELETE_CLIENT_TEXT": "{name} viene rimosso dal tuo registro.", "NEW_ASSIGNMENT": "Nuovo incarico", "NEW_ASSIGNMENT_INTRO": "Registra un lavoro per un tuo cliente e concorda il prezzo. Dal contratto puoi aggiungere fasi, registrare ore e fatturare.", "PICK_CLIENT_INTRO": "Per chi è il lavoro?", "ASSIGNMENT_DESCRIPTION_PLACEHOLDER": "Cosa è stato concordato, materiali, tutto ciò che il cliente deve sapere", "START_DATE": "Data di inizio", "END_DATE": "Data di fine", "END_BEFORE_START": "La data di fine è prima della data di inizio.", "STEPS_OPTIONAL_HINT": "Facoltativo. Senza fasi, l’intero lavoro è una sola fase.", "STEPS_SPLIT_HINT": "Ogni fase viene approvata separatamente. Gli importi devono corrispondere al prezzo.", "STEPS_HOURLY_HINT": "Ogni fase viene approvata separatamente. Le ore vengono registrate sul contratto.", "STEP_TITLE": "Fase", "STEP_TITLE_PLACEHOLDER": "Ad es. Demolizione e scarichi", "STEP_TITLE_REQUIRED": "Dai un nome a ogni fase.", "STEP_AMOUNT": "Importo (NOK)", "STEP_AMOUNT_REQUIRED": "Indica un importo per ogni fase.", "STEP_DUE": "Scadenza", "STEP_DESCRIPTION_PLACEHOLDER": "Cosa comprende questa fase", "STEPS_MUST_ADD_UP": "La somma delle fasi deve essere {total}.", "STEPS_ADD_UP": "La somma delle fasi corrisponde al prezzo ✓", "STEPS_REST": "Da ripartire: {rest}", "STEPS_TOTAL_MISMATCH": "La somma delle fasi è {steps}, il prezzo concordato è {total}.", "REMOVE_STEP": "Rimuovi fase", "ADD_STEP": "Aggiungi fase", "ADD_STEP_INTRO": "Il cliente approva ogni fase quando è completata.", "EDIT_STEP": "Modifica fase", "DELETE_STEP": "Elimina fase", "DELETE_STEP_TITLE": "Eliminare questa fase?", "DELETE_STEP_TEXT": "«{title}» viene rimossa dal contratto.", "STEP_STARTED_NO_DELETE": "Questa fase è già iniziata, quindi puoi modificarla ma non eliminarla.", "CREATE_CONTRACT": "Crea contratto", "JOB_HAS_CONTRACT": "Questo lavoro ha già un contratto.", "JOB_NOT_YOURS": "Solo chi ha creato il lavoro può modificarlo.", "JOB_CANNOT_EDIT": "Qualcuno è già stato incaricato, quindi il lavoro non può più essere modificato.", "EDIT_JOB": "Modifica lavoro", "EDIT_JOB_INTRO": "I professionisti vedono subito le modifiche.", "EDIT_JOB_WITH_OFFERS": "Preventivi ricevuti: {n}. Informa i professionisti delle modifiche importanti in chat, così i loro preventivi restano validi.", "CREATED_AGO": "Creato {time}", "DRAFT_NOT_VISIBLE": "Questa è una bozza. I professionisti non la vedono finché non la pubblichi.", "CANCEL_JOB": "Annulla lavoro", "CANCEL_JOB_TITLE": "Annullare questo lavoro?", "CANCEL_JOB_TEXT": "Il lavoro viene ritirato e non può essere riaperto.", "CANCEL_JOB_WITH_OFFERS_TEXT": "Il lavoro viene ritirato e i professionisti che hanno inviato un preventivo ({n}) vengono avvisati dell’annullamento.", "DELETE_JOB_TITLE": "Eliminare la bozza?", "DELETE_JOB_TEXT": "La bozza viene eliminata definitivamente.", "CANCEL_CONTRACT": "Annulla il contratto", "CANCEL_CONTRACT_INTRO": "Il lavoro si ferma qui. Le fasi approvate e le fatture restano, e l’altra parte viene avvisata.", "CANCEL_REASON": "Perché? (facoltativo)", "CANCEL_REASON_PLACEHOLDER": "Due parole che potrete vedere entrambi più tardi", "CONTRACT_CANCELLED_ON": "Annullato il {date}", "COMPLETE_CLIENT_JOB_TEXT": "Tutte le fasi sono firmate. Il lavoro viene segnato come completato.", "SIGN_ON_SITE": "Firma del cliente", "SIGN_ON_SITE_INTRO": "Fai controllare il lavoro al cliente e fallo firmare con un dito sullo schermo. Così la fase viene approvata.", "CUSTOMER_NAME": "Nome del cliente", "SIGNATURE": "Firma", "SIGN_HERE": "Firma qui", "APPROVE_WITH_SIGNATURE": "Approva con firma", "CHANGE_PASSWORD": "Cambia password", "CHANGE_PASSWORD_INTRO": "Qui resti connesso. Dagli altri telefoni e browser verrai disconnesso.", "CURRENT_PASSWORD": "Password attuale", "CURRENT_PASSWORD_REQUIRED": "Inserisci la password attuale.", "CURRENT_PASSWORD_WRONG": "Questa non è la tua password attuale.", "NEW_PASSWORD": "Nuova password", "REPEAT_PASSWORD": "Ripeti la nuova password", "PASSWORDS_DONT_MATCH": "Le password non coincidono.", "PASSWORD_SAME_AS_OLD": "Scegli una password che non hai già usato qui.", "PASSWORD_CHANGED": "Password cambiata", "PAYMENTS": "Pagamenti", "PAYMENT": "Pagamento", "NO_PAYMENTS": "Ancora nessun pagamento", "NO_PAYMENTS_TEXT": "I pagamenti fatti tramite l’app compaiono qui. I lavori pagati con fattura sono in Fatture.", "PAYMENT_STATUS_PENDING": "In attesa", "PAYMENT_STATUS_HELD": "Custodito in sicurezza", "PAYMENT_STATUS_RELEASED": "Pagato", "PAYMENT_STATUS_REFUNDED": "Rimborsato", "PAYMENT_STATUS_FAILED": "Non riuscito", "PLATFORM_FEE": "Commissione {fee}", "TEAM": "Team", "TEAM_ROW_HINT": "Le persone che lavorano nell’azienda", "TEAM_MANAGE_HINT": "I colleghi devono prima avere un account Qup Work. Tocca una persona per modificarla o rimuoverla.", "TEAM_WORKER_HINT": "Il titolare e gli amministratori aggiungono e rimuovono i colleghi.", "ADD_MEMBER": "Aggiungi collega", "ADD_MEMBER_INTRO": "Usa l’email con cui si è registrato a Qup Work.", "MEMBER_NOT_FOUND": "Nessuno si è ancora registrato con questa email. Chiedigli di creare prima un account.", "MEMBER_ALREADY": "Questa persona fa già parte dell’azienda.", "ROLE": "Ruolo", "ROLE_ADMIN_HINT": "Gli amministratori possono modificare i dati dell’azienda e le impostazioni di fatturazione, e aggiungere colleghi.", "ROLE_WORKER_HINT": "I dipendenti vedono i lavori dell’azienda, registrano le ore e svolgono il lavoro.", "REMOVE_FROM_COMPANY": "Rimuovi dall’azienda", "REMOVE_MEMBER_TITLE": "Rimuovere dall’azienda?", "REMOVE_MEMBER_TEXT": "{name} non vedrà più i lavori e i clienti dell’azienda.", "LEAVE_COMPANY": "Lascia l’azienda", "LEAVE_COMPANY_TITLE": "Lasciare l’azienda?", "LEAVE_COMPANY_TEXT": "Non vedrai più i lavori e i clienti di {name}.", "NOTIF_JOB_WITHDRAWN": "Il cliente ha annullato il lavoro", "INVOICE_EMAILED_TO": "{email} ha ricevuto la fattura in PDF.", "INVOICE_NO_EMAIL": "Inviata, ma non via email: il cliente non ha un indirizzo email. Apri il PDF e condividilo tu, oppure usa Invia via email.", "INVOICE_EMAIL_NOT_SET_UP": "Inviata, ma non via email: l'email non è ancora configurata sul server (RESEND_API_KEY).", "INVOICE_EMAIL_FAILED": "Inviata, ma l'email non è andata a buon fine: {error}", "SEND_INVOICE_EMAIL_TO": "Il PDF viene inviato via email a {email}.", "SEND_INVOICE_NO_EMAIL": "Non c'è un indirizzo email, quindi non verrà inviata via email. Puoi condividere il PDF tu.", "EMAIL_INVOICE": "Invia via email", "PREVIEW_PDF": "Anteprima PDF", "OPEN_PDF": "Apri PDF", "EMAILED": "Inviata via email", "EMAILED_ON": "{email}, {date}", "NOT_EMAILED": "Non inviata via email", "INVOICE_LANGUAGE": "Lingua della fattura", "NOTIF_NEW_JOB_NEARBY": "Nuovo lavoro vicino a te", "NOTIF_NEW_JOB_REMOTE": "Nuovo lavoro da remoto", "NOTIF_JOB_INVITED": "Sei stato invitato a un lavoro", "NOTIF_JOB_IN_PLACE": "«{job}» a {place}", "JOB_ALERTS": "Avvisi nuovi lavori", "JOB_ALERTS_ON_TEXT": "Ricevi una notifica quando nella tua zona viene pubblicato un lavoro nelle tue categorie.", "JOB_ALERTS_OFF_TEXT": "Non riceverai avvisi sui nuovi lavori, ma puoi comunque vederli nell'app.", "JOB_ALERTS_NEEDS_VISIBLE": "Attiva prima la visibilità. Solo i professionisti che i clienti possono trovare ricevono gli avvisi.", "FORGOT_PASSWORD": "Password dimenticata?", "FORGOT_PASSWORD_TITLE": "Nuova password", "FORGOT_PASSWORD_INTRO": "Inserisci l’email con cui ti sei registrato e ti invieremo un codice.", "SEND_CODE": "Invia codice", "RESET_CODE_SENT": "Se {email} ha un account, è in arrivo un codice di 6 cifre. Inseriscilo qui sotto insieme a una nuova password.", "RESET_CODE": "Codice dall’email", "RESET_CODE_INVALID": "Il codice ha 6 cifre.", "RESET_CODE_WRONG": "Il codice è errato o scaduto. Richiedine uno nuovo.", "SAVE_NEW_PASSWORD": "Salva e accedi", "RESET_CODE_AGAIN": "Invia un nuovo codice", "RESET_CODE_RESENT": "Nuovo codice inviato", "RESET_CODE_SPAM_HINT": "Nessuna email dopo qualche minuto? Controlla la cartella spam.", "DELETE_ACCOUNT": "Elimina account", "DELETE_ACCOUNT_INTRO": "Questa azione elimina l’account di {email}. Non si può annullare.", "DELETE_WHAT_GOES": "Viene eliminato", "DELETE_GOES_PROFILE": "Nome, foto, telefono ed email", "DELETE_GOES_PRO": "Il tuo profilo professionale, così i clienti non ti troveranno più", "DELETE_GOES_JOBS": "I lavori aperti che hai pubblicato e i preventivi a cui nessuno ha risposto", "DELETE_GOES_LOGIN": "Il tuo accesso, su tutti i dispositivi", "DELETE_WHAT_STAYS": "Viene conservato, senza il tuo nome", "DELETE_STAYS_CONTRACTS": "Contratti conclusi, messaggi e recensioni, così l’altra parte li ha ancora", "DELETE_STAYS_INVOICES": "Le fatture, che le norme contabili norvegesi impongono di conservare per 5 anni", "DELETE_PASSWORD_HINT": "Per essere sicuri che sei tu.", "DELETE_ACCOUNT_CONFIRM_TITLE": "Eliminare il tuo account?", "DELETE_ACCOUNT_CONFIRM_TEXT": "Verrai disconnesso e non potrai più accedere con questo account.", "DELETE_BLOCKED_CONTRACTS": "Hai contratti in corso. Completali o annullali prima, così l’altra parte non resta in attesa.", "DELETE_BLOCKED_COMPANY": "Possiedi un’azienda con altri membri. Rimuovili prima in Team.", "JOB_CATEGORY_REQUIRED": "Scegli una categoria, così i professionisti giusti vengono a sapere del lavoro."}}
QUP_LOCALES_EOF
node - "$BACKUP/new-texts.json" <<'QUP_NODE_EOF'
const fs = require('fs');
const all = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
let added = 0;
for (const [code, texts] of Object.entries(all)) {
  const file = `src/locales/${code}.json`;
  if (!fs.existsSync(file)) { console.log(`     ⚠️  ${file} not found, skipped`); continue; }
  const data = JSON.parse(fs.readFileSync(file, 'utf8'));
  for (const [k, v] of Object.entries(texts)) if (!(k in data)) { data[k] = v; added++; }
  fs.writeFileSync(file, JSON.stringify(data, null, '\t') + '\n');
}
console.log(`     ${added} texts added`);
QUP_NODE_EOF

# ---- app.json: the expo-notifications plugin
cp app.json "$BACKUP/app.json"
node -e '
const fs = require("fs");
const cfg = JSON.parse(fs.readFileSync("app.json", "utf8"));
const plugins = (cfg.expo.plugins ??= []);
if (!plugins.some((p) => (Array.isArray(p) ? p[0] : p) === "expo-notifications")) {
  plugins.push(["expo-notifications", { color: "#1D2A2E" }]);
  fs.writeFileSync("app.json", JSON.stringify(cfg, null, 2) + "\n");
  console.log("  ✏️  app.json (expo-notifications plugin)");
}
'

echo
echo "📦 Installing expo-notifications (the version that matches your Expo SDK)..."
if npx expo install expo-notifications; then
  echo "✅ Done. $CHANGED files updated, backups in $BACKUP/"
else
  echo "⚠️  Files are updated, but the install failed. Run this yourself: npx expo install expo-notifications"
fi
[ -f scripts/check-locales.mjs ] && node scripts/check-locales.mjs || true
echo "Push needs an EAS project id (npx eas-cli@latest init) and a development build; Expo Go skips it."
