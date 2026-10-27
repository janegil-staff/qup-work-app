// /qup-work-app/src/components/BackButton.js
import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { Pressable, StyleSheet } from 'react-native';
import { colors } from '@/constants/theme';
import { useI18n } from '@/i18n';

// Goes back, or to the start screen when the page was opened directly (deep link / web)
export function goBackOr(fallback = '/') {
  if (router.canGoBack()) router.back();
  else router.replace(fallback);
}

export function BackButton({ onDark, icon = 'arrow-back', label, onPress }) {
  const { t } = useI18n();
  return (
    <Pressable
      onPress={onPress ?? (() => goBackOr())}
      hitSlop={10}
      accessibilityRole="button"
      accessibilityLabel={label ?? (icon === 'close' ? t('CLOSE') : t('BACK'))}
      style={({ pressed }) => [styles.button, onDark ? styles.onDark : styles.light, pressed && { opacity: 0.7 }]}
    >
      <Ionicons name={icon} size={22} color={onDark ? colors.textOnDark : colors.text} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: { width: 42, height: 42, borderRadius: 21, alignItems: 'center', justifyContent: 'center' },
  onDark: { backgroundColor: colors.slateRaised },
  light: { backgroundColor: colors.paper },
});
