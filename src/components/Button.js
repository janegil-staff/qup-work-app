// /qup-work-app/src/components/Button.js
//   primary → hi-vis yellow (the main action on a screen, use once)
//   dark    → slate
//   outline → transparent with a border
//   danger  → for logout / cancel
import Ionicons from '@expo/vector-icons/Ionicons';
import { ActivityIndicator, Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { colors, radius, spacing } from '@/constants/theme';

const VARIANTS = {
  primary: { bg: colors.hivis, border: colors.hivis, text: colors.slate },
  dark: { bg: colors.slate, border: colors.slate, text: colors.textOnDark },
  outline: { bg: 'transparent', border: colors.slate, text: colors.slate },
  outlineOnDark: { bg: 'transparent', border: colors.slateLine, text: colors.textOnDark },
  danger: { bg: 'transparent', border: colors.danger, text: colors.danger },
};

export function Button({ title, onPress, variant = 'primary', icon, loading, disabled, small, style }) {
  const v = VARIANTS[variant];
  const inactive = disabled || loading;

  return (
    <Pressable
      onPress={onPress}
      disabled={inactive}
      accessibilityRole="button"
      accessibilityState={{ disabled: inactive, busy: loading }}
      style={({ pressed }) => [
        styles.base,
        small && styles.small,
        { backgroundColor: v.bg, borderColor: v.border },
        pressed && { transform: [{ scale: 0.98 }], opacity: 0.9 },
        inactive && styles.inactive,
        style,
      ]}
    >
      {loading ? (
        <ActivityIndicator color={v.text} />
      ) : (
        <View style={styles.content}>
          {icon ? <Ionicons name={icon} size={small ? 16 : 19} color={v.text} /> : null}
          <AppText variant="button" color={v.text} style={small && { fontSize: 14 }}>
            {title}
          </AppText>
        </View>
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: {
    minHeight: 52,
    borderRadius: radius.md,
    borderWidth: 1.5,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: spacing.xl,
  },
  small: { minHeight: 40, paddingHorizontal: spacing.lg, borderRadius: radius.sm },
  content: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  inactive: { opacity: 0.45 },
});
