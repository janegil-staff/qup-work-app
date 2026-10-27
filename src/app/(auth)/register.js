// /qup-work-app/src/app/(auth)/register.js
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

export default function RegisterScreen() {
  const { register } = useAuth();
  const { t } = useI18n();
  const insets = useSafeAreaInsets();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);
  const emailRef = useRef(null);
  const passwordRef = useRef(null);

  async function onSubmit() {
    if (!name || !email || !password) {
      setError(t('REGISTER_FILL_FIELDS'));
      return;
    }
    if (password.length < 8) {
      setError(t('PASSWORD_TOO_SHORT'));
      return;
    }
    setError(null);
    setLoading(true);
    try {
      await register(name, email, password);
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
            {t('CREATE_ACCOUNT')}
          </AppText>
          <AppText variant="body" muted>
            {t('REGISTER_INTRO')}
          </AppText>
        </View>

        <View style={styles.form}>
          <ErrorBanner message={error} />
          <TextField
            label={t('NAME')}
            value={name}
            onChangeText={setName}
            placeholder={t('NAME_PLACEHOLDER')}
            autoComplete="name"
            textContentType="name"
            returnKeyType="next"
            onSubmitEditing={() => emailRef.current?.focus()}
          />
          <TextField
            ref={emailRef}
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
            autoComplete="new-password"
            textContentType="newPassword"
            returnKeyType="go"
            onSubmitEditing={onSubmit}
            hint={t('PASSWORD_HINT')}
            error={password.length > 0 && password.length < 8 ? t('PASSWORD_HINT') : undefined}
          />
          <Button title={t('CREATE_ACCOUNT')} variant="dark" onPress={onSubmit} loading={loading} />
        </View>

        <Pressable onPress={() => router.replace('/login')} style={styles.switch} accessibilityRole="link">
          <AppText variant="body" muted>
            {t('HAVE_ACCOUNT')}
          </AppText>
          <AppText variant="bodyStrong" style={styles.switchLink}>
            {t('LOG_IN')}
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
