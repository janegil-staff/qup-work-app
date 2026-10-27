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
import { errorMessage } from '@/lib/api';

export default function LoginScreen() {
  const { login } = useAuth();
  const insets = useSafeAreaInsets();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);
  const passwordRef = useRef(null);

  async function onSubmit() {
    if (!email || !password) {
      setError('Fyll inn e-post og passord.');
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
        contentContainerStyle={[styles.content, { paddingTop: Platform.OS === 'ios' ? spacing.lg : insets.top + spacing.md }]}
        keyboardShouldPersistTaps="handled"
      >
        <BackButton icon="close" label="Lukk" onPress={() => goBackOr('/')} />

        <View style={styles.header}>
          <AppText variant="display" accessibilityRole="header">
            Logg inn
          </AppText>
          <AppText variant="body" muted>
            Gi tilbud, send meldinger og følg jobbene dine.
          </AppText>
        </View>

        <View style={styles.form}>
          <ErrorBanner message={error} />
          <TextField
            label="E-post"
            value={email}
            onChangeText={setEmail}
            placeholder="navn@eksempel.no"
            autoCapitalize="none"
            autoComplete="email"
            keyboardType="email-address"
            textContentType="emailAddress"
            returnKeyType="next"
            onSubmitEditing={() => passwordRef.current?.focus()}
          />
          <TextField
            ref={passwordRef}
            label="Passord"
            value={password}
            onChangeText={setPassword}
            secureTextEntry
            autoComplete="current-password"
            textContentType="password"
            returnKeyType="go"
            onSubmitEditing={onSubmit}
          />
          <Button title="Logg inn" variant="dark" onPress={onSubmit} loading={loading} />
        </View>

        <Pressable onPress={() => router.replace('/register')} style={styles.switch} accessibilityRole="link">
          <AppText variant="body" muted>
            Ny her?
          </AppText>
          <AppText variant="bodyStrong" style={styles.switchLink}>
            Opprett konto
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
