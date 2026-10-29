// /qup-work-app/src/app/account.js
// My details: profile photo, name and phone. (Email and password are separate.)
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
