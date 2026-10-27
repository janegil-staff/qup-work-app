// /qup-work-app/src/components/ErrorBanner.js
import Ionicons from '@expo/vector-icons/Ionicons';
import { Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { colors, radius, spacing } from '@/constants/theme';

export function ErrorBanner({ message, onRetry, style }) {
  if (!message) return null;
  return (
    <View style={[styles.box, style]} accessibilityRole="alert">
      <Ionicons name="alert-circle" size={20} color={colors.danger} />
      <AppText variant="small" color={colors.danger} style={{ flex: 1 }}>
        {message}
      </AppText>
      {onRetry ? (
        <Pressable onPress={onRetry} hitSlop={10} accessibilityRole="button">
          <AppText variant="smallStrong" color={colors.danger}>
            Prøv igjen
          </AppText>
        </Pressable>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  box: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    backgroundColor: colors.dangerSoft,
    borderRadius: radius.md,
    padding: spacing.md,
  },
});
