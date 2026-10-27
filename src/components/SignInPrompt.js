// /qup-work-app/src/components/SignInPrompt.js
// Shown on screens that need an account (Meldinger, Profil) when browsing as a guest.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { Button } from '@/components/Button';
import { colors, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';

export function SignInPrompt({ icon = 'person-outline', title, text }) {
  const { t } = useI18n();
  return (
    <View style={styles.wrapper}>
      <View style={styles.icon}>
        <Ionicons name={icon} size={30} color={colors.slate} />
      </View>
      <View style={{ gap: spacing.sm }}>
        <AppText variant="h2" center>
          {title}
        </AppText>
        <AppText variant="body" muted center>
          {text}
        </AppText>
      </View>
      <View style={styles.buttons}>
        <Button title={t('LOG_IN')} variant="dark" onPress={() => router.push('/login')} />
        <Button title={t('CREATE_ACCOUNT')} variant="outline" onPress={() => router.push('/register')} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'stretch',
    gap: spacing.xl,
    padding: spacing.xxl,
    maxWidth: 440,
    width: '100%',
    alignSelf: 'center',
  },
  icon: {
    alignSelf: 'center',
    width: 68,
    height: 68,
    borderRadius: radius.lg,
    backgroundColor: colors.hivis,
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttons: { gap: spacing.md },
});
